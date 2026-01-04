targetScope = 'resourceGroup'

// ============================================
// Parameters - Basic Configuration
// ============================================

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name for all resources. Resources will be named as {baseName}-{resourceType}')
@minLength(3)
@maxLength(15)
param baseName string

@description('Environment name (e.g., dev, test, prod, or any custom name)')
param environment string = 'dev'

@description('Tags to apply to all resources')
param tags object = {
  environment: environment
  managedBy: 'bicep'
  project: 'azure-ai-foundry'
}

// ============================================
// Parameters - AI Model Configuration
// ============================================

@description('Name of the AI model to deploy')
param modelName string = 'gpt-4o'

@description('Format of the AI model')
param modelFormat string = 'OpenAI'

@description('Version of the AI model')
param modelVersion string = '2024-08-06'

@description('SKU name for the model deployment')
@allowed(['Standard', 'GlobalStandard'])
param modelSkuName string = 'GlobalStandard'

@description('Capacity for the model deployment')
@minValue(1)
@maxValue(1000)
param modelCapacity int = 100

// ============================================
// Parameters - Existing Resources (Optional)
// ============================================

@description('Resource ID of existing AI Search service (leave empty to create new)')
param existingAiSearchResourceId string = ''

@description('Resource ID of existing Storage Account (leave empty to create new)')
param existingStorageAccountResourceId string = ''

@description('Resource ID of existing Cosmos DB account (leave empty to create new)')
param existingCosmosDbAccountResourceId string = ''

// ============================================
// Parameters - Project Configuration
// ============================================

@description('Display name for the AI project')
param projectDisplayName string = 'AI Agent Project'

@description('Description for the AI project')
param projectDescription string = 'Microsoft Foundry project for building AI agents'

@description('User Principal ID (Object ID) to assign AI Project Manager role (leave empty to skip)')
param userPrincipalId string = ''

// ============================================
// Variables - Resource Naming
// ============================================

// Generate unique hash for consistent naming across all resources
var nameHash = substring(uniqueString(resourceGroup().id, baseName, environment), 0, 6)

// AI Services Account: max 64 chars, alphanumeric and hyphens
var accountNameBase = toLower('${baseName}-${environment}')
var accountNameTruncated = substring(accountNameBase, 0, min(length(accountNameBase), 50))
var accountName = '${accountNameTruncated}-ai-${nameHash}'

// AI Project: max 64 chars, alphanumeric and hyphens
var projectNameBase = toLower('${baseName}-${environment}')
var projectNameTruncated = substring(projectNameBase, 0, min(length(projectNameBase), 50))
var projectName = '${projectNameTruncated}-prj-${nameHash}'

// AI Search: max 60 chars, lowercase alphanumeric and hyphens
var searchNameBase = toLower(replace('${baseName}${environment}', '-', ''))
var searchNameTruncated = substring(searchNameBase, 0, min(length(searchNameBase), 47))
var aiSearchName = '${searchNameTruncated}-srch-${nameHash}'

// Storage account: max 24 chars, lowercase alphanumeric only
var storageNameBase = toLower(replace('${baseName}${environment}', '-', ''))
var storageNameTruncated = substring(storageNameBase, 0, min(length(storageNameBase), 18))
var storageName = '${storageNameTruncated}${nameHash}'

// Cosmos DB: max 44 chars, lowercase alphanumeric and hyphens
var cosmosNameBase = toLower(replace('${baseName}${environment}', '-', ''))
var cosmosNameTruncated = substring(cosmosNameBase, 0, min(length(cosmosNameBase), 31))
var cosmosDbName = '${cosmosNameTruncated}-cosmos-${nameHash}'

// Capability Host names
var projectCapHostName = '${projectName}-caphost'
var accountCapHostName = '${accountName}-caphost'

// ============================================
// Module 1: Validate Existing Resources
// ============================================

module resourceValidator './modules/utils/resource-validator.bicep' = {
  name: 'validate-existing-resources'
  params: {
    aiSearchResourceId: existingAiSearchResourceId
    azureStorageAccountResourceId: existingStorageAccountResourceId
    azureCosmosDBAccountResourceId: existingCosmosDbAccountResourceId
  }
}

// ============================================
// Module 2: Deploy Dependent Resources
// ============================================

module dependentResources './modules/dependent-resources/dependent-resources.bicep' = {
  name: 'deploy-dependent-resources'
  params: {
    location: location
    
    // Resource names
    aiSearchName: aiSearchName
    azureStorageName: storageName
    cosmosDBName: cosmosDbName
    
    // Existing resource IDs
    aiSearchResourceId: existingAiSearchResourceId
    azureStorageAccountResourceId: existingStorageAccountResourceId
    cosmosDBResourceId: existingCosmosDbAccountResourceId
    
    // Validation results
    aiSearchExists: resourceValidator.outputs.aiSearchExists
    azureStorageExists: resourceValidator.outputs.azureStorageExists
    cosmosDBExists: resourceValidator.outputs.cosmosDBExists
  }
}

// ============================================
// Module 3: Deploy AI Account
// ============================================

module aiAccount './modules/core/ai-account.bicep' = {
  name: 'deploy-ai-account'
  params: {
    accountName: accountName
    location: location
    modelName: modelName
    modelFormat: modelFormat
    modelVersion: modelVersion
    modelSkuName: modelSkuName
    modelCapacity: modelCapacity
  }
}

// ============================================
// Module 4: Deploy AI Project
// ============================================

module aiProject './modules/core/ai-project.bicep' = {
  name: 'deploy-ai-project'
  params: {
    accountName: accountName
    projectName: projectName
    location: location
    projectDescription: projectDescription
    displayName: projectDisplayName
    
    // Dependent resource names
    aiSearchName: dependentResources.outputs.aiSearchName
    cosmosDBName: dependentResources.outputs.cosmosDBName
    azureStorageName: dependentResources.outputs.azureStorageName
    
    // Resource group information
    aiSearchServiceResourceGroupName: dependentResources.outputs.aiSearchServiceResourceGroupName
    aiSearchServiceSubscriptionId: dependentResources.outputs.aiSearchServiceSubscriptionId
    cosmosDBResourceGroupName: dependentResources.outputs.cosmosDBResourceGroupName
    cosmosDBSubscriptionId: dependentResources.outputs.cosmosDBSubscriptionId
    azureStorageResourceGroupName: dependentResources.outputs.azureStorageResourceGroupName
    azureStorageSubscriptionId: dependentResources.outputs.azureStorageSubscriptionId
  }
  dependsOn: [
    aiAccount
  ]
}

// ============================================
// Module 5: Format Project Workspace ID
// ============================================

module workspaceIdFormatter './modules/utils/workspace-id-formatter.bicep' = {
  name: 'format-workspace-id'
  params: {
    projectWorkspaceId: aiProject.outputs.projectWorkspaceId
  }
}

// ============================================
// Module 6: Assign Azure Roles
// ============================================

module roleAssignments './modules/security/role-assignments.bicep' = {
  name: 'assign-azure-roles'
  params: {
    // Principal IDs
    projectPrincipalId: aiProject.outputs.projectPrincipalId
    projectWorkspaceIdGuid: workspaceIdFormatter.outputs.projectWorkspaceIdGuid
    userPrincipalId: userPrincipalId
    
    // Account and Project names for AI Project Manager role
    accountName: accountName
    projectName: projectName
    
    // Resource names
    aiSearchName: dependentResources.outputs.aiSearchName
    cosmosDBName: dependentResources.outputs.cosmosDBName
    azureStorageName: dependentResources.outputs.azureStorageName
    
    // Resource group information
    aiSearchServiceResourceGroupName: dependentResources.outputs.aiSearchServiceResourceGroupName
    aiSearchServiceSubscriptionId: dependentResources.outputs.aiSearchServiceSubscriptionId
    cosmosDBResourceGroupName: dependentResources.outputs.cosmosDBResourceGroupName
    cosmosDBSubscriptionId: dependentResources.outputs.cosmosDBSubscriptionId
    azureStorageResourceGroupName: dependentResources.outputs.azureStorageResourceGroupName
    azureStorageSubscriptionId: dependentResources.outputs.azureStorageSubscriptionId
  }
}

// ============================================
// Module 7: Configure Project Capability Host
// ============================================

module projectCapabilityHost './modules/capabilities/project-capability-host.bicep' = {
  name: 'configure-capability-host'
  params: {
    accountName: accountName
    projectName: projectName
    projectCapHost: projectCapHostName
    accountCapHost: accountCapHostName
    
    // Connection names
    cosmosDBConnection: aiProject.outputs.cosmosDBConnection
    azureStorageConnection: aiProject.outputs.azureStorageConnection
    aiSearchConnection: aiProject.outputs.aiSearchConnection
  }
  dependsOn: [
    roleAssignments
  ]
}

// ============================================
// Outputs
// ============================================

@description('Resource group name')
output resourceGroupName string = resourceGroup().name

@description('AI Services account name')
output aiAccountName string = aiAccount.outputs.accountName

@description('AI Services account endpoint')
output aiAccountEndpoint string = aiAccount.outputs.accountTarget

@description('AI Project name')
output aiProjectName string = aiProject.outputs.projectName

@description('AI Project ID')
output aiProjectId string = aiProject.outputs.projectId

@description('AI Search service name')
output aiSearchName string = dependentResources.outputs.aiSearchName

@description('Storage account name')
output storageAccountName string = dependentResources.outputs.azureStorageName

@description('Cosmos DB account name')
output cosmosDbAccountName string = dependentResources.outputs.cosmosDBName

@description('Deployment completed successfully')
output deploymentStatus string = 'All resources deployed successfully. You can now start using Microsoft Foundry.'
