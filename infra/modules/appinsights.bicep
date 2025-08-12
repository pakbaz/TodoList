param location string
param env string
param tags object

var appiName = toLower(uniqueString(resourceGroup().id, env, 'appi'))

resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: appiName
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    Request_Source: 'rest'
  }
}

output name string = appi.name
output connectionString string = appi.properties.ConnectionString
