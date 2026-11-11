#!/usr/bin/env python3
"""Regression cases for guard-bash.py. Run: python3 .claude/hooks-platform/test_guard_bash.py"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

GUARD = Path(__file__).with_name("guard-bash.py")

BLOCKED = [
    # terraform
    "terraform apply",
    "terraform -chdir=infra/bootstrap apply -auto-approve",
    "terraform destroy",
    "terraform import azurerm_resource_group.x /subscriptions/x",
    "terraform state rm module.aks",
    "terraform force-unlock 1234",
    "terraform plan -lock=false",
    "cd infra && terraform apply",
    "bash -c 'terraform apply'",
    # terragrunt
    "terragrunt apply",
    "terragrunt destroy",
    "terragrunt run --all apply",
    "terragrunt run --all --non-interactive apply",
    "terragrunt run --all -- apply -auto-approve",
    "terragrunt run -- apply",
    "terragrunt run apply",
    "terragrunt run-all apply",
    "terragrunt apply-all",
    "terragrunt destroy-all",
    "terragrunt run --all destroy",
    "terragrunt run -- destroy",
    "terragrunt import azurerm_resource_group.x /subscriptions/x",
    "terragrunt force-unlock 1234",
    "terragrunt run -- force-unlock 1234",
    "terragrunt state rm azurerm_resource_group.this",
    "terragrunt run -- state mv a b",
    "terragrunt run --all plan -lock=false",
    "terragrunt run --all plan --backend-bootstrap",
    "terragrunt backend bootstrap",
    "terragrunt backend delete",
    "terragrunt backend migrate dev/a dev/b",
    "terragrunt stack run apply",
    "terragrunt exec -- terraform apply",
    "terragrunt exec -- az group delete -n rg-x",
    "TG_NON_INTERACTIVE=true terragrunt run --all apply",
    "cd infra/deployment/dev && terragrunt run --all apply",
    # azure / k8s / helm / databricks
    "az group delete -n rg-x",
    "az aks get-credentials -n a -g b --admin",
    "az keyvault secret show --vault-name kv --name x",
    "kubectl apply -f x.yaml",
    "kubectl delete pod x",
    "helm upgrade x chart",
    "databricks clusters delete 123",
    # state / plan readers
    "cat infra/deployment/dev/aks/.terragrunt-cache/x/y/terraform.tfstate",
    "cat tfplan",
    "strings infra/deployment/dev/aks/.terragrunt-cache/x/y/dev.tfplan",
]

ALLOWED = [
    "terraform plan -out=tfplan",
    "terraform plan -destroy -out=tfplan",
    "terraform show -json tfplan",
    "terraform validate",
    "terragrunt run --all plan",
    "terragrunt run --all --non-interactive plan --out-dir /tmp/plans --json-out-dir /tmp/json",
    "terragrunt run -- plan -destroy",
    "terragrunt run --all -- init -backend=false",
    "terragrunt run --all --no-auto-init -- validate",
    "terragrunt run -- show -json tfplan",
    "terragrunt run -- providers lock -platform=linux_amd64",
    "terragrunt hcl fmt --check",
    "terragrunt hcl validate --inputs",
    "terragrunt render --format json",
    "terragrunt output -json",
    "terragrunt dag graph",
    "terragrunt find --dag",
    "terragrunt list",
    "terragrunt state list",
    "terragrunt run -- state show azurerm_resource_group.this",
    "terragrunt stack generate",
    "terragrunt exec -- terraform version",
    "az account show",
    "az aks show -n a -g b --query 'upgradeSettings'",
    "kubectl get pods -A",
    "kubectl apply --dry-run=server -f x.yaml",
    "jq '.resource_changes' tfplan.json",
    "cat <<'EOF' > notes.md\nterraform apply happens in CI\nEOF",
]


def run(cmd: str) -> int:
    payload = json.dumps({"tool_name": "Bash", "tool_input": {"command": cmd}})
    return subprocess.run([sys.executable, str(GUARD)], input=payload, text=True, capture_output=True).returncode


def main() -> int:
    failures = [f"expected BLOCK: {c}" for c in BLOCKED if run(c) != 2]
    failures += [f"expected ALLOW: {c}" for c in ALLOWED if run(c) != 0]
    for f in failures:
        print(f"FAIL {f}")
    total = len(BLOCKED) + len(ALLOWED)
    print(f"{total - len(failures)}/{total} guard cases passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
