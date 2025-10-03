# Custom Models

You can add new predictive models to the operator. This guide outlines the pattern used by Linear, Holt‑Winters, and GBDT, and how to extend it for other models (e.g., XGBoost, VAR).

## Overview

PHPA invokes Python algorithms by piping JSON to stdin and expecting a single integer (predicted replicas) on stdout. The Go controller:

- Marshals model context + history into JSON,
- Runs the Python script with a timeout,
- Parses the integer result,
- Prunes stored history per model’s rules.

## Steps

1. CRD/API

- Add a new type constant and config struct in `api/v1alpha1/predictivehorizontalpodautoscaler_types.go`.
- Include the type in the `Model` enum and add a pointer field for your config (e.g., `XGBoost *XGBoost`).
- Run `make generate` to update deepcopy and CRDs under `helm/templates/crd`.

2. Go Predicter

- Create `internal/prediction/<model>/<model>.go` that implements:
  - `GetType() string` returning your type name.
  - `GetPrediction(model *v1alpha1.Model, history []TimestampedReplicas) (int32, error)` which:
    - Validates config/history,
    - Marshals a small JSON payload (typically `{ replicaHistory, lookAhead, ... }`),
    - Calls the Python runner `RunAlgorithmWithValue(algorithmPath, json, timeout)`,
    - Parses `strconv.Atoi` from stdout.
  - `PruneHistory(...)` to bound stored points (e.g., by `HistorySize`).

See `internal/prediction/gbdt/gbdt.go` for a concise example.

3. Python Runtime

- Add `algorithms/<model>/<model>.py` that:
  - Reads JSON from stdin.
  - Validates and extracts `replicaHistory` (list of `{time, replicas}`), and any params (e.g., `lags`, `lookAhead`).
  - Builds features from history (keep it light and deterministic; avoid heavy plotting, file IO, or long training).
  - Produces an integer prediction to stdout (no extra prints).
  - Exits non‑zero and prints errors to stderr on failure.

Contract example (input):

```json
{
  "replicaHistory": [{"time": "2025-01-01T00:00:00Z", "replicas": 3}],
  "lookAhead": 10000,
  "lags": 6
}
``;
Output: `7`
```

4. Dependencies

- If your runtime needs additional packages, add them in `algorithms/requirements.txt` so the Dockerfile installs them into the operator image.
  - Keep runtime dependencies minimal; avoid large training‑only stacks.

5. Wire into Operator

- Import your predicter and append it to the `Predicters` slice in `main.go`.
- Build and deploy the operator image. If using Helm, set `.Values.image.repository` and `.Values.image.tag`.

6. Example PHPA

- Add an example under `examples/<model>/phpa.yaml` showing `type: <YourType>` and your config block.

## Notes

- Timeouts: Use `calculationTimeout` to guard long‑running algorithms.
- Scheduling: Use `perSyncPeriod` to run costly models less often.
- Multi‑model: Combine with others and set `decisionType` to control how predictions are aggregated.

## Mapping Training → Runtime

Offline scripts (e.g., `train_xgboost.py`, `train_var.py`) are for experimentation. To use these approaches online:

- Extract the core inference idea into a small, fast Python runtime that consumes `replicaHistory`.
- For tree models (XGBoost/GBDT), consider using recent lags as features and iterative multi‑step prediction for `lookAhead`.
- For VAR, use a compact lag order and multivariate features derived from timestamps if desired, while keeping compute bounded.
