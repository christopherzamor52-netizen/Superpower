#!/usr/bin/env bash
# board-map.sh — human telemetry: render the board DAG as a Mermaid flowchart.
#
# Usage: board-map.sh [--write]
#
#   (default)  print the markdown (mermaid graph + legend + PR links) to stdout
#   --write    also save it to doperpowers/issue-tracker/MAP.md — committable,
#              and GitHub renders the mermaid block natively
#
# Reading the map: node color = state; ELIGIBLE (ready-for-agent + all
# blockers done, not an epic) gets a thick green border; a thick arrow is an
# ACTIVE block, a dotted arrow a satisfied one (blocker already done);
# labeled dotted arrows carry lineage (spawned) / relates edges; epics are
# boxes (subgraphs) around their children.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"
[ -f "$MAP" ] || die "no board at $MAP (nothing registered yet)"

write=0
[ "${1:-}" = "--write" ] && write=1

out="$(_py - <<'PY'
import json, os

with open(os.environ["BOARD_MAP"]) as f:
    board = json.load(f)
tickets = board["tickets"]

def num(tid): return int(tid[1:])
order = sorted(tickets, key=num)
epics = {n["parent"] for n in tickets.values() if n.get("parent")}
children = {}
for tid in order:
    p = tickets[tid].get("parent")
    if p:
        children.setdefault(p, []).append(tid)

def eligible(tid, n):
    if tid in epics or n["state"] != "ready-for-agent":
        return False
    return all(tickets.get(b, {}).get("state") == "done"
               for b in n.get("blocked_by", []))

CLASS = {"done": "s_done", "in-progress": "s_prog", "in-review": "s_rev",
         "blocked": "s_blk", "needs-info": "s_info", "deferred": "s_def",
         "wontfix": "s_wf"}
def cls(tid, n):
    if n["state"] == "ready-for-agent":
        return "s_elig" if eligible(tid, n) else "s_wait"
    return CLASS.get(n["state"], "s_wait")

def label(tid, n):
    # One-line title, quotes stripped (they would close the mermaid string),
    # truncated so the graph stays scannable; state as a second label line.
    t = " ".join(str(n["title"]).split()).replace('"', "'")
    if len(t) > 48:
        t = t[:47] + "…"
    state = n["state"]
    if state == "ready-for-agent":
        unmet = [b for b in n.get("blocked_by", [])
                 if tickets.get(b, {}).get("state") != "done"]
        state = ("waiting: " + ",".join(unmet)) if unmet else "ELIGIBLE"
    return '%s["%s · %s<br/><i>%s</i>"]' % (tid, tid, t, state)

lines = ["flowchart TD"]
for d in [
    "classDef s_done fill:#d3f9d8,stroke:#2b8a3e,color:#1b4332",
    "classDef s_prog fill:#d0ebff,stroke:#1971c2,color:#1c3f5e",
    "classDef s_rev fill:#e5dbff,stroke:#6741d9,color:#3b2b73",
    "classDef s_elig fill:#ffffff,stroke:#2b8a3e,stroke-width:3px,color:#1b4332",
    "classDef s_wait fill:#f1f3f5,stroke:#adb5bd,color:#495057",
    "classDef s_blk fill:#ffe3e3,stroke:#c92a2a,color:#5f1414",
    "classDef s_info fill:#fff3bf,stroke:#e67700,color:#5c3c00",
    "classDef s_def fill:#f1f3f5,stroke:#adb5bd,stroke-dasharray: 5 5,color:#868e96",
    "classDef s_wf fill:#dee2e6,stroke:#495057,stroke-dasharray: 3 3,color:#495057",
]:
    lines.append("  " + d)

emitted = set()
def emit(tid, indent):
    # Epics nest as subgraphs (recursion covers epics inside epics); a cycle
    # in hand-edited parent fields must not hang the renderer.
    if tid in emitted:
        return
    emitted.add(tid)
    pad = "  " * indent
    n = tickets[tid]
    if tid in epics:
        t = " ".join(str(n["title"]).split()).replace('"', "'")
        state = n["state"]
        lines.append('%ssubgraph %s["%s · %s · %s"]' % (pad, tid, tid, t, state))
        for c in children.get(tid, []):
            emit(c, indent + 1)
        lines.append("%send" % pad)
    else:
        lines.append(pad + label(tid, n))

for tid in order:
    if not tickets[tid].get("parent"):
        emit(tid, 1)
for tid in order:  # orphans under a cyclic/missing parent still render
    emit(tid, 1)

seen_rel = set()
for tid in order:
    n = tickets[tid]
    for b in n.get("blocked_by", []):
        if b not in tickets:
            continue
        arrow = "-.->" if tickets[b]["state"] == "done" else "==>"
        lines.append("  %s %s %s" % (b, arrow, tid))
    sb = n.get("spawned_by")
    if sb and sb in tickets:
        lines.append("  %s -. spawned .-> %s" % (sb, tid))
    for r in n.get("relates_to", []) or []:
        if r in tickets and (r, tid) not in seen_rel:
            seen_rel.add((tid, r))
            lines.append("  %s -. relates .- %s" % (tid, r))

for tid in order:
    lines.append("  class %s %s" % (tid, cls(tid, tickets[tid])))

updated = max((n.get("updated") or "" for n in tickets.values()), default="")
md = []
md.append("# Issue Board Map")
md.append("")
md.append("_Board updated %s · %d tickets · regenerate with `board-map.sh --write`_"
          % (updated, len(tickets)))
md.append("")
md.append("```mermaid")
md.extend(lines)
md.append("```")
md.append("")
md.append("**Legend** — green: done · blue: in-progress · violet: in-review · "
          "thick green border: ELIGIBLE (dispatchable now) · gray: waiting · "
          "red: blocked · amber: needs-info · dashed: deferred/wontfix. "
          "Thick arrow = active block, dotted = satisfied dependency; "
          "labeled dotted arrows = spawned/relates lineage. "
          "Epic boxes wrap their children.")
links = [(tid, tickets[tid]) for tid in order if tickets[tid].get("pr")]
if links:
    md.append("")
    md.append("| ticket | state | PR |")
    md.append("|---|---|---|")
    for tid, n in links:
        md.append("| %s | %s | %s |" % (tid, n["state"], n["pr"]))
print("\n".join(md))
PY
)"

printf '%s\n' "$out"
if [ "$write" -eq 1 ]; then
  printf '%s\n' "$out" > "$BOARD_DIR/MAP.md"
  # Render the interactive graph. Call python3 directly (not via _py) so the
  # template/html paths are exported to it unambiguously alongside BOARD_MAP.
  BOARD_MAP="$MAP" BOARD_TEMPLATE="$SCRIPT_DIR/board-map.template.html" \
  BOARD_HTML="$BOARD_DIR/MAP.html" python3 - <<'PY'
import json, os

with open(os.environ["BOARD_MAP"]) as f:
    board = json.load(f)
tickets = board["tickets"]

def num(t): return int(t[1:])
order = sorted(tickets, key=num)
epics = {n["parent"] for n in tickets.values() if n.get("parent")}

def eligible(tid, n):
    if tid in epics or n["state"] != "ready-for-agent":
        return False
    return all(tickets.get(b, {}).get("state") == "done" for b in n.get("blocked_by", []))

CLASS = {"done": "s_done", "in-progress": "s_prog", "in-review": "s_rev", "blocked": "s_blk",
         "needs-info": "s_info", "deferred": "s_def", "wontfix": "s_wf"}
def cls(tid, n):
    if n["state"] == "ready-for-agent":
        return "s_elig" if eligible(tid, n) else "s_wait"
    return CLASS.get(n["state"], "s_wait")

def state_label(tid, n):
    if n["state"] == "ready-for-agent":
        unmet = [b for b in n.get("blocked_by", []) if tickets.get(b, {}).get("state") != "done"]
        return ("waiting: " + ",".join(unmet)) if unmet else "ELIGIBLE"
    return n["state"]

# Longest-path layering over blocked_by (blockers above dependents); memoized,
# and cycle-tolerant for a hand-edited map (a back-edge just resolves to 0).
LAYER = {}
def layer(tid, seen):
    if tid in LAYER:
        return LAYER[tid]
    if tid in seen:
        return 0
    bs = [b for b in tickets[tid].get("blocked_by", []) if b in tickets]
    lv = 0 if not bs else 1 + max(layer(b, seen | {tid}) for b in bs)
    LAYER[tid] = lv
    return lv
for t in order:
    layer(t, set())

def root(tid):
    seen, p = set(), tid
    while tickets[p].get("parent") in tickets and tickets[p]["parent"] not in seen:
        seen.add(p); p = tickets[p]["parent"]
    return p

def descendants(tid):
    out, seen, stack = [], set(), [c for c in order if tickets[c].get("parent") == tid]
    while stack:
        c = stack.pop()
        if c in seen or c not in tickets:
            continue
        seen.add(c); out.append(c)
        stack.extend(k for k in order if tickets[k].get("parent") == c)
    return sorted(out, key=num)

# Coordinates: give each top-level cluster (epic tree or lone node) its own
# disjoint column band, so an epic's bounding box can only ever enclose its own
# members — a non-member lives in another band, at another x. Layer sets the row.
COL, ROW = 210, 110
clusters = {}
for t in order:
    clusters.setdefault(root(t), []).append(t)
col_start, next_col = {}, 0
for rt in sorted(clusters, key=num):
    per_layer = {}
    for t in clusters[rt]:
        per_layer.setdefault(LAYER[t], []).append(t)
    col_start[rt] = next_col
    next_col += max(len(v) for v in per_layer.values())
pos = {}
for rt in sorted(clusters, key=num):
    per_layer = {}
    for t in clusters[rt]:
        per_layer.setdefault(LAYER[t], []).append(t)
    for lv, members in per_layer.items():
        for i, t in enumerate(sorted(members, key=num)):
            pos[t] = ((col_start[rt] + i) * COL, lv * ROW)

nodes = []
for t in order:
    n = tickets[t]; x, y = pos[t]
    nodes.append({
        "id": t, "state": n["state"], "eligible": eligible(t, n),
        "cls": cls(t, n), "label": state_label(t, n),
        "title": " ".join(str(n["title"]).split()),
        "category": n.get("category"), "note": n.get("note"),
        "blocked_by": n.get("blocked_by", []), "spawned_by": n.get("spawned_by"),
        "relates_to": n.get("relates_to", []) or [], "branch": n.get("branch"),
        "pr": n.get("pr"), "md": n.get("md"),
        "created": n.get("created"), "updated": n.get("updated"),
        "x": x, "y": y,
    })

edges = []
seen_rel = set()
for t in order:
    n = tickets[t]
    for b in n.get("blocked_by", []):
        if b in tickets:
            edges.append({"from": b, "to": t,
                          "kind": "block-done" if tickets[b]["state"] == "done" else "block-active"})
    sb = n.get("spawned_by")
    if sb in tickets:
        edges.append({"from": sb, "to": t, "kind": "spawned"})
    for r in n.get("relates_to", []) or []:
        if r in tickets and (r, t) not in seen_rel:
            seen_rel.add((t, r))
            edges.append({"from": t, "to": r, "kind": "relates"})

epx = [{"id": e, "descendants": descendants(e)} for e in sorted(epics, key=num) if e in tickets]
updated = max((n.get("updated") or "" for n in tickets.values()), default="")
payload = {"meta": {"updated": updated, "count": len(tickets)},
           "nodes": nodes, "edges": edges, "epics": epx}

# Embed in a <script> block: neutralize <, >, & so a title can't break out.
data = json.dumps(payload, indent=2).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
with open(os.environ["BOARD_TEMPLATE"]) as f:
    tpl = f.read()
with open(os.environ["BOARD_HTML"], "w") as f:
    f.write(tpl.replace("__BOARD_PAYLOAD__", data))
PY
  echo "wrote $BOARD_DIR/MAP.md and $BOARD_DIR/MAP.html" >&2
fi
