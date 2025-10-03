#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LAB_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(cd "${LAB_ROOT}/.." && pwd)

NAMESPACE=${NAMESPACE:-phpa-lab}
OPERATOR_NAMESPACE=${OPERATOR_NAMESPACE:-phpa-system}
METRICS_TIMEOUT=${METRICS_TIMEOUT:-180}
IMAGE_REPOSITORY=${IMAGE_REPOSITORY:-syswe/predictive-horizontal-pod-autoscaler}
IMAGE_TAG=${IMAGE_TAG:-latest}

for bin in kubectl helm docker make; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "[bootstrap] Hata: '$bin' komutu bulunamadı." >&2
    exit 1
  fi
done

# Metrics server kurulumu
if kubectl -n kube-system get deploy metrics-server >/dev/null 2>&1; then
  printf '[bootstrap] metrics-server zaten mevcut, kurulumu atlanıyor.\n'
else
  printf '[bootstrap] metrics-server uygulanıyor...\n'
  kubectl apply -f "${LAB_ROOT}/manifests/metrics-server.yaml" >/dev/null
  kubectl -n kube-system rollout status deploy/metrics-server --timeout="${METRICS_TIMEOUT}s" || true
fi

# Namespace'leri hazırla
if ! kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
  kubectl create namespace "${NAMESPACE}" >/dev/null
fi
if ! kubectl get namespace "${OPERATOR_NAMESPACE}" >/dev/null 2>&1; then
  kubectl create namespace "${OPERATOR_NAMESPACE}" >/dev/null
fi

# Operatör image'ini yerelde üret
printf '[bootstrap] Operatör imajı derleniyor (%s:%s)\n' "${IMAGE_REPOSITORY}" "${IMAGE_TAG}"
REGISTRY="${IMAGE_REPOSITORY%%/*}"
NAME="${IMAGE_REPOSITORY##*/}"
make -C "${REPO_ROOT}" docker REGISTRY="${REGISTRY}" NAME="${NAME}" VERSION="${IMAGE_TAG}"

# Operatörü Helm chart ile kur
printf '[bootstrap] Operatör Helm chartı kuruluyor...\n'
helm upgrade --install predictive-horizontal-pod-autoscaler-operator "${REPO_ROOT}/helm" \
  --namespace "${OPERATOR_NAMESPACE}" --create-namespace \
  --set mode=cluster \
  --set image.repository="${IMAGE_REPOSITORY}" \
  --set image.tag="${IMAGE_TAG}" \
  --wait

# Test uygulaması ve yük üreticisi
printf '[bootstrap] Örnek uygulama ve yük üreticisi uygulanıyor...\n'
kubectl apply -n "${NAMESPACE}" -f "${LAB_ROOT}/manifests/sample-app.yaml"
kubectl apply -n "${NAMESPACE}" -f "${LAB_ROOT}/manifests/load-generator.yaml"

printf '[bootstrap] Bootstrap tamamlandı. Namespace=%s, Operator namespace=%s\n' "${NAMESPACE}" "${OPERATOR_NAMESPACE}"
