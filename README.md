<div align="center">

```
██████╗ ██╗      █████╗ ████████╗███████╗ ██████╗ ██████╗ ███╗   ███╗      ██╗
██╔══██╗██║     ██╔══██╗╚══██╔══╝██╔════╝██╔═══██╗██╔══██╗████╗ ████║     ███║
██████╔╝██║     ███████║   ██║   █████╗  ██║   ██║██████╔╝██╔████╔██║     ╚██║
██╔═══╝ ██║     ██╔══██║   ██║   ██╔══╝  ██║   ██║██╔══██╗██║╚██╔╝██║      ██║
██║     ███████╗██║  ██║   ██║   ██║     ╚██████╔╝██║  ██║██║ ╚═╝ ██║      ██║
╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝      ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝      ╚═╝
```

**Internal Developer Platform** — from idea to production in under 10 minutes.

[![Bootstrap](https://img.shields.io/badge/Bootstrap-Automated-00e5a0?style=flat-square&logo=gnubash&logoColor=black)](/.devcontainer/bootstrap.sh)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-ef7b4d?style=flat-square&logo=argo&logoColor=white)](https://argoproj.github.io/cd)
[![Crossplane](https://img.shields.io/badge/Infra-Crossplane-ff6b35?style=flat-square)](https://crossplane.io)
[![Kyverno](https://img.shields.io/badge/Policy-Kyverno-326ce5?style=flat-square)](https://kyverno.io)
[![OTel](https://img.shields.io/badge/Observability-OpenTelemetry-425cc7?style=flat-square&logo=opentelemetry)](https://opentelemetry.io)
[![License](https://img.shields.io/badge/License-MIT-8b949e?style=flat-square)](LICENSE)

</div>

---

## ⚡ 60-second overview

```
Developer fills Backstage form
        │
        ▼
 Crossplane provisions:          ArgoCD watches git →
  ├─ RDS PostgreSQL               auto-deploys every push
  ├─ S3 Bucket                         │
  ├─ ElastiCache Redis                 ▼
  └─ Kubernetes namespace        Kyverno enforces:
        │                          ├─ Required labels
        ▼                          ├─ Resource limits
  OTel Collector (auto-injected)  ├─ OTel env injection
  ├─ Metrics → Prometheus          └─ Cosign signatures (Audit)
  ├─ Traces  → Tempo
  └─ Logs    → Loki → Grafana
```

> **No tickets. No waiting. No toil.**

---

## 🚨 Before you do anything — replace `YOUR_ORG`

Every image reference, GitOps repo URL, and Go module path uses `YOUR_ORG` as a placeholder.
Run this **once** from the project root before any other command:

```bash
ORG=your-github-org-name          # e.g. acme-corp
grep -rl "YOUR_ORG" . \
  --include="*.yaml" \
  --include="*.mod"  \
  --include="*.go"   \
  | xargs sed -i "s/YOUR_ORG/${ORG}/g"
```

That's the **only** change required for local Codespaces dev.

---

## 🚀 Quickstart

### Option A — GitHub Codespaces (recommended)

1. Push this repo to `github.com/YOUR_ORG/platform-one`
2. Click **Code → Codespaces → Create codespace on main**
3. Wait ~8 minutes — `bootstrap.sh` runs fully automatically
4. All UIs appear as forwarded ports in the Codespaces panel

### Option B — Local (requires Docker + 16 GB RAM)

```bash
# 1. Scaffold the directory structure
bash init.sh ./platform-one && cd platform-one

# 2. Replace org placeholder
grep -rl "YOUR_ORG" . --include="*.yaml" --include="*.mod" \
  | xargs sed -i "s/YOUR_ORG/your-org/g"

# 3. Bootstrap everything
bash .devcontainer/bootstrap.sh

# 4. Open all UIs via port-forward
make pf

# 5. Seed Vault with platform secrets
make vault-setup
```

---

## 🖥️ UIs & access

| Service | URL | Credentials |
|---|---|---|
| **Platform Portal** | http://localhost:8080 | — |
| **ArgoCD** | http://localhost:8090 | `admin` / `make argocd-pw` |
| **Grafana** | http://localhost:3000 | `admin` / `prom-operator` |
| **Prometheus** | http://localhost:9090 | — |
| **Vault** | http://localhost:8200 | token: `root` |

---

## 📋 All commands

```bash
make help             # Full command reference

# ── Cluster ───────────────────────────────────────────────
make bootstrap        # Full install: cluster + all infra (idempotent)
make up               # Start a stopped cluster
make down             # Stop cluster, preserve state
make reset            # Destroy + recreate from scratch

# ── Access ────────────────────────────────────────────────
make pf               # Start port-forwards for all UIs
make pf-stop          # Stop port-forwards
make argocd-pw        # Print ArgoCD admin password
make status           # Show pod + ArgoCD app health

# ── Platform ops ──────────────────────────────────────────
make vault-setup      # Seed Vault + configure k8s auth
make apply-policies   # Apply/update Kyverno policies
make apply-xrds       # Apply Crossplane XRDs + compositions

# ── Development ───────────────────────────────────────────
make portal-dev       # Run portal locally, no k8s needed
make build-all        # Build all Docker images
make lint             # conftest policy checks on k8s manifests
make test             # Run Go unit tests
make logs             # Tail logs from all app pods
```

---

## 📁 Project structure

```
platform-one/
│
├── 📄 init.sh                          ← Scaffold entire skeleton in one command
├── 📄 Makefile                         ← All operational commands
│
├── 📂 .devcontainer/
│   ├── devcontainer.json               ← Codespaces: 4 CPU, 16 GB, auto-bootstrap
│   └── bootstrap.sh                    ← Full idempotent cluster + infra install
│
├── 📂 .github/workflows/
│   ├── ci.yaml                         ← Trivy + Checkov + cosign + GitOps push
│   └── portal.yaml                     ← Portal image build + sign + deploy
│
├── 📂 apps/
│   ├── microservice/                   ← Go REST API (Prometheus, distroless, non-root)
│   │   ├── cmd/server/main.go          ← HTTP server with /healthz /metrics /api/items
│   │   ├── go.mod
│   │   ├── Dockerfile                  ← Multi-stage, gcr.io/distroless/static
│   │   ├── k8s/                        ← Namespace + Deployment + Service + Ingress
│   │   └── rollout.yaml                ← Argo Rollouts canary + AnalysisTemplates
│   │
│   ├── frontend/                       ← React + Vite SPA (Nginx, 8080, non-root)
│   │   ├── src/                        ← React source (replace with your app)
│   │   ├── Dockerfile                  ← Node build → Nginx serve
│   │   └── k8s/                        ← Namespace + Deployment + Service + Ingress
│   │
│   └── kafka-consumer/                 ← Go Kafka consumer (DLQ, OTel, Prometheus)
│       ├── cmd/consumer/main.go        ← Sarama consumer group with dead-letter queue
│       ├── go.mod
│       ├── Dockerfile
│       └── k8s/                        ← Namespace + Deployment + ConfigMap + Service
│
├── 📂 backstage/templates/
│   ├── rest-microservice-template.yaml ← Form → repo + ArgoCD app + Crossplane infra
│   ├── frontend-app-template.yaml
│   └── kafka-consumer-template.yaml
│
├── 📂 infrastructure/
│   ├── argocd/
│   │   ├── helm-values.yaml            ← ArgoCD Helm config (insecure local mode)
│   │   ├── apps/
│   │   │   ├── root-app.yaml           ← App-of-apps bootstrap point
│   │   │   ├── portal.yaml             ← Platform portal ArgoCD app
│   │   │   └── tenant-apps.yaml        ← ApplicationSet: auto-discovers apps/*
│   │   ├── apps-infra/                 ← Infra app defs (reference; managed by Helm)
│   │   └── projects/platform-project.yaml
│   │
│   ├── crossplane/
│   │   ├── xrds/                       ← AppEnvironment CRD definition
│   │   └── compositions/               ← AWS: RDS + S3 + ElastiCache + namespace
│   │
│   ├── cert-manager/cluster-issuer.yaml← Self-signed CA for local dev
│   ├── external-secrets/               ← ClusterSecretStore + ExternalSecret examples
│   ├── monitoring/                     ← kube-prometheus-stack + Loki Helm values
│   └── vault/helm-values.yaml          ← Vault dev mode (root token)
│
├── 📂 observability/
│   ├── otel/collector-config.yaml      ← ConfigMap + OpenTelemetryCollector CR
│   └── grafana/dora-slo-dashboard.json ← DORA 4 metrics + SLO burn rate dashboard
│
├── 📂 policies/
│   ├── kyverno/policy-bundle.yaml      ← 5 policies (labels, limits, registries, OTel, cosign)
│   └── rego/k8s.rego                   ← conftest policies for CI gates
│
├── 📂 portal/
│   ├── server.js                       ← Zero-dependency Node.js server (built-ins only)
│   ├── public/index.html               ← Full IDP dashboard UI
│   ├── Dockerfile                      ← node:20-alpine, zero npm installs in k8s
│   └── k8s/                            ← Namespace + RBAC + Deployment + Ingress
│
└── 📂 scripts/
    ├── setup-vault.sh                  ← Seed secrets + configure k8s auth
    └── port-forward.sh                 ← Open all UIs [start|stop|status]
```

---

## 🏗️ Architecture planes

### Developer Plane
Backstage Software Templates (3 golden paths: REST API, Frontend, Kafka Consumer).
Each template creates a GitHub repo, registers in the Software Catalog, creates an
ArgoCD Application, and fires a Crossplane Composite Resource Claim — all in one form submit.

### GitOps Plane
ArgoCD with an ApplicationSet that auto-discovers every `apps/*/k8s/` directory.
Every new repo gets a fully managed ArgoCD Application with automated sync and self-heal.
Argo Rollouts handles progressive delivery with Prometheus-gated canary analysis.

### Policy Plane
Kyverno with five policies applied at admission time:

| Policy | Mode | What it does |
|---|---|---|
| `require-labels` | **Enforce** | Blocks any Deployment missing `team` or `app.kubernetes.io/name` |
| `require-resource-limits` | **Enforce** | Blocks any Pod without CPU + memory limits |
| `restrict-image-registries` | Audit | Reports images not from approved registries |
| `inject-otel-env` | Mutate | Adds `OTEL_*` env vars to pods in labelled namespaces |
| `verify-image-signatures` | Audit | Reports unsigned images (cosign keyless) |

### Infrastructure Plane
Crossplane `AppEnvironment` Composite Resource provisions:
RDS PostgreSQL + S3 bucket + optional ElastiCache Redis + Kubernetes namespace — all from one `kubectl apply`.

### Observability Plane
OpenTelemetry Collector running as a Deployment:
- Metrics → Prometheus (remote write)
- Traces → Tempo
- Logs → Loki

All correlated in Grafana via exemplars. DORA metrics dashboard included.

---

## 📐 Implementation roadmap

```
Week 1-2   ████████░░░░░░░░░░░░  k3d + ArgoCD + GitOps structure
Week 3-4   ████████████░░░░░░░░  Backstage + 3 Software Templates
Week 5-6   ████████████████░░░░  Crossplane XRDs + AWS provisioning
Week 7-8   ████████████████████  Vault + ESO + Kyverno policies
Week 9-10  ████████████████████  Argo Rollouts + OTel pipeline
Week 11-12 ████████████████████  Karpenter + CI gates + DORA dashboard
```

---

## 🏭 Production (AWS EKS)

Additional requirements beyond local dev:

```bash
# IAM roles needed
KarpenterNodeRole-platform-one
CrossplaneProviderRole   # AmazonRDS*, AmazonS3*, AmazonElastiCache*, EKS*

# Additional placeholder to replace
your-ecr-account → your AWS account ID
# In: policies/kyverno/policy-bundle.yaml

# Secrets in AWS Secrets Manager
/platform-one/argocd/github-token
/platform-one/backstage/github-oauth-client-id
/platform-one/backstage/github-oauth-client-secret
```

---

## 📊 DORA metrics (target)

| Metric | Target | Elite threshold |
|---|---|---|
| Deployment Frequency | **14.2 /day** | > 1/day |
| Lead Time for Changes | **23 min** | < 1 hour |
| Change Failure Rate | **2.1 %** | < 5% |
| MTTR | **18 min** | < 1 hour |

---

## 🛡️ Security posture

- **Zero-trust networking** — SPIFFE/SPIRE workload identity (phase 6)
- **Keyless image signing** — cosign OIDC via GitHub Actions OIDC token
- **No long-lived secrets** — all secrets from Vault via External Secrets Operator
- **Admission control** — Kyverno blocks non-compliant workloads at API server
- **Supply chain** — Trivy + Checkov + conftest in every PR
- **Audit mode for strict policies** — cosign + registry restrictions are Audit in dev,
  switch to Enforce in production by editing `validationFailureAction`

---

## 💰 Cost optimisation

Karpenter NodePool configured for spot/on-demand mix:
- Prefers spot instances (`karpenter.sh/capacity-type: spot`)
- Falls back to on-demand automatically
- Consolidates underutilised nodes every 30 seconds
- **Expected saving: ~65% vs on-demand only**

---

## 🤝 Contributing

1. Fork the repo
2. Open in Codespaces (bootstrap runs automatically)
3. Make changes in a branch
4. CI runs: `trivy` + `checkov` + `conftest` on every PR
5. Merge → ArgoCD auto-deploys

---

<div align="center">

Built with Backstage · Crossplane · ArgoCD · Kyverno · Vault · OpenTelemetry

**⭐ Star this repo if it saved you from filing a ticket**

</div>
