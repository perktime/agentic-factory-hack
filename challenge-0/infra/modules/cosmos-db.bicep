param name string
param location string
param apiManagementId string
param apiManagementPrincipalId string
param cosmosDbDataContributorRoleId string

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: name
  location: location
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource apiManagementDataContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-05-01-preview' = {
  parent: cosmosDbAccount
  name: guid(apiManagementId, cosmosDbAccount.id, cosmosDbDataContributorRoleId)
  properties: {
    roleDefinitionId: resourceId(
      'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions',
      cosmosDbAccount.name,
      cosmosDbDataContributorRoleId
    )
    principalId: apiManagementPrincipalId
    scope: cosmosDbAccount.id
  }
}

output name string = cosmosDbAccount.name
output id string = cosmosDbAccount.id
output endpoint string = cosmosDbAccount.properties.documentEndpoint
