param dataFactoryName string
param storageLinkedServiceName string = 'azureblobstoragelinkedservice'

// Reference existing Data Factory
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
}

// Reference existing linked services (don't create them here as they're created in datafactory.bicep)
resource linkedServiceStorage 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' existing = {
  parent: dataFactory
  name: storageLinkedServiceName
}

resource linkedServiceSql 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' existing = {
  parent: dataFactory
  name: 'azuresqldatabaselinkedservice'
}

// 3️⃣ Dataset for Blob (CSV input)
resource datasetBlob 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  parent: dataFactory
  name: 'InputBlobDataset'
  dependsOn: [ linkedServiceStorage ]  
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
  parent: dataFactory
  name: 'OutputSQLDataset'
  dependsOn: [ linkedServiceSql ]   
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

// 5️⃣ Pipeline
resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  parent: dataFactory
  name: 'etl-demo-pipeline'
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
