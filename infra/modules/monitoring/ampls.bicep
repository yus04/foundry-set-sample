// ============================================
// Azure Monitor Private Link Scope (AMPLS)
// - Phase 1: AMPLS resource + Scoped Resources only
// - PE is created in a separate module to avoid
//   RequiredMembers race condition
// ============================================

@description('AMPLS resource name')
param amplsName string

@description('Tags to apply to resources')
param tags object = {}

@description('Log Analytics workspace resource ID')
param logAnalyticsId string

@description('Log Analytics workspace name')
param logAnalyticsName string

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
// Outputs
// ============================================

output amplsId string = ampls.id
output amplsName string = ampls.name
