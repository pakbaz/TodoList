variable "name_root" { type = string }
variable "suffix" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }

resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-${var.name_root}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "appi" {
  name                = "appi-${var.name_root}-${var.suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
  tags                = var.tags
}

output "app_insights_connection_string" { value = azurerm_application_insights.appi.connection_string }
output "log_analytics_workspace_id" { value = azurerm_log_analytics_workspace.law.id }
