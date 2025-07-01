// Simplified Bicep template for TodoList Container App deployment
targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name of the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string = resourceGroup().location

@description('Name of the resource group')
param resourceGroupName string

@description('Docker image tag for the application')
param imageTag string = 'latest'

// Generate a unique resource token based on environment name and resource group id
var resourceToken = toLower(uniqueString(subscription().id, resourceGroup().id, environmentName))
var prefix = take(resourceToken, 10) // Keep it short to avoid naming conflicts

// Tags to be applied to all resources
var tags = {
  Environment: environmentName
  Application: 'TodoList'
  ManagedBy: 'GitHubActions'
  'azd-env-name': environmentName
}

// ================================================================================================
// CORE INFRASTRUCTURE
// ================================================================================================

// Log Analytics Workspace for monitoring
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${prefix}-log'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights for application monitoring
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${prefix}-appinsights'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Container Registry for storing container images
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: replace('${prefix}acr', '-', '')
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

// ================================================================================================
// CONTAINER APPS ENVIRONMENT
// ================================================================================================

// Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${prefix}-env'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    zoneRedundant: false
  }
}

// ================================================================================================
// IDENTITIES AND RBAC
// ================================================================================================

// User-assigned managed identity for the container app
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${prefix}-identity'
  location: location
  tags: tags
}

// Grant the managed identity access to pull from Container Registry
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, managedIdentity.id, 'AcrPull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ================================================================================================
// CONTAINER APP
// ================================================================================================

// TodoList Container App
resource todolistApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${prefix}-app'
  location: location
  tags: union(tags, {
    'azd-service-name': 'todolist-app'
  })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
        transport: 'http'
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
          allowedHeaders: ['*']
          allowCredentials: false
        }
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: managedIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'todolist-app'
          image: '${containerRegistry.properties.loginServer}/todolist-app:${imageTag}'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'ConnectionStrings__SqliteConnection'
              value: 'Data Source=/tmp/todolist.db'
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: applicationInsights.properties.ConnectionString
            }
            {
              name: 'ASPNETCORE_URLS'
              value: 'http://+:8080'
            }
          ]
          probes: [
            {
              type: 'Readiness'
              httpGet: {
                path: '/health'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              timeoutSeconds: 5
              failureThreshold: 3
            }
            {
              type: 'Liveness'
              httpGet: {
                path: '/health'
                port: 8080
                scheme: 'HTTP'
              }
              initialDelaySeconds: 30
              periodSeconds: 30
              timeoutSeconds: 10
              failureThreshold: 3
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'http-scaling'
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
  dependsOn: [
    acrPullRole
  ]
}

// ================================================================================================
// OUTPUTS
// ================================================================================================

@description('The name of the resource group')
output resourceGroupName string = resourceGroupName

@description('Resource group ID')
output RESOURCE_GROUP_ID string = resourceGroup().id

@description('The name of the Container Apps environment')
output containerAppsEnvironmentName string = containerAppsEnvironment.name

@description('The name of the Container Registry')
output containerRegistryName string = containerRegistry.name

@description('The login server of the Container Registry')
output containerRegistryLoginServer string = containerRegistry.properties.loginServer

@description('The container registry endpoint')
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer

@description('The URL of the TodoList app')
output todolistAppUrl string = 'https://${todolistApp.properties.configuration.ingress.fqdn}'

output containerAppName string = todolistApp.name

@description('The name of the managed identity')
output managedIdentityName string = managedIdentity.name

@description('The client ID of the managed identity')
output managedIdentityClientId string = managedIdentity.properties.clientId

@description('The principal ID of the managed identity')
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
