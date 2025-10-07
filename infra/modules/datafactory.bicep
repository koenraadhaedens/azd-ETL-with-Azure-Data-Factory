param name string
param location string
param storageAccountId string

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
}

resource linkedServiceStorage 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  parent: dataFactory
  name: 'AzureBlobStorageLinkedService'
  properties: {
    type: 'AzureBlobStorage'
    typeProperties: {
      connectionString: 'DefaultEndpointsProtocol=https;AccountName=${last(split(storageAccountId, '/'))};EndpointSuffix=${environment().suffixes.storage}'
    }
  }
}

output name string = dataFactory.name
output id string = dataFactory.id
