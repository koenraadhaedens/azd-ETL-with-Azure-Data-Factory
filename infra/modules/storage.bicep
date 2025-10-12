param name string
param location string
param subnetId string = ''
param vnetName string = ''

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    isHnsEnabled: true // Enable hierarchical namespace (Data Lake Gen2)
    publicNetworkAccess: 'Enabled' // Keep public access for flexibility
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Private endpoint for Storage Account (blob)
resource storagePrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (!empty(subnetId)) {
  name: '${name}-pe-blob'
  location: location
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-pe-blob-connection'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

// Private DNS zone for Storage Account
resource storagePrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(subnetId)) {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
}

// Link private DNS zone to VNet
resource storagePrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!empty(subnetId) && !empty(vnetName)) {
  parent: storagePrivateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: resourceId('Microsoft.Network/virtualNetworks', vnetName)
    }
  }
}

// Private DNS zone group
resource storagePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (!empty(subnetId)) {
  parent: storagePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-blob-core-windows-net'
        properties: {
          privateDnsZoneId: storagePrivateDnsZone.id
        }
      }
    ]
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  name: 'default'
  parent: storage
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'raw'
  properties: {
    publicAccess: 'None'
  }
}

output name string = storage.name
output id string = storage.id
output primaryEndpoint string = storage.properties.primaryEndpoints.blob
