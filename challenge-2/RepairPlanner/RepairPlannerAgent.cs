using System.Text.Json;
using System.Text.Json.Serialization;
using Azure.AI.Projects;
using Azure.AI.Projects.OpenAI;
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;
using Microsoft.Extensions.Logging;
using RepairPlanner.Models;
using RepairPlanner.Services;

namespace RepairPlanner;

// Primary constructor parameters are available throughout the class, like values assigned in Python's __init__.
public sealed class RepairPlannerAgent(
    AIProjectClient projectClient,
    CosmosDbService cosmosDb,
    IFaultMappingService faultMapping,
    string modelDeploymentName,
    ILogger<RepairPlannerAgent> logger)
{
    private const string AgentName = "RepairPlannerAgent";

    private const string AgentInstructions = """
        You are a Repair Planner Agent for tire manufacturing equipment.
        Generate a practical repair plan using only the technicians and parts supplied in the request.
        Return only valid JSON matching the requested WorkOrder schema. Do not use Markdown fences.

        Required fields:
        - workOrderNumber, machineId, faultType, title, description
        - type: "corrective" | "preventive" | "emergency"
        - priority: "critical" | "high" | "medium" | "low"
        - status, assignedTo, notes
        - estimatedDuration: integer minutes
        - partsUsed: [{ partId, partNumber, quantity }]
        - tasks: [{ sequence, title, description, estimatedDurationMinutes, requiredSkills: [string], safetyNotes: [string] }]

        Rules:
        - Assign the most qualified available technician, or null if no supplied technician is suitable.
        - Include only supplied parts with sufficient inventory; use an empty array when none are needed.
        - Order tasks by sequence and make each step actionable.
        - All duration and quantity fields must be integers, not strings with units.
        """;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        NumberHandling = JsonNumberHandling.AllowReadingFromString,
        Converters = { new StringOrArrayJsonConverter() }
    };

    public async Task EnsureAgentVersionAsync(CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(modelDeploymentName))
        {
            throw new InvalidOperationException("A model deployment name is required.");
        }

        var definition = new PromptAgentDefinition(model: modelDeploymentName)
        {
            Instructions = AgentInstructions
        };

        await projectClient.Agents.CreateAgentVersionAsync(
            AgentName,
            new AgentVersionCreationOptions(definition),
            cancellationToken);

        logger.LogInformation("Registered Foundry agent {AgentName}", AgentName);
    }

    public async Task<WorkOrder> PlanAndCreateWorkOrderAsync(
        DiagnosedFault fault,
        CancellationToken cancellationToken = default)
    {
        ValidateFault(fault);

        var requiredSkills = faultMapping.GetRequiredSkills(fault.FaultType);
        var requiredPartNumbers = faultMapping.GetRequiredParts(fault.FaultType);

        var techniciansTask = cosmosDb.GetAvailableTechniciansWithSkillsAsync(
            requiredSkills,
            cancellationToken);
        var partsTask = cosmosDb.GetPartsInventoryAsync(requiredPartNumbers, cancellationToken);

        await Task.WhenAll(techniciansTask, partsTask);
        var technicians = await techniciansTask;
        var parts = await partsTask;

        logger.LogInformation(
            "Planning repair for {FaultType} on {MachineId} with {TechnicianCount} technicians and {PartCount} parts",
            fault.FaultType,
            fault.MachineId,
            technicians.Count,
            parts.Count);

        var prompt = BuildPrompt(fault, requiredSkills, requiredPartNumbers, technicians, parts);
        var agent = projectClient.GetAIAgent(name: AgentName);
        var response = await agent.RunAsync(prompt, thread: null, options: null, cancellationToken);

        var workOrder = DeserializeWorkOrder(response.Text);
        ApplyDefaultsAndConstraints(workOrder, fault, technicians, parts);

        await cosmosDb.CreateWorkOrderAsync(workOrder, cancellationToken);
        return workOrder;
    }

    private static string BuildPrompt(
        DiagnosedFault fault,
        IReadOnlyList<string> requiredSkills,
        IReadOnlyList<string> requiredPartNumbers,
        IReadOnlyList<Technician> technicians,
        IReadOnlyList<Part> parts)
    {
        var context = new
        {
            fault,
            requiredSkills,
            requiredPartNumbers,
            availableTechnicians = technicians,
            inventoryParts = parts
        };

        return $"""
            Create one repair work order from this grounded planning context:
            {JsonSerializer.Serialize(context, JsonOptions)}
            """;
    }

    private static WorkOrder DeserializeWorkOrder(string? responseText)
    {
        if (string.IsNullOrWhiteSpace(responseText))
        {
            throw new InvalidOperationException("The Repair Planner Agent returned an empty response.");
        }

        var json = ExtractJsonObject(responseText);

        try
        {
            return JsonSerializer.Deserialize<WorkOrder>(json, JsonOptions)
                ?? throw new InvalidOperationException("The Repair Planner Agent returned JSON with no work order.");
        }
        catch (JsonException exception)
        {
            throw new InvalidOperationException("The Repair Planner Agent returned invalid WorkOrder JSON.", exception);
        }
    }

    private static string ExtractJsonObject(string responseText)
    {
        var firstBrace = responseText.IndexOf('{');
        var lastBrace = responseText.LastIndexOf('}');

        if (firstBrace < 0 || lastBrace <= firstBrace)
        {
            throw new InvalidOperationException("The Repair Planner Agent response did not contain a JSON object.");
        }

        return responseText[firstBrace..(lastBrace + 1)];
    }

    private static void ApplyDefaultsAndConstraints(
        WorkOrder workOrder,
        DiagnosedFault fault,
        IReadOnlyList<Technician> technicians,
        IReadOnlyList<Part> parts)
    {
        var now = DateTimeOffset.UtcNow;

        // ?? means "if null, use this instead", similar to Python's "or" for absent values.
        workOrder.Id = string.IsNullOrWhiteSpace(workOrder.Id) ? Guid.NewGuid().ToString() : workOrder.Id;
        workOrder.WorkOrderNumber = string.IsNullOrWhiteSpace(workOrder.WorkOrderNumber)
            ? $"WO-{now:yyyyMMddHHmmss}"
            : workOrder.WorkOrderNumber;
        workOrder.MachineId = fault.MachineId;
        workOrder.FaultType = fault.FaultType;
        workOrder.Type = NormalizeChoice(workOrder.Type, "corrective", "corrective", "preventive", "emergency");
        workOrder.Priority = NormalizeChoice(
            workOrder.Priority,
            PriorityFromSeverity(fault.Severity),
            "critical",
            "high",
            "medium",
            "low");
        workOrder.Status = "new";
        workOrder.CreatedAt = now;
        workOrder.EstimatedDuration = Math.Max(0, workOrder.EstimatedDuration);

        var technicianIds = technicians.Select(technician => technician.Id).ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (workOrder.AssignedTo is not null && !technicianIds.Contains(workOrder.AssignedTo))
        {
            workOrder.AssignedTo = null;
        }

        var availableParts = parts.ToDictionary(part => part.Id, StringComparer.OrdinalIgnoreCase);
        workOrder.PartsUsed = workOrder.PartsUsed
            .Where(usage =>
                usage.Quantity > 0
                && availableParts.TryGetValue(usage.PartId, out var part)
                && usage.Quantity <= part.QuantityInStock
                && string.Equals(usage.PartNumber, part.PartNumber, StringComparison.OrdinalIgnoreCase))
            .ToList();

        workOrder.Tasks = workOrder.Tasks
            .OrderBy(task => task.Sequence)
            .Select((task, index) =>
            {
                task.Sequence = index + 1;
                task.EstimatedDurationMinutes = Math.Max(0, task.EstimatedDurationMinutes);
                return task;
            })
            .ToList();
    }

    private static string NormalizeChoice(
        string? value,
        string fallback,
        params string[] allowedValues)
    {
        return allowedValues.Contains(value, StringComparer.OrdinalIgnoreCase)
            ? value!.ToLowerInvariant()
            : fallback;
    }

    private static string PriorityFromSeverity(string? severity)
    {
        return severity?.ToLowerInvariant() switch
        {
            "critical" => "critical",
            "high" => "high",
            "low" => "low",
            _ => "medium"
        };
    }

    private static void ValidateFault(DiagnosedFault fault)
    {
        ArgumentNullException.ThrowIfNull(fault);
        ArgumentException.ThrowIfNullOrWhiteSpace(fault.MachineId);
        ArgumentException.ThrowIfNullOrWhiteSpace(fault.FaultType);
    }

    private sealed class StringOrArrayJsonConverter : JsonConverter<List<string>>
    {
        public override List<string> Read(
            ref Utf8JsonReader reader,
            Type typeToConvert,
            JsonSerializerOptions options)
        {
            if (reader.TokenType == JsonTokenType.String)
            {
                return [reader.GetString() ?? string.Empty];
            }

            if (reader.TokenType != JsonTokenType.StartArray)
            {
                throw new JsonException("Expected a string or an array of strings.");
            }

            var values = new List<string>();
            while (reader.Read() && reader.TokenType != JsonTokenType.EndArray)
            {
                if (reader.TokenType != JsonTokenType.String)
                {
                    throw new JsonException("Expected an array containing only strings.");
                }

                values.Add(reader.GetString() ?? string.Empty);
            }

            return values;
        }

        public override void Write(
            Utf8JsonWriter writer,
            List<string> value,
            JsonSerializerOptions options)
        {
            writer.WriteStartArray();
            foreach (var item in value)
            {
                writer.WriteStringValue(item);
            }

            writer.WriteEndArray();
        }
    }
}