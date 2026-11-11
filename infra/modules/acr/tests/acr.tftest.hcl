mock_provider "azurerm" {}

variables {
  name                = "crplatdevweu01"
  location            = "westeurope"
  resource_group_name = "rg-plat-dev-weu-01"
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = azurerm_container_registry.this.admin_enabled == false && azurerm_container_registry.this.anonymous_pull_enabled == false
    error_message = "Admin user and anonymous pull must be disabled."
  }

  assert {
    condition     = azurerm_container_registry.this.public_network_access_enabled == false && azurerm_container_registry.this.export_policy_enabled == false
    error_message = "Public access and export must be disabled by default."
  }

  assert {
    condition     = azurerm_container_registry.this.sku == "Premium"
    error_message = "Premium SKU is required for private endpoints."
  }
}

run "rejects_hyphenated_name" {
  command = plan

  variables {
    name = "cr-plat-dev"
  }

  expect_failures = [var.name]
}
