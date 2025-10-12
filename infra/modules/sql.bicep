param name string
param dbName string
param location string
param administratorLogin string = 'sqladminuser'
@secure()
param administratorPassword string
param subnetId string = ''
param vnetName string = ''

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: name
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    publicNetworkAccess: 'Enabled' // Keep public access for flexibility
    restrictOutboundNetworkAccess: 'Disabled'
  }
}

// Allow Azure services and resources to access this server
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2022-02-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Private endpoint for SQL Server
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (!empty(subnetId)) {
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
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

// Private DNS zone for SQL Server
resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(subnetId)) {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
}

// Link private DNS zone to VNet
resource sqlPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!empty(subnetId) && !empty(vnetName)) {
  parent: sqlPrivateDnsZone
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
resource sqlPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (!empty(subnetId)) {
  parent: sqlPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-database-windows-net'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZone.id
        }
      }
    ]
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2022-02-01-preview' = {
  parent: sqlServer
  name: dbName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    maxSizeBytes: 2147483648
  }
}

output serverName string = sqlServer.name
output databaseName string = sqlDb.name
output serverId string = sqlServer.id
output fullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName
output privateEndpointId string = !empty(subnetId) ? sqlPrivateEndpoint.id : ''
