# Azure Key Vault for storing application secrets
# Provides secure storage for database connection strings, API keys, and certificates
# Includes private endpoint configuration for enhanced security

resource "azurerm_key_vault" "main" {
  name                        = local.key_vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = var.soft_delete_retention_days
  purge_protection_enabled    = var.enable_purge_protection

  sku_name = var.sku_name

  # Network access rules
  network_acls {
    bypass                     = "AzureServices"
    default_action             = var.enable_private_endpoint ? "Deny" : "Allow"
    virtual_network_subnet_ids = var.allowed_subnet_ids
    ip_rules                   = var.allowed_ip_ranges
  }

  tags = merge(var.tags, {
    Purpose = "Application secrets storage"
    Security = "Private"
  })
}

# Current Azure client configuration
data "azurerm_client_config" "current" {}

# Access policy for the current service principal (CI/CD)
resource "azurerm_key_vault_access_policy" "cicd" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List", 
    "Set",
    "Delete",
    "Recover",
    "Backup",
    "Restore"
  ]

  certificate_permissions = [
    "Get",
    "List",
    "Update",
    "Create",
    "Import",
    "Delete",
    "Recover",
    "Backup",
    "Restore",
    "ManageContacts",
    "ManageIssuers",
    "GetIssuers",
    "ListIssuers",
    "SetIssuers",
    "DeleteIssuers"
  ]
}

# Access policy for container apps managed identity
resource "azurerm_key_vault_access_policy" "container_app" {
  count = var.container_app_identity_principal_id != null ? 1 : 0
  
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = var.container_app_identity_principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Private endpoint for secure access
resource "azurerm_private_endpoint" "key_vault" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "${local.key_vault_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${local.key_vault_name}-psc"
    private_connection_resource_id = azurerm_key_vault.main.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault[0].id]
  }

  tags = var.tags
}

# Private DNS zone for Key Vault
resource "azurerm_private_dns_zone" "key_vault" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link private DNS zone to virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                  = "${local.key_vault_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

# Database connection string secret
resource "azurerm_key_vault_secret" "database_connection_string" {
  count = var.database_connection_string != null ? 1 : 0
  
  name         = "database-connection-string"
  value        = var.database_connection_string
  key_vault_id = azurerm_key_vault.main.id

  tags = merge(var.tags, {
    SecretType = "ConnectionString"
  })

  depends_on = [azurerm_key_vault_access_policy.cicd]
}

# Application Insights connection string
resource "azurerm_key_vault_secret" "application_insights_connection_string" {
  count = var.application_insights_connection_string != null ? 1 : 0
  
  name         = "application-insights-connection-string"
  value        = var.application_insights_connection_string
  key_vault_id = azurerm_key_vault.main.id

  tags = merge(var.tags, {
    SecretType = "ConnectionString"
  })

  depends_on = [azurerm_key_vault_access_policy.cicd]
}

# Additional application secrets
resource "azurerm_key_vault_secret" "app_secrets" {
  for_each = var.additional_secrets
  
  name         = each.key
  value        = each.value
  key_vault_id = azurerm_key_vault.main.id

  tags = merge(var.tags, {
    SecretType = "Application"
  })

  depends_on = [azurerm_key_vault_access_policy.cicd]
}

# Diagnostic settings for monitoring
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  count = var.log_analytics_workspace_id != null ? 1 : 0
  
  name                       = "${local.key_vault_name}-diagnostics"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Local variables
locals {
  key_vault_name = "kv-${var.app_name}-${var.environment}-${var.location_short}"
}
