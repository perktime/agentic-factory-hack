using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;
using RepairPlanner.Models;

namespace RepairPlanner.Services;

// Primary constructor parameters are available throughout the class, like values assigned in Python's __init__.
public sealed class CosmosDbService(
    CosmosClient client,
    CosmosDbOptions options,
    ILogger<CosmosDbService> logger)
{
    private readonly Container _technicians = GetContainer(
        client,
        options,
        CosmosDbOptions.TechniciansContainerName);

    private readonly Container _parts = GetContainer(
        client,
        options,
        CosmosDbOptions.PartsContainerName);

    private readonly Container _workOrders = GetContainer(
        client,
        options,
        CosmosDbOptions.WorkOrdersContainerName);

    public async Task<IReadOnlyList<Technician>> GetAvailableTechniciansWithSkillsAsync(
        IReadOnlyCollection<string> requiredSkills,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(requiredSkills);

        var skills = NormalizeValues(requiredSkills);
        var queryText = skills.Length == 0
            ? "SELECT * FROM c WHERE c.available = true"
            : """
              SELECT * FROM c
              WHERE c.available = true
                AND EXISTS(
                    SELECT VALUE skill
                    FROM skill IN c.skills
                    WHERE ARRAY_CONTAINS(@requiredSkills, skill)
                )
              """;

        var query = new QueryDefinition(queryText);
        if (skills.Length > 0)
        {
            query.WithParameter("@requiredSkills", skills);
        }

        return await ReadQueryAsync<Technician>(
            _technicians,
            query,
            "Query available technicians",
            cancellationToken);
    }

    public async Task<IReadOnlyList<Part>> GetPartsInventoryAsync(
        IReadOnlyCollection<string> partNumbers,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(partNumbers);

        var normalizedPartNumbers = NormalizeValues(partNumbers);
        if (normalizedPartNumbers.Length == 0)
        {
            return [];
        }

        var query = new QueryDefinition(
                "SELECT * FROM c WHERE ARRAY_CONTAINS(@partNumbers, c.partNumber)")
            .WithParameter("@partNumbers", normalizedPartNumbers);

        return await ReadQueryAsync<Part>(
            _parts,
            query,
            "Query parts inventory",
            cancellationToken);
    }

    public async Task<string> CreateWorkOrderAsync(
        WorkOrder workOrder,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(workOrder);

        if (string.IsNullOrWhiteSpace(workOrder.Id))
        {
            throw new ArgumentException("A work order must have an id.", nameof(workOrder));
        }

        if (string.IsNullOrWhiteSpace(workOrder.Status))
        {
            throw new ArgumentException("A work order must have a status partition key.", nameof(workOrder));
        }

        try
        {
            var response = await _workOrders.CreateItemAsync(
                workOrder,
                new PartitionKey(workOrder.Status),
                cancellationToken: cancellationToken);

            logger.LogInformation(
                "Created work order {WorkOrderNumber} with id {WorkOrderId}; status {Status}; RU {RequestCharge}",
                workOrder.WorkOrderNumber,
                response.Resource.Id,
                response.Resource.Status,
                response.RequestCharge);

            LogSlowOperation("Create work order", response.Diagnostics, response.RequestCharge);
            return response.Resource.Id;
        }
        catch (CosmosException exception)
        {
            LogCosmosFailure(exception, "Create work order {WorkOrderId}", workOrder.Id);
            throw;
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Unexpected failure creating work order {WorkOrderId}", workOrder.Id);
            throw;
        }
    }

    private async Task<IReadOnlyList<T>> ReadQueryAsync<T>(
        Container container,
        QueryDefinition query,
        string operationName,
        CancellationToken cancellationToken)
    {
        var results = new List<T>();
        var totalRequestCharge = 0d;

        try
        {
            using var iterator = container.GetItemQueryIterator<T>(
                query,
                requestOptions: new QueryRequestOptions { MaxItemCount = 100 });

            while (iterator.HasMoreResults)
            {
                var response = await iterator.ReadNextAsync(cancellationToken);
                totalRequestCharge += response.RequestCharge;
                results.AddRange(response);
                LogSlowOperation(operationName, response.Diagnostics, response.RequestCharge);
            }

            logger.LogDebug(
                "{OperationName} returned {ItemCount} items; RU {RequestCharge}",
                operationName,
                results.Count,
                totalRequestCharge);

            return results;
        }
        catch (CosmosException exception)
        {
            LogCosmosFailure(exception, "{OperationName}", operationName);
            throw;
        }
        catch (Exception exception)
        {
            logger.LogError(exception, "Unexpected failure during {OperationName}", operationName);
            throw;
        }
    }

    private void LogCosmosFailure(CosmosException exception, string message, params object?[] args)
    {
        logger.LogError(
            exception,
            $"{message}; status {{StatusCode}}; RU {{RequestCharge}}; retry after {{RetryAfter}}; diagnostics {{Diagnostics}}",
            [.. args, exception.StatusCode, exception.RequestCharge, exception.RetryAfter, exception.Diagnostics?.ToString()]);
    }

    private void LogSlowOperation(string operationName, CosmosDiagnostics diagnostics, double requestCharge)
    {
        var elapsed = diagnostics.GetClientElapsedTime();
        if (elapsed > TimeSpan.FromMilliseconds(100))
        {
            logger.LogWarning(
                "Slow Cosmos operation {OperationName}: {ElapsedMilliseconds} ms; RU {RequestCharge}; diagnostics {Diagnostics}",
                operationName,
                elapsed.TotalMilliseconds,
                requestCharge,
                diagnostics.ToString());
        }
    }

    private static Container GetContainer(
        CosmosClient client,
        CosmosDbOptions options,
        string containerName)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(options.DatabaseName);
        return client.GetContainer(options.DatabaseName, containerName);
    }

    private static string[] NormalizeValues(IEnumerable<string> values)
    {
        return values
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }
}