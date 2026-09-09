param virtualNetworkId string

var zoneNames = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
  'privatelink.search.windows.net'
  'privatelink.documents.azure.com'
  'privatelink.blob.${environment().suffixes.storage}'
  'privatelink.azurecr.io'
  'privatelink.monitor.azure.com'
  'privatelink.oms.opinsights.azure.com'
  'privatelink.ods.opinsights.azure.com'
  'privatelink.agentsvc.azure-automation.net'
]

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' = [for zoneName in zoneNames: {
  name: zoneName
  location: 'global'
}]

resource virtualNetworkLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (zoneName, index) in zoneNames: {
  parent: privateDnsZones[index]
  name: 'vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}]

output zoneIds object = {
  cognitiveServices: privateDnsZones[0].id
  openAi: privateDnsZones[1].id
  aiServices: privateDnsZones[2].id
  search: privateDnsZones[3].id
  cosmosSql: privateDnsZones[4].id
  storageBlob: privateDnsZones[5].id
  containerRegistry: privateDnsZones[6].id
  monitor: privateDnsZones[7].id
  monitorOms: privateDnsZones[8].id
  monitorOds: privateDnsZones[9].id
  monitorAgent: privateDnsZones[10].id
}
