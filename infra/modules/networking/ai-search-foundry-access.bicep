targetScope = 'resourceGroup'

@description('Foundry account hosting the embedding model')
param aiAccountName string

@description('AI Search service name')
param aiSearchName string

@description('Resource group containing the AI Search service')
param aiSearchResourceGroupName string

@description('Subscription containing the AI Search service')
param aiSearchSubscriptionId string

resource aiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiAccountName
}

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: aiSearchName
  scope: resourceGroup(aiSearchSubscriptionId, aiSearchResourceGroupName)
}

var requestMessage = 'Foundry IQ embeddings from ${aiSearchName} (${uniqueString(searchService.id, aiAccount.id)})'

module cognitiveServicesRoles '../security/ai-search-cognitive-services-roles.bicep' = {
  name: 'assign-ai-search-cognitive-services-roles'
  params: {
    aiAccountName: aiAccount.name
    aiSearchPrincipalId: searchService.identity.principalId
  }
}

module sharedPrivateLink './ai-search-shared-private-link.bicep' = {
  name: 'deploy-ai-search-foundry-shared-private-link'
  scope: resourceGroup(aiSearchSubscriptionId, aiSearchResourceGroupName)
  params: {
    aiSearchName: aiSearchName
    aiAccountResourceId: aiAccount.id
    requestMessage: requestMessage
  }
}

module approveConnection './approve-foundry-private-endpoint.bicep' = {
  name: 'approve-ai-search-foundry-connection'
  params: {
    aiAccountName: aiAccount.name
    privateEndpointConnectionNames: sharedPrivateLink.outputs.privateEndpointConnectionNames
    requestMessage: requestMessage
  }
}
