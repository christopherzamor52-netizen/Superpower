#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

python3 - "$REPO_ROOT" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

repo_root = Path(sys.argv[1])
plugin_yaml = repo_root / ".hermes-plugin" / "plugin.yaml"
plugin_init = repo_root / "__init__.py"
hermes_tools = repo_root / "skills" / "using-superpowers" / "references" / "hermes-tools.md"


def assert_contains(text, needle, label):
    if needle not in text:
        raise AssertionError(f"{label}: missing {needle!r}")


manifest_text = plugin_yaml.read_text(encoding="utf-8")
for expected in [
    "name: superpowers",
    "version: 6.1.1",
    "provides_hooks:",
    "  - pre_llm_call",
]:
    assert_contains(manifest_text, expected, "plugin.yaml")

version_config = json.loads((repo_root / ".version-bump.json").read_text(encoding="utf-8"))
if not any(
    entry.get("path") == ".hermes-plugin/plugin.yaml" and entry.get("field") == "version"
    for entry in version_config.get("files", [])
    if isinstance(entry, dict)
):
    raise AssertionError(".version-bump.json must update plugin.yaml version")

spec = importlib.util.spec_from_file_location("superpowers_hermes_plugin", plugin_init)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FakeContext:
    def __init__(self):
        self.skills = []
        self.hooks = []

    def register_skill(self, name, skill_md):
        self.skills.append((name, Path(skill_md)))

    def register_hook(self, name, handler):
        self.hooks.append((name, handler))


ctx = FakeContext()
module.register(ctx)

skill_names = {name for name, _path in ctx.skills}
for expected_skill in [
    "using-superpowers",
    "brainstorming",
    "systematic-debugging",
    "test-driven-development",
    "subagent-driven-development",
]:
    if expected_skill not in skill_names:
        raise AssertionError(f"missing registered skill: {expected_skill}")

if len(skill_names) != len(ctx.skills):
    raise AssertionError("registered skill names must be unique")

for _name, skill_path in ctx.skills:
    if skill_path.name != "SKILL.md" or not skill_path.exists():
        raise AssertionError(f"registered skill path is invalid: {skill_path}")

pre_llm_hooks = [handler for name, handler in ctx.hooks if name == "pre_llm_call"]
if len(pre_llm_hooks) != 1:
    raise AssertionError(f"expected exactly one pre_llm_call hook, got {len(pre_llm_hooks)}")

result = pre_llm_hooks[0](
    session_id="test",
    user_message="Let's make a react todo list",
    conversation_history=[],
    is_first_turn=True,
    model="test-model",
    platform="cli",
)
if not isinstance(result, dict) or not isinstance(result.get("context"), str):
    raise AssertionError("pre_llm_call hook must return {'context': <text>}")

context = result["context"]
for expected in [
    "<EXTREMELY_IMPORTANT>",
    "You have superpowers.",
    "The Rule",
    "Hermes Agent Tool Mapping",
    'skill_view(name="superpowers:brainstorming")',
    "delegate_task",
    "todo",
    "</EXTREMELY_IMPORTANT>",
]:
    assert_contains(context, expected, "bootstrap context")

if "name: using-superpowers" in context:
    raise AssertionError("bootstrap should strip SKILL.md frontmatter before injection")

mapping = hermes_tools.read_text(encoding="utf-8")
for expected in [
    "skill_view",
    "read_file",
    "write_file",
    "patch",
    "search_files",
    "terminal",
    "delegate_task",
    "todo",
]:
    assert_contains(mapping, expected, "hermes tool mapping")

print("Hermes plugin wiring looks good")
PY
