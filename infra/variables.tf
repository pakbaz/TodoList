# Input variables for the TodoList infrastructure
variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "East US"
}

variable "project_name" {
  description = "Name of the project (used in resource naming)"
  type        = string
  default     = "todolist"
  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "Project name must be 3-20 characters, lowercase letters, numbers, and hyphens only."
  }
}

variable "enable_zone_redundancy" {
  description = "Enable zone redundancy for high availability (increases cost)"
  type        = bool
  default     = false
}

variable "enable_backup_geo_redundancy" {
  description = "Enable geo-redundant backup storage for PostgreSQL"
  type        = bool
  default     = false
}

# PostgreSQL Configuration
variable "postgresql_sku_name" {
  description = "SKU name for PostgreSQL Flexible Server"
  type        = string
  default     = "B_Standard_B1ms"
  validation {
    condition     = contains(["B_Standard_B1ms", "B_Standard_B2s", "GP_Standard_D2s_v3", "GP_Standard_D4s_v3"], var.postgresql_sku_name)
    error_message = "PostgreSQL SKU must be one of the supported tiers."
  }
}

variable "postgresql_storage_mb" {
  description = "Storage size in MB for PostgreSQL Flexible Server"
  type        = number
  default     = 32768
  validation {
    condition     = var.postgresql_storage_mb >= 20480 && var.postgresql_storage_mb <= 16777216
    error_message = "PostgreSQL storage must be between 20GB (20480 MB) and 16TB (16777216 MB)."
  }
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
  validation {
    condition     = contains(["13", "14", "15", "16"], var.postgresql_version)
    error_message = "PostgreSQL version must be one of: 13, 14, 15, 16."
  }
}

variable "postgresql_admin_username" {
  description = "Administrator username for PostgreSQL"
  type        = string
  default     = "psqladmin"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{2,62}$", var.postgresql_admin_username))
    error_message = "PostgreSQL admin username must start with a letter and be 3-63 characters."
  }
}

# Container Apps Configuration
variable "container_app_min_replicas" {
  description = "Minimum number of container app replicas"
  type        = number
  default     = 1
  validation {
    condition     = var.container_app_min_replicas >= 0 && var.container_app_min_replicas <= 25
    error_message = "Container app min replicas must be between 0 and 25."
  }
}

variable "container_app_max_replicas" {
  description = "Maximum number of container app replicas"
  type        = number
  default     = 5
  validation {
    condition     = var.container_app_max_replicas >= 1 && var.container_app_max_replicas <= 25
    error_message = "Container app max replicas must be between 1 and 25."
  }
}

variable "container_cpu" {
  description = "CPU allocation for container app"
  type        = string
  default     = "0.5"
  validation {
    condition     = contains(["0.25", "0.5", "0.75", "1.0", "1.25", "1.5", "1.75", "2.0"], var.container_cpu)
    error_message = "Container CPU must be one of the supported values."
  }
}

variable "container_memory" {
  description = "Memory allocation for container app"
  type        = string
  default     = "1Gi"
  validation {
    condition     = contains(["0.5Gi", "1Gi", "1.5Gi", "2Gi", "3Gi", "4Gi"], var.container_memory)
    error_message = "Container memory must be one of the supported values."
  }
}

# Container Registry Configuration
variable "container_registry_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.container_registry_sku)
    error_message = "Container Registry SKU must be Basic, Standard, or Premium."
  }
}

# Log Analytics Configuration
variable "log_analytics_sku" {
  description = "SKU for Log Analytics Workspace"
  type        = string
  default     = "PerGB2018"
  validation {
    condition     = contains(["Free", "PerNode", "PerGB2018", "Premium", "Standalone"], var.log_analytics_sku)
    error_message = "Log Analytics SKU must be one of the supported tiers."
  }
}

variable "log_analytics_retention_days" {
  description = "Log retention in days for Log Analytics Workspace"
  type        = number
  default     = 30
  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "Log Analytics retention must be between 30 and 730 days."
  }
}

# Monitoring and Alerts Configuration
variable "enable_application_insights" {
  description = "Enable Application Insights for application monitoring"
  type        = bool
  default     = true
}

variable "enable_container_app_ingress" {
  description = "Enable external ingress for Container App"
  type        = bool
  default     = true
}

variable "enable_https_only" {
  description = "Enable HTTPS only for Container App ingress"
  type        = bool
  default     = true
}

# Networking Configuration
variable "allowed_ip_ranges" {
  description = "List of IP ranges allowed to access PostgreSQL"
  type        = list(string)
  default     = []
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint for PostgreSQL (requires virtual network)"
  type        = bool
  default     = false
}

# Resource Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "TodoList"
    ManagedBy   = "Terraform"
    Environment = "prod"
  }
}

# Application Configuration
variable "application_name" {
  description = "Name of the application (used in resource naming)"
  type        = string
  default     = "todolist"
}

variable "container_image_name" {
  description = "Name of the container image (without registry prefix)"
  type        = string
  default     = "todolist"
}

variable "container_image_tag" {
  description = "Tag of the container image"
  type        = string
  default     = "latest"
}

# Security Configuration
variable "enable_managed_identity" {
  description = "Enable system-assigned managed identity for Container App"
  type        = bool
  default     = true
}

variable "postgresql_backup_retention_days" {
  description = "Backup retention period in days for PostgreSQL"
  type        = number
  default     = 7
  validation {
    condition     = var.postgresql_backup_retention_days >= 7 && var.postgresql_backup_retention_days <= 35
    error_message = "PostgreSQL backup retention must be between 7 and 35 days."
  }
}

# Development and Testing Configuration
variable "enable_development_features" {
  description = "Enable development features (less security, more access)"
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring with more metrics and logs"
  type        = bool
  default     = true
}
