mock_provider "azurerm" {}

variables {
  location = "westeurope"
  resource_groups = {
    network = "rg-net-plat-dev-weu-01"
    aks     = "rg-aks-plat-dev-weu-01"
  }
  tags = {
    environment = "dev"
    managed_by  = "terraform"
  }
}

run "one_group_per_key_with_tags" {
  command = plan

  assert {
    condition     = length(azurerm_resource_group.this) == 2
    error_message = "Expected one resource group per key."
  }

  assert {
    condition     = alltrue([for rg in azurerm_resource_group.this : rg.tags["managed_by"] == "terraform"])
    error_message = "Every resource group must carry the env tags."
  }
}

run "rejects_non_caf_name" {
  command = plan

  variables {
    resource_groups = { network = "Network_RG" }
  }

  expect_failures = [var.resource_groups]
}
