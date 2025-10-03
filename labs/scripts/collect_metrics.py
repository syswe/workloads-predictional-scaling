#!/usr/bin/env python3
import argparse
import csv
import json
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import List


def run_cmd(cmd: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True)


def parse_cpu(value: str) -> float:
    value = value.strip()
    if not value or value == '--':
        return 0.0
    if value.endswith('m'):
        return float(value[:-1])
    # Assume cores
    return float(value) * 1000.0


def collect_top(namespace: str, selector: str) -> float:
    proc = run_cmd([
        'kubectl', '-n', namespace, 'top', 'pod',
        '--no-headers', '-l', selector
    ])
    if proc.returncode != 0:
        return 0.0
    total = 0.0
    for line in proc.stdout.strip().splitlines():
        parts = line.split()
        if len(parts) >= 2:
            total += parse_cpu(parts[1])
    return total


def get_json(namespace: str, resource: str, name: str) -> dict:
    proc = run_cmd([
        'kubectl', '-n', namespace, 'get', resource, name, '-o', 'json'
    ])
    if proc.returncode != 0:
        raise RuntimeError(f"kubectl get {resource} {name} failed: {proc.stderr.strip()}")
    return json.loads(proc.stdout)


def main():
    parser = argparse.ArgumentParser(description='Kubernetes HPA/PHPA metrik toplayıcı')
    parser.add_argument('--namespace', default='phpa-lab')
    parser.add_argument('--resource-type', choices=['hpa', 'phpa'], required=True)
    parser.add_argument('--resource-name', required=True)
    parser.add_argument('--deployment', default='php-apache')
    parser.add_argument('--duration', type=int, default=240)
    parser.add_argument('--interval', type=int, default=5)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--selector', default='run=php-apache', help='kubectl top için label selector')
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)

    resource_kind = 'predictivehorizontalpodautoscaler' if args.resource_type == 'phpa' else 'hpa'

    fieldnames = [
        'timestamp', 'elapsed_seconds', 'resource_type', 'resource_name',
        'desired_replicas', 'current_replicas', 'ready_replicas',
        'cpu_millicores_total', 'cpu_millicores_avg',
        'scale_up_events', 'scale_down_events',
        'scale_up_history_len', 'scale_down_history_len',
        'current_metrics_json'
    ]

    start = time.time()
    with args.output.open('w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        while True:
            now = time.time()
            elapsed = now - start
            if elapsed > args.duration:
                break

            timestamp = datetime.utcnow().isoformat()
            try:
                payload = get_json(args.namespace, resource_kind, args.resource_name)
            except RuntimeError as exc:
                print(f"[collect] uyarı: {exc}", file=sys.stderr)
                time.sleep(args.interval)
                continue

            status = payload.get('status', {})
            desired = status.get('desiredReplicas', 0)
            current = status.get('currentReplicas', 0)

            try:
                deploy_status = get_json(args.namespace, 'deployment', args.deployment).get('status', {})
                ready = deploy_status.get('readyReplicas', 0)
            except RuntimeError:
                ready = 0

            cpu_total = collect_top(args.namespace, args.selector)
            cpu_avg = cpu_total / ready if ready else (cpu_total / current if current else 0.0)

            if args.resource_type == 'phpa':
                scale_up_events = len(status.get('scaleUpEventHistory', []) or [])
                scale_down_events = len(status.get('scaleDownEventHistory', []) or [])
                scale_up_history_len = len(status.get('scaleUpReplicaHistory', []) or [])
                scale_down_history_len = len(status.get('scaleDownReplicaHistory', []) or [])
            else:
                scale_up_events = 0
                scale_down_events = 0
                scale_up_history_len = 0
                scale_down_history_len = 0

            row = {
                'timestamp': timestamp,
                'elapsed_seconds': round(elapsed, 2),
                'resource_type': args.resource_type,
                'resource_name': args.resource_name,
                'desired_replicas': desired,
                'current_replicas': current,
                'ready_replicas': ready,
                'cpu_millicores_total': round(cpu_total, 2),
                'cpu_millicores_avg': round(cpu_avg, 2),
                'scale_up_events': scale_up_events,
                'scale_down_events': scale_down_events,
                'scale_up_history_len': scale_up_history_len,
                'scale_down_history_len': scale_down_history_len,
                'current_metrics_json': json.dumps(status.get('currentMetrics', [])),
            }
            writer.writerow(row)
            csvfile.flush()
            time.sleep(args.interval)


if __name__ == '__main__':
    main()
