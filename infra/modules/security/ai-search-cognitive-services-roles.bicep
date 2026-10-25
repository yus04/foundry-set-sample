targetScope = 'resourceGroup'

@description('Foundry account hosting the embedding model')
param aiAccountName string

@description('AI Search system-assigned managed identity principal ID')
param aiSearchPrincipalId string

var roleDefinitionIds = [
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd' // Cognitive Services OpenAI User
  'a97b65f3-24c7-4388-baec-2e87135dc908' // Cognitive Services User
]

resource aiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiAccountName
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for roleDefinitionId in roleDefinitionIds: {
  name: guid(aiAccount.id, aiSearchPrincipalId, roleDefinitionId)
  scope: aiAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
    principalId: aiSearchPrincipalId
    principalType: 'ServicePrincipal'
  }
}]
