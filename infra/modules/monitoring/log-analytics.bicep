// ============================================
// Log Analytics Workspace
// ============================================

@description('Azure region for the workspace')
param location string

@description('Log Analytics workspace name')
param logAnalyticsName string

@description('Tags to apply to resources')
param tags object = {}

@description('Retention period in days')
param retentionInDays int = 30

// ============================================
// Log Analytics Workspace
// ============================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================
// Outputs
// ============================================

output logAnalyticsId string = logAnalytics.id
output logAnalyticsName string = logAnalytics.name
output logAnalyticsWorkspaceId string = logAnalytics.properties.customerId
