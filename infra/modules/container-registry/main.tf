# Azure Container Registry for storing application container images
# Provides private container image repository with security scanning and geo-replication

resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  # Enable public network access based on private endpoint configuration
  public_network_access_enabled = !var.enable_private_endpoint
  network_rule_bypass_option    = "AzureServices"

  # Network rules when public access is enabled
  dynamic "network_rule_set" {
    for_each = var.enable_private_endpoint ? [] : [1]
    
    content {
      default_action = "Allow"
      
      dynamic "ip_rule" {
        for_each = var.allowed_ip_ranges
        content {
          action   = "Allow"
          ip_range = ip_rule.value
        }
      }
      
      dynamic "virtual_network" {
        for_each = var.allowed_subnet_ids
        content {
          action    = "Allow"
          subnet_id = virtual_network.value
        }
      }
    }
  }

  # Enable vulnerability scanning and trust policies for Premium SKU
  dynamic "trust_policy" {
    for_each = var.sku == "Premium" ? [1] : []
    content {
      enabled = var.enable_trust_policy
    }
  }

  dynamic "retention_policy" {
    for_each = var.sku == "Premium" ? [1] : []
    content {
      days    = var.retention_policy_days
      enabled = var.enable_retention_policy
    }
  }

  # Geo-replication for Premium SKU
  dynamic "georeplications" {
    for_each = var.sku == "Premium" ? var.georeplications : []
    
    content {
      location                  = georeplications.value.location
      zone_redundancy_enabled   = georeplications.value.zone_redundancy_enabled
      regional_endpoint_enabled = georeplications.value.regional_endpoint_enabled
      tags                     = var.tags
    }
  }

  # Enable system-assigned managed identity
  identity {
    type = "SystemAssigned"
  }

  tags = merge(var.tags, {
    Purpose = "Container image storage"
    Security = var.enable_private_endpoint ? "Private" : "Public"
  })
}

# Private endpoint for secure access
resource "azurerm_private_endpoint" "acr" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "${local.acr_name}-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${local.acr_name}-psc"
    private_connection_resource_id = azurerm_container_registry.main.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr[0].id]
  }

  tags = var.tags
}

# Private DNS zone for ACR
resource "azurerm_private_dns_zone" "acr" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                = "privatelink.azurecr.io"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Link private DNS zone to virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  count = var.enable_private_endpoint ? 1 : 0
  
  name                  = "${local.acr_name}-dns-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.acr[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

# Role assignment for container apps to pull images
resource "azurerm_role_assignment" "acr_pull" {
  count = var.container_app_identity_principal_id != null ? 1 : 0
  
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = var.container_app_identity_principal_id
}

# Diagnostic settings for monitoring
resource "azurerm_monitor_diagnostic_setting" "acr" {
  count = var.log_analytics_workspace_id != null ? 1 : 0
  
  name                       = "${local.acr_name}-diagnostics"
  target_resource_id         = azurerm_container_registry.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Local variables
locals {
  # ACR names must be globally unique and contain only alphanumeric characters
  acr_name = replace("acr${var.app_name}${var.environment}${var.location_short}", "-", "")
}

# Validate ACR name length (5-50 characters)
resource "null_resource" "validate_acr_name" {
  lifecycle {
    precondition {
      condition     = length(local.acr_name) >= 5 && length(local.acr_name) <= 50
      error_message = "ACR name '${local.acr_name}' must be between 5 and 50 characters long."
    }
  }
}
