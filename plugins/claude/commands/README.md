# Legacy path (do not add command `.md` files here)

Plugin slash commands live in the repo root [`commands/`](../../commands/) directory
(`init.md` → `/ace:init`, `evolve.md` → `/ace:evolve`, etc.).

Files placed here are also registered by Claude Code and would duplicate `/ace:*`
as `/ace-init`, `/ace-evolve`, … — so this folder must stay empty of commands.

Install via marketplace: `claude plugin install ace@ace`, then `/reload-plugins`.
