param name string
param location string
param storageAccountId string
param sqlServerId string = ''
param sqlServerName string = ''
param subnetId string = ''
param vnetName string = ''

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    // Enable interactive authoring by default
    version: '2018-06-01'
  }
}

// Managed Virtual Network for ADF
resource managedVirtualNetwork 'Microsoft.DataFactory/factories/managedVirtualNetworks@2018-06-01' = {
  parent: dataFactory
  name: 'default'
  properties: {}
}

// Custom Managed Integration Runtime for private connectivity
resource integrationRuntime 'Microsoft.DataFactory/factories/integrationRuntimes@2018-06-01' = {
  parent: dataFactory
  name: 'ManagedVnetIntegrationRuntime'
  properties: {
    type: 'Managed'
    managedVirtualNetwork: {
      type: 'ManagedVirtualNetworkReference'
      referenceName: managedVirtualNetwork.name
    }
    typeProperties: {
      computeProperties: {
        location: 'AutoResolve'
        dataFlowProperties: {
          computeType: 'General'
          coreCount: 8
        }
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
      referenceName: !empty(subnetId) ? integrationRuntime.name : 'AutoResolveIntegrationRuntime'
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
      referenceName: !empty(subnetId) ? integrationRuntime.name : 'AutoResolveIntegrationRuntime'
      type: 'IntegrationRuntimeReference'
    }
  }
}

// Private endpoint for Azure Data Factory
resource adfPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (!empty(subnetId)) {
  name: '${name}-pe'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-pe-connection'
        properties: {
          privateLinkServiceId: dataFactory.id
          groupIds: [
            'dataFactory'
          ]
        }
      }
    ]
  }
}

// Private DNS zone for Azure Data Factory
resource adfPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(subnetId)) {
  name: 'privatelink.datafactory.azure.net'
  location: 'global'
}

// Link private DNS zone to VNet
resource adfPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!empty(subnetId) && !empty(vnetName)) {
  parent: adfPrivateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks', vnetName)
    }
  }
}

// Private DNS zone group for ADF
resource adfPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (!empty(subnetId)) {
  parent: adfPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-datafactory-azure-net'
        properties: {
          privateDnsZoneId: adfPrivateDnsZone.id
        }
      }
    ]
  }
}

output name string = dataFactory.name
output id string = dataFactory.id
output privateEndpointId string = !empty(subnetId) ? adfPrivateEndpoint.id : ''
