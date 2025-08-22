# Container Apps Environment module variables

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

variable "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID for Container Apps"
  type        = string
}

variable "infrastructure_subnet_id" {
  description = "Subnet ID for Container Apps infrastructure"
  type        = string
  default     = null
}

variable "enable_internal_load_balancer" {
  description = "Enable internal load balancer for Container Apps"
  type        = bool
  default     = false
}

variable "enable_zone_redundancy" {
  description = "Enable zone redundancy for high availability"
  type        = bool
  default     = false
}

variable "workload_profiles" {
  description = "Workload profiles for Container Apps Environment"
  type = list(object({
    name                  = string
    workload_profile_type = string
    maximum_count         = number
    minimum_count         = number
  }))
  default = []
  
  validation {
    condition = alltrue([
      for profile in var.workload_profiles : 
      contains(["Consumption", "D4", "D8", "D16", "D32", "E4", "E8", "E16", "E32"], profile.workload_profile_type)
    ])
    error_message = "Workload profile type must be one of: Consumption, D4, D8, D16, D32, E4, E8, E16, E32."
  }
}

variable "storage_accounts" {
  description = "Storage accounts for Container Apps shared volumes"
  type = map(object({
    account_name = string
    share_name   = string
    access_key   = string
    access_mode  = string
  }))
  default = {}
  
  validation {
    condition = alltrue([
      for storage in values(var.storage_accounts) : 
      contains(["ReadOnly", "ReadWrite"], storage.access_mode)
    ])
    error_message = "Storage access mode must be ReadOnly or ReadWrite."
  }
}

variable "dapr_components" {
  description = "Dapr components for microservices patterns"
  type = map(object({
    component_type = string
    version        = string
    scopes         = optional(list(string), [])
    metadata = list(object({
      name  = string
      value = string
    }))
    secrets = optional(list(object({
      name  = string
      value = string
    })), [])
  }))
  default = {}
}

variable "certificates" {
  description = "Certificates for custom domains"
  type = map(object({
    certificate_blob_base64 = string
    certificate_password    = string
  }))
  default   = {}
  sensitive = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
