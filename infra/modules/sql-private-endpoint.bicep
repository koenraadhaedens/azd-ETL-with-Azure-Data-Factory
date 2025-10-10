// SQL Server with Private Endpoint (most secure option)
param name string
param dbName string
param location string
param administratorLogin string = 'sqladminuser'
@secure()
param administratorPassword string
param virtualNetworkId string
param subnetId string

@description('Enable private endpoint for SQL Server (more secure than firewall rules)')
param enablePrivateEndpoint bool = true

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: name
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    restrictOutboundNetworkAccess: 'Disabled'
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

// Private endpoint for SQL Server (when enabled)
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = if (enablePrivateEndpoint) {
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

// DNS zone for private endpoint
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (enablePrivateEndpoint) {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
}

// Link DNS zone to virtual network
resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (enablePrivateEndpoint) {
  parent: privateDnsZone
  name: '${name}-dns-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

// DNS zone group for private endpoint
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = if (enablePrivateEndpoint) {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// Fallback firewall rule for Azure services (only when private endpoint is disabled)
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2022-02-01-preview' = if (!enablePrivateEndpoint) {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output serverName string = sqlServer.name
output databaseName string = sqlDb.name
output serverFqdn string = sqlServer.properties.fullyQualifiedDomainName
output administratorLogin string = administratorLogin
output privateEndpointId string = enablePrivateEndpoint ? privateEndpoint.id : ''
