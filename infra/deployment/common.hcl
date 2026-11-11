# Shared Terragrunt configuration, included by every unit (ri-iac ADR-005: common.hcl).
# Composes CAF names and required tags once from <env>/env.hcl, pins tool versions and
# generates the azurerm provider. Units read these locals through _envcommon/<unit>.hcl.

locals {
  # Units live at infra/deployment/<env>/<unit>/, so env.hcl is one level above the unit.
  env = read_terragrunt_config("${get_original_terragrunt_dir()}/../env.hcl").locals

  # PLATFORM_OFFLINE=true: no Azure access (CI static checks, `make tg-validate`).
  # Dependencies return mock_outputs and IDs fall back to placeholders.
  offline = get_env("PLATFORM_OFFLINE", "false") == "true"

  workload    = "plat"
  repo        = "lazy-engineering"
  name_suffix = "${local.workload}-${local.env.environment}-${local.env.region_short}"
  compact     = "${local.workload}${local.env.environment}${local.env.region_short}${local.env.instance}"

  tenant_id = get_env("ARM_TENANT_ID", local.offline ? "00000000-0000-0000-0000-000000000000" : "")

  tags = {
    environment = local.env.environment
    owner       = local.env.owner
    cost_center = local.env.cost_center
    managed_by  = "terraform"
    repo        = local.repo
    workload    = local.workload
  }

  resource_groups = {
    network    = "rg-net-${local.name_suffix}-${local.env.instance}"
    shared     = "rg-shared-${local.name_suffix}-${local.env.instance}"
    aks        = "rg-aks-${local.name_suffix}-${local.env.instance}"
    databricks = "rg-dbw-${local.name_suffix}-${local.env.instance}"
  }

  names = {
    vnet        = "vnet-${local.name_suffix}-${local.env.instance}"
    log         = "log-${local.name_suffix}-${local.env.instance}"
    kv          = "kv-${local.name_suffix}-${local.env.instance}"
    acr         = "cr${local.compact}"
    aks         = "aks-${local.name_suffix}-${local.env.instance}"
    dbw         = "dbw-${local.name_suffix}-${local.env.instance}"
    dbw_managed = "rg-dbw-${local.name_suffix}-${local.env.instance}-managed"
    dbac        = "dbac-${local.name_suffix}-${local.env.instance}"
    st_uc       = "st${local.workload}uc${local.env.environment}${local.env.region_short}${local.env.instance}"
  }

  subnet_names = {
    aks_nodes            = "snet-aks-nodes"
    private_endpoints    = "snet-pe"
    databricks_host      = "snet-dbw-host"
    databricks_container = "snet-dbw-container"
  }

  # Standalone spokes egress through a NAT gateway; hub-connected spokes route 0/0 to the hub firewall.
  use_hub_egress = local.env.egress_next_hop_ip != null
  use_hub_dns    = local.env.hub_private_dns_zone_ids != null

  private_dns_zone_names = {
    key_vault  = "privatelink.vaultcore.azure.net"
    acr        = "privatelink.azurecr.io"
    databricks = "privatelink.azuredatabricks.net"
    blob       = "privatelink.blob.core.windows.net"
    dfs        = "privatelink.dfs.core.windows.net"
    aks        = "privatelink.${local.env.location}.azmk8s.io"
  }

  # Read-only commands that may use dependency mock_outputs (upstream unit not applied yet, or offline).
  # Never add apply/destroy/import/refresh: those must run against real outputs.
  mock_commands = ["init", "validate", "plan", "providers", "show"]

  # Placeholder IDs for mock_outputs (must parse as Azure resource IDs).
  mock_sub    = "/subscriptions/00000000-0000-0000-0000-000000000000"
  mock_rg     = "${local.mock_sub}/resourceGroups/rg-mock"
  mock_vnet   = "${local.mock_rg}/providers/Microsoft.Network/virtualNetworks/vnet-mock"
  mock_subnet = "${local.mock_vnet}/subnets/snet-mock"
  mock_dns_zone_ids = {
    for k, z in local.private_dns_zone_names : z => "${local.mock_rg}/providers/Microsoft.Network/privateDnsZones/${z}"
  }
}

terraform_binary              = "terraform"
terraform_version_constraint  = ">= 1.9.0"
terragrunt_version_constraint = ">= 1.1.0, < 2.0.0"

# Subscription comes from ARM_SUBSCRIPTION_ID (az CLI locally, OIDC in CI). Never hardcode it.
generate "provider_azurerm" {
  path      = "provider_azurerm_gen.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    provider "azurerm" {
      features {
        key_vault {
          purge_soft_delete_on_destroy = false
        }
        resource_group {
          prevent_deletion_if_contains_resources = true
        }
      }
      storage_use_azuread = true
    }
  EOF
}

inputs = {
  location = local.env.location
  tags     = local.tags
}
