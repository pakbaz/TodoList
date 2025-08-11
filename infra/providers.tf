# Configure Terraform providers and backend
terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  # Configure remote state storage (commented out for initial testing)
  # backend "azurerm" {
  #   # These values will be provided during initialization
  #   # resource_group_name  = "rg-terraform-state"
  #   # storage_account_name = "satodolisttfstate"
  #   # container_name       = "tfstate"
  #   # key                  = "todolist.terraform.tfstate"
  # }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Configure the Random Provider
provider "random" {
}
