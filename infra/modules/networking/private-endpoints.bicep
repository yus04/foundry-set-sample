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

// Standard private endpoint configs (1 PE → 1 DNS zone)
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
    dnsZoneName: 'privatelink.documents.azure.com'
    groupId: 'Sql'
    resourceId: cosmosDbAccountId
    resourceName: cosmosDbAccountName
  }
]

// AI Account requires multiple DNS zones for a single private endpoint
var aiAccountDnsZoneNames = [
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.services.ai.azure.com'
]

// ============================================
// Private DNS Zones (Standard)
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
// Private DNS Zones (AI Account - multi-zone)
// ============================================

resource aiAccountDnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' = [for zone in aiAccountDnsZoneNames: {
  name: zone
  location: 'global'
  tags: tags
}]

resource aiAccountVnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (zone, i) in aiAccountDnsZoneNames: {
  parent: aiAccountDnsZones[i]
  name: '${replace(zone, '.', '-')}-link'
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
// Private Endpoints (Standard)
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

// ============================================
// Private Endpoint (AI Account - multi-zone DNS)
// ============================================

resource aiAccountPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${aiAccountName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${aiAccountName}-plsc'
        properties: {
          privateLinkServiceId: aiAccountId
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

resource aiAccountDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: aiAccountPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [for (zone, i) in aiAccountDnsZoneNames: {
      name: replace(zone, '.', '-')
      properties: {
        privateDnsZoneId: aiAccountDnsZones[i].id
      }
    }]
  }
}

// ============================================
// Outputs
// ============================================

@description('Blob Private DNS Zone resource ID (shared with AMPLS)')
output blobDnsZoneId string = privateDnsZones[0].id
