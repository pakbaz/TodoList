# Azure Container Apps Environment
# Provides the hosting environment for container applications with integrated networking and monitoring

resource "azurerm_container_app_environment" "main" {
  name                           = local.container_app_env_name
  location                       = var.location
  resource_group_name            = var.resource_group_name
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  infrastructure_subnet_id       = var.infrastructure_subnet_id
  internal_load_balancer_enabled = var.enable_internal_load_balancer
  zone_redundancy_enabled        = var.enable_zone_redundancy

  # Workload profiles for better performance and isolation
  dynamic "workload_profile" {
    for_each = var.workload_profiles
    
    content {
      name                  = workload_profile.value.name
      workload_profile_type = workload_profile.value.workload_profile_type
      maximum_count         = workload_profile.value.maximum_count
      minimum_count         = workload_profile.value.minimum_count
    }
  }

  tags = merge(var.tags, {
    Purpose = "Container Apps hosting environment"
    Type    = var.enable_internal_load_balancer ? "Internal" : "External"
  })
}

# Managed identity for the Container Apps Environment
resource "azurerm_user_assigned_identity" "container_app_env" {
  name                = "${local.container_app_env_name}-identity"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Storage for Container Apps (for shared volumes, if needed)
resource "azurerm_container_app_environment_storage" "shared_storage" {
  for_each = var.storage_accounts
  
  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.main.id
  account_name                 = each.value.account_name
  share_name                   = each.value.share_name
  access_key                   = each.value.access_key
  access_mode                  = each.value.access_mode
}

# Dapr components for microservices patterns
resource "azurerm_container_app_environment_dapr_component" "components" {
  for_each = var.dapr_components
  
  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.main.id
  component_type               = each.value.component_type
  version                      = each.value.version
  scopes                       = each.value.scopes

  dynamic "metadata" {
    for_each = each.value.metadata
    
    content {
      name  = metadata.value.name
      value = metadata.value.value
    }
  }

  dynamic "secret" {
    for_each = each.value.secrets
    
    content {
      name  = secret.value.name
      value = secret.value.value
    }
  }
}

# Certificate for custom domains
resource "azurerm_container_app_environment_certificate" "custom_domain" {
  for_each = var.certificates
  
  name                         = each.key
  container_app_environment_id = azurerm_container_app_environment.main.id
  certificate_blob_base64      = each.value.certificate_blob_base64
  certificate_password         = each.value.certificate_password

  tags = var.tags
}

# Diagnostic settings for Container Apps Environment
resource "azurerm_monitor_diagnostic_setting" "container_app_env" {
  count = var.log_analytics_workspace_id != null ? 1 : 0
  
  name                       = "${local.container_app_env_name}-diagnostics"
  target_resource_id         = azurerm_container_app_environment.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerAppConsoleLogs"
  }

  enabled_log {
    category = "ContainerAppSystemLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Local variables
locals {
  container_app_env_name = "cae-${var.app_name}-${var.environment}-${var.location_short}"
}
