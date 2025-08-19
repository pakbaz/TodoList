targetScope = 'resourceGroup'

// =================
// PARAMETERS
// =================

@description('The name of the Container App')
param containerAppName string

@description('The Azure region where resources will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('The resource ID of the Container Apps environment')
param containerAppsEnvironmentId string

@description('The resource ID of the managed identity')
param managedIdentityId string

@description('The name of the Azure Container Registry')
param acrName string

@description('The image tag to deploy')
param imageTag string

@description('The application name')
param appName string

@description('Minimum number of replicas')
@minValue(0)
@maxValue(30)
param minReplicas int = 1

@description('Maximum number of replicas')
@minValue(1)
@maxValue(30)
param maxReplicas int = 10

@description('CPU allocation')
param cpu string = '0.5'

@description('Memory allocation')
param memory string = '1Gi'

@description('The name of the Key Vault')
param keyVaultName string

@description('Application Insights connection string')
param appInsightsConnectionString string

@description('Enable external ingress')
param enableExternalIngress bool = true

// =================
// VARIABLES
// =================

var containerImage = '${acrName}.azurecr.io/${appName}:${imageTag}'

// =================
// CONTAINER APP
// =================

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironmentId
    configuration: {
      ingress: {
        external: enableExternalIngress
        targetPort: 8080
        transport: 'http'
        allowInsecure: false
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
      }
      registries: [
        {
          server: '${acrName}.azurecr.io'
          identity: managedIdentityId
        }
      ]
      secrets: [
        {
          name: 'connection-string'
          keyVaultUrl: 'https://${keyVaultName}.${environment().suffixes.keyvaultDns}/secrets/ConnectionStrings--DefaultConnection'
          identity: managedIdentityId
        }
      ]
      dapr: {
        enabled: false
      }
    }
    template: {
      revisionSuffix: imageTag
      containers: [
        {
          name: appName
          image: containerImage
          resources: {
            cpu: json(cpu)
            memory: memory
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:8080'
            }
            {
              name: 'ConnectionStrings__DefaultConnection'
              secretRef: 'connection-string'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: reference(managedIdentityId, '2023-01-31').clientId
            }
            {
              name: 'Logging__LogLevel__Default'
              value: 'Information'
            }
            {
              name: 'Logging__LogLevel__Microsoft.AspNetCore'
              value: 'Warning'
            }
            {
              name: 'Logging__LogLevel__Microsoft.EntityFrameworkCore'
              value: 'Information'
            }
          ]
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/health'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 5
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/health/ready'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 5
              periodSeconds: 5
              timeoutSeconds: 3
              failureThreshold: 3
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health/live'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 15
              periodSeconds: 30
              timeoutSeconds: 5
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-scaler'
            http: {
              metadata: {
                concurrentRequests: '30'
              }
            }
          }
          {
            name: 'cpu-scaler'
            custom: {
              type: 'cpu'
              metadata: {
                type: 'Utilization'
                value: '70'
              }
            }
          }
          {
            name: 'memory-scaler'
            custom: {
              type: 'memory'
              metadata: {
                type: 'Utilization'
                value: '80'
              }
            }
          }
        ]
      }
    }
  }
}

// =================
// OUTPUTS
// =================

@description('The resource ID of the Container App')
output containerAppId string = containerApp.id

@description('The name of the Container App')
output containerAppName string = containerApp.name

@description('The FQDN of the Container App')
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn

@description('The latest revision name')
output latestRevisionName string = containerApp.properties.latestRevisionName

@description('The latest revision FQDN')
output latestRevisionFqdn string = containerApp.properties.latestRevisionFqdn
