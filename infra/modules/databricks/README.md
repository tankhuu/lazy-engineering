# databricks

Azure Databricks Premium workspace with VNet injection, Secure Cluster Connectivity (no public IP), Private Link (`databricks_ui_api`, optional regional `browser_authentication`), infrastructure encryption, optional default storage firewall, and diagnostics.

Changing anything in `custom_parameters` or `managed_resource_group_name` replaces the workspace. Unity Catalog is configured separately in `../databricks-uc`. See `.claude/skills/databricks-terraform/SKILL.md`.

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
| [azurerm_databricks_workspace.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/databricks_workspace) | resource |
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_private_endpoint.browser_auth](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_private_endpoint.ui_api](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| container\_subnet\_name | Name of the delegated container (private) subnet. | `string` | n/a | yes |
| container\_subnet\_nsg\_association\_id | NSG association ID of the container subnet. | `string` | n/a | yes |
| host\_subnet\_name | Name of the delegated host (public) subnet. | `string` | n/a | yes |
| host\_subnet\_nsg\_association\_id | NSG association ID of the host subnet. | `string` | n/a | yes |
| location | Azure region. | `string` | n/a | yes |
| managed\_resource\_group\_name | Name of the Databricks-managed resource group (rg-<workspace>-managed). Changing it replaces the workspace. | `string` | n/a | yes |
| name | Workspace name (dbw-<workload>-<env>-<region>-<nn>). | `string` | n/a | yes |
| resource\_group\_name | Resource group name. | `string` | n/a | yes |
| virtual\_network\_id | VNet ID used for VNet injection. | `string` | n/a | yes |
| access\_connector\_id | Access connector used to reach the workspace default storage when its firewall is enabled. | `string` | `null` | no |
| default\_storage\_firewall\_enabled | Enable the firewall on the workspace-managed DBFS storage account (requires access\_connector\_id). | `bool` | `false` | no |
| diagnostics | Send Databricks audit/diagnostic logs to Log Analytics. | ```object({ enabled = bool log_analytics_workspace_id = optional(string) })``` | ```{ "enabled": false }``` | no |
| private\_endpoint | Private Link: databricks\_ui\_api endpoint (front-end + back-end) and optionally the regional browser\_authentication endpoint. | ```object({ enabled = bool subnet_id = optional(string) private_dns_zone_id = optional(string) create_browser_authentication = optional(bool, false) })``` | ```{ "enabled": false }``` | no |
| public\_network\_access\_enabled | Allow front-end access from the internet. When false, NSG rules switch to NoAzureDatabricksRules and the private endpoint is required. | `bool` | `false` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| id | Workspace ARM resource ID (azure\_workspace\_resource\_id for the databricks provider). |
| managed\_resource\_group\_id | Databricks-managed resource group ID. |
| name | Workspace name. |
| workspace\_id | Numeric Databricks workspace ID (for metastore assignment). |
| workspace\_url | Workspace URL without scheme, e.g. adb-123.4.azuredatabricks.net. |
<!-- END_TF_DOCS -->
