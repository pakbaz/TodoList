# Key Vault module outputs

output "key_vault_id" {
  description = "The ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "The name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "The URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "private_endpoint_id" {
  description = "The ID of the private endpoint"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.key_vault[0].id : null
}

output "private_endpoint_fqdn" {
  description = "The FQDN of the private endpoint"
  value       = var.enable_private_endpoint ? azurerm_private_endpoint.key_vault[0].custom_dns_configs[0].fqdn : null
}

output "database_connection_string_secret_name" {
  description = "Name of the database connection string secret"
  value       = var.database_connection_string != null ? azurerm_key_vault_secret.database_connection_string[0].name : null
}

output "application_insights_connection_string_secret_name" {
  description = "Name of the Application Insights connection string secret"
  value       = var.application_insights_connection_string != null ? azurerm_key_vault_secret.application_insights_connection_string[0].name : null
}
