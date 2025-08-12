// Container App module
targetScope = 'resourceGroup'

@description('The name of the Container App')
param appName string

@description('Location for the Container App')
param location string = resourceGroup().location

@description('Container Apps Environment ID')
param environmentId string

@description('Container image')
param containerImage string

@description('Container registry server')
param registryServer string

@description('Key Vault name for secrets')
param keyVaultName string

@description('Minimum number of replicas')
param minReplicas int = 0

@description('Maximum number of replicas')
param maxReplicas int = 3

@description('Tags to apply to the Container App')
param tags object = {}

@description('Target port for the container')
param targetPort int = 8080

@description('CPU limit')
param cpuLimit string = '0.5'

@description('Memory limit')
param memoryLimit string = '1Gi'

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: targetPort
        transport: 'http'
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        stickySessions: {
          affinity: 'sticky'
        }
      }
      registries: [
        {
          server: registryServer
          identity: 'system'
        }
      ]
      secrets: [
        {
          name: 'connection-string'
          keyVaultUrl: 'https://${keyVaultName}.${environment().suffixes.keyvaultDns}/secrets/ConnectionStrings--DefaultConnection'
          identity: 'system'
        }
        {
          name: 'app-insights-connection-string'
          keyVaultUrl: 'https://${keyVaultName}.${environment().suffixes.keyvaultDns}/secrets/ApplicationInsights--ConnectionString'
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'todolist-app'
          image: containerImage
          resources: {
            cpu: json(cpuLimit)
            memory: memoryLimit
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:${targetPort}'
            }
            {
              name: 'ConnectionStrings__DefaultConnection'
              secretRef: 'connection-string'
            }
            {
              name: 'ApplicationInsights__ConnectionString'
              secretRef: 'app-insights-connection-string'
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: targetPort
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 30
              timeoutSeconds: 10
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: targetPort
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
            }
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: targetPort
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 30
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

// Outputs
output appId string = containerApp.id
output appName string = containerApp.name
output appUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output principalId string = containerApp.identity.principalId
