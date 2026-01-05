targetScope = 'resourceGroup'

@description('User Principal ID (Object ID) to assign AI Project Manager role')
param userPrincipalId string

@description('AI Services account name')
param accountName string

@description('AI Project name')
param projectName string

// Get existing AI Services account
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: accountName
}

// Get existing AI Project
resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  parent: account
  name: projectName
}

// AI Project Manager role definition (Microsoft Foundry Project Manager)
// Role ID: eadc314b-1a2d-4efa-be10-5d325db5065e
resource aiProjectManagerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: 'eadc314b-1a2d-4efa-be10-5d325db5065e'
}

// Cognitive Services OpenAI Contributor role definition
// Role ID: a001fd3d-188f-4b5d-821b-7da978bf7442
// This role provides access to Azure OpenAI data actions including data-generations
resource cognitiveServicesOpenAIContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: 'a001fd3d-188f-4b5d-821b-7da978bf7442'
}

// Assign AI Project Manager role to user on Project scope
resource aiProjectManagerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (userPrincipalId != '') {
  scope: project
  name: guid(userPrincipalId, aiProjectManagerRole.id, project.id)
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: aiProjectManagerRole.id
    principalType: 'User'
  }
}

// Assign Cognitive Services OpenAI Contributor role to user on AI Services Account scope
// This enables access to OpenAI data-generations and other OpenAI data actions
resource openAIContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (userPrincipalId != '') {
  scope: account
  name: guid(userPrincipalId, cognitiveServicesOpenAIContributorRole.id, account.id)
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: cognitiveServicesOpenAIContributorRole.id
    principalType: 'User'
  }
}

output projectManagerRoleAssignmentId string = aiProjectManagerAssignment.id
output projectManagerRoleAssignmentName string = aiProjectManagerAssignment.name
output openAIContributorRoleAssignmentId string = openAIContributorAssignment.id
output openAIContributorRoleAssignmentName string = openAIContributorAssignment.name
