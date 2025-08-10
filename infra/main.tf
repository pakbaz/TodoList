############################################
# Locals & Resource Group
############################################
locals {
  name_root = lower(replace("${var.prefix}-${var.environment}", " ", ""))
  tags = merge({
    Environment = var.environment
    Application = "TodoList"
    ManagedBy   = "Terraform"
  }, var.tags)
}

resource "azurerm_resource_group" "main" {
  count    = var.resource_group_name == "" ? 1 : 0
  name     = var.resource_group_name == "" ? "rg-${local.name_root}" : var.resource_group_name
  location = var.location
  tags     = local.tags
}

locals { 
  rg_name = var.resource_group_name == "" ? azurerm_resource_group.main[0].name : var.resource_group_name 
}

resource "random_string" "suffix" { 
  length = 5
  special = false
  upper = false 
}

############################################
# Networking (optional)
############################################
resource "azurerm_virtual_network" "vnet" {
  count               = var.enable_vnet ? 1 : 0
  name                = "vnet-${local.name_root}"
  address_space       = ["10.20.0.0/16"]
  location            = var.location
  resource_group_name = local.rg_name
  tags                = local.tags
}

resource "azurerm_subnet" "subnet_containerapps" {
  count                = var.enable_vnet ? 1 : 0
  name                 = "snet-ca"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  address_prefixes     = ["10.20.1.0/24"]
  delegation {
    name = "delegation"
    service_delegation { 
      name = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"] 
    }
  }
}

resource "azurerm_subnet" "subnet_postgres" {
  count                = var.enable_vnet ? 1 : 0
  name                 = "snet-pg"
  resource_group_name  = local.rg_name
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  address_prefixes     = ["10.20.2.0/24"]
  delegation { 
    name = "pgdelegation"
    service_delegation { 
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"] 
    } 
  }
}

############################################
# Shared ACR
############################################
resource "azurerm_container_registry" "acr" {
  name                = replace("acr${local.name_root}${random_string.suffix.result}", "-", "")
  resource_group_name = local.rg_name
  location            = var.location
  sku                 = var.acr_sku
  admin_enabled       = false
  tags                = local.tags
}

############################################
# Monitoring Module
############################################
module "monitoring" {
  source              = "./modules/monitoring"
  name_root           = local.name_root
  suffix              = random_string.suffix.result
  location            = var.location
  resource_group_name = local.rg_name
  tags                = local.tags
}

############################################
# PostgreSQL Module
############################################
module "postgres" {
  source                = "./modules/postgres"
  name_root             = local.name_root
  suffix                = random_string.suffix.result
  location              = var.location
  resource_group_name   = local.rg_name
  admin_user            = var.postgres_admin_user
  admin_password        = var.postgres_admin_password
  postgres_version      = var.postgres_version
  storage_mb            = var.postgres_storage_mb
  sku_name              = var.postgres_sku_name
  delegated_subnet_id   = var.enable_vnet ? azurerm_subnet.subnet_postgres[0].id : null
  tags                  = local.tags
}

############################################
# Build connection string (root)
############################################
locals {
  pg_conn_string = "Host=${module.postgres.fqdn};Database=todolistdb;Username=${var.postgres_admin_user};Password=${var.postgres_admin_password};Ssl Mode=Require;"
}

############################################
# Container App Module
############################################
module "container_app" {
  source                         = "./modules/container_app"
  name_root                      = local.name_root
  location                       = var.location
  resource_group_name            = local.rg_name
  tags                           = local.tags
  environment_name_suffix        = random_string.suffix.result
  log_analytics_workspace_id     = module.monitoring.log_analytics_workspace_id
  containerapps_subnet_id        = var.enable_vnet ? azurerm_subnet.subnet_containerapps[0].id : null
  acr_login_server               = azurerm_container_registry.acr.login_server
  acr_id                         = azurerm_container_registry.acr.id
  image_repository               = var.image_repository
  image_tag                      = var.image_tag
  cpu                            = var.container_cpu
  memory_gi                      = var.container_memory
  autoscale_min_replicas         = var.autoscale_min_replicas
  autoscale_max_replicas         = var.autoscale_max_replicas
  default_connection_string      = local.pg_conn_string
  environment                    = var.environment
}
