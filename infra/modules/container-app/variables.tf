# Container App module variables

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

variable "location_short" {
  description = "Short name for Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "container_app_environment_id" {
  description = "Container App Environment ID"
  type        = string
}

variable "revision_mode" {
  description = "Revision mode for the Container App"
  type        = string
  default     = "Single"
  
  validation {
    condition     = contains(["Single", "Multiple"], var.revision_mode)
    error_message = "Revision mode must be Single or Multiple."
  }
}

variable "workload_profile_name" {
  description = "Workload profile name"
  type        = string
  default     = null
}

# Container configuration
variable "container_name" {
  description = "Name of the container"
  type        = string
  default     = "main"
}

variable "container_image" {
  description = "Container image to deploy"
  type        = string
}

variable "container_cpu" {
  description = "CPU allocation for the container"
  type        = number
  default     = 0.25
  
  validation {
    condition     = contains([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], var.container_cpu)
    error_message = "CPU must be one of: 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0."
  }
}

variable "container_memory" {
  description = "Memory allocation for the container"
  type        = string
  default     = "0.5Gi"
  
  validation {
    condition     = can(regex("^[0-9]+(\\.[0-9]+)?Gi$", var.container_memory))
    error_message = "Memory must be specified in Gi format (e.g., 0.5Gi, 1Gi, 2Gi)."
  }
}

# Environment variables
variable "environment_variables" {
  description = "Environment variables for the container"
  type        = map(string)
  default     = {}
}

variable "secret_environment_variables" {
  description = "Secret environment variables for the container"
  type        = map(string)
  default     = {}
}

# Scaling configuration
variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 1
  
  validation {
    condition     = var.min_replicas >= 0 && var.min_replicas <= 1000
    error_message = "Min replicas must be between 0 and 1000."
  }
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 10
  
  validation {
    condition     = var.max_replicas >= 1 && var.max_replicas <= 1000
    error_message = "Max replicas must be between 1 and 1000."
  }
}

# Health probes
variable "liveness_probe" {
  description = "Liveness probe configuration"
  type = object({
    port                    = number
    transport               = string
    failure_count_threshold = optional(number, 3)
    host                    = optional(string)
    initial_delay           = optional(number, 1)
    interval_seconds        = optional(number, 10)
    path                    = optional(string)
    timeout                 = optional(number, 1)
    headers = optional(list(object({
      name  = string
      value = string
    })), [])
  })
  default = null
}

variable "readiness_probe" {
  description = "Readiness probe configuration"
  type = object({
    port                    = number
    transport               = string
    failure_count_threshold = optional(number, 3)
    host                    = optional(string)
    interval_seconds        = optional(number, 10)
    path                    = optional(string)
    success_count_threshold = optional(number, 1)
    timeout                 = optional(number, 1)
    headers = optional(list(object({
      name  = string
      value = string
    })), [])
  })
  default = null
}

variable "startup_probe" {
  description = "Startup probe configuration"
  type = object({
    port                    = number
    transport               = string
    failure_count_threshold = optional(number, 3)
    host                    = optional(string)
    interval_seconds        = optional(number, 10)
    path                    = optional(string)
    timeout                 = optional(number, 1)
    headers = optional(list(object({
      name  = string
      value = string
    })), [])
  })
  default = null
}

# Scale rules
variable "http_scale_rules" {
  description = "HTTP scale rules"
  type = list(object({
    name                = string
    concurrent_requests = number
    metadata = list(object({
      name  = string
      value = string
    }))
  }))
  default = []
}

variable "custom_scale_rules" {
  description = "Custom scale rules"
  type = list(object({
    name             = string
    custom_rule_type = string
    metadata = list(object({
      name  = string
      value = string
    }))
    authentication = optional(object({
      secret_name       = string
      trigger_parameter = string
    }))
  }))
  default = []
}

variable "azure_queue_scale_rules" {
  description = "Azure Queue scale rules"
  type = list(object({
    name         = string
    queue_name   = string
    queue_length = number
    authentication = optional(object({
      secret_name       = string
      trigger_parameter = string
    }))
  }))
  default = []
}

variable "tcp_scale_rules" {
  description = "TCP scale rules"
  type = list(object({
    name                = string
    concurrent_requests = number
    metadata = list(object({
      name  = string
      value = string
    }))
    authentication = optional(object({
      secret_name       = string
      trigger_parameter = string
    }))
  }))
  default = []
}

# Ingress configuration
variable "enable_ingress" {
  description = "Enable ingress for the Container App"
  type        = bool
  default     = true
}

variable "allow_insecure_connections" {
  description = "Allow insecure connections to the Container App"
  type        = bool
  default     = false
}

variable "external_enabled" {
  description = "Enable external ingress"
  type        = bool
  default     = true
}

variable "target_port" {
  description = "Target port for ingress"
  type        = number
  default     = 8080
}

variable "transport" {
  description = "Transport protocol for ingress"
  type        = string
  default     = "auto"
  
  validation {
    condition     = contains(["auto", "http", "http2", "tcp"], var.transport)
    error_message = "Transport must be one of: auto, http, http2, tcp."
  }
}

variable "exposed_port" {
  description = "Exposed port for ingress"
  type        = number
  default     = null
}

variable "traffic_weights" {
  description = "Traffic weight configuration for revisions"
  type = list(object({
    label           = optional(string)
    latest_revision = optional(bool, true)
    revision_suffix = optional(string)
    percentage      = number
  }))
  default = [{
    latest_revision = true
    percentage      = 100
  }]
}

variable "custom_domains" {
  description = "Custom domains for the Container App"
  type = list(object({
    name           = string
    binding_type   = string
    certificate_id = string
  }))
  default = []
}

variable "ip_security_restrictions" {
  description = "IP security restrictions"
  type = list(object({
    action           = string
    ip_address_range = string
    name             = string
    description      = optional(string)
  }))
  default = []
}

# Storage and volumes
variable "volumes" {
  description = "Volumes for the Container App"
  type = list(object({
    name         = string
    storage_name = string
    storage_type = string
  }))
  default = []
}

variable "volume_mounts" {
  description = "Volume mounts for the container"
  type = list(object({
    name = string
    path = string
  }))
  default = []
}

# Secrets
variable "secrets" {
  description = "Secrets for the Container App"
  type = list(object({
    name  = string
    value = string
  }))
  default   = []
  sensitive = true
}

# Init containers
variable "init_containers" {
  description = "Init containers configuration"
  type = list(object({
    name                 = string
    image                = string
    args                 = optional(list(string))
    command              = optional(list(string))
    cpu                  = optional(number, 0.25)
    memory               = optional(string, "0.5Gi")
    environment_variables = optional(map(string), {})
    volume_mounts = optional(list(object({
      name = string
      path = string
    })), [])
  }))
  default = []
}

# Identity configuration
variable "enable_managed_identity" {
  description = "Enable managed identity for the Container App"
  type        = bool
  default     = true
}

variable "identity_type" {
  description = "Type of managed identity"
  type        = string
  default     = "SystemAssigned"
  
  validation {
    condition     = contains(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned"], var.identity_type)
    error_message = "Identity type must be SystemAssigned, UserAssigned, or 'SystemAssigned, UserAssigned'."
  }
}

variable "identity_ids" {
  description = "List of user assigned identity IDs"
  type        = list(string)
  default     = []
}

# Dapr configuration
variable "enable_dapr" {
  description = "Enable Dapr for the Container App"
  type        = bool
  default     = false
}

variable "dapr_config" {
  description = "Dapr configuration"
  type = object({
    app_id       = string
    app_port     = optional(number)
    app_protocol = optional(string, "http")
  })
  default = {
    app_id = "todolist-app"
  }
}

# Registry configuration
variable "registry_credentials" {
  description = "Registry credentials for private container registries"
  type = list(object({
    server               = string
    username             = optional(string)
    password_secret_name = optional(string)
    identity             = optional(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
