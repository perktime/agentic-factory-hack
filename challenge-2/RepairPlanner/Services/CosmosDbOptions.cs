namespace RepairPlanner.Services;

public sealed class CosmosDbOptions
{
    public const string TechniciansContainerName = "Technicians";
    public const string PartsContainerName = "PartsInventory";
    public const string WorkOrdersContainerName = "WorkOrders";

    public string DatabaseName { get; init; } = string.Empty;
}