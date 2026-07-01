#!/usr/bin/env bash
# daemon-resume.sh <uuid> <message>
#
# Send a follow-up message to an existing daemon and run one more turn, IN PLACE
# (same UUID, full context preserved). Blocks until the turn completes, then
# records the reply. LAUNCH THIS IN A BACKGROUND SHELL (Bash run_in_background:
# true) so it doesn't tie up the orchestrator — the shell's exit re-invokes you
# with the reply preview.
#
# claude --resume is scoped to the daemon's cwd (its project), so this script
# cd's to the recorded cwd before resuming — resuming from the wrong dir yields
# "No conversation found".

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$DIR/_lib.sh"

uuid="${1:?usage: daemon-resume.sh <uuid> <message>}"
msg="${2:?missing message}"

[ -f "$(_meta_path "$uuid")" ] || { echo "unknown daemon: $uuid (not in registry)" >&2; exit 2; }
cwd="$(_meta_get "$uuid" cwd)"; model="$(_meta_get "$uuid" model)"
turns="$(_meta_get "$uuid" turns)"; [ -n "$turns" ] || turns=0

_meta_set "$uuid" status "working" updated "$(_now)"

args=( -p --resume "$uuid" --permission-mode auto --output-format json )
[ -n "$model" ] && args+=( --model "$model" )
args+=( "$msg" )

reply="$(_reply_path "$uuid")"; err="$(_err_path "$uuid")"
rc=0
( cd "$cwd" && _timeout "$DAEMON_TIMEOUT" claude "${args[@]}" ) >"$reply" 2>"$err" || rc=$?

if [ "$rc" -eq 0 ] && _reply_ok "$uuid"; then
  _meta_set "$uuid" status "idle" updated "$(_now)" turns "$((turns + 1))"
else
  _meta_set "$uuid" status "error" updated "$(_now)" exit_code "$rc"
fi

echo "daemon resumed: $(_meta_get "$uuid" name)  [$uuid]  status=$(_meta_get "$uuid" status)  turns=$(_meta_get "$uuid" turns)"
echo "--- reply ---"
_reply_text "$uuid"
