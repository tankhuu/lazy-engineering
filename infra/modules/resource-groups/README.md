# resource-groups

Creates the per-environment resource groups (network, shared, aks, databricks). It is the first unit of every Terragrunt environment (`infra/deployment/<env>/resource-groups`); the other units depend on it for ordering and take names from `common.hcl`.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
