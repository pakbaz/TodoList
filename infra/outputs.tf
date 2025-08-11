# Resource Group
output "resource_group_name" {
  description = "Name of the resource group"
  value       = local.resource_group_name
}

# Container Registry
output "container_registry_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.main.name
}

output "container_registry_login_server" {
  description = "Login server URL for the container registry"
  value       = azurerm_container_registry.main.login_server
}

# Container App Outputs
output "container_app_name" {
  description = "Name of the Container App"
  value       = module.container_app.container_app_name
}

output "container_app_fqdn" {
  description = "FQDN of the Container App"
  value       = module.container_app.fqdn
}

output "container_app_url" {
  description = "URL of the Container App"
  value       = "https://${module.container_app.fqdn}"
}

# PostgreSQL Outputs
output "postgres_server_name" {
  description = "Name of the PostgreSQL server"
  value       = module.postgres.server_name
}

output "postgres_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = module.postgres.fqdn
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string"
  value       = module.postgres.connection_string
  sensitive   = true
}

# Monitoring Outputs
output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = module.monitoring.app_insights_connection_string
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = module.monitoring.log_analytics_workspace_id
}
