# ----------- config (rename.sh will update these) -----------
PKG_U=template_python_project   # underscored (module import path)
PKG_H=template-python-project   # hyphenated (CLI/app name)

UV ?= uv
PY ?= python

# ----------- meta -----------
.DEFAULT_GOAL := help
.PHONY: help setup fmt lint test run build check clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ----------- env mgmt -----------
setup: ## Create/refresh local venv with uv (lock + sync)
	$(UV) lock
	$(UV) sync

# ----------- quality -----------
fmt: ## Format code with Ruff (formatter)
	$(UV) run ruff format .

lint: ## Lint code with Ruff (checks only)
	$(UV) run ruff check .

test: ## Run tests with pytest
	$(UV) run pytest -q

check: lint test ## Lint + test

# ----------- run/build -----------
run: ## Run the application
	$(UV) run $(PKG_H)

build: ## Build via Nix (uses uv.lock through uv2nix)
	nix build

# ----------- misc -----------
clean: ## Remove caches and build artifacts
	rm -rf .venv .uv __pycache__ .pytest_cache build dist result \
	       **/__pycache__ **/*.pyc **/*.pyo
