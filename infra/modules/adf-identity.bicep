@description('Name of the Azure Data Factory instance')
param dataFactoryName string

@description('Resource ID of the Storage Account to grant access')
param storageAccountId string

// 🔹 1. Reference the existing Data Factory (identity is already enabled in datafactory.bicep)
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

// 🔹 2. Assign permissions on the storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  scope: resourceGroup()
  name: last(split(storageAccountId, '/'))
}

resource adfStorageAccess 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageAccountId, 'Storage Blob Data Contributor', dataFactory.name)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
    )
    principalId: dataFactory.identity.principalId
  }
}

output principalId string = dataFactory.identity.principalId
