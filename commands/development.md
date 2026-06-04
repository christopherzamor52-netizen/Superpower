---
description: ACE Paradigm 3 - Develop ACE framework using ace plugin skills
---
# ACE P3 - ACE Development

Improve ACE framework using official ace plugin skills with evolution闭环.

## Usage

```
/ace:development
```

This command invokes the `ace-development` skill.

## ACE CLI Commands (Recommended)

### List Nodes
```bash
ace node list --source local              # local only (default)
ace node list --source all [--device <device_id>]
```

### Pull from ace-hub (if nodes not found)
```bash
ace hub list --type nodes
ace hub pull <node_id> --type node
```

### Show Node Details
```bash
ace node show <node_id>
```

### Run Evolution Cycle
```bash
ace evolve run
```

### Show Evolution Health
```bash
ace evolve health
```

### List Insights
```bash
ace insight list [--type <type>] [--status <status>]
```

### View Insight Details
```bash
ace insight show <insight_id>
```

### Knowledge Search
```bash
ace knowledge search "<query>"
```

### Knowledge Ingest
```bash
ace knowledge ingest <file_path> [--type <type>]
```

### Run Tests
```bash
ace sandbox test [test_pattern]
```

## Workflow

1. Design (`ace:brainstorming`)
2. Plan (`ace:writing-plans`)
3. **Develop with TDD** (`ace:test-driven-development`)
   - RED: Write failing test first
   - GREEN: Write minimal code to pass
   - REFACTOR: Clean up while green
4. Evolution闭环 (`/ace:evolve`)
5. Complete (`ace:finishing-a-development-branch`)

## Output

- Specs: docs/superpowers/specs/
- Plans: docs/superpowers/plans/

## Invocation

```
Skill("ace-development")
```
