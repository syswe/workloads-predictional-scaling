#!/usr/bin/env bash
set -euo pipefail

# Run offline training scripts for GBDT, XGBoost, VAR on a common dataset
# and summarize metrics.

usage() {
  cat <<EOF
Usage: bash scripts/offline-benchmark.sh --train <train.csv> --test <test.csv> [--prefix <id>]

Outputs metrics JSON and a CSV summary to stdout.
EOF
}

TRAIN=""
TEST=""
PREFIX="run_$(date +%Y%m%d_%H%M%S)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --train) TRAIN="$2"; shift 2;;
    --test)  TEST="$2"; shift 2;;
    --prefix) PREFIX="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

[[ -f "$TRAIN" ]] || { echo "train csv not found: $TRAIN" >&2; exit 1; }
[[ -f "$TEST"  ]] || { echo "test csv not found: $TEST" >&2; exit 1; }

echo "[1/4] GBDT"
python algorithms/gbdt/train_gbdt.py --train-file "$TRAIN" --test-file "$TEST" --run-id "${PREFIX}_gbdt" || true

echo "[2/4] XGBoost"
python algorithms/xgboost/train_xgboost.py --train-file "$TRAIN" --test-file "$TEST" --run-id "${PREFIX}_xgb" || true

echo "[3/4] CatBoost"
python algorithms/catboost/train_catboost.py --train-file "$TRAIN" --test-file "$TEST" --run-id "${PREFIX}_cb" || true

echo "[4/4] VAR"
python algorithms/var/train_var.py --train-file "$TRAIN" --test-file "$TEST" --run-id "${PREFIX}_var" || true

echo "[Summary (CSV)]"
python tools/compare_models.py --root . --fields rmse mae mape
