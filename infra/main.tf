# Data source to use existing resource group if provided
data "azurerm_resource_group" "existing" {
  count = var.resource_group_name != "" ? 1 : 0
  name  = var.resource_group_name
}

# Create resource group if not using existing one
resource "azurerm_resource_group" "main" {
  count    = var.resource_group_name == "" ? 1 : 0
  name     = "rg-${var.prefix}-${var.environment}-${var.location}"
  location = var.location

  tags = {
    Environment = var.environment
    Application = var.prefix
    ManagedBy   = "Terraform"
  }
}

# Local to determine which resource group to use
locals {
  resource_group_name = var.resource_group_name != "" ? data.azurerm_resource_group.existing[0].name : azurerm_resource_group.main[0].name
  location            = var.resource_group_name != "" ? data.azurerm_resource_group.existing[0].location : azurerm_resource_group.main[0].location
  
  # Common tags
  common_tags = {
    Environment = var.environment
    Application = var.prefix
    ManagedBy   = "Terraform"
  }
}

# Random suffix for unique naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = "acr${var.prefix}${var.environment}${random_id.suffix.hex}"
  resource_group_name = local.resource_group_name
  location            = local.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = local.common_tags
}

# Monitoring Module
module "monitoring" {
  source = "./modules/monitoring"

  name_root           = "${var.prefix}-${var.environment}"
  suffix              = random_id.suffix.hex
  location            = local.location
  resource_group_name = local.resource_group_name
  tags                = local.common_tags
}

# PostgreSQL Module
module "postgres" {
  source = "./modules/postgres"

  name_root             = "${var.prefix}-${var.environment}"
  suffix               = random_id.suffix.hex
  location             = local.location
  resource_group_name  = local.resource_group_name
  admin_user           = var.postgres_admin_username
  admin_password       = var.postgres_admin_password
  postgres_version     = "15"
  sku_name            = "B_Standard_B1ms"
  storage_mb          = 32768
  delegated_subnet_id = null
  tags                = local.common_tags
}

# Container App Module
module "container_app" {
  source = "./modules/container_app"

  name_root                    = "${var.prefix}-${var.environment}"
  location                     = local.location
  resource_group_name          = local.resource_group_name
  environment_name_suffix      = random_id.suffix.hex
  log_analytics_workspace_id   = module.monitoring.log_analytics_workspace_id
  containerapps_subnet_id      = null
  acr_login_server            = azurerm_container_registry.main.login_server
  acr_id                      = azurerm_container_registry.main.id
  image_repository            = "todolist-app"
  image_tag                   = "latest"
  cpu                         = 0.5
  memory_gi                   = 1
  autoscale_min_replicas      = 0
  autoscale_max_replicas      = 3
  default_connection_string   = module.postgres.connection_string
  environment                 = var.environment
  tags                        = local.common_tags
}
