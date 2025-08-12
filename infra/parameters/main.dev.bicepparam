using '../main.bicep'

param environment = 'dev'
param applicationName = 'todolist'
param location = 'East US 2'
param postgresAdminLogin = 'todolistadmin'
param postgresAdminPassword = readEnvironmentVariable('POSTGRES_ADMIN_PASSWORD')
param logRetentionInDays = 30
param databaseSkuName = 'Standard_B1ms'
param databaseStorageSizeGB = 32
param enableDatabaseHA = false
param enableZoneRedundancy = false
param minReplicas = 0
param maxReplicas = 3
