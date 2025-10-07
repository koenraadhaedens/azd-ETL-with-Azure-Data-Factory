@description('Name of the Azure Data Factory instance')
param dataFactoryName string

@description('Resource ID of the Storage Account to grant access')
param storageAccountId string

// 🔹 1. Enable System-Assigned Managed Identity on the existing Data Factory
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

resource miUpdate 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactory.name
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

// 🔹 2. Wait for MI creation, then assign permissions on the storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
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
    principalId: miUpdate.identity.principalId
  }
}

output principalId string = miUpdate.identity.principalId
