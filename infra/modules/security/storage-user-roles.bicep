targetScope = 'resourceGroup'

@description('User Principal ID (Object ID) to assign storage roles')
param userPrincipalId string

@description('Storage account name')
param storageName string

// Reference existing storage account
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageName
}

// Storage Blob Data Contributor Role - Allows users to read, write, and delete blobs
// Role ID: ba92f5b4-2d11-453d-a403-e96b0029c9fe
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}

// Storage Account Contributor Role - Allows users to manage storage accounts
// Role ID: 17d1049b-9a84-46fb-8f53-869881c3d3ab
resource storageAccountContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
}

// Assign Storage Blob Data Contributor role to user for blob operations
resource blobDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (userPrincipalId != '') {
  scope: storage
  name: guid(userPrincipalId, storageBlobDataContributorRole.id, storage.id)
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: storageBlobDataContributorRole.id
    principalType: 'User'
  }
}

// Assign Storage Account Contributor role to user for account-level operations
resource storageAccountContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (userPrincipalId != '') {
  scope: storage
  name: guid(userPrincipalId, storageAccountContributorRole.id, storage.id)
  properties: {
    principalId: userPrincipalId
    roleDefinitionId: storageAccountContributorRole.id
    principalType: 'User'
  }
}

output blobDataContributorAssignmentId string = blobDataContributorAssignment.id
output storageAccountContributorAssignmentId string = storageAccountContributorAssignment.id
