@description('Container App Environment name')
param containerAppEnvironmentName string

@description('Container App name')
param containerAppName string

@description('Azure region for resource deployment')
param location string

@description('Resource tags')
param tags object

@description('Environment name')
param environment string

@description('Container Apps subnet ID')
param containerAppsSubnetId string

@description('Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('Container Registry Login Server')
param containerRegistryLoginServer string

@secure()
@description('Application Insights Connection String')
param appInsightsConnectionString string

@description('Key Vault URI')
param keyVaultUri string

@description('Managed Identity ID for Container App')
param managedIdentityId string

@description('Database Connection String Secret URI')
param databaseConnectionStringSecretUri string

// Container Apps configuration based on environment
var containerAppConfig = {
  dev: {
    minReplicas: 0
    maxReplicas: 3
    cpu: '0.25'
    memory: '0.5Gi'
    allowInsecure: true
    containerImage: '${containerRegistryLoginServer}/todolist:latest'
    httpScaleRule: {
      concurrentRequests: 100
    }
  }
  staging: {
    minReplicas: 1
    maxReplicas: 5
    cpu: '0.5'
    memory: '1Gi'
    allowInsecure: false
    containerImage: '${containerRegistryLoginServer}/todolist:latest'
    httpScaleRule: {
      concurrentRequests: 50
    }
  }
  prod: {
    minReplicas: 2
    maxReplicas: 10
    cpu: '1'
    memory: '2Gi'
    allowInsecure: false
    containerImage: '${containerRegistryLoginServer}/todolist:latest'
    httpScaleRule: {
      concurrentRequests: 30
    }
  }
}

var selectedConfig = containerAppConfig[environment]

// Container Apps Environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: containerAppEnvironmentName
  location: location
  tags: tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: containerAppsSubnetId
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2023-09-01').primarySharedKey
      }
    }
    zoneRedundant: environment == 'prod'
    kedaConfiguration: {}
    daprConfiguration: {}
    customDomainConfiguration: {
      certificatePassword: ''
      dnsSuffix: ''
    }
  }
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
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
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: selectedConfig.allowInsecure
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
          allowedHeaders: ['*']
          allowCredentials: false
        }
      }
      registries: [
        {
          server: containerRegistryLoginServer
          identity: managedIdentityId
        }
      ]
      secrets: [
        {
          name: 'connection-string'
          keyVaultUrl: databaseConnectionStringSecretUri
          identity: managedIdentityId
        }
        {
          name: 'appinsights-connection-string'
          value: appInsightsConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          image: selectedConfig.containerImage
          name: 'todolist'
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: environment == 'prod' ? 'Production' : (environment == 'staging' ? 'Staging' : 'Development')
            }
            {
              name: 'ConnectionStrings__DefaultConnection'
              secretRef: 'connection-string'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              secretRef: 'appinsights-connection-string'
            }
            {
              name: 'KeyVault__VaultUri'
              value: keyVaultUri
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:8080'
            }
            {
              name: 'ASPNETCORE_HTTP_PORTS'
              value: '8080'
            }
          ]
          resources: {
            cpu: json(selectedConfig.cpu)
            memory: selectedConfig.memory
          }
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
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
              initialDelaySeconds: 10
              periodSeconds: 5
              timeoutSeconds: 3
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: selectedConfig.minReplicas
        maxReplicas: selectedConfig.maxReplicas
        rules: [
          {
            name: 'http-scale-rule'
            http: {
              metadata: {
                concurrentRequests: string(selectedConfig.httpScaleRule.concurrentRequests)
              }
            }
          }
        ]
      }
    }
  }
}

// Diagnostic settings for Container App Environment
resource environmentDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'container-env-diagnostics'
  scope: containerAppEnvironment
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
  }
}

// Diagnostic settings for Container App
resource appDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'container-app-diagnostics'
  scope: containerApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: environment == 'prod' ? 90 : 30
        }
      }
    ]
  }
}

// Outputs
@description('Container App Environment ID')
output containerAppEnvironmentId string = containerAppEnvironment.id

@description('Container App Environment Name')
output containerAppEnvironmentName string = containerAppEnvironment.name

@description('Container App ID')
output containerAppId string = containerApp.id

@description('Container App Name')
output containerAppName string = containerApp.name

@description('Container App FQDN')
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn

@description('Container App URL')
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
