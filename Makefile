.PHONY: help bootstrap up down reset status pf pf-stop \
        vault-setup argocd-pw lint test build-all \
        apply-policies apply-xrds deploy-portal logs

WORKDIR := $(shell pwd)
CLUSTER := platform-one

# ── Default ───────────────────────────────────────────────────────────────────
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Quick start:"
	@echo "    make bootstrap   # Full cluster + all infra (run once)"
	@echo "    make pf          # Open all UIs via port-forward"
	@echo "    make status      # Health check"

# ── Cluster lifecycle ─────────────────────────────────────────────────────────
bootstrap: ## Full bootstrap: cluster + all infra (idempotent)
	bash .devcontainer/bootstrap.sh

up: ## Start existing k3d cluster
	k3d cluster start $(CLUSTER)
	@echo "Cluster started — run 'make pf' to open UIs"

down: ## Stop k3d cluster (preserves state)
	k3d cluster stop $(CLUSTER)

reset: ## DESTROY and recreate cluster from scratch
	k3d cluster delete $(CLUSTER) || true
	bash .devcontainer/bootstrap.sh

# ── Port-forwarding ───────────────────────────────────────────────────────────
pf: ## Start all port-forwards (Portal, ArgoCD, Grafana, Prometheus, Vault)
	bash scripts/port-forward.sh start

pf-stop: ## Stop all port-forwards
	bash scripts/port-forward.sh stop

# ── Status & debug ─────────────────────────────────────────────────────────────
status: ## Show cluster, pod, and ArgoCD app health
	@echo "\n--- Nodes ---"
	kubectl get nodes
	@echo "\n--- Pods (all namespaces) ---"
	kubectl get pods -A --sort-by=.metadata.namespace | grep -v "Running\|Completed" || \
	  kubectl get pods -A --sort-by=.metadata.namespace
	@echo "\n--- ArgoCD Apps ---"
	argocd app list 2>/dev/null || kubectl get applications -n argocd

argocd-pw: ## Print ArgoCD admin password
	@kubectl -n argocd get secret argocd-initial-admin-secret \
	  -o jsonpath="{.data.password}" | base64 -d && echo

# ── Vault ──────────────────────────────────────────────────────────────────────
vault-setup: ## Seed Vault with platform secrets and configure k8s auth
	bash scripts/setup-vault.sh

# ── Policy & infra management ─────────────────────────────────────────────────
apply-policies: ## Apply Kyverno policies
	kubectl apply -f policies/kyverno/policy-bundle.yaml
	@echo "Policies applied"

apply-xrds: ## Apply Crossplane XRDs and compositions
	kubectl apply -f infrastructure/crossplane/xrds/
	kubectl apply -f infrastructure/crossplane/compositions/
	@echo "XRDs and compositions applied"

apply-external-secrets: ## Apply ESO SecretStore and example ExternalSecrets
	kubectl apply -f infrastructure/external-secrets/vault-secret-store.yaml

# ── Portal ─────────────────────────────────────────────────────────────────────
deploy-portal: ## Build and deploy the platform portal
	cd portal && npm install
	kubectl apply -f portal/k8s/
	@echo "Portal deployed — http://localhost:8080"

portal-dev: ## Run portal locally (no k8s)
	cd portal && npm install && npm start

# ── Building ───────────────────────────────────────────────────────────────────
build-all: ## Build Docker images for all apps (requires Docker)
	docker build -t platform-one/microservice:dev    apps/microservice/
	docker build -t platform-one/kafka-consumer:dev  apps/kafka-consumer/
	docker build -t platform-one/frontend:dev        apps/frontend/
	@echo "All images built"

# ── Testing ────────────────────────────────────────────────────────────────────
lint: ## Run conftest policy checks on all k8s manifests
	@if command -v conftest >/dev/null 2>&1; then \
	  find apps -name "*.yaml" -path "*/k8s/*" | \
	    xargs conftest test --policy policies/rego/ --all-namespaces; \
	else \
	  echo "conftest not installed — run bootstrap.sh first"; \
	fi

test: ## Run go tests for all apps
	cd apps/microservice    && go test ./... -v -race
	cd apps/kafka-consumer  && go test ./... -v

# ── Logs ──────────────────────────────────────────────────────────────────────
logs: ## Tail logs from all app pods
	kubectl logs -n microservice   -l app=microservice   -f --tail=50 &
	kubectl logs -n kafka-consumer -l app=kafka-consumer -f --tail=50 &
	kubectl logs -n platform-portal -l app=platform-portal -f --tail=50

logs-portal: ## Tail portal logs only
	kubectl logs -n platform-portal -l app=platform-portal -f --tail=100
