targetScope = 'resourceGroup'

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

@description('Cognitive Services account name')
param cognitiveServicesName string

// ============================================
// AI Search Role Assignments
// ============================================

// Assign AI Search roles to AI Project (for search operations)
module aiSearchRoles './ai-search-roles.bicep' = {
  name: 'assign-ai-search-roles'
  scope: resourceGroup(aiSearchServiceSubscriptionId, aiSearchServiceResourceGroupName)
  params: {
    aiSearchName: aiSearchName
    projectPrincipalId: projectPrincipalId
  }
}

// Assign Storage Blob Data Reader role to AI Search managed identity
// This is required for AI Search to access blob storage when creating knowledge source indexes
module aiSearchStorageRoles './ai-search-storage-roles.bicep' = {
  name: 'assign-ai-search-storage-roles'
  scope: resourceGroup(azureStorageSubscriptionId, azureStorageResourceGroupName)
  params: {
    aiSearchName: aiSearchName
    storageName: azureStorageName
  }
  dependsOn: [
    aiSearchRoles
  ]
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

// Assign storage roles to AI Project (managed identity)
module storageContainerRoles './storage-container-roles.bicep' = {
  name: 'assign-storage-container-roles'
  scope: resourceGroup(azureStorageSubscriptionId, azureStorageResourceGroupName)
  params: {
    storageName: azureStorageName
    aiProjectPrincipalId: projectPrincipalId
    workspaceId: projectWorkspaceIdGuid
  }
}

// Assign storage roles to User for file upload and knowledge source operations
module storageUserRoles './storage-user-roles.bicep' = if (userPrincipalId != '') {
  name: 'assign-storage-user-roles'
  scope: resourceGroup(azureStorageSubscriptionId, azureStorageResourceGroupName)
  params: {
    userPrincipalId: userPrincipalId
    storageName: azureStorageName
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

// ============================================
// Contributor Role Assignment (User)
// ============================================

// Assign Contributor role to user on all Azure resources
module userContributorRoles './user-contributor-roles.bicep' = if (userPrincipalId != '') {
  name: 'assign-user-contributor-roles'
  params: {
    userPrincipalId: userPrincipalId
    accountName: accountName
    projectName: projectName
    storageName: azureStorageName
    cognitiveServicesName: cognitiveServicesName
    aiSearchName: aiSearchName
    aiSearchResourceGroupName: aiSearchServiceResourceGroupName
    aiSearchSubscriptionId: aiSearchServiceSubscriptionId
    cosmosDBName: cosmosDBName
    cosmosDBResourceGroupName: cosmosDBResourceGroupName
    cosmosDBSubscriptionId: cosmosDBSubscriptionId
  }
}

// ============================================
// Resource Group Reader Role Assignment
// ============================================

// Assign Reader role to group on Resource Group
module resourceGroupReaderRole './resource-group-reader-role.bicep' = if (userPrincipalId != '') {
  name: 'assign-resource-group-reader-role'
  params: {
    userPrincipalId: userPrincipalId
  }
}
