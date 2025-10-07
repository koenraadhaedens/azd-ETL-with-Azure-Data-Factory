param dataFactoryName string

// Example simple pipeline JSON definition inline
resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: '${dataFactoryName}/etl-demo-pipeline'
  properties: {
    description: 'ETL demo pipeline that copies data from Blob Storage to SQL Database'
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
