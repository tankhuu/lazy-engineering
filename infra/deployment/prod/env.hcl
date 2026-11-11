# Environment values for prod (ri-iac ADR-005: <env>/env.hcl). Non-secret only.
# Tenant/subscription/account IDs come from the environment:
#   ARM_TENANT_ID, ARM_SUBSCRIPTION_ID, DATABRICKS_ACCOUNT_ID, DATABRICKS_METASTORE_ID
# Hub resource IDs below are placeholders: replace with the landing-zone hub outputs.

locals {
  environment  = "prod"
  location     = "westeurope"
  region_short = "weu"
  instance     = "01"
  owner        = "platform-team@example.com"
  cost_center  = "CC-1234"

  address_space = ["10.20.0.0/20"]
  subnet_cidrs = {
    aks_nodes            = "10.20.0.0/22"
    private_endpoints    = "10.20.4.0/24"
    databricks_host      = "10.20.8.0/23"
    databricks_container = "10.20.10.0/23"
  }

  # Hub-connected spoke: 0/0 via hub firewall, private DNS zones owned by the hub.
  egress_next_hop_ip = "10.0.1.4"
  hub_vnet_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-weu/providers/Microsoft.Network/virtualNetworks/vnet-hub-weu"
  hub_private_dns_zone_ids = {
    key_vault  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dns/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"
    acr        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dns/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io"
    databricks = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dns/providers/Microsoft.Network/privateDnsZones/privatelink.azuredatabricks.net"
    blob       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dns/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
    dfs        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dns/providers/Microsoft.Network/privateDnsZones/privatelink.dfs.core.windows.net"
    aks        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub-dns/providers/Microsoft.Network/privateDnsZones/privatelink.westeurope.azmk8s.io"
  }

  aks = {
    kubernetes_version      = "1.34"
    sku_tier                = "Standard"
    private_cluster_enabled = true
    admin_group_object_ids  = ["00000000-0000-0000-0000-000000000000"] # replace with the platform-admins group object ID
    system_pool = {
      vm_size   = "Standard_D4ds_v5"
      min_count = 3
      max_count = 5
    }
    user_pools = {
      apps = {
        vm_size   = "Standard_D8ds_v5"
        min_count = 3
        max_count = 20
      }
    }
    workload_identities = {}
  }

  acr           = { georeplication_locations = ["northeurope"] }
  key_vault     = { admin_group_object_ids = [] }
  log_analytics = { retention_in_days = 90 }

  databricks = {
    public_network_access_enabled = false
    catalogs = {
      prod = {
        comment = "Production catalog"
        grants = {
          "data-engineers" = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
          "data-platform"  = ["ALL_PRIVILEGES"]
        }
      }
    }
  }
}
