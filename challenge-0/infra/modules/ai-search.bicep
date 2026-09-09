param name string
param location string
param skuName string

resource searchService 'Microsoft.Search/searchServices@2023-11-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: skuName
  }
  properties: {
    hostingMode: 'default'
    replicaCount: 1
    partitionCount: 1
    publicNetworkAccess: 'disabled'
    disableLocalAuth: true
  }
}

output name string = searchService.name
output id string = searchService.id
output principalId string = searchService.identity.principalId
output endpoint string = 'https://${searchService.name}.search.windows.net/'
