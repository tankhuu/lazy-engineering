# aks

Production AKS baseline: private API server, Entra RBAC with local accounts disabled, workload identity + OIDC issuer, Azure CNI Overlay with Cilium, autoscaled system pool (critical add-ons only, rotation instead of replacement) and user pools, Key Vault CSI driver, Container Insights + managed Prometheus, optional Defender/Azure Policy, weekly maintenance windows, and per-app federated workload identities.

See `.claude/skills/aks-terraform/SKILL.md` for the design rationale and upgrade runbook.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9, < 2.0 |
| azurerm | ~> 5.13 |

## Providers

| Name | Version |
| ---- | ------- |
| azurerm | 5.13.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_federated_identity_credential.workload](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_kubernetes_cluster.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster) | resource |
| [azurerm_kubernetes_cluster_node_pool.user](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool) | resource |
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_role_assignment.control_plane_private_dns](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.control_plane_route_table](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.control_plane_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.kubelet_acr_pull](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_user_assigned_identity.control_plane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_user_assigned_identity.workload](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| admin\_group\_object\_ids | Entra ID groups granted cluster-admin through Entra RBAC. | `list(string)` | n/a | yes |
| kubernetes\_version | Kubernetes minor version (e.g. "1.33"); patch upgrades come from the upgrade channel. | `string` | n/a | yes |
| location | Azure region. | `string` | n/a | yes |
| log\_analytics\_workspace\_id | Log Analytics workspace ID for Container Insights, Defender and diagnostics. | `string` | n/a | yes |
| name | Cluster name (aks-<workload>-<env>-<region>-<nn>). | `string` | n/a | yes |
| nodes\_subnet\_id | Subnet ID for node pools (Azure CNI Overlay: pods do not consume VNet IPs). | `string` | n/a | yes |
| resource\_group\_name | Resource group for the cluster and its identities. | `string` | n/a | yes |
| tenant\_id | Entra ID tenant for cluster RBAC. | `string` | n/a | yes |
| acr | Grant the kubelet identity AcrPull on this registry. | ```object({ attach = bool id = optional(string) })``` | ```{ "attach": false }``` | no |
| automatic\_upgrade\_channel | AKS auto-upgrade channel. | `string` | `"patch"` | no |
| diagnostic\_log\_categories | AKS resource log categories sent to Log Analytics. | `list(string)` | ```[ "kube-audit-admin", "guard", "kube-controller-manager", "cluster-autoscaler" ]``` | no |
| enable\_azure\_policy | Enable the Azure Policy add-on (Gatekeeper). | `bool` | `true` | no |
| enable\_defender | Enable Microsoft Defender for Containers sensor. | `bool` | `false` | no |
| enable\_diagnostics | Create the diagnostic setting for control-plane logs. | `bool` | `true` | no |
| enable\_keda | Enable the KEDA add-on. | `bool` | `false` | no |
| enable\_vpa | Enable the Vertical Pod Autoscaler add-on. | `bool` | `false` | no |
| host\_encryption\_enabled | Encrypt node temp/cache disks at host (requires subscription feature EncryptionAtHost). | `bool` | `false` | no |
| maintenance\_window | Weekly window for control-plane and node OS upgrades. | ```object({ day_of_week = optional(string, "Sunday") start_time = optional(string, "02:00") utc_offset = optional(string, "+00:00") duration_hours = optional(number, 4) })``` | `{}` | no |
| node\_auto\_provisioning | Enable Node Auto Provisioning (Karpenter-based). Keep false to manage pools explicitly with the cluster autoscaler. | `bool` | `false` | no |
| outbound\_type | Egress type: userDefinedRouting (hub firewall), userAssignedNATGateway, or loadBalancer. | `string` | `"userDefinedRouting"` | no |
| pod\_cidr | Overlay pod CIDR; must not overlap VNet, hub, or on-prem ranges. | `string` | `"192.168.0.0/16"` | no |
| private\_cluster\_enabled | Private API server. Changing this replaces the cluster. | `bool` | `true` | no |
| private\_dns\_zone\_id | "System", "None", or the ID of a BYO privatelink.<region>.azmk8s.io zone. | `string` | `"System"` | no |
| private\_dns\_zone\_manage\_role | Grant the control-plane identity Private DNS Zone Contributor on a BYO private\_dns\_zone\_id. A plain bool so count stays known when the zone ID is computed. | `bool` | `false` | no |
| route\_table | Grant the control-plane identity Network Contributor on the subnet route table (needed for userDefinedRouting). | ```object({ manage_role = bool id = optional(string) })``` | ```{ "manage_role": false }``` | no |
| service\_cidr | Kubernetes service CIDR; dns\_service\_ip is the 10th address. | `string` | `"172.16.0.0/16"` | no |
| sku\_tier | Free, Standard (uptime SLA) or Premium (LTS). | `string` | `"Standard"` | no |
| system\_pool | System node pool (critical add-ons only). | ```object({ vm_size = optional(string, "Standard_D4ds_v5") min_count = optional(number, 3) max_count = optional(number, 5) max_pods = optional(number, 110) zones = optional(list(string), ["1", "2", "3"]) os_sku = optional(string, "AzureLinux") })``` | `{}` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |
| user\_pools | User node pools keyed by pool name (<= 12 lowercase alphanumerics). | ```map(object({ vm_size = string min_count = number max_count = number max_pods = optional(number, 110) zones = optional(list(string), ["1", "2", "3"]) os_sku = optional(string, "AzureLinux") os_disk_type = optional(string, "Ephemeral") max_surge = optional(string, "33%") labels = optional(map(string), {}) taints = optional(list(string), []) }))``` | `{}` | no |
| workload\_identities | User-assigned identities federated to Kubernetes service accounts, keyed by app name. | ```map(object({ namespace = string service_account = string }))``` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| control\_plane\_identity\_principal\_id | Principal ID of the control-plane user-assigned identity. |
| id | AKS cluster resource ID. |
| kubelet\_identity\_object\_id | Object ID of the kubelet identity (grant AcrPull / storage roles to this). |
| name | AKS cluster name. |
| node\_resource\_group | Managed node resource group. |
| oidc\_issuer\_url | OIDC issuer URL for workload identity federation. |
| private\_fqdn | Private API server FQDN (null for public clusters). |
| workload\_identity\_client\_ids | Client IDs of workload identities keyed by app name (annotate service accounts with azure.workload.identity/client-id). |
<!-- END_TF_DOCS -->
