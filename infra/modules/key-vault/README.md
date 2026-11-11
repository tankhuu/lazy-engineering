# key-vault

Key Vault in RBAC mode with purge protection, firewall default `Deny`, optional private endpoint (`vault`) and diagnostic settings. Access is granted through `role_assignments` (data-plane roles such as `Key Vault Secrets User`); access policies are not supported by design.

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
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_private_endpoint.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| location | Azure region. | `string` | n/a | yes |
| name | Key Vault name (kv-<workload>-<env>-<region>, 3-24 chars, globally unique). | `string` | n/a | yes |
| resource\_group\_name | Resource group name. | `string` | n/a | yes |
| tenant\_id | Entra ID tenant ID. | `string` | n/a | yes |
| allowed\_ip\_ranges | Public IP ranges allowed through the firewall (only effective when public access is enabled). | `list(string)` | `[]` | no |
| diagnostics | Send audit logs and metrics to Log Analytics. | ```object({ enabled = bool log_analytics_workspace_id = optional(string) })``` | ```{ "enabled": false }``` | no |
| private\_endpoint | Private endpoint (subresource vault) in the given subnet, registered in privatelink.vaultcore.azure.net. | ```object({ enabled = bool subnet_id = optional(string) private_dns_zone_id = optional(string) })``` | ```{ "enabled": false }``` | no |
| public\_network\_access\_enabled | Allow access over the public endpoint (firewall still applies). | `bool` | `false` | no |
| role\_assignments | Data-plane RBAC on the vault keyed by a stable name, e.g. { platform\_admins = { role\_definition\_name = "Key Vault Administrator", principal\_id = "..." } }. | ```map(object({ role_definition_name = string principal_id = string principal_type = optional(string, "Group") }))``` | `{}` | no |
| sku\_name | standard or premium (HSM-backed keys). | `string` | `"standard"` | no |
| soft\_delete\_retention\_days | Soft delete retention (7-90 days). | `number` | `90` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| id | Key Vault resource ID. |
| name | Key Vault name. |
| private\_endpoint\_id | Private endpoint ID, or null when disabled. |
| vault\_uri | Key Vault URI. |
<!-- END_TF_DOCS -->
