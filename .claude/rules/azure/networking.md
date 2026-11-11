---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "infra/deployment/**/*.hcl"
---
# Azure Networking

## Topology

- Hub-spoke: shared hub (firewall, DNS resolver, Bastion, VPN/ER gateway) owned by the connectivity layer; each env is a spoke VNet peered to the hub. This repo manages the spoke; the hub VNet ID and firewall private IP come in as variables.
- Plan CIDRs up front and record them in `infra/deployment/<env>/env.hcl` (`address_space`, `subnet_cidrs`). No overlaps between envs or with on-prem.

## Spoke subnet layout (example /20)

| Subnet | Size | Purpose |
|--------|------|---------|
| `snet-aks-nodes` | /22 | AKS nodes (Azure CNI Overlay: pods use `pod_cidr`, not VNet IPs) |
| `snet-aks-api` | /28 | API server VNet integration (delegated `Microsoft.ContainerService/managedClusters`) |
| `snet-dbw-host` | /24 | Databricks host/public subnet (delegated `Microsoft.Databricks/workspaces`) |
| `snet-dbw-container` | /24 | Databricks container/private subnet (delegated) |
| `snet-pe` | /26 | Private endpoints |

- Databricks subnets: each needs an NSG association, delegation, and must not be shared with anything else. Minimum /26, recommended /24 for scale.
- AKS: `network_plugin = "azure"`, `network_plugin_mode = "overlay"`, `network_policy = "cilium"` with `network_data_plane = "cilium"`; `pod_cidr` and `service_cidr` must not overlap VNet/hub/on-prem ranges.

## Egress

- Force-tunnel spoke egress through the hub firewall with a route table (`0.0.0.0/0 -> VirtualAppliance`). AKS then uses `outbound_type = "userDefinedRouting"`; allow required AKS and Databricks FQDN tags on the firewall.
- Without a hub firewall (dev), use NAT Gateway (`outbound_type = "userAssignedNATGateway"`) instead of load balancer SNAT.

## Private endpoints and DNS

- Every PaaS dependency (Key Vault, Storage blob/dfs, ACR, Databricks `databricks_ui_api` + `browser_authentication`) gets a private endpoint in `snet-pe`.
- Private DNS zones live in the hub (connectivity subscription) and are linked to spokes; modules accept `private_dns_zone_ids` as input. Only create zones locally when `var.create_private_dns_zones = true` (isolated dev).
- Zones: `privatelink.vaultcore.azure.net`, `privatelink.blob.core.windows.net`, `privatelink.dfs.core.windows.net`, `privatelink.azurecr.io`, `privatelink.azuredatabricks.net`, `privatelink.<region>.azmk8s.io`.

## NSGs

- One NSG per subnet; explicit deny-all inbound from Internet at lowest priority; allow rules reference service tags (`AzureLoadBalancer`, `VirtualNetwork`, `AzureDatabricks`) instead of IP ranges.
- Databricks VNet-injected workspaces manage required NSG rules themselves (`network_security_group_rules_required = "NoAzureDatabricksRules"` when using Private Link back-end only) - do not add conflicting rules.
