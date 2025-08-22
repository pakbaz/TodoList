output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.resource_group.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = module.resource_group.location
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = module.networking.vnet_id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.networking.vnet_name
}

output "container_apps_subnet_id" {
  description = "ID of the Container Apps subnet"
  value       = module.networking.container_apps_subnet_id
}

output "private_endpoint_subnet_id" {
  description = "ID of the private endpoints subnet"
  value       = module.networking.private_endpoint_subnet_id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.log_analytics.workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = module.log_analytics.workspace_name
}

output "application_insights_id" {
  description = "ID of the Application Insights instance"
  value       = module.log_analytics.application_insights_id
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = module.log_analytics.application_insights_instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = module.log_analytics.application_insights_connection_string
  sensitive   = true
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = module.key_vault.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = module.key_vault.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = module.key_vault.vault_uri
}

output "container_registry_id" {
  description = "ID of the Container Registry"
  value       = module.container_registry.id
}

output "container_registry_name" {
  description = "Name of the Container Registry"
  value       = module.container_registry.name
}

output "container_registry_login_server" {
  description = "Login server URL of the Container Registry"
  value       = module.container_registry.login_server
}

output "postgresql_server_id" {
  description = "ID of the PostgreSQL server"
  value       = module.postgresql.server_id
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL server"
  value       = module.postgresql.server_name
}

output "postgresql_server_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = module.postgresql.server_fqdn
}

output "postgresql_database_name" {
  description = "Name of the PostgreSQL database"
  value       = "todolistdb"
}

output "container_apps_environment_id" {
  description = "ID of the Container Apps environment"
  value       = module.container_apps_environment.id
}

output "container_apps_environment_name" {
  description = "Name of the Container Apps environment"
  value       = module.container_apps_environment.name
}

output "container_apps_environment_static_ip" {
  description = "Static IP address of the Container Apps environment"
  value       = module.container_apps_environment.static_ip_address
}

output "todolist_app_id" {
  description = "ID of the TodoList container app"
  value       = module.todolist_app.id
}

output "todolist_app_name" {
  description = "Name of the TodoList container app"
  value       = module.todolist_app.name
}

output "todolist_app_url" {
  description = "URL of the TodoList application"
  value       = module.todolist_app.application_url
}

output "todolist_app_managed_identity_id" {
  description = "Managed identity ID of the TodoList app"
  value       = module.todolist_app.managed_identity_id
}

output "todolist_app_managed_identity_principal_id" {
  description = "Managed identity principal ID of the TodoList app"
  value       = module.todolist_app.managed_identity_principal_id
}

# Deployment information
output "deployment_info" {
  description = "Deployment information summary"
  value = {
    app_name        = var.app_name
    environment     = var.environment
    location        = var.location
    resource_group  = module.resource_group.name
    app_url         = module.todolist_app.application_url
    deployed_image  = var.container_image
    deployment_time = timestamp()
  }
}
