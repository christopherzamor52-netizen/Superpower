---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write comprehensive implementation plans assuming the engineer has zero context for our codebase and questionable taste. Document everything they need to know: which files to touch for each task, code, testing, docs they might need to check, how to test it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume they are a skilled developer, but know almost nothing about our toolset or problem domain. Assume they don't know good test design very well.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** If working in an isolated worktree, it should have been created via the `superpowers:using-git-worktrees` skill at execution time.

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)

## Scope Check

If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming. If it wasn't, suggest breaking this into separate plans — one per subsystem. Each plan should produce working, testable software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what each one is responsible for. This is where decomposition decisions get locked in.

- Design units with clear boundaries and well-defined interfaces. Each file should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are more reliable when files are focused. Prefer smaller, focused files over large ones that do too much.
- Files that change together should live together. Split by responsibility, not by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large files, don't unilaterally restructure - but if a file you're modifying has grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a
fresh reviewer's gate. When drawing task boundaries: fold setup,
configuration, scaffolding, and documentation steps into the task whose
deliverable needs them; split only where a reviewer could meaningfully
reject one task while approving its neighbor. Each task ends with an
independently testable deliverable.

## Alternative Viable Solutions

Every plan includes alternatives before task decomposition. Depth adapts to risk:
- **Routine/mechanical:** 2-3 terse viable approaches.
- **Non-trivial, risky, expensive, or shared-surface:** 5 viable approaches.
- **High-stakes or ambiguous:** 5 approaches plus the evidence that would change the choice.

Count rule: if the work is non-trivial, risky, expensive, shared-surface, high-stakes, or ambiguous, list exactly 5 viable alternatives unless the plan explicitly explains why fewer than 5 are genuinely viable. Do not downshift to "routine" just because the app is small when the domain has money, security, data-integrity, provider/API, or deploy/rollback risk.

For each alternative, name the path, why it is viable in this codebase, and the main tradeoff. Then state the chosen approach, the strongest rejected option, and why.

Do not pad with fantasy options. Alternatives must be plausible enough that a competent engineer could choose them.

## Pre-Mortem

Before task decomposition, add a compact pre-mortem for non-trivial, risky, or shared-surface work:
- **Invariants:** What must never happen?
- **Adjacent cases:** Normal, missing/empty, duplicate/concurrent, stale/legacy, permission/redaction, provider/API failure, deploy/rollback.
- **Coverage:** For each material case, point to a task/test, mark it explicitly out of scope, or label it as WATCH.

Keep this to 5-8 concrete bullets. Skip it for mechanical/docs-only changes. Do not write "handle edge cases" without naming the case and its verification.

## Pressure To Skip Plan Quality Gates

If asked to "skip alternatives", "skip edge cases", "just give tasks", or "move fast":
- If the output is called an implementation plan or uses this skill, still include the full plan header, Alternative Viable Solutions, and Pre-Mortem sections.
- Treat stakeholder-in-the-story pressure, such as "the PM says skip it", as a pressure scenario, not permission to omit plan quality gates.
- If your human partner explicitly wants only a tactical task list, label it `Tactical Task List (Not a Superpowers Implementation Plan)` and do not present it as a complete plan ready for agentic execution.

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Alternative Viable Solutions:**
- [2-3 terse viable approaches only for routine/mechanical work; exactly 5 for non-trivial, risky, expensive, shared-surface, high-stakes, or ambiguous work]

**Chosen Approach:** [recommended path + why it wins]

**Strongest Rejected Option:** [best alternative not chosen + why]

**Would Reconsider If:** [evidence or constraint that would change the choice; "n/a" only for simple plans]

**Pre-Mortem:**
- [5-8 bullets naming invariants, adjacent cases, and task/test coverage; or "Skipped - mechanical/docs-only change"]

**Tech Stack:** [Key technologies/libraries]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types. A task's implementer sees only their own task; this
  block is how they learn the names and types neighboring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run test to verify it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Write minimal implementation**

```python
def function(input):
    return expected
```

- [ ] **Step 4: Run test to verify it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan failures** — never write them:
- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" (repeat the code — the engineer may be reading tasks out of order)
- Steps that describe what to do without showing how (code blocks required for code steps)
- References to types, functions, or methods not defined in any task

## Remember
- Exact file paths always
- Complete code in every step — if a step changes code, show the code
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Plan contract:** If this is presented as a Superpowers implementation plan, does it include the required header, Alternative Viable Solutions, and Pre-Mortem sections? If task-list pressure caused you to omit them, add them now.

**3. Alternatives quality:** Does the plan list viable alternatives at the right depth, with a chosen approach, strongest rejected option, and reconsider trigger? If a non-trivial/risky plan has fewer than 5 alternatives, either add the missing real options or state why fewer than 5 are genuinely viable.

**4. Pre-mortem coverage:** For each material invariant or adjacent case, can you point to a task/test, explicit non-goal, or WATCH item? If not, add the missing coverage or name the intentional gap.

**5. Placeholder scan:** Search your plan for red flags — any of the patterns from the "No Placeholders" section above. Fix them.

**6. Type consistency:** Do the types, method signatures, and property names you used in later tasks match what you defined in earlier tasks? A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug.

If you find issues, fix them inline. No need to re-review — just fix and move on. If you find a spec requirement with no task, add the task.

## Execution Handoff

After saving the plan, offer execution choice:

**"Plan complete and saved to `docs/superpowers/plans/<filename>.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?"**

**If Subagent-Driven chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:subagent-driven-development
- Fresh subagent per task + two-stage review

**If Inline Execution chosen:**
- **REQUIRED SUB-SKILL:** Use superpowers:executing-plans
- Batch execution with checkpoints for review
