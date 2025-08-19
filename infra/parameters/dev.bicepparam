using '../main.bicep'

// =================
// DEVELOPMENT ENVIRONMENT PARAMETERS
// =================

param appName = 'todolist'
param environment = 'dev'
param location = 'East US'
param imageTag = 'latest'
param databaseAdminUsername = 'dbadmin'
param databaseAdminPassword = readEnvironmentVariable('DATABASE_PASSWORD', 'DevPassword123!')
