#!/usr/bin/env bash
# Tests for the SDD workspace: scripts/sdd-workspace resolves a self-ignoring
# working-tree directory for SDD artifacts, and the SDD scripts write into it.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SDD_SCRIPTS="$REPO_ROOT/skills/subagent-driven-development/scripts"

FAILURES=0
TEST_ROOT=""

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

cleanup() {
    if [[ -n "$TEST_ROOT" && -d "$TEST_ROOT" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

without_sdd_session() {
    unset CLAUDE_CODE_SESSION_ID
    unset SUPERPOWERS_SDD_SESSION
    "$@"
}

main() {
    echo "=== Test: sdd-workspace ==="

    TEST_ROOT="$(mktemp -d)"
    trap cleanup EXIT

    # Resolve repo to its physical path so string comparisons match the
    # helper's output (git rev-parse --show-toplevel resolves symlinks; on
    # macOS mktemp lives under /var -> /private/var).
    git init -q -b main "$TEST_ROOT/repo"
    local repo
    repo="$(cd "$TEST_ROOT/repo" && git rev-parse --show-toplevel)"

    local dir
    dir="$(cd "$repo" && without_sdd_session "$SDD_SCRIPTS/sdd-workspace")"

    if [[ "$dir" == "$repo/.superpowers/sdd" ]]; then
        pass "prints <repo-root>/.superpowers/sdd"
    else
        fail "prints <repo-root>/.superpowers/sdd"
        echo "    got: $dir"
    fi

    if [[ -f "$repo/.superpowers/sdd/.gitignore" && "$(cat "$repo/.superpowers/sdd/.gitignore")" == "*" ]]; then
        pass "self-ignoring .gitignore created with '*'"
    else
        fail "self-ignoring .gitignore created with '*'"
    fi

    local empty_dir
    empty_dir="$(cd "$repo" && CLAUDE_CODE_SESSION_ID= SUPERPOWERS_SDD_SESSION= "$SDD_SCRIPTS/sdd-workspace")"
    if [[ "$empty_dir" == "$repo/.superpowers/sdd" ]]; then
        pass "empty session vars fall back to the unscoped workspace"
    else
        fail "empty session vars fall back to the unscoped workspace"
        echo "    got: $empty_dir"
    fi

    printf 'x\n' > "$repo/.superpowers/sdd/artifact.md"
    local status
    status="$(cd "$repo" && git status --porcelain)"
    if [[ -z "$status" ]]; then
        pass "workspace invisible to git status"
    else
        fail "workspace invisible to git status"
        echo "    status: $status"
    fi

    ( cd "$repo" && git add -A )
    local staged
    staged="$(cd "$repo" && git diff --cached --name-only)"
    if [[ -z "$staged" ]]; then
        pass "git add -A does not stage the workspace"
    else
        fail "git add -A does not stage the workspace"
        echo "    staged: $staged"
    fi

    cat > "$repo/plan.md" <<'PLAN'
# Plan

## Task 1: First thing

Do the first thing.
PLAN

    local brief_out brief_path
    brief_out="$(cd "$repo" && without_sdd_session "$SDD_SCRIPTS/task-brief" plan.md 1)"
    brief_path="$(printf '%s\n' "$brief_out" | sed -n 's/^wrote \(.*\): [0-9][0-9]* lines$/\1/p')"
    case "$brief_path" in
        "$repo/.superpowers/sdd/"*) pass "task-brief writes its brief under the workspace" ;;
        *)
            fail "task-brief writes its brief under the workspace"
            echo "    got: $brief_path"
            ;;
    esac

    local git_id=(-c user.email=t@example.com -c user.name=t -c commit.gpgsign=false)
    ( cd "$repo" \
        && git add plan.md \
        && git "${git_id[@]}" commit -qm c1 \
        && printf 'y\n' > f && git add f \
        && git "${git_id[@]}" commit -qm c2 )
    local rp_out rp_path
    rp_out="$(cd "$repo" && without_sdd_session "$SDD_SCRIPTS/review-package" HEAD~1 HEAD)"
    rp_path="$(printf '%s\n' "$rp_out" | sed -n 's/^wrote \(.*\): [0-9].*$/\1/p')"
    case "$rp_path" in
        "$repo/.superpowers/sdd/"*) pass "review-package writes its diff under the workspace" ;;
        *)
            fail "review-package writes its diff under the workspace"
            echo "    got: $rp_path"
            ;;
    esac

    local alpha_dir beta_dir
    alpha_dir="$(cd "$repo" && CLAUDE_CODE_SESSION_ID=alpha "$SDD_SCRIPTS/sdd-workspace")"
    beta_dir="$(cd "$repo" && CLAUDE_CODE_SESSION_ID=beta "$SDD_SCRIPTS/sdd-workspace")"
    if [[ "$alpha_dir" == "$repo/.superpowers/sdd/alpha" && "$beta_dir" == "$repo/.superpowers/sdd/beta" && "$alpha_dir" != "$beta_dir" ]]; then
        pass "CLAUDE_CODE_SESSION_ID scopes workspaces by session"
    else
        fail "CLAUDE_CODE_SESSION_ID scopes workspaces by session"
        echo "    alpha: $alpha_dir"
        echo "    beta:  $beta_dir"
    fi

    cat > "$repo/plan.md" <<'PLAN'
# Plan

## Task 1: Alpha

Alpha session content.
PLAN
    local alpha_brief_out alpha_brief_path beta_brief_out beta_brief_path
    alpha_brief_out="$(cd "$repo" && CLAUDE_CODE_SESSION_ID=alpha "$SDD_SCRIPTS/task-brief" plan.md 1)"
    alpha_brief_path="$(printf '%s\n' "$alpha_brief_out" | sed -n 's/^wrote \(.*\): [0-9][0-9]* lines$/\1/p')"

    cat > "$repo/plan.md" <<'PLAN'
# Plan

## Task 1: Beta

Beta session content.
PLAN
    beta_brief_out="$(cd "$repo" && CLAUDE_CODE_SESSION_ID=beta "$SDD_SCRIPTS/task-brief" plan.md 1)"
    beta_brief_path="$(printf '%s\n' "$beta_brief_out" | sed -n 's/^wrote \(.*\): [0-9][0-9]* lines$/\1/p')"

    if [[ "$alpha_brief_path" == "$repo/.superpowers/sdd/alpha/task-1-brief.md" \
        && "$beta_brief_path" == "$repo/.superpowers/sdd/beta/task-1-brief.md" \
        && "$alpha_brief_path" != "$beta_brief_path" \
        && "$(cat "$alpha_brief_path")" == *"Alpha session content."* \
        && "$(cat "$beta_brief_path")" == *"Beta session content."* ]]; then
        pass "task-brief writes same task number to session-isolated files"
    else
        fail "task-brief writes same task number to session-isolated files"
        echo "    alpha: $alpha_brief_path"
        echo "    beta:  $beta_brief_path"
    fi

    local override_dir unsafe_dir
    override_dir="$(cd "$repo" && CLAUDE_CODE_SESSION_ID=alpha SUPERPOWERS_SDD_SESSION=override "$SDD_SCRIPTS/sdd-workspace")"
    if [[ "$override_dir" == "$repo/.superpowers/sdd/override" ]]; then
        pass "SUPERPOWERS_SDD_SESSION overrides CLAUDE_CODE_SESSION_ID"
    else
        fail "SUPERPOWERS_SDD_SESSION overrides CLAUDE_CODE_SESSION_ID"
        echo "    got: $override_dir"
    fi

    unsafe_dir="$(cd "$repo" && CLAUDE_CODE_SESSION_ID=alpha SUPERPOWERS_SDD_SESSION="a/b .." "$SDD_SCRIPTS/sdd-workspace")"
    if [[ "$unsafe_dir" == "$repo/.superpowers/sdd/a_b_.." && ! -d "$repo/.superpowers/sdd/a" ]]; then
        pass "session ids are sanitized to one safe path segment"
    else
        fail "session ids are sanitized to one safe path segment"
        echo "    got: $unsafe_dir"
    fi

    # --- Worktree isolation: a linked worktree resolves its own workspace ---
    local wt="$TEST_ROOT/wt"
    ( cd "$repo" && git worktree add -q "$wt" -b wt-feature )
    local wt_root wt_dir
    wt_root="$(cd "$wt" && git rev-parse --show-toplevel)"
    wt_dir="$(cd "$wt" && without_sdd_session "$SDD_SCRIPTS/sdd-workspace")"
    if [[ "$wt_dir" == "$wt_root/.superpowers/sdd" && "$wt_dir" != "$dir" ]]; then
        pass "linked worktree resolves its own distinct workspace"
    else
        fail "linked worktree resolves its own distinct workspace"
        echo "    main: $dir"
        echo "    wt:   $wt_dir"
    fi

    local wt_session_dir
    wt_session_dir="$(cd "$wt" && CLAUDE_CODE_SESSION_ID=alpha "$SDD_SCRIPTS/sdd-workspace")"
    if [[ "$wt_session_dir" == "$wt_root/.superpowers/sdd/alpha" && "$wt_session_dir" != "$alpha_dir" ]]; then
        pass "linked worktree session workspace remains distinct"
    else
        fail "linked worktree session workspace remains distinct"
        echo "    main: $alpha_dir"
        echo "    wt:   $wt_session_dir"
    fi

    printf 'y\n' > "$wt/.superpowers/sdd/artifact.md"
    local wt_status
    wt_status="$(cd "$wt" && git status --porcelain)"
    if [[ -z "$wt_status" ]]; then
        pass "worktree workspace invisible to git status"
    else
        fail "worktree workspace invisible to git status"
        echo "    status: $wt_status"
    fi

    echo ""
    if [[ "$FAILURES" -ne 0 ]]; then
        echo "FAILED: $FAILURES assertion(s)."
        exit 1
    fi
    echo "PASS"
}

main "$@"
