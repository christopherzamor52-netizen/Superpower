# Hermes Agent Tool Mapping

Skills speak in actions ("dispatch a subagent", "create a todo", "read a file"). In Hermes Agent these resolve to the tools below.

| Action skills request | Hermes Agent equivalent |
| --- | --- |
| Invoke a skill | Call `skill_view` with the plugin-qualified skill name, e.g. `skill_view(name="superpowers:brainstorming")`. The `using-superpowers` bootstrap is already loaded by this plugin; do not load it again unless inspecting it explicitly. |
| Read a file | `read_file` |
| Create a file | `write_file` |
| Edit or delete file content | `patch` for targeted edits; `write_file` only when replacing an entire file. |
| Search file contents / find files by name | `search_files` (`target="content"` or `target="files"`) |
| Run a shell command | `terminal` |
| Dispatch a subagent | `delegate_task` for quick isolated subtasks. For long-lived or interactive child Hermes agents, use `terminal` to run `hermes chat -q ...` or a tmux-driven `hermes` process. |
| Create / update todos | `todo` |
| Fetch a URL / web search | Use Hermes web tools when enabled; otherwise use `terminal` with `curl` for direct URLs. |

## Skill invocation

This plugin registers bundled skills under Hermes' plugin namespace. When a Superpowers skill applies, load it with:

```text
skill_view(name="superpowers:<skill-name>")
```

Examples:

- `skill_view(name="superpowers:brainstorming")`
- `skill_view(name="superpowers:systematic-debugging")`
- `skill_view(name="superpowers:test-driven-development")`

Do not use bare names such as `skill_view(name="brainstorming")` unless the user has separately installed those skills into Hermes' normal skills directory. The plugin-qualified form is the portable path for this integration.

## Subagents

Hermes' `delegate_task` runs isolated subagents in the background and returns their summaries to the parent session when they finish. Use it when a Superpowers skill asks to dispatch independent implementer, reviewer, or research agents.

If the skill needs an interactive or long-lived agent process instead of a bounded subtask, spawn Hermes itself from the terminal, for example with `hermes chat -q "..."` for one-shot work or `tmux new-session ... 'hermes'` for interactive coordination.
