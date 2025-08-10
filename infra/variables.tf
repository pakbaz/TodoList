variable "prefix" { description = "Global prefix for all resource names" type = string default = "todolist" }
variable "environment" { description = "Deployment environment (dev/staging/prod)" type = string default = "dev" }
variable "location" { description = "Azure region" type = string default = "eastus" }
variable "resource_group_name" { description = "If provided, use existing RG name instead of creating" type = string default = "" }
variable "acr_sku" { description = "Container Registry SKU" type = string default = "Basic" }
variable "container_cpu" { description = "Container vCPU" type = number default = 0.5 }
variable "container_memory" { description = "Container memory (Gi)" type = number default = 1.0 }
variable "autoscale_min_replicas" { type = number default = 0 }
variable "autoscale_max_replicas" { type = number default = 5 }
variable "postgres_admin_user" { type = string default = "pgadmin" }
variable "postgres_admin_password" { type = string sensitive = true }
variable "postgres_version" { type = string default = "16" }
variable "postgres_storage_mb" { type = number default = 32768 }
variable "postgres_sku_name" { type = string default = "B_Standard_B1ms" }
variable "enable_vnet" { type = bool default = true }
variable "tags" { type = map(string) default = {} }
variable "image_tag" { description = "Image tag to deploy" type = string default = "latest" }
variable "image_repository" { description = "Image repository name" type = string default = "todolist" }
