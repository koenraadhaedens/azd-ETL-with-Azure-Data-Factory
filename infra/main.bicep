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

@description('Azure Data Factory IP ranges for SQL Server firewall. Update these based on your deployment region.')
@metadata({
  note: 'These IP ranges are region-specific for Azure Data Factory Integration Runtime'
  documentation: 'https://docs.microsoft.com/en-us/azure/data-factory/data-movement-security-considerations#azure-ir-ip-addresses'
  instructions: 'Replace with IP ranges for your specific Azure region where ADF is deployed'
})
param dataFactoryIPRanges array = [
  { start: '20.42.2.0', end: '20.42.2.255' }   // East US ADF Integration Runtime IPs
  { start: '20.42.4.0', end: '20.42.4.255' }   // East US ADF Integration Runtime IPs  
  { start: '20.42.5.0', end: '20.42.5.255' }   // East US ADF Integration Runtime IPs
  { start: '40.71.14.32', end: '40.71.14.63' } // East US ADF Integration Runtime IPs
]


resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: {
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'}
}



// Variables for naming conventions
var projectPrefix = toLower(environmentName)
var uniqueSuffix = uniqueString(rg.id)
var storageName = take('${projectPrefix}store${uniqueSuffix}', 24)
var sqlServerName = take('${projectPrefix}sql${uniqueSuffix}', 60)
var sqlDbName = 'salesdb'
var adfName = take('${projectPrefix}adf${uniqueSuffix}', 60)

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
    dataFactoryIPRanges: dataFactoryIPRanges
  }
}

// Deploy Database Tables with AAD configuration
module sqlTables 'modules/sql-tables-with-aad.bicep' = {
  name: 'sqlTablesDeploy'
  scope: rg
  params: {
    sqlServerName: sql.outputs.serverName
    databaseName: sql.outputs.databaseName
    location: location
    sqlAdminPassword: sqlAdminPassword
    dataFactoryPrincipalId: adf.outputs.identityPrincipalId
    dataFactoryName: adfName
  }
}

// Deploy Azure Data Factory
module adf 'modules/datafactory.bicep' = {
  name: 'adfDeploy'
  scope: rg
  params: {
    dataFactoryName: adfName
    sqlServerName: sql.outputs.serverName
    sqlDatabaseName: sql.outputs.databaseName
    storageAccountName: storage.outputs.name 
  }
}

module adfIdentity 'modules/adf-identity.bicep' = {
  name: 'adfIdentitySetup'
  scope: rg
  dependsOn: [
    adf   
  ]
  params: {
    dataFactoryName: adfName
    storageAccountId: storage.outputs.id
  }
}

module adfPipeline 'modules/adf-pipeline.bicep' = {
  name: 'adfPipelineDeploy'
  scope: rg
  dependsOn: [
    adf
    sqlTables   // Ensure database setup is complete
    adfIdentity // Ensure identity permissions are set up
  ]
  params: {
    dataFactoryName: adfName
  }
}


output resourceGroupName string = rg.name
output storageAccountName string = storage.outputs.name
output sqlServerName string = sql.outputs.serverName
output sqlDatabaseName string = sql.outputs.databaseName

