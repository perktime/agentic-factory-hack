param logAnalyticsWorkspaceName string
param applicationInsightsName string
param location string
param privateLinkScopeName string

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    DisableLocalAuth: true
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Disabled'
  }
}

resource privateLinkScope 'Microsoft.Insights/privateLinkScopes@2023-06-01-preview' = {
  name: privateLinkScopeName
  location: 'global'
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'PrivateOnly'
      queryAccessMode: 'PrivateOnly'
    }
  }
}

resource scopedApplicationInsights 'Microsoft.Insights/privateLinkScopes/scopedResources@2023-06-01-preview' = {
  parent: privateLinkScope
  name: 'application-insights'
  properties: {
    kind: 'resource'
    linkedResourceId: applicationInsights.id
  }
}

resource scopedLogAnalytics 'Microsoft.Insights/privateLinkScopes/scopedResources@2023-06-01-preview' = {
  parent: privateLinkScope
  name: 'log-analytics'
  properties: {
    kind: 'resource'
    linkedResourceId: logAnalyticsWorkspace.id
  }
}

output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output applicationInsightsName string = applicationInsights.name
output applicationInsightsId string = applicationInsights.id
output privateLinkScopeId string = privateLinkScope.id
