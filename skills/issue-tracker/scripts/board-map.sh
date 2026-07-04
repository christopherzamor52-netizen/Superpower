#!/usr/bin/env bash
# board-map.sh — human telemetry for the board.
#
# Usage: board-map.sh [--write]
#
#   (default)  print the fallback table (ticket · state · title · PR) to stdout
#   --write    render two caches of map.json into doperpowers/issue-tracker/:
#              BOARD.html — the primary view: an interactive layered-DAG (pan/zoom,
#              click a node for detail, filter by state, collapse epics), opened
#              in a browser; and BOARD.md — a minimal node/state table, the
#              GitHub-inline fallback. Both are pure render caches, refreshed by
#              every board write; --write re-renders them by hand.
#
# Reading BOARD.html: node color = state; ELIGIBLE (ready-for-agent + all blockers
# done, not an epic) gets a thick green border; a solid arrow is an ACTIVE block,
# a dotted one a satisfied dependency; labeled dotted lines carry spawned/relates
# lineage; each epic is a labeled box around its members (click to collapse).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=_lib.sh
. "$SCRIPT_DIR/_lib.sh"
[ -f "$MAP" ] || die "no board at $MAP (nothing registered yet)"

write=0
[ "${1:-}" = "--write" ] && write=1

# One python pass per call: it always prints the fallback table to stdout, and
# on --write it also writes BOARD.md and renders BOARD.html — the table and the
# graph share the single map.json parse (one process, not two).
BOARD_MAP="$MAP" BOARD_DIR="$BOARD_DIR" \
BOARD_TEMPLATE="$SCRIPT_DIR/board-map.template.html" \
BOARD_WRITE="$write" python3 - <<'PY'
import json, os

env = os.environ
with open(env["BOARD_MAP"]) as f:
    board = json.load(f)
tickets = board["tickets"]

def num(t): return int(t[1:])
order = sorted(tickets, key=num)
epics = {n["parent"] for n in tickets.values() if n.get("parent")}

def eligible(tid, n):
    if tid in epics or n["state"] != "ready-for-agent":
        return False
    return all(tickets.get(b, {}).get("state") == "done" for b in n.get("blocked_by", []))

def state_label(tid, n):
    if n["state"] == "ready-for-agent":
        unmet = [b for b in n.get("blocked_by", []) if tickets.get(b, {}).get("state") != "done"]
        return ("waiting: " + ",".join(unmet)) if unmet else "ELIGIBLE"
    return n["state"]

updated = max((n.get("updated") or "" for n in tickets.values()), default="")

# The fallback table: stdout always; BOARD.md on --write. GitHub renders it inline.
md = ["# Issue Board", "",
      "_Board updated %s · %d tickets · full interactive graph in "
      "`BOARD.html` (open in a browser)_" % (updated, len(tickets)), "",
      "| ticket | state | title | PR |", "|---|---|---|---|"]
for tid in order:
    n = tickets[tid]
    title = " ".join(str(n["title"]).split()).replace("|", "\\|")
    md.append("| %s | %s | %s | %s |" % (tid, state_label(tid, n), title, n.get("pr") or ""))
table = "\n".join(md)
print(table)

if env["BOARD_WRITE"] != "1":
    raise SystemExit(0)

with open(env["BOARD_DIR"] + "/BOARD.md", "w") as f:
    f.write(table + "\n")

# --- the interactive graph (BOARD.html) ---
CLASS = {"done": "s_done", "in-progress": "s_prog", "in-review": "s_rev", "blocked": "s_blk",
         "needs-info": "s_info", "deferred": "s_def", "wontfix": "s_wf"}
def cls(tid, n):
    if n["state"] == "ready-for-agent":
        return "s_elig" if eligible(tid, n) else "s_wait"
    return CLASS.get(n["state"], "s_wait")

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

# Rendered edges that can visually cross: blocked_by (block), spawned_by
# (spawned), relates_to (relates). Parent edges draw as epic BOXES, not lines,
# so they never cross — the neighbor set below deliberately excludes them.
nbr = {t: set() for t in order}
for t in order:
    n = tickets[t]
    for b in n.get("blocked_by", []):
        if b in tickets:
            nbr[t].add(b); nbr[b].add(t)
    sb = n.get("spawned_by")
    if sb in tickets:
        nbr[t].add(sb); nbr[sb].add(t)
    for r in n.get("relates_to", []) or []:
        if r in tickets:
            nbr[t].add(r); nbr[r].add(t)

# Within-layer ordering: crossing minimization by barycenter, constrained to a
# cluster's own band (a node never leaves its swimlane, so an epic's bounding
# box stays honest). Fully deterministic (no Date/random) and never worse than
# the id-stable baseline: the numeric-id order is always a candidate and we keep
# whichever order has the fewest actual crossings — a graph the heuristic can't
# improve renders byte-identical to before.
def _ccw(a, b, c):
    return (c[1] - a[1]) * (b[0] - a[0]) - (b[1] - a[1]) * (c[0] - a[0])
def _seg_cross(p1, p2, p3, p4):  # proper intersection; shared endpoints don't count
    return ((_ccw(p3, p4, p1) > 0) != (_ccw(p3, p4, p2) > 0) and
            (_ccw(p1, p2, p3) > 0) != (_ccw(p1, p2, p4) > 0))
def _bary(t, ix, cset):
    ns = [ix[u] for u in nbr[t] if u in cset]
    return sum(ns) / len(ns) if ns else ix[t]

def order_cluster(members):
    cset = set(members)
    per_layer = {}
    for t in members:
        per_layer.setdefault(LAYER[t], []).append(t)
    for lv in per_layer:
        per_layer[lv].sort(key=num)
    # this cluster's rendered edges, once each (as BOARD.html draws them),
    # as (u, v) segments — direction is irrelevant to a crossing count.
    ce, seen_rel = [], set()
    for t in sorted(cset, key=num):
        n = tickets[t]
        for b in n.get("blocked_by", []):
            if b in cset: ce.append((b, t))
        sb = n.get("spawned_by")
        if sb in cset: ce.append((sb, t))
        for r in n.get("relates_to", []) or []:
            if r in cset and (r, t) not in seen_rel:
                seen_rel.add((t, r)); ce.append((t, r))
    def slots(o):
        m = {}
        for lst in o.values():
            for i, t in enumerate(lst): m[t] = i
        return m
    def crossings(o):
        xy = {t: (i, LAYER[t]) for t, i in slots(o).items()}
        c = 0
        for i in range(len(ce)):
            a, b = ce[i]
            for j in range(i + 1, len(ce)):
                d, e = ce[j]
                if len({a, b, d, e}) == 4 and _seg_cross(xy[a], xy[b], xy[d], xy[e]):
                    c += 1
        return c
    best = {lv: list(v) for lv, v in per_layer.items()}
    best_x = crossings(best)
    cur = {lv: list(v) for lv, v in per_layer.items()}
    for it in range(6):
        seq = sorted(per_layer, reverse=bool(it % 2))
        ix = slots(cur)
        for lv in seq:
            cur[lv] = sorted(cur[lv], key=lambda t, ix=ix: (_bary(t, ix, cset), num(t)))
            ix = slots(cur)
        x = crossings(cur)
        if x < best_x:
            best_x, best = x, {lv: list(v) for lv, v in cur.items()}
        if best_x == 0:
            break
    return best

# Coordinates: give each top-level cluster (epic tree or lone node) its own
# disjoint column band, so an epic's bounding box can only ever enclose its own
# members. Band width is the max nodes-per-layer (order-independent), so the
# bands are identical to id-order — only the slot a node takes within its band
# changes. Layer sets the row; crossing-minimized order sets the slot.
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
    for lv, lst in order_cluster(clusters[rt]).items():
        for i, t in enumerate(lst):
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
payload = {"meta": {"updated": updated, "count": len(tickets)},
           "nodes": nodes, "edges": edges, "epics": epx}

# Embed in a <script> block: neutralize <, >, & so a title can't break out.
data = json.dumps(payload, indent=2).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
with open(env["BOARD_TEMPLATE"]) as f:
    tpl = f.read()
with open(env["BOARD_DIR"] + "/BOARD.html", "w") as f:
    f.write(tpl.replace("__BOARD_PAYLOAD__", data))
PY

if [ "$write" -eq 1 ]; then
  echo "wrote $BOARD_DIR/BOARD.md and $BOARD_DIR/BOARD.html" >&2
fi
