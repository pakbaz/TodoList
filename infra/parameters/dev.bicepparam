using '../main.bicep'

param environmentName = 'dev'
param applicationName = 'todolist'
param postgresAdminLogin = 'todolistadmin'
param postgresAdminPassword = readEnvironmentVariable('POSTGRES_ADMIN_PASSWORD', 'DefaultPassword123!')
param deploymentPrincipalId = readEnvironmentVariable('AZURE_CLIENT_ID', '00000000-0000-0000-0000-000000000000')
