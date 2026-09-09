targetScope = 'subscription'

@description('Name of the azd environment, used to create stable deployment names.')
param environmentName string

@description('Azure location where resources should be deployed.')
param location string

@description('Resource group that contains the workshop resources.')
param resourceGroupName string = 'rg-tire-factory-hack-${environmentName}'

@description('SKU for Azure AI Search.')
@allowed([
  'basic'
  'standard'
])
param searchServiceSku string = 'standard'

resource workshopResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
}

module infrastructure './azuredeploy.bicep' = {
  name: 'infrastructure-${environmentName}'
  scope: workshopResourceGroup
  params: {
    location: location
    searchServiceSku: searchServiceSku
  }
}

output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP string = workshopResourceGroup.name
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_STORAGE_ACCOUNT_NAME string = infrastructure.outputs.storageAccountName
output LOG_ANALYTICS_WORKSPACE_NAME string = infrastructure.outputs.logAnalyticsWorkspaceName
output SEARCH_SERVICE_NAME string = infrastructure.outputs.searchServiceName
output SEARCH_SERVICE_ENDPOINT string = infrastructure.outputs.searchServiceEndpoint
output AI_FOUNDRY_HUB_NAME string = infrastructure.outputs.aiFoundryHubName
output AI_FOUNDRY_PROJECT_NAME string = infrastructure.outputs.aiFoundryProjectName
output AI_FOUNDRY_HUB_ENDPOINT string = infrastructure.outputs.aiFoundryHubEndpoint
output AI_FOUNDRY_PROJECT_ENDPOINT string = infrastructure.outputs.aiFoundryProjectEndpoint
output COSMOS_NAME string = infrastructure.outputs.cosmosDbAccountName
output COSMOS_ENDPOINT string = infrastructure.outputs.cosmosDbEndpoint
output ACR_NAME string = infrastructure.outputs.containerRegistryName
output CONTAINER_APP_ENVIRONMENT_NAME string = infrastructure.outputs.containerAppEnvironmentName
output CONTAINER_APP_NAME string = infrastructure.outputs.containerAppName
output CONTAINER_APP_URL string = infrastructure.outputs.containerAppUrl
output APPLICATION_INSIGHTS_NAME string = infrastructure.outputs.applicationInsightsName
output CONTENT_SAFETY_NAME string = infrastructure.outputs.contentSafetyName
output CONTENT_SAFETY_ENDPOINT string = infrastructure.outputs.contentSafetyEndpoint
