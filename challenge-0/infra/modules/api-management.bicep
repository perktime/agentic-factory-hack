param name string
param location string
param subnetId string
param searchServiceName string

resource apiManagement 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'StandardV2'
    capacity: 1
  }
  properties: {
    publisherEmail: 'admin@contoso.com'
    publisherName: 'Contoso'
    virtualNetworkType: 'External'
    virtualNetworkConfiguration: {
      subnetResourceId: subnetId
    }
  }
}

resource machineWikiMcpApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apiManagement
  name: 'machine-wiki-mcp'
  properties: {
    displayName: 'Machine Wiki MCP'
    path: 'machine-wiki'
    protocols: [
      'https'
    ]
    serviceUrl: 'https://${searchServiceName}.search.windows.net/knowledgebases/machine-kb'
    subscriptionRequired: false
  }
}

resource machineWikiMcpOperation 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  parent: machineWikiMcpApi
  name: 'mcp-post'
  properties: {
    displayName: 'MCP POST'
    method: 'POST'
    urlTemplate: '/mcp'
  }
}

output id string = apiManagement.id
output principalId string = apiManagement.identity.principalId
