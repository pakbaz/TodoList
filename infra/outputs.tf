// Use the resolved resource group name (works whether RG was created or supplied)
output "resource_group_name" { 
  value = local.rg_name 
}
output "acr_name" { 
  value = azurerm_container_registry.acr.name 
}
output "acr_login_server" { 
  value = azurerm_container_registry.acr.login_server 
}
output "container_app_name" { 
  value = module.container_app.container_app_name 
}
output "container_app_url" { 
  value = module.container_app.fqdn 
}
output "postgres_fqdn" { 
  value = module.postgres.fqdn 
}
output "application_insights_connection_string" { 
  value = module.monitoring.app_insights_connection_string 
}
