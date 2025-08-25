using './main.bicep'

param namePrefix = 'todolist'
param environment = 'dev'
param imageTag = 'latest'

// Provide these via pipeline secret injection or local azd deployment
param pgAdminUser = 'pgadmin'
param pgAdminPassword = 'ChangeMe_123!'
