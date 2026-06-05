#!/usr/bin/env bash
# scripts/setup-vault.sh
# Seeds Vault (dev mode) with platform secrets and configures Kubernetes auth.
# Run AFTER bootstrap: bash scripts/setup-vault.sh
set -euo pipefail

export VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
export VAULT_TOKEN="${VAULT_TOKEN:-root}"

log()  { echo -e "\033[1;36m==> $*\033[0m"; }
ok()   { echo -e "\033[1;32m✔  $*\033[0m"; }
warn() { echo -e "\033[1;33m⚠  $*\033[0m"; }

# ── Port-forward Vault if not reachable ──────────────────────────────────────
PF_PID=""
if ! curl -sf "${VAULT_ADDR}/v1/sys/health" > /dev/null 2>&1; then
  log "Port-forwarding Vault on :8200..."
  kubectl port-forward -n vault svc/vault 8200:8200 &
  PF_PID=$!
  sleep 4
fi
trap '[ -n "$PF_PID" ] && kill "$PF_PID" 2>/dev/null || true' EXIT

log "Vault status"
vault status 2>/dev/null || warn "Vault may still be starting — continuing"

# ── Enable KV v2 ──────────────────────────────────────────────────────────────
log "Enabling KV v2 at secret/"
vault secrets enable -path=secret kv-v2 2>/dev/null || ok "KV v2 already enabled"

# ── Seed secrets ──────────────────────────────────────────────────────────────
log "Writing microservice/database"
vault kv put secret/microservice/database \
  host="microservice-db.microservice.svc:5432" \
  username="appuser" \
  password="$(openssl rand -base64 20)"
ok "microservice/database"

log "Writing platform-portal/config"
vault kv put secret/platform-portal/config \
  session_secret="$(openssl rand -base64 32)"
ok "platform-portal/config"

log "Writing kafka-consumer/config"
vault kv put secret/kafka-consumer/config \
  brokers="kafka.kafka.svc:9092" \
  consumer_group="platform-consumer"
ok "kafka-consumer/config"

# ── Enable Kubernetes auth ─────────────────────────────────────────────────────
log "Enabling Kubernetes auth"
vault auth enable kubernetes 2>/dev/null || ok "k8s auth already enabled"

# Write CA cert to temp file (avoids bash process substitution)
TMPCA=$(mktemp)
kubectl get cm -n kube-system kube-root-ca.crt -o jsonpath='{.data.ca\.crt}' > "$TMPCA"
trap 'rm -f "$TMPCA"; [ -n "$PF_PID" ] && kill "$PF_PID" 2>/dev/null || true' EXIT

K8S_HOST=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')

vault write auth/kubernetes/config \
  kubernetes_host="$K8S_HOST" \
  kubernetes_ca_cert=@"$TMPCA" \
  disable_iss_validation=true
ok "Kubernetes auth configured"

# ── Policy ────────────────────────────────────────────────────────────────────
log "Writing platform-read policy"
vault policy write platform-read - << 'POLICY'
path "secret/data/*" {
  capabilities = ["read", "list"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list"]
}
POLICY
ok "policy written"

# ── Auth roles per namespace ──────────────────────────────────────────────────
for ns in microservice kafka-consumer frontend platform-portal; do
  vault write "auth/kubernetes/role/${ns}" \
    bound_service_account_names=default \
    bound_service_account_namespaces="$ns" \
    policies=platform-read \
    ttl=1h
  ok "k8s auth role: $ns"
done

echo ""
echo "╔════════════════════════════════════════════╗"
echo "║  Vault setup complete ✅                   ║"
echo "║  UI:    http://localhost:8200              ║"
echo "║  Token: root  (dev mode)                  ║"
echo "╚════════════════════════════════════════════╝"
