// ============================================
// AMPLS Private Endpoint + DNS Zones
// - Phase 2: Deployed as a SEPARATE module from
//   AMPLS to guarantee Scoped Resources are fully
//   provisioned before PE creation.
// ============================================

@description('Azure region for the private endpoint')
param location string

@description('AMPLS resource name')
param amplsName string

@description('Tags to apply to resources')
param tags object = {}

@description('AMPLS resource ID')
param amplsId string

@description('VNet resource ID for DNS zone linking')
param vnetId string

@description('Subnet resource ID for private endpoint')
param subnetId string

@description('Blob Private DNS Zone resource ID (shared with private-endpoints module)')
param blobDnsZoneId string

// ============================================
// DNS Zones for Azure Monitor
// ============================================

var amplsDnsZoneNames = [
  'privatelink.monitor.azure.com'
  'privatelink.oms.opinsights.azure.com'
  'privatelink.ods.opinsights.azure.com'
  'privatelink.agentsvc.azure-automation.net'
]

resource amplsDnsZones 'Microsoft.Network/privateDnsZones@2024-06-01' = [for zoneName in amplsDnsZoneNames: {
  name: zoneName
  location: 'global'
  tags: tags
}]

resource amplsVnetLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [for (zoneName, i) in amplsDnsZoneNames: {
  parent: amplsDnsZones[i]
  name: '${replace(zoneName, '.', '-')}-link'
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
// AMPLS Private Endpoint
// ============================================

resource amplsPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: '${amplsName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${amplsName}-plsc'
        properties: {
          privateLinkServiceId: amplsId
          groupIds: [
            'azuremonitor'
          ]
        }
      }
    ]
  }
}

// ============================================
// DNS Zone Group
// ============================================

resource amplsDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: amplsPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-monitor-azure-com'
        properties: {
          privateDnsZoneId: amplsDnsZones[0].id
        }
      }
      {
        name: 'privatelink-oms-opinsights-azure-com'
        properties: {
          privateDnsZoneId: amplsDnsZones[1].id
        }
      }
      {
        name: 'privatelink-ods-opinsights-azure-com'
        properties: {
          privateDnsZoneId: amplsDnsZones[2].id
        }
      }
      {
        name: 'privatelink-agentsvc-azure-automation-net'
        properties: {
          privateDnsZoneId: amplsDnsZones[3].id
        }
      }
      {
        name: 'privatelink-blob'
        properties: {
          privateDnsZoneId: blobDnsZoneId
        }
      }
    ]
  }
}
