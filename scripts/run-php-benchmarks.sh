#!/usr/bin/env bash
set -euo pipefail

NS="default"
PHPA_NAME="simple-catboost"
PORT=18080
SCENARIOS_ARG=""
SAMPLE_INTERVAL=10

usage() {
  cat <<'USAGE'
Usage: bash scripts/run-php-benchmarks.sh [options]
  --namespace <ns>     Kubernetes namespace for the demo stack (default: default)
  --phpa-name <name>   PredictiveHorizontalPodAutoscaler resource name (default: simple-catboost)
  --port <port>        Local port for service port-forward (default: 18080)
  --scenarios <list>   Comma-separated subset of scenarios to run (default: all)
  --interval <sec>     Sampling interval for metrics (default: 10)
  -h, --help           Show this help

The script assumes the php-apache sample app and PHPA operator are already running.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NS="$2"; shift 2;;
    --phpa-name) PHPA_NAME="$2"; shift 2;;
    --port) PORT="$2"; shift 2;;
    --scenarios) SCENARIOS_ARG="$2"; shift 2;;
    --interval) SAMPLE_INTERVAL="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1;;
  esac
done

command -v kubectl >/dev/null 2>&1 || { echo "kubectl not found" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found" >&2; exit 1; }

HEY_BIN=${HEY_BIN:-"$(go env GOPATH 2>/dev/null)/bin/hey"}
if [[ ! -x "$HEY_BIN" ]]; then
  echo "hey load generator not found at $HEY_BIN" >&2
  echo "Install via: go install github.com/rakyll/hey@latest" >&2
  exit 1
fi

kubectl get namespace "$NS" >/dev/null 2>&1 || { echo "Namespace $NS not found" >&2; exit 1; }
kubectl -n "$NS" get phpa "$PHPA_NAME" >/dev/null 2>&1 || { echo "PHPA $PHPA_NAME not found in namespace $NS" >&2; exit 1; }
kubectl -n "$NS" get svc php-apache >/dev/null 2>&1 || { echo "Service php-apache not found in namespace $NS" >&2; exit 1; }

RESULT_ROOT="benchmark/results/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULT_ROOT"
SUMMARY_FILE="$RESULT_ROOT/summary.csv"

declare -a ALL_SCENARIOS=(
  "steady_baseline"
  "lunch_rush"
  "marketing_spike"
  "release_ramp"
  "weekend_waves"
  "flash_sale"
  "nightly_maintenance"
  "bot_attack"
  "sustained_demand"
  "decay_after_peak"
)

scenario_description() {
  case "$1" in
    steady_baseline) echo "Steady weekday traffic with predictable baseline load" ;;
    lunch_rush) echo "Midday ramp with lunch peak typical of food ordering apps" ;;
    marketing_spike) echo "Abrupt spike from a marketing blast followed by return to normal" ;;
    release_ramp) echo "Gradual traffic climb after a feature release announcement" ;;
    weekend_waves) echo "Repeated high/low weekend browsing waves" ;;
    flash_sale) echo "Short burst flash sale traffic with cooldowns" ;;
    nightly_maintenance) echo "Low overnight traffic with maintenance window pause" ;;
    bot_attack) echo "Noisy bot-like traffic surge with elevated concurrency" ;;
    sustained_demand) echo "Sustained elevated demand from a popular campaign" ;;
    decay_after_peak) echo "Sharp peak that decays gradually after event ends" ;;
    *) echo "(no description)" ;;
  esac
}

if [[ -n "$SCENARIOS_ARG" ]]; then
  IFS=',' read -r -a SELECTED_SCENARIOS <<< "$SCENARIOS_ARG"
else
  SELECTED_SCENARIOS=("${ALL_SCENARIOS[@]}")
fi

TARGET_URL="http://127.0.0.1:${PORT}/"
PORT_FWD_LOG="$RESULT_ROOT/port-forward.log"
PF_PID=""
SAMPLER_PID=""

cleanup() {
  if [[ -n "$SAMPLER_PID" ]]; then
    kill "$SAMPLER_PID" 2>/dev/null || true
  fi
  if [[ -n "$PF_PID" ]]; then
    kill "$PF_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

start_port_forward() {
  if lsof -i tcp:"$PORT" >/dev/null 2>&1; then
    echo "Port $PORT is already in use" >&2
    exit 1
  fi
  kubectl -n "$NS" port-forward svc/php-apache "$PORT":80 >"$PORT_FWD_LOG" 2>&1 &
  PF_PID=$!
  sleep 5
  if ! kill -0 "$PF_PID" >/dev/null 2>&1; then
    echo "Failed to establish port-forward. Check $PORT_FWD_LOG" >&2
    exit 1
  fi
}

run_phase() {
  local scenario="$1"
  local label="$2"
  local duration="$3"
  local qps="$4"
  local concurrency="$5"
  local load_log="$6"

  printf '\n[%s] phase=%s duration=%ss qps=%s concurrency=%s\n' "$(date -Iseconds)" "$label" "$duration" "$qps" "$concurrency" | tee -a "$load_log"
  if [[ "$qps" == "0" ]]; then
    sleep "$duration"
    printf 'SLEEP %s seconds\n' "$duration" >> "$load_log"
    return
  fi

  local tmp_log
  tmp_log="$(mktemp)"
  if ! "$HEY_BIN" -z "${duration}s" -q "$qps" -c "$concurrency" "$TARGET_URL" >"$tmp_log" 2>&1; then
    cat "$tmp_log" >&2
    rm -f "$tmp_log"
    exit 1
  fi
  cat "$tmp_log" >> "$load_log"
  rm -f "$tmp_log"
}

start_sampler() {
  local scenario="$1"
  local sample_file="$2"
  local flag_file="$3"
  local interval="$4"
  : > "$sample_file"
  printf 'timestamp,currentReplicas,desiredReplicas,readyReplicas,avgCpuMilli\n' >> "$sample_file"
  (
    while [[ -f "$flag_file" ]]; do
      local ts current desired ready cpu avg_cpu
      ts="$(date -Iseconds)"
      local ph_json
      ph_json=$(kubectl -n "$NS" get phpa "$PHPA_NAME" -o json 2>/dev/null || echo '{}')
      current=$(echo "$ph_json" | jq -r '.status.currentReplicas // 0')
      desired=$(echo "$ph_json" | jq -r '.status.desiredReplicas // 0')
      ready=$(kubectl -n "$NS" get deploy php-apache -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
      cpu=$(kubectl -n "$NS" top pods -l app=php-apache --no-headers 2>/dev/null | \
        awk '{gsub("m","",$2); if ($2 != "") {sum+=$2; count+=1}} END {if(count>0) printf "%.1f", sum/count;}' )
      if [[ -z "$cpu" ]]; then cpu=0; fi
      printf '%s,%s,%s,%s,%s\n' "$ts" "$current" "$desired" "$ready" "$cpu" >> "$sample_file"
      sleep "$interval"
    done
  ) &
  SAMPLER_PID=$!
}

aggregate_results() {
  local scenario="$1"
  local desc="$2"
  local sample_file="$3"
  local load_log="$4"
  local summary_file="$5"

  python3 - "$scenario" "$desc" "$sample_file" "$load_log" "$summary_file" <<'PY'
import csv
import re
import sys
from pathlib import Path

scenario, desc, sample_path, load_log_path, summary_path = sys.argv[1:6]
sample_file = Path(sample_path)
load_file = Path(load_log_path)

samples = []
with sample_file.open() as f:
    reader = csv.DictReader(f)
    for row in reader:
        try:
            current = float(row['currentReplicas'])
            desired = float(row['desiredReplicas'])
            ready = float(row['readyReplicas']) if row['readyReplicas'] else 0.0
            cpu = float(row['avgCpuMilli']) if row['avgCpuMilli'] else 0.0
        except ValueError:
            continue
        samples.append({
            'current': current,
            'desired': desired,
            'ready': ready,
            'cpu': cpu,
        })

if not samples:
    peak_desired = peak_ready = avg_current = avg_cpu = max_cpu = 0.0
else:
    peak_desired = max(s['desired'] for s in samples)
    peak_ready = max(s['ready'] for s in samples)
    avg_current = sum(s['current'] for s in samples) / len(samples)
    avg_cpu = sum(s['cpu'] for s in samples) / len(samples)
    max_cpu = max(s['cpu'] for s in samples)

log_text = load_file.read_text()
blocks = re.split(r"\nSummary:\n", log_text)
phase_stats = []
for block in blocks[1:]:
    if 'Requests/sec' not in block:
        continue
    duration_match = re.search(r"Total:\s+([0-9.]+)\s+secs", block)
    rps_match = re.search(r"Requests/sec:\s+([0-9.]+)", block)
    avg_match = re.search(r"Average:\s+([0-9.]+)\s+secs", block)
    responses = sum(int(m.group(2)) for m in re.finditer(r"\[(\d+)\]\s+(\d+) responses", block))
    if not (duration_match and rps_match and avg_match):
        continue
    duration = float(duration_match.group(1))
    rps = float(rps_match.group(1))
    avg_latency = float(avg_match.group(1))
    phase_stats.append({
        'duration': duration,
        'rps': rps,
        'responses': responses,
        'avg_latency': avg_latency,
    })

total_duration = sum(p['duration'] for p in phase_stats)
total_requests = sum(p['responses'] for p in phase_stats)
if total_duration > 0:
    avg_rps = total_requests / total_duration
else:
    avg_rps = 0.0
if total_requests > 0:
    weighted_latency = sum(p['avg_latency'] * p['responses'] for p in phase_stats) / total_requests
else:
    weighted_latency = 0.0

summary_fields = [
    'scenario', 'description', 'total_duration_s', 'total_requests', 'avg_rps',
    'weighted_avg_latency_s', 'peak_desired', 'peak_ready', 'avg_current', 'avg_cpu_m', 'max_cpu_m'
]

summary_row = [
    scenario,
    desc,
    f"{total_duration:.1f}",
    str(total_requests),
    f"{avg_rps:.2f}",
    f"{weighted_latency:.3f}",
    f"{peak_desired:.1f}",
    f"{peak_ready:.1f}",
    f"{avg_current:.2f}",
    f"{avg_cpu:.1f}",
    f"{max_cpu:.1f}",
]

summary_path = Path(summary_path)
if not summary_path.exists():
    summary_path.write_text(','.join(summary_fields) + '\n')
with summary_path.open('a') as f:
    f.write(','.join(summary_row) + '\n')

print(', '.join(f"{field}={value}" for field, value in zip(summary_fields, summary_row)))
PY
}

run_scenario() {
  local scenario="$1"
  local desc="$2"
  local sampler_interval="$3"

  local scenario_dir="$RESULT_ROOT/$scenario"
  mkdir -p "$scenario_dir"
  local sample_file="$scenario_dir/samples.csv"
  local load_log="$scenario_dir/load.log"
  local flag_file="$scenario_dir/.running"
  : > "$load_log"
  touch "$flag_file"

  start_sampler "$scenario" "$sample_file" "$flag_file" "$sampler_interval"

  case "$scenario" in
    steady_baseline)
      run_phase "$scenario" "warmup" 30 10 4 "$load_log"
      run_phase "$scenario" "steady" 60 18 6 "$load_log"
      ;;
    lunch_rush)
      run_phase "$scenario" "baseline" 30 8 4 "$load_log"
      run_phase "$scenario" "ramp" 30 40 12 "$load_log"
      run_phase "$scenario" "peak" 30 80 20 "$load_log"
      ;;
    marketing_spike)
      run_phase "$scenario" "pre" 30 8 4 "$load_log"
      run_phase "$scenario" "spike" 45 180 36 "$load_log"
      run_phase "$scenario" "recovery" 30 12 6 "$load_log"
      ;;
    release_ramp)
      run_phase "$scenario" "phase1" 20 20 6 "$load_log"
      run_phase "$scenario" "phase2" 20 40 10 "$load_log"
      run_phase "$scenario" "phase3" 20 80 18 "$load_log"
      run_phase "$scenario" "phase4" 20 120 24 "$load_log"
      run_phase "$scenario" "plateau" 20 120 24 "$load_log"
      ;;
    weekend_waves)
      for i in 1 2 3; do
        run_phase "$scenario" "wave${i}_idle" 20 18 6 "$load_log"
        run_phase "$scenario" "wave${i}_peak" 20 120 24 "$load_log"
      done
      ;;
    flash_sale)
      for i in 1 2 3 4; do
        run_phase "$scenario" "cycle${i}_prep" 15 15 5 "$load_log"
        run_phase "$scenario" "cycle${i}_burst" 15 160 32 "$load_log"
      done
      ;;
    nightly_maintenance)
      run_phase "$scenario" "evening" 45 10 4 "$load_log"
      run_phase "$scenario" "maintenance" 60 0 0 "$load_log"
      run_phase "$scenario" "back_online" 30 15 5 "$load_log"
      ;;
    bot_attack)
      run_phase "$scenario" "baseline" 30 50 16 "$load_log"
      run_phase "$scenario" "attack" 60 300 60 "$load_log"
      run_phase "$scenario" "cooldown" 30 40 12 "$load_log"
      ;;
    sustained_demand)
      run_phase "$scenario" "sustained" 120 150 30 "$load_log"
      ;;
    decay_after_peak)
      run_phase "$scenario" "peak" 30 150 30 "$load_log"
      run_phase "$scenario" "post_peak" 30 90 18 "$load_log"
      run_phase "$scenario" "tail" 30 40 12 "$load_log"
      ;;
    *)
      echo "Unknown scenario $scenario" >&2
      rm -f "$flag_file"
      wait "$SAMPLER_PID" 2>/dev/null || true
      return 1
      ;;
  esac

  rm -f "$flag_file"
  if [[ -n "$SAMPLER_PID" ]]; then
    wait "$SAMPLER_PID" 2>/dev/null || true
    SAMPLER_PID=""
  fi

  aggregate_results "$scenario" "$desc" "$sample_file" "$load_log" "$SUMMARY_FILE"
}

start_port_forward

printf 'Writing detailed results under %s\n' "$RESULT_ROOT"

echo "scenario,description,total_duration_s,total_requests,avg_rps,weighted_avg_latency_s,peak_desired,peak_ready,avg_current,avg_cpu_m,max_cpu_m" > "$SUMMARY_FILE"

for scenario in "${SELECTED_SCENARIOS[@]}"; do
  desc="$(scenario_description "$scenario")"
  printf '\n=== Running scenario: %s ===\n' "$scenario"
  run_scenario "$scenario" "$desc" "$SAMPLE_INTERVAL"
  printf 'Scenario %s complete.\n' "$scenario"

done

printf '\nBenchmark summary (CSV): %s\n' "$SUMMARY_FILE"
cat "$SUMMARY_FILE"
