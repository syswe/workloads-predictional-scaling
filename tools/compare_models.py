#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def load_metrics(path: Path):
    try:
        with path.open() as f:
            data = json.load(f)
        return data
    except Exception:
        return None


def find_runs(root: Path):
    models = {
        'gbdt': root / 'train/models/gbdt_model/runs',
        'xgboost': root / 'train/models/xgboost_model/runs',
        'var': root / 'train/models/var_model/runs',
        'catboost': root / 'train/models/catboost_model/runs',
    }
    for name, base in models.items():
        if not base.exists():
            continue
        for run_dir in base.iterdir():
            metrics = load_metrics(run_dir / 'metrics.json')
            if metrics is not None:
                yield name, run_dir.name, metrics


def main():
    ap = argparse.ArgumentParser(description='Summarize model runs metrics')
    ap.add_argument('--root', type=Path, default=Path('.'), help='Project root')
    ap.add_argument('--fields', nargs='*', default=['rmse', 'mae', 'mape'], help='Metric fields to show')
    args = ap.parse_args()

    print('model,run,' + ','.join(args.fields))
    for model, run, metrics in find_runs(args.root):
        row = [model, run]
        for f in args.fields:
            row.append(str(metrics.get(f, '')))
        print(','.join(row))


if __name__ == '__main__':
    main()
