import sys
import json
import math
from datetime import datetime

import numpy as np
from catboost import CatBoostRegressor


def read_stdin():
    raw = sys.stdin.read()
    if not raw:
        print("No standard input provided to CatBoost algorithm, exiting", file=sys.stderr)
        sys.exit(1)
    try:
        return json.loads(raw)
    except json.JSONDecodeError as ex:
        print(f"Invalid JSON provided: {str(ex)}", file=sys.stderr)
        sys.exit(1)


def parse_history(replica_history):
    parsed = []
    for item in replica_history:
        try:
            t = datetime.strptime(item["time"], "%Y-%m-%dT%H:%M:%SZ")
            r = int(item["replicas"])
        except Exception as ex:
            print(f"Invalid replica history item: {ex}", file=sys.stderr)
            sys.exit(1)
        parsed.append((t, r))
    parsed.sort(key=lambda x: x[0])
    times = [t for t, _ in parsed]
    values = [r for _, r in parsed]
    return times, values


def build_lag_matrix(values, lags):
    X = []
    y = []
    for i in range(lags, len(values)):
        X.append(values[i - lags:i][::-1])
        y.append(values[i])
    return np.asarray(X, dtype=float), np.asarray(y, dtype=float)


def median_step_ms(times):
    if len(times) < 2:
        return None
    deltas = [(times[i] - times[i - 1]).total_seconds() * 1000.0 for i in range(1, len(times))]
    if not deltas:
        return None
    return float(np.median(deltas))


def cb_predict_next(values, lags):
    X, y = build_lag_matrix(values, lags)
    if len(y) == 0:
        return values[-1]
    model = CatBoostRegressor(
        iterations=200,
        learning_rate=0.1,
        depth=4,
        loss_function='RMSE',
        verbose=False,
        random_seed=42,
    )
    model.fit(X, y)
    x_next = np.asarray(values[-lags:][::-1], dtype=float).reshape(1, -1)
    return float(model.predict(x_next)[0])


def main():
    payload = read_stdin()
    replica_history = payload.get("replicaHistory")
    look_ahead_ms = int(payload.get("lookAhead", 0))
    lags = int(payload.get("lags", 6))

    if not isinstance(replica_history, list) or len(replica_history) == 0:
        print("No evaluations provided to CatBoost algorithm", file=sys.stderr)
        sys.exit(1)

    times, values = parse_history(replica_history)
    if len(values) <= lags:
        sys.stdout.write(str(int(values[-1])))
        return

    step_ms = median_step_ms(times)
    steps_ahead = 1
    if step_ms and step_ms > 0:
        steps_ahead = max(1, int(math.ceil(look_ahead_ms / step_ms)))

    forecast_values = list(values)
    for _ in range(steps_ahead):
        pred = cb_predict_next(forecast_values, lags)
        pred = max(1, int(math.ceil(pred)))
        forecast_values.append(pred)

    sys.stdout.write(str(int(forecast_values[-1])))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)

