# Output values for reference and use in other configurations
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.rg.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.rg.location
}

# Container Registry outputs
output "container_registry_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.acr.name
}

output "container_registry_login_server" {
  description = "Login server URL for the Azure Container Registry"
  value       = azurerm_container_registry.acr.login_server
}

output "container_registry_admin_username" {
  description = "Admin username for the Azure Container Registry"
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

# Container App outputs
output "container_app_name" {
  description = "Name of the Container App"
  value       = azurerm_container_app.app.name
}

output "container_app_fqdn" {
  description = "Fully qualified domain name of the Container App"
  value       = var.enable_container_app_ingress ? azurerm_container_app.app.latest_revision_fqdn : null
}

output "container_app_url" {
  description = "URL of the Container App"
  value       = var.enable_container_app_ingress ? "https://${azurerm_container_app.app.latest_revision_fqdn}" : null
}

output "container_app_identity_principal_id" {
  description = "Principal ID of the Container App managed identity"
  value       = azurerm_container_app.app.identity[0].principal_id
}

# PostgreSQL outputs
output "postgresql_server_name" {
  description = "Name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.postgresql.name
}

output "postgresql_server_fqdn" {
  description = "Fully qualified domain name of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.postgresql.fqdn
}

output "postgresql_database_name" {
  description = "Name of the PostgreSQL database"
  value       = azurerm_postgresql_flexible_server_database.database.name
}

output "postgresql_admin_username" {
  description = "Administrator username for PostgreSQL"
  value       = azurerm_postgresql_flexible_server.postgresql.administrator_login
  sensitive   = true
}

# Key Vault outputs
output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.kv.vault_uri
}

# Monitoring outputs
output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.log.name
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.log.id
}

output "application_insights_name" {
  description = "Name of Application Insights"
  value       = var.enable_application_insights ? azurerm_application_insights.app_insights[0].name : null
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation key for Application Insights"
  value       = var.enable_application_insights ? azurerm_application_insights.app_insights[0].instrumentation_key : null
  sensitive   = true
}

output "application_insights_app_id" {
  description = "Application ID for Application Insights"
  value       = var.enable_application_insights ? azurerm_application_insights.app_insights[0].app_id : null
}

# Container App Environment outputs
output "container_app_environment_name" {
  description = "Name of the Container App Environment"
  value       = azurerm_container_app_environment.env.name
}

output "container_app_environment_id" {
  description = "ID of the Container App Environment"
  value       = azurerm_container_app_environment.env.id
}

# Connection strings and endpoints for external use
output "postgresql_connection_string_template" {
  description = "Template for PostgreSQL connection string (password must be added)"
  value       = "Host=${azurerm_postgresql_flexible_server.postgresql.fqdn};Database=${local.database_name};Username=<username>;Password=<password>;SSL Mode=Require"
}

# Deployment information
output "deployment_info" {
  description = "Deployment information and next steps"
  value = {
    container_registry_push_command = "docker push ${azurerm_container_registry.acr.login_server}/todolist:latest"
    container_app_logs_command      = "az containerapp logs show --name ${azurerm_container_app.app.name} --resource-group ${azurerm_resource_group.rg.name}"
    postgresql_connect_command      = "az postgres flexible-server connect --name ${azurerm_postgresql_flexible_server.postgresql.name} --admin-user ${azurerm_postgresql_flexible_server.postgresql.administrator_login} --database ${local.database_name}"
    key_vault_access_command        = "az keyvault secret list --vault-name ${azurerm_key_vault.kv.name}"
  }
}

# Resource IDs for advanced scenarios
output "resource_ids" {
  description = "Resource IDs for advanced configuration"
  value = {
    resource_group_id            = azurerm_resource_group.rg.id
    container_registry_id        = azurerm_container_registry.acr.id
    container_app_id             = azurerm_container_app.app.id
    container_app_environment_id = azurerm_container_app_environment.env.id
    postgresql_server_id         = azurerm_postgresql_flexible_server.postgresql.id
    postgresql_database_id       = azurerm_postgresql_flexible_server_database.database.id
    key_vault_id                 = azurerm_key_vault.kv.id
    log_analytics_workspace_id   = azurerm_log_analytics_workspace.log.id
    application_insights_id      = var.enable_application_insights ? azurerm_application_insights.app_insights[0].id : null
  }
}

# Networking information
output "networking_info" {
  description = "Networking configuration information"
  value = {
    postgresql_public_access_enabled = azurerm_postgresql_flexible_server.postgresql.public_network_access_enabled
    container_app_external_enabled   = var.enable_container_app_ingress
    https_only_enabled               = var.enable_https_only
  }
}

# Cost estimation information
output "cost_estimation" {
  description = "Monthly cost estimation for deployed resources"
  value = {
    environment             = var.environment
    postgresql_sku          = local.current_postgresql_config.sku_name
    container_app_resources = "${local.current_container_config.cpu} CPU, ${local.current_container_config.memory} Memory"
    container_registry_sku  = var.container_registry_sku
    estimated_monthly_cost_usd = {
      postgresql_server    = var.environment == "prod" ? "25-50" : "12-25"
      container_apps       = var.environment == "prod" ? "30-60" : "15-30"
      container_registry   = var.container_registry_sku == "Basic" ? "5" : var.container_registry_sku == "Standard" ? "20" : "50"
      log_analytics        = "2-10"
      application_insights = "0-5"
      key_vault            = "1"
      total_range          = var.environment == "prod" ? "63-131" : "35-76"
    }
  }
}

# Security information
output "security_info" {
  description = "Security configuration summary"
  value = {
    managed_identity_enabled = var.enable_managed_identity
    key_vault_integration    = true
    postgresql_entra_auth    = true
    https_only               = var.enable_https_only
    private_endpoint_enabled = var.enable_private_endpoint
    backup_geo_redundancy    = local.current_postgresql_config.geo_redundant_backup
  }
}
