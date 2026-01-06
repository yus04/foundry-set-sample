targetScope = 'resourceGroup'

@description('User Principal ID to assign Contributor role')
param userPrincipalId string

@description('Resource name')
param resourceName string

@description('Resource type (e.g., Microsoft.Search/searchServices)')
param resourceType string

// Contributor role definition
resource contributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

// Dynamic resource reference based on resource type
resource targetResource 'Microsoft.Search/searchServices@2024-06-01-preview' existing = if (resourceType == 'Microsoft.Search/searchServices') {
  name: resourceName
}

resource targetResourceCosmos 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = if (resourceType == 'Microsoft.DocumentDB/databaseAccounts') {
  name: resourceName
}

// Assign Contributor role
resource contributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (resourceType == 'Microsoft.Search/searchServices') {
  scope: targetResource
  name: guid(userPrincipalId, contributorRole.id, targetResource.id, 'contributor')
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: contributorRole.id
    principalType: 'Group'
  }
}

resource contributorAssignmentCosmos 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (resourceType == 'Microsoft.DocumentDB/databaseAccounts') {
  scope: targetResourceCosmos
  name: guid(userPrincipalId, contributorRole.id, targetResourceCosmos.id, 'contributor')
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: contributorRole.id
    principalType: 'Group'
  }
}

output roleAssignmentId string = resourceType == 'Microsoft.Search/searchServices' ? contributorAssignment.id : contributorAssignmentCosmos.id
