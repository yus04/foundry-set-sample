// ============================================
// Private Endpoints and DNS Zones
// ============================================

@description('Azure region for private endpoints')
param location string

@description('Tags to apply to resources')
param tags object = {}

@description('VNet resource ID for DNS zone linking')
param vnetId string

@description('Subnet resource ID for private endpoints')
param subnetId string

// Resource IDs for private endpoint targets
@description('Storage Account resource ID')
param storageAccountId string

@description('AI Search service resource ID')
param aiSearchId string

@description('AI Services account resource ID')
param aiAccountId string

@description('Cosmos DB account resource ID')
param cosmosDbAccountId string

// Resource names for private endpoint naming
@description('Storage Account name')
param storageAccountName string

@description('AI Search service name')
param aiSearchName string

@description('AI Services account name')
param aiAccountName string

@description('Cosmos DB account name')
param cosmosDbAccountName string

// ============================================
// Private Endpoint Configurations
// ============================================

var storageSuffix = environment().suffixes.storage

var privateEndpointConfigs = [
  {
    dnsZoneName: 'privatelink.blob.${storageSuffix}'
    groupId: 'blob'
    resourceId: storageAccountId
    resourceName: storageAccountName
  }
  {
    dnsZoneName: 'privatelink.search.windows.net'
    groupId: 'searchService'
    resourceId: aiSearchId
    resourceName: aiSearchName
  }
  {
    dnsZoneName: 'privatelink.cognitiveservices.azure.com'
    groupId: 'account'
    resourceId: aiAccountId
    resourceName: aiAccountName
  }
  {
    dnsZoneName: 'privatelink.documents.azure.com'
    groupId: 'Sql'
    resourceId: cosmosDbAccountId
    resourceName: cosmosDbAccountName
  }
]

// ============================================
// Private DNS Zones
// ============================================

resource privateDnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' = [for config in privateEndpointConfigs: {
  name: config.dnsZoneName
  location: 'global'
  tags: tags
}]

resource vnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (config, i) in privateEndpointConfigs: {
  parent: privateDnsZones[i]
  name: '${replace(config.dnsZoneName, '.', '-')}-link'
  location: 'global'
  tags: tags
  properties: {
    virtualNetwork: {
      id: vnetId
    }
    registrationEnabled: false
  }
}]

// ============================================
// Private Endpoints
// ============================================

resource privateEndpoints 'Microsoft.Network/privateEndpoints@2024-05-01' = [for (config, i) in privateEndpointConfigs: {
  name: '${config.resourceName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${config.resourceName}-plsc'
        properties: {
          privateLinkServiceId: config.resourceId
          groupIds: [
            config.groupId
          ]
        }
      }
    ]
  }
}]

resource dnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = [for (config, i) in privateEndpointConfigs: {
  parent: privateEndpoints[i]
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: replace(config.dnsZoneName, '.', '-')
        properties: {
          privateDnsZoneId: privateDnsZones[i].id
        }
      }
    ]
  }
}]
