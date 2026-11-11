#!/usr/bin/env python3
"""Offline wiring checks for every Terragrunt unit (replaces the old env-root tftests).

Renders each unit with PLATFORM_OFFLINE=true (dependencies return mock_outputs, no Azure
access) and asserts naming, tagging, state-key and per-environment network invariants.
Usage: python3 infra/deployment/tests/render_check.py [env ...]
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

DEPLOYMENT = Path(__file__).resolve().parents[1]
REPO = DEPLOYMENT.parents[1]
UNITS = ["resource-groups", "network", "log-analytics", "key-vault", "acr", "aks", "databricks", "databricks-uc"]
CAF_NAMED_UNITS = {"network", "log-analytics", "key-vault", "aks", "databricks"}
MUTATING_COMMANDS = {"apply", "destroy", "import", "refresh", "state"}
REQUIRED_TAGS = {"environment", "owner", "cost_center", "managed_by", "repo", "workload"}
CAF_NAME = re.compile(r"^(vnet|log|kv|aks|dbw|dbac)-plat-(dev|prod)-[a-z]+-\d{2}$")
CAF_RG_NAME = re.compile(r"^rg-(net|shared|aks|dbw)-plat-(dev|prod)-[a-z]+-\d{2}(-managed)?$")


def render(unit_dir: Path) -> dict:
    env = {**os.environ, "PLATFORM_OFFLINE": "true"}
    out = subprocess.run(
        ["terragrunt", "render", "--format", "json", "--non-interactive", "--log-level", "error"],
        cwd=unit_dir, env=env, capture_output=True, text=True, check=False,
    )
    if out.returncode != 0:
        raise RuntimeError(f"{unit_dir.relative_to(REPO)}: render failed\n{out.stderr}")
    return json.loads(out.stdout)


def check_env(env_name: str) -> list[str]:
    errors: list[str] = []

    def expect(cond: bool, msg: str) -> None:
        if not cond:
            errors.append(f"[{env_name}] {msg}")

    rendered = {u: render(DEPLOYMENT / env_name / u) for u in UNITS}

    for unit, cfg in rendered.items():
        inputs = cfg["inputs"]
        state = cfg["remote_state"]
        expect(state["backend"] == "azurerm", f"{unit}: backend must be azurerm")
        expect(state["config"]["key"] == f"infra/deployment/{env_name}/{unit}/terraform.tfstate",
               f"{unit}: state key must be the unit path, got {state['config']['key']}")
        expect(state["config"].get("use_azuread_auth") is True, f"{unit}: state must use Entra ID auth")
        tags = inputs.get("tags", {})
        expect(set(tags) == REQUIRED_TAGS and all(tags.values()), f"{unit}: required tags missing or empty: {tags}")
        expect(tags.get("managed_by") == "terraform", f"{unit}: managed_by must be terraform")
        expect(tags.get("environment") == env_name, f"{unit}: environment tag must be {env_name}")
        for dep_name, dep in (cfg.get("dependency") or {}).items():
            allowed = set(dep.get("mock_outputs_allowed_terraform_commands") or [])
            expect(dep.get("mock_outputs") is not None, f"{unit}: dependency {dep_name} needs mock_outputs")
            expect(not allowed & MUTATING_COMMANDS, f"{unit}: dependency {dep_name} allows mocks for {allowed & MUTATING_COMMANDS}")
        if "resource_group_name" in inputs:
            expect(bool(CAF_RG_NAME.match(inputs["resource_group_name"])), f"{unit}: resource group '{inputs['resource_group_name']}' is not a CAF name")
        if unit in CAF_NAMED_UNITS:
            expect(bool(CAF_NAME.match(inputs["name"])), f"{unit}: name '{inputs['name']}' is not a CAF name")

    rgs = rendered["resource-groups"]["inputs"]["resource_groups"]
    expect(set(rgs) == {"network", "shared", "aks", "databricks"}, f"unexpected resource groups {rgs}")
    expect(all(CAF_RG_NAME.match(n) for n in rgs.values()), f"resource group names not CAF: {rgs}")
    expect(bool(CAF_RG_NAME.match(rendered["databricks"]["inputs"]["managed_resource_group_name"])),
           "Databricks managed resource group name is not CAF")

    net = rendered["network"]["inputs"]
    aks = rendered["aks"]["inputs"]
    dbw = rendered["databricks"]["inputs"]
    expect(aks["name"] == f"aks-plat-{env_name}-weu-01", f"aks name is {aks['name']}")
    expect(aks["private_cluster_enabled"] is True, "AKS must be a private cluster")
    expect(re.fullmatch(r"cr[a-z0-9]{5,48}", rendered["acr"]["inputs"]["name"]) is not None, "ACR name must be alphanumeric")

    hub = net["egress_next_hop_ip"] is not None
    if hub:
        expect(aks["outbound_type"] == "userDefinedRouting", "hub spoke must egress via UDR")
        expect(net["nat_gateway"]["enabled"] is False, "hub spoke must not create a NAT gateway")
        expect(net["private_dns_zones"] == [], "hub spoke must not create private DNS zones")
        expect(net["hub_vnet_id"] is not None, "hub spoke needs hub_vnet_id")
        expect(dbw["private_endpoint"]["create_browser_authentication"] is False, "hub owns browser_authentication")
    else:
        expect(aks["outbound_type"] == "userAssignedNATGateway", "standalone spoke must egress via NAT gateway")
        expect(net["nat_gateway"]["enabled"] is True, "standalone spoke needs a NAT gateway")
        expect(len(net["private_dns_zones"]) == 6, "standalone spoke must create all 6 private DNS zones")

    if env_name == "prod":
        expect(hub, "prod must be hub-connected")
        expect(dbw["public_network_access_enabled"] is False, "prod Databricks must be private-only")

    return errors


def main() -> int:
    envs = sys.argv[1:] or sorted(p.name for p in DEPLOYMENT.iterdir() if (p / "env.hcl").is_file())
    errors = [e for env_name in envs for e in check_env(env_name)]
    for e in errors:
        print(f"FAIL {e}")
    print(f"{'FAILED' if errors else 'OK'}: {len(envs)} env(s), {len(envs) * len(UNITS)} units checked")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
