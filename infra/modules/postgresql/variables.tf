# PostgreSQL module variables

variable "app_name" {
  description = "Application name"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9-]{3,24}$", var.app_name))
    error_message = "App name must be 3-24 characters long and contain only lowercase letters, numbers, and hyphens."
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
  description = "Azure region for resources"
  type        = string
}

variable "location_short" {
  description = "Short name for Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
  
  validation {
    condition     = contains(["11", "12", "13", "14", "15", "16"], var.postgresql_version)
    error_message = "PostgreSQL version must be one of: 11, 12, 13, 14, 15, 16."
  }
}

variable "sku_name" {
  description = "The SKU Name for the PostgreSQL Flexible Server"
  type        = string
  default     = "B_Standard_B1ms"
  
  validation {
    condition = can(regex("^(B_Standard_B[1-4]ms|GP_Standard_D[2-8]s_v[3-5]|MO_Standard_E[2-8]s_v[3-5])$", var.sku_name))
    error_message = "SKU name must be a valid PostgreSQL Flexible Server SKU (e.g., B_Standard_B1ms, GP_Standard_D2s_v3)."
  }
}

variable "storage_mb" {
  description = "Max storage allowed for the PostgreSQL Flexible Server"
  type        = number
  default     = 32768
  
  validation {
    condition     = var.storage_mb >= 32768 && var.storage_mb <= 16777216
    error_message = "Storage must be between 32768 MB (32 GB) and 16777216 MB (16 TB)."
  }
}

variable "storage_tier" {
  description = "Storage performance tier for IOPS"
  type        = string
  default     = "P6"
  
  validation {
    condition     = contains(["P4", "P6", "P10", "P15", "P20", "P30", "P40", "P50"], var.storage_tier)
    error_message = "Storage tier must be one of: P4, P6, P10, P15, P20, P30, P40, P50."
  }
}

variable "auto_grow_enabled" {
  description = "Enable auto grow for storage"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention days for the PostgreSQL Flexible Server"
  type        = number
  default     = 7
  
  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "Backup retention days must be between 7 and 35."
  }
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backup"
  type        = bool
  default     = false
}

variable "administrator_login" {
  description = "Administrator login for the PostgreSQL Flexible Server"
  type        = string
  default     = "psqladmin"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.administrator_login))
    error_message = "Administrator login must start with a letter and contain only letters, numbers, and underscores (max 63 characters)."
  }
}

variable "administrator_password" {
  description = "Administrator password for the PostgreSQL Flexible Server"
  type        = string
  default     = null
  sensitive   = true
  
  validation {
    condition = var.administrator_password == null || (
      length(var.administrator_password) >= 8 && 
      length(var.administrator_password) <= 128 &&
      can(regex("[A-Z]", var.administrator_password)) &&
      can(regex("[a-z]", var.administrator_password)) &&
      can(regex("[0-9]", var.administrator_password))
    )
    error_message = "Password must be 8-128 characters long and contain uppercase, lowercase, and numeric characters."
  }
}

variable "availability_zone" {
  description = "Availability zone for the PostgreSQL Flexible Server"
  type        = string
  default     = "1"
  
  validation {
    condition     = contains(["1", "2", "3"], var.availability_zone)
    error_message = "Availability zone must be 1, 2, or 3."
  }
}

variable "enable_high_availability" {
  description = "Enable high availability"
  type        = bool
  default     = false
}

variable "high_availability_mode" {
  description = "High availability mode"
  type        = string
  default     = "ZoneRedundant"
  
  validation {
    condition     = contains(["ZoneRedundant", "SameZone"], var.high_availability_mode)
    error_message = "High availability mode must be ZoneRedundant or SameZone."
  }
}

variable "standby_availability_zone" {
  description = "Standby server availability zone"
  type        = string
  default     = "2"
  
  validation {
    condition     = contains(["1", "2", "3"], var.standby_availability_zone)
    error_message = "Standby availability zone must be 1, 2, or 3."
  }
}

variable "delegated_subnet_id" {
  description = "Subnet ID for PostgreSQL delegation"
  type        = string
  default     = null
}

variable "enable_private_dns" {
  description = "Enable private DNS zone"
  type        = bool
  default     = true
}

variable "vnet_id" {
  description = "Virtual Network ID for private DNS zone link"
  type        = string
  default     = null
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "todolist"
  
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.database_name))
    error_message = "Database name must start with a letter and contain only letters, numbers, and underscores (max 63 characters)."
  }
}

variable "database_charset" {
  description = "Charset for the database"
  type        = string
  default     = "UTF8"
}

variable "database_collation" {
  description = "Collation for the database"
  type        = string
  default     = "en_US.utf8"
}

variable "postgresql_configurations" {
  description = "PostgreSQL configuration parameters"
  type        = map(string)
  default = {
    "shared_preload_libraries" = "pg_stat_statements"
    "log_statement"           = "all"
    "log_min_duration_statement" = "1000"
    "log_checkpoints"         = "on"
    "log_connections"         = "on"
    "log_disconnections"      = "on"
    "log_lock_waits"          = "on"
    "log_temp_files"          = "0"
  }
}

variable "firewall_rules" {
  description = "Firewall rules for the PostgreSQL server"
  type = map(object({
    start_ip_address = string
    end_ip_address   = string
  }))
  default = {}
}

variable "enable_azure_ad_auth" {
  description = "Enable Azure AD authentication"
  type        = bool
  default     = true
}

variable "azure_ad_admin_object_id" {
  description = "Object ID of the Azure AD administrator"
  type        = string
  default     = null
}

variable "azure_ad_admin_principal_name" {
  description = "Principal name of the Azure AD administrator"
  type        = string
  default     = null
}

variable "azure_ad_admin_principal_type" {
  description = "Principal type of the Azure AD administrator"
  type        = string
  default     = "User"
  
  validation {
    condition     = contains(["User", "Group", "ServicePrincipal"], var.azure_ad_admin_principal_type)
    error_message = "Principal type must be User, Group, or ServicePrincipal."
  }
}

variable "maintenance_window" {
  description = "Maintenance window configuration"
  type = object({
    day_of_week  = number
    start_hour   = number
    start_minute = number
  })
  default = null
  
  validation {
    condition = var.maintenance_window == null || (
      var.maintenance_window.day_of_week >= 0 && 
      var.maintenance_window.day_of_week <= 6 &&
      var.maintenance_window.start_hour >= 0 && 
      var.maintenance_window.start_hour <= 23 &&
      var.maintenance_window.start_minute >= 0 && 
      var.maintenance_window.start_minute <= 59
    )
    error_message = "Maintenance window day_of_week must be 0-6, start_hour 0-23, start_minute 0-59."
  }
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for diagnostic settings"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
