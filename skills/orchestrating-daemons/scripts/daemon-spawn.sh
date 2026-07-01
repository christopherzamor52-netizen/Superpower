#!/usr/bin/env bash
# daemon-spawn.sh <name> <task> [cwd] [model]
#
# Spawn a durable, resumable headless claude session ("daemon") with a stable
# UUID and run its FIRST turn. Blocks until that turn completes, then records the
# reply. LAUNCH THIS IN A BACKGROUND SHELL (Bash run_in_background: true) so the
# blocking turn doesn't tie up the orchestrator — the shell's exit re-invokes you
# with the reply preview in its output.
#
#   name   short human label (also the session's display name)
#   task   the initial prompt / task text
#   cwd    working dir the daemon runs in (default: $PWD). REQUIRED for resume:
#          claude --resume is scoped to the cwd's project, so it is recorded.
#   model  optional model alias/id (default: inherit)

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$DIR/_lib.sh"

name="${1:?usage: daemon-spawn.sh <name> <task> [cwd] [model]}"
task="${2:?missing task}"
cwd="${3:-$PWD}"
model="${4:-}"

uuid="$(uuidgen | tr 'A-Z' 'a-z')"

_meta_set "$uuid" \
  uuid "$uuid" name "$name" task "$task" cwd "$cwd" model "$model" \
  status "working" created "$(_now)" updated "$(_now)" turns "0"

# Fixed flags: headless, stable id, auto permission classifier, JSON out.
args=( -p --session-id "$uuid" --permission-mode auto --output-format json --name "$name" )
[ -n "$model" ] && args+=( --model "$model" )
args+=( "$task" )

reply="$(_reply_path "$uuid")"; err="$(_err_path "$uuid")"
rc=0
( cd "$cwd" && _timeout "$DAEMON_TIMEOUT" claude "${args[@]}" ) >"$reply" 2>"$err" || rc=$?

if [ "$rc" -eq 0 ] && _reply_ok "$uuid"; then
  _meta_set "$uuid" status "idle" updated "$(_now)" turns "1"
else
  _meta_set "$uuid" status "error" updated "$(_now)" exit_code "$rc"
fi

echo "daemon spawned: $name  [$uuid]  cwd=$cwd  status=$(_meta_get "$uuid" status)"
echo "--- reply ---"
_reply_text "$uuid"
