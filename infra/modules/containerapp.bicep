@description('Location for Container App')
param location string

@description('Container App name')
param name string

@description('Container Apps Environment resource id')
param environmentId string

@description('Container image fully qualified name')
param containerImage string

@description('Container target port')
param targetPort int = 8080

@description('CPU cores as integer (0.5 not supported in schema; use 1 for 1 vCPU equivalent)')
param cpu int = 1

@description('Memory amount (e.g., 1Gi)')
param memory string = '1Gi'

@description('ACR login server (for image)')
param registryServer string

@description('Key Vault resource id for secret references')
param keyVaultId string

@description('Optional Application Insights connection string for SDK autocollection')
param appInsightsConnectionString string = ''

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: true
        targetPort: targetPort
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: registryServer
          identity: 'system'
        }
      ]
      secrets: [
        {
          name: 'default-connection'
          keyVaultUrl: '${reference(keyVaultId, '2023-07-01').properties.vaultUri}secrets/DefaultConnection'
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'todolist'
          image: containerImage
          resources: {
            cpu: cpu
            memory: memory
          }
          env: [
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:8080'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            {
              name: 'ConnectionStrings__DefaultConnection'
              secretRef: 'default-connection'
            }
          ]
        }
      ]
    }
  }
}

output fqdn string = app.properties.configuration.ingress.fqdn
output principalId string = app.identity.principalId
