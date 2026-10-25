targetScope = 'resourceGroup'

@description('Foundry account receiving the shared private link request')
param aiAccountName string

@description('Exactly one connection must match the Search-to-Foundry approval message')
@minLength(1)
@maxLength(1)
param privateEndpointConnectionNames string[]

@description('Preserve the identifying request message so redeployments find the same connection')
param requestMessage string

resource aiAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: aiAccountName
}

resource approvedConnection 'Microsoft.CognitiveServices/accounts/privateEndpointConnections@2024-10-01' = {
  parent: aiAccount
  name: privateEndpointConnectionNames[0]
  properties: {
    privateLinkServiceConnectionState: {
      status: 'Approved'
      description: requestMessage
    }
  }
}
