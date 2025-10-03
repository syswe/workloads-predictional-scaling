#!/usr/bin/env python3
import argparse
import csv
from datetime import datetime, timedelta
import math
import random
from pathlib import Path


def synth_value(t: datetime) -> float:
    # Gün içi dalgalanma
    hour_frac = t.hour + t.minute / 60
    daily = 35 + 18 * math.sin(2 * math.pi * hour_frac / 24)
    # Haftalık ritim (hafta sonu daha düşük)
    weekly = 6 * math.cos(2 * math.pi * (t.weekday() / 7))
    # Trend ve gürültü
    trend = 0.05 * ((t - datetime(t.year, t.month, 1)).total_seconds() / 3600)
    noise = random.gauss(0, 3)
    value = daily + weekly + trend + noise
    return max(1, value)


def write_series(start: datetime, hours: int, step_minutes: int, path: Path) -> None:
    current = start
    delta = timedelta(minutes=step_minutes)
    end = start + timedelta(hours=hours)
    with path.open('w', newline='') as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(['timestamp', 'pod_count'])
        while current < end:
            writer.writerow([current.isoformat(), f"{synth_value(current):.2f}"])
            current += delta


def main():
    parser = argparse.ArgumentParser(description='Sentetik PHPA veri seti üretir.')
    parser.add_argument('--output-dir', type=Path, required=True, help='Çıktı klasörü')
    parser.add_argument('--train-hours', type=int, default=72, help='Eğitim verisi süresi (saat)')
    parser.add_argument('--test-hours', type=int, default=24, help='Test verisi süresi (saat)')
    parser.add_argument('--step-minutes', type=int, default=5, help='Ölçüm aralığı (dakika)')
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)

    now = datetime.utcnow().replace(minute=0, second=0, microsecond=0)
    train_start = now - timedelta(hours=args.train_hours + args.test_hours)
    test_start = now - timedelta(hours=args.test_hours)

    write_series(train_start, args.train_hours, args.step_minutes, args.output_dir / 'train.csv')
    write_series(test_start, args.test_hours, args.step_minutes, args.output_dir / 'test.csv')

    print(f"Generated synthetic datasets under {args.output_dir}")


if __name__ == '__main__':
    main()
