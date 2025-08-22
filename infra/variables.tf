variable "app_name" {
  description = "Name of the application"
  type        = string
  default     = "todolist"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.app_name))
    error_message = "App name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US 2"
}

variable "location_short" {
  description = "Short name for Azure region"
  type        = string
  default     = "eus2"
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Networking Variables
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_configs" {
  description = "Configuration for subnets"
  type = map(object({
    address_prefixes                          = list(string)
    private_endpoint_network_policies        = optional(string, "Enabled")
    private_link_service_network_policies_enabled = optional(bool, true)
    service_endpoints                         = optional(list(string), [])
    delegation = optional(object({
      name = string
      service_delegation = object({
        name    = string
        actions = optional(list(string), [])
      })
    }))
  }))
  default = {
    container_apps = {
      address_prefixes = ["10.0.1.0/24"]
      delegation = {
        name = "Microsoft.App/environments"
        service_delegation = {
          name = "Microsoft.App/environments"
          actions = [
            "Microsoft.Network/virtualNetworks/subnets/join/action"
          ]
        }
      }
    }
    private_endpoints = {
      address_prefixes                          = ["10.0.2.0/24"]
      private_endpoint_network_policies        = "Disabled"
      private_link_service_network_policies_enabled = false
      service_endpoints                         = [
        "Microsoft.KeyVault",
        "Microsoft.ContainerRegistry",
        "Microsoft.Storage"
      ]
    }
  }
}

# Log Analytics Variables
variable "log_analytics_sku" {
  description = "SKU for Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30
  
  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "Log retention must be between 30 and 730 days."
  }
}

# Key Vault Variables
variable "key_vault_soft_delete_retention_days" {
  description = "Number of days to retain deleted Key Vault items"
  type        = number
  default     = 7
  
  validation {
    condition     = var.key_vault_soft_delete_retention_days >= 7 && var.key_vault_soft_delete_retention_days <= 90
    error_message = "Soft delete retention must be between 7 and 90 days."
  }
}

# Container Registry Variables
variable "acr_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Premium"
  
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.acr_sku)
    error_message = "ACR SKU must be Basic, Standard, or Premium."
  }
}

variable "georeplications" {
  description = "List of geo-replication configurations for Container Registry (Premium SKU only)"
  type = list(object({
    location                  = string
    zone_redundancy_enabled   = bool
    regional_endpoint_enabled = bool
  }))
  default = []
}

# PostgreSQL Variables
variable "db_admin_username" {
  description = "Administrator username for PostgreSQL server"
  type        = string
  default     = "psqladmin"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{2,62}$", var.db_admin_username))
    error_message = "Username must start with a letter and be 3-63 characters long."
  }
}

variable "db_admin_password" {
  description = "Administrator password for PostgreSQL server"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_admin_password) >= 8 && length(var.db_admin_password) <= 128
    error_message = "Password must be between 8 and 128 characters long."
  }
}

variable "database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "todolistdb"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{2,62}$", var.database_name))
    error_message = "Database name must start with a letter and be 3-63 characters long."
  }
}

variable "postgresql_version" {
  description = "PostgreSQL server version"
  type        = string
  default     = "16"
  
  validation {
    condition     = contains(["13", "14", "15", "16"], var.postgresql_version)
    error_message = "PostgreSQL version must be 13, 14, 15, or 16."
  }
}

variable "postgresql_sku" {
  description = "SKU for PostgreSQL Flexible Server"
  type        = string
  default     = "GP_Standard_D2s_v3"
  
  validation {
    condition = can(regex("^(B_Standard_B|GP_Standard_D|MO_Standard_E)", var.postgresql_sku))
    error_message = "PostgreSQL SKU must be a valid Flexible Server SKU."
  }
}

variable "postgresql_storage_mb" {
  description = "Storage size in MB for PostgreSQL server"
  type        = number
  default     = 32768 # 32 GB
  
  validation {
    condition     = var.postgresql_storage_mb >= 32768 && var.postgresql_storage_mb <= 16777216
    error_message = "Storage size must be between 32 GB (32768 MB) and 16 TB (16777216 MB)."
  }
}

variable "postgresql_backup_retention_days" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
  
  validation {
    condition     = var.postgresql_backup_retention_days >= 7 && var.postgresql_backup_retention_days <= 35
    error_message = "Backup retention must be between 7 and 35 days."
  }
}

variable "postgresql_geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = false
}

# High Availability Variables
variable "enable_high_availability" {
  description = "Enable high availability features"
  type        = bool
  default     = false
}

variable "standby_availability_zone" {
  description = "Availability zone for standby server"
  type        = string
  default     = "2"
  
  validation {
    condition     = contains(["1", "2", "3"], var.standby_availability_zone)
    error_message = "Standby availability zone must be 1, 2, or 3."
  }
}

# Container App Variables
variable "container_image" {
  description = "Container image to deploy"
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "container_cpu_limit" {
  description = "CPU limit for container"
  type        = number
  default     = 0.5
  
  validation {
    condition     = var.container_cpu_limit >= 0.25 && var.container_cpu_limit <= 4
    error_message = "CPU limit must be between 0.25 and 4 cores."
  }
}

variable "container_memory_limit" {
  description = "Memory limit for container (in Gi)"
  type        = string
  default     = "1Gi"
  
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?Gi$", var.container_memory_limit))
    error_message = "Memory limit must be specified in Gi format (e.g., 1Gi, 2.5Gi)."
  }
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 1
  
  validation {
    condition     = var.min_replicas >= 0 && var.min_replicas <= 30
    error_message = "Minimum replicas must be between 0 and 30."
  }
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 10
  
  validation {
    condition     = var.max_replicas >= 1 && var.max_replicas <= 30
    error_message = "Maximum replicas must be between 1 and 30."
  }
}

variable "scale_concurrent_requests" {
  description = "Number of concurrent requests to trigger scaling"
  type        = number
  default     = 100
  
  validation {
    condition     = var.scale_concurrent_requests >= 1 && var.scale_concurrent_requests <= 1000
    error_message = "Concurrent requests threshold must be between 1 and 1000."
  }
}
