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

@description('Tags to apply to all resources')
param tags object = {
  environment: baseName
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
// Parameters - Enterprise Networking
// ============================================

@description('Publisher email for API Management')
param apimPublisherEmail string = 'admin@contoso.com'

@description('Publisher name for API Management')
param apimPublisherName string = 'AI Platform Team'

// ============================================
// Variables - Resource Naming
// ============================================

// Generate unique hash for consistent naming across all resources
var nameHash = substring(uniqueString(resourceGroup().id, baseName), 0, 6)

// AI Services Account: max 64 chars, alphanumeric and hyphens
var accountNameBase = toLower(baseName)
var accountNameTruncated = substring(accountNameBase, 0, min(length(accountNameBase), 50))
var accountName = '${accountNameTruncated}-ai-${nameHash}'

// AI Project: max 64 chars, alphanumeric and hyphens
var projectNameBase = toLower(baseName)
var projectNameTruncated = substring(projectNameBase, 0, min(length(projectNameBase), 50))
var projectName = '${projectNameTruncated}-prj-${nameHash}'

// AI Search: max 60 chars, lowercase alphanumeric and hyphens
var searchNameBase = toLower(replace(baseName, '-', ''))
var searchNameTruncated = substring(searchNameBase, 0, min(length(searchNameBase), 47))
var aiSearchName = '${searchNameTruncated}-srch-${nameHash}'

// Storage account: max 24 chars, lowercase alphanumeric only
var storageNameBase = toLower(replace(baseName, '-', ''))
var storageNameTruncated = substring(storageNameBase, 0, min(length(storageNameBase), 18))
var storageName = '${storageNameTruncated}${nameHash}'

// Cosmos DB: max 44 chars, lowercase alphanumeric and hyphens
var cosmosNameBase = toLower(replace(baseName, '-', ''))
var cosmosNameTruncated = substring(cosmosNameBase, 0, min(length(cosmosNameBase), 31))
var cosmosDbName = '${cosmosNameTruncated}-cosmos-${nameHash}'

// Cognitive Services (AVM): max 64 chars, alphanumeric and hyphens
var cognitiveServicesName = '${accountName}-cs'

// Capability Host names
var projectCapHostName = '${projectName}-caphost'
var accountCapHostName = '${accountName}-caphost'

// Log Analytics: max 63 chars
var logAnalyticsName = '${toLower(baseName)}-law-${nameHash}'

// AMPLS
var amplsName = '${toLower(baseName)}-ampls-${nameHash}'

// API Management: must be globally unique
var apimNameBase = toLower(replace(baseName, '-', ''))
var apimName = '${apimNameBase}-apim-${nameHash}'

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
// Module: Deploy Virtual Network
// ============================================

module vnet './modules/networking/vnet.bicep' = {
  name: 'deploy-vnet'
  params: {
    location: location
    baseName: baseName
    tags: tags
  }
}

// ============================================
// Module: Deploy Log Analytics
// ============================================

module logAnalytics './modules/monitoring/log-analytics.bicep' = {
  name: 'deploy-log-analytics'
  params: {
    location: location
    logAnalyticsName: logAnalyticsName
    tags: tags
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
// Module: Deploy Private Endpoints
// ============================================

module privateEndpoints './modules/networking/private-endpoints.bicep' = {
  name: 'deploy-private-endpoints'
  params: {
    location: location
    tags: tags
    vnetId: vnet.outputs.vnetId
    subnetId: vnet.outputs.privateEndpointSubnetId
    storageAccountId: dependentResources.outputs.azureStorageId
    aiSearchId: dependentResources.outputs.aiSearchID
    aiAccountId: aiAccount.outputs.accountID
    cosmosDbAccountId: dependentResources.outputs.cosmosDBId
    storageAccountName: dependentResources.outputs.azureStorageName
    aiSearchName: dependentResources.outputs.aiSearchName
    aiAccountName: aiAccount.outputs.accountName
    cosmosDbAccountName: dependentResources.outputs.cosmosDBName
  }
}

// ============================================
// Module: Deploy AMPLS - Phase 1 (Scope + Resource)
// ============================================

module ampls './modules/monitoring/ampls.bicep' = {
  name: 'deploy-ampls'
  params: {
    amplsName: amplsName
    tags: tags
    logAnalyticsId: logAnalytics.outputs.logAnalyticsId
    logAnalyticsName: logAnalytics.outputs.logAnalyticsName
  }
}

// ============================================
// Module: Deploy AMPLS - Phase 2 (Private Endpoint + DNS)
// Separate module ensures Scoped Resources are fully
// provisioned before PE creation, avoiding RequiredMembers mismatch.
// ============================================

module amplsPrivateEndpoint './modules/monitoring/ampls-private-endpoint.bicep' = {
  name: 'deploy-ampls-private-endpoint'
  params: {
    location: location
    amplsName: amplsName
    tags: tags
    amplsId: ampls.outputs.amplsId
    vnetId: vnet.outputs.vnetId
    subnetId: vnet.outputs.privateEndpointSubnetId
    blobDnsZoneId: privateEndpoints.outputs.blobDnsZoneId
  }
}

// ============================================
// Module: Deploy API Management (AI Gateway)
// ============================================

module apiManagement './modules/networking/api-management.bicep' = {
  name: 'deploy-api-management'
  params: {
    location: location
    apimName: apimName
    tags: tags
    aiAccountEndpoint: aiAccount.outputs.accountTarget
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
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
    cognitiveServicesName: cognitiveServicesName
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
// Module: APIM Role Assignment for Cognitive Services
// ============================================

module apimRoleAssignment './modules/security/apim-cognitive-services-role.bicep' = {
  name: 'assign-apim-cognitive-services-role'
  params: {
    aiAccountName: accountName
    apimPrincipalId: apiManagement.outputs.apimPrincipalId
  }
}

// ============================================
// Module: Diagnostic Settings (Foundry → Log Analytics)
// ============================================

module diagnosticSettings './modules/monitoring/diagnostic-settings.bicep' = {
  name: 'configure-diagnostic-settings'
  params: {
    aiAccountName: accountName
    logAnalyticsId: logAnalytics.outputs.logAnalyticsId
  }
  dependsOn: [
    aiAccount
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

@description('Virtual Network name')
output vnetName string = vnet.outputs.vnetName

@description('Log Analytics workspace name')
output logAnalyticsName string = logAnalytics.outputs.logAnalyticsName

@description('API Management name')
output apimName string = apiManagement.outputs.apimName

@description('API Management gateway URL')
output apimGatewayUrl string = apiManagement.outputs.apimGatewayUrl
