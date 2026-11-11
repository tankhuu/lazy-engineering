---
description: Read-only configuration and governance check of an Azure Databricks workspace (network isolation, Unity Catalog, cluster policies, compute hygiene).
argument-hint: "<resource-group>/<workspace-name> | <env>"
---

# /dbx-check

Target: `$ARGUMENTS`. For an env, resolve from the Terragrunt units (read-only):

```bash
PLATFORM_OFFLINE=true terragrunt render --format json --log-level error --working-dir infra/deployment/<env>/databricks \
  | jq -r '.inputs | "\(.resource_group_name)/\(.name)"'
make output ENV=<env> UNIT=databricks | jq '{workspace_url, workspace_id}'
make output ENV=<env> UNIT=databricks-uc | jq '{metastore_id, catalog_names, cluster_policy_id}'
```

Delegate to **databricks-platform-engineer** with these read-only steps:

1. Azure resource
   ```bash
   az databricks workspace show -g <rg> -n <name> --query "{sku:sku.name, url:workspaceUrl, publicAccess:publicNetworkAccess, nsgRules:requiredNsgRules, npip:parameters.enableNoPublicIp.value, vnet:parameters.customVirtualNetworkId.value, managedRg:managedResourceGroupId, pe:privateEndpointConnections[].{name:name,state:properties.privateLinkServiceConnectionState.status}}" -o json
   ```
2. Workspace (Databricks CLI with Azure CLI auth: `export DATABRICKS_HOST=https://<url>`; `databricks auth describe`):
   ```bash
   databricks current-user me -o json | jq '{userName, groups: [.groups[].display]}'
   databricks metastores current -o json
   databricks catalogs list -o json | jq -r '.[].name'
   databricks cluster-policies list -o json | jq -r '.[] | "\(.policy_id)\t\(.name)"'
   databricks clusters list -o json | jq -r '.[] | "\(.cluster_id)\t\(.cluster_name)\t\(.state)\t\(.policy_id // "NO_POLICY")\t\(.data_security_mode // "-")\t\(.autotermination_minutes)"'
   databricks warehouses list -o json | jq -r '.[] | "\(.name)\t\(.state)\t\(.auto_stop_mins)"'
   ```
   Or use the `databricks` MCP server.
3. Compare against the baseline in `.claude/agents/databricks-platform-engineer.md` and `infra/modules/databricks*`.

## Report

| Area | Status | Detail |
|------|--------|--------|
| SKU / workspace | | premium? |
| Network | | NPIP, VNet injection, public access, PE status |
| Unity Catalog | | metastore assigned, catalogs, external locations |
| Compute governance | | clusters without policy, autotermination 0, legacy security modes |
| Cost | | always-on warehouses/clusters |

Then actions expressed as Terraform changes (databricks provider) or policy updates.
