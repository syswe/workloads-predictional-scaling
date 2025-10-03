#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LAB_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(cd "${LAB_ROOT}/.." && pwd)

NAMESPACE=${NAMESPACE:-phpa-lab}
RUN_DURATION=${RUN_DURATION:-240}
SAMPLING_INTERVAL=${SAMPLING_INTERVAL:-5}
PYTHON_BIN=${PYTHON:-python3}
RAW_DIR="${LAB_ROOT}/output/online/raw"
SUMMARY_CSV="${LAB_ROOT}/output/online/summary.csv"
LOG_DIR="${LAB_ROOT}/output/logs"

mkdir -p "${RAW_DIR}" "${LOG_DIR}"

ensure_base() {
  kubectl apply -n "${NAMESPACE}" -f "${LAB_ROOT}/manifests/sample-app.yaml" >/dev/null
  kubectl apply -n "${NAMESPACE}" -f "${LAB_ROOT}/manifests/load-generator.yaml" >/dev/null
  kubectl -n "${NAMESPACE}" rollout status deploy/php-apache --timeout=180s >/dev/null
  kubectl -n "${NAMESPACE}" scale deploy/load-generator --replicas=0 >/dev/null 2>&1 || true
}

reset_environment() {
  kubectl -n "${NAMESPACE}" delete predictivehorizontalpodautoscalers --all --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n "${NAMESPACE}" delete hpa php-apache-baseline --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n "${NAMESPACE}" scale deploy/load-generator --replicas=0 >/dev/null 2>&1 || true
  kubectl -n "${NAMESPACE}" scale deploy/php-apache --replicas=1 >/dev/null 2>&1 || true
}

collect() {
  local type="$1"
  local name="$2"
  local outfile="$3"
  printf '[online] %s ölçümü %s saniye sürecek...\n' "$name" "${RUN_DURATION}"
  "${PYTHON_BIN}" "${SCRIPT_DIR}/collect_metrics.py" \
    --namespace "${NAMESPACE}" \
    --resource-type "$type" \
    --resource-name "$name" \
    --duration "${RUN_DURATION}" \
    --interval "${SAMPLING_INTERVAL}" \
    --output "$outfile" \
    >> "${LOG_DIR}/${name}.log" 2>&1
}

run_baseline() {
  printf '[online] Standart HPA senaryosu başlatılıyor...\n'
  kubectl -n "${NAMESPACE}" apply -f "${LAB_ROOT}/manifests/hpa-baseline.yaml" >/dev/null
  sleep 10
  kubectl -n "${NAMESPACE}" scale deploy/load-generator --replicas=1 >/dev/null
  sleep 10
  collect "hpa" "php-apache-baseline" "${RAW_DIR}/baseline_hpa.csv"
  kubectl -n "${NAMESPACE}" scale deploy/load-generator --replicas=0 >/dev/null
  kubectl -n "${NAMESPACE}" delete hpa php-apache-baseline --ignore-not-found >/dev/null
  kubectl -n "${NAMESPACE}" scale deploy/php-apache --replicas=1 >/dev/null
  sleep 30
}

run_model() {
  local model="$1"
  local manifest="${LAB_ROOT}/manifests/phpa-${model}.yaml"
  local resource="phpa-${model}"
  printf '[online] PHPA modeli: %s\n' "$model"
  kubectl -n "${NAMESPACE}" apply -f "$manifest" >/dev/null
  sleep 10
  kubectl -n "${NAMESPACE}" scale deploy/load-generator --replicas=1 >/dev/null
  sleep 10
  collect "phpa" "$resource" "${RAW_DIR}/phpa_${model}.csv"
  kubectl -n "${NAMESPACE}" scale deploy/load-generator --replicas=0 >/dev/null
  kubectl -n "${NAMESPACE}" delete predictivehorizontalpodautoscaler "$resource" --ignore-not-found >/dev/null
  kubectl -n "${NAMESPACE}" scale deploy/php-apache --replicas=1 >/dev/null
  sleep 30
}

ensure_base
reset_environment

run_baseline

for model in linear holtwinters gbdt catboost var xgboost; do
  run_model "$model"
done

printf '[online] Özet oluşturuluyor...\n'
"${PYTHON_BIN}" "${SCRIPT_DIR}/analyze_online.py" \
  --input-dir "${RAW_DIR}" \
  --output-csv "$SUMMARY_CSV"

printf '[online] Deney tamamlandı. Özet: %s\n' "$SUMMARY_CSV"
