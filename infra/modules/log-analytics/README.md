# log-analytics

Workload Log Analytics workspace used by AKS Container Insights and the diagnostic settings of every module. Local (shared key) authentication is disabled; agents use managed identity.

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
| [azurerm_log_analytics_workspace.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| location | Azure region. | `string` | n/a | yes |
| name | Workspace name (log-<workload>-<env>-<region>-<nn>). | `string` | n/a | yes |
| resource\_group\_name | Resource group name. | `string` | n/a | yes |
| daily\_quota\_gb | Daily ingestion cap in GB; -1 means unlimited. | `number` | `-1` | no |
| internet\_ingestion\_enabled | Allow ingestion over the public internet (set false when using AMPLS). | `bool` | `true` | no |
| internet\_query\_enabled | Allow queries over the public internet (set false when using AMPLS). | `bool` | `true` | no |
| retention\_in\_days | Interactive retention in days. | `number` | `30` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| id | Log Analytics workspace resource ID (use for diagnostic settings and AKS oms\_agent). |
| name | Log Analytics workspace name. |
| workspace\_id | Log Analytics workspace (customer) ID used by agents and queries. |
<!-- END_TF_DOCS -->
