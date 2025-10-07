param name string
param dbName string
param location string
param administratorLogin string = 'sqladminuser'
@secure()
param administratorPassword string

resource sqlServer 'Microsoft.Sql/servers@2022-02-01-preview' = {
  name: name
  location: location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorPassword
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
output connectionString string = 'Server=tcp:${sqlServer.name}.${environment().suffixes.sqlServerHostname},1433;Initial Catalog=${dbName};User ID=${administratorLogin};Password=${administratorPassword};Encrypt=True;'
