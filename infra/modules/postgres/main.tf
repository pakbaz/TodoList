variable "name_root" { type = string }
variable "suffix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "admin_user" { type = string }
variable "admin_password" { type = string sensitive = true }
variable "version" { type = string }
variable "storage_mb" { type = number }
variable "sku_name" { type = string }
variable "delegated_subnet_id" { type = string default = null }
variable "tags" { type = map(string) }

resource "azurerm_postgresql_flexible_server" "pg" {
  name                   = "pg-${var.name_root}-${var.suffix}"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = var.version
  administrator_login    = var.admin_user
  administrator_password = var.admin_password
  storage_mb             = var.storage_mb
  sku_name               = var.sku_name
  delegated_subnet_id    = var.delegated_subnet_id
  zone                   = "1"
  backup { backup_retention_days = 7 geo_redundant_backup_enabled = false }
  high_availability { mode = "Disabled" }
  lifecycle { ignore_changes = [zone] }
  tags = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "appdb" {
  name      = "todolistdb"
  server_id = azurerm_postgresql_flexible_server.pg.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

output "fqdn" { value = azurerm_postgresql_flexible_server.pg.fqdn }
