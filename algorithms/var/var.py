import sys
import json
import math
from datetime import datetime

import numpy as np
import pandas as pd
from statsmodels.tsa.vector_ar.var_model import VAR


def read_stdin():
    raw = sys.stdin.read()
    if not raw:
        print("No standard input provided to VAR algorithm, exiting", file=sys.stderr)
        sys.exit(1)
    try:
        return json.loads(raw)
    except json.JSONDecodeError as ex:
        print(f"Invalid JSON provided: {str(ex)}", file=sys.stderr)
        sys.exit(1)


def parse_history(replica_history):
    rows = []
    for item in replica_history:
        try:
            t = datetime.strptime(item["time"], "%Y-%m-%dT%H:%M:%SZ")
            r = int(item["replicas"])
        except Exception as ex:
            print(f"Invalid replica history item: {ex}", file=sys.stderr)
            sys.exit(1)
        rows.append((t, r))
    rows.sort(key=lambda x: x[0])
    return rows


def median_step_ms(times):
    if len(times) < 2:
        return None
    deltas = [(times[i] - times[i - 1]).total_seconds() * 1000.0 for i in range(1, len(times))]
    if not deltas:
        return None
    return float(np.median(deltas))


def build_var_dataframe(rows):
    # Build DataFrame with replicas + time-derived exogenous like features (hour, dow)
    df = pd.DataFrame(rows, columns=["timestamp", "replicas"])
    df["hour"] = df["timestamp"].dt.hour
    df["day_of_week"] = df["timestamp"].dt.dayofweek
    return df[["replicas", "hour", "day_of_week"]]


def var_predict_next(df, maxlags):
    # Fit a small VAR; if not enough points for requested lags, let statsmodels choose
    try:
        model = VAR(df)
        maxlags = max(1, min(maxlags, len(df) // 5))
        fitted = model.fit(maxlags=maxlags)
        lag_order = fitted.k_ar
        forecast_input = df.values[-lag_order:]
        forecast = fitted.forecast(y=forecast_input, steps=1)
        return float(forecast[0][0])  # first column is replicas
    except Exception as ex:
        # Fallback to last observed
        return float(df["replicas"].iloc[-1])


def main():
    payload = read_stdin()
    replica_history = payload.get("replicaHistory")
    look_ahead_ms = int(payload.get("lookAhead", 0))
    lags = int(payload.get("lags", 6))

    if not isinstance(replica_history, list) or len(replica_history) == 0:
        print("No evaluations provided to VAR algorithm", file=sys.stderr)
        sys.exit(1)

    rows = parse_history(replica_history)
    times = [t for t, _ in rows]
    df = build_var_dataframe(rows)

    if len(df) <= lags:
        sys.stdout.write(str(int(df["replicas"].iloc[-1])))
        return

    step_ms = median_step_ms(times)
    steps_ahead = 1
    if step_ms and step_ms > 0:
        steps_ahead = max(1, int(math.ceil(look_ahead_ms / step_ms)))

    forecast_df = df.copy()
    for _ in range(steps_ahead):
        pred = var_predict_next(forecast_df, lags)
        pred = max(1, int(math.ceil(pred)))
        # Append as next step with derived time features simply repeating last hour/dow (approximation)
        last_ts = times[-1]
        times.append(last_ts)  # keep times length consistent; value not used for next features except hour/dow
        next_row = pd.DataFrame({
            "replicas": [pred],
            "hour": [forecast_df["hour"].iloc[-1]],
            "day_of_week": [forecast_df["day_of_week"].iloc[-1]],
        })
        forecast_df = pd.concat([forecast_df, next_row], ignore_index=True)

    sys.stdout.write(str(int(forecast_df["replicas"].iloc[-1])))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(str(e), file=sys.stderr)
        sys.exit(1)

