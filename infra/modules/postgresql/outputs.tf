# PostgreSQL module outputs

output "server_id" {
  description = "The ID of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.id
}

output "server_name" {
  description = "The name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "server_fqdn" {
  description = "The FQDN of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "database_id" {
  description = "The ID of the PostgreSQL database"
  value       = azurerm_postgresql_flexible_server_database.main.id
}

output "database_name" {
  description = "The name of the PostgreSQL database"
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "administrator_login" {
  description = "The administrator login for the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.administrator_login
}

output "administrator_password" {
  description = "The administrator password for the PostgreSQL Flexible Server"
  value       = var.administrator_password != null ? var.administrator_password : random_password.admin_password[0].result
  sensitive   = true
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = local.connection_string
  sensitive   = true
}

output "private_dns_zone_id" {
  description = "The ID of the private DNS zone"
  value       = var.enable_private_dns ? azurerm_private_dns_zone.postgresql[0].id : null
}

output "backup_retention_days" {
  description = "Backup retention period in days"
  value       = azurerm_postgresql_flexible_server.main.backup_retention_days
}

output "geo_redundant_backup_enabled" {
  description = "Whether geo-redundant backup is enabled"
  value       = azurerm_postgresql_flexible_server.main.geo_redundant_backup_enabled
}

output "high_availability_enabled" {
  description = "Whether high availability is enabled"
  value       = var.enable_high_availability
}

output "storage_mb" {
  description = "Storage size in MB"
  value       = azurerm_postgresql_flexible_server.main.storage_mb
}
