# Unit: AKS (private, CNI Overlay + Cilium, workload identity). Included by <env>/aks/terragrunt.hcl.

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl")).locals
  env    = local.common.env
  aks    = local.env.aks
}

terraform {
  source = "${get_repo_root()}/infra/modules/aks"
}

dependency "network" {
  config_path  = "${get_terragrunt_dir()}/../network"
  skip_outputs = local.common.offline

  mock_outputs = {
    subnet_ids           = { (local.common.subnet_names.aks_nodes) = local.common.mock_subnet }
    private_dns_zone_ids = local.common.mock_dns_zone_ids
    route_table_id       = local.common.use_hub_egress ? "${local.common.mock_rg}/providers/Microsoft.Network/routeTables/rt-mock" : null
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

dependency "acr" {
  config_path  = "${get_terragrunt_dir()}/../acr"
  skip_outputs = local.common.offline

  mock_outputs = {
    id = "${local.common.mock_rg}/providers/Microsoft.ContainerRegistry/registries/crmock"
  }
  mock_outputs_allowed_terraform_commands = local.common.mock_commands
}

inputs = {
  name                       = local.common.names.aks
  resource_group_name        = local.common.resource_groups.aks
  tenant_id                  = local.common.tenant_id
  kubernetes_version         = local.aks.kubernetes_version
  sku_tier                   = local.aks.sku_tier
  admin_group_object_ids     = local.aks.admin_group_object_ids
  nodes_subnet_id            = dependency.network.outputs.subnet_ids[local.common.subnet_names.aks_nodes]
  private_cluster_enabled    = local.aks.private_cluster_enabled
  outbound_type              = local.common.use_hub_egress ? "userDefinedRouting" : "userAssignedNATGateway"
  log_analytics_workspace_id = dependency.log_analytics.outputs.id
  system_pool                = local.aks.system_pool
  user_pools                 = local.aks.user_pools
  workload_identities        = local.aks.workload_identities

  private_dns_zone_id = local.aks.private_cluster_enabled ? try(
    local.env.hub_private_dns_zone_ids["aks"],
    dependency.network.outputs.private_dns_zone_ids[local.common.private_dns_zone_names.aks],
  ) : "None"
  private_dns_zone_manage_role = local.aks.private_cluster_enabled

  route_table = {
    manage_role = local.common.use_hub_egress
    id          = dependency.network.outputs.route_table_id
  }

  acr = {
    attach = true
    id     = dependency.acr.outputs.id
  }
}
