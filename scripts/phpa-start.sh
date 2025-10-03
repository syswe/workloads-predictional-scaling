#!/usr/bin/env bash
set -euo pipefail

# PHPA quick-start script
# - Installs/patches Metrics Server (unless --skip-metrics)
# - Applies CRD
# - Deploys the operator (local manifest by default; Helm optional)
# - Deploys sample app (php-apache)
# - Applies a PHPA for the chosen model (gbdt|xgboost|var|multi)
# - Optionally starts a load generator

NS="default"
MODEL="gbdt"         # gbdt|xgboost|var|catboost|multi
USE_HELM=0           # 1 to use Helm chart deploy
START_LOAD=0
SKIP_METRICS=0
IMAGE_TAG=""         # If set with Helm path

usage() {
  cat <<EOF
Usage: bash scripts/phpa-start.sh [options]
  -n, --namespace <ns>     Kubernetes namespace (default: default)
  -m, --model <name>       Model to apply: gbdt|xgboost|var|multi (default: gbdt)
      --helm               Use Helm to deploy the operator (default: local manifest)
      --image-tag <tag>    Helm image tag override (requires --helm)
      --skip-metrics       Do not install/patch metrics-server
      --start-load         Start load generator pod
  -h, --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--namespace) NS="$2"; shift 2;;
    -m|--model) MODEL="$2"; shift 2;;
    --helm) USE_HELM=1; shift;;
    --image-tag) IMAGE_TAG="$2"; shift 2;;
    --skip-metrics) SKIP_METRICS=1; shift;;
    --start-load) START_LOAD=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found" >&2; exit 1; }

echo "[1/6] Applying PHPA CRD"
kubectl apply -f helm/templates/crd/syswe.me_predictivehorizontalpodautoscalers.yaml

if [[ "$SKIP_METRICS" -eq 0 ]]; then
  echo "[2/6] Ensuring metrics-server is installed and patched for Docker Desktop"
  if ! kubectl -n kube-system get deploy metrics-server >/dev/null 2>&1; then
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  fi
  # Patch for Docker Desktop (insecure TLS to kubelet)
  kubectl -n kube-system patch deploy/metrics-server -p '{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--cert-dir=/tmp","--secure-port=10250","--kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP","--kubelet-insecure-tls"]}]}}}}' || true
  # Wait until metrics available
  echo "Waiting for metrics-server rollout..."
  kubectl -n kube-system rollout status deploy/metrics-server --timeout=120s || true
fi

echo "[3/6] Deploying PHPA operator"
if [[ "$USE_HELM" -eq 1 ]]; then
  command -v helm >/dev/null 2>&1 || { echo "helm not found (or omit --helm)" >&2; exit 1; }
  if [[ -n "$IMAGE_TAG" ]]; then
    helm upgrade --install predictive-horizontal-pod-autoscaler-operator helm/ \
      --set mode=cluster \
      --set image.tag="$IMAGE_TAG"
  else
    helm upgrade --install predictive-horizontal-pod-autoscaler-operator helm/ \
      --set mode=cluster
  fi
else
  kubectl apply -f deploy/local-operator.yaml
fi
kubectl rollout status deploy/predictive-horizontal-pod-autoscaler -n "$NS" --timeout=120s

echo "[4/6] Deploying sample app (php-apache)"
kubectl apply -n "$NS" -f examples/simple-linear/deployment.yaml
kubectl -n "$NS" set image deployment/php-apache php-apache=registry.k8s.io/hpa-example || true
kubectl -n "$NS" rollout status deploy/php-apache --timeout=120s || true

echo "[5/6] Applying PHPA for model: $MODEL"
case "$MODEL" in
  gbdt)    kubectl apply -n "$NS" -f examples/simple-gbdt/phpa.yaml;;
  xgboost) kubectl apply -n "$NS" -f examples/simple-xgboost/phpa.yaml;;
  var)     kubectl apply -n "$NS" -f examples/simple-var/phpa.yaml;;
  catboost) kubectl apply -n "$NS" -f examples/simple-catboost/phpa.yaml;;
  multi)
    # Combined demo: mean of GBDT + XGBoost + VAR
    kubectl apply -n "$NS" -f examples/multi-model/phpa.yaml
    ;;
  *) echo "Unknown model: $MODEL"; exit 1;;
esac

echo "[6/6] Optional: starting load generator: $START_LOAD"
if [[ "$START_LOAD" -eq 1 ]]; then
  kubectl -n "$NS" run load-generator --image=busybox --restart=Never -- \
    /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done" || true
fi

echo "Done. Useful commands:"
echo "  kubectl -n $NS describe phpa <name>"
echo "  kubectl -n $NS logs -l name=predictive-horizontal-pod-autoscaler -f"
echo "  kubectl -n $NS get configmap predictive-horizontal-pod-autoscaler-<name>-data -o=json | jq -r '.data.data'"
