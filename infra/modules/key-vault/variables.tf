# Key Vault module variables

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

variable "sku_name" {
  description = "The Name of the SKU used for this Key Vault"
  type        = string
  default     = "standard"
  
  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "SKU name must be either standard or premium."
  }
}

variable "soft_delete_retention_days" {
  description = "The number of days that items should be retained for once soft-deleted"
  type        = number
  default     = 90
  
  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "Soft delete retention days must be between 7 and 90."
  }
}

variable "enable_purge_protection" {
  description = "Is Purge Protection enabled for this Key Vault?"
  type        = bool
  default     = true
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint for Key Vault"
  type        = bool
  default     = true
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
  default     = null
}

variable "vnet_id" {
  description = "Virtual Network ID for private DNS zone link"
  type        = string
  default     = null
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs that can access the Key Vault"
  type        = list(string)
  default     = []
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges that can access the Key Vault"
  type        = list(string)
  default     = []
}

variable "container_app_identity_principal_id" {
  description = "Principal ID of the container app managed identity"
  type        = string
  default     = null
}

variable "database_connection_string" {
  description = "Database connection string to store as secret"
  type        = string
  default     = null
  sensitive   = true
}

variable "application_insights_connection_string" {
  description = "Application Insights connection string to store as secret"
  type        = string
  default     = null
  sensitive   = true
}

variable "additional_secrets" {
  description = "Additional secrets to store in Key Vault"
  type        = map(string)
  default     = {}
  sensitive   = true
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
