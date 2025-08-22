@description('The location for the resource group')
param location string = resourceGroup().location

@description('The environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('The application name')
param applicationName string

@description('Resource tags for cost tracking and governance')
param tags object = {}

// Variables for consistent naming
var resourceTags = union(tags, {
  Environment: environmentName
  Application: applicationName
  ManagedBy: 'Infrastructure as Code'
})

// The resource group is already created, we just need to return its info
output resourceGroupName string = resourceGroup().name
output resourceGroupId string = resourceGroup().id
output location string = location
output tags object = resourceTags
