terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {
    # Backend configuration will be provided via terraform init command or environment variables
    # See: https://developer.hashicorp.com/terraform/language/backend/azurerm
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  
  # Use OIDC authentication for GitHub Actions
  use_oidc = true
}

# Data source to get current Azure client configuration
data "azurerm_client_config" "current" {}

# Generate random suffix for unique resource naming
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  # Common naming convention
  name_prefix = "${var.app_name}-${var.environment}"
  name_suffix = random_id.suffix.hex
  
  # Common tags applied to all resources
  common_tags = merge(var.tags, {
    Application = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CreatedBy   = "DevOps-Pipeline"
    CreatedOn   = timestamp()
  })
}

# Resource Group
module "resource_group" {
  source = "./modules/resource-group"
  
  name     = "rg-${local.name_prefix}-${local.name_suffix}"
  location = var.location
  tags     = local.common_tags
}

# Networking
module "networking" {
  source = "./modules/networking"
  
  resource_group_name = module.resource_group.name
  location           = var.location
  name_prefix        = local.name_prefix
  name_suffix        = local.name_suffix
  tags               = local.common_tags
  
  vnet_address_space = var.vnet_address_space
  subnet_configs     = var.subnet_configs
}

# Log Analytics Workspace
module "log_analytics" {
  source = "./modules/log-analytics"
  
  resource_group_name = module.resource_group.name
  location           = var.location
  name_prefix        = local.name_prefix
  name_suffix        = local.name_suffix
  tags               = local.common_tags
  
  sku               = var.log_analytics_sku
  retention_in_days = var.log_analytics_retention_days
}

# Key Vault
module "key_vault" {
  source = "./modules/key-vault"
  
  app_name            = var.app_name
  environment         = var.environment
  location           = var.location
  location_short     = var.location_short
  resource_group_name = module.resource_group.name
  tags               = local.common_tags
  
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  vnet_id                   = module.networking.vnet_id
  soft_delete_retention_days = var.key_vault_soft_delete_retention_days
}

# Azure Container Registry
module "container_registry" {
  source = "./modules/container-registry"
  
  app_name            = var.app_name
  environment         = var.environment
  location           = var.location
  location_short     = var.location_short
  resource_group_name = module.resource_group.name
  tags               = local.common_tags
  
  sku                        = var.acr_sku
  admin_enabled              = false
  private_endpoint_subnet_id = module.networking.private_endpoint_subnet_id
  vnet_id                   = module.networking.vnet_id
  georeplications           = var.georeplications
}

# PostgreSQL Flexible Server
module "postgresql" {
  source = "./modules/postgresql"
  
  app_name            = var.app_name
  environment         = var.environment
  location           = var.location
  location_short     = var.location_short
  resource_group_name = module.resource_group.name
  tags               = local.common_tags
  
  administrator_login        = var.db_admin_username
  postgresql_version         = var.postgresql_version
  sku_name                   = var.postgresql_sku
  storage_mb                 = var.postgresql_storage_mb
  
  enable_high_availability   = var.enable_high_availability
  high_availability_mode     = "ZoneRedundant"
  standby_availability_zone  = var.standby_availability_zone
  
  backup_retention_days        = var.postgresql_backup_retention_days
  geo_redundant_backup_enabled = var.postgresql_geo_redundant_backup_enabled
}

# Container Apps Environment
module "container_apps_environment" {
  source = "./modules/container-apps-env"
  
  app_name            = var.app_name
  environment         = var.environment
  location           = var.location
  location_short     = var.location_short
  resource_group_name = module.resource_group.name
  tags               = local.common_tags
  
  log_analytics_workspace_id = module.log_analytics.workspace_id
  infrastructure_subnet_id   = module.networking.container_apps_subnet_id
  enable_zone_redundancy     = var.enable_high_availability
}

# TodoList Container App
module "todolist_app" {
  source = "./modules/container-app"
  
  app_name                     = var.app_name
  environment                  = var.environment
  location_short              = var.location_short
  resource_group_name         = module.resource_group.name
  container_app_environment_id = module.container_apps_environment.id
  
  container_name   = "todolist-app"
  container_image  = var.container_image
  
  # Environment variables
  environment_variables = {
    "ASPNETCORE_ENVIRONMENT" = title(var.environment)
    "ASPNETCORE_URLS"       = "http://+:8080"
  }
  
  # Resource allocation
  container_cpu    = var.container_cpu_limit
  container_memory = var.container_memory_limit
  
  # Scaling configuration
  min_replicas = var.min_replicas
  max_replicas = var.max_replicas
  
  http_scale_rules = {
    concurrent_requests = var.scale_concurrent_requests
  }
  
  tags = local.common_tags
  
  depends_on = [module.postgresql]
}

# Store database connection string in Key Vault
resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "db-connection-string"
  value        = module.postgresql.connection_string
  key_vault_id = module.key_vault.id
  
  depends_on = [module.key_vault]
  
  tags = local.common_tags
}

# Create RBAC assignments for the container app to access Key Vault
resource "azurerm_role_assignment" "app_key_vault_secrets_user" {
  scope                = module.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.todolist_app.identity_principal_id
}

# Create RBAC assignment for the container app to pull from ACR
resource "azurerm_role_assignment" "app_acr_pull" {
  scope                = module.container_registry.id
  role_definition_name = "AcrPull"
  principal_id         = module.todolist_app.identity_principal_id
}
