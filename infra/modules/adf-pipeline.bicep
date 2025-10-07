param dataFactoryName string
param sqlServerName string
param sqlDatabaseName string
param storageLinkedServiceName string = 'AzureBlobStorageLinkedService'

// 1️⃣ Linked Service for Blob Storage
resource linkedServiceStorage 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${dataFactoryName}/${storageLinkedServiceName}'
  properties: {
    type: 'AzureBlobStorage'
    typeProperties: {
      connectionString: 'DefaultEndpointsProtocol=https;AccountName=${dataFactoryName};EndpointSuffix=core.windows.net;'
    }
  }
}

// 2️⃣ Linked Service for SQL Database
resource linkedServiceSql 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: '${dataFactoryName}/AzureSqlDatabaseLinkedService'
  properties: {
    type: 'AzureSqlDatabase'
    typeProperties: {
      connectionString: 'Server=tcp:${sqlServerName}.${environment().suffixes.sqlServerHostname},1433;Database=${sqlDatabaseName};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication="SQL Password";'
    }
  }
}

// 3️⃣ Dataset for Blob (CSV input)
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

// 4️⃣ Dataset for SQL (Output)
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

// 5️⃣ Pipeline
resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${dataFactoryName}/etl-demo-pipeline'
  properties: {
    description: 'ETL pipeline to copy data from Blob Storage to SQL Database'
    activities: [
      {
        name: 'CopyFromBlobToSQL'
        type: 'Copy'
        dependsOn: []
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
