# Azure Database for PostgreSQL Flexible Server
# Provides managed PostgreSQL database with high availability and automated backups

# Random password for the administrator if not provided
resource "random_password" "admin_password" {
  count   = var.administrator_password == null ? 1 : 0
  length  = 32
  special = true
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                   = local.postgresql_server_name
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = var.postgresql_version
  delegated_subnet_id    = var.delegated_subnet_id
  private_dns_zone_id    = var.enable_private_dns ? azurerm_private_dns_zone.postgresql[0].id : null
  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password != null ? var.administrator_password : random_password.admin_password[0].result
  zone                   = var.availability_zone

  storage_mb            = var.storage_mb
  storage_tier          = var.storage_tier
  auto_grow_enabled     = var.auto_grow_enabled

  sku_name = var.sku_name

  # Backup configuration
  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  # High availability configuration
  dynamic "high_availability" {
    for_each = var.enable_high_availability ? [1] : []
    
    content {
      mode                      = var.high_availability_mode
      standby_availability_zone = var.standby_availability_zone
    }
  }

  # Maintenance window
  dynamic "maintenance_window" {
    for_each = var.maintenance_window != null ? [var.maintenance_window] : []
    
    content {
      day_of_week  = maintenance_window.value.day_of_week
      start_hour   = maintenance_window.value.start_hour
      start_minute = maintenance_window.value.start_minute
    }
  }

  # Enable authentication
  authentication {
    active_directory_auth_enabled = var.enable_azure_ad_auth
    password_auth_enabled         = true
    tenant_id                     = var.enable_azure_ad_auth ? data.azurerm_client_config.current.tenant_id : null
  }

  tags = merge(var.tags, {
    Purpose = "Application database"
    DatabaseEngine = "PostgreSQL"
  })

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgresql]
}

# Current Azure client configuration
data "azurerm_client_config" "current" {}

# PostgreSQL database
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = var.database_collation
  charset   = var.database_charset
}

# Private DNS zone for PostgreSQL
resource "azurerm_private_dns_zone" "postgresql" {
  count = var.enable_private_dns ? 1 : 0
  
  name                = "${var.app_name}-${var.environment}.postgres.database.azure.com"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link private DNS zone to virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  count = var.enable_private_dns ? 1 : 0
  
  name                  = "${local.postgresql_server_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

# PostgreSQL configuration parameters
resource "azurerm_postgresql_flexible_server_configuration" "configurations" {
  for_each = var.postgresql_configurations
  
  name      = each.key
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = each.value
}

# Firewall rules for development environments
resource "azurerm_postgresql_flexible_server_firewall_rule" "firewall_rules" {
  for_each = var.firewall_rules
  
  name             = each.key
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = each.value.start_ip_address
  end_ip_address   = each.value.end_ip_address
}

# Azure AD administrator
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "admin" {
  count = var.enable_azure_ad_auth && var.azure_ad_admin_object_id != null ? 1 : 0
  
  server_name         = azurerm_postgresql_flexible_server.main.name
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = var.azure_ad_admin_object_id
  principal_name      = var.azure_ad_admin_principal_name
  principal_type      = var.azure_ad_admin_principal_type
}

# Diagnostic settings for monitoring
resource "azurerm_monitor_diagnostic_setting" "postgresql" {
  count = var.log_analytics_workspace_id != null ? 1 : 0
  
  name                       = "${local.postgresql_server_name}-diagnostics"
  target_resource_id         = azurerm_postgresql_flexible_server.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "PostgreSQLLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Local variables
locals {
  postgresql_server_name = "psql-${var.app_name}-${var.environment}-${var.location_short}"
  
  # Build connection string
  connection_string = "Host=${azurerm_postgresql_flexible_server.main.fqdn};Database=${azurerm_postgresql_flexible_server_database.main.name};Username=${var.administrator_login};Password=${var.administrator_password != null ? var.administrator_password : random_password.admin_password[0].result};SSL Mode=Require;"
}
