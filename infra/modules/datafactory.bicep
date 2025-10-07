param dataFactoryName string
param storageLinkedServiceName string = 'AzureBlobStorageLinkedService'
param sqlServerName string
param sqlDatabaseName string

//  Linked Service for SQL Database
resource linkedServiceSql 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${dataFactoryName}/AzureSqlDatabaseLinkedService'
  properties: {
    type: 'AzureSqlDatabase'
    typeProperties: {
      connectionString: 'Server=tcp:${sqlServerName}.${environment().suffixes.sqlServerHostname},1433;Database=${sqlDatabaseName};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication="SQL Password";'
    }
  }
}

// Dataset for Blob (CSV input)
resource datasetBlob 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: '${dataFactoryName}/InputBlobDataset'
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
  name: '${dataFactoryName}/OutputSQLDataset'
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

// Simple Pipeline that copies from Blob to SQL
resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${dataFactoryName}/etl-demo-pipeline'
  properties: {
    description: 'Demo ETL pipeline to copy data from Blob Storage to SQL Database'
    activities: [
      {
        name: 'CopyFromBlobToSQL'
        type: 'Copy'
        dependsOn: []
        policy: {
          timeout: '7.00:00:00'
          retry: 0
          retryIntervalInSeconds: 30
          secureOutput: false
          secureInput: false
        }
        typeProperties: {
          source: {
            type: 'DelimitedTextSource'
          }
          sink: {
            type: 'SqlSink'
          }
        }
        inputs: [
          {
            referenceName: 'InputBlobDataset'
            type: 'DatasetReference'
          }
        ]
        outputs: [
          {
            referenceName: 'OutputSQLDataset'
            type: 'DatasetReference'
          }
        ]
      }
    ]
  }
}

output pipelineName string = pipeline.name
