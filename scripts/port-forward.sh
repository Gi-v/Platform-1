#!/usr/bin/env bash
# scripts/port-forward.sh
# Opens all platform UIs in background port-forwards.
# Usage: bash scripts/port-forward.sh [start|stop|status]
set -euo pipefail

PF_DIR="/tmp/platform-one-pf"
mkdir -p "$PF_DIR"

start_pf() {
  local name=$1 ns=$2 svc=$3 local_port=$4 remote_port=$5
  local pidfile="$PF_DIR/${name}.pid"
  if [ -f "$pidfile" ] && kill -0 "$(cat $pidfile)" 2>/dev/null; then
    echo "  ⚡ $name already forwarding on :$local_port"
    return
  fi
  kubectl port-forward -n "$ns" "svc/$svc" "$local_port:$remote_port" \
    > "$PF_DIR/${name}.log" 2>&1 &
  echo $! > "$pidfile"
  echo "  ✔ $name  →  http://localhost:$local_port"
}

stop_pf() {
  for pidfile in "$PF_DIR"/*.pid; do
    [ -f "$pidfile" ] || continue
    pid=$(cat "$pidfile")
    name=$(basename "$pidfile" .pid)
    kill "$pid" 2>/dev/null && echo "  stopped $name" || true
    rm -f "$pidfile"
  done
}

case "${1:-start}" in
  start)
    echo "Starting port-forwards..."
    start_pf argocd     argocd          argocd-server            8090 80
    start_pf grafana    monitoring      kube-prometheus-grafana  3000 80
    start_pf prometheus monitoring      kube-prometheus-kube-prome-prometheus 9090 9090
    start_pf vault      vault           vault                    8200 8200
    start_pf portal     platform-portal platform-portal          8080 80
    echo ""
    echo "All UIs available:"
    echo "  Portal      → http://localhost:8080"
    echo "  ArgoCD      → http://localhost:8090   (admin / see bootstrap output)"
    echo "  Grafana     → http://localhost:3000   (admin / prom-operator)"
    echo "  Prometheus  → http://localhost:9090"
    echo "  Vault       → http://localhost:8200   (token: root)"
    ;;
  stop)
    echo "Stopping port-forwards..."
    stop_pf
    echo "done"
    ;;
  status)
    echo "Port-forward status:"
    for pidfile in "$PF_DIR"/*.pid; do
      [ -f "$pidfile" ] || continue
      pid=$(cat "$pidfile")
      name=$(basename "$pidfile" .pid)
      if kill -0 "$pid" 2>/dev/null; then
        echo "  ✔ $name (pid $pid)"
      else
        echo "  ✗ $name (dead)"
      fi
    done
    ;;
  *)
    echo "Usage: $0 [start|stop|status]"
    exit 1
    ;;
esac
