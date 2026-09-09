param name string
param projectName string
param location string
param agentSubnetId string
param applicationInsightsName string
param applicationInsightsId string
param monitoringMetricsPublisherRoleId string
param searchServiceName string
param searchServicePrincipalId string
param cognitiveServicesUserRoleId string
param searchServiceContributorRoleId string
param searchIndexDataReaderRoleId string

resource searchService 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: searchServiceName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  properties: {
    allowProjectManagement: true
    customSubDomainName: name
    disableLocalAuth: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    networkInjections: [
      {
        scenario: 'agent'
        subnetArmId: agentSubnetId
        useMicrosoftManagedNetwork: false
      }
    ]
  }
}

resource aiProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: aiFoundry
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

resource applicationInsightsConnection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-04-01-preview' = {
  parent: aiProject
  name: applicationInsightsName
  properties: {
    #disable-next-line BCP036
    authType: 'ProjectManagedIdentity'
    category: 'AppInsights'
    target: applicationInsightsId
    useWorkspaceManagedIdentity: true
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ApplicationInsightsConnectionString: applicationInsights.properties.ConnectionString
      ResourceId: applicationInsightsId
    }
  }
  dependsOn: [
    projectMonitoringMetricsPublisher
  ]
}

resource gpt54Mini 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: aiFoundry
  name: 'gpt-5.4-mini'
  sku: {
    capacity: 50
    name: 'GlobalStandard'
  }
  properties: {
    model: {
      name: 'gpt-5.4-mini'
      format: 'OpenAI'
      version: '2026-03-17'
    }
  }
}

resource gpt54 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: aiFoundry
  name: 'gpt-5.4'
  sku: {
    capacity: 50
    name: 'GlobalStandard'
  }
  properties: {
    model: {
      name: 'gpt-5.4'
      format: 'OpenAI'
      version: '2026-03-05'
    }
  }
  dependsOn: [
    gpt54Mini
  ]
}

resource textEmbedding3Large 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview' = {
  parent: aiFoundry
  name: 'text-embedding-3-large'
  sku: {
    capacity: 10
    name: 'Standard'
  }
  properties: {
    model: {
      name: 'text-embedding-3-large'
      format: 'OpenAI'
      version: '1'
    }
  }
  dependsOn: [
    gpt54
  ]
}

resource searchCognitiveServicesUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiFoundry
  name: guid(searchService.id, aiFoundry.id, cognitiveServicesUserRoleId, 'search-to-cognitive')
  properties: {
    roleDefinitionId: cognitiveServicesUserRoleId
    principalId: searchServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource foundrySearchContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, aiFoundry.id, searchServiceContributorRoleId)
  properties: {
    roleDefinitionId: searchServiceContributorRoleId
    principalId: aiFoundry.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource projectSearchContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, aiProject.id, searchServiceContributorRoleId)
  properties: {
    roleDefinitionId: searchServiceContributorRoleId
    principalId: aiProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource projectSearchIndexDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: searchService
  name: guid(searchService.id, aiProject.id, searchIndexDataReaderRoleId)
  properties: {
    roleDefinitionId: searchIndexDataReaderRoleId
    principalId: aiProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource foundryMonitoringMetricsPublisher 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: applicationInsights
  name: guid(applicationInsights.id, aiFoundry.id, monitoringMetricsPublisherRoleId)
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRoleId
    principalId: aiFoundry.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource projectMonitoringMetricsPublisher 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: applicationInsights
  name: guid(applicationInsights.id, aiProject.id, monitoringMetricsPublisherRoleId)
  properties: {
    roleDefinitionId: monitoringMetricsPublisherRoleId
    principalId: aiProject.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource searchConnection 'Microsoft.CognitiveServices/accounts/connections@2025-04-01-preview' = {
  parent: aiFoundry
  name: '${name}-aisearch'
  properties: {
    category: 'CognitiveSearch'
    target: 'https://${searchService.name}.search.windows.net'
    authType: 'AAD'
    isSharedToAll: true
    useWorkspaceManagedIdentity: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: searchService.id
      location: location
    }
  }
}

output name string = aiFoundry.name
output id string = aiFoundry.id
output projectName string = aiProject.name
output projectId string = aiProject.id
output hubEndpoint string = 'https://ml.azure.com/home?wsid=${aiFoundry.id}'
output projectEndpoint string = 'https://ai.azure.com/build/overview?wsid=${aiProject.id}'
