using '../main.bicep'

// =================
// STAGING ENVIRONMENT PARAMETERS
// =================

param appName = 'todolist'
param environment = 'staging'
param location = 'East US'
param imageTag = 'latest'
param databaseAdminUsername = 'dbadmin'
param databaseAdminPassword = readEnvironmentVariable('DATABASE_PASSWORD', 'StagingPassword123!')
