#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
LAB_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(cd "${LAB_ROOT}/.." && pwd)

PYTHON_BIN=${PYTHON:-python3}
DATA_DIR="${LAB_ROOT}/data/generated"
OUTPUT_DIR="${LAB_ROOT}/output/offline"
RUN_ID_PREFIX=${RUN_ID_PREFIX:-lab_offline}

mkdir -p "${DATA_DIR}" "${OUTPUT_DIR}"

# 1. Sentetik veri üret
printf '[offline] Sentetik veri oluşturuluyor...\n'
"${PYTHON_BIN}" "${LAB_ROOT}/data/generate_synthetic.py" \
  --output-dir "${DATA_DIR}" \
  --train-hours 48 \
  --test-hours 12

TRAIN_FILE="${DATA_DIR}/train.csv"
TEST_FILE="${DATA_DIR}/test.csv"

# 2. Eğitim scriptlerini sıra ile çalıştır
run_model() {
  local name="$1"
  local module_path="$2"
  local extra_args="$3"
  local run_id="${RUN_ID_PREFIX}_${name}_$(date +%Y%m%d_%H%M%S)"
  printf '[offline] %s modeli eğitiliyor (run=%s)\n' "$name" "$run_id"
  (cd "${REPO_ROOT}" && "${PYTHON_BIN}" "$module_path" \
    --train-file "$TRAIN_FILE" \
    --test-file "$TEST_FILE" \
    --run-id "$run_id" $extra_args) \
    >> "${OUTPUT_DIR}/${name}.log" 2>&1 || true
}

run_model "gbdt" "algorithms/gbdt/train_gbdt.py" ""
run_model "xgboost" "algorithms/xgboost/train_xgboost.py" ""
run_model "catboost" "algorithms/catboost/train_catboost.py" ""
run_model "var" "algorithms/var/train_var.py" "--maxlags 24"

# 3. Özet CSV üret
printf '[offline] Metrik özeti oluşturuluyor...\n'
(cd "${REPO_ROOT}" && "${PYTHON_BIN}" tools/compare_models.py --root . --fields rmse mae mape \
  > "${OUTPUT_DIR}/metrics_summary.csv")

printf '[offline] Offline çalışma tamamlandı. Çıktılar: %s\n' "${OUTPUT_DIR}"
