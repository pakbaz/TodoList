@description('Log Analytics Workspace name')
param logAnalyticsName string

@description('Application Insights name')
param appInsightsName string

@description('Azure region for resource deployment')
param location string

@description('Resource tags')
param tags object

@description('Environment name')
param environment string

// Monitoring configuration based on environment
var monitoringConfig = {
  dev: {
    logAnalyticsRetentionInDays: 30
    appInsightsRetentionInDays: 30
    logAnalyticsSku: 'PerGB2018'
    appInsightsSamplingPercentage: 50
  }
  staging: {
    logAnalyticsRetentionInDays: 60
    appInsightsRetentionInDays: 60
    logAnalyticsSku: 'PerGB2018'
    appInsightsSamplingPercentage: 25
  }
  prod: {
    logAnalyticsRetentionInDays: 90
    appInsightsRetentionInDays: 90
    logAnalyticsSku: 'PerGB2018'
    appInsightsSamplingPercentage: 10
  }
}

var selectedConfig = monitoringConfig[environment]

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: selectedConfig.logAnalyticsSku
    }
    retentionInDays: selectedConfig.logAnalyticsRetentionInDays
    features: {
      searchVersion: 1
      legacy: 0
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// Application Insights
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    RetentionInDays: selectedConfig.appInsightsRetentionInDays
    SamplingPercentage: selectedConfig.appInsightsSamplingPercentage
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Action Group for alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-${environment}-todolist'
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'TodoAlert'
    enabled: true
    emailReceivers: []
    smsReceivers: []
    webhookReceivers: []
    azureAppPushReceivers: []
    itsmReceivers: []
    automationRunbookReceivers: []
    voiceReceivers: []
    logicAppReceivers: []
    azureFunctionReceivers: []
    armRoleReceivers: []
  }
}

// Alert Rules for Application Insights
resource appInsightsAvailabilityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-availability-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when application availability drops below threshold'
    severity: 2
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'AvailabilityResult'
          metricName: 'availabilityResults/availabilityPercentage'
          operator: 'LessThan'
          threshold: environment == 'prod' ? 99 : 95
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource appInsightsResponseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-response-time-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when average response time exceeds threshold'
    severity: 3
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ResponseTime'
          metricName: 'requests/duration'
          operator: 'GreaterThan'
          threshold: environment == 'prod' ? 2000 : 5000
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

resource appInsightsFailureRateAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'alert-failure-rate-${environment}'
  location: 'global'
  tags: tags
  properties: {
    description: 'Alert when failure rate exceeds threshold'
    severity: 1
    enabled: true
    scopes: [
      appInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'FailureRate'
          metricName: 'requests/failed'
          operator: 'GreaterThan'
          threshold: environment == 'prod' ? 5 : 10
          timeAggregation: 'Count'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// Workbook for monitoring dashboard
resource monitoringWorkbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: guid('${environment}-todolist-workbook')
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: 'TodoList Monitoring Dashboard - ${environment}'
    serializedData: string({
      version: 'Notebook/1.0'
      items: [
        {
          type: 1
          content: {
            json: '# TodoList Application Monitoring Dashboard\n\nThis dashboard provides insights into the TodoList application performance and health.'
          }
          name: 'text - dashboard title'
        }
        {
          type: 10
          content: {
            chartId: 'workbook-item-chart-1'
            version: 'MetricsItem/2.0'
            size: 0
            chartType: 2
            resourceType: 'microsoft.insights/components'
            metricScope: 0
            resourceIds: [
              appInsights.id
            ]
            timeContext: {
              durationMs: 3600000
            }
            metrics: [
              {
                namespace: 'microsoft.insights/components'
                metric: 'microsoft.insights/components-Kusto-requests/duration'
                aggregation: 4
              }
            ]
            title: 'Response Times'
          }
          name: 'metric - response times'
        }
      ]
      fallbackResourceIds: []
    })
    category: 'workbook'
    sourceId: appInsights.id
  }
}

// Outputs
@description('Log Analytics Workspace ID')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id

@description('Log Analytics Workspace Name')
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name

@description('Log Analytics Workspace Customer ID')
output logAnalyticsCustomerId string = logAnalyticsWorkspace.properties.customerId

@description('Application Insights ID')
output appInsightsId string = appInsights.id

@description('Application Insights Name')
output appInsightsName string = appInsights.name

@description('Application Insights Instrumentation Key')
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey

@description('Application Insights Connection String')
output appInsightsConnectionString string = appInsights.properties.ConnectionString

@description('Action Group ID')
output actionGroupId string = actionGroup.id
