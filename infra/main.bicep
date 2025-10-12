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
var vnetName = '${projectPrefix}-vnet'

// Deploy Virtual Network
module vnet 'modules/vnet.bicep' = {
  scope: rg
  params: {
    name: vnetName
    location: location
  }
}

// Deploy the Storage Account with VNet integration
module storage 'modules/storage.bicep' = {
  scope: rg
  params: {
    name: storageName
    location: location
    subnetId: vnet.outputs.storageSubnetId
    vnetName: vnet.outputs.vnetName
  }
}

// Deploy SQL Server + Database with VNet integration
module sql 'modules/sql.bicep' = {
  scope: rg
  params: {
    name: sqlServerName
    dbName: sqlDbName
    location: location
    administratorPassword: sqlAdminPassword
    subnetId: vnet.outputs.sqlSubnetId
    vnetName: vnet.outputs.vnetName
  }
}

// Deploy Azure Data Factory with managed VNet and private endpoints
module adf 'modules/datafactory.bicep' = {
  scope: rg
  params: {
    name: adfName
    location: location
    storageAccountId: storage.outputs.id
    sqlServerId: sql.outputs.serverId
    sqlServerName: sql.outputs.serverName
    subnetId: vnet.outputs.adfSubnetId
    vnetName: vnet.outputs.vnetName
  }
}

output resourceGroupName string = rg.name
output vnetName string = vnet.outputs.vnetName
output storageAccountName string = storage.outputs.name
output sqlServerName string = sql.outputs.serverName
output sqlServerFqdn string = sql.outputs.fullyQualifiedDomainName
output sqlDatabaseName string = sql.outputs.databaseName
output dataFactoryName string = adf.outputs.name
output adfPrivateEndpointId string = adf.outputs.privateEndpointId
