targetScope = 'resourceGroup'

// =================
// PARAMETERS
// =================

@description('The name of the Log Analytics workspace')
param logAnalyticsName string

@description('The name of the Application Insights instance')
param appInsightsName string

@description('The Azure region where resources will be deployed')
param location string = resourceGroup().location

@description('Tags to apply to all resources')
param tags object = {}

@description('Log Analytics workspace retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Log Analytics workspace pricing tier')
@allowed(['PerGB2018', 'Free', 'Standalone', 'PerNode', 'Standard', 'Premium'])
param sku string = 'PerGB2018'

// =================
// LOG ANALYTICS WORKSPACE
// =================

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
      disableLocalAuth: false
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// =================
// APPLICATION INSIGHTS
// =================

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    DisableIpMasking: false
    DisableLocalAuth: false
    ForceCustomerStorageForProfiler: false
  }
}

// =================
// DIAGNOSTIC SETTINGS - Temporarily disabled for deployment troubleshooting
// =================

// resource logAnalyticsDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${logAnalyticsName}-diagnostics'
//   scope: logAnalyticsWorkspace
//   properties: {
//     workspaceId: logAnalyticsWorkspace.id
//     logs: [
//       {
//         categoryGroup: 'allLogs'
//         enabled: true
//         retentionPolicy: {
//           enabled: false
//           days: 0
//         }
//       }
//     ]
//     metrics: [
//       {
//         category: 'AllMetrics'
//         enabled: true
//         retentionPolicy: {
//           enabled: false
//           days: 0
//         }
//       }
//     ]
//   }
// }

// =================
// OUTPUTS
// =================

@description('The resource ID of the Log Analytics workspace')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics workspace')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

@description('The workspace ID (customer ID) of the Log Analytics workspace')
output logAnalyticsCustomerId string = logAnalyticsWorkspace.properties.customerId

@description('The primary shared key of the Log Analytics workspace')
output logAnalyticsPrimarySharedKey string = logAnalyticsWorkspace.listKeys().primarySharedKey

@description('The resource ID of the Application Insights instance')
output appInsightsId string = appInsights.id

@description('The name of the Application Insights instance')
output appInsightsName string = appInsights.name

@description('The instrumentation key of the Application Insights instance')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('The connection string of the Application Insights instance')
output appInsightsConnectionString string = appInsights.properties.ConnectionString
