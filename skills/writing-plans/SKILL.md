---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

## Overview

Write implementation plans as precise **contracts, not transcribed code**. Each task specifies *what* to build — exact interfaces, the behavior it must satisfy, the test scenarios to cover, and acceptance criteria — and leaves *how* to implement it to the engineer, who designs the code via real TDD. Document which files to touch, the interfaces each task consumes and produces, the behavior contract, and how to verify it. Give them the whole plan as bite-sized tasks. DRY. YAGNI. TDD. Frequent commits.

Assume the engineer is a capable developer who reasons about implementation, but knows almost nothing about our toolset or problem domain and has NOT seen the rest of the plan. That is why interfaces and constraints must be exact: they are the only channel between isolated tasks. The implementation itself is theirs to write.

Assume they don't have strong test-design instincts — that is why you enumerate the test scenarios explicitly. They decide *how* to write the tests and the code; you decide *which behaviors and cases matter*.

**Contract, not code:** Do NOT paste the finished implementation into the plan. Specify the contract precisely enough that any competent engineer would satisfy it, then let them implement. Include real code ONLY in a task's *Implementation notes*, and only where ambiguity would be costly — a specific algorithm, an exact wire format, a non-obvious data shape. Everywhere else, the "how" is the engineer's to decide, bounded by the acceptance criteria and the review.

**Announce at start:** "I'm using the writing-plans skill to create the implementation plan."

**Context:** If working in an isolated worktree, it should have been created via the `superpowers:using-git-worktrees` skill at execution time.

**Save plans to:** `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`
- (User preferences for plan location override this default)

## Commits (suggest, never commit)

Plans favor frequent, well-scoped commits — but the agent NEVER runs `git commit`. Every commit step stages the work and presents a suggested commit command for your human partner to run. Write commit steps this way throughout the plan.

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

## Bite-Sized Task Granularity

**Each step is one action (2-5 minutes):**
- "Write the failing test" - step
- "Run it to make sure it fails" - step
- "Implement the minimal code to make the test pass" - step
- "Run the tests and make sure they pass" - step
- "Stage the change and suggest a commit" - step

## Plan Document Header

**Every plan MUST start with this header:**

```markdown
# [Feature Name] Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Execution model — CONTRACT, NOT CODE:** Each task gives you a precise contract (exact interfaces, behavior, test scenarios, acceptance criteria) — not the implementation. You design and write the code via real TDD. What is fixed: file paths, the public signatures in each task's **Interfaces** block, and the Global Constraints. What is yours: how you implement it. Full code appears only in **Implementation notes**, and only where ambiguity would be costly.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

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

**Interfaces:** (the hard contract — keep EXACT; this is the only channel between isolated tasks)
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function/class names, parameter
  and return types. A task's implementer sees only their own task; this block
  is how they learn the names and types neighboring tasks use.]

**Behavior contract:**
- [What the unit must do, as inputs → outputs and side effects. Cover the happy
  path plus edges and error behavior — e.g. "empty input → returns []",
  "invalid X → raises ValueError naming X". This is exact about behavior and
  silent about implementation. It replaces dictated code.]

**Test scenarios:** (the engineer writes these as tests, TDD — you name the cases, they write the code)
- Given [input], when [action], then [expected outcome]
- Edge: [edge case → expected]
- Error: [invalid case → raised error / handling]

**Acceptance criteria:**
- All scenarios above covered by tests and green
- Public signatures match the **Interfaces** block exactly
- [Any task-specific constraint checks]

**Implementation notes:** (OPTIONAL — include only where ambiguity would be costly)
- [A specific algorithm, exact wire format, or non-obvious data shape. Paste
  code here ONLY when getting it wrong is likely and expensive. Otherwise leave
  this out — the implementation is the engineer's to design.]

- [ ] **Step 1: Write the failing test(s)** covering the Test scenarios above

- [ ] **Step 2: Run the tests to verify they fail**

Run: `pytest tests/path/test.py -v`
Expected: FAIL for the right reason (e.g. "function not defined")

- [ ] **Step 3: Implement to satisfy the contract**

Design and write the implementation yourself so the tests pass and the Behavior
contract holds. Match the **Interfaces** signatures exactly.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `pytest tests/path/test.py -v`
Expected: PASS. Refactor if needed, keeping tests green.

- [ ] **Step 5: Stage the change and suggest a commit**

Stage the files, then present the suggested commit for your human partner to run — do NOT run `git commit` yourself:

```bash
git add tests/path/test.py src/path/file.py
# Suggested commit (your human partner runs this):
#   git commit -m "feat: add specific feature"
```
````

## Precise Contracts, Free Implementation

Vagueness is still banned — but at the **contract** level, not by pasting the implementation. Every task must pin down interfaces, behavior, test scenarios, and acceptance criteria precisely. These are **plan failures** — never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases" — instead, name the exact behavior as a scenario: "invalid X → raises ValueError naming X"
- "Write tests for the above" without listing the scenarios — enumerate the cases (happy path, edges, errors)
- A behavior contract that could be read two ways — pick one and state it
- References to types, functions, or methods not defined in any task's **Interfaces**
- Approximate signatures ("returns the parsed data") instead of exact ones (`parse(raw: str) -> list[str]`)

What is deliberately NOT required (and should usually be absent):

- Finished implementation code in the steps — the engineer designs it via TDD
- "Similar to Task N (repeat the code)" — there is no code to repeat; exact **Interfaces** blocks remove the need

Include real code ONLY in a task's **Implementation notes**, and only where ambiguity would be costly — a specific algorithm, an exact wire format, a non-obvious data shape. The test: *would a competent engineer plausibly get this wrong or diverge in a way that breaks a neighboring task?* If yes, pin it. If no, leave the implementation to them.

## Remember
- Exact file paths always
- Exact interface signatures always — they are the contract between isolated tasks
- Behavior contract + test scenarios in every task, not implementation code
- Real code only in Implementation notes, only where ambiguity is costly
- Exact commands with expected output
- DRY, YAGNI, TDD, frequent commits (agent stages and suggests; your human partner makes the commits)

## Self-Review

After writing the complete plan, look at the spec with fresh eyes and check the plan against it. This is a checklist you run yourself — not a subagent dispatch.

**1. Spec coverage:** Skim each section/requirement in the spec. Can you point to a task that implements it? List any gaps.

**2. Contract completeness:** Does every task carry a Behavior contract, Test scenarios, and Acceptance criteria? Do the scenarios cover the happy path plus edges and errors? Scan for the red flags in "Precise Contracts, Free Implementation" above — vague behavior, approximate signatures, "handle edge cases", or finished implementation code where a contract belongs. Fix them.

**3. Interface consistency:** Do the signatures a later task Consumes match what an earlier task Produces? Names, parameter types, and return types must line up exactly. A function called `clearLayers()` in Task 3 but `clearFullLayers()` in Task 7 is a bug. Every type or symbol a task references must be Produced by some task's Interfaces block.

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
