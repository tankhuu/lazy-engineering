---
description: Read-only health and configuration check of an AKS cluster (control plane, node pools, workloads, upgrades, security posture) compared against the repo baseline.
argument-hint: "<resource-group>/<cluster-name> | <env>"
---

# /aks-check

Target: `$ARGUMENTS`. If an env is given, resolve RG/cluster from the Terragrunt unit (read-only):

```bash
PLATFORM_OFFLINE=true terragrunt render --format json --log-level error --working-dir infra/deployment/<env>/aks \
  | jq -r '.inputs | "\(.resource_group_name)/\(.name)"'      # names are composed in common.hcl, no Azure access needed
make output ENV=<env> UNIT=aks | jq '{name, node_resource_group, oidc_issuer_url}'   # state outputs, if applied
```

Delegate to **aks-platform-engineer** with these read-only steps:

1. Control plane / config
   ```bash
   az aks show -g <rg> -n <name> --query "{version:kubernetesVersion, state:provisioningState, power:powerState.code, sku:sku.tier, private:apiServerAccessProfile.enablePrivateCluster, localAccounts:disableLocalAccounts, aadRbac:aadProfile.enableAzureRbac, oidc:oidcIssuerProfile.enabled, wi:securityProfile.workloadIdentity.enabled, network:networkProfile.{plugin:networkPlugin,mode:networkPluginMode,dataplane:networkDataplane,policy:networkPolicy,outbound:outboundType}, upgrade:autoUpgradeProfile}" -o json
   az aks nodepool list -g <rg> --cluster-name <name> --query "[].{name:name,mode:mode,vm:vmSize,count:count,min:minCount,max:maxCount,ver:orchestratorVersion,zones:availabilityZones,state:provisioningState}" -o table
   az aks get-upgrades -g <rg> -n <name> -o table
   ```
2. In-cluster (after `az aks get-credentials -g <rg> -n <name>` and `kubelogin convert-kubeconfig -l azurecli`; never `--admin`):
   ```bash
   kubectl get nodes -o wide
   kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
   kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -30
   kubectl top nodes
   kubectl get pdb -A
   ```
   Or use the `kubernetes` MCP server (read-only mode).
3. Compare against the baseline in `.claude/agents/aks-platform-engineer.md` and `infra/modules/aks`.

## Report

| Area | Status | Detail |
|------|--------|--------|
| Control plane | OK/WARN/FAIL | version, upgrade available, SKU |
| Node pools | ... | ... |
| Workloads | ... | pending/crashlooping pods |
| Security | ... | private API, local accounts, RBAC, WI |
| Networking | ... | CNI overlay/cilium, outbound |

Then a prioritised action list; each action is a Terraform/GitOps change, not a kubectl/az mutation.
