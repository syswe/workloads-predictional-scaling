#!/usr/bin/env bash
set -euo pipefail

# PHPA stop/cleanup script
# - Deletes load generator, PHPA CRs, sample app
# - Optionally deletes operator, CRD, metrics-server

NS="default"
DEEP=0   # if 1, also remove operator, CRD; metrics-server optional
RM_METRICS=0

usage() {
  cat <<EOF
Usage: bash scripts/phpa-stop.sh [options]
  -n, --namespace <ns>   Kubernetes namespace (default: default)
      --deep             Also remove operator and CRD
      --rm-metrics       Remove metrics-server as well
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NS="$2"; shift 2;;
    --deep) DEEP=1; shift;;
    --rm-metrics) RM_METRICS=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

echo "[1/5] Deleting load generator"
kubectl -n "$NS" delete pod load-generator --ignore-not-found

echo "[2/5] Deleting PHPA resources (examples)"
kubectl -n "$NS" delete -f examples/simple-gbdt/phpa.yaml --ignore-not-found
kubectl -n "$NS" delete -f examples/simple-xgboost/phpa.yaml --ignore-not-found
kubectl -n "$NS" delete -f examples/simple-var/phpa.yaml --ignore-not-found
kubectl -n "$NS" delete -f examples/simple-catboost/phpa.yaml --ignore-not-found
kubectl -n "$NS" delete -f examples/multi-model/phpa.yaml --ignore-not-found || true

echo "[3/5] Deleting sample app (php-apache)"
kubectl -n "$NS" delete -f examples/simple-linear/deployment.yaml --ignore-not-found

if [[ "$DEEP" -eq 1 ]]; then
  echo "[4/5] Deleting operator"
  # Try both local manifest and helm uninstall
  kubectl delete -f deploy/local-operator.yaml --ignore-not-found || true
  if command -v helm >/dev/null 2>&1; then
    helm uninstall predictive-horizontal-pod-autoscaler-operator || true
  fi

  echo "[5/5] Deleting CRD"
  kubectl delete -f helm/templates/crd/syswe.me_predictivehorizontalpodautoscalers.yaml --ignore-not-found || true
fi

if [[ "$RM_METRICS" -eq 1 ]]; then
  echo "[extra] Removing metrics-server"
  kubectl -n kube-system delete deploy metrics-server --ignore-not-found || true
  kubectl delete apiservice v1beta1.metrics.k8s.io --ignore-not-found || true
fi

echo "Cleanup complete. Current pods:"
kubectl get pods -A

# Hint if operator is still running and deep cleanup wasn't requested
if kubectl -n "$NS" get deploy predictive-horizontal-pod-autoscaler >/dev/null 2>&1; then
  if [[ "$DEEP" -eq 0 ]]; then
    echo
    echo "Note: Operator is still running (deployment/predictive-horizontal-pod-autoscaler)."
    echo "Run with --deep to also remove the operator and CRD:"
    echo "  bash scripts/phpa-stop.sh --deep"
  fi
fi
