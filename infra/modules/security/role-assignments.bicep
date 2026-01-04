targetScope = 'resourceGroup'

@description('AI Account principal ID')
param accountPrincipalId string

@description('AI Project principal ID')
param projectPrincipalId string

@description('Project workspace ID (GUID format)')
param projectWorkspaceIdGuid string

@description('User Principal ID (Object ID) to assign AI Project Manager role')
param userPrincipalId string = ''

@description('AI Services account name')
param accountName string

@description('AI Project name')
param projectName string

@description('AI Search service name')
param aiSearchName string

@description('AI Search resource group')
param aiSearchServiceResourceGroupName string

@description('AI Search subscription ID')
param aiSearchServiceSubscriptionId string

@description('Cosmos DB account name')
param cosmosDBName string

@description('Cosmos DB resource group')
param cosmosDBResourceGroupName string

@description('Cosmos DB subscription ID')
param cosmosDBSubscriptionId string

@description('Storage account name')
param azureStorageName string

@description('Storage resource group')
param azureStorageResourceGroupName string

@description('Storage subscription ID')
param azureStorageSubscriptionId string

// ============================================
// AI Search Role Assignments
// ============================================

module aiSearchRoles './ai-search-roles.bicep' = {
  name: 'assign-ai-search-roles'
  scope: resourceGroup(aiSearchServiceSubscriptionId, aiSearchServiceResourceGroupName)
  params: {
    aiSearchName: aiSearchName
    projectPrincipalId: projectPrincipalId
  }
}

// ============================================
// Cosmos DB Role Assignments
// ============================================

module cosmosDbAccountRole './cosmos-db-account-role.bicep' = {
  name: 'assign-cosmos-account-role'
  scope: resourceGroup(cosmosDBSubscriptionId, cosmosDBResourceGroupName)
  params: {
    cosmosDBName: cosmosDBName
    projectPrincipalId: projectPrincipalId
  }
}

module cosmosDbContainerRoles './cosmos-db-container-roles.bicep' = {
  name: 'assign-cosmos-container-roles'
  scope: resourceGroup(cosmosDBSubscriptionId, cosmosDBResourceGroupName)
  params: {
    cosmosAccountName: cosmosDBName
    projectPrincipalId: projectPrincipalId
    projectWorkspaceId: projectWorkspaceIdGuid
  }
}

// ============================================
// Storage Account Role Assignments
// ============================================

module storageAccountRole './storage-account-role.bicep' = {
  name: 'assign-storage-account-role'
  scope: resourceGroup(azureStorageSubscriptionId, azureStorageResourceGroupName)
  params: {
    azureStorageName: azureStorageName
    projectPrincipalId: projectPrincipalId
  }
}

module storageContainerRoles './storage-container-roles.bicep' = {
  name: 'assign-storage-container-roles'
  scope: resourceGroup(azureStorageSubscriptionId, azureStorageResourceGroupName)
  params: {
    storageName: azureStorageName
    aiProjectPrincipalId: projectPrincipalId
    workspaceId: projectWorkspaceIdGuid
  }
}

// ============================================
// AI Project Manager Role Assignment (User)
// ============================================

module aiProjectManagerRole './ai-project-manager-role.bicep' = if (userPrincipalId != '') {
  name: 'assign-ai-project-manager-role'
  params: {
    userPrincipalId: userPrincipalId
    accountName: accountName
    projectName: projectName
  }
}
