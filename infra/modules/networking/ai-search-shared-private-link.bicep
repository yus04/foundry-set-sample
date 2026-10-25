targetScope = 'resourceGroup'

@description('AI Search service name')
param aiSearchName string

@description('Resource ID of the Foundry account hosting the embedding model')
param aiAccountResourceId string

@description('Unique approval message identifying this Search-to-Foundry connection')
param requestMessage string

var accountParts = split(aiAccountResourceId, '/')

resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: aiSearchName
}

resource aiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: accountParts[8]
  scope: resourceGroup(accountParts[2], accountParts[4])
}

resource sharedPrivateLink 'Microsoft.Search/searchServices/sharedPrivateLinkResources@2024-06-01-preview' = {
  parent: searchService
  name: 'foundry-openai-${uniqueString(aiAccountResourceId)}'
  properties: {
    privateLinkResourceId: aiAccountResourceId
    groupId: 'openai_account'
    requestMessage: requestMessage
  }
}

// Outputs are evaluated after link provisioning, when the target-side connection exists.
output privateEndpointConnectionNames string[] = map(
  filter(aiAccount.properties.privateEndpointConnections, connection => connection.properties.privateLinkServiceConnectionState.?description == requestMessage),
  connection => last(split(connection.id, '/'))
)
