targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@secure()
@description('Password for the SQL Server administrator')
param sqlAdminPassword string // user will be prompted during deployment



resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: {
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'}
}

// Variables for naming conventions
var projectPrefix = toLower(environmentName)
var storageName = take('${projectPrefix}store', 24)
var sqlServerName = take('${projectPrefix}sql', 60)
var sqlDbName = 'salesdb'
var adfName = take('${projectPrefix}adf', 60)

// Deploy the Storage Account
module storage 'modules/storage.bicep' = {
  name: 'storageDeploy'
  scope: rg
  params: {
    name: storageName
    location: location
  }
}

// Deploy SQL Server + Database
module sql 'modules/sql.bicep' = {
  name: 'sqlDeploy'
  scope: rg
  params: {
    name: sqlServerName
    dbName: sqlDbName
    location: location
    administratorPassword: sqlAdminPassword
  }
}

// Deploy Azure Data Factory
module adf 'modules/datafactory.bicep' = {
  name: 'adfDeploy'
  scope: rg
  params: {
    name: adfName
    location: location
    storageAccountId: storage.outputs.id
  }
}

output resourceGroupName string = rg.name
output storageAccountName string = storage.outputs.name
output sqlServerName string = sql.outputs.serverName
output sqlDatabaseName string = sql.outputs.databaseName
output dataFactoryName string = adf.outputs.name
