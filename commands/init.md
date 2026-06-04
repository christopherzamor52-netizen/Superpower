---
description: Initialize ACE in current project - install CLAUDE.md with proper paths
---

# ACE Init - Initialize ACE in Current Project

Initialize ACE support in the current project directory by installing a properly configured CLAUDE.md.

## What This Command Does

1. Reads ACE root directory from `~/.ace/config.json` (set during `make install`)
2. Copies ACE's CLAUDE.md to the current directory
3. Converts relative `docs/xx.md` paths to absolute paths: `<ace_root>/docs/xx.md`

## Usage

Run this command in any project directory where you want to use ACE:

```
/ace:init
```

## Requirements

- ACE must be installed via `make install` (which saves the ACE root path)
- The ACE root path is stored in `~/.ace/config.json`

## Result

After running `/ace:init`, you'll have:
- `CLAUDE.md` in your current directory with correct absolute paths to ACE documentation
- Full access to ACE paradigms and workflows

## Invocation

```
Skill("ace-init")
```
