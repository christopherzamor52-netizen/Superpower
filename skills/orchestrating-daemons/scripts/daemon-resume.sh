#!/usr/bin/env bash
# daemon-resume.sh <short-or-full-uuid> <message>
#
# Continue a daemon by FORKING a new native background turn. A daemon's identity
# is its ORIGINAL session uuid (the registry meta filename); each resume runs
# `claude stop` on the current turn to release its bg ownership (which also drops
# it from the active `claude agents` view), then `claude --bg --resume <current>`
# to fork a fresh bg agent that carries the full conversation forward. The new
# turn gets its own short/uuid; the registry chains them via the `current` field,
# so the daemon keeps one stable id while its human-visible short changes.
#
# Because the forked turn is a native `--bg` agent, it is visible in
# `claude agents` (kind=background) and survives this orchestrator ending — the
# toolkit never kills it.
#
# NEVER RUN THIS IN THE FOREGROUND — it blocks while the watcher polls for the
# forked turn to finish, prints the reply, then exits. Run it under a Monitor (the
# reply streams into context as an event — no read step) or a background shell
# (Bash run_in_background: true). Resume is scoped to the daemon's cwd, which this
# script restores.

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$DIR/_lib.sh"

uuid="$(_resolve_uuid "${1:?usage: daemon-resume.sh <uuid> <message>}")"
msg="${2:?missing message}"

name="$(_meta_get "$uuid" name)"
cwd="$(_meta_get "$uuid" cwd)"; model="$(_meta_get "$uuid" model)"
turns="$(_meta_get "$uuid" turns)"; [ -n "$turns" ] || turns=0

# The turn to fork from is the CURRENT session (backward compat: metas created
# before the fork rework have no `current`, so fall back to the daemon's uuid).
cur="$(_meta_get "$uuid" current)"; [ -n "$cur" ] || cur="$uuid"
curshort="$(_meta_get "$uuid" short)"

# Release the current bg turn (idempotent — harmless if already stopped). This
# also drops it from the active `claude agents` view before the next turn forks.
[ -n "$curshort" ] && claude stop "$curshort" >/dev/null 2>&1 || true

_meta_set "$uuid" status "working" updated "$(_now)"

# Fork a new native bg agent from the current session — new short/uuid, full
# context. `-n` keeps the daemon's display name stable across turns.
args=( --bg --resume "$cur" --permission-mode auto -n "$name" )
[ -n "$model" ] && args+=( --model "$model" )
args+=( "$msg" )

banner="$(cd "$cwd" && claude "${args[@]}" </dev/null 2>&1 | _strip_ansi)"
newshort="$(printf '%s\n' "$banner" | sed -n 's/.*backgrounded · \([0-9a-f][0-9a-f]*\).*/\1/p' | head -1)"
if [ -z "$newshort" ]; then
  _meta_set "$uuid" status "error" updated "$(_now)"
  echo "resume failed — could not parse background id from:" >&2
  echo "$banner" >&2
  exit 1
fi

# Wait for the forked turn to finish; capture the new UUID and state. The cwd is
# fixed at spawn (the worktree path, if any) and never changes across turns.
read -r newuuid state _ < <(_poll_until_done "$newshort" "$((DAEMON_TIMEOUT / 2))") || true
if [ -z "$newuuid" ]; then
  _meta_set "$uuid" status "error" short "$newshort" updated "$(_now)"
  echo "resume: forked agent $newshort never appeared in 'claude agents'" >&2
  exit 1
fi

status="idle"; [ "$state" = "blocked" ] && status="blocked"; [ "$state" = "error" ] && status="error"

# Reply file stays keyed by the ORIGINAL uuid; read the reply from the new turn.
_transcript_reply "$newuuid" > "$(_reply_path "$uuid")"
_meta_set "$uuid" current "$newuuid" short "$newshort" \
  status "$status" updated "$(_now)" turns "$((turns + 1))"

echo "daemon resumed: $name  [$newshort / $uuid]  status=$(_meta_get "$uuid" status)  turns=$(_meta_get "$uuid" turns)  current=$newuuid"
echo "--- reply ---"
_reply_text "$uuid"
