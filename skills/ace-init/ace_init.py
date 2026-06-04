#!/usr/bin/env python3
"""
ACE Init - Initialize ACE in current project

Copies ACE's CLAUDE.md to current directory with docs paths
converted to absolute paths.
"""

import json
import re
import sys
from pathlib import Path


def get_ace_root():
    """Read ACE root from ~/.ace/config.json."""
    config_file = Path.home() / '.ace' / 'config.json'

    if not config_file.exists():
        return None

    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
        return config.get('ace_root')
    except (json.JSONDecodeError, IOError):
        return None


def init_ace():
    """Initialize ACE in current directory."""
    # Get ACE root
    ace_root = get_ace_root()
    if not ace_root:
        print("Error: ACE not installed or not configured.")
        print("Please run 'make install' in the ACE repository first.")
        print("")
        print("If ACE is already installed, ensure ~/.ace/config.json exists")
        print("with an 'ace_root' field pointing to your ACE installation.")
        sys.exit(1)

    ace_root = Path(ace_root)
    claude_md_source = ace_root / 'CLAUDE.md'

    if not claude_md_source.exists():
        print(f"Error: CLAUDE.md not found at {claude_md_source}")
        print("ACE installation may be corrupted. Please reinstall.")
        sys.exit(1)

    # Read CLAUDE.md
    with open(claude_md_source, 'r') as f:
        content = f.read()

    # Replace docs/xx.md paths with absolute paths
    # Match patterns like `docs/01-architecture.md` or docs/xx.md in various contexts
    def replace_doc_path(match):
        # match.group(1) is the opening quote/backtick/paren
        # match.group(2) is the docs/xx.md path
        # match.group(3) is the closing quote/backtick/paren
        opening = match.group(1) if match.group(1) else ''
        doc_path = match.group(2)
        closing = match.group(3) if match.group(3) else ''
        abs_path = str(ace_root / doc_path)
        return f"{opening}{abs_path}{closing}"

    # Pattern matches docs/xx.md in various contexts:
    # - `docs/xx.md`
    # - "docs/xx.md"
    # - 'docs/xx.md'
    # - (docs/xx.md)
    # - | docs/xx.md |
    # Just the path at start of line or after whitespace
    pattern = r'([`\("\'\s]|^)(docs/[\w\-]+\.md)([`\)"\'\s]|$)'
    content = re.sub(pattern, replace_doc_path, content)

    # Write to current directory
    target_file = Path.cwd() / 'CLAUDE.md'
    with open(target_file, 'w') as f:
        f.write(content)

    print(f"✅ ACE initialized successfully!")
    print(f"   CLAUDE.md installed: {target_file}")
    print(f"   ACE root: {ace_root}")
    print("")
    print("You can now use ACE in this project.")
    print("Run '/ace:run-workflow', '/ace:device-onboarding', or '/ace:development' to get started.")


if __name__ == '__main__':
    init_ace()
