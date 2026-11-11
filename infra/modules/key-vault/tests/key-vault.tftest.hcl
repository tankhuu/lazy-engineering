mock_provider "azurerm" {}

variables {
  name                = "kv-plat-dev-weu"
  location            = "westeurope"
  resource_group_name = "rg-plat-dev-weu-01"
  tenant_id           = "00000000-0000-0000-0000-000000000000"
  tags                = { environment = "dev" }
}

run "secure_defaults" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled && azurerm_key_vault.this.purge_protection_enabled
    error_message = "Key Vault must use RBAC authorization and purge protection."
  }

  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled == false
    error_message = "Public network access must be disabled by default."
  }

  assert {
    condition     = azurerm_key_vault.this.network_acls[0].default_action == "Deny"
    error_message = "Firewall default action must be Deny."
  }
}

run "private_endpoint_and_diagnostics" {
  command = plan

  variables {
    private_endpoint = {
      enabled             = true
      subnet_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet-pe"
      private_dns_zone_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
    }
    diagnostics = {
      enabled                    = true
      log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log"
    }
  }

  assert {
    condition     = length(azurerm_private_endpoint.this) == 1 && azurerm_private_endpoint.this[0].private_service_connection[0].subresource_names[0] == "vault"
    error_message = "Private endpoint for subresource vault expected."
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 1
    error_message = "Diagnostic setting expected when enabled."
  }
}

run "rejects_long_name" {
  command = plan

  variables {
    name = "kv-this-name-is-way-too-long-for-azure"
  }

  expect_failures = [var.name]
}

run "requires_law_for_diagnostics" {
  command = plan

  variables {
    diagnostics = { enabled = true }
  }

  expect_failures = [var.diagnostics]
}
