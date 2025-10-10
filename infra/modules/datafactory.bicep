param dataFactoryName string
param storageLinkedServiceName string = 'azureblobstoragelinkedservice'
param sqlServerName string
param sqlDatabaseName string
param storageAccountName string

// 1️⃣ Data Factory resource
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'   // 👈 this line enables managed identity
  }
}

// 2️⃣ Linked Service for Blob Storage
resource linkedServiceBlob 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  parent: dataFactory
  name: storageLinkedServiceName
  properties: {
    type: 'AzureBlobStorage'
    typeProperties: {
      connectionString: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage}'
    }
  }
}

// 3️⃣ Linked Service for SQL Database (using Managed Identity)
resource linkedServiceSql 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  parent: dataFactory
  name: 'azuresqldatabaselinkedservice'
  properties: {
    type: 'AzureSqlDatabase'
    typeProperties: {
      connectionString: 'Server=tcp:${sqlServerName}.${environment().suffixes.sqlServerHostname},1433;Database=${sqlDatabaseName};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
      // Use managed identity authentication
      servicePrincipalCredentialType: 'ManagedServiceIdentity'
    }
  }
}

// 4️⃣ Dataset for Blob (CSV input)
resource datasetBlob 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  parent: dataFactory
  name: 'InputBlobDataset'
  properties: {
    linkedServiceName: {
      referenceName: storageLinkedServiceName
      type: 'LinkedServiceReference'
    }
    type: 'DelimitedText'
    typeProperties: {
      location: {
        type: 'AzureBlobStorageLocation'
        folderPath: 'raw'
      }
      firstRowAsHeader: true
      columnDelimiter: ','
    }
  }
}

// 5️⃣ Dataset for SQL (Output)
resource datasetSql 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  parent: dataFactory
  name: 'OutputSQLDataset'
  properties: {
    linkedServiceName: {
      referenceName: 'azuresqldatabaselinkedservice'
      type: 'LinkedServiceReference'
    }
    type: 'AzureSqlTable'
    typeProperties: {
      tableName: 'SalesFact'
    }
  }
}


// 6️⃣ (Optional) Output values
output name string = dataFactory.name
output id string = dataFactory.id
output identityPrincipalId string = dataFactory.identity.principalId

