#!/usr/bin/env python3
import argparse
import csv
from pathlib import Path
from statistics import mean


def read_rows(path: Path):
    rows = []
    with path.open() as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                rows.append({
                    'elapsed': float(row['elapsed_seconds']),
                    'desired': float(row['desired_replicas']),
                    'current': float(row['current_replicas']),
                    'ready': float(row['ready_replicas']),
                    'cpu_total': float(row['cpu_millicores_total']),
                    'cpu_avg': float(row['cpu_millicores_avg']),
                    'scale_up_events': float(row['scale_up_events']),
                    'scale_down_events': float(row['scale_down_events'])
                })
            except ValueError:
                continue
    return rows


def area_under_curve(rows, key):
    if len(rows) < 2:
        return 0.0
    area = 0.0
    for prev, curr in zip(rows, rows[1:]):
        dt = curr['elapsed'] - prev['elapsed']
        if dt < 0:
            continue
        avg_val = (curr[key] + prev[key]) / 2.0
        area += avg_val * dt
    return area


def first_time_above(rows, baseline):
    for row in rows:
        if row['desired'] > baseline:
            return row['elapsed']
    return None


def summarise(path: Path):
    rows = read_rows(path)
    if not rows:
        return None
    baseline = rows[0]['desired']
    peak = max(rows, key=lambda r: r['desired'])
    summary = {
        'scenario': path.stem,
        'duration': rows[-1]['elapsed'] if rows else 0,
        'desired_peak': peak['desired'],
        'time_to_peak': peak['elapsed'],
        'time_to_first_scale': first_time_above(rows, baseline),
        'mean_desired': mean([r['desired'] for r in rows]),
        'mean_ready': mean([r['ready'] for r in rows]),
        'peak_ready': max(r['ready'] for r in rows),
        'cpu_mean_millicores': mean([r['cpu_total'] for r in rows]),
        'cpu_peak_millicores': max(r['cpu_total'] for r in rows),
        'scale_up_events_total': max(r['scale_up_events'] for r in rows),
        'scale_down_events_total': max(r['scale_down_events'] for r in rows),
        'desired_replica_area': area_under_curve(rows, 'desired'),
    }
    return summary


def main():
    ap = argparse.ArgumentParser(description='Online deney sonuçlarını özetler')
    ap.add_argument('--input-dir', type=Path, required=True)
    ap.add_argument('--output-csv', type=Path, required=True)
    args = ap.parse_args()

    summaries = []
    for path in sorted(args.input_dir.glob('*.csv')):
        summary = summarise(path)
        if summary:
            summaries.append(summary)

    if not summaries:
        print('No online data found.')
        return

    fieldnames = list(summaries[0].keys())
    args.output_csv.parent.mkdir(parents=True, exist_ok=True)
    with args.output_csv.open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for item in summaries:
            writer.writerow(item)


if __name__ == '__main__':
    main()
