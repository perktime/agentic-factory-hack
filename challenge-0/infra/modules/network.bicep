param name string
param location string
param addressPrefix string = '10.20.0.0/16'
param foundrySubnetPrefix string = '10.20.0.0/24'
param containerAppsSubnetPrefix string = '10.20.1.0/24'
param apiManagementSubnetPrefix string = '10.20.2.0/24'
param privateEndpointSubnetPrefix string = '10.20.3.0/24'

resource apiManagementNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: '${name}-apim-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowAzureKeyVaultOutbound'
        properties: {
          access: 'Allow'
          direction: 'Outbound'
          priority: 100
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureKeyVault'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-foundry-agent'
        properties: {
          addressPrefix: foundrySubnetPrefix
          delegations: [
            {
              name: 'foundry-agent-delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'snet-container-apps'
        properties: {
          addressPrefix: containerAppsSubnetPrefix
          delegations: [
            {
              name: 'container-apps-delegation'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'snet-api-management'
        properties: {
          addressPrefix: apiManagementSubnetPrefix
          delegations: [
            {
              name: 'api-management-delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          networkSecurityGroup: {
            id: apiManagementNsg.id
          }
        }
      }
      {
        name: 'snet-private-endpoints'
        properties: {
          addressPrefix: privateEndpointSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

output id string = virtualNetwork.id
output name string = virtualNetwork.name
output foundrySubnetId string = '${virtualNetwork.id}/subnets/snet-foundry-agent'
output containerAppsSubnetId string = '${virtualNetwork.id}/subnets/snet-container-apps'
output apiManagementSubnetId string = '${virtualNetwork.id}/subnets/snet-api-management'
output privateEndpointSubnetId string = '${virtualNetwork.id}/subnets/snet-private-endpoints'
