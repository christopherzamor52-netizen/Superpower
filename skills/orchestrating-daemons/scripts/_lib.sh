#!/usr/bin/env bash
# _lib.sh — shared helpers for the orchestrating-daemons toolkit.
# Sourced by daemon-*.sh. Not meant to be run directly.
#
# A "daemon" is a durable, resumable headless `claude` session identified by a
# stable UUID. Each daemon has one metadata file and one latest-reply file under
# the registry dir. One turn per daemon runs at a time, so per-daemon files never
# race (different daemons touch different files; no locking needed).

set -euo pipefail

# Registry location — override with DAEMON_HOME for tests.
DAEMON_HOME="${DAEMON_HOME:-$HOME/.claude/orchestrating-daemons}"
mkdir -p "$DAEMON_HOME"

# Default per-turn wall-clock cap (seconds). A turn that blocks longer (e.g. on a
# permission wall no one can answer) is killed so its background shell can't hang
# forever. Override with DAEMON_TIMEOUT.
DAEMON_TIMEOUT="${DAEMON_TIMEOUT:-900}"

_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

_meta_path()  { printf '%s/%s.json' "$DAEMON_HOME" "$1"; }
_reply_path() { printf '%s/%s.reply.json' "$DAEMON_HOME" "$1"; }
_err_path()   { printf '%s/%s.err' "$DAEMON_HOME" "$1"; }

# Portable timeout: macOS ships neither `timeout` nor `gtimeout` by default.
_timeout() {
  local secs="$1"; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    "$@" &
    local pid=$!
    ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null || true ) &
    local watcher=$!
    local rc=0
    wait "$pid" || rc=$?
    kill "$watcher" 2>/dev/null || true
    return "$rc"
  fi
}

# Merge key=value pairs into a daemon's metadata JSON (creates it if absent).
# Usage: _meta_set <uuid> field1 value1 [field2 value2 ...]
_meta_set() {
  local uuid="$1"; shift
  local path; path="$(_meta_path "$uuid")"
  DAEMON_META_PATH="$path" python3 - "$@" <<'PY'
import json, os, sys
path = os.environ["DAEMON_META_PATH"]
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}
args = sys.argv[1:]
for i in range(0, len(args), 2):
    data[args[i]] = args[i + 1]
tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
os.replace(tmp, path)
PY
}

# Print one metadata field (empty string if missing).
_meta_get() {
  local uuid="$1" field="$2" path
  path="$(_meta_path "$uuid")"
  [ -f "$path" ] || { printf ''; return 0; }
  DAEMON_META_PATH="$path" python3 - "$field" <<'PY'
import json, os, sys
try:
    with open(os.environ["DAEMON_META_PATH"]) as f:
        print(json.load(f).get(sys.argv[1], ""))
except Exception:
    print("")
PY
}

# Return 0 if a daemon's latest reply file is a successful result turn, else 1.
_reply_ok() {
  local path; path="$(_reply_path "$1")"
  [ -f "$path" ] || return 1
  DAEMON_REPLY_PATH="$path" python3 - <<'PY'
import json, os, sys
try:
    d = json.load(open(os.environ["DAEMON_REPLY_PATH"]))
except Exception:
    sys.exit(1)
sys.exit(0 if d.get("type") == "result" and not d.get("is_error") else 1)
PY
}

# Extract the assistant reply text (.result) from a claude -p JSON reply file.
# Prints a diagnostic string if the file is missing or not the success shape.
_reply_text() {
  local uuid="$1" path
  path="$(_reply_path "$uuid")"
  [ -f "$path" ] || { printf '(no reply yet)'; return 0; }
  DAEMON_REPLY_PATH="$path" python3 - <<'PY'
import json, os
try:
    with open(os.environ["DAEMON_REPLY_PATH"]) as f:
        d = json.load(f)
except Exception as e:
    print(f"(unparseable reply: {e})"); raise SystemExit
if d.get("type") == "result" and not d.get("is_error"):
    print(d.get("result", "").strip())
else:
    print(f"(error turn: {d.get('subtype') or d.get('result') or d})")
PY
}

# Resolve a short id (or full UUID prefix) to a full UUID by matching registry
# metadata files. Prints the full UUID, or errors if zero / multiple matches.
_resolve_uuid() {
  local q="$1" match
  match="$(DAEMON_HOME="$DAEMON_HOME" python3 - "$q" <<'PY'
import glob, os, sys
home = os.environ["DAEMON_HOME"]; q = sys.argv[1]
hits = []
for p in glob.glob(os.path.join(home, "*.json")):
    if p.endswith(".reply.json"):
        continue
    u = os.path.basename(p)[:-5]
    if u == q or u.startswith(q):
        hits.append(u)
if len(hits) == 1:
    print(hits[0])
elif not hits:
    sys.exit(3)
else:
    sys.stderr.write("ambiguous id '%s' matches: %s\n" % (q, ", ".join(hits)))
    sys.exit(4)
PY
)" || { echo "no daemon matching '$q'" >&2; return 1; }
  printf '%s' "$match"
}

# Resolve the on-disk transcript path for a daemon in a given cwd (fallback reader).
_transcript_path() {
  local uuid="$1" cwd="$2" munged
  munged="$(printf '%s' "$cwd" | sed 's#/#-#g')"
  printf '%s/.claude/projects/%s/%s.jsonl' "$HOME" "$munged" "$uuid"
}
