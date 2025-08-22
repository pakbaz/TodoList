@description('The location for resources')
param location string

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('The application name')
param applicationName string

@description('Resource tags for cost tracking and governance')
param tags object = {}

@description('Container Apps Environment ID')
param containerAppEnvironmentId string

@description('Container Registry login server')
param containerRegistryLoginServer string

@description('Container image name and tag')
param containerImage string = '${containerRegistryLoginServer}/${applicationName}:latest'

@description('Key Vault URI')
param keyVaultUri string

@description('Enable ingress')
param enableIngress bool = true

@description('Target port for the container')
param targetPort int = 8080

@description('CPU and memory resources')
param resources object = {
  cpu: environmentName == 'prod' ? '1.0' : '0.5'
  memory: environmentName == 'prod' ? '2Gi' : '1Gi'
}

@description('Replica count settings')
param replicas object = {
  min: environmentName == 'prod' ? 2 : 1
  max: environmentName == 'prod' ? 10 : 3
}

// Variables
var containerAppName = 'ca-${applicationName}-${environmentName}-${uniqueString(resourceGroup().id)}'

// Container App with managed identity
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppEnvironmentId
    configuration: {
      ingress: enableIngress ? {
        external: true
        targetPort: targetPort
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      } : null
      registries: [
        {
          server: containerRegistryLoginServer
          identity: 'system'
        }
      ]
      secrets: [
        {
          name: 'appinsights-connection-string'
          keyVaultUrl: '${keyVaultUri}secrets/appinsights-connection-string'
          identity: 'system'
        }
        {
          name: 'postgresql-connection-string'
          keyVaultUrl: '${keyVaultUri}secrets/postgresql-passwordless-connection-string'
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: applicationName
          image: containerImage
          resources: {
            cpu: json(resources.cpu)
            memory: resources.memory
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: environmentName == 'prod' ? 'Production' : 'Development'
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:${targetPort}'
            }
            {
              name: 'ASPNETCORE_FORWARDEDHEADERS_ENABLED'
              value: 'true'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'appinsights-connection-string'
            }
            {
              name: 'ConnectionStrings__DefaultConnection'
              secretRef: 'postgresql-connection-string'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: 'system'
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
              timeoutSeconds: 5
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health/ready'
                port: targetPort
                scheme: 'HTTP'
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: replicas.min
        maxReplicas: replicas.max
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
output containerAppId string = containerApp.id
output containerAppName string = containerApp.name
output containerAppFqdn string = enableIngress ? containerApp.properties.configuration.ingress.fqdn : ''
output principalId string = containerApp.identity.principalId
