#!/usr/bin/env bash
# board-show.sh — one ticket in full: node JSON, md path, bound daemon.
#
# Usage: board-show.sh <id>
#
# The daemon binding lives in the daemon registry (a `ticket` key in the
# daemon's meta JSON — see board-bind.sh), never in the map.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"
[ $# -eq 1 ] || { usage_from_header "$0" >&2; exit 2; }
[ -f "$MAP" ] || die "no board at $MAP (nothing registered yet)"

T_ID="$1" T_DHOME="$DAEMON_HOME" _py - <<'PY'
import glob, json, os, sys

env = os.environ
with open(env["BOARD_MAP"]) as f:
    board = json.load(f)
tid = env["T_ID"]
n = board["tickets"].get(tid)
if n is None:
    sys.stderr.write("error: unknown ticket: %s\n" % tid)
    sys.exit(1)
print(json.dumps({tid: n}, indent=2))
print("md: %s" % os.path.join(os.path.dirname(env["BOARD_MAP"]), n["md"]))
for p in sorted(glob.glob(os.path.join(env["T_DHOME"], "*.json"))):
    try:
        with open(p) as f:
            m = json.load(f)
    except (ValueError, OSError):
        continue
    if m.get("ticket") == tid:
        print("daemon: %s  status=%s  cwd=%s  worktree=%s" %
              (m.get("uuid", os.path.basename(p)[:-5]), m.get("status"),
               m.get("cwd"), m.get("worktree") or "-"))
        break
else:
    print("daemon: (none bound)")
PY
