---
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "infra/deployment/**/*.hcl"
---
# Azure Naming and Tagging

Based on the Cloud Adoption Framework (CAF) abbreviations.

## Pattern

`<abbr>-<workload>-<env>-<region>-<instance>` e.g. `aks-plat-dev-weu-01`.

Resources that disallow hyphens or have short limits drop separators and use lowercase: `st<workload><env><region><nn>` (storage, max 24), `cr<workload><env><region><nn>` (ACR, alphanumeric), `kv-<workload>-<env>-<region>` (Key Vault, max 24).

| Resource | Abbr | Resource | Abbr |
|----------|------|----------|------|
| Resource group | `rg` | Virtual network | `vnet` |
| Subnet | `snet` | Network security group | `nsg` |
| Route table | `rt` | Private endpoint | `pe` |
| AKS cluster | `aks` | AKS node pool | `np` (<= 12 chars, lowercase alnum) |
| Container registry | `cr` | Key Vault | `kv` |
| Log Analytics | `log` | Storage account | `st` |
| User-assigned identity | `id` | Databricks workspace | `dbw` |
| Databricks access connector | `dbac` | Application Insights | `appi` |

Region short codes: `weu` westeurope, `neu` northeurope, `sea` southeastasia, `eus` eastus, `eus2` eastus2.

## Implementation

- Compose names once in `locals.tf` of each env (`local.name_suffix = "${var.workload}-${var.environment}-${var.region_short}"`) and pass full names into modules. Modules do not invent names.
- Validate env values: `contains(["dev", "test", "prod"], var.environment)`.

## Required tags

| Tag | Example |
|-----|---------|
| `environment` | `dev` |
| `owner` | `platform-team@example.com` |
| `cost_center` | `CC-1234` |
| `managed_by` | `terraform` |
| `repo` | `lazy-engineering` |
| `workload` | `platform` |

- Define `local.tags` in the env, pass `tags = local.tags` to every module; modules merge with `merge(var.tags, {...})` and apply to every taggable resource.
- Databricks: also set `custom_tags` on clusters/pools so DBU cost is attributable.
- AKS node pools: set `tags`, and the managed `node_resource_group` inherits through `node_resource_group` naming `rg-<aks-name>-nodes`.
