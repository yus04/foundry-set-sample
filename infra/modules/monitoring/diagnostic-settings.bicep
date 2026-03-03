// ============================================
// Diagnostic Settings for Foundry AI Account
// ============================================

@description('AI Services account name')
param aiAccountName string

@description('Log Analytics workspace resource ID')
param logAnalyticsId string

// ============================================
// Existing AI Account Reference
// ============================================

resource aiAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: aiAccountName
}

// ============================================
// Diagnostic Settings
// ============================================

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${aiAccountName}-diag'
  scope: aiAccount
  properties: {
    workspaceId: logAnalyticsId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
