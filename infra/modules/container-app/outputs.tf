# Container App module outputs

output "container_app_id" {
  description = "The ID of the Container App"
  value       = azurerm_container_app.main.id
}

output "container_app_name" {
  description = "The name of the Container App"
  value       = azurerm_container_app.main.name
}

output "container_app_fqdn" {
  description = "The FQDN of the Container App"
  value       = var.enable_ingress ? azurerm_container_app.main.ingress[0].fqdn : null
}

output "container_app_url" {
  description = "The URL of the Container App"
  value       = var.enable_ingress ? "https://${azurerm_container_app.main.ingress[0].fqdn}" : null
}

output "latest_revision_name" {
  description = "The name of the latest revision"
  value       = azurerm_container_app.main.latest_revision_name
}

output "latest_revision_fqdn" {
  description = "The FQDN of the latest revision"
  value       = azurerm_container_app.main.latest_revision_fqdn
}

output "outbound_ip_addresses" {
  description = "List of outbound IP addresses"
  value       = azurerm_container_app.main.outbound_ip_addresses
}

output "custom_domain_verification_id" {
  description = "Custom domain verification ID"
  value       = azurerm_container_app.main.custom_domain_verification_id
}

output "identity_principal_id" {
  description = "The principal ID of the system assigned managed identity"
  value       = var.enable_managed_identity ? azurerm_container_app.main.identity[0].principal_id : null
}

output "identity_tenant_id" {
  description = "The tenant ID of the system assigned managed identity"  
  value       = var.enable_managed_identity ? azurerm_container_app.main.identity[0].tenant_id : null
}
