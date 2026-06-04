#!/bin/bash
# Install ace plugin for detected IDE (legacy project-local copy — prefer marketplace)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IDE=${1:-auto}

detect_ide() {
  if [ -d ".claude" ] || [ -n "$CLAUDE_CODE" ]; then
    echo "claude"
  elif [ -d ".opencode" ]; then
    echo "opencode"
  elif [ -d ".cursor" ]; then
    echo "cursor"
  else
    echo "unknown"
  fi
}

if [ "$IDE" = "auto" ]; then
  IDE=$(detect_ide)
fi

echo "ace plugin: use marketplace install for /ace:* commands"
echo "  Claude Code: claude plugin install ace@ace  then /reload-plugins"
echo "  Cursor: /add-plugin ace"
echo ""
echo "Skipping legacy copy to .claude/commands (would duplicate /ace:init as /ace-init)."
echo "OpenCode-only path still copies plugins/opencode/commands/ if needed."

case $IDE in
  claude|cursor)
    echo "Nothing to copy for IDE: $IDE"
    ;;
  opencode)
    mkdir -p .opencode/commands
    cp "$SCRIPT_DIR/plugins/opencode/commands/"*.md .opencode/commands/
    echo "Installed to .opencode/commands/"
    ;;
  *)
    echo "Unknown IDE: $IDE"
    exit 1
    ;;
esac

echo "Installation complete!"
