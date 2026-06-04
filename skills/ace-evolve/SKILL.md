---
name: ace-evolve
description: "LLM-driven evolution闭环 — gather multi-source context, analyze traces + known quirks, distill insights through L1→L4, update CLAUDE.md and entity memories"
user-invocable: false
---

# ACE Evolution — LLM-Driven Learning Loop

Transform execution traces, known quirks, and development context into lasting
knowledge through the 4-level insight hierarchy.

## When to Use

- After completing a P1 workflow run (Phase 6 of `ace-run-workflow`)
- After completing a P2 device onboarding (Phase 6 of `ace-device-onboarding`)
- After completing a P3 development cycle (Phase 6 of `ace-development`)
- Periodically to consolidate accumulated traces into insights
- When `CLAUDE_BENCHMARK_STATUS.md` contains Known Quirks worth preserving

## What This Skill Does (vs. `ace evolve` CLI)

The `ace evolve run` CLI command runs the mechanical engine: pattern extraction,
scoring, decay. This **skill** wraps that engine with LLM-driven context analysis:

| Layer | CLI (`ace evolve run`) | Skill (`ace-evolve`) |
|-------|----------------------|----------------------|
| Trace analysis | Regex pattern extraction | LLM reads traces, understands intent |
| Known Quirks | Not handled | Reads `CLAUDE_BENCHMARK_STATUS.md`, extracts negative knowledge |
| Context | Blind | Reads recent git log, CLAUDE.md, existing insights |
| Distillation | Rule-based scoring | LLM proposes principle updates to CLAUDE.md |
| Contradictions | String matching | LLM resolves conflicting insights with reasoning |
| Memory | Mechanical sync | LLM associates insights to correct entities |

## 4-Level Insight Hierarchy

```
L4: Memory        ← Cross-session universal lessons
L3: CLAUDE.md     ← Project-level engineering principles
L2: Insight       ← Pattern-detected, fitness-scored entries (~/.ace/insights/)
L1: Traces        ← Raw execution data, immutable (~/.ace/traces/)
```

Flow: L1 → L2 → L3 → L4 (each phase of this skill promotes one level)

## Checklist

You MUST create a task for each phase and complete them in order:

1. **Phase 1: Gather Context** — collect traces, quirks, existing insights, recent changes
2. **Phase 2: Analyze** — LLM-driven pattern extraction from all sources
3. **Phase 3: Distill & Promote** — promote insights through L1→L2→L3→L4
4. **Phase 4: Apply** — update CLAUDE.md, create entity memories, propose mutations
5. **Phase 5: Share** — push evolved knowledge to ace-hub

## Phase 1: Gather Context

Collect inputs from multiple sources. Do NOT skip any source — even if empty,
confirm it was checked.

### 1.1 Execution Traces

```bash
# Run the mechanical engine first to get baseline stats
ace evolve status

# Check recent traces
ls -la ~/.ace/traces/
```

Read the most recent trace files. Focus on:
- Failed executions (PCFL candidates)
- Unexpectedly successful runs (CDSI candidates)
- Repeated patterns across multiple runs

### 1.2 Known Quirks

```bash
# Check for benchmark status files in workspace
find . -name "CLAUDE_BENCHMARK_STATUS.md" -o -name "*BENCHMARK*STATUS*" 2>/dev/null
```

If found, read the **Known Quirks** section. Each quirk is a candidate for
negative knowledge (what NOT to do, or framework bugs to work around).

### 1.3 Existing Knowledge

```bash
# Current insights
ace insight list

# Current CLAUDE.md principles
cat CLAUDE.md
```

### 1.4 Recent Changes

```bash
# Recent development activity
git log --oneline -20

# What changed recently
git diff --stat HEAD~5
```

### 1.5 Context Summary

After gathering, summarize what you found in one short paragraph:
- How many traces (and their timespan)
- How many known quirks
- How many existing insights
- Key themes from recent changes

## Phase 2: Analyze (LLM-Driven)

Use LLM reasoning to extract patterns from the gathered context.

### 2.1 Failure Analysis (PCFL)

For each failed trace or known quirk, extract:
- **Problem**: What went wrong?
- **Cause**: Root cause (not symptoms)
- **Fix**: How was it / should it be resolved?
- **Lesson**: Generalizable takeaway for future sessions

### 2.2 Breakthrough Analysis (CDSI)

For each unexpectedly successful execution:
- **Challenge**: What was being attempted?
- **Detours**: What didn't work first?
- **Solution**: What actually worked?
- **Insight**: Why did this approach succeed?

### 2.3 Contradiction Detection

Compare new patterns against existing insights:
- Do any new findings contradict existing L2 insights?
- Are there duplicate insights that should be merged?
- Have any existing insights been invalidated by recent evidence?

### 2.4 Analysis Output

For each extracted pattern, record:
- **Source**: Which trace / quirk / change produced this
- **Type**: `failure_pattern` | `parameter_guideline` | `workflow_template` | `anomaly`
- **Polarity**: `positive` (do this) | `negative` (don't do this)
- **Confidence**: 0.0–1.0 based on evidence strength
- **Entity**: Which device/workflow/node this relates to (if any)

## Phase 3: Distill & Promote

### 3.1 Run the Mechanical Engine

```bash
ace evolve run
```

This handles the baseline: pattern scoring, decay, promotion/demotion.

### 3.2 L1 → L2: Create Insight Entries

For each high-confidence pattern from Phase 2 that the engine didn't catch:

```bash
# Import as insight
ace insight import <insight-file.json>
```

Or create directly if CLI supports it.

### 3.3 L2 → L3: Principle Distillation

Review existing CLAUDE.md principles against the new insights:
- Should any new principle be added?
- Should any existing principle be strengthened with new evidence?
- Should any principle be removed (contradicted by evidence)?

**Rule: Max 10 principles in CLAUDE.md.** If adding one, consider removing the
weakest. Principles must be earned through repeated evidence, not added lightly.

### 3.4 L3 → L4: Memory Sync

For entity-associated patterns, create or update memories:

```bash
# Memories are stored in ~/.ace/store/{devices,workflows,nodes}/{id}/memory/
ls ~/.ace/store/devices/*/memory/ 2>/dev/null
ls ~/.ace/store/workflows/*/memory/ 2>/dev/null
```

Create memory entries for:
- Best parameters discovered
- Common failure modes
- Optimization tips
- Known quirks (from CLAUDE_BENCHMARK_STATUS.md)

## Phase 4: Apply

### 4.1 Update CLAUDE.md

If Phase 3.3 identified principle changes, apply them:
- Add new principles with evidence citations
- Update existing principles with strengthened evidence
- Remove invalidated principles

**HITL gate: Show the proposed CLAUDE.md diff to the user before applying.**

### 4.2 Create Entity Memories

Write memory JSON files to the appropriate entity directories:

```
~/.ace/store/{entity_type}/{entity_id}/memory/
├── common_failures.md     ← from PCFL analysis
├── optimization_tips.md   ← from CDSI analysis
├── best_params.json       ← from parameter patterns
└── known_quirks.md        ← from CLAUDE_BENCHMARK_STATUS.md
```

### 4.3 Propose Mutations

If patterns suggest workflow/node improvements:
- Describe the proposed change
- Show evidence (which traces support it)
- Let the user decide whether to apply

## Phase 5: Share

### 5.1 Push to ace-hub

```bash
# Push updated memories
ace hub push <entity-id> --type <entity-type>
```

**HITL gate: Ask before each `ace hub push`.**

### 5.2 Evolution Report

Present a summary to the user:
- Patterns extracted (count by type)
- Insights created / updated
- CLAUDE.md changes (if any)
- Memories created
- Mutations proposed

## Anti-Patterns — STOP Immediately

- Skipping Phase 1 context gathering → STOP, gather first
- Creating insights without evidence → STOP, show the trace/quirk source
- Modifying CLAUDE.md without user approval → STOP, show diff first
- Adding > 10 principles to CLAUDE.md → STOP, prioritize and prune
- Pushing to ace-hub without asking → STOP, HITL gate required
- Running only `ace evolve run` and calling it done → STOP, that's just the engine, not the skill

## Canonical Statements

- "Gathering evolution context from traces, quirks, and recent changes..."
- "Analyzing patterns with LLM: extracting PCFL failures and CDSI breakthroughs..."
- "Running mechanical engine baseline: ace evolve run..."
- "Distilling insights: L1 traces → L2 insights → L3 principles..."
- "Proposing CLAUDE.md update — here's the diff for your review..."
- "Creating entity memories for {device/workflow/node}..."
- "Evolution cycle complete. Summary: {N} patterns, {M} insights, {K} memories."
