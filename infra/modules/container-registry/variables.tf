# Container Registry module variables

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

variable "sku" {
  description = "The SKU name of the container registry"
  type        = string
  default     = "Basic"
  
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be one of: Basic, Standard, Premium."
  }
}

variable "admin_enabled" {
  description = "Specifies whether the admin user is enabled"
  type        = bool
  default     = false
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint for Container Registry"
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
  description = "List of subnet IDs that can access the registry"
  type        = list(string)
  default     = []
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges that can access the registry"
  type        = list(string)
  default     = []
}

variable "container_app_identity_principal_id" {
  description = "Principal ID of the container app managed identity"
  type        = string
  default     = null
}

variable "enable_trust_policy" {
  description = "Enable content trust policy (Premium SKU only)"
  type        = bool
  default     = true
}

variable "enable_retention_policy" {
  description = "Enable retention policy (Premium SKU only)"
  type        = bool
  default     = true
}

variable "retention_policy_days" {
  description = "Number of days to retain untagged manifests (Premium SKU only)"
  type        = number
  default     = 30
  
  validation {
    condition     = var.retention_policy_days >= 1 && var.retention_policy_days <= 365
    error_message = "Retention policy days must be between 1 and 365."
  }
}

variable "georeplications" {
  description = "List of geo-replication configurations (Premium SKU only)"
  type = list(object({
    location                  = string
    zone_redundancy_enabled   = bool
    regional_endpoint_enabled = bool
  }))
  default = []
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
