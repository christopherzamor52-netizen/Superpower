---
name: ace-init
description: "Initialize ACE in current project by installing CLAUDE.md with proper absolute paths"
---

# ACE Init - Initialize ACE in Current Project

Install ACE's CLAUDE.md into the current project directory with docs paths converted to absolute paths.

## When to Use

- User runs `/ace:init` command
- Setting up a new project to use ACE
- Need CLAUDE.md with working documentation links

## Execution Steps

1. **Read ACE root from config**
   ```python
   import json
   from pathlib import Path

   config_file = Path.home() / '.ace' / 'config.json'
   if not config_file.exists():
       print("Error: ACE not installed. Run 'make install' in ACE repository first.")
       return

   with open(config_file) as f:
       config = json.load(f)
   ace_root = config.get('ace_root')

   if not ace_root:
       print("Error: ACE root not configured. Run 'make install' in ACE repository.")
       return
   ```

2. **Read ACE CLAUDE.md**
   ```python
   import re

   claude_md_path = Path(ace_root) / 'CLAUDE.md'
   if not claude_md_path.exists():
       print(f"Error: CLAUDE.md not found at {claude_md_path}")
       return

   with open(claude_md_path) as f:
       content = f.read()
   ```

3. **Replace docs/ paths with absolute paths**
   ```python
   # Replace `docs/xx.md` with `<ace_root>/docs/xx.md`
   def replace_path(match):
       opening = match.group(1) or ''
       doc_path = match.group(2)
       closing = match.group(3) or ''
       abs_path = f"{ace_root}/{doc_path}"
       return f"{opening}{abs_path}{closing}"

   # Pattern matches docs/xx.md in various quote contexts
   pattern = r'([`\("\'\s]|^)(docs/[\w\-]+\.md)([`\)"\'\s]|$)'
   content = re.sub(pattern, replace_path, content)
   ```

4. **Write CLAUDE.md to current directory**
   ```python
   target = Path.cwd() / 'CLAUDE.md'
   with open(target, 'w') as f:
       f.write(content)

   print(f"✅ ACE initialized: {target}")
   print(f"   Docs path: {ace_root}/docs/")
   ```

## Error Handling

- **Missing `~/.ace/config.json`**: "ACE not installed. Run 'make install' in ACE repository first."
- **Missing `ace_root` in config**: Same error
- **Missing `${ace_root}/CLAUDE.md`**: "ACE installation corrupted. Please reinstall."
- **Permission error**: Report file system error with specific path

## Success Output

```
✅ ACE initialized: /path/to/project/CLAUDE.md
   Docs path: /path/to/ace/docs/

You can now use ACE in this project.
```

## Invocation

```
Skill("ace-init")
```
