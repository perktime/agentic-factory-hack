param name string
param location string
param environmentId string
param repositoryUrl string
param repositoryRef string
param cosmosDbAccountName string
param cosmosDbEndpoint string
param cosmosDbDataContributorRoleId string
param storageAccountName string
param storageBlobDataContributorRoleId string
param apiManagementName string
param apiManagementServiceContributorRoleId string

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' existing = {
  name: cosmosDbAccountName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource apiManagement 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apiManagementName
}

resource seedJob 'Microsoft.App/jobs@2025-01-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: environmentId
    configuration: {
      triggerType: 'Manual'
      replicaTimeout: 1800
      replicaRetryLimit: 2
      manualTriggerConfig: {
        replicaCompletionCount: 1
        parallelism: 1
      }
      identitySettings: [
        {
          identity: 'system'
          lifecycle: 'All'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'seed-data'
          image: 'mcr.microsoft.com/devcontainers/python:3.13-bookworm'
          command: [
            '/bin/bash'
          ]
          args: [
            '-lc'
            'rm -rf /tmp/agentic-factory-hack && git clone --depth 1 --branch "$SEED_REPOSITORY_REF" --filter=blob:none --sparse "$SEED_REPOSITORY_URL" /tmp/agentic-factory-hack && git -C /tmp/agentic-factory-hack sparse-checkout set challenge-0 && cd /tmp/agentic-factory-hack/challenge-0 && ./seed-data.sh'
          ]
          env: [
            {
              name: 'SEED_REPOSITORY_URL'
              value: repositoryUrl
            }
            {
              name: 'SEED_REPOSITORY_REF'
              value: repositoryRef
            }
            {
              name: 'AZURE_SUBSCRIPTION_ID'
              value: subscription().subscriptionId
            }
            {
              name: 'AZURE_RESOURCE_GROUP'
              value: resourceGroup().name
            }
            {
              name: 'APIM_NAME'
              value: apiManagementName
            }
            {
              name: 'COSMOS_ENDPOINT'
              value: cosmosDbEndpoint
            }
            {
              name: 'AZURE_STORAGE_ACCOUNT_NAME'
              value: storageAccountName
            }
            {
              name: 'PIP_INDEX_URL'
              value: 'https://packagefeedproxy.microsoft.io/pypi/simple'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
    }
  }
}

resource seedCosmosDataContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2025-05-01-preview' = {
  parent: cosmosDbAccount
  name: guid(seedJob.id, cosmosDbAccount.id, cosmosDbDataContributorRoleId)
  properties: {
    roleDefinitionId: resourceId(
      'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions',
      cosmosDbAccount.name,
      cosmosDbDataContributorRoleId
    )
    principalId: seedJob.identity.principalId
    scope: cosmosDbAccount.id
  }
}

resource seedStorageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(seedJob.id, storageAccount.id, storageBlobDataContributorRoleId)
  scope: storageAccount
  properties: {
    roleDefinitionId: storageBlobDataContributorRoleId
    principalId: seedJob.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource seedApiManagementServiceContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(seedJob.id, apiManagement.id, apiManagementServiceContributorRoleId)
  scope: apiManagement
  properties: {
    roleDefinitionId: apiManagementServiceContributorRoleId
    principalId: seedJob.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output name string = seedJob.name
output principalId string = seedJob.identity.principalId