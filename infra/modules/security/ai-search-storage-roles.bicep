targetScope = 'resourceGroup'

@description('Name of the AI Search service')
param aiSearchName string

@description('Name of the Storage Account')
param storageName string

// Reference existing AI Search service
resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: aiSearchName
}

// Reference existing storage account
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageName
}

// Storage Blob Data Reader Role - Required for AI Search to read blobs for knowledge source indexing
// Role ID: 2a2b9908-6b9a-4582-a4c1-7e3c5d6ca4c3
resource storageBlobDataReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '2a2b9908-6b9a-4582-a4c1-7e3c5d6ca4c3'
}

// Assign Storage Blob Data Reader role to AI Search managed identity
// This allows AI Search to access blob containers for creating knowledge source indexes
resource storageBlobDataReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(searchService.id, storageBlobDataReaderRole.id, storage.id)
  properties: {
    principalId: searchService.identity.principalId
    roleDefinitionId: storageBlobDataReaderRole.id
    principalType: 'ServicePrincipal'
  }
}

output roleAssignmentId string = storageBlobDataReaderAssignment.id
output roleAssignmentName string = storageBlobDataReaderAssignment.name
