# Local values and computed variables
locals {
  # Common naming convention
  name_prefix = "${var.project_name}-${var.environment}"

  # Resource naming
  resource_group_name            = "rg-${local.name_prefix}"
  container_registry_name        = "cr${replace(local.name_prefix, "-", "")}${random_string.suffix.result}"
  container_app_environment_name = "cae-${local.name_prefix}"
  container_app_name             = "ca-${local.name_prefix}"
  postgresql_server_name         = "psql-${local.name_prefix}-${random_string.suffix.result}"
  key_vault_name                 = "kv-${local.name_prefix}-${random_string.suffix.result}"
  log_analytics_name             = "log-${local.name_prefix}"
  app_insights_name              = "ai-${local.name_prefix}"

  # Database configuration
  database_name = "todolistdb"
  database_user = "app_user"

  # Container configuration
  container_port = 8080

  # Common tags
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    Application = var.application_name
    CreatedBy   = "Terraform"
    CreatedDate = formatdate("YYYY-MM-DD", timestamp())
  })

  # PostgreSQL configuration based on environment
  postgresql_config = {
    dev = {
      sku_name             = "B_Standard_B1ms"
      storage_mb           = 32768
      backup_retention     = 7
      geo_redundant_backup = false
    }
    staging = {
      sku_name             = "B_Standard_B2s"
      storage_mb           = 65536
      backup_retention     = 14
      geo_redundant_backup = false
    }
    prod = {
      sku_name             = var.postgresql_sku_name
      storage_mb           = var.postgresql_storage_mb
      backup_retention     = var.postgresql_backup_retention_days
      geo_redundant_backup = var.enable_backup_geo_redundancy
    }
  }

  # Container Apps configuration based on environment
  container_config = {
    dev = {
      min_replicas = 0
      max_replicas = 2
      cpu          = "0.25"
      memory       = "0.5Gi"
    }
    staging = {
      min_replicas = 1
      max_replicas = 3
      cpu          = "0.5"
      memory       = "1Gi"
    }
    prod = {
      min_replicas = var.container_app_min_replicas
      max_replicas = var.container_app_max_replicas
      cpu          = var.container_cpu
      memory       = var.container_memory
    }
  }

  # Get environment-specific configuration
  current_postgresql_config = local.postgresql_config[var.environment]
  current_container_config  = local.container_config[var.environment]

  # Container image reference
  container_image = "${azurerm_container_registry.acr.login_server}/${var.container_image_name}:${var.container_image_tag}"

  # Application environment variables
  app_environment_variables = [
    {
      name  = "ASPNETCORE_ENVIRONMENT"
      value = "Production"
    },
    {
      name  = "ASPNETCORE_URLS"
      value = "http://+:${local.container_port}"
    },
    {
      name  = "Azure__KeyVault__VaultUrl"
      value = azurerm_key_vault.kv.vault_uri
    }
  ]

  # Application secrets (stored in Key Vault)
  app_secrets = [
    {
      name        = "connectionstrings--defaultconnection"
      keyVaultUrl = "${azurerm_key_vault.kv.vault_uri}secrets/postgresql-connection-string"
      identity    = azurerm_container_app.app.identity[0].principal_id
    },
    {
      name        = "applicationinsights--connectionstring"
      keyVaultUrl = "${azurerm_key_vault.kv.vault_uri}secrets/appinsights-connection-string"
      identity    = azurerm_container_app.app.identity[0].principal_id
    }
  ]

  # PostgreSQL connection string
  postgresql_connection_string = "Host=${azurerm_postgresql_flexible_server.postgresql.fqdn};Database=${local.database_name};Username=${local.database_user};SSL Mode=Require;Trust Server Certificate=true"
}
