---
name: external-model-workers
description: Use Claude CLI or Gemini CLI as opt-in external implementers or task reviewers in isolated worktrees with write-scope enforcement and local verification.
---

# External Model Workers

Use this skill when you want to delegate a task to an external model CLI
while keeping orchestration, git safety, and final verification in the
controller.

This is an opt-in execution path. It does not replace
`subagent-driven-development`; it is a worker backend you can use when a
task is a good fit for an external model.

## Workflow

1. Choose the task:
   - Delegate only tasks with a clear brief and explicit write scope.
   - Keep high-risk tasks sequential unless your human partner has asked
     for external worker mode anyway.
2. Create isolated worktrees:
   - Use one worktree per delegated task.
   - Do not share a writable checkout across multiple active external workers.
3. Send role-specific prompts:
   - `implementer`
   - `spec-reviewer`
   - `code-quality-reviewer`
4. Require strict output:
   - Status line
   - Tests run
   - Files changed
   - Report path
5. Inspect diffs after the worker returns.
6. Run tests locally.
7. Enforce write scope with the task metadata validator.
8. Merge only after verification.

## Guardrails

- External workers are optional and explicit.
- Controllers keep responsibility for routing, diff inspection, and merge.
- Workers must stay inside declared write scope.
- If write scope is violated, pause and review before continuing.
- If the provider CLI is unavailable, fall back to native subagents or
  same-session work.
- Gemini can be used if a working `gemini` executable is installed, even
  though Superpowers no longer ships Gemini as a native harness integration.

## Wrapper

```powershell
.\skills\external-model-workers\scripts\run-worker-with-model.ps1 `
  -Provider claude `
  -Role implementer `
  -TaskBriefPath .superpowers\sdd\task-2-brief.md `
  -RepoRoot . `
  -WorktreePath C:\worktrees\feature-task-2 `
  -WriteScope src\feature.ts,tests\feature.test.ts `
  -ReportFile .superpowers\sdd\task-2-report.md
```

## Worker Roles

`implementer`
- Builds the task in its isolated worktree
- Runs the requested tests
- Writes a detailed report

`spec-reviewer`
- Reads the task brief and diff
- Checks requested behavior only

`code-quality-reviewer`
- Reads the task brief and diff
- Checks correctness, tests, maintainability, and safety
