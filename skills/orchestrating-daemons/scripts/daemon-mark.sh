#!/usr/bin/env bash
# daemon-mark.sh <short-or-full-uuid> <status> [note]
#
# Stamp a daemon with an orchestrator-decided status + optional note. The scripts
# only ever set working/idle/error automatically; YOU set the judgment states:
#   awaiting-human  you escalated its last reply and are waiting on the human
#   done            you judged its work complete (leave it resumable, or retire)
# The note records WHY (e.g. "escalated: playful vs professional tone — user call").

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_lib.sh
source "$DIR/_lib.sh"

uuid="$(_resolve_uuid "${1:?usage: daemon-mark.sh <uuid> <status> [note]}")"
status="${2:?missing status}"
note="${3:-}"
_meta_set "$uuid" status "$status" updated "$(_now)" note "$note"
echo "marked $(_meta_get "$uuid" name) [$uuid] -> $status${note:+  ($note)}"
