#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LAB_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

NAMESPACE=${NAMESPACE:-phpa-lab}
OPERATOR_NAMESPACE=${OPERATOR_NAMESPACE:-phpa-system}

printf '[destroy] Laboratuvar kaynakları temizleniyor...\n'

# PHPA ve HPA tanımlarını kaldır
kubectl -n "${NAMESPACE}" delete predictivehorizontalpodautoscalers --all --ignore-not-found || true
kubectl -n "${NAMESPACE}" delete hpa php-apache-baseline --ignore-not-found || true

# Örnek uygulama ve yük üreticisi
kubectl -n "${NAMESPACE}" delete -f "${LAB_ROOT}/manifests/load-generator.yaml" --ignore-not-found || true
kubectl -n "${NAMESPACE}" delete -f "${LAB_ROOT}/manifests/sample-app.yaml" --ignore-not-found || true

# Namespace'i sil (içinde başka kaynak yoksa)
kubectl delete namespace "${NAMESPACE}" --ignore-not-found || true

# Operatör helm release'i kaldır
helm uninstall predictive-horizontal-pod-autoscaler-operator --namespace "${OPERATOR_NAMESPACE}" >/dev/null 2>&1 || true
kubectl delete namespace "${OPERATOR_NAMESPACE}" --ignore-not-found || true

# metrics-server manifesti kaldır
kubectl delete -f "${LAB_ROOT}/manifests/metrics-server.yaml" --ignore-not-found || true

printf '[destroy] Temizlik tamamlandı.\n'
