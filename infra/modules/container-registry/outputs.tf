# Container Registry module outputs

output "registry_id" {
  description = "The ID of the Container Registry"
  value       = azurerm_container_registry.main.id
}

output "registry_name" {
  description = "The name of the Container Registry"
  value       = azurerm_container_registry.main.name
}

output "login_server" {
  description = "The URL that can be used to log into the container registry"
  value       = azurerm_container_registry.main.login_server
}

output "admin_username" {
  description = "The Username associated with the Container Registry Admin account"
  value       = azurerm_container_registry.main.admin_username
  sensitive   = true
}

output "admin_password" {
  description = "The Password associated with the Container Registry Admin account"
  value       = azurerm_container_registry.main.admin_password
  sensitive   = true
}

output "identity_principal_id" {
  description = "The Principal ID of the System Assigned Managed Identity"
  value       = azurerm_container_registry.main.identity[0].principal_id
}

output "identity_tenant_id" {
  description = "The Tenant ID of the System Assigned Managed Identity"
  value       = azurerm_container_registry.main.identity[0].tenant_id
}

output "private_endpoint_id" {
  description = "The ID of the private endpoint"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.acr[0].id : null
}

output "private_endpoint_fqdn" {
  description = "The FQDN of the private endpoint"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.acr[0].custom_dns_configs[0].fqdn : null
}
