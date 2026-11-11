SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# Terragrunt layout (backbase-rnd/ri-iac ADR-005): infra/deployment/<env>/<unit>/terragrunt.hcl
ENV      ?= dev
UNIT     ?=
TG_ROOT  := infra/deployment
TG_DIR   := $(TG_ROOT)/$(ENV)
TG_ENVS  := $(sort $(patsubst $(TG_ROOT)/%/env.hcl,%,$(wildcard $(TG_ROOT)/*/env.hcl)))
PLAN_DIR := $(CURDIR)/.plans/$(ENV)
MODULES  := $(sort $(dir $(wildcard infra/modules/*/versions.tf)))
ROOTS    := infra/bootstrap
TG       := terragrunt --non-interactive
# Offline: dependencies return mock_outputs, no backend, placeholder IDs (see common.hcl).
TG_OFFLINE := PLATFORM_OFFLINE=true $(TG) --log-level error

# azurerm >= 4 needs a subscription; default to the active az CLI context.
export ARM_SUBSCRIPTION_ID ?= $(shell az account show --query id -o tsv 2>/dev/null)
export ARM_TENANT_ID       ?= $(shell az account show --query tenantId -o tsv 2>/dev/null)

.PHONY: help
help: ## Show targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

## --- Harness -------------------------------------------------------------

.PHONY: ecc-sync
ecc-sync: ## Install/refresh ECC into .claude and apply the platform pack
	python3 scripts/ecc_sync.py

.PHONY: init-tools
init-tools: ## Install tflint plugins and pre-commit hooks
	tflint --init --config=.tflint.hcl
	pre-commit install

## --- Static checks (offline) ---------------------------------------------

.PHONY: fmt
fmt: ## terraform fmt + terragrunt hcl fmt (write)
	terraform fmt -recursive infra/modules infra/bootstrap
	$(TG) hcl fmt --working-dir $(TG_ROOT)

.PHONY: fmt-check
fmt-check: ## terraform fmt + terragrunt hcl fmt (check only)
	terraform fmt -check -recursive -diff infra/modules infra/bootstrap
	$(TG) hcl fmt --check --diff --working-dir $(TG_ROOT)

.PHONY: validate
validate: ## Terragrunt inputs + terraform validate for one env, offline (ENV=dev)
	$(TG_OFFLINE) hcl validate --inputs --working-dir $(TG_DIR)
	$(TG_OFFLINE) run --all --working-dir $(TG_DIR) -- init -backend=false -input=false >/dev/null
	$(TG_OFFLINE) run --all --no-auto-init --working-dir $(TG_DIR) -- validate -no-color

.PHONY: validate-all
validate-all: ## validate every module, bootstrap and every env (offline)
	@for d in $(MODULES) $(ROOTS); do \
	  echo "==> $$d"; \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null; \
	  if grep -q configuration_aliases $$d/versions.tf 2>/dev/null; then \
	    echo "   (provider aliases: validated through its Terragrunt unit)"; \
	  else \
	    terraform -chdir=$$d validate -no-color; \
	  fi; \
	done
	@for e in $(TG_ENVS); do echo "==> $(TG_ROOT)/$$e"; $(MAKE) --no-print-directory validate ENV=$$e; done

.PHONY: tflint
tflint: ## tflint modules and bootstrap
	@for d in infra/modules infra/bootstrap; do \
	  tflint --config="$(CURDIR)/.tflint.hcl" --recursive --chdir=$$d --format=compact; \
	done

.PHONY: checkov
checkov: ## checkov static security scan (modules + bootstrap)
	checkov --config-file .checkov.yaml

.PHONY: checkov-plan
checkov-plan: ## checkov on the plan JSON from `make plan` (ENV=dev)
	@test -d $(PLAN_DIR) || { echo "no plans in $(PLAN_DIR); run 'make plan ENV=$(ENV)' first"; exit 1; }
	checkov --config-file .checkov.yaml --framework terraform_plan -d $(PLAN_DIR) --repo-root-for-plan-enrichment .

.PHONY: lint
lint: fmt-check tflint checkov ## fmt-check + tflint + checkov

.PHONY: test
test: test-modules test-wiring test-hooks ## module tests + Terragrunt wiring checks + guard hook cases

.PHONY: test-modules
test-modules: ## terraform test for every module and bootstrap (mocked providers)
	@for d in $(MODULES) $(ROOTS); do \
	  if [ -d "$$d/tests" ]; then \
	    echo "==> $$d"; \
	    terraform -chdir=$$d init -backend=false -input=false >/dev/null; \
	    terraform -chdir=$$d test -no-color; \
	  fi; \
	done

.PHONY: test-wiring
test-wiring: ## render every unit offline and assert naming/tags/state keys/network invariants
	python3 $(TG_ROOT)/tests/render_check.py $(TG_ENVS)

.PHONY: test-hooks
test-hooks: ## guard-bash.py block/allow regression cases
	python3 .claude/hooks-platform/test_guard_bash.py

.PHONY: docs
docs: ## Regenerate module READMEs with terraform-docs
	@for d in $(MODULES); do terraform-docs --config .terraform-docs.yml $$d; done

.PHONY: graph
graph: ## Unit dependency graph for one env (ENV=dev)
	$(TG) dag graph --working-dir $(TG_DIR)

## --- Environment (read-only against Azure) -------------------------------

.PHONY: plan
plan: ## terragrunt plan, all units or UNIT=aks (ENV=dev). Writes binary + JSON plans to .plans/<env>. Apply is CI-only.
	@rm -rf $(PLAN_DIR) && mkdir -p $(PLAN_DIR)
ifeq ($(strip $(UNIT)),)
	$(TG) run --all --working-dir $(TG_DIR) --out-dir $(PLAN_DIR) --json-out-dir $(PLAN_DIR) \
	  -- plan -input=false -lock-timeout=5m
else
	$(TG) run --working-dir $(TG_DIR)/$(UNIT) -- plan -input=false -lock-timeout=5m -out=$(PLAN_DIR)/$(UNIT).tfplan
	$(TG) run --working-dir $(TG_DIR)/$(UNIT) -- show -json $(PLAN_DIR)/$(UNIT).tfplan > $(PLAN_DIR)/$(UNIT).json
endif
	@echo "Plan JSON under $(PLAN_DIR) (summarise with the terraform-plan-analyzer agent)"

.PHONY: drift
drift: ## refresh-only plan per unit; exit 2 means drift (ENV=dev)
	$(TG) run --all --working-dir $(TG_DIR) --json-out-dir $(PLAN_DIR)/drift \
	  -- plan -refresh-only -detailed-exitcode -input=false -lock-timeout=5m

.PHONY: output
output: ## terragrunt output -json for one unit (ENV=dev UNIT=aks)
	@test -n "$(UNIT)" || { echo "UNIT is required, e.g. make output ENV=dev UNIT=aks"; exit 1; }
	@$(TG) --log-level error output -json --working-dir $(TG_DIR)/$(UNIT)

.PHONY: lock
lock: ## Refresh .terraform.lock.hcl in bootstrap and every unit for linux + macOS
	@for d in $(ROOTS); do \
	  terraform -chdir=$$d init -backend=false -input=false >/dev/null; \
	  terraform -chdir=$$d providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64; \
	done
	$(TG_OFFLINE) run --all --working-dir $(TG_ROOT) -- init -backend=false -input=false >/dev/null
	$(TG_OFFLINE) run --all --no-auto-init --working-dir $(TG_ROOT) \
	  -- providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64

.PHONY: clean
clean: ## Remove local .terraform/.terragrunt-cache dirs and plan files
	find infra -type d \( -name .terraform -o -name .terragrunt-cache \) -prune -exec rm -rf {} +
	find infra -type f \( -name 'tfplan' -o -name '*.tfplan' -o -name 'tfplan.json' -o -name 'drift.json' \) -delete
	rm -rf .plans
