SHELL := /bin/bash
.DEFAULT_GOAL := help

ENV_FILE ?= .env
COMPOSE_BASE = docker compose --env-file $(ENV_FILE) -f compose.yaml
COMPOSE_LOCAL = $(COMPOSE_BASE) -f compose.local.yaml
COMPOSE_VM = $(COMPOSE_BASE) -f compose.vm.yaml

.PHONY: help env vendor check-env check-ports check-network static-check preflight config config-local build-base build up up-local down ps logs restart access-info verify-start verify-target verify-persistence verify-student-interface mfa-status mfa-validate-dbo mfa-validate-abs reset reset-local clean-all ssh-oper ssh-cash ssh-acc ssh-it

help:
	@echo "Virtual Bank Docker lab"
	@echo ""
	@echo "Setup and validation:"
	@echo "  make env                 Create .env from .env.example if missing"
	@echo "  make vendor              Fetch pinned OWASP-101 and Dolibarr sources"
	@echo "  make check-env           Validate required variables and addresses"
	@echo "  make check-ports         Refuse startup when a published port is busy"
	@echo "  make check-network       Check all lab CIDRs against Docker and host routes"
	@echo "  make static-check        Validate shell, Python and both Compose profiles"
	@echo "  make config              Validate Ubuntu VM Compose configuration"
	@echo "  make config-local        Validate local macOS Compose configuration"
	@echo ""
	@echo "Run:"
	@echo "  make build               Build all pinned images"
	@echo "  make up                  Start Ubuntu VM profile (0.0.0.0 bindings)"
	@echo "  make up-local            Start local profile (127.0.0.1 bindings)"
	@echo "  make down                Stop containers and preserve all student volumes"
	@echo "  make ps                  Show service state"
	@echo "  make logs                Follow logs"
	@echo "  make access-info         Print SSH, xRDP, DBO and VPN endpoints"
	@echo "  make verify-start        Verify the expected unsafe START state"
	@echo "  make verify-target       Verify configured TARGET controls"
	@echo "  make verify-student-interface Verify production-style paths shown to students"
	@echo ""
	@echo "Destructive operations:"
	@echo "  CONFIRM=RESET make reset      Delete state and restore START on Ubuntu VM"
	@echo "  CONFIRM=RESET make reset-local Delete state and restore local START"
	@echo "  CONFIRM=DELETE make clean-all Delete containers, volumes and local images"

env:
	@if [[ ! -f "$(ENV_FILE)" ]]; then cp .env.example "$(ENV_FILE)"; echo "Created $(ENV_FILE). Change training passwords before VM exposure."; else echo "$(ENV_FILE) already exists."; fi

vendor:
	@bash scripts/fetch_vendor.sh

check-env: env
	@python3 scripts/validate_env.py "$(ENV_FILE)"

check-ports: check-env
	@python3 scripts/check_ports.py "$(ENV_FILE)"

check-network: check-env
	@python3 scripts/check_networks.py "$(ENV_FILE)"

preflight: check-ports check-network

static-check: check-env
	@find images services scripts tests -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
	@python3 -c 'import ast,pathlib; [ast.parse(p.read_text(), filename=str(p)) for p in pathlib.Path(".").rglob("*.py") if "vendor" not in p.parts]'
	@$(MAKE) config-local
	@$(MAKE) config
	@echo "Static validation passed."

config: check-env
	@$(COMPOSE_VM) config -q

config-local: check-env
	@$(COMPOSE_LOCAL) config -q

build-base: check-env
	@docker build --build-arg UBUNTU_VERSION="$$(awk -F= '$$1=="UBUNTU_VERSION"{print $$2}' $(ENV_FILE))" -t banklab/ubuntu-base:1.0 -f images/ubuntu-base/Dockerfile .

build: vendor config config-local build-base
	@$(COMPOSE_VM) build

up: preflight vendor build-base
	@$(COMPOSE_VM) up -d --build
	@$(MAKE) access-info

up-local: preflight vendor build-base
	@$(COMPOSE_LOCAL) up -d --build
	@$(MAKE) access-info HOST=127.0.0.1

down: env
	@$(COMPOSE_BASE) down

ps: env
	@$(COMPOSE_BASE) ps

logs: env
	@$(COMPOSE_BASE) logs -f --tail=100

restart: env
	@$(COMPOSE_BASE) restart

access-info: env
	@bash scripts/access_info.sh "$(ENV_FILE)" "$${HOST:-$${HOSTNAME:-<VM_IP>}}"

verify-start: env
	@bash tests/verify_start.sh "$(ENV_FILE)"

verify-target: env
	@bash tests/verify_target.sh "$(ENV_FILE)"

verify-persistence: env
	@bash tests/verify_persistence.sh "$(ENV_FILE)"

verify-student-interface: env
	@bash tests/verify_student_interface.sh "$(ENV_FILE)"

mfa-status: env
	@docker exec bank_mfa_dbo banklab-mfa-status
	@docker exec bank_mfa_abs banklab-mfa-status

mfa-validate-dbo: env
	@docker exec bank_mfa_dbo banklab-mfa-validate

mfa-validate-abs: env
	@docker exec bank_mfa_abs banklab-mfa-validate

ssh-oper: env
	@set -a; source "$(ENV_FILE)"; set +a; ssh -p "$$ARM_OPER_HOST_SSH_PORT" "$$LAB_ADMIN_USER@127.0.0.1"

ssh-cash: env
	@set -a; source "$(ENV_FILE)"; set +a; ssh -p "$$ARM_CASH_HOST_SSH_PORT" "$$LAB_ADMIN_USER@127.0.0.1"

ssh-acc: env
	@set -a; source "$(ENV_FILE)"; set +a; ssh -p "$$ARM_ACC_HOST_SSH_PORT" "$$LAB_ADMIN_USER@127.0.0.1"

ssh-it: env
	@set -a; source "$(ENV_FILE)"; set +a; ssh -p "$$ARM_IT_HOST_SSH_PORT" "$$LAB_ADMIN_USER@127.0.0.1"

reset: env
	@if [[ "$(CONFIRM)" != "RESET" ]]; then echo "Reset deletes every student change. Run: CONFIRM=RESET make reset"; exit 1; fi
	@$(COMPOSE_BASE) down --volumes --remove-orphans
	@$(MAKE) up

reset-local: env
	@if [[ "$(CONFIRM)" != "RESET" ]]; then echo "Reset deletes every student change. Run: CONFIRM=RESET make reset-local"; exit 1; fi
	@$(COMPOSE_BASE) down --volumes --remove-orphans
	@$(MAKE) up-local

clean-all: env
	@if [[ "$(CONFIRM)" != "DELETE" ]]; then echo "Full cleanup removes containers, volumes and locally built images. Run: CONFIRM=DELETE make clean-all"; exit 1; fi
	@$(COMPOSE_BASE) down --volumes --remove-orphans --rmi local
