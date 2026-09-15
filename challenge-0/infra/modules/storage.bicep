param name string
param location string
param searchServicePrincipalId string
param storageBlobDataReaderRoleId string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

resource searchBlobDataReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, searchServicePrincipalId, storageBlobDataReaderRoleId)
  properties: {
    roleDefinitionId: storageBlobDataReaderRoleId
    principalId: searchServicePrincipalId
    principalType: 'ServicePrincipal'
  }
}

output name string = storageAccount.name
output id string = storageAccount.id
