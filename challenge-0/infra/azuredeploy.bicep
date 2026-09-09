@description('Azure location where resources should be deployed')
@allowed([
  'swedencentral'
  'francecentral'
  'eastus2'
  'germanywestcentral'
])
param location string = 'swedencentral'

@description('SKU for Azure Cognitive Search service (basic or standard)')
@allowed([
  'basic'
  'standard'
])
param searchServiceSku string = 'standard'

var prefix = 'msagthack'
var suffix = uniqueString(resourceGroup().id, deployment().name)
var virtualNetworkName = '${prefix}-vnet-${suffix}'
var storageAccountName = replace('${prefix}-sa-${suffix}', '-', '')
var logAnalyticsWorkspaceName = '${prefix}-loganalytics-${suffix}'
var searchServiceName = '${prefix}-search-${suffix}'
var containerRegistryName = replace('${prefix}cr${suffix}', '-', '')
var aiFoundryName = '${prefix}-aifoundry-${suffix}'
var aiProjectName = '${prefix}-aiproject-${suffix}'
var applicationInsightsName = '${prefix}-appinsights-${suffix}'
var cosmosDbAccountName = '${prefix}-cosmos-${suffix}'
var containerAppEnvironmentName = '${prefix}-caenv-${suffix}'
var containerAppName = '${prefix}-ca-${suffix}'
var contentSafetyName = '${prefix}-contentsafety-${suffix}'
var apiManagementName = '${prefix}-apim-${suffix}'
var privateLinkScopeName = '${prefix}-ampls-${suffix}'
var cognitiveServicesUserRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'a97b65f3-24c7-4388-baec-2e87135dc908'
)
var searchServiceContributorRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
)
var searchIndexDataReaderRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '1407120a-92aa-4202-b7e9-c0e197c71c8f'
)
var monitoringMetricsPublisherRoleId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '3913510d-42f4-4e42-8a64-420c390055eb'
)
var cosmosDbDataContributorRoleId = '00000000-0000-0000-0000-000000000002'

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    name: virtualNetworkName
    location: location
  }
}

module privateDns 'modules/private-dns.bicep' = {
  name: 'private-dns'
  params: {
    virtualNetworkId: network.outputs.id
  }
}

module apiManagement 'modules/api-management.bicep' = {
  name: 'api-management'
  params: {
    name: apiManagementName
    location: location
    subnetId: network.outputs.apiManagementSubnetId
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    name: storageAccountName
    location: location
  }
}

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    applicationInsightsName: applicationInsightsName
    location: location
    privateLinkScopeName: privateLinkScopeName
  }
}

module cosmosDb 'modules/cosmos-db.bicep' = {
  name: 'cosmos-db'
  params: {
    name: cosmosDbAccountName
    location: location
    apiManagementId: apiManagement.outputs.id
    apiManagementPrincipalId: apiManagement.outputs.principalId
    cosmosDbDataContributorRoleId: cosmosDbDataContributorRoleId
  }
}

module aiSearch 'modules/ai-search.bicep' = {
  name: 'ai-search'
  params: {
    name: searchServiceName
    location: location
    skuName: searchServiceSku
  }
}

module containerRegistry 'modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    name: containerRegistryName
    location: location
  }
}

module contentSafety 'modules/content-safety.bicep' = {
  name: 'content-safety'
  params: {
    name: contentSafetyName
    location: location
  }
}

module foundry 'modules/foundry.bicep' = {
  name: 'foundry'
  params: {
    name: aiFoundryName
    projectName: aiProjectName
    location: location
    agentSubnetId: network.outputs.foundrySubnetId
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    applicationInsightsId: monitoring.outputs.applicationInsightsId
    monitoringMetricsPublisherRoleId: monitoringMetricsPublisherRoleId
    searchServiceName: aiSearch.outputs.name
    searchServicePrincipalId: aiSearch.outputs.principalId
    cognitiveServicesUserRoleId: cognitiveServicesUserRoleId
    searchServiceContributorRoleId: searchServiceContributorRoleId
    searchIndexDataReaderRoleId: searchIndexDataReaderRoleId
  }
}

module containerApps 'modules/container-apps.bicep' = {
  name: 'container-apps'
  params: {
    environmentName: containerAppEnvironmentName
    appName: containerAppName
    location: location
    infrastructureSubnetId: network.outputs.containerAppsSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
  dependsOn: [
    containerRegistry
    cosmosDb
    foundry
    aiSearch
    contentSafety
  ]
}

module storagePrivateEndpoint 'modules/private-endpoint.bicep' = {
  name: 'storage-private-endpoint'
  params: {
    name: '${storageAccountName}-blob-pe'
    location: location
    subnetId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: storage.outputs.id
    groupIds: [
      'blob'
    ]
    privateDnsZoneIds: [
      privateDns.outputs.zoneIds.storageBlob
    ]
  }
}

module cosmosPrivateEndpoint 'modules/private-endpoint.bicep' = {
  name: 'cosmos-private-endpoint'
  params: {
    name: '${cosmosDbAccountName}-sql-pe'
    location: location
    subnetId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: cosmosDb.outputs.id
    groupIds: [
      'Sql'
    ]
    privateDnsZoneIds: [
      privateDns.outputs.zoneIds.cosmosSql
    ]
  }
}

module searchPrivateEndpoint 'modules/private-endpoint.bicep' = {
  name: 'search-private-endpoint'
  params: {
    name: '${searchServiceName}-pe'
    location: location
    subnetId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: aiSearch.outputs.id
    groupIds: [
      'searchService'
    ]
    privateDnsZoneIds: [
      privateDns.outputs.zoneIds.search
    ]
  }
}

module registryPrivateEndpoint 'modules/private-endpoint.bicep' = {
  name: 'registry-private-endpoint'
  params: {
    name: '${containerRegistryName}-pe'
    location: location
    subnetId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: containerRegistry.outputs.id
    groupIds: [
      'registry'
    ]
    privateDnsZoneIds: [
      privateDns.outputs.zoneIds.containerRegistry
    ]
  }
}

module contentSafetyPrivateEndpoint 'modules/private-endpoint.bicep' = {
  name: 'content-safety-private-endpoint'
  params: {
    name: '${contentSafetyName}-pe'
    location: location
    subnetId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: contentSafety.outputs.id
    groupIds: [
      'account'
    ]
    privateDnsZoneIds: [
      privateDns.outputs.zoneIds.cognitiveServices
    ]
  }
}

module foundryPrivateEndpoint 'modules/private-endpoint.bicep' = {
  name: 'foundry-private-endpoint'
  params: {
    name: '${aiFoundryName}-pe'
    location: location
    subnetId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: foundry.outputs.id
    groupIds: [
      'account'
    ]
    privateDnsZoneIds: [
      privateDns.outputs.zoneIds.cognitiveServices
      privateDns.outputs.zoneIds.openAi
      privateDns.outputs.zoneIds.aiServices
    ]
  }
}

module monitorPrivateEndpoint 'modules/private-endpoint.bicep' = {
  name: 'monitor-private-endpoint'
  params: {
    name: '${privateLinkScopeName}-pe'
    location: location
    subnetId: network.outputs.privateEndpointSubnetId
    privateLinkServiceId: monitoring.outputs.privateLinkScopeId
    groupIds: [
      'azuremonitor'
    ]
    privateDnsZoneIds: [
      privateDns.outputs.zoneIds.monitor
      privateDns.outputs.zoneIds.monitorOms
      privateDns.outputs.zoneIds.monitorOds
      privateDns.outputs.zoneIds.monitorAgent
      privateDns.outputs.zoneIds.storageBlob
    ]
  }
}

output storageAccountName string = storage.outputs.name
output logAnalyticsWorkspaceName string = monitoring.outputs.logAnalyticsWorkspaceName
output searchServiceName string = aiSearch.outputs.name
output aiFoundryHubName string = foundry.outputs.name
output aiFoundryProjectName string = foundry.outputs.projectName
output containerRegistryName string = containerRegistry.outputs.name
output acrName string = containerRegistry.outputs.name
output applicationInsightsName string = monitoring.outputs.applicationInsightsName
output searchServiceEndpoint string = aiSearch.outputs.endpoint
output aiFoundryHubEndpoint string = foundry.outputs.hubEndpoint
output aiFoundryProjectEndpoint string = foundry.outputs.projectEndpoint
output cosmosDbAccountName string = cosmosDb.outputs.name
output cosmosDbEndpoint string = cosmosDb.outputs.endpoint
output containerAppEnvironmentName string = containerApps.outputs.environmentName
output containerAppName string = containerApps.outputs.appName
output containerAppUrl string = containerApps.outputs.url
output contentSafetyName string = contentSafety.outputs.name
output contentSafetyEndpoint string = contentSafety.outputs.endpoint
output apiManagementName string = apiManagementName
