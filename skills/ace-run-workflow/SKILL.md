---
name: ace-run-workflow
description: "ACE Paradigm 1: Build and run workflows on existing devices. Enforces Clarify → Design → Plan → Execute → Verify → Share."
user-invocable: false
---

# ACE Paradigm 1 — Run / Build Workflow

Build, compose, and execute workflows/nodes using existing device abstractions,
with ace-hub sharing and evolution闭环.

## Hard rule: do not build before Clarify is complete

**You MUST NOT call `Write`, `Edit`, `Bash` with mutating commands, or any CLI like
`ace workflow create` / `ace node create` until all Phase-1 Clarify gates below are
satisfied.** The ONLY tools allowed in Phase 1 are `AskUserQuestion`, `Read`, `Glob`,
`Grep`, `TodoWrite`, and read-only `Bash` (e.g. `ls`, `cat`, `ace workflow list`).
If you feel the urge to skip ahead, call `AskUserQuestion` instead.

## Phase 1 — Clarify (gather, don't build)

Use `AskUserQuestion` to collect exactly four answers, **one question per call**:

| Gate id     | Question                                                                       |
|-------------|--------------------------------------------------------------------------------|
| `task_type` | Build new workflow, build new node, run existing, or modify existing?         |
| `device`    | Which device? (must already exist in `~/.ace/store/devices/` or ace-hub)       |
| `goal`      | What should the workflow accomplish? (inputs, expected outputs, success criteria)|
| `params`    | Any special parameters, constraints, or execution preferences?                 |

Rules:
- Ask **one question at a time** via `AskUserQuestion`. Do not batch.
- After each answer, acknowledge briefly (one line) and immediately ask the next gate.
- If the human says "just do it" / "you decide" — still collect all four answers,
  but accept short ones. Do not skip any gate.
- You may use `Read` / `Glob` / `Grep` and read-only `Bash` to inspect existing
  resources **only when the human explicitly points you at something** in their answer.
- **Each gate MUST use `AskUserQuestion`** — do not infer answers from context or skip gates.

When all four gates are collected, summarise the answers back to the human in one
short message and explicitly ask for approval to move to Phase 2.

## Phase 2 — Design (brainstorming + spec)

Once Phase 1 is approved:

1. **Search existing resources**:
   ```bash
   ace hub list --type workflows
   ace workflow list
   ace node list --device <device-id>
   ```
2. **If "run workflow"** — show matching workflows, call `AskUserQuestion` to confirm choice.
   Pull from hub if needed: `ace hub pull <workflow-id> --type workflow`.
   If no match, switch to "build" mode.
3. **If "build workflow"** — propose **2 or 3** workflow topologies with node compositions.
   Call `AskUserQuestion` for the human to choose.
4. **If "build node"** — define input/output ports (JSON Schema), get approval.
5. **If "modify existing"** — show current workflow/node, identify what to change,
   call `AskUserQuestion` to confirm modification scope.

## Phase 3 — Plan (structured planning)

1. **Query existing memory** for the target workflow/device before planning:
   ```bash
   ls ~/.ace/store/workflows/<workflow-id>/memory/ 2>/dev/null
   ls ~/.ace/store/devices/<device-id>/memory/ 2>/dev/null
   ```
   If memory exists (e.g. `execution_history.json`, `best_params.json`,
   `common_failures.md`), read it and incorporate lessons into the plan.

2. **Write a task list** via `TodoWrite` enumerating concrete tasks for Phases 4–6.
   Typical breakdown:
   - Check node availability, build missing nodes (TDD)
   - Compose workflow definition
   - Execute workflow via CLI
   - Verify results
   - Evolution & sharing

3. **Present the plan** to the human via `AskUserQuestion` and **wait for explicit
   approval** before starting any execution work.

**Do NOT start Phase 4 until the human has approved the plan.**

## Phase 4 — Execute

**HITL gates — call `AskUserQuestion` before EACH of these CLI operations:**
- `ace node create` — ask: "Ready to build node. Proceed?"
- `ace workflow create` — ask: "Ready to create workflow. Proceed?"
- `ace workflow run` — ask: "Ready to run workflow. Proceed?"
- `ace hub push` — ask: "Ready to push to ace-hub. Proceed?"

Do NOT batch these into one confirmation. Each destructive CLI call gets its own
`AskUserQuestion` gate.

**If "run workflow" (existing):**
```bash
# MUST use CLI for reproducibility
ace workflow run <workflow-id> [--input '<json>']
```

**If "build node" (TDD REQUIRED):**
1. RED — write a failing test first.
2. GREEN — minimum code to pass.
3. REFACTOR — clean up, test stays green.

**If "build workflow":**
1. Build any missing nodes with TDD (see above).
2. Compose workflow: `ace workflow create --name <name> --device <device-id> --nodes '<node-list>'`
3. Execute: `ace workflow run <workflow-id>`

**If "modify existing":**
1. Read and show the current workflow/node definition to the human.
2. Apply modifications (TDD for node changes).
3. Re-run: `ace workflow run <workflow-id>` to verify.

### Critical Rule

> **Phase 4 "run workflow" MUST use CLI command `ace workflow run <id>` for reproducibility.**
> Never call workflow APIs directly in Python — always go through the CLI.

### Scope Boundary

Workflow building creates artifacts in `~/.ace/store/`:
- `nodes/<device-id>/<node_id>/` — node implementations
- `workflows/` — workflow definitions

Never modify ACE framework core. Work around limitations in your nodes/workflows.

### Efficiency

- Don't loop on `Bash` for debugging — read error messages and fix in one pass.
- Don't create excessive tasks. 5–10 `TodoWrite` items is ideal.
- Keep tool calls minimal: aim for < 100 total tool calls.

## Phase 5 — Verify (verification before completion)

1. Check execution results:
   ```bash
   ls ~/.ace/store/run/workflow/<workflow-id>/
   ```
2. **Show the workflow run output** to the human — paste the full stdout/stderr
   so they can see the result.
3. Validate workflow structure (if built): `ace workflow validate <workflow-id>`
4. Validate nodes (if built): `ace node info <node-id>`

Fix failures before marking Phase 5 complete.

## Phase 6 — Evolution & Sharing

**Before invoking ace-evolve**, write `CLAUDE_BENCHMARK_STATUS.md` in workspace root:
  - Workflow built/run, commands executed, how to reproduce, results summary.

**Then invoke `ace:ace-evolve`** for LLM-driven evolution闭环.

The `ace-evolve` skill will:
1. Gather context (traces, `CLAUDE_BENCHMARK_STATUS.md` Known Quirks, existing insights)
2. Analyze patterns with LLM (PCFL failures, CDSI breakthroughs)
3. Distill and promote insights (L1→L2→L3→L4)
4. Apply changes (update CLAUDE.md, create entity memories)
5. Share evolution artifacts to ace-hub (with HITL approval)

**After ace-evolve completes, push built artifacts to ace-hub:**

**HITL gate:** call `AskUserQuestion` before each `ace hub push`.

```bash
ace hub push <workflow-id> --type workflow --commit
ace hub push <node-id> --type node
```

## Memory Management

Memory is automatically synced between local store and ace-hub:

| Memory Type | Local Path | Hub Path | Sync Command |
|------------|------------|----------|--------------|
| Workflow Memory | `~/.ace/store/workflows/<id>/memory/` | `ace-hub/workflows/<id>/memory/` | `ace hub pull/push` |
| Node Memory | `~/.ace/store/nodes/<id>/memory/` | `ace-hub/nodes/<id>/memory/` | `ace hub pull/push` |
| Device Memory | `~/.ace/store/devices/<id>/memory/` | `ace-hub/devices/<id>/memory/` | `ace hub pull/push` |

**Memory folder contents:**
- `execution_history.json` - Past executions with params and results
- `best_params.json` - Optimized parameter combinations
- `common_failures.md` - Known issues and solutions
- `optimization_tips.md` - Performance recommendations

## Anti-Patterns — STOP Immediately

- Writing code before all 4 Clarify gates → STOP, go back to Phase 1
- Skipping `AskUserQuestion` for a gate → STOP, ask now
- Skipping `AskUserQuestion` before destructive CLI calls → STOP, ask first
- Running `Bash` exploratory commands during Phase 1 without the human's direction → STOP, ask first
- Starting execution before plan is approved → STOP, present plan first
- Calling workflow APIs in Python instead of `ace workflow run` → STOP, use CLI
- 100+ tool calls without completion → simplify approach

### TDD Red Flags — STOP and Delete

- Node code written before test → Delete and start over
- Test passes immediately → Fix test, must fail first
- "Node is too simple to test" → Test it anyway
- "I'll add tests after building workflow" → No. Test-first NOW
