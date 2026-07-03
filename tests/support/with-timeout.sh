#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 SECONDS COMMAND [ARG...]" >&2
  exit 2
fi

duration="$1"
shift

if command -v timeout >/dev/null 2>&1; then
  exec timeout "$duration" "$@"
fi

if command -v gtimeout >/dev/null 2>&1; then
  exec gtimeout "$duration" "$@"
fi

command -v python3 >/dev/null 2>&1 || {
  echo "ERROR: timeout/gtimeout not found and python3 is unavailable" >&2
  exit 127
}

exec python3 - "$duration" "$@" <<'PY'
import subprocess
import sys

raw_duration = sys.argv[1]
command = sys.argv[2:]

try:
    timeout_seconds = float(raw_duration[:-1] if raw_duration.endswith("s") else raw_duration)
except ValueError:
    print(f"ERROR: invalid timeout duration: {raw_duration}", file=sys.stderr)
    sys.exit(2)

try:
    completed = subprocess.run(command, timeout=timeout_seconds)
except subprocess.TimeoutExpired:
    print(f"ERROR: command timed out after {raw_duration}", file=sys.stderr)
    sys.exit(124)
except FileNotFoundError:
    print(f"ERROR: command not found: {command[0]}", file=sys.stderr)
    sys.exit(127)

if completed.returncode < 0:
    sys.exit(128 + abs(completed.returncode))
sys.exit(completed.returncode)
PY
