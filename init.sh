#!/usr/bin/env bash
# platform-one — scaffold entire project skeleton in one command
# Usage: bash init.sh [target-dir]   (default: ./platform-one)
set -euo pipefail

ROOT="${1:-./platform-one}"
log()  { echo -e "\033[1;36m▶  $*\033[0m"; }
ok()   { echo -e "\033[1;32m   ✔ $*\033[0m"; }

log "Scaffolding platform-one at: $ROOT"

# ── Directories ────────────────────────────────────────────────────────────────
mkdir -p \
  "$ROOT/.devcontainer" \
  "$ROOT/.github/workflows" \
  "$ROOT/apps/microservice/cmd/server" \
  "$ROOT/apps/microservice/k8s" \
  "$ROOT/apps/frontend/src" \
  "$ROOT/apps/frontend/public" \
  "$ROOT/apps/frontend/k8s" \
  "$ROOT/apps/kafka-consumer/cmd/consumer" \
  "$ROOT/apps/kafka-consumer/k8s" \
  "$ROOT/backstage/templates" \
  "$ROOT/infrastructure/argocd/apps" \
  "$ROOT/infrastructure/argocd/apps-infra" \
  "$ROOT/infrastructure/argocd/applicationsets" \
  "$ROOT/infrastructure/argocd/projects" \
  "$ROOT/infrastructure/cert-manager" \
  "$ROOT/infrastructure/crossplane/xrds" \
  "$ROOT/infrastructure/crossplane/compositions" \
  "$ROOT/infrastructure/external-secrets" \
  "$ROOT/infrastructure/monitoring" \
  "$ROOT/infrastructure/vault" \
  "$ROOT/observability/grafana" \
  "$ROOT/observability/otel" \
  "$ROOT/policies/kyverno" \
  "$ROOT/policies/rego" \
  "$ROOT/portal/k8s" \
  "$ROOT/portal/public" \
  "$ROOT/scripts"
ok "Directories created"

# ── Files ──────────────────────────────────────────────────────────────────────
FILES=(
  ".devcontainer/devcontainer.json"
  ".devcontainer/bootstrap.sh"
  ".github/workflows/ci.yaml"
  ".github/workflows/portal.yaml"
  ".gitignore"
  "init.sh"
  "Makefile"
  "README.md"
  "apps/microservice/Dockerfile"
  "apps/microservice/.dockerignore"
  "apps/microservice/go.mod"
  "apps/microservice/cmd/server/main.go"
  "apps/microservice/k8s/namespace.yaml"
  "apps/microservice/k8s/deployment.yaml"
  "apps/microservice/rollout.yaml"
  "apps/frontend/Dockerfile"
  "apps/frontend/.dockerignore"
  "apps/frontend/package.json"
  "apps/frontend/vite.config.js"
  "apps/frontend/index.html"
  "apps/frontend/nginx.conf"
  "apps/frontend/src/main.jsx"
  "apps/frontend/src/App.jsx"
  "apps/frontend/src/index.css"
  "apps/frontend/k8s/deployment.yaml"
  "apps/kafka-consumer/Dockerfile"
  "apps/kafka-consumer/.dockerignore"
  "apps/kafka-consumer/go.mod"
  "apps/kafka-consumer/cmd/consumer/main.go"
  "apps/kafka-consumer/k8s/deployment.yaml"
  "backstage/templates/rest-microservice-template.yaml"
  "backstage/templates/frontend-app-template.yaml"
  "backstage/templates/kafka-consumer-template.yaml"
  "infrastructure/argocd/helm-values.yaml"
  "infrastructure/argocd/apps/root-app.yaml"
  "infrastructure/argocd/apps/portal.yaml"
  "infrastructure/argocd/apps/tenant-apps.yaml"
  "infrastructure/argocd/apps-infra/crossplane.yaml"
  "infrastructure/argocd/apps-infra/external-secrets.yaml"
  "infrastructure/argocd/apps-infra/kyverno.yaml"
  "infrastructure/argocd/apps-infra/monitoring.yaml"
  "infrastructure/argocd/apps-infra/vault.yaml"
  "infrastructure/argocd/applicationsets/tenant-apps.yaml"
  "infrastructure/argocd/projects/platform-project.yaml"
  "infrastructure/crossplane/xrds/app-environment-xrd.yaml"
  "infrastructure/crossplane/compositions/app-environment-composition.yaml"
  "infrastructure/cert-manager/cluster-issuer.yaml"
  "infrastructure/external-secrets/vault-secret-store.yaml"
  "infrastructure/karpenter-nodepool.yaml"
  "infrastructure/monitoring/prometheus-values.yaml"
  "infrastructure/monitoring/loki-values.yaml"
  "infrastructure/vault/helm-values.yaml"
  "observability/otel/collector-config.yaml"
  "observability/grafana/dora-slo-dashboard.json"
  "policies/kyverno/policy-bundle.yaml"
  "policies/rego/k8s.rego"
  "portal/Dockerfile"
  "portal/.dockerignore"
  "portal/package.json"
  "portal/server.js"
  "portal/public/index.html"
  "portal/k8s/deployment.yaml"
  "scripts/setup-vault.sh"
  "scripts/port-forward.sh"
)

for f in "${FILES[@]}"; do
  touch "$ROOT/$f"
done
ok "${#FILES[@]} files created"

# ── Permissions ────────────────────────────────────────────────────────────────
chmod +x \
  "$ROOT/.devcontainer/bootstrap.sh" \
  "$ROOT/scripts/setup-vault.sh" \
  "$ROOT/scripts/port-forward.sh" \
  "$ROOT/init.sh"
ok "Permissions set"

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  platform-one skeleton created at: $ROOT"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  NEXT: replace YOUR_ORG with your GitHub org:               ║"
echo "║  grep -rl YOUR_ORG . | xargs sed -i s/YOUR_ORG/your-org/g  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
find "$ROOT" -type f | sort | sed "s|$ROOT/||"
