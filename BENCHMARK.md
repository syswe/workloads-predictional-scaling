# PHPA Model Benchmarking (GBDT, XGBoost, VAR, CatBoost)

This guide describes how to benchmark the runtime models (excluding Holt‑Winters and Linear) across 10 distinct scenarios, using both offline training scripts and an online PHPA setup. It produces comparable metrics (RMSE/MAE/MAPE) and shows how to aggregate and compare results.

## Models Covered
- GBDT (scikit‑learn)
- XGBoost
- VAR (statsmodels)
- CatBoost

## Prerequisites
- Python 3.8 with pip
- kubectl (optional, for online checks)
- jq (for JSON formatting)
- From the repo root, install dev deps:
  - `python -m pip install -r requirements-dev.txt`

## Scenarios (10)
We generate synthetic series to represent common scaling situations.

1. steady: flat baseline (low variance)
2. spike: isolated sudden spike
3. ramp_up: gradual increase
4. daily_seasonality: smooth sinusoidal seasonality
5. weekday_weekend: weekly pattern (weekend boost)
6. noisy: white noise around baseline
7. stepwise: discrete upward steps
8. multi_spike: several spikes at random times
9. zero_dip: short temporary drop to zero
10. bursty_poisson: bursty arrivals (Poisson) with injected bursts

## Generate Datasets
Use the provided generator to build train/test CSVs for each scenario.

- Generate a single scenario (20s interval, 720 points total, 70/30 split):
  - `python tools/generate_scenarios.py --scenario spike --points 720 --step 20 --split 0.7 --outdir benchmark/data`
- Generate all scenarios:
  - `for s in steady spike ramp_up daily_seasonality weekday_weekend noisy stepwise multi_spike zero_dip bursty_poisson; do \
      python tools/generate_scenarios.py --scenario "$s" --points 720 --step 20 --split 0.7 --outdir benchmark/data; \
    done`

Data is written under `benchmark/data/<scenario>/train.csv` and `test.csv` with columns `timestamp,pod_count`.

## Offline Benchmark (Batch)
Run all four models on the generated train/test data for each scenario and compare metrics. This does not require Kubernetes.

- One scenario:
  - `bash scripts/offline-benchmark.sh --train benchmark/data/spike/train.csv --test benchmark/data/spike/test.csv --prefix spike`
- All scenarios:
  - `for s in steady spike ramp_up daily_seasonality weekday_weekend noisy stepwise multi_spike zero_dip bursty_poisson; do \
      bash scripts/offline-benchmark.sh --train benchmark/data/$s/train.csv --test benchmark/data/$s/test.csv --prefix $s; \
    done`

Artifacts:
- GBDT: `train/models/gbdt_model/runs/<run-id>/metrics.json`
- XGBoost: `train/models/xgboost_model/runs/<run-id>/metrics.json`
- VAR: `train/models/var_model/runs/<run-id>/metrics.json`
- CatBoost: `train/models/catboost_model/runs/<run-id>/metrics.json`

Summary:
- The script prints a CSV table via `tools/compare_models.py`:
  - `model,run,rmse,mae,mape`
- Aggregate all runs into a single CSV (example):
  - `bash -c 'for d in train/models/*_model/runs/*; do m=$(echo $d | sed -E "s#train/models/(.*)_model/runs/.*#\1#"); run=$(basename $d); jq -r ". | \"$m,$run,\" + (.rmse|tostring) + \",\" + (.mae|tostring) + \",\" + (.mape|tostring)" $d/metrics.json; done' > benchmark/summary.csv'`

## Online Checks (Optional)
You can validate models live under PHPA with generated load.

1) Start stack with a model (e.g., GBDT):
- `bash scripts/phpa-start.sh -m gbdt --start-load`

2) Inspect PHPA:
- `kubectl describe phpa simple-gbdt`
- `kubectl get configmap predictive-horizontal-pod-autoscaler-simple-gbdt-data -o=json | jq -r '.data.data | fromjson | .modelHistories'`

3) Switch model:
- `bash scripts/phpa-stop.sh` (or `--deep`)
- `bash scripts/phpa-start.sh -m catboost --start-load`

4) Multi-model mean (GBDT + XGBoost + VAR + CatBoost):
- `bash scripts/phpa-start.sh -m multi --start-load`
- Review ConfigMap histories per model.

## Tips & Notes
- Keep lookAhead and lags consistent across models for apples-to-apples comparisons (e.g., `lookAhead=10000ms`, `lags=6`).
- VAR is multivariate; we derive simple time features internally, but it may perform best with clear periodic signals.
- Training time is not included in runtime PHPA loop for these models; the runtime impls retrain small models on recent lags for fast inference.
- For heavy benchmarks, pin CPU/GPU resources and record training/inference time separately.

## Reproducibility
- The generator uses a fixed seed (`np.random.seed(42)`).
- Timestamps are generated relative to current time; models use values rather than absolute times, so results are stable.

## Extending
- Add new scenarios to `tools/generate_scenarios.py` and re-run the loop.
- Add new models using `docs/user-guide/custom-models.md` and wire them into comparison scripts.

