# Model Comparison

Compare models in two complementary ways: offline (experiment on historical data) and online (run multiple models in the PHPA and choose a decision strategy).

## Offline Experiments

Use the training scripts to evaluate models on the same dataset and compare their metrics.

- GBDT (scikit‑learn): `algorithms/gbdt/train_gbdt.py`
- XGBoost: `algorithms/xgboost/train_xgboost.py`
- VAR (statsmodels): `algorithms/var/train_var.py`

Run each model on identical train/test CSVs with a unique `--run-id`.

Artifacts are written under `train/models/<model_name>/runs/<run-id>/` with:

- `metrics.json` (contains RMSE, MAE, MAPE, and timing),
- `predictions.csv` (actual vs predicted),
- plots for quick visual inspection.

Example (summarize RMSE/MAE/ MAPE across runs with jq):

```bash
# GBDT
jq -r '. | {model:"gbdt", rmse, mae, mape}' train/models/gbdt_model/runs/<run-id>/metrics.json
# XGBoost
jq -r '. | {model:"xgboost", rmse, mae, mape}' train/models/xgboost_model/runs/<run-id>/metrics.json
# VAR
jq -r '. | {model:"var", rmse, mae, mape}' train/models/var_model/runs/<run-id>/metrics.json
```

You can script aggregation/ranking across multiple runs to find best hyperparameters per model.

Helper script:

```bash
python tools/compare_models.py --root . --fields rmse mae mape
```

This prints a CSV of model, run ID, and requested fields for quick comparison.

## Online Comparison in PHPA

PHPA can run multiple models concurrently on the same target and combine them with `decisionType`:

- `maximum`: choose the most conservative (highest) prediction
- `minimum`: choose the lowest prediction
- `mean`: average all predictions (rounded)
- `median`: median of all predictions

Example (Linear + Holt‑Winters + GBDT):

```yaml
spec:
  decisionType: mean
  models:
    - type: Linear
      name: linear-10s
      linear:
        lookAhead: 10000
        historySize: 6
    - type: HoltWinters
      name: hw-6sp
      holtWinters:
        alpha: 0.9
        beta: 0.9
        gamma: 0.9
        seasonalPeriods: 6
        storedSeasons: 4
        trend: additive
        seasonal: additive
    - type: GBDT
      name: gbdt-6lags
      gbdt:
        lookAhead: 10000
        historySize: 30
        lags: 6
```

Inspect the per‑model histories in the PHPA data ConfigMap to review each model’s series over time:

```bash
kubectl get configmap predictive-horizontal-pod-autoscaler-<phpa-name>-data -o=json \
  | jq -r '.data.data | fromjson | .modelHistories'
```

Tip: Use `perSyncPeriod` to run heavy models less frequently (e.g., every 2–3 syncs) alongside lightweight ones.
