// ============================================
// Azure Monitor Private Link Scope (AMPLS)
// ============================================

@description('Azure region for the private endpoint')
param location string

@description('AMPLS resource name')
param amplsName string

@description('Tags to apply to resources')
param tags object = {}

@description('Log Analytics workspace resource ID')
param logAnalyticsId string

@description('Log Analytics workspace name')
param logAnalyticsName string

@description('VNet resource ID for DNS zone linking')
param vnetId string

@description('Subnet resource ID for private endpoint')
param subnetId string

@description('Blob Private DNS Zone resource ID (shared with private-endpoints module)')
param blobDnsZoneId string

// ============================================
// AMPLS Resource
// ============================================

resource ampls 'microsoft.insights/privateLinkScopes@2021-07-01-preview' = {
  name: amplsName
  location: 'global'
  tags: tags
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'PrivateOnly'
      queryAccessMode: 'Open'
    }
  }
}

resource amplsScopedResource 'microsoft.insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  parent: ampls
  name: '${logAnalyticsName}-scoped'
  properties: {
    linkedResourceId: logAnalyticsId
  }
}

// ============================================
// AMPLS DNS Zones
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
          privateLinkServiceId: ampls.id
          groupIds: [
            'azuremonitor'
          ]
        }
      }
    ]
  }
}

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

// ============================================
// Outputs
// ============================================

output amplsId string = ampls.id
output amplsName string = ampls.name
