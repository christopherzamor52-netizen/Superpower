---
name: generating-diagrams
description: "Use when generating architecture diagrams, system overview visuals, or illustrative images from text descriptions via an image generation API"
---

# Generating Architecture Diagrams

Generate architecture diagrams and illustrative images by calling the GPUGeek image generation API, using the project's configured LLM API key.

## When to Use

- Creating visual architecture overviews from codebase context or descriptions
- Generating diagrams for documentation, design specs, or presentations
- Producing illustrative images when a visual aid helps communicate structure
- Need a quick diagram without manually drawing tools

## When NOT to Use

- When precise, engineering-grade diagrams are required (use Graphviz, Mermaid, or CAD)
- When the diagram must be editable later (these are raster images)
- For simple flowcharts that text or DOT can express more accurately

## Quick Reference

| Parameter | Default | Options |
|-----------|---------|---------|
| size      | 1024x1024 | 1024x1024, 4096x4096 (HD) |
| timeout   | 300s      | Any integer (image gen is slow) |
| api_key   | `ACE_LLM_API_KEY` env var | Override via `--api-key` |

## Usage

### CLI

```bash
# Default size (1024x1024)
python -m skills.generating_diagrams.generate_diagram \
  "A clean, minimal architecture diagram showing a microservices setup with API gateway, auth service, and three backend services connected via message queue" \
  -o docs/arch.png \
  --size 1024x1024

# HD (4096x4096)
python -m skills.generating_diagrams.generate_diagram \
  "A detailed system architecture diagram..." \
  -o docs/arch-hd.png \
  --size 4096x4096

# JSON output for scripting
python -m skills.generating_diagrams.generate_diagram \
  "A diagram of a three-tier web application" \
  -o diagram.png \
  --size 1024x1024 \
  --json
```

### Python API

```python
from skills.generating_diagrams.generate_diagram import generate_diagram

path = generate_diagram(
    prompt="A minimal architecture diagram of a message-driven event pipeline",
    output_path="docs/pipeline.png",
    size="1024x1024",  # or "4096x4096" for HD
)
print(f"Saved to {path}")
```

## Prompt Tips

- Be specific about style: "clean, minimal, light background, professional"
- Mention layout preferences: "top-down flow", "left-to-right data flow"
- Include component names so the model renders labels accurately
- For architecture diagrams, ask for "labeled boxes and arrows"

## Error Handling

| Error | Cause | Fix |
|-------|-------|-----|
| `API key not found` | `ACE_LLM_API_KEY` not set | `export ACE_LLM_API_KEY=...` |
| `API request failed` | API error or network issue | Check key validity and network |
| `Unexpected API response format` | API changed response shape | Check API docs / report issue |

## Canonical Statements

- "Generating architecture diagram..."
- "Calling image generation API (this may take a while)..."
- "Image saved: [path]"
- "Using HD resolution (4096x4096)..."
