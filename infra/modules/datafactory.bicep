param dataFactoryName string
param storageLinkedServiceName string = 'AzureBlobStorageLinkedService'
param sqlServerName string
param sqlDatabaseName string

// Data Factory resource
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: dataFactoryName
  location: resourceGroup().location
}

//  Linked Service for SQL Database
resource linkedServiceSql 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  parent: dataFactory
  name: 'AzureSqlDatabaseLinkedService'
  properties: {
    type: 'AzureSqlDatabase'
    typeProperties: {
      connectionString: 'Server=tcp:${sqlServerName}.${environment().suffixes.sqlServerHostname},1433;Database=${sqlDatabaseName};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication="SQL Password";'
    }
  }
}

// Dataset for Blob (CSV input)
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

// Dataset for SQL (Output)
resource datasetSql 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'OutputSQLDataset'
  parent: dataFactory
  properties: {
    linkedServiceName: {
      referenceName: 'AzureSqlDatabaseLinkedService'
      type: 'LinkedServiceReference'
    }
    type: 'AzureSqlTable'
    typeProperties: {
      tableName: 'SalesFact'
    }
  }
}



output name string = dataFactory.name
output id string = dataFactory.id

