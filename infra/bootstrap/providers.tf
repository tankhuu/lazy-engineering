# Subscription comes from ARM_SUBSCRIPTION_ID (exported by the Makefile from `az account show`).
provider "azurerm" {
  features {}
  storage_use_azuread = true
}
