# acr

Premium Azure Container Registry with admin user and anonymous pull disabled, public access off, optional private endpoint (`registry`), geo-replication and diagnostics. AKS pulls through the kubelet identity (`AcrPull`, assigned in the `aks` module).

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
| [azurerm_container_registry.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry) | resource |
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_private_endpoint.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| location | Azure region. | `string` | n/a | yes |
| name | Registry name (cr<workload><env><region><nn>, 5-50 alphanumerics, globally unique). | `string` | n/a | yes |
| resource\_group\_name | Resource group name. | `string` | n/a | yes |
| diagnostics | Send registry logs and metrics to Log Analytics. | ```object({ enabled = bool log_analytics_workspace_id = optional(string) })``` | ```{ "enabled": false }``` | no |
| georeplication\_locations | Additional regions to replicate the registry to. | `list(string)` | `[]` | no |
| private\_endpoint | Private endpoint (subresource registry), registered in privatelink.azurecr.io. | ```object({ enabled = bool subnet_id = optional(string) private_dns_zone_id = optional(string) })``` | ```{ "enabled": false }``` | no |
| public\_network\_access\_enabled | Allow pulls/pushes over the public endpoint. | `bool` | `false` | no |
| quarantine\_policy\_enabled | Quarantine pushed images until a scanner releases them. | `bool` | `false` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |
| untagged\_retention\_days | Days to keep untagged manifests before purge. | `number` | `7` | no |
| zone\_redundancy\_enabled | Zone-redundant registry (region must support zones). | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| id | Container registry resource ID (scope for AcrPull). |
| login\_server | Registry login server, e.g. crplatdevweu01.azurecr.io. |
| name | Container registry name. |
<!-- END_TF_DOCS -->
