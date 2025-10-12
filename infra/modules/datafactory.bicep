param name string
param location string
param storageAccountId string
param sqlServerId string = ''
param sqlServerName string = ''

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

// Managed Virtual Network for ADF
resource managedVirtualNetwork 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  parent: dataFactory
  name: 'default'
  properties: {}
}

// Self-hosted Integration Runtime for private connectivity
resource integrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  parent: dataFactory
  name: 'AutoResolveIntegrationRuntime'
  properties: {
    type: 'Managed'
    managedVirtualNetwork: {
      type: 'ManagedVirtualNetworkReference'
      referenceName: managedVirtualNetwork.name
    }
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
      }
    }
  }
}

// Managed private endpoint for SQL Server
resource sqlManagedPrivateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = if (!empty(sqlServerId)) {
  parent: managedVirtualNetwork
  name: '${sqlServerName}-mpe'
  properties: {
    privateLinkResourceId: sqlServerId
    groupId: 'sqlServer'
  }
}

// Managed private endpoint for Storage Account
resource storageManagedPrivateEndpoint 'Microsoft.DataFactory/factories/managedVirtualNetworks/managedPrivateEndpoints@2018-06-01' = {
  parent: managedVirtualNetwork
  name: 'storage-mpe'
  properties: {
    privateLinkResourceId: storageAccountId
    groupId: 'blob'
  }
}

resource linkedServiceStorage 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  parent: dataFactory
  name: 'AzureBlobStorageLinkedService'
  properties: {
    type: 'AzureBlobStorage'
    typeProperties: {
      connectionString: 'DefaultEndpointsProtocol=https;AccountName=${last(split(storageAccountId, '/'))};EndpointSuffix=${environment().suffixes.storage}'
    }
    connectVia: {
      referenceName: integrationRuntime.name
      type: 'IntegrationRuntimeReference'
    }
  }
}

// SQL Server linked service (using private endpoint when available)
resource linkedServiceSql 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = if (!empty(sqlServerId)) {
  parent: dataFactory
  name: 'AzureSqlDatabaseLinkedService'
  properties: {
    type: 'AzureSqlDatabase'
    typeProperties: {
      connectionString: 'Server=tcp:${sqlServerName}${environment().suffixes.sqlServerHostname},1433;Database=salesdb;Encrypt=True;'
    }
    connectVia: {
      referenceName: integrationRuntime.name
      type: 'IntegrationRuntimeReference'
    }
  }
}

output name string = dataFactory.name
output id string = dataFactory.id
