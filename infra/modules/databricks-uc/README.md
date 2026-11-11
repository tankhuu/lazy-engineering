# databricks-uc

Unity Catalog wiring for one workspace:

- **Azure**: ADLS Gen2 account (HNS, no shared keys, firewall `Deny` with a resource-instance rule for the access connector), `unity-catalog` container, access connector with `Storage Blob Data Contributor`, optional blob/dfs private endpoints.
- **Account** (`databricks.account`): optional regional metastore, metastore assignment.
- **Workspace** (`databricks.workspace`): storage credential, external location, catalogs with grants to account groups, jobs cluster policy with fixed cost tags.

The caller passes both provider aliases:

```hcl
module "databricks_uc" {
  source    = "../../modules/databricks-uc"
  providers = { databricks.account = databricks.account, databricks.workspace = databricks.workspace }
  # ...
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.9, < 2.0 |
| azurerm | ~> 5.13 |
| databricks | ~> 1.142 |

## Providers

| Name | Version |
| ---- | ------- |
| azurerm | 5.13.0 |
| databricks.account | 1.142.0 |
| databricks.workspace | 1.142.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_databricks_access_connector.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/databricks_access_connector) | resource |
| [azurerm_private_endpoint.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_role_assignment.connector_blob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.uc](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.uc](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [databricks_catalog.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/catalog) | resource |
| [databricks_cluster_policy.jobs](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/cluster_policy) | resource |
| [databricks_external_location.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/external_location) | resource |
| [databricks_grants.catalog](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/grants) | resource |
| [databricks_metastore.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/metastore) | resource |
| [databricks_metastore_assignment.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/metastore_assignment) | resource |
| [databricks_storage_credential.this](https://registry.terraform.io/providers/databricks/databricks/latest/docs/resources/storage_credential) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| access\_connector\_name | Databricks access connector name (dbac-<workload>-<env>-<region>-<nn>). | `string` | n/a | yes |
| environment | Environment name used in UC object names and fixed cluster tags. | `string` | n/a | yes |
| location | Azure region (also the metastore region). | `string` | n/a | yes |
| metastore | Create a regional metastore (once per account+region) or attach to an existing one by ID. | ```object({ create = bool id = optional(string) name = optional(string) owner = optional(string) })``` | n/a | yes |
| resource\_group\_name | Resource group for the storage account and access connector. | `string` | n/a | yes |
| storage\_account\_name | ADLS Gen2 account for UC managed storage (st<workload><env><region>uc, 3-24 lowercase alphanumerics). | `string` | n/a | yes |
| workspace\_id | Numeric Databricks workspace ID (module.databricks.workspace\_id). | `string` | n/a | yes |
| catalogs | Catalogs keyed by name; grants map account-group name => privileges, e.g. { data\_engineers = ["USE\_CATALOG", "CREATE\_SCHEMA"] }. | ```map(object({ comment = optional(string) grants = optional(map(list(string)), {}) }))``` | `{}` | no |
| cluster\_policy | Guardrails for the jobs cluster policy. | ```object({ allowed_node_types = optional(list(string), ["Standard_D4ds_v5", "Standard_D8ds_v5", "Standard_E8ds_v5"]) max_autotermination_minutes = optional(number, 60) spark_version_regex = optional(string, "1[5-9]\\.[0-9]+\\.x-scala.*") })``` | `{}` | no |
| private\_endpoint | Private endpoints for the UC storage account (blob + dfs); private\_dns\_zone\_ids keyed by subresource. | ```object({ enabled = bool subnet_id = optional(string) private_dns_zone_ids = optional(map(string), {}) })``` | ```{ "enabled": false }``` | no |
| storage\_replication\_type | Replication for the UC storage account. | `string` | `"ZRS"` | no |
| tags | Tags applied to Azure resources; cost\_center also becomes a fixed cluster tag. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| access\_connector\_id | Access connector resource ID. |
| catalog\_names | Created catalog names. |
| cluster\_policy\_id | ID of the jobs cluster policy. |
| external\_location\_url | abfss:// URL of the UC managed storage root. |
| metastore\_id | Metastore assigned to the workspace. |
| storage\_account\_id | UC storage account resource ID. |
<!-- END_TF_DOCS -->
