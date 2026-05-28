# ace-recorder

Query and control the user's local screen/audio/UI recording history via screenpipe.

## When to Use

Use this skill when the user or agent needs to:
- Understand what the user has been doing on their computer
- Find a specific moment, app, or piece of text from recent screen history
- Generate a summary of app usage, meetings, or activities
- Control screen recording (start/stop)
- Export recorded actions into Aloha-compatible format for workflow learning

## Prerequisites

Screenpipe must be installed and running:
- Install: `make install-recorder`
- Start: `ace record start`
- Stop: `ace record stop`

## Tools

### recorder_start
Start the screenpipe recording daemon.

**Parameters:**
- `audio` (bool, optional): Enable audio recording. Default: false.
- `port` (int, optional): API port. Default: 3030.

**Example:**
```
recorder_start(audio=false, port=3030)
```

### recorder_stop
Stop the screenpipe recording daemon.

**Example:**
```
recorder_stop()
```

### recorder_status
Check if screenpipe is running and API is healthy.

**Returns:** `{running: bool, pid: int|null, api: string, health: object}`

### recorder_activity
Get a high-level summary of app usage, window time, and key texts.

**Parameters:**
- `since` (string, optional): Time range. Default: "1h". Formats: "1h", "30m", "1d".

**Example:**
```
recorder_activity(since="2h")
```

**Returns:** List of apps with duration and window titles.

### recorder_search
Keyword search across screen text (OCR), audio transcriptions, and UI events.

**Parameters:**
- `query` (string, required): Search keyword.
- `since` (string, optional): Time range. Default: "1h".
- `limit` (int, optional): Max results. Default: 10. Max: 50.

**Example:**
```
recorder_search(query="meeting", since="1d", limit=20)
```

### recorder_sql
Run a read-only SQL query against the local SQLite database.

**Parameters:**
- `query` (string, required): SQL SELECT statement.
- `limit` (int, optional): Auto-injected LIMIT if missing. Default: 50.

**Important:** Every query MUST include `LIMIT` (enforced automatically).

**Example:**
```
recorder_sql(query="SELECT event_type, app_name, COUNT(*) FROM ui_events GROUP BY event_type, app_name LIMIT 20")
```

**Available tables:** `frames`, `ocr_text`, `audio_transcriptions`, `ui_events`, `speakers`, `meetings`, `memories`

### recorder_recent
Get the most recent captures.

**Parameters:**
- `type` (string, required): One of `"frames"`, `"audio"`, `"ui"`.
- `limit` (int, optional): Default: 10.

**Example:**
```
recorder_recent(type="ui", limit=5)
```

### recorder_export
Export screenpipe UI events and frames into ShowUI-Aloha format.

**Parameters:**
- `project` (string, required): Project name for output directory.
- `since` (string, optional): Time range to export.
- `aloha_path` (string, optional): Path to ShowUI-Aloha repo.
- `frame_step` (int, optional): Extract every Nth frame. Default: 1.
- `sql` (string, optional): Raw SQL WHERE fragment.
- `application` (string, optional): Fuzzy match on app_name.
- `event` (string, optional): Event type filter (`click`, `move`, `scroll`, `key`, `text`, `app_switch`).
- `key` (string, optional): Exact match on key_code.
- `keyword` (string, optional): Fuzzy match on text_content or window_title.

Multiple filters are combined with AND logic.

**Example:**
```
recorder_export(project="blender_demo", since="30m", event="click")
```

### recorder_learn
Run Aloha Learn on exported data to generate a semantic trace.

**Parameters:**
- `project` (string, required): Exported project name.
- `aloha_path` (string, optional): Path to ShowUI-Aloha repo.
- `task` (string, optional): Natural-language description of the task.

**Example:**
```
recorder_learn(project="blender_demo", task="Create a sphere in Blender")
```

### recorder_push
Push an exported project to HyperData Hub for versioned storage.

**Parameters:**
- `project` (string, required): Exported project name.
- `remote_url` (string, optional): S3 URL for the Zarr store.
- `hub_name` (string, optional): Hub catalogue name.

**Example:**
```
recorder_push(project="blender_demo", remote_url="s3://hyperdata-data/ace/blender_demo.zarr", hub_name="ace/blender_demo")
```

**Prerequisites:** `pip install hyperdata Pillow numpy`

### recorder_trace_editor
Interactive image editor for project screenshots with two tabs:
- **Tab 1 (Manual Crop):** Mouse drag to select a crop region, then batch-crop all images.
- **Tab 2 (AI Process):** Enter a natural-language description (e.g. "grayscale", "crop to the left panel", "increase brightness"), send to VLM (kimi), preview the result on the first image, then batch-apply to all images.

**Parameters:**
- `project` (string, required): Exported project name.
- `aloha_path` (string, optional): Path to ShowUI-Aloha repo.

**Example:**
```
recorder_trace_editor(project="blender_demo")
```

**Prerequisites:** `pip install Pillow` (tkinter is bundled with Python on most systems).

## Progressive Disclosure

When reasoning about user history, query in this order:

1. **`recorder_activity`** — highest-level summary (apps used, time spent).
2. **`recorder_search`** — keyword search when looking for something specific.
3. **`recorder_sql`** — precise queries when the schema is known.
4. **`recorder_recent`** — latest events when recency matters.

## Constraints

- **Time ranges:** Start with 1–2 hours. Expand only if needed.
- **Frame fetching:** Never fetch more than 2–3 frames per query.
- **SQL LIMIT:** Every `SELECT` must include `LIMIT` (auto-enforced by `recorder_sql`).
- **Large responses (>5KB):** Write to a temp file and reference it rather than printing inline.
- **Privacy:** All data stays local. Never upload screen/audio data to remote services.

## Integration with ACE

Screenpipe data can feed into ACE's knowledge and insight systems:
- Use `recorder_activity` to generate daily/weekly work summaries.
- Use `recorder_search` to find context for a workflow or task.
- Use `recorder_export` + `recorder_trace_editor` + `recorder_learn` to teach Aloha how to replay a workflow.

## References

- [screenpipe GitHub](https://github.com/screenpipe/screenpipe)
- [screenpipe API docs](https://docs.screenpi.pe)
- ShowUI-Aloha: `Aloha_Learn/parser.py` for trace generation pipeline
