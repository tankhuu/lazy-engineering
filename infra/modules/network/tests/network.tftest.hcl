mock_provider "azurerm" {}

variables {
  name                = "vnet-plat-dev-weu-01"
  location            = "westeurope"
  resource_group_name = "rg-plat-dev-weu-01"
  address_space       = ["10.10.0.0/20"]
  egress_next_hop_ip  = "10.0.0.4"
  private_dns_zones   = ["privatelink.vaultcore.azure.net"]
  tags                = { environment = "dev", managed_by = "terraform" }

  subnets = {
    snet-aks-nodes = { address_prefixes = ["10.10.0.0/22"] }
    snet-pe        = { address_prefixes = ["10.10.4.0/26"], route_via_firewall = false }
    snet-dbw-host = {
      address_prefixes = ["10.10.5.0/24"]
      delegation = {
        name         = "databricks"
        service_name = "Microsoft.Databricks/workspaces"
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action",
          "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
          "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
        ]
      }
    }
  }
}

run "creates_one_nsg_per_subnet_with_internet_deny" {
  command = plan

  assert {
    condition     = length(azurerm_network_security_group.this) == 3
    error_message = "Expected an NSG for every subnet with create_nsg = true."
  }

  assert {
    condition     = alltrue([for r in azurerm_network_security_rule.deny_internet_inbound : r.access == "Deny" && r.source_address_prefix == "Internet"])
    error_message = "Every NSG must deny inbound traffic from Internet."
  }
}

run "routes_only_opted_in_subnets_through_firewall" {
  command = plan

  assert {
    condition     = length(azurerm_route_table.this) == 1 && one([for r in azurerm_route_table.this[0].route : r.next_hop_in_ip_address]) == "10.0.0.4"
    error_message = "Route table must point 0.0.0.0/0 to the hub firewall."
  }

  assert {
    condition     = !contains(keys(azurerm_subnet_route_table_association.this), "snet-pe")
    error_message = "Subnets with route_via_firewall = false must not get the route table."
  }
}

run "subnets_have_no_default_outbound_access" {
  command = plan

  assert {
    condition     = alltrue([for s in azurerm_subnet.this : s.default_outbound_access_enabled == false])
    error_message = "Default outbound access must be disabled."
  }
}

run "no_route_table_without_firewall" {
  command = plan

  variables {
    egress_next_hop_ip = null
  }

  assert {
    condition     = length(azurerm_route_table.this) == 0 && length(azurerm_subnet_route_table_association.this) == 0
    error_message = "No route table expected when egress_next_hop_ip is null."
  }
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    subnets = { bad = { address_prefixes = ["10.10.0.0/33"] } }
  }

  expect_failures = [var.subnets]
}
