---
name: cross-model-review
description: Use Claude CLI or Gemini CLI as an independent reviewer for specs, plans, diffs, and release-readiness checks while keeping code changes in the controller's hands.
---

# Cross-Model Review

Use this skill when you want a second-model critique without giving that
model write access to the repo.

## Workflow

1. Identify the review target:
   - Use the user-supplied file path for `spec`, `plan`, or `release`.
   - Use the current git diff for `diff` review when no file is supplied.
   - Prefer one precise artifact over broad repository context.
2. Select provider:
   - Use `claude` when the user asks for Claude.
   - Use `gemini` when the user asks for Gemini.
   - If unspecified, prefer Claude for prose/spec review and Gemini for
     plan/diff sanity checks when both are installed.
3. Select mode:
   - `spec`: requirements, contradictions, acceptance criteria, edge cases,
     implementation risks, testability.
   - `plan`: sequencing, dependencies, missing tests, vague steps,
     compatibility or migration gaps.
   - `diff`: bugs, regressions, data loss, race conditions,
     security/privacy issues, test gaps.
   - `release`: readiness, verification, docs, rollback, remaining risk.
4. Run `scripts/review-with-model.ps1`.
5. Summarize the external output as findings-first feedback.

## Guardrails

- Treat Claude/Gemini as reviewers, not authorities.
- Do not let external models edit files or execute project mutations.
- Do not pass secrets, `.env` files, token files, private keys,
  recordings, databases, or unrelated folders.
- Validate every external finding against the repo or spec before applying it.
- If the user asks for implementation, Codex still makes the edits and runs
  the verification.

## Wrapper

```powershell
.\skills\cross-model-review\scripts\review-with-model.ps1 `
  -Provider claude `
  -Mode spec `
  -InputPath docs\superpowers\specs\example.md `
  -RepoRoot .
```

For current diff review:

```powershell
.\skills\cross-model-review\scripts\review-with-model.ps1 `
  -Provider gemini `
  -Mode diff `
  -RepoRoot .
```

## Output Handling

Return a concise synthesis:

- Findings ordered by severity
- Open questions that block implementation
- Suggested spec, plan, or code changes
- Explicitly say when the external review found no major issues

Do not paste long raw transcripts unless your human partner asks for them.
