targetScope = 'subscription'

// ============================================
// Parameters - Basic Configuration
// ============================================

@description('Azure region for all resources')
param location string

@description('Base name for all resources. Resources will be named as {baseName}-{resourceType}')
@minLength(3)
@maxLength(15)
param baseName string

@description('Environment name (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environmentName string = 'dev'

@description('Resource group name')
param resourceGroupName string = 'rg-${baseName}-${environmentName}'

@description('Tags to apply to all resources')
param tags object = {
  environment: environmentName
  managedBy: 'azd'
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
// Resource Group
// ============================================

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ============================================
// Module: Deploy Resources
// ============================================

module resources './main.resources.bicep' = {
  name: 'deploy-resources'
  scope: rg
  params: {
    location: location
    baseName: baseName
    environment: environmentName
    tags: tags
    modelName: modelName
    modelFormat: modelFormat
    modelVersion: modelVersion
    modelSkuName: modelSkuName
    modelCapacity: modelCapacity
    existingAiSearchResourceId: existingAiSearchResourceId
    existingStorageAccountResourceId: existingStorageAccountResourceId
    existingCosmosDbAccountResourceId: existingCosmosDbAccountResourceId
    projectDisplayName: projectDisplayName
    projectDescription: projectDescription
    userPrincipalId: userPrincipalId
  }
}

// ============================================
// Outputs
// ============================================

@description('Resource group name')
output resourceGroupName string = rg.name

@description('AI Services account name')
output aiAccountName string = resources.outputs.aiAccountName

@description('AI Services account endpoint')
output aiAccountEndpoint string = resources.outputs.aiAccountEndpoint

@description('AI Project name')
output aiProjectName string = resources.outputs.aiProjectName

@description('AI Project ID')
output aiProjectId string = resources.outputs.aiProjectId

@description('AI Search service name')
output aiSearchName string = resources.outputs.aiSearchName

@description('Storage account name')
output storageAccountName string = resources.outputs.storageAccountName

@description('Cosmos DB account name')
output cosmosDbAccountName string = resources.outputs.cosmosDbAccountName

@description('Deployment completed successfully')
output deploymentStatus string = resources.outputs.deploymentStatus

@description('Azure Portal URL for the project')
output azurePortalUrl string = 'https://portal.azure.com/#@/resource${rg.id}'
