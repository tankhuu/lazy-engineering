#!/usr/bin/env python3
"""PreToolUse(Bash) guard for the Azure platform repo.

Blocks commands that mutate Terraform state, Azure, AKS, Helm releases or Databricks,
and commands that read Terraform state or secret values. Exit 2 blocks the tool call
and shows stderr to Claude. Only the command verb is inspected, so read-only calls with
words like "upgrade" inside --query strings are not affected.
"""

from __future__ import annotations

import json
import os
import re
import shlex
import sys

SEPARATORS = {";", "&&", "||", "|", "&", "(", ")"}
WRAPPERS = {"sudo", "env", "command", "exec", "time", "nohup", "xargs"}

TF_BLOCKED = {"apply", "destroy", "import", "taint", "untaint", "force-unlock", "refresh"}
TF_STATE_BLOCKED = {"rm", "mv", "push", "replace-provider"}

# Terragrunt: `run --all apply` auto-approves, so every apply/destroy form is CI-only.
TG_BLOCKED = TF_BLOCKED | {"apply-all", "destroy-all"}
TG_BACKEND_BLOCKED = {"bootstrap", "delete", "migrate"}

AZ_MUTATING = {
    "create", "delete", "update", "set", "assign", "purge", "deallocate", "stop", "start",
    "restart", "upgrade", "scale", "rotate-certs", "reset-credentials", "add", "remove",
    "import", "invoke", "run-command", "approve", "reject", "enable", "disable", "recover",
    "restore", "regenerate", "renew", "attach", "detach", "abort", "migrate",
}
AZ_ALLOWED_PATHS = {
    ("account", "set"),
    ("config", "set"),
    ("extension", "add"),
    ("login",),
    ("logout",),
}

KUBECTL_MUTATING = {
    "apply", "create", "delete", "edit", "patch", "replace", "scale", "drain", "cordon",
    "uncordon", "taint", "label", "annotate", "set", "expose", "run", "autoscale", "cp",
    "exec", "debug", "attach", "port-forward",
}
KUBECTL_VALUE_FLAGS = {"-n", "--namespace", "--context", "--kubeconfig", "--cluster", "--user", "-s", "--server", "--as"}

HELM_MUTATING = {"install", "upgrade", "uninstall", "delete", "rollback"}

DATABRICKS_MUTATING = {
    "create", "delete", "permanent-delete", "edit", "update", "start", "restart", "resize",
    "pin", "unpin", "set", "reset", "run-now", "submit", "deploy", "destroy", "import",
}

PLAN_BINARY = re.compile(r"(^|/)(tfplan|[^/]*\.tfplan)$")

READERS = {"cat", "less", "more", "head", "tail", "bat", "jq", "grep", "rg", "strings", "cp", "scp",
           "curl", "base64", "xxd", "vi", "vim", "nano", "code", "open", "awk", "sed"}


def block(reason: str) -> None:
    print(f"BLOCKED by platform guard: {reason}", file=sys.stderr)
    print("Changes to Azure/AKS/Databricks/Terraform state go through PR + CI (see CLAUDE.md > Hard rules).",
          file=sys.stderr)
    sys.exit(2)


HEREDOC = re.compile(r"(?<!<)<<(?!<)(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")
SHELLS = {"bash", "sh", "zsh"}


def extract_heredocs(cmd: str) -> tuple[str, list[str]]:
    """Drop heredoc bodies (file content, not commands) and return bodies fed to a shell."""
    lines, kept, scripts, i = cmd.split("\n"), [], [], 0
    while i < len(lines):
        line = lines[i]
        kept.append(line)
        i += 1
        for match in HEREDOC.finditer(line):
            strip_tabs, tag = match.group(1) == "-", match.group(3)
            body = []
            while i < len(lines) and (lines[i].lstrip("\t") if strip_tabs else lines[i]) != tag:
                body.append(lines[i])
                i += 1
            i += 1
            feeds_shell = any(
                os.path.basename(strip_prefix(t)[0]) in SHELLS
                for t in split_commands(line[: match.start()]) if strip_prefix(t)
            )
            if feeds_shell:
                scripts.append("\n".join(body))
    return "\n".join(kept), scripts


def split_commands(cmd: str) -> list[list[str]]:
    lexer = shlex.shlex(cmd.replace("\\\n", " "), posix=True, punctuation_chars=";&|()\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    commands, current = [], []
    try:
        for tok in lexer:
            if tok in SEPARATORS or set(tok) <= set(";&|()\n"):
                if current:
                    commands.append(current)
                current = []
            else:
                current.append(tok)
    except ValueError:
        return [line.split() for line in cmd.split("\n") if line.strip()]
    if current:
        commands.append(current)
    return commands


def strip_prefix(tokens: list[str]) -> list[str]:
    i = 0
    while i < len(tokens):
        tok = tokens[i]
        if "=" in tok and not tok.startswith("-") and tok.split("=", 1)[0].isidentifier():
            i += 1
        elif os.path.basename(tok) in WRAPPERS:
            i += 1
        else:
            break
    return tokens[i:]


def positional(tokens: list[str], value_flags: set[str] = frozenset()) -> list[str]:
    out, skip = [], False
    for tok in tokens:
        if skip:
            skip = False
            continue
        if tok.startswith("-"):
            if "=" not in tok and tok in value_flags:
                skip = True
            continue
        out.append(tok)
    return out


def leading_path(tokens: list[str]) -> list[str]:
    path = []
    for tok in tokens:
        if tok.startswith("-"):
            break
        path.append(tok)
    return path


def check(tokens: list[str]) -> None:
    tokens = strip_prefix(tokens)
    if not tokens:
        return
    prog, args = os.path.basename(tokens[0]), tokens[1:]

    if prog in {"bash", "sh", "zsh"} and len(args) >= 2 and args[0] == "-c":
        for sub in split_commands(args[1]):
            check(sub)
        return

    if prog in {"terraform", "tofu"}:
        pos = [a for a in args if not a.startswith("-")]
        if any(a == "-lock=false" for a in args):
            block("-lock=false is forbidden")
        if pos and pos[0] in TF_BLOCKED:
            block(f"terraform {pos[0]} is CI-only")
        if len(pos) >= 2 and pos[0] == "state" and pos[1] in TF_STATE_BLOCKED:
            block("terraform state mutations are forbidden; use moved/import/removed blocks")
        if pos and pos[0] == "plan" and "-destroy" in args:
            return

    elif prog == "terragrunt":
        # Forms: `run [--all] -- <tf cmd>`, `run [--all] <tf cmd>`, `run-all <tf cmd>`,
        # shortcuts (`terragrunt apply`), `exec -- <cmd>`, `backend <verb>`, `stack run <tf cmd>`.
        split = args.index("--") if "--" in args else len(args)
        tg_args, passthrough = args[:split], args[split + 1:]
        pos = [a for a in tg_args if not a.startswith("-")]
        if any(a == "-lock=false" for a in args):
            block("-lock=false is forbidden")
        if "--backend-bootstrap" in tg_args or any(a.startswith("--backend-bootstrap=") for a in tg_args):
            block("terragrunt --backend-bootstrap creates/changes the state backend; use infra/bootstrap via CI")
        if pos[:1] == ["exec"]:
            if passthrough:
                check(passthrough)
            return
        if pos[:1] == ["backend"] and len(pos) > 1 and pos[1] in TG_BACKEND_BLOCKED:
            block(f"terragrunt backend {pos[1]} mutates remote state storage")
        hit = next((p for p in pos if p in TG_BLOCKED), None)
        if hit:
            block(f"terragrunt {hit} is CI-only (run --all apply auto-approves)")
        if "state" in pos and any(p in TF_STATE_BLOCKED for p in pos[pos.index("state") + 1:]):
            block("terragrunt state mutations are forbidden; use moved/import/removed blocks")
        if passthrough:
            check(["terraform", *passthrough])

    elif prog == "az":
        path = tuple(leading_path(args))
        if path[:2] == ("aks", "get-credentials") and "--admin" in args:
            block("admin kubeconfig is forbidden; use Entra RBAC + kubelogin")
        if path[:3] == ("keyvault", "secret", "show") or path[:3] == ("keyvault", "secret", "download"):
            block("printing Key Vault secret values is forbidden")
        if path and path not in AZ_ALLOWED_PATHS and path[-1] in AZ_MUTATING:
            block(f"mutating az CLI verb '{' '.join(path)}' is not allowed locally")

    elif prog in {"kubectl", "oc"}:
        pos = positional(args, KUBECTL_VALUE_FLAGS)
        dry_run = any(a.startswith("--dry-run") for a in args)
        if pos and not dry_run:
            if pos[0] in KUBECTL_MUTATING:
                block(f"kubectl {pos[0]} is not allowed (use GitOps/Terraform); --dry-run is allowed")
            if pos[0] == "rollout" and len(pos) > 1 and pos[1] in {"restart", "undo", "pause", "resume"}:
                block(f"kubectl rollout {pos[1]} is not allowed")

    elif prog == "helm":
        pos = positional(args, {"-n", "--namespace", "--kube-context"})
        if pos and pos[0] in HELM_MUTATING and "--dry-run" not in args:
            block(f"helm {pos[0]} is done by GitOps/CI")

    elif prog == "databricks":
        path = leading_path(args)
        if any(p in DATABRICKS_MUTATING for p in path):
            block(f"mutating databricks CLI command '{' '.join(path)}'; manage via Terraform")

    if prog in READERS and any(".tfstate" in a for a in args):
        block("reading or copying Terraform state is forbidden (plain-text secrets)")
    if prog in READERS and any(PLAN_BINARY.search(a) for a in args):
        block("reading binary plan files is forbidden; summarise the `terraform show -json` output instead")


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    pending = [(payload.get("tool_input") or {}).get("command", "")]
    while pending:
        cmd, scripts = extract_heredocs(pending.pop())
        pending.extend(scripts)
        for tokens in split_commands(cmd):
            check(tokens)
    return 0


if __name__ == "__main__":
    sys.exit(main())
