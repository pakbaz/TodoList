# Output values for TodoList infrastructure

output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "container_registry_name" {
  description = "The name of the Container Registry"
  value       = azurerm_container_registry.main.name
}

output "container_registry_login_server" {
  description = "The login server URL for the Container Registry"
  value       = azurerm_container_registry.main.login_server
}

output "postgresql_fqdn" {
  description = "The FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
  sensitive   = false
}

output "database_name" {
  description = "The name of the database"
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "container_app_environment_id" {
  description = "The ID of the Container App Environment"
  value       = azurerm_container_app_environment.main.id
}

output "container_app_name" {
  description = "The name of the Container App"
  value       = azurerm_container_app.main.name
}

output "todolist_app_url" {
  description = "The URL of the TodoList application"
  value       = "https://${azurerm_container_app.main.latest_revision_fqdn}"
}

output "app_url" {
  description = "The URL of the application (alias for todolist_app_url)"
  value       = "https://${azurerm_container_app.main.latest_revision_fqdn}"
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}
