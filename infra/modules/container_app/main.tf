variable "name_root" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "environment_name_suffix" { type = string }
variable "log_analytics_workspace_id" { type = string }
variable "containerapps_subnet_id" { type = string default = null }
variable "acr_login_server" { type = string }
variable "acr_id" { type = string }
variable "image_repository" { type = string }
variable "image_tag" { type = string }
variable "cpu" { type = number }
variable "memory_gi" { type = number }
variable "autoscale_min_replicas" { type = number }
variable "autoscale_max_replicas" { type = number }
variable "default_connection_string" { type = string }
variable "environment" { type = string }

resource "azurerm_container_app_environment" "env" {
  name                       = "cae-${var.name_root}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = var.log_analytics_workspace_id
  infrastructure_subnet_id   = var.containerapps_subnet_id
  tags                       = var.tags
}

resource "azurerm_user_assigned_identity" "uami" {
  name                = "id-${var.name_root}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.uami.principal_id
}

resource "azurerm_container_app" "app" {
  name                         = "app-${var.name_root}"
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.env.id
  revision_mode                = "Single"
  tags                         = var.tags
  identity { type = "UserAssigned" identity_ids = [azurerm_user_assigned_identity.uami.id] }
  template {
    container {
      name   = "todolist"
      image  = "${var.acr_login_server}/${var.image_repository}:${var.image_tag}"
      cpu    = var.cpu
      memory = "${var.memory_gi}Gi"
      env { name = "ConnectionStrings__DefaultConnection" value = var.default_connection_string }
      env { name = "ASPNETCORE_ENVIRONMENT" value = var.environment == "prod" ? "Production" : "Development" }
    }
    scale {
      min_replicas = var.autoscale_min_replicas
      max_replicas = var.autoscale_max_replicas
      rule { name = "http-concurrency" http { concurrent_requests = 50 } }
    }
  }
  ingress { external_enabled = true target_port = 8080 transport = "auto" }
  registry { server = var.acr_login_server identity = azurerm_user_assigned_identity.uami.id }
  depends_on = [azurerm_role_assignment.acr_pull]
}

output "container_app_name" { value = azurerm_container_app.app.name }
output "fqdn" { value = azurerm_container_app.app.latest_revision_fqdn }
