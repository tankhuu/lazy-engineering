# Unit: spoke VNet, subnets, NSGs, egress, private DNS. Included by <env>/network/terragrunt.hcl.

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = local.common.env
  sn     = local.common.subnet_names

  databricks_delegation = {
    name         = "databricks"
    service_name = "Microsoft.Databricks/workspaces"
    actions = [
      "Microsoft.Network/virtualNetworks/subnets/join/action",
      "Microsoft.Network/virtualNetworks/subnets/prepareNetworkPolicies/action",
      "Microsoft.Network/virtualNetworks/subnets/unprepareNetworkPolicies/action",
    ]
  }
}

terraform {
  source = "${get_repo_root()}/infra/modules/network"
}

dependencies {
  paths = ["${get_terragrunt_dir()}/../resource-groups"]
}

inputs = {
  name                = local.common.names.vnet
  resource_group_name = local.common.resource_groups.network
  address_space       = local.env.address_space
  hub_vnet_id         = local.env.hub_vnet_id
  egress_next_hop_ip  = local.env.egress_next_hop_ip
  private_dns_zones   = local.common.use_hub_dns ? [] : values(local.common.private_dns_zone_names)
  nat_gateway         = { enabled = !local.common.use_hub_egress }

  subnets = {
    (local.sn.aks_nodes) = {
      address_prefixes = [local.env.subnet_cidrs.aks_nodes]
      nat_gateway      = !local.common.use_hub_egress
    }
    (local.sn.private_endpoints) = {
      address_prefixes   = [local.env.subnet_cidrs.private_endpoints]
      route_via_firewall = false
    }
    (local.sn.databricks_host) = {
      address_prefixes = [local.env.subnet_cidrs.databricks_host]
      nat_gateway      = !local.common.use_hub_egress
      delegation       = local.databricks_delegation
    }
    (local.sn.databricks_container) = {
      address_prefixes = [local.env.subnet_cidrs.databricks_container]
      nat_gateway      = !local.common.use_hub_egress
      delegation       = local.databricks_delegation
    }
  }
}
