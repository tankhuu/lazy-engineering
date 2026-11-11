terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.13"
    }
    databricks = {
      source                = "databricks/databricks"
      version               = "~> 1.142"
      configuration_aliases = [databricks.account, databricks.workspace]
    }
  }
}
