# Environment values for dev (ri-iac ADR-005: <env>/env.hcl). Non-secret only.
# Tenant/subscription/account IDs come from the environment:
#   ARM_TENANT_ID, ARM_SUBSCRIPTION_ID, DATABRICKS_ACCOUNT_ID, DATABRICKS_METASTORE_ID

locals {
  environment  = "dev"
  location     = "westeurope"
  region_short = "weu"
  instance     = "01"
  owner        = "platform-team@example.com"
  cost_center  = "CC-1234"

  address_space = ["10.10.0.0/20"]
  subnet_cidrs = {
    aks_nodes            = "10.10.0.0/22"
    private_endpoints    = "10.10.4.0/24"
    databricks_host      = "10.10.8.0/23"
    databricks_container = "10.10.10.0/23"
  }

  # Standalone spoke: NAT gateway egress, private DNS zones created locally.
  egress_next_hop_ip       = null
  hub_vnet_id              = null
  hub_private_dns_zone_ids = null

  aks = {
    kubernetes_version      = "1.34"
    sku_tier                = "Free"
    private_cluster_enabled = true
    admin_group_object_ids  = ["00000000-0000-0000-0000-000000000000"] # replace with the platform-admins group object ID
    system_pool = {
      vm_size   = "Standard_D4ds_v5"
      min_count = 2
      max_count = 3
    }
    user_pools = {
      apps = {
        vm_size   = "Standard_D4ds_v5"
        min_count = 1
        max_count = 5
      }
    }
    workload_identities = {}
  }

  acr           = { georeplication_locations = [] }
  key_vault     = { admin_group_object_ids = [] }
  log_analytics = { retention_in_days = 30 }

  databricks = {
    # Dev keeps the workspace UI reachable without VPN; prod is private-only.
    public_network_access_enabled = true
    catalogs = {
      dev_sandbox = {
        comment = "Dev sandbox catalog"
        grants = {
          "data-engineers" = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "SELECT", "MODIFY"]
        }
      }
    }
  }
}
