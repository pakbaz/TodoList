# Container Apps Environment module outputs

output "environment_id" {
  description = "The ID of the Container App Environment"
  value       = azurerm_container_app_environment.main.id
}

output "environment_name" {
  description = "The name of the Container App Environment"
  value       = azurerm_container_app_environment.main.name
}

output "default_domain" {
  description = "The default domain of the Container App Environment"
  value       = azurerm_container_app_environment.main.default_domain
}

output "static_ip_address" {
  description = "The static IP address of the Container App Environment"
  value       = azurerm_container_app_environment.main.static_ip_address
}

output "docker_bridge_cidr" {
  description = "The Docker bridge CIDR for the Container App Environment"
  value       = azurerm_container_app_environment.main.docker_bridge_cidr
}

output "platform_reserved_cidr" {
  description = "The platform reserved CIDR for the Container App Environment"
  value       = azurerm_container_app_environment.main.platform_reserved_cidr
}

output "platform_reserved_dns_ip_address" {
  description = "The platform reserved DNS IP address for the Container App Environment"
  value       = azurerm_container_app_environment.main.platform_reserved_dns_ip_address
}

output "managed_identity_id" {
  description = "The ID of the user assigned managed identity"
  value       = azurerm_user_assigned_identity.container_app_env.id
}

output "managed_identity_principal_id" {
  description = "The principal ID of the user assigned managed identity"
  value       = azurerm_user_assigned_identity.container_app_env.principal_id
}

output "managed_identity_client_id" {
  description = "The client ID of the user assigned managed identity"
  value       = azurerm_user_assigned_identity.container_app_env.client_id
}

output "managed_identity_tenant_id" {
  description = "The tenant ID of the user assigned managed identity"
  value       = azurerm_user_assigned_identity.container_app_env.tenant_id
}

output "certificate_ids" {
  description = "Map of certificate names to their IDs"
  value = {
    for name, cert in azurerm_container_app_environment_certificate.custom_domain :
    name => cert.id
  }
}
