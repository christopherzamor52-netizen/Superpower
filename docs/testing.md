# Testing Superpowers

Superpowers has two distinct kinds of tests, each in its own directory:

- **`tests/`** - does the plugin's non-LLM code work? Bash, node, python, and PowerShell tests for brainstorm-server JS, OpenCode plugin loading, codex-plugin sync, wrapper scripts, and analysis utilities.
- **`evals/`** - do agents behave correctly on real LLM sessions? Python harness driving real tmux sessions of Claude Code and Codex, with an LLM actor and verifier judging skill compliance.

## Plugin tests

Live in `tests/`. Currently:

- `tests/brainstorm-server/` - node test suite for the brainstorm server JS code.
- `tests/opencode/` - bash tests for OpenCode plugin loading, bootstrap caching, and tool registration.
- `tests/codex-plugin-sync/` - bash sync verification.
- `tests/kimi/` - bash/Python checks for Kimi plugin manifest wiring.
- `tests/claude-code/test-helpers.sh`, `analyze-token-usage.py` - utilities used by remaining bash tests.
- `tests/claude-code/test-subagent-driven-development.sh` - agent-can-describe-SDD test (no drill counterpart; tests description-recall, not behavior).
- `tests/claude-code/test-subagent-driven-development-integration.sh` - extended SDD integration with token analysis (drill covers the YAGNI subset; bash adds commit-count, Claude Code task-tracking, and token telemetry assertions).
- `tests/claude-code/test-worktree-native-preference.sh` - RED-GREEN-REFACTOR validation for worktree skill (drill covers the PRESSURE phase; bash also covers RED/GREEN baselines).
- `tests/explicit-skill-requests/` - Haiku-specific, multi-turn, and skill-name-prompted tests not covered by drill.
- `tests/phase1-orchestration.test.ps1` - task metadata, deterministic routing, and write-scope validation checks.
- `tests/external-model-orchestration.test.ps1` - cross-model review and external worker wrapper checks with mock providers.

Run plugin tests via the relevant directory's `run-*.sh`, `npm test`, or the
PowerShell script directly when the test is a `.ps1`.

## Skill behavior evals

Live in `evals/`. Drill is the harness; scenarios live at `evals/scenarios/*.yaml`. See `evals/README.md` for setup. Quick start:

```bash
cd evals
uv sync --extra dev
export ANTHROPIC_API_KEY=sk-...
uv run drill run triggering-test-driven-development -b claude
```

Drill scenarios are slow (3-30+ minutes each) and run real LLM sessions. They are not part of CI today; the natural follow-up is a tiered model (fast subset on PR, full sweep nightly + on-demand).
