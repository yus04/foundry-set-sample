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
// Role ID: d87bc03e-fc68-4e57-b076-c9caa8c2a73d
resource aiProjectManagerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: 'd87bc03e-fc68-4e57-b076-c9caa8c2a73d'
}

// Assign AI Project Manager role to user
resource aiProjectManagerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (userPrincipalId != '') {
  scope: project
  name: guid(userPrincipalId, aiProjectManagerRole.id, project.id)
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: aiProjectManagerRole.id
    principalType: 'User'
  }
}

output roleAssignmentId string = aiProjectManagerAssignment.id
output roleAssignmentName string = aiProjectManagerAssignment.name
