#!/usr/bin/env python3
"""Summarise per-unit Terragrunt plan JSON (from `terragrunt run --all --json-out-dir DIR -- plan`).

Prints a markdown summary (per-unit counts + destroy/replace list) for the PR comment.
--fail-on-stateful exits 3 when a stateful Azure resource would be destroyed or replaced
(CLAUDE.md hard rule: blocker until a human confirms).
Usage: plan_summary.py JSON_DIR --env dev [--fail-on-stateful] [--changes-file PATH]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

STATEFUL = {
    "azurerm_kubernetes_cluster", "azurerm_kubernetes_cluster_node_pool", "azurerm_databricks_workspace",
    "azurerm_storage_account", "azurerm_storage_container", "azurerm_key_vault", "azurerm_virtual_network",
    "azurerm_subnet", "azurerm_container_registry", "azurerm_log_analytics_workspace",
    "azurerm_resource_group", "databricks_metastore", "databricks_catalog", "databricks_external_location",
}


def actions_of(rc: dict) -> str:
    acts = rc["change"]["actions"]
    if acts == ["no-op"] or acts == ["read"]:
        return "noop"
    if "delete" in acts and "create" in acts:
        return "replace"
    return acts[0]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("json_dir", type=Path)
    ap.add_argument("--env", required=True)
    ap.add_argument("--fail-on-stateful", action="store_true")
    ap.add_argument("--changes-file", type=Path, help="write 'true'/'false' (any change) to this file")
    args = ap.parse_args()

    plans = sorted(args.json_dir.rglob("*.json"))
    if not plans:
        print(f"no plan JSON found under {args.json_dir}", file=sys.stderr)
        return 1

    rows, risky, any_change = [], [], False
    for path in plans:
        unit = str(path.parent.relative_to(args.json_dir)) or path.stem
        plan = json.loads(path.read_text())
        counts = {"create": 0, "update": 0, "replace": 0, "delete": 0}
        for rc in plan.get("resource_changes", []):
            act = actions_of(rc)
            if act in counts:
                counts[act] += 1
                if act in {"delete", "replace"}:
                    risky.append((unit, act, rc["address"], rc["type"] in STATEFUL))
        any_change |= any(counts.values())
        rows.append((unit, counts))

    stateful = [r for r in risky if r[3]]
    out = [f"### Terragrunt plan: `{args.env}`", ""]
    if stateful:
        out += ["> [!CAUTION]", "> Stateful resources would be destroyed or replaced. Blocker until confirmed; "
                "prefer `moved`/`import` blocks.", ""]
    out += ["| unit | create | update | replace | delete |", "|---|---:|---:|---:|---:|"]
    out += [f"| `{u}` | {c['create']} | {c['update']} | {c['replace']} | {c['delete']} |" for u, c in rows]
    if risky:
        out += ["", "**Destroy / replace:**", ""]
        out += [f"- {'**STATEFUL** ' if s else ''}`{u}`: {a} `{addr}`" for u, a, addr, s in risky]
    out += ["", "Review with `/tf-review` before merging. Apply runs after merge behind environment approval."]
    print("\n".join(out))

    if args.changes_file:
        args.changes_file.write_text("true" if any_change else "false")
    if args.fail_on_stateful and stateful:
        print(f"{len(stateful)} stateful destroy/replace action(s); refusing to apply", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
