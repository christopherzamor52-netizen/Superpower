# Gemini CLI Tool Mapping

Skills use Claude Code tool names. When you encounter these in a skill, use
the Gemini CLI equivalent:

| Skill references | Gemini CLI equivalent |
|-----------------|----------------------|
| `Read` (file reading) | `read_file` |
| `Write` (file creation) | `write_file` |
| `Edit` (file editing) | `replace` |
| `Bash` (run commands) | `run_shell_command` |
| `Grep` (search file content) | `grep_search` |
| `Glob` (search files by name) | `glob` |
| `TodoWrite` (task tracking) | `write_todos` |
| `Skill` tool (invoke a skill) | `activate_skill` |
| `WebSearch` | `google_web_search` |
| `WebFetch` | `web_fetch` |
| `Task` tool (dispatch subagent) | `@generalist` with the prompt from the skill |

## Subagent support

Gemini CLI supports subagents through `@` dispatch. When a skill asks you to
dispatch a subagent, use `@generalist` with the fully filled prompt template.

- Keep dependent tasks sequential.
- Independent tasks may be dispatched in parallel.
- If a skill requires a named reviewer or implementer prompt, pass that full
  prompt to `@generalist`.

## Additional Gemini CLI tools

These tools exist in Gemini CLI but may not have a direct Claude Code name:

| Tool | Purpose |
|------|---------|
| `list_directory` | List files and subdirectories |
| `save_memory` | Persist facts to `GEMINI.md` across sessions |
| `ask_user` | Request structured input from the user |
| `tracker_create_task` | Rich task management |
| `enter_plan_mode` / `exit_plan_mode` | Switch to read-only planning mode |
