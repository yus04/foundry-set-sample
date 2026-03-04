
param accountName string
param location string
param modelName string
param modelFormat string
param modelVersion string
param modelSkuName string
param modelCapacity int

@description('Agent subnet resource ID for VNet rule')
param agentSubnetId string

resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: accountName
  location: location
  sku: {
    name: 'S0'
  }
  kind: 'AIServices'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: accountName
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: agentSubnetId
          ignoreMissingVnetServiceEndpoint: true
        }
      ]
      ipRules: []
    }
    publicNetworkAccess: 'Enabled'

    // API-key based auth is not supported for the Agent service
    disableLocalAuth: false
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-04-01-preview'=  {
  parent: account
  name: modelName
  sku : {
    capacity: modelCapacity
    name: modelSkuName
  }
  properties: {
    model:{
      name: modelName
      format: modelFormat
      version: modelVersion
    }
  }
}

output accountName string = account.name
output accountID string = account.id
output accountTarget string = account.properties.endpoint
output accountPrincipalId string = account.identity.principalId

// ============================================
// Azure Verified Module (AVM) for Cognitive Services
// ============================================

// Deploy additional Cognitive Services using Microsoft's verified module
module cognitiveServicesAVM 'br/public:avm/res/cognitive-services/account:0.14.0' = {
  name: 'deploy-cognitive-services-${accountName}'
  params: {
    kind: 'CognitiveServices'
    name: '${accountName}-cs'
    location: location
  }
}
