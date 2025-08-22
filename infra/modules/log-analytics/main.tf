# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-${var.name_prefix}-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  retention_in_days   = var.retention_in_days
  tags                = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

# Application Insights
resource "azurerm_application_insights" "this" {
  name                = "ai-${var.name_prefix}-${var.name_suffix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = azurerm_log_analytics_workspace.this.id
  application_type    = "web"
  tags                = var.tags
}
