@description('The location used for all deployed resources')
param location string = resourceGroup().location

@description('Tags that will be applied to all resources')
param tags object = {}


param todoListExists bool

@description('Id of the user or app to assign application roles')
param principalId string

@description('Principal type of user or app')
param principalType string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = uniqueString(subscription().id, resourceGroup().id, location)

// Monitor application with Azure Monitor
module monitoring 'br/public:avm/ptn/azd/monitoring:0.1.0' = {
  name: 'monitoring'
  params: {
    logAnalyticsName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: '${abbrs.portalDashboards}${resourceToken}'
    location: location
    tags: tags
  }
}

// Key Vault for secrets management
module keyVault 'br/public:avm/res/key-vault/vault:0.6.1' = {
  name: 'keyVault'
  params: {
    name: '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    enableRbacAuthorization: true
    roleAssignments: [
      {
        principalId: todoListIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
      }
    ]
  }
}

// PostgreSQL Flexible Server for database
module postgreSqlServer 'br/public:avm/res/db-for-postgre-sql/flexible-server:0.1.4' = {
  name: 'postgreSqlServer'
  params: {
    name: '${abbrs.dBforPostgreSQLServers}${resourceToken}'
    location: location
    tags: tags
    administratorLogin: 'todolistadmin'
    administratorLoginPassword: 'TodoList123!@#'
    skuName: 'Standard_B1ms'
    tier: 'Burstable'
    storageSizeGB: 32
    version: '15'
    databases: [
      {
        name: 'todolistdb'
      }
    ]
    highAvailability: 'Disabled'
    configurations: [
      {
        name: 'azure.extensions'
        value: 'uuid-ossp'
        source: 'user-override'
      }
    ]
  }
}

// Store database connection string in Key Vault as a separate resource
resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${abbrs.keyVaultVaults}${resourceToken}/postgresql-connection-string'
  properties: {
    value: 'Host=${postgreSqlServer.outputs.fqdn};Database=todolistdb;Username=todolistadmin;Password=TodoList123!@#;SSL Mode=Require;Trust Server Certificate=true'
  }
  tags: tags
}
// Container registry
module containerRegistry 'br/public:avm/res/container-registry/registry:0.1.1' = {
  name: 'registry'
  params: {
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccess: 'Enabled'
    roleAssignments:[
      {
        principalId: todoListIdentity.outputs.principalId
        principalType: 'ServicePrincipal'
        roleDefinitionIdOrName: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
      }
    ]
  }
}

// Container apps environment
module containerAppsEnvironment 'br/public:avm/res/app/managed-environment:0.4.5' = {
  name: 'container-apps-environment'
  params: {
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceResourceId
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    zoneRedundant: false
  }
}

module todoListIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.2.1' = {
  name: 'todoListidentity'
  params: {
    name: '${abbrs.managedIdentityUserAssignedIdentities}todoList-${resourceToken}'
    location: location
  }
}
module todoListFetchLatestImage './modules/fetch-container-image.bicep' = {
  name: 'todoList-fetch-image'
  params: {
    exists: todoListExists
    name: 'todo-list'
  }
}

module todoList 'br/public:avm/res/app/container-app:0.8.0' = {
  name: 'todoList'
  params: {
    name: 'todo-list'
    ingressTargetPort: 8080
    scaleMinReplicas: 1
    scaleMaxReplicas: 10
    secrets: {
      secureList: [
        {
          name: 'postgresql-connection-string'
          keyVaultUrl: 'https://${keyVault.outputs.name}.${environment().suffixes.keyvaultDns}/secrets/postgresql-connection-string'
          identity: todoListIdentity.outputs.resourceId
        }
      ]
    }
    containers: [
      {
        image: todoListFetchLatestImage.outputs.?containers[?0].?image ?? 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        name: 'main'
        resources: {
          cpu: json('0.5')
          memory: '1.0Gi'
        }
        env: [
          {
            name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
            value: monitoring.outputs.applicationInsightsConnectionString
          }
          {
            name: 'AZURE_CLIENT_ID'
            value: todoListIdentity.outputs.clientId
          }
          {
            name: 'PORT'
            value: '8080'
          }
          {
            name: 'ConnectionStrings__DefaultConnection'
            secretRef: 'postgresql-connection-string'
          }
          {
            name: 'ASPNETCORE_ENVIRONMENT'
            value: 'Production'
          }
        ]
      }
    ]
    managedIdentities:{
      systemAssigned: false
      userAssignedResourceIds: [todoListIdentity.outputs.resourceId]
    }
    registries:[
      {
        server: containerRegistry.outputs.loginServer
        identity: todoListIdentity.outputs.resourceId
      }
    ]
    environmentResourceId: containerAppsEnvironment.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'todo-list' })
  }
}
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_RESOURCE_TODO_LIST_ID string = todoList.outputs.resourceId
