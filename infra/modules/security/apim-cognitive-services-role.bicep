// ============================================
// APIM Cognitive Services Role Assignment
// ============================================

@description('AI Services account name')
param aiAccountName string

@description('APIM managed identity principal ID')
param apimPrincipalId string

// Cognitive Services OpenAI User role
var cognitiveServicesOpenAIUserRoleId = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource aiAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: aiAccountName
}

resource apimCognitiveServicesRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiAccount.id, apimPrincipalId, cognitiveServicesOpenAIUserRoleId)
  scope: aiAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', cognitiveServicesOpenAIUserRoleId)
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}
