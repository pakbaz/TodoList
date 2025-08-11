# Generate random suffix for resource names to ensure uniqueness
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Generate random password for PostgreSQL admin
resource "random_password" "postgresql_admin_password" {
  length  = 16
  special = true
}

# Get current Azure client configuration
data "azurerm_client_config" "current" {}

# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# Create Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "log" {
  name                = local.log_analytics_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.common_tags
}

# Create Application Insights for application monitoring
resource "azurerm_application_insights" "app_insights" {
  count               = var.enable_application_insights ? 1 : 0
  name                = local.app_insights_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.log.id
  application_type    = "web"
  tags                = local.common_tags
}

# Create Container Registry
resource "azurerm_container_registry" "acr" {
  name                = local.container_registry_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = var.container_registry_sku
  admin_enabled       = true

  tags = local.common_tags
}

# Create Key Vault for secrets management
resource "azurerm_key_vault" "kv" {
  name                = local.key_vault_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Enable for deployment and template access
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  enabled_for_disk_encryption     = true

  # Soft delete and purge protection
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = local.common_tags
}

# Grant Key Vault access to current user/service principal
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
  ]

  key_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Import", "Backup", "Restore", "Recover"
  ]

  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Import", "ManageContacts", "GetIssuers", "ListIssuers", "SetIssuers", "DeleteIssuers", "ManageIssuers", "Recover", "Backup", "Restore"
  ]
}

# Create PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "postgresql" {
  name                = local.postgresql_server_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  version                       = var.postgresql_version
  delegated_subnet_id           = null
  private_dns_zone_id           = null
  public_network_access_enabled = true

  administrator_login    = var.postgresql_admin_username
  administrator_password = random_password.postgresql_admin_password.result

  zone = var.enable_zone_redundancy ? "1" : null

  storage_mb   = local.current_postgresql_config.storage_mb
  storage_tier = "P4"
  sku_name     = local.current_postgresql_config.sku_name

  backup_retention_days        = local.current_postgresql_config.backup_retention
  geo_redundant_backup_enabled = local.current_postgresql_config.geo_redundant_backup

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  tags = local.common_tags

  depends_on = [azurerm_resource_group.rg]
}

# Configure PostgreSQL server parameters for optimal performance
resource "azurerm_postgresql_flexible_server_configuration" "postgresql_config" {
  for_each = {
    "shared_preload_libraries"   = "pg_stat_statements"
    "log_statement"              = "all"
    "log_min_duration_statement" = "1000"
    "log_checkpoints"            = "on"
    "log_connections"            = "on"
    "log_disconnections"         = "on"
    "log_lock_waits"             = "on"
  }

  server_id = azurerm_postgresql_flexible_server.postgresql.id
  name      = each.key
  value     = each.value
}

# Create PostgreSQL database
resource "azurerm_postgresql_flexible_server_database" "database" {
  name      = local.database_name
  server_id = azurerm_postgresql_flexible_server.postgresql.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Create firewall rule for Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.postgresql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Create firewall rules for allowed IP ranges
resource "azurerm_postgresql_flexible_server_firewall_rule" "allowed_ips" {
  count            = length(var.allowed_ip_ranges)
  name             = "AllowedIP-${count.index}"
  server_id        = azurerm_postgresql_flexible_server.postgresql.id
  start_ip_address = split("-", var.allowed_ip_ranges[count.index])[0]
  end_ip_address   = length(split("-", var.allowed_ip_ranges[count.index])) > 1 ? split("-", var.allowed_ip_ranges[count.index])[1] : split("-", var.allowed_ip_ranges[count.index])[0]
}

# Create Container Apps Environment
resource "azurerm_container_app_environment" "env" {
  name                       = local.container_app_environment_name
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log.id

  tags = local.common_tags
}

# Create Container App
resource "azurerm_container_app" "app" {
  name                         = local.container_app_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  resource_group_name          = azurerm_resource_group.rg.name
  revision_mode                = "Single"

  identity {
    type = "SystemAssigned"
  }

  template {
    min_replicas = local.current_container_config.min_replicas
    max_replicas = local.current_container_config.max_replicas

    container {
      name   = "todolist"
      image  = "${azurerm_container_registry.acr.login_server}/todolist:latest"
      cpu    = local.current_container_config.cpu
      memory = local.current_container_config.memory

      # Environment variables
      dynamic "env" {
        for_each = local.app_environment_variables
        content {
          name  = env.value.name
          value = env.value.value
        }
      }

      # Liveness probe
      liveness_probe {
        transport = "HTTP"
        port      = local.container_port
        path      = "/health"

        initial_delay     = 30
        interval_seconds  = 30
        timeout           = 5
        failure_threshold = 3
      }

      # Readiness probe
      readiness_probe {
        transport = "HTTP"
        port      = local.container_port
        path      = "/health"

        initial_delay     = 5
        interval_seconds  = 10
        timeout           = 3
        failure_threshold = 3
      }
    }

    # HTTP scaling rule
    http_scale_rule {
      name                = "http-scaler"
      concurrent_requests = 100
    }
  }

  ingress {
    allow_insecure_connections = !var.enable_https_only
    external_enabled           = var.enable_container_app_ingress
    target_port                = local.container_port

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  # Registry configuration
  registry {
    server               = azurerm_container_registry.acr.login_server
    username             = azurerm_container_registry.acr.admin_username
    password_secret_name = "acr-password"
  }

  # ACR password secret
  secret {
    name  = "acr-password"
    value = azurerm_container_registry.acr.admin_password
  }

  tags = local.common_tags

  depends_on = [
    azurerm_container_registry.acr,
    azurerm_container_app_environment.env
  ]
}

# Grant Container App access to Key Vault
resource "azurerm_key_vault_access_policy" "container_app" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_container_app.app.identity[0].principal_id

  secret_permissions = [
    "Get", "List"
  ]

  depends_on = [azurerm_container_app.app]
}

# Store PostgreSQL connection string in Key Vault
resource "azurerm_key_vault_secret" "postgresql_connection_string" {
  name         = "postgresql-connection-string"
  value        = "Host=${azurerm_postgresql_flexible_server.postgresql.fqdn};Database=${local.database_name};Username=${local.database_user};SSL Mode=Require;Trust Server Certificate=true"
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.current_user,
    azurerm_postgresql_flexible_server.postgresql
  ]
}

# Store Application Insights connection string in Key Vault
resource "azurerm_key_vault_secret" "app_insights_connection_string" {
  count        = var.enable_application_insights ? 1 : 0
  name         = "appinsights-connection-string"
  value        = azurerm_application_insights.app_insights[0].connection_string
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [
    azurerm_key_vault_access_policy.current_user,
    azurerm_application_insights.app_insights
  ]
}

# Store PostgreSQL admin password in Key Vault
resource "azurerm_key_vault_secret" "postgresql_admin_password" {
  name         = "postgresql-admin-password"
  value        = random_password.postgresql_admin_password.result
  key_vault_id = azurerm_key_vault.kv.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
}
