#!/usr/bin/env bash
# platform-one bootstrap — runs automatically in GitHub Codespaces
set -euo pipefail

WORKDIR="/workspaces/platform-one"
BIN="/usr/local/bin"

log()  { echo -e "\033[1;36m==> $*\033[0m"; }
ok()   { echo -e "\033[1;32m✔  $*\033[0m"; }
warn() { echo -e "\033[1;33m⚠  $*\033[0m"; }

# ── Helper: latest GitHub release tag ───────────────────────────────────────
gh_latest() {
  curl -sf "https://api.github.com/repos/$1/releases/latest" \
    | grep '"tag_name"' | head -1 | cut -d'"' -f4
}

# ── k3d ─────────────────────────────────────────────────────────────────────
if ! command -v k3d &>/dev/null; then
  log "Installing k3d"
  curl -sf https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi
ok "k3d $(k3d version | head -1)"

# ── kubectl (already in universal image, but ensure it) ─────────────────────
if ! command -v kubectl &>/dev/null; then
  log "Installing kubectl"
  K8S_VER=$(curl -sf https://dl.k8s.io/release/stable.txt)
  curl -sfLo "$BIN/kubectl" "https://dl.k8s.io/release/${K8S_VER}/bin/linux/amd64/kubectl"
  chmod +x "$BIN/kubectl"
fi
ok "kubectl $(kubectl version --client --short 2>/dev/null || kubectl version --client)"

# ── Helm ─────────────────────────────────────────────────────────────────────
if ! command -v helm &>/dev/null; then
  log "Installing Helm"
  curl -sf https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
ok "helm $(helm version --short)"

# ── ArgoCD CLI ───────────────────────────────────────────────────────────────
if ! command -v argocd &>/dev/null; then
  log "Installing ArgoCD CLI"
  ARGOCD_VER=$(gh_latest argoproj/argo-cd)
  curl -sfLo "$BIN/argocd" \
    "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VER}/argocd-linux-amd64"
  chmod +x "$BIN/argocd"
fi
ok "argocd $(argocd version --client --short 2>/dev/null | head -1)"

# ── cosign ───────────────────────────────────────────────────────────────────
if ! command -v cosign &>/dev/null; then
  log "Installing cosign"
  COSIGN_VER=$(gh_latest sigstore/cosign)
  curl -sfLo "$BIN/cosign" \
    "https://github.com/sigstore/cosign/releases/download/${COSIGN_VER}/cosign-linux-amd64"
  chmod +x "$BIN/cosign"
fi
ok "cosign $(cosign version 2>/dev/null | grep GitVersion | awk '{print $2}')"

# ── syft ─────────────────────────────────────────────────────────────────────
if ! command -v syft &>/dev/null; then
  log "Installing syft"
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh \
    | sh -s -- -b "$BIN" 2>/dev/null
fi
ok "syft $(syft --version)"

# ── Trivy ────────────────────────────────────────────────────────────────────
if ! command -v trivy &>/dev/null; then
  log "Installing Trivy"
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b "$BIN" 2>/dev/null
fi
ok "trivy $(trivy --version | head -1)"

# ── Vault CLI ────────────────────────────────────────────────────────────────
if ! command -v vault &>/dev/null; then
  log "Installing Vault CLI"
  VAULT_VER="1.17.2"
  curl -sSLo /tmp/vault.zip \
    "https://releases.hashicorp.com/vault/${VAULT_VER}/vault_${VAULT_VER}_linux_amd64.zip"
  unzip -qo /tmp/vault.zip -d "$BIN" && rm /tmp/vault.zip
fi
ok "vault $(vault version)"

# ── conftest ─────────────────────────────────────────────────────────────────
if ! command -v conftest &>/dev/null; then
  log "Installing conftest"
  CVER=$(gh_latest open-policy-agent/conftest | tr -d v)
  curl -sSLo /tmp/conftest.tar.gz \
    "https://github.com/open-policy-agent/conftest/releases/download/v${CVER}/conftest_${CVER}_Linux_x86_64.tar.gz"
  tar -xzf /tmp/conftest.tar.gz -C "$BIN" conftest && rm /tmp/conftest.tar.gz
fi
ok "conftest $(conftest --version)"

# ── k9s ──────────────────────────────────────────────────────────────────────
if ! command -v k9s &>/dev/null; then
  log "Installing k9s"
  K9S_VER=$(gh_latest derailed/k9s)
  curl -sSLo /tmp/k9s.tar.gz \
    "https://github.com/derailed/k9s/releases/download/${K9S_VER}/k9s_Linux_amd64.tar.gz"
  tar -xzf /tmp/k9s.tar.gz -C "$BIN" k9s && rm /tmp/k9s.tar.gz
fi
ok "k9s $(k9s version --short 2>/dev/null | head -1)"

# ── Node deps for portal ─────────────────────────────────────────────────────
if [ -f "$WORKDIR/portal/package.json" ]; then
  log "Installing portal npm dependencies"
  cd "$WORKDIR/portal" && npm install --silent
  ok "Portal deps installed"
fi

# ── Create k3d cluster ───────────────────────────────────────────────────────
if ! k3d cluster list | grep -q "^platform-one"; then
  log "Creating k3d cluster (platform-one)"
  k3d cluster create platform-one \
    --port "8080:80@loadbalancer" \
    --port "8443:443@loadbalancer" \
    --agents 2 \
    --k3s-arg "--disable=traefik@server:0" \
    --k3s-arg "--disable=servicelb@server:0" \
    --wait
  ok "k3d cluster created"
else
  warn "k3d cluster 'platform-one' already exists — skipping"
fi

kubectl config use-context k3d-platform-one

# ── Add Helm repos ────────────────────────────────────────────────────────────
log "Adding Helm repos"
helm repo add argo          https://argoproj.github.io/argo-helm           2>/dev/null || true
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx     2>/dev/null || true
helm repo add cert-manager  https://charts.jetstack.io                     2>/dev/null || true
helm repo add crossplane    https://charts.crossplane.io/stable            2>/dev/null || true
helm repo add hashicorp     https://helm.releases.hashicorp.com            2>/dev/null || true
helm repo add grafana       https://grafana.github.io/helm-charts          2>/dev/null || true
helm repo add prometheus    https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add kyverno       https://kyverno.github.io/kyverno/             2>/dev/null || true
helm repo add external-secrets https://charts.external-secrets.io          2>/dev/null || true
helm repo add open-telemetry   https://open-telemetry.github.io/opentelemetry-helm-charts 2>/dev/null || true
helm repo update

# ── Namespaces ───────────────────────────────────────────────────────────────
log "Creating namespaces"
for ns in argocd crossplane-system vault monitoring kyverno external-secrets cert-manager ingress-nginx platform-portal; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# ── ingress-nginx ─────────────────────────────────────────────────────────────
log "Installing ingress-nginx"
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --set controller.service.type=LoadBalancer \
  --set controller.hostPort.enabled=true \
  --set controller.hostPort.ports.http=80 \
  --set controller.hostPort.ports.https=443 \
  --wait --timeout 120s
ok "ingress-nginx ready"

# ── cert-manager ──────────────────────────────────────────────────────────────
log "Installing cert-manager"
helm upgrade --install cert-manager cert-manager/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true \
  --wait --timeout 120s
ok "cert-manager ready"

# ── ArgoCD ───────────────────────────────────────────────────────────────────
log "Installing ArgoCD"
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --values "$WORKDIR/infrastructure/argocd/helm-values.yaml" \
  --wait --timeout 180s
ok "ArgoCD ready"

# ── Argo Rollouts ─────────────────────────────────────────────────────────────
log "Installing Argo Rollouts"
helm upgrade --install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts \
  --create-namespace \
  --set dashboard.enabled=true \
  --wait --timeout 120s
ok "Argo Rollouts ready"

# ── Crossplane ────────────────────────────────────────────────────────────────
log "Installing Crossplane"
helm upgrade --install crossplane crossplane/crossplane \
  --namespace crossplane-system \
  --set args='{--enable-composition-revisions}' \
  --wait --timeout 180s
ok "Crossplane ready"

# ── Crossplane Providers ──────────────────────────────────────────────────────
log "Installing Crossplane providers (kubernetes + AWS)"
# Kubernetes provider — needed for namespace/object management in local dev
kubectl apply -f - <<'PROVIDER'
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.14.1
  installRuntimeConfig:
    spec:
      serviceAccountName: provider-kubernetes
PROVIDER

# Wait for provider to be healthy (up to 3 min)
echo "Waiting for Crossplane Kubernetes provider..."
for i in $(seq 1 36); do
  STATUS=$(kubectl get provider provider-kubernetes -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}' 2>/dev/null || echo "")
  [ "$STATUS" = "True" ] && { ok "Crossplane Kubernetes provider ready"; break; }
  sleep 5
done

# Grant provider cluster-admin for local dev
kubectl create clusterrolebinding crossplane-provider-kubernetes \
  --clusterrole=cluster-admin \
  --serviceaccount=crossplane-system:provider-kubernetes 2>/dev/null || true

ok "Crossplane providers ready"

# ── Kyverno ──────────────────────────────────────────────────────────────────
log "Installing Kyverno"
helm upgrade --install kyverno kyverno/kyverno \
  --namespace kyverno \
  --set admissionController.replicas=1 \
  --wait --timeout 180s
ok "Kyverno ready"

# ── Apply Kyverno policies ────────────────────────────────────────────────────
log "Applying Kyverno policies"
kubectl apply -f "$WORKDIR/policies/kyverno/policy-bundle.yaml" || warn "Some policies need cluster to warm up first"

# ── External Secrets Operator ─────────────────────────────────────────────────
log "Installing External Secrets Operator"
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --wait --timeout 120s
ok "External Secrets Operator ready"

# ── Vault (dev mode for local) ────────────────────────────────────────────────
log "Installing Vault (dev mode)"
helm upgrade --install vault hashicorp/vault \
  --namespace vault \
  --values "$WORKDIR/infrastructure/vault/helm-values.yaml" \
  --wait --timeout 120s
ok "Vault ready"

# ── kube-prometheus-stack ────────────────────────────────────────────────────
log "Installing kube-prometheus-stack"
helm upgrade --install kube-prometheus prometheus/kube-prometheus-stack \
  --namespace monitoring \
  --values "$WORKDIR/infrastructure/monitoring/prometheus-values.yaml" \
  --wait --timeout 300s
ok "Prometheus + Grafana ready"

# ── Loki ─────────────────────────────────────────────────────────────────────
log "Installing Loki"
helm upgrade --install loki grafana/loki \
  --namespace monitoring \
  --values "$WORKDIR/infrastructure/monitoring/loki-values.yaml" \
  --wait --timeout 120s
ok "Loki ready"

# ── Tempo ─────────────────────────────────────────────────────────────────────
log "Installing Tempo"
helm upgrade --install tempo grafana/tempo \
  --namespace monitoring \
  --set tempo.storage.trace.backend=local \
  --wait --timeout 120s
ok "Tempo ready"

# ── OTel Operator ─────────────────────────────────────────────────────────────
log "Installing OpenTelemetry Operator"
helm upgrade --install opentelemetry-operator open-telemetry/opentelemetry-operator \
  --namespace monitoring \
  --set "manager.collectorImage.repository=otel/opentelemetry-collector-contrib" \
  --wait --timeout 120s
kubectl apply -f "$WORKDIR/observability/otel/collector-config.yaml"
ok "OTel Operator ready"

# ── Apply Crossplane XRDs ─────────────────────────────────────────────────────
log "Applying Crossplane XRDs"
kubectl apply -f "$WORKDIR/infrastructure/crossplane/xrds/" || warn "XRDs queued"
kubectl apply -f "$WORKDIR/infrastructure/crossplane/compositions/" || warn "Compositions queued"


# ── Apply ArgoCD project and RBAC ────────────────────────────────────────────
log "Creating ArgoCD platform project"
kubectl apply -f "$WORKDIR/infrastructure/argocd/projects/platform-project.yaml"
ok "ArgoCD platform project created"

# ── Bootstrap ArgoCD root app ─────────────────────────────────────────────────
log "Bootstrapping ArgoCD root app"
kubectl apply -f "$WORKDIR/infrastructure/argocd/apps/root-app.yaml"


# ── Portal ConfigMaps (bundle source code into cluster) ───────────────────────
log "Creating portal source ConfigMaps"
kubectl create configmap platform-portal-src \
  --from-file="$WORKDIR/portal/server.js" \
  --from-file="$WORKDIR/portal/package.json" \
  -n platform-portal --dry-run=client -o yaml | kubectl apply -f -

kubectl create configmap platform-portal-public \
  --from-file="$WORKDIR/portal/public/index.html" \
  -n platform-portal --dry-run=client -o yaml | kubectl apply -f -
ok "Portal ConfigMaps created"

# ── Deploy Platform Portal ────────────────────────────────────────────────────
log "Deploying Platform Portal"
kubectl apply -f "$WORKDIR/portal/k8s/"
ok "Platform Portal deploying"

# ── Print summary ─────────────────────────────────────────────────────────────
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "check-argocd-secret")

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           platform-one is ready 🚀                          ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Portal      → http://localhost:8080                        ║"
echo "║  ArgoCD      → http://localhost:8080/argocd                 ║"
echo "║  Grafana     → http://localhost:3000  (admin/prom-operator) ║"
echo "║  Prometheus  → http://localhost:9090                        ║"
echo "║  Vault       → http://localhost:8200  (token: root)         ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  ArgoCD admin password: $ARGOCD_PASS"
echo "╚══════════════════════════════════════════════════════════════╝"
