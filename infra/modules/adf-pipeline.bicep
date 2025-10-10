param dataFactoryName string

// Reference existing Data Factory
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName
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
