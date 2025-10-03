import sys
import json
import math
from datetime import datetime

import numpy as np
from sklearn.ensemble import GradientBoostingRegressor


def read_stdin():
    data = sys.stdin.read()
    if data is None or data == "":
        print("No standard input provided to GBDT algorithm, exiting", file=sys.stderr)
        sys.exit(1)
    try:
        return json.loads(data)
    except json.JSONDecodeError as ex:
        print(f"Invalid JSON provided: {str(ex)}, exiting", file=sys.stderr)
        sys.exit(1)


def parse_history(replica_history):
    # Expecting list of {"time": "...Z", "replicas": int}
    parsed = []
    for item in replica_history:
        try:
            t = datetime.strptime(item["time"], "%Y-%m-%dT%H:%M:%SZ")
            r = int(item["replicas"])
        except Exception as ex:
            print(f"Invalid replica history item: {ex}", file=sys.stderr)
            sys.exit(1)
        parsed.append((t, r))
    # Sort ascending by time
    parsed.sort(key=lambda x: x[0])
    times = [t for t, _ in parsed]
    values = [r for _, r in parsed]
    return times, values


def build_lag_matrix(values, lags):
    X = []
    y = []
    for i in range(lags, len(values)):
        X.append(values[i - lags:i][::-1])  # most recent first
        y.append(values[i])
    return np.asarray(X), np.asarray(y)


def median_step_ms(times):
    if len(times) < 2:
        return None
    deltas = []
    for i in range(1, len(times)):
        deltas.append((times[i] - times[i - 1]).total_seconds() * 1000.0)
    if not deltas:
        return None
    return float(np.median(deltas))


def gbdt_predict_next(values, lags):
    X, y = build_lag_matrix(values, lags)
    if len(y) == 0:
        return values[-1]
    model = GradientBoostingRegressor(
        n_estimators=150,
        learning_rate=0.1,
        max_depth=3,
        subsample=1.0,
        random_state=42,
    )
    model.fit(X, y)
    x_next = np.asarray(values[-lags:][::-1]).reshape(1, -1)
    return float(model.predict(x_next)[0])


def main():
    payload = read_stdin()

    replica_history = payload.get("replicaHistory")
    look_ahead_ms = int(payload.get("lookAhead", 0))
    lags = int(payload.get("lags", 3))

    if not isinstance(replica_history, list) or len(replica_history) == 0:
        print("No evaluations provided to GBDT algorithm", file=sys.stderr)
        sys.exit(1)

    times, values = parse_history(replica_history)

    # If not enough points for lags, return latest observed replicas
    if len(values) <= lags:
        sys.stdout.write(str(int(values[-1])))
        return

    step_ms = median_step_ms(times)
    steps_ahead = 1
    if step_ms and step_ms > 0:
        steps_ahead = max(1, int(math.ceil(look_ahead_ms / step_ms)))

    # Iterative multi-step forecasting
    forecast_values = list(values)
    for _ in range(steps_ahead):
        pred = gbdt_predict_next(forecast_values, lags)
        # enforce at least 1 replica and round up for safety
        pred = max(1, int(math.ceil(pred)))
        forecast_values.append(pred)

    sys.stdout.write(str(int(forecast_values[-1])))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)

