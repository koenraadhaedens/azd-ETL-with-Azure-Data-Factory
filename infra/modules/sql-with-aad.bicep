param name string
param dbName string
param location string
param administratorLogin string = 'sqladminuser'
@secure()
param administratorPassword string

// Azure AD admin configuration - these need to be provided as parameters
param aadAdminLogin string
param aadAdminObjectId string
param aadAdminType string = 'User' // Can be 'User' or 'Group'

@description('Array of IP ranges to allow for Azure Data Factory access')
param dataFactoryIPRanges array = [
  { start: '20.42.2.0', end: '20.42.2.255' }
  { start: '20.42.4.0', end: '20.42.4.255' }
  { start: '20.42.5.0', end: '20.42.5.255' }
]

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: name
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
    // Enable Azure AD authentication
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: false // Allow both SQL and AAD auth
      login: aadAdminLogin
      sid: aadAdminObjectId
      tenantId: tenant().tenantId
      principalType: aadAdminType
    }
  }
}

// Allow specific Azure Data Factory IP ranges for the region
// Note: These IP ranges are region-specific. Update based on your deployment region.
// For a complete list, see: https://docs.microsoft.com/en-us/azure/data-factory/data-movement-security-considerations
resource allowDataFactoryIPs 'Microsoft.Sql/servers/firewallRules@2022-02-01-preview' = [for (ipRange, index) in dataFactoryIPRanges: {
  parent: sqlServer
  name: 'AllowADF-${index}'
  properties: {
    startIpAddress: ipRange.start
    endIpAddress: ipRange.end
  }
}]



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
output serverFqdn string = sqlServer.properties.fullyQualifiedDomainName
output administratorLogin string = administratorLogin
