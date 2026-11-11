# Unit: Databricks workspace (Premium, VNet injection, SCC, private link). Included by <env>/databricks/terragrunt.hcl.

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = local.common.env
  sn     = local.common.subnet_names
}

terraform {
  source = "${get_repo_root()}/infra/modules/databricks"
}

dependency "network" {
  config_path  = "${get_terragrunt_dir()}/../network"
  skip_outputs = local.common.offline

  mock_outputs = {
    id         = local.common.mock_vnet
    subnet_ids = { (local.sn.private_endpoints) = local.common.mock_subnet }
    nsg_association_ids = {
      (local.sn.databricks_host)      = "${local.common.mock_vnet}/subnets/${local.sn.databricks_host}"
      (local.sn.databricks_container) = "${local.common.mock_vnet}/subnets/${local.sn.databricks_container}"
    }
    private_dns_zone_ids = local.common.mock_dns_zone_ids
  }
  mock_outputs_allowed_terraform_commands = local.common.mock_commands
}

dependency "log_analytics" {
  config_path  = "${get_terragrunt_dir()}/../log-analytics"
  skip_outputs = local.common.offline

  mock_outputs = {
    id = "${local.common.mock_rg}/providers/Microsoft.OperationalInsights/workspaces/log-mock"
  }
  mock_outputs_allowed_terraform_commands = local.common.mock_commands
}

inputs = {
  name                                = local.common.names.dbw
  resource_group_name                 = local.common.resource_groups.databricks
  managed_resource_group_name         = local.common.names.dbw_managed
  virtual_network_id                  = dependency.network.outputs.id
  host_subnet_name                    = local.sn.databricks_host
  container_subnet_name               = local.sn.databricks_container
  host_subnet_nsg_association_id      = dependency.network.outputs.nsg_association_ids[local.sn.databricks_host]
  container_subnet_nsg_association_id = dependency.network.outputs.nsg_association_ids[local.sn.databricks_container]
  public_network_access_enabled       = local.env.databricks.public_network_access_enabled

  private_endpoint = {
    enabled   = true
    subnet_id = dependency.network.outputs.subnet_ids[local.sn.private_endpoints]
    private_dns_zone_id = try(
      local.env.hub_private_dns_zone_ids["databricks"],
      dependency.network.outputs.private_dns_zone_ids[local.common.private_dns_zone_names.databricks],
    )
    # One browser_authentication endpoint per region; the hub owns it when DNS is hub-managed.
    create_browser_authentication = !local.common.use_hub_dns
  }

  diagnostics = {
    enabled                    = true
    log_analytics_workspace_id = dependency.log_analytics.outputs.id
  }
}
