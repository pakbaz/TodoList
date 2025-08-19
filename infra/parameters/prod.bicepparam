using '../main.bicep'

// =================
// PRODUCTION ENVIRONMENT PARAMETERS
// =================

param appName = 'todolist'
param environment = 'prod'
param location = 'East US'
param imageTag = 'latest'
param databaseAdminUsername = 'dbadmin'
param databaseAdminPassword = readEnvironmentVariable('DATABASE_PASSWORD', 'ProductionPassword123!')
