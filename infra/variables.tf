variable "prefix" {
  description = "Global prefix for all resource names"
  type        = string
  default     = "todolist"
}

variable "environment" {
  description = "Deployment environment (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "centralus"
}

variable "resource_group_name" {
  description = "If provided, use existing RG name instead of creating"
  type        = string
  default     = ""
}

variable "postgres_admin_username" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "todolist_admin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}
