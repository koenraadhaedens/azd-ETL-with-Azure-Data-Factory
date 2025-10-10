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

// Allow Azure services to access the server
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2022-02-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
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
output serverFqdn string = sqlServer.properties.fullyQualifiedDomainName
output administratorLogin string = administratorLogin
