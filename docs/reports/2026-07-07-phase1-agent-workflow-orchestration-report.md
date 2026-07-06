# Phase 1 Agent Workflow Orchestration Report

Date: 2026-07-07

## Scope completed

Phase 1 is implemented for the Superpowers workflow changes described in
`docs/superpowers/specs/2026-07-06-agent-workflow-orchestration-design.md`.

Included:

- task metadata in implementation plans
- dependency validation rules
- write-scope enforcement rules
- deterministic sequential versus parallel routing
- read-only Claude/Gemini review wrappers
- isolated-worktree Claude/Gemini worker wrappers
- controller-backed external task orchestration with validation, local
  verification, commit, and merge-back

Excluded by design:

- native internal Claude/Gemini worker orchestration
- replacing subagent-driven-development with Claude/Gemini workers

Claude and Gemini remain external reviewers or external worker CLIs only.

## Exact file changes

### Plan and routing rules

- `skills/writing-plans/SKILL.md`
  - requires `task_metadata` blocks in implementation plans
  - requires `id`, `depends_on`, `write_scope`, `risk_level`,
    `review_required`, and `external_review`
  - prohibits hand-authored parallel eligibility
- `skills/subagent-driven-development/SKILL.md`
  - adds controller rules for dependency validation, write-scope
    enforcement, and external-review boundaries
- `skills/dispatching-parallel-agents/SKILL.md`
  - adds deterministic routing rules derived from task metadata

### Validation and controller scripts

- `skills/subagent-driven-development/scripts/validate-plan-metadata.ps1`
  - validates task metadata shape
  - rejects missing dependencies and dependency cycles
  - rejects overlapping parallel write scopes
  - rejects out-of-scope changed files for an active task
  - computes sequential versus parallel routing from metadata
- `skills/cross-model-review/scripts/review-with-model.ps1`
  - wraps Claude or Gemini for read-only spec, plan, diff, and release review
- `skills/external-model-workers/scripts/run-worker-with-model.ps1`
  - wraps Claude or Gemini for implementer, spec-reviewer, and
    code-quality-reviewer roles inside an isolated worktree
- `skills/external-model-workers/scripts/orchestrate-external-task.ps1`
  - creates the worktree
  - dispatches the external worker
  - validates changed files against `write_scope`
  - runs the local verification command
  - commits successful changes
  - fast-forward merges the task branch back into the repo branch

### New and updated skills

- `skills/cross-model-review/SKILL.md`
  - adds read-only Claude/Gemini review workflow guidance
- `skills/cross-model-review/references/prompts.md`
  - stores prompt guidance for review modes
- `skills/external-model-workers/SKILL.md`
  - documents the low-level worker wrapper
  - documents the controller wrapper for end-to-end task execution
- `skills/using-superpowers/references/gemini-tools.md`
  - restores Gemini bootstrap documentation used by `GEMINI.md`

### Tests and documentation

- `tests/phase1-orchestration.test.ps1`
  - verifies task metadata requirements and validator behavior
- `tests/external-model-orchestration.test.ps1`
  - verifies wrapper scripts exist
  - verifies prompt contracts
  - verifies the controller script can create a worktree, validate scope,
    verify output, commit, and merge in a temp repo
- `README.md`
  - documents the new external review and worker orchestration path
- `docs/testing.md`
  - documents the new PowerShell orchestration tests

## Verification evidence

The following commands were run against the current branch and completed
successfully:

### Repository tests

```powershell
& tests/phase1-orchestration.test.ps1
& tests/external-model-orchestration.test.ps1
```

Observed results:

- `Phase 1 orchestration checks passed.`
- `External model orchestration checks passed.`

### Live Claude and Gemini review smoke tests

```powershell
.\skills\cross-model-review\scripts\review-with-model.ps1 `
  -Provider claude `
  -Mode release `
  -InputPath $env:TEMP\superpowers-phase1-release-summary.md `
  -RepoRoot .

.\skills\cross-model-review\scripts\review-with-model.ps1 `
  -Provider gemini `
  -Mode release `
  -InputPath $env:TEMP\superpowers-phase1-release-summary.md `
  -RepoRoot .
```

Observed results:

- Gemini returned a release review with `Blockers`, `Warnings`, and
  `Recommended Follow-Up`.
- Claude returned a release review response under the wrapper entrypoint.

### Live Claude external worker orchestration smoke test

A temp git repo was created with one tracked file, `app.txt`, containing
`hello`.

Command shape:

```powershell
.\skills\external-model-workers\scripts\orchestrate-external-task.ps1 `
  -Provider claude `
  -PlanPath <temp-plan> `
  -TaskId task-1 `
  -TaskBriefPath <temp-brief> `
  -RepoRoot <temp-repo> `
  -VerificationCommand "Get-Content -Raw app.txt" `
  -CommitMessage "test: live claude orchestration"
```

Observed results:

- changed files: `app.txt`
- verification output: `hello world`
- resulting git log included `test: live claude orchestration`

### Live Gemini external worker orchestration smoke test

The same temp-repo scenario was run with Gemini.

Command shape:

```powershell
.\skills\external-model-workers\scripts\orchestrate-external-task.ps1 `
  -Provider gemini `
  -PlanPath <temp-plan> `
  -TaskId task-1 `
  -TaskBriefPath <temp-brief> `
  -RepoRoot <temp-repo> `
  -VerificationCommand "Get-Content -Raw app.txt" `
  -CommitMessage "test: live gemini orchestration"
```

Observed results:

- changed files: `app.txt`
- verification output: `hello world`
- resulting git log included `test: live gemini orchestration`

## Usage examples

### 1. Validate task metadata and routing

```powershell
.\skills\subagent-driven-development\scripts\validate-plan-metadata.ps1 `
  -PlanPath .superpowers\plans\feature-plan.md `
  -Json
```

### 2. Ask Claude for a read-only plan review

```powershell
.\skills\cross-model-review\scripts\review-with-model.ps1 `
  -Provider claude `
  -Mode plan `
  -InputPath .superpowers\plans\feature-plan.md `
  -RepoRoot .
```

### 3. Ask Gemini for a read-only diff review

```powershell
.\skills\cross-model-review\scripts\review-with-model.ps1 `
  -Provider gemini `
  -Mode diff `
  -RepoRoot .
```

### 4. Dispatch a low-level external implementer

Use this only when a controller already created the worktree and selected
the role.

```powershell
.\skills\external-model-workers\scripts\run-worker-with-model.ps1 `
  -Provider claude `
  -Role implementer `
  -TaskBriefPath .superpowers\sdd\task-2-brief.md `
  -RepoRoot . `
  -WorktreePath C:\worktrees\feature-task-2 `
  -WriteScope src\feature.ts,tests\feature.test.ts `
  -ReportFile .superpowers\sdd\task-2-report.md `
  -FocusedTestCommand "npm test -- feature"
```

### 5. Run the full controller-backed external task flow

```powershell
.\skills\external-model-workers\scripts\orchestrate-external-task.ps1 `
  -Provider gemini `
  -PlanPath .superpowers\plans\feature-plan.md `
  -TaskId task-2 `
  -TaskBriefPath .superpowers\sdd\task-2-brief.md `
  -RepoRoot . `
  -VerificationCommand "npm test -- feature" `
  -CommitMessage "task(task-2): implement feature"
```

## Git state

This work was pushed to branch:

- `codex/phase-1-agent-workflow-orchestration`

