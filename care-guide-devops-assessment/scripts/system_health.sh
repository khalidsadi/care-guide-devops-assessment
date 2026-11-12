#!/usr/bin/env bash
set -euo pipefail

DISK_THRESHOLD=80
CPU_THRESHOLD=90
MEM_THRESHOLD=85
LOG_FILE="${LOG_FILE:-./health_log.txt}"
MAX_LOG_BYTES="${MAX_LOG_BYTES:-1048576}"
JSON_OUTPUT=false
WARNING=false
CRITICAL=false

usage() {
  cat <<'EOF'
Usage: system_health.sh [--disk N] [--cpu N] [--mem N] [--json] [--help]
Defaults: disk=80%, cpu=90%, memory=85%.
Exit codes: 0 healthy, 1 warning, 2 critical.
EOF
}

while (($#)); do
  case "$1" in
    --disk) DISK_THRESHOLD="${2:?Missing value for --disk}"; shift 2 ;;
    --cpu) CPU_THRESHOLD="${2:?Missing value for --cpu}"; shift 2 ;;
    --mem) MEM_THRESHOLD="${2:?Missing value for --mem}"; shift 2 ;;
    --json) JSON_OUTPUT=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for value in "$DISK_THRESHOLD" "$CPU_THRESHOLD" "$MEM_THRESHOLD"; do
  if ! [[ "$value" =~ ^[0-9]+$ ]] || ((value < 1 || value > 100)); then
    echo "Thresholds must be integers from 1 to 100." >&2
    exit 2
  fi
done

rotate_log() {
  if [[ -f "$LOG_FILE" ]]; then
    local size
    size=$(wc -c < "$LOG_FILE")
    if ((size >= MAX_LOG_BYTES)); then
      mv "$LOG_FILE" "${LOG_FILE}.1"
    fi
  fi
}

timestamp=$(date -Is)
cpu_usage=$(awk ' /cpu / {idle=$5; total=0; for(i=2;i<=NF;i++) total+=$i; if(total>0) printf "%.0f", (1-idle/total)*100 }' /proc/stat)
mem_usage=$(free | awk '/Mem:/ {printf "%.0f", ($3/$2)*100}')
disk_report=$(df -P -x tmpfs -x devtmpfs | awk 'NR>1 {print $5 " " $6}')
disk_max=$(df -P -x tmpfs -x devtmpfs | awk 'NR>1 {gsub("%","",$5); if($5>max) max=$5} END {print max+0}')
load_average=$(awk '{print $1" "$2" "$3}' /proc/loadavg)
top_processes=$(ps -eo pid,comm,%mem --sort=-%mem | head -n 6)

((cpu_usage > CPU_THRESHOLD)) && WARNING=true
((mem_usage > MEM_THRESHOLD)) && WARNING=true
((disk_max > DISK_THRESHOLD)) && WARNING=true

status="healthy"
exit_code=0
if [[ "$WARNING" == true ]]; then
  status="warning"
  exit_code=1
fi

if [[ "$cpu_usage" -gt $((CPU_THRESHOLD + 10)) || "$mem_usage" -gt $((MEM_THRESHOLD + 10)) || "$disk_max" -gt 95 ]]; then
  status="critical"
  exit_code=2
fi

if [[ "$JSON_OUTPUT" == true ]]; then
  output=$(python3 - "$timestamp" "$cpu_usage" "$mem_usage" "$disk_max" "$load_average" "$status" <<'PY'
import json, sys
timestamp, cpu, memory, disk, load, status = sys.argv[1:]
print(json.dumps({
  "timestamp": timestamp,
  "cpu_usage_percent": int(cpu),
  "memory_usage_percent": int(memory),
  "max_disk_usage_percent": int(disk),
  "load_average": load.split(),
  "status": status
}))
PY
)
else
  output="[$timestamp] status=$status cpu=${cpu_usage}% memory=${mem_usage}% max_disk=${disk_max}% load=$load
Disk usage:
$disk_report
Top 5 processes by memory:
$top_processes"
fi

rotate_log
printf '%s\n' "$output" | tee -a "$LOG_FILE"

if ((exit_code > 0)); then
  echo "[WARNING] One or more resource thresholds were exceeded."
fi
exit "$exit_code"
