mock_provider "azurerm" {}

variables {
  name                                = "dbw-plat-dev-weu-01"
  location                            = "westeurope"
  resource_group_name                 = "rg-plat-dev-weu-01"
  managed_resource_group_name         = "rg-dbw-plat-dev-weu-01-managed"
  virtual_network_id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet"
  host_subnet_name                    = "snet-dbw-host"
  container_subnet_name               = "snet-dbw-container"
  host_subnet_nsg_association_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet-dbw-host"
  container_subnet_nsg_association_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet-dbw-container"
  private_endpoint = {
    enabled   = true
    subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet-pe"
  }
}

run "premium_vnet_injected_scc" {
  command = plan

  assert {
    condition     = azurerm_databricks_workspace.this.sku == "premium"
    error_message = "Premium SKU is required for Unity Catalog and Private Link."
  }

  assert {
    condition     = azurerm_databricks_workspace.this.custom_parameters[0].no_public_ip
    error_message = "Secure Cluster Connectivity (no public IP) must be enabled."
  }
}

run "private_by_default" {
  command = plan

  assert {
    condition     = azurerm_databricks_workspace.this.public_network_access_enabled == false && azurerm_databricks_workspace.this.network_security_group_rules_required == "NoAzureDatabricksRules"
    error_message = "Workspace must be private with back-end Private Link NSG mode."
  }

  assert {
    condition     = length(azurerm_private_endpoint.ui_api) == 1 && length(azurerm_private_endpoint.browser_auth) == 0
    error_message = "ui_api endpoint expected; browser_authentication only when requested."
  }
}

run "public_front_end_uses_all_rules" {
  command = plan

  variables {
    public_network_access_enabled = true
    private_endpoint              = { enabled = false }
  }

  assert {
    condition     = azurerm_databricks_workspace.this.network_security_group_rules_required == "AllRules"
    error_message = "Public workspaces must use AllRules."
  }
}

run "storage_firewall_requires_connector" {
  command = plan

  variables {
    default_storage_firewall_enabled = true
  }

  expect_failures = [var.default_storage_firewall_enabled]
}
