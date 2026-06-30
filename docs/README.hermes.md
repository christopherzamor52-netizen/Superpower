# Hermes Agent

Superpowers supports Hermes Agent via an in-process Python plugin (Shape B).

## Install

```bash
hermes plugins install obra/superpowers --enable
```

## What you get

All Superpowers skills auto-trigger in Hermes sessions:
brainstorming before feature work, systematic-debugging on bugs,
test-driven-development for implementation, writing-plans before
touching code, and all other skills in `skills/`.

## How it works

The plugin injects the `using-superpowers` bootstrap as a user-role
message via the `on_session_start` hook. Skills are registered from
the bundled `skills/` directory and are discoverable in Hermes's
native agentskills.io catalog.

## Verifying

See `.hermes-plugin/INSTALL.md` for the smoke check and acceptance test.
