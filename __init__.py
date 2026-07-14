"""Hermes Agent plugin entry point for Superpowers.

Hermes loads this module from a plugin install and calls ``register(ctx)`` once at
startup. The plugin registers the bundled Superpowers skills under the
``superpowers:`` namespace and injects the using-superpowers bootstrap before LLM
turns so the workflow is active without per-session opt-in.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

_PLUGIN_DIR = Path(__file__).resolve().parent
_SKILLS_DIR = _PLUGIN_DIR / "skills"
_BOOTSTRAP_PATH = _SKILLS_DIR / "using-superpowers" / "SKILL.md"
_TOOL_MAPPING_PATH = _SKILLS_DIR / "using-superpowers" / "references" / "hermes-tools.md"
_FRONTMATTER_RE = re.compile(r"\A---\s*\n.*?\n---\s*\n", re.DOTALL)

_bootstrap_cache: str | None = None


def _strip_frontmatter(text: str) -> str:
    return _FRONTMATTER_RE.sub("", text, count=1)


def _build_bootstrap() -> str:
    global _bootstrap_cache
    if _bootstrap_cache is not None:
        return _bootstrap_cache

    skill_body = _strip_frontmatter(_BOOTSTRAP_PATH.read_text(encoding="utf-8"))
    tool_mapping = _TOOL_MAPPING_PATH.read_text(encoding="utf-8")

    _bootstrap_cache = f"""<EXTREMELY_IMPORTANT>
You have superpowers.

IMPORTANT: The using-superpowers skill content is included below. It is ALREADY LOADED - you are currently following it. Do not use skill_view to load "superpowers:using-superpowers" again unless the user explicitly asks to inspect it.

{skill_body}

{tool_mapping}
</EXTREMELY_IMPORTANT>"""
    return _bootstrap_cache


def _inject_bootstrap(**_kwargs: Any) -> dict[str, str] | None:
    """pre_llm_call hook: inject Superpowers context into the current turn."""
    try:
        return {"context": _build_bootstrap()}
    except Exception:
        # Plugin hooks should never break the agent loop. If the installed plugin
        # is incomplete, fail closed by not injecting context.
        return None


def register(ctx: Any) -> None:
    """Register Superpowers skills and the startup bootstrap hook."""
    if _SKILLS_DIR.exists():
        for child in sorted(_SKILLS_DIR.iterdir()):
            skill_md = child / "SKILL.md"
            if child.is_dir() and skill_md.exists():
                ctx.register_skill(child.name, skill_md)

    ctx.register_hook("pre_llm_call", _inject_bootstrap)
