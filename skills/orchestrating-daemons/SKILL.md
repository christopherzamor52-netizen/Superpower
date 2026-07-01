---
name: orchestrating-daemons
description: Use when you need to spawn, track, and autonomously drive several durable background `claude` sessions (daemons) that persist across turns and sessions and can be resumed later — kicking off long-running or independent tasks to run on their own and checking back, delegating to resumable headless sessions, or fanning out work that must survive this session ending. Not for ephemeral in-session subagents.
---

# Orchestrating Daemons

## Overview

A **daemon** is a durable, resumable headless `claude` session with a stable UUID. You are the orchestrator: you spawn a fleet of them, read each reply, and for every reply make one call — **answer it yourself, queue it for the human, or wake the human now** — then resume it. Daemons persist on disk; they survive this session ending and the human can `claude --resume <uuid>` any of them.

**This is not `dispatching-parallel-agents`.** That skill fans out *in-session* Task subagents that share your context and die with your turn. Daemons are separate `claude` processes with their own context windows, resumable across sessions. Use daemons when work must persist, be resumed later, or not consume your context.

## The loop

Each daemon turn = a `claude -p` call that blocks until the turn ends. Run it in a **background shell** (Claude Code: the Bash tool with `run_in_background: true`) so it never ties up your main loop — the shell's exit re-invokes you with the daemon's reply.

1. **Spawn** each task: `scripts/daemon-spawn.sh "<name>" "<task>" [cwd]` in a background shell.
2. **Read** the reply — it's the `--- reply ---` block in the shell output, or `scripts/daemon-reply.sh <id>`.
3. **Judge** it with the rubric below.
4. **Resume** with your answer: `scripts/daemon-resume.sh <uuid> "<message>"` in a background shell. Or, if you queued it, `scripts/daemon-mark.sh <uuid> awaiting-human "<why>"`.
5. **Track**: `scripts/daemon-list.sh` is your fleet view — show it when the human asks "what's running". Retire finished daemons with `scripts/daemon-retire.sh <uuid>`.

## Toolkit

Paths are relative to this skill's directory. The scripts hide every sharp edge (UUID handling, cwd-scoped resume, ANSI, JSON parsing, macOS timeout) — **use them; don't hand-roll `claude` invocations.**

| Script | Does |
|---|---|
| `daemon-spawn.sh <name> <task> [cwd] [model]` | Mint a daemon, run turn 1. Launch in a bg shell. |
| `daemon-resume.sh <uuid> <message>` | Continue a daemon **in place** (same id, full context). Launch in a bg shell. |
| `daemon-reply.sh <id>` | Print a daemon's latest full reply. |
| `daemon-list.sh [status]` | Fleet view; optional status filter. |
| `daemon-mark.sh <id> <status> [note]` | Record a judgment state (`awaiting-human`, `done`) + why. |
| `daemon-retire.sh <id> [purge]` | Drop from active fleet; transcript stays resumable. |

## Decide vs. escalate

When a daemon ends its turn with a question or decision point, **"needs a human" is not the same as "needs a human now."** Default to answering or queuing; reserve waking for genuine urgency.

| The daemon is asking about… | You… |
|---|---|
| Something technical/mechanical with an obvious best answer (naming, which test, a bug fix, a retry, a clarification you can infer) | **Answer it yourself** and resume. |
| Whether to exceed the scope it was given | **Answer "stay in scope"** and resume; note the suggestion for the human's next check-in. |
| A genuine product / design / brand / taste fork, or approval for something large or irreversible (implement a recommendation, deploy, spend, delete) — but nothing is blocked or unsafe *right now* | **Queue it**: `daemon-mark.sh <id> awaiting-human`, have the daemon produce every option / a decision-ready writeup, and surface it at the next check-in. Don't wake. |
| Something destructive/irreversible about to happen, a security / data-loss / production risk, or a hard blocker where every path needs info only the human has **and** it can't wait | **Wake the human now** (send a PushNotification). |

You are trusted to answer on the human's behalf for technical and mechanical calls. Escalate *judgment*, not *work*.

## Spawn-prompt hygiene

Daemons run unattended, so the prompt does the guardrail work. In every spawn prompt: **state the scope explicitly, name the deliverable, and tell the daemon to END ITS TURN clearly stating any decision that is above its scope rather than guessing.** A daemon that stops and asks cleanly is one whose reply you can classify in seconds.

## Permissions

The scripts spawn with `--permission-mode auto` — the LLM classifier auto-approves safe tool use and gates genuinely unsafe ops. **Do not add `--dangerously-skip-permissions` to dodge overnight prompts.** A gated op is a *feature*: it surfaces in the daemon's reply as "couldn't do X / needs permission", which your rubric turns into an escalation. Bypassing hands an unattended process the power to do something irreversible with no one watching.

## Common mistakes

- **Assuming `--bg --resume` continues a session** — it *forks* a new id. `daemon-resume.sh` uses `-p --resume`, which continues in place with a stable id. Always resume through the script.
- **Resuming from the wrong directory** — `claude --resume` is scoped to the daemon's cwd/project. The scripts record and restore cwd; hand-rolled resumes fail with "No conversation found".
- **Running a daemon turn in the foreground** — it blocks your main loop for the whole turn. Always launch spawn/resume in a background shell.
- **Waking the human for scope or "should I do more?" questions** — those are yours to answer. Queue the taste/approval forks; wake only for the last row of the rubric.
