#!/usr/bin/env python3
import argparse
from datetime import datetime, timedelta
import numpy as np
import pandas as pd
from pathlib import Path


def gen_time_index(n, step_s):
    start = datetime.utcnow() - timedelta(seconds=n*step_s)
    return [start + timedelta(seconds=i*step_s) for i in range(n)]


def steady(n, base):
    return np.full(n, base)


def spike(n, base, amp, at):
    y = np.full(n, base)
    if 0 <= at < n:
        y[at] = base + amp
    return y


def ramp_up(n, start, end):
    return np.linspace(start, end, n)


def daily_seasonality(n, base, amp):
    x = np.arange(n)
    return base + amp*np.sin(2*np.pi*x/1440)


def weekday_weekend(n, base, weekend_boost):
    # Approximate 7-day cycle mapped on index; treat each 1440 points as a day
    x = np.arange(n)
    dow = (x // 1440) % 7
    boost = np.where(dow >= 5, weekend_boost, 0)
    return base + boost


def noisy(n, base, sigma):
    return base + np.random.normal(0, sigma, size=n)


def stepwise(n, base, step_every, step_size):
    x = np.arange(n)
    steps = (x // step_every) * step_size
    return base + steps


def multi_spike(n, base, amp, count):
    y = np.full(n, base)
    idx = np.random.choice(n, size=min(count, n), replace=False)
    y[idx] = y[idx] + amp
    return y


def zero_dip(n, base, length, at):
    y = np.full(n, base)
    y[max(0, at):min(n, at+length)] = 0
    return y


def bursty_poisson(n, lam, bursts, amp):
    y = np.random.poisson(lam, size=n)
    for _ in range(bursts):
        at = np.random.randint(0, n)
        y[at] += amp
    return y


SCENARIOS = {
    'steady': lambda n: steady(n, base=3),
    'spike': lambda n: spike(n, base=3, amp=10, at=int(n*0.6)),
    'ramp_up': lambda n: ramp_up(n, start=1, end=10),
    'daily_seasonality': lambda n: daily_seasonality(n, base=3, amp=2),
    'weekday_weekend': lambda n: weekday_weekend(n, base=3, weekend_boost=2),
    'noisy': lambda n: noisy(n, base=3, sigma=1.0),
    'stepwise': lambda n: stepwise(n, base=2, step_every=200, step_size=1),
    'multi_spike': lambda n: multi_spike(n, base=3, amp=7, count=5),
    'zero_dip': lambda n: zero_dip(n, base=4, length=30, at=int(n*0.5)),
    'bursty_poisson': lambda n: bursty_poisson(n, lam=3, bursts=5, amp=8),
}


def write_csv(ts, y, out):
    df = pd.DataFrame({'timestamp': [t.isoformat(timespec='seconds') + 'Z' for t in ts], 'pod_count': np.clip(np.rint(y), 0, None).astype(int)})
    out.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(out, index=False)


def main():
    ap = argparse.ArgumentParser(description='Generate synthetic scenarios for benchmarking')
    ap.add_argument('--scenario', required=True, choices=SCENARIOS.keys())
    ap.add_argument('--points', type=int, default=720, help='total points (default 720)')
    ap.add_argument('--step', type=int, default=20, help='seconds per step (default 20s)')
    ap.add_argument('--split', type=float, default=0.7, help='train split fraction (default 0.7)')
    ap.add_argument('--outdir', type=Path, default=Path('benchmark/data'))
    args = ap.parse_args()

    n = args.points
    ts = gen_time_index(n, args.step)
    y = SCENARIOS[args.scenario](n)

    cut = int(n * args.split)
    train_ts, test_ts = ts[:cut], ts[cut:]
    train_y, test_y = y[:cut], y[cut:]

    write_csv(train_ts, train_y, args.outdir / args.scenario / 'train.csv')
    write_csv(test_ts, test_y, args.outdir / args.scenario / 'test.csv')

    print(f"Wrote {args.outdir / args.scenario / 'train.csv'} and test.csv")


if __name__ == '__main__':
    np.random.seed(42)
    main()

