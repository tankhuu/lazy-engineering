#!/usr/bin/env bash
# PostToolUse(Edit|Write|MultiEdit):
#   *.tf/*.tfvars/*.tftest.hcl -> terraform fmt the file, then tflint its directory.
#   Terragrunt *.hcl (infra/deployment/**) -> terragrunt hcl fmt the file, then
#     `terragrunt hcl validate --inputs` on the unit (offline, mock dependency outputs).
# Exit 2 feeds findings back to Claude so it fixes them; formatting itself never blocks.
set -uo pipefail

file="$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("tool_input",{}).get("file_path",""))')"
[[ -f "$file" ]] || exit 0
root="${CLAUDE_PROJECT_DIR:-$(git -C "$(dirname "$file")" rev-parse --show-toplevel 2>/dev/null || pwd)}"

terragrunt_file() {
  command -v terragrunt >/dev/null 2>&1 || exit 0
  terragrunt hcl fmt --file "$file" >/dev/null 2>&1 || {
    echo "terragrunt hcl fmt failed on $file (syntax error?):" >&2
    terragrunt hcl fmt --check --diff --file "$file" >&2 || true
    exit 2
  }
  # Unit file: validate that its inputs match the module variables. Shared files
  # (common.hcl, backend.hcl, env.hcl, _envcommon/*) are covered by `make validate`.
  [[ "$(basename "$file")" == "terragrunt.hcl" ]] || exit 0
  local out
  out="$(cd "$(dirname "$file")" && PLATFORM_OFFLINE=true terragrunt hcl validate --inputs \
    --non-interactive --log-level error 2>&1)"
  if [[ $? -ne 0 ]]; then
    echo "terragrunt hcl validate --inputs failed for $(dirname "$file"):" >&2
    echo "$out" >&2
    exit 2
  fi
  exit 0
}

case "$file" in
  "$root"/infra/deployment/*.hcl | infra/deployment/*.hcl) terragrunt_file ;;
  *.tf|*.tfvars|*.tftest.hcl) ;;
  *) exit 0 ;;
esac
command -v terraform >/dev/null 2>&1 || exit 0

terraform fmt "$file" >/dev/null 2>&1 || {
  echo "terraform fmt failed on $file (syntax error?):" >&2
  terraform fmt -check -diff "$file" >&2 || true
  exit 2
}

[[ "$file" == *.tf ]] || exit 0
command -v tflint >/dev/null 2>&1 || exit 0

dir="$(dirname "$file")"
cfg="$root/.tflint.hcl"
args=(--chdir="$dir" --format=compact --no-color)
[[ -f "$cfg" ]] && args+=(--config="$cfg")

out="$(tflint "${args[@]}" 2>&1)"
rc=$?
if [[ $rc -ne 0 && -n "$out" ]]; then
  # tflint exits 2 when plugins are missing; surface that once instead of blocking every edit.
  if grep -q "plugin" <<<"$out" && grep -qi "not found\|tflint --init" <<<"$out"; then
    echo "tflint plugins missing - run 'make init-tools' (tflint --init)." >&2
    exit 0
  fi
  echo "tflint findings in $dir:" >&2
  echo "$out" >&2
  exit 2
fi
exit 0
