# Remote state backend example (rename to backend.tf and customize)
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-todolist-state"
#     storage_account_name = "sttodoliststate"    # must be globally unique
#     container_name       = "tfstate"
#     key                  = "todolist-${var.environment}.tfstate"
#   }
# }
