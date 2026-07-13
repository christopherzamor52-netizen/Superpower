# Installing Superpowers from this fork

This fork is a self-contained Claude Code plugin: `.claude-plugin/marketplace.json`
registers the repo as a marketplace named `superpowers-dev`, and
`.claude-plugin/plugin.json` defines the `superpowers` plugin whose source is the
repo itself. That means you can install every skill directly from this fork
without going through the upstream marketplace.

## Claude Code

Inside any Claude Code session, run:

```
/plugin marketplace add patriotjordanian-create/superpowers
/plugin install superpowers@superpowers-dev
```

Or from the terminal:

```bash
claude plugin marketplace add patriotjordanian-create/superpowers
claude plugin install superpowers@superpowers-dev
```

Then restart your session. The plugin's SessionStart hook loads the
`using-superpowers` bootstrap, which makes all skills (brainstorming,
test-driven-development, systematic-debugging, writing-plans, and the rest)
auto-trigger at the right moments.

## Updating

After pushing changes to this fork, refresh with:

```
/plugin marketplace update superpowers-dev
```

## Verifying it works

Open a fresh session and say "Let's make a react todo list" — the
`brainstorming` skill should trigger before any code is written.
