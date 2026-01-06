targetScope = 'resourceGroup'

@description('Group Principal ID (Object ID) to assign Reader role')
param userPrincipalId string

// Reader role definition
// Role ID: acdd72a7-3385-48ef-bd42-f606fba81ae7
resource readerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

// Assign Reader role to group on Resource Group
resource readerResourceGroupAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (userPrincipalId != '') {
  scope: resourceGroup()
  name: guid(userPrincipalId, readerRole.id, resourceGroup().id, 'reader')
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: readerRole.id
    principalType: 'Group'
  }
}

output readerResourceGroupAssignmentId string = readerResourceGroupAssignment.id
