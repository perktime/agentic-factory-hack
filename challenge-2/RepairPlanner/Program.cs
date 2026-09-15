using System.Text.Json;
using Azure.AI.Projects;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using RepairPlanner;
using RepairPlanner.Models;
using RepairPlanner.Services;

var projectEndpoint = GetRequiredEnvironmentVariable("AZURE_AI_PROJECT_ENDPOINT");
var modelDeploymentName = GetRequiredEnvironmentVariable("MODEL_DEPLOYMENT_NAME");
var cosmosEndpoint = GetRequiredEnvironmentVariable("COSMOS_ENDPOINT");
var cosmosDatabaseName = GetRequiredEnvironmentVariable("COSMOS_DATABASE_NAME");

var services = new ServiceCollection();

services.AddLogging(builder =>
{
	builder.AddSimpleConsole(options =>
	{
		options.SingleLine = true;
		options.TimestampFormat = "HH:mm:ss ";
	});
	builder.SetMinimumLevel(LogLevel.Information);
});

services.AddSingleton(new DefaultAzureCredential());
services.AddSingleton(serviceProvider =>
	new AIProjectClient(
		new Uri(projectEndpoint),
		serviceProvider.GetRequiredService<DefaultAzureCredential>()));
services.AddSingleton(serviceProvider =>
	new CosmosClient(
		cosmosEndpoint,
		serviceProvider.GetRequiredService<DefaultAzureCredential>(),
		new CosmosClientOptions
		{
			ApplicationName = "RepairPlanner",
			ConnectionMode = ConnectionMode.Direct
		}));
services.AddSingleton(new CosmosDbOptions { DatabaseName = cosmosDatabaseName });
services.AddSingleton<IFaultMappingService, FaultMappingService>();
services.AddSingleton<CosmosDbService>();
services.AddSingleton(serviceProvider =>
	new RepairPlannerAgent(
		serviceProvider.GetRequiredService<AIProjectClient>(),
		serviceProvider.GetRequiredService<CosmosDbService>(),
		serviceProvider.GetRequiredService<IFaultMappingService>(),
		modelDeploymentName,
		serviceProvider.GetRequiredService<ILogger<RepairPlannerAgent>>()));

// await using is like Python's "async with" and disposes singleton clients during shutdown.
await using var provider = services.BuildServiceProvider();
var logger = provider.GetRequiredService<ILoggerFactory>().CreateLogger("Program");

var sampleFault = new DiagnosedFault
{
	MachineId = "machine-001",
	FaultType = "curing_temperature_excessive",
	RootCause = "Temperature sensor drift or a failing mold heating element",
	Severity = "High",
	DetectedAt = DateTimeOffset.UtcNow,
	Metadata = new Dictionary<string, object?>
	{
		["MostLikelyRootCauses"] = new[]
		{
			"Temperature sensor drift",
			"Heating element malfunction"
		}
	}
};

try
{
	var repairPlanner = provider.GetRequiredService<RepairPlannerAgent>();

	logger.LogInformation("Registering the Repair Planner Agent");
	await repairPlanner.EnsureAgentVersionAsync();

	logger.LogInformation(
		"Planning a repair for {FaultType} on {MachineId}",
		sampleFault.FaultType,
		sampleFault.MachineId);

	var workOrder = await repairPlanner.PlanAndCreateWorkOrderAsync(sampleFault);

	logger.LogInformation(
		"Saved work order {WorkOrderNumber} (id={WorkOrderId}, status={Status}, assignedTo={AssignedTo})",
		workOrder.WorkOrderNumber,
		workOrder.Id,
		workOrder.Status,
		workOrder.AssignedTo ?? "unassigned");

	Console.WriteLine(JsonSerializer.Serialize(
		workOrder,
		new JsonSerializerOptions { WriteIndented = true }));
}
catch (Exception exception)
{
	logger.LogCritical(exception, "Repair planning failed");
	return 1;
}

return 0;

static string GetRequiredEnvironmentVariable(string name)
{
	// ?? means "if null, use this instead", similar to Python's "or" for absent values.
	return Environment.GetEnvironmentVariable(name)
		?? throw new InvalidOperationException($"Required environment variable '{name}' is not set.");
}
