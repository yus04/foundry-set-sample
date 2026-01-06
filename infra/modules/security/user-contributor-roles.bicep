targetScope = 'resourceGroup'

@description('User Principal ID (Object ID) to assign Contributor role')
param userPrincipalId string

@description('AI Services account name')
param accountName string

@description('AI Project name')
param projectName string

@description('Storage account name')
param storageName string

@description('AI Search service name')
param aiSearchName string

@description('AI Search resource group')
param aiSearchResourceGroupName string

@description('AI Search subscription ID')
param aiSearchSubscriptionId string

@description('Cosmos DB account name')
param cosmosDBName string

@description('Cosmos DB resource group')
param cosmosDBResourceGroupName string

@description('Cosmos DB subscription ID')
param cosmosDBSubscriptionId string

@description('Cognitive Services account name')
param cognitiveServicesName string

// Contributor role definition
// Role ID: b24988ac-6180-42a0-ab88-20f7382dd24c
resource contributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

// Reference existing AI Services account
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

// Reference existing Cognitive Services account (AVM)
resource cognitiveServices 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: cognitiveServicesName
}

// Reference existing Storage Account
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageName
}

// Assign Contributor role to group on AI Services Account
// Note: AI Project inherits permissions from AI Services Account scope, so no separate assignment needed
resource contributorAccountAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (userPrincipalId != '') {
  scope: account
  name: guid(userPrincipalId, contributorRole.id, account.id, 'contributor')
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: contributorRole.id
    principalType: 'Group'
  }
}

// Assign Contributor role to group on Storage Account
resource contributorStorageAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (userPrincipalId != '') {
  scope: storage
  name: guid(userPrincipalId, contributorRole.id, storage.id, 'contributor')
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: contributorRole.id
    principalType: 'Group'
  }
}

// Assign Contributor role to group on Cognitive Services Account
resource contributorCognitiveServicesAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (userPrincipalId != '') {
  scope: cognitiveServices
  name: guid(userPrincipalId, contributorRole.id, cognitiveServices.id, 'contributor')
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: contributorRole.id
    principalType: 'Group'
  }
}

// Assign Contributor role to user on AI Search (cross-resource-group)
module contributorAiSearchAssignment './cross-rg-contributor-assignment.bicep' = if (userPrincipalId != '') {
  name: 'assign-contributor-ai-search'
  scope: resourceGroup(aiSearchSubscriptionId, aiSearchResourceGroupName)
  params: {
    userPrincipalId: userPrincipalId
    resourceName: aiSearchName
    resourceType: 'Microsoft.Search/searchServices'
  }
}

// Assign Contributor role to user on Cosmos DB (cross-resource-group)
module contributorCosmosDbAssignment './cross-rg-contributor-assignment.bicep' = if (userPrincipalId != '') {
  name: 'assign-contributor-cosmos-db'
  scope: resourceGroup(cosmosDBSubscriptionId, cosmosDBResourceGroupName)
  params: {
    userPrincipalId: userPrincipalId
    resourceName: cosmosDBName
    resourceType: 'Microsoft.DocumentDB/databaseAccounts'
  }
}

output contributorAccountAssignmentId string = contributorAccountAssignment.id
output contributorStorageAssignmentId string = contributorStorageAssignment.id
output contributorCognitiveServicesAssignmentId string = contributorCognitiveServicesAssignment.id
