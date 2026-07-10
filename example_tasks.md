# OCR Translator — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Execution model — CONTRACT, NOT CODE:** Each task gives you a precise contract (exact interfaces, behavior, test scenarios, acceptance criteria) — not the implementation. You design and write the code via real TDD. What is fixed: file paths, public signatures in **Interfaces**, and the Global Constraints. What is yours: how you implement it. Full code appears only in **Implementation notes**, and only where ambiguity would be costly.

**Goal:** Desktop OCR + translation app (Python/PyQt6) that lives in the system tray, translating selected text and screen regions via global hotkeys.

**Architecture:** Four layers — `platform` (OS services behind interfaces), `providers` (translation + OCR, plugable via registry), `core` (orchestrator + IPC + single-instance), `ui` (PyQt6). UI and core never import OS-specific code directly; they talk to `platform/base.py` interfaces resolved by a factory.

**Tech Stack:** Python 3.11+, PyQt6, pytesseract (Tesseract), Google (HTTP, no key) + Argos Translate providers, pytest + pytest-qt + pytest-mock.

## Global Constraints

- Python 3.11+; GUI is PyQt6.
- Target platforms: Windows and Linux GNOME-on-Wayland only. X11 is out of scope.
- UI and `core` MUST NOT import from `platform/windows/` or `platform/linux_gnome/`. They depend only on the interfaces in `platform/base.py`, obtained via `platform/factory.py`.
- Network, OCR and translation calls run OFF the UI thread; results return to the UI via a Qt signal.
- Config is a single JSON file in the user config dir: `%APPDATA%\ocr-translator\config.json` (Windows), `~/.config/ocr-translator/config.json` (Linux).
- A failure in any single action never crashes the resident app; worst case is a clear error popup.
- Test tooling: `pytest`, `pytest-qt`, `pytest-mock`. No network or real OS calls in unit tests — use fakes/mocks.

---

## Task 1: Project scaffold + config model

**Files:**
- Create: `pyproject.toml`, `src/ocr_translator/__init__.py`, `src/ocr_translator/config/__init__.py`
- Create: `src/ocr_translator/config/settings.py`, `src/ocr_translator/config/defaults.py`
- Test:   `tests/config/test_settings.py`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `class Settings` — dataclass with fields: `target_language: str`, `source_language: str = "auto"`, `ocr_language: str`, `translation_provider: str` (`"google"` | `"argos"`), `copy_ocr_to_clipboard: bool = False`, `hotkeys: dict[str, str]`.
  - `config_path() -> pathlib.Path` — resolves the per-OS config file path.
  - `load_settings(path: Path | None = None) -> Settings`
  - `save_settings(settings: Settings, path: Path | None = None) -> None`
  - `DEFAULTS: Settings` (in `defaults.py`)

**Behavior contract:**
- `config_path()` returns `%APPDATA%\ocr-translator\config.json` on Windows and `~/.config/ocr-translator/config.json` elsewhere.
- `load_settings` reads JSON and returns a `Settings`. Missing file → returns `DEFAULTS` and writes it to disk.
- Corrupt/invalid JSON → back up the bad file to `<name>.bak`, recreate from `DEFAULTS`, return `DEFAULTS`.
- Unknown extra keys in the file are ignored; missing keys fall back to their default.
- `save_settings` writes pretty-printed JSON, creating parent dirs as needed.

**Test scenarios:**
- `config_path()` matches the OS-specific path (patch `sys.platform` and env).
- Round-trip: `save_settings(s)` then `load_settings()` → equal `Settings`.
- Missing file → returns `DEFAULTS` and the file now exists.
- Corrupt file → `<name>.bak` created, returns `DEFAULTS`, file rewritten valid.
- File missing a key → that field takes the default; extra unknown key → ignored.

**Acceptance criteria:**
- All scenarios covered and green.
- Public signatures match the **Interfaces** block exactly.
- No real user-home writes in tests (use `tmp_path`).

**Implementation notes:** none.

- [ ] **Step 1:** Write tests covering the scenarios above (use `tmp_path`, patch `sys.platform`).
- [ ] **Step 2:** Run — confirm they fail for the right reason (`ModuleNotFoundError` / missing symbols).
- [ ] **Step 3:** Implement `settings.py` + `defaults.py` + minimal `pyproject.toml` to satisfy the contract (your design).
- [ ] **Step 4:** Run — confirm green; refactor if needed.
- [ ] **Step 5:** Stage the change and suggest a commit (do NOT run `git commit`):
  ```bash
  git add pyproject.toml src/ocr_translator/config/ tests/config/test_settings.py
  # Suggested commit (your human partner runs this):
  #   git commit -m "feat(config): settings model with load/save and corruption recovery"
  ```

---

## Task 2: Translation provider interface + registry

**Files:**
- Create: `src/ocr_translator/providers/__init__.py`, `src/ocr_translator/providers/translation/__init__.py`
- Create: `src/ocr_translator/providers/translation/base.py`
- Test:   `tests/providers/translation/test_base.py`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `class TranslationError(Exception)`
  - `class TranslationProvider(abc.ABC)` with abstract methods:
    - `translate(self, text: str, source: str, target: str) -> str`
    - `detect_language(self, text: str) -> str`
    - `supported_languages(self) -> list[str]`
  - `register_provider(name: str, cls: type[TranslationProvider]) -> None`
  - `get_provider(name: str) -> TranslationProvider`  (raises `KeyError` if unknown)

**Behavior contract:**
- `TranslationProvider` cannot be instantiated directly (it is abstract).
- The registry maps a name → provider class; `get_provider` constructs and returns an instance.
- Registering the same name twice overwrites the previous entry.
- `get_provider` on an unknown name raises `KeyError`.

**Test scenarios:**
- Instantiating `TranslationProvider()` raises `TypeError`.
- A concrete subclass registered under `"fake"` is returned by `get_provider("fake")` as an instance of that subclass.
- `get_provider("nope")` raises `KeyError`.
- Re-registering `"fake"` with a second class → `get_provider("fake")` returns the second.

**Acceptance criteria:**
- All scenarios covered and green.
- Signatures match **Interfaces** exactly; `source="auto"` is a legal input value (contract only — behavior lives in concrete providers).

**Implementation notes:** none.

- [ ] **Step 1:** Write tests (define a tiny in-test concrete subclass as a fixture).
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement `base.py` (your design).
- [ ] **Step 4:** Run — confirm green.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/providers/translation/base.py tests/providers/translation/test_base.py
  #   git commit -m "feat(providers): translation provider interface + registry"
  ```

---

## Task 3: Google translation provider

**Files:**
- Create: `src/ocr_translator/providers/translation/google.py`
- Test:   `tests/providers/translation/test_google.py`

**Interfaces:**
- Consumes: `TranslationProvider`, `TranslationError` (Task 2)
- Produces:
  - `class GoogleProvider(TranslationProvider)` — registered under name `"google"`.

**Behavior contract:**
- Uses the unofficial Google endpoint over HTTP; no API key. Auto-detect when `source == "auto"`.
- `translate` returns the translated string for a normal response.
- `detect_language(text)` returns the detected ISO code.
- Network error, timeout, or non-2xx response → raises `TranslationError` (never bubbles a raw `requests`/HTTP exception).
- Empty/whitespace-only `text` → returns `""` without making a network call.
- Uses a short timeout (≤ 5s).

**Test scenarios (mock HTTP — no real network):**
- Well-formed mocked response → `translate("hola","auto","en")` returns the expected English text and the request used `sl=auto`.
- `detect_language("bonjour")` → `"fr"` given a mocked detection response.
- HTTP timeout → raises `TranslationError`.
- Non-2xx (e.g. 503) → raises `TranslationError`.
- `translate("   ", "auto", "en")` → returns `""` and asserts HTTP was NOT called.

**Acceptance criteria:**
- All scenarios green with HTTP fully mocked (patch the HTTP client, assert on call args).
- No real network access in the test run.
- Raises only `TranslationError` for failure modes.

**Implementation notes:**
- The endpoint response is a nested JSON array; the translated segments live in `data[0][*][0]`. Concatenate them in order. (This exact shape is non-obvious, so it is pinned here — the parsing code itself is yours to write.)

- [ ] **Step 1:** Write tests with the HTTP client mocked (`pytest-mock`), including call-arg assertions.
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement `google.py` (your design; register under `"google"`).
- [ ] **Step 4:** Run — confirm green.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/providers/translation/google.py tests/providers/translation/test_google.py
  #   git commit -m "feat(providers): Google translation provider"
  ```

---

## Task 4: Argos (offline) translation provider

**Files:**
- Create: `src/ocr_translator/providers/translation/argos.py`
- Test:   `tests/providers/translation/test_argos.py`

**Interfaces:**
- Consumes: `TranslationProvider`, `TranslationError` (Task 2)
- Produces:
  - `class ArgosProvider(TranslationProvider)` — registered under name `"argos"`.

**Behavior contract:**
- Translates locally via `argostranslate`; detects language offline (via `argostranslate`/langdetect).
- If the required language-pair model is not installed → raises `TranslationError` with a message that names the missing pair (e.g. `"model not installed: fr->en"`).
- Empty/whitespace `text` → returns `""` without invoking the library.
- `supported_languages()` returns the codes of installed models.

**Test scenarios (mock `argostranslate` — no real models):**
- Installed pair mocked → `translate("hola","es","en")` returns mocked output.
- `detect_language` returns the mocked detected code.
- Missing pair → raises `TranslationError` naming the pair.
- Empty text → `""`, library not called.
- `supported_languages()` reflects the mocked installed set.

**Acceptance criteria:**
- All scenarios green with `argostranslate` mocked; no model downloads in tests.
- Failure modes raise only `TranslationError`.

**Implementation notes:** none (the library API is stable; mock it at the module boundary).

- [ ] **Step 1:** Write tests with `argostranslate` mocked.
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement `argos.py` (your design; register under `"argos"`).
- [ ] **Step 4:** Run — confirm green.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/providers/translation/argos.py tests/providers/translation/test_argos.py
  #   git commit -m "feat(providers): Argos offline translation provider"
  ```

---

## Task 5: OCR engine interface + Tesseract engine

**Files:**
- Create: `src/ocr_translator/providers/ocr/__init__.py`, `src/ocr_translator/providers/ocr/base.py`, `src/ocr_translator/providers/ocr/tesseract.py`
- Test:   `tests/providers/ocr/test_tesseract.py`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `class OCRError(Exception)`
  - `class OCREngine(abc.ABC)`:
    - `extract_text(self, image: "PIL.Image.Image", lang: str) -> str`
    - `available_languages(self) -> list[str]`
    - `is_available(self) -> bool`
  - `class TesseractEngine(OCREngine)`

**Behavior contract:**
- `is_available()` → `True` iff the Tesseract binary is found; never raises.
- `extract_text` on an available engine returns the recognized text (may be `""`).
- Tesseract not installed → `extract_text` raises `OCRError`; `available_languages()` returns `[]`.
- Requested `lang` not in `available_languages()` → raises `OCRError` naming the language.
- Recognized-but-empty result → returns `""` (not an error).

**Test scenarios (mock `pytesseract` — no real binary):**
- Available + text → `extract_text(img,"eng")` returns mocked text.
- Not installed (mock raises `TesseractNotFoundError`) → `is_available()` is `False`; `extract_text` raises `OCRError`.
- `lang="deu"` not in available set → raises `OCRError` mentioning `"deu"`.
- Empty recognition → returns `""`.

**Acceptance criteria:**
- All scenarios green with `pytesseract` mocked.
- `is_available()` never raises.

**Implementation notes:** none.

- [ ] **Step 1:** Write tests with `pytesseract` mocked.
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement `base.py` + `tesseract.py` (your design).
- [ ] **Step 4:** Run — confirm green.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/providers/ocr/ tests/providers/ocr/test_tesseract.py
  #   git commit -m "feat(providers): OCR interface + Tesseract engine"
  ```

---

## Task 6: Platform interfaces + factory

**Files:**
- Create: `src/ocr_translator/platform/__init__.py`, `src/ocr_translator/platform/base.py`, `src/ocr_translator/platform/factory.py`
- Test:   `tests/platform/test_factory.py`

**Interfaces:**
- Consumes: nothing
- Produces (all in `base.py`, defined as `abc.ABC` or `typing.Protocol`):
  - `class GlobalHotkeys`: `register(self, action: str, combo: str) -> bool`; `unregister(self, action: str) -> None`; `set_handler(self, handler: Callable[[str], None]) -> None`
  - `class ScreenCapture`: `select_region(self) -> "PIL.Image.Image | None"`  (`None` when the user cancels)
  - `class TextSelection`: `get(self) -> str`
  - `class Clipboard`: `read(self) -> str`; `write(self, text: str) -> None`
  - `@dataclass class PlatformServices`: `hotkeys: GlobalHotkeys`, `capture: ScreenCapture`, `selection: TextSelection`, `clipboard: Clipboard`
  - In `factory.py`: `create_platform_services() -> PlatformServices`

**Behavior contract:**
- `create_platform_services()` inspects `sys.platform` and returns a `PlatformServices` wired with Windows implementations on `win32` and GNOME implementations otherwise.
- An unsupported platform raises `RuntimeError` with a clear message.
- `factory.py` is the ONLY module in the non-platform codebase that imports from `platform/windows/` or `platform/linux_gnome/` (lazily, inside the branches).

**Test scenarios:**
- `sys.platform == "win32"` (patched) → returns a `PlatformServices` whose members are the Windows implementations (assert types; the concrete modules may be import-mocked).
- `sys.platform == "linux"` → returns the GNOME implementations.
- An unsupported value (e.g. `"darwin"`) → raises `RuntimeError`.

**Acceptance criteria:**
- All scenarios green.
- Interface signatures match **Interfaces** exactly (consumers in later tasks depend on them).
- Import isolation respected: only `factory.py` touches concrete platform packages.

**Implementation notes:**
- Do the concrete-package imports lazily inside each branch so importing `factory` never pulls in the other OS's dependencies.

- [ ] **Step 1:** Write tests patching `sys.platform` and mocking the concrete platform modules.
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement `base.py` + `factory.py` (your design).
- [ ] **Step 4:** Run — confirm green.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/platform/base.py src/ocr_translator/platform/factory.py tests/platform/test_factory.py
  #   git commit -m "feat(platform): service interfaces + OS factory"
  ```

---

## Task 7: Orchestrator (core flows) — with fakes

**Files:**
- Create: `src/ocr_translator/core/__init__.py`, `src/ocr_translator/core/orchestrator.py`
- Test:   `tests/core/test_orchestrator.py`

**Interfaces:**
- Consumes: `PlatformServices` + its interfaces (Task 6), `TranslationProvider` (Task 2), `OCREngine` (Task 5), `Settings` (Task 1)
- Produces:
  - `@dataclass class TranslationResult`: `source_text: str`, `translated_text: str`, `source_lang: str`, `target_lang: str`
  - `@dataclass class OCRResult`: `text: str`
  - `class Empty` sentinel result (or `None`) returned when there is no input — see contract
  - `class Orchestrator`:
    - `__init__(self, services: PlatformServices, provider: TranslationProvider, ocr: OCREngine, settings: Settings)`
    - `translate_selection(self) -> TranslationResult | None`
    - `ocr_and_translate(self) -> TranslationResult | None`
    - `ocr_only(self) -> OCRResult | None`
    - `translate_text(self, text: str, source: str | None, target: str) -> TranslationResult`

**Behavior contract (this is the most valuable layer to test — no OS, no network; use fakes):**
- `translate_selection`: reads `selection.get()`; if empty/whitespace → returns `None` (caller shows the discreet "no text selected" popup). Otherwise detects source (when settings say `auto`), translates to `settings.target_language`, returns `TranslationResult`.
- `ocr_and_translate`: calls `capture.select_region()`; if `None` (cancelled) → returns `None` silently; if the image yields empty OCR text → returns `None`; otherwise translates and returns `TranslationResult`.
- `ocr_only`: like above through OCR; returns `OCRResult` (no translation). If `settings.copy_ocr_to_clipboard` is `True`, also calls `clipboard.write(text)`.
- `translate_text`: translates the given text; `source=None` means auto-detect.
- Provider/OCR exceptions (`TranslationError`, `OCRError`) propagate to the caller unchanged (the UI layer maps them to popups) — the orchestrator does not swallow them.

**Test scenarios (inject in-memory fakes for services + provider + OCR):**
- Selection empty → `translate_selection()` returns `None`; provider NOT called.
- Selection non-empty → returns `TranslationResult` with the fake provider's output and `target_lang == settings.target_language`.
- OCR flow, capture cancelled (`select_region` → `None`) → `ocr_and_translate()` returns `None`; OCR NOT called.
- OCR flow, empty recognized text → returns `None`; provider NOT called.
- OCR flow, success → returns `TranslationResult` with recognized source text + translation.
- `ocr_only` with `copy_ocr_to_clipboard=True` → `clipboard.write` called with the text.
- `translate_text("hi", None, "pt")` → provider called with auto-detect.
- Provider raises `TranslationError` → it propagates out of `translate_selection`.

**Acceptance criteria:**
- All scenarios green using fakes only — zero real OS/network/OCR.
- No swallowing of `TranslationError`/`OCRError`.
- Signatures match **Interfaces** exactly.

**Implementation notes:** none — this is pure coordination logic; design it yourself against the fakes.

- [ ] **Step 1:** Write the fakes + tests for all scenarios.
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement `orchestrator.py` (your design).
- [ ] **Step 4:** Run — confirm green.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/core/orchestrator.py tests/core/test_orchestrator.py
  #   git commit -m "feat(core): orchestrator flows with fakes"
  ```

---

## Task 8: IPC server/client + single instance

**Files:**
- Create: `src/ocr_translator/core/ipc.py`, `src/ocr_translator/core/single_instance.py`
- Test:   `tests/core/test_ipc.py`, `tests/core/test_single_instance.py`

**Interfaces:**
- Consumes: nothing (uses stdlib sockets)
- Produces:
  - `class IpcServer`: `__init__(self, handler: Callable[[str], None])`; `start(self) -> None`; `stop(self) -> None`; property `address`
  - `send_action(action: str) -> bool`  (returns `True` if a live instance received it, `False` if none is listening)
  - `class SingleInstance`: context manager; `__enter__ -> bool` (`True` if this is the primary instance), releases the lock on `__exit__`.

**Behavior contract:**
- `IpcServer` listens on a local socket (Unix socket on Linux, localhost TCP or named pipe on Windows) and calls `handler(action)` for each received action string.
- `send_action` connects to that socket and delivers the action; if nothing is listening → returns `False` (no exception).
- A stale/orphaned lock or socket from a dead process is detected and recovered (a fresh primary can acquire it).
- `SingleInstance.__enter__` returns `True` for the first holder, `False` while another live holder exists.

**Test scenarios:**
- Start `IpcServer` with a recording handler → `send_action("translate-selection")` → handler receives exactly that string.
- `send_action` with no server running → returns `False`.
- First `SingleInstance` → `True`; a second concurrent one → `False`; after the first exits, a new one → `True`.
- Orphaned lock file present (simulate a dead PID) → a new `SingleInstance` still acquires (`True`).

**Acceptance criteria:**
- All scenarios green using a temp socket/lock path (`tmp_path`); no reliance on a real running app.
- `send_action` never raises on a missing server.

**Implementation notes:**
- Keep the socket/lock path derivation in one small helper so tests can point it at `tmp_path`.

- [ ] **Step 1:** Write tests (temp paths; start/stop server within the test).
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement `ipc.py` + `single_instance.py` (your design).
- [ ] **Step 4:** Run — confirm green.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/core/ipc.py src/ocr_translator/core/single_instance.py tests/core/
  #   git commit -m "feat(core): local IPC + single-instance guard"
  ```

---

## Task 9: ResultPopup (PyQt6) — light UI test

**Files:**
- Create: `src/ocr_translator/ui/__init__.py`, `src/ocr_translator/ui/result_popup.py`
- Test:   `tests/ui/test_result_popup.py`

**Interfaces:**
- Consumes: `TranslationResult`, `OCRResult` (Task 7), `Clipboard` (Task 6)
- Produces:
  - `class ResultPopup(QWidget)`:
    - `__init__(self, clipboard: Clipboard)`
    - `show_result(self, result: "TranslationResult | OCRResult") -> None`
    - `show_message(self, text: str) -> None`  (for discreet notices like "no text selected")

**Behavior contract:**
- `show_result` with a `TranslationResult` displays source + translated text; with an `OCRResult` displays the recognized text only.
- Clicking the "copy" button calls `clipboard.write(...)` with the translated text (or the OCR text for `OCRResult`).
- `show_message` displays a short notice with no copy button.
- The popup does not aggressively steal focus (set the appropriate non-activating window flags).

**Test scenarios (pytest-qt, `qtbot`; fake `Clipboard`):**
- `show_result(TranslationResult(...))` → both source and translated strings are present in the rendered widgets.
- Clicking copy → fake `clipboard.write` called with the translated text.
- `show_result(OCRResult("abc"))` → recognized text shown; copy writes `"abc"`.
- `show_message("no text selected")` → message shown, no copy button present.

**Acceptance criteria:**
- All scenarios green under `pytest-qt` with a fake clipboard.
- No real system clipboard access in tests.

**Implementation notes:** none.

- [ ] **Step 1:** Write `pytest-qt` tests with a fake `Clipboard`.
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement `result_popup.py` (your design).
- [ ] **Step 4:** Run — confirm green.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/ui/result_popup.py tests/ui/test_result_popup.py
  #   git commit -m "feat(ui): result popup with copy"
  ```

---

## Task 10: MainWindow (PyQt6) — light UI test

**Files:**
- Create: `src/ocr_translator/ui/main_window.py`
- Test:   `tests/ui/test_main_window.py`

**Interfaces:**
- Consumes: `Orchestrator` (Task 7)
- Produces:
  - `class MainWindow(QMainWindow)`:
    - `__init__(self, orchestrator: Orchestrator)`
    - source/target text areas, a language selector with an "auto" option, a swap-languages button, a translate button, a copy-result button, and a provider selector.

**Behavior contract:**
- Clicking translate calls `orchestrator.translate_text(source_text, source, target)` with the current field values (`source="auto"` maps to `None`) and renders the returned `translated_text` in the target area.
- The swap button exchanges source/target languages (and their text).
- The copy button copies the current target text via the orchestrator's clipboard path.
- Long-running translate runs off the UI thread; the result is applied on the main thread (contract: assert the orchestrator is invoked with the right args — the threading mechanism is yours).

**Test scenarios (pytest-qt; the `Orchestrator` is a mock/fake):**
- Enter source text, click translate → `orchestrator.translate_text` called with the field values; target area shows the returned translation.
- `source` selector on "auto" → orchestrator called with `source=None`.
- Swap button → source/target language selectors are exchanged.

**Acceptance criteria:**
- All scenarios green with a mocked orchestrator.
- No real network/OS in tests.

**Implementation notes:**
- For deterministic tests, keep the "run off-thread then apply result" seam injectable so tests can run it synchronously.

- [ ] **Step 1:** Write `pytest-qt` tests with a mock orchestrator.
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement `main_window.py` (your design).
- [ ] **Step 4:** Run — confirm green.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/ui/main_window.py tests/ui/test_main_window.py
  #   git commit -m "feat(ui): main window"
  ```

---

## Task 11: SettingsDialog + Tray

**Files:**
- Create: `src/ocr_translator/ui/settings_dialog.py`, `src/ocr_translator/ui/tray.py`
- Test:   `tests/ui/test_settings_dialog.py`

**Interfaces:**
- Consumes: `Settings`, `save_settings` (Task 1), `Orchestrator` (Task 7)
- Produces:
  - `class SettingsDialog(QDialog)`: `__init__(self, settings: Settings)`; `result_settings(self) -> Settings` (the edited copy)
  - `class Tray(QSystemTrayIcon)`: `__init__(self, orchestrator: Orchestrator, on_open_window: Callable[[], None], on_open_settings: Callable[[], None], on_quit: Callable[[], None])`

**Behavior contract:**
- `SettingsDialog` edits: translation provider, default target language, OCR languages, `copy_ocr_to_clipboard`, and displays the GNOME hotkey command strings (read-only instructions). `result_settings()` returns a `Settings` reflecting the edits without mutating the input.
- `Tray` menu offers: open window, run each action manually (translate-selection / ocr-and-translate / ocr-only), open settings, quit — wired to the injected callbacks / orchestrator methods.

**Test scenarios (pytest-qt):**
- Change target language + toggle `copy_ocr_to_clipboard` in the dialog → `result_settings()` reflects the changes; the original `Settings` is unchanged.
- The dialog shows the GNOME command strings for the configured actions.
- Triggering the tray "translate-selection" menu item → `orchestrator.translate_selection` called.
- Triggering "open settings" → `on_open_settings` callback fired.

**Acceptance criteria:**
- All scenarios green with mocks/fakes; input `Settings` never mutated in place.

**Implementation notes:** none.

- [ ] **Step 1:** Write `pytest-qt` tests.
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement `settings_dialog.py` + `tray.py` (your design).
- [ ] **Step 4:** Run — confirm green.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/ui/settings_dialog.py src/ocr_translator/ui/tray.py tests/ui/test_settings_dialog.py
  #   git commit -m "feat(ui): settings dialog + tray"
  ```

---

## Task 12: App bootstrap + CLI entrypoint

**Files:**
- Create: `src/ocr_translator/app.py`, `src/ocr_translator/__main__.py`
- Test:   `tests/test_entrypoint.py`

**Interfaces:**
- Consumes: `create_platform_services` (Task 6), `Orchestrator` (Task 7), `IpcServer` + `send_action` + `SingleInstance` (Task 8), `load_settings` (Task 1), UI classes (Tasks 9–11), providers/OCR registries
- Produces:
  - `parse_args(argv: list[str]) -> argparse.Namespace`  (supports `--action=<translate-selection|ocr-and-translate|ocr-only>`)
  - `main(argv: list[str] | None = None) -> int`

**Behavior contract:**
- No `--action` and no live instance → become the primary: build services + orchestrator + UI + tray, start `IpcServer`, run the Qt loop.
- `--action=<x>` with a live instance → `send_action(x)` returns `True` → exit `0` without opening a window.
- `--action=<x>` with NO live instance → start the instance and perform the action.
- A second launch with no action while an instance is live → focus the existing window (via an IPC "focus" action) and exit.
- `parse_args` rejects an unknown `--action` value (non-zero exit / `SystemExit`).

**Test scenarios (mock QApplication, factory, IpcServer/send_action, SingleInstance — do NOT spin a real Qt loop):**
- `parse_args(["--action=ocr-only"])` → `action == "ocr-only"`.
- `parse_args(["--action=bogus"])` → raises `SystemExit`.
- `main(["--action=translate-selection"])` with `send_action` mocked to `True` → returns `0`, QApplication NOT constructed.
- `main([])` as primary (SingleInstance → `True`, send nothing) → constructs the app and starts `IpcServer` (assert on the mocks).

**Acceptance criteria:**
- All scenarios green with the Qt loop and platform factory fully mocked.
- The IPC-dispatch path never constructs a QApplication.

**Implementation notes:**
- Keep `main` thin and inject the collaborators (or patch them at module scope) so the branches are testable without a real event loop.

- [ ] **Step 1:** Write tests with QApplication/factory/IPC mocked.
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement `app.py` + `__main__.py` (your design).
- [ ] **Step 4:** Run — confirm green.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/app.py src/ocr_translator/__main__.py tests/test_entrypoint.py
  #   git commit -m "feat(app): bootstrap + CLI action dispatch"
  ```

---

## Task 13: Windows platform implementations (manual verification)

**Files:**
- Create: `src/ocr_translator/platform/windows/__init__.py`, `.../hotkeys.py`, `.../capture.py`, `.../selection.py`, `.../clipboard.py`
- Test:   `docs/superpowers/manual-checklists/windows.md` (manual checklist — these need a real Windows desktop)

**Interfaces:**
- Consumes: the interfaces in `platform/base.py` (Task 6)
- Produces: concrete `GlobalHotkeys`, `ScreenCapture`, `TextSelection`, `Clipboard` for Windows, discoverable by `factory.py`.

**Behavior contract:**
- `GlobalHotkeys`: register via `RegisterHotKey` (through the chosen lib); a failed registration (combo already taken) returns `False` and is surfaced in settings — it does not crash.
- `ScreenCapture.select_region()`: full-screen static screenshot shown fullscreen with slight dimming (screen "freezes"); user drags a rectangle; returns the cropped image, or `None` on ESC.
- `TextSelection.get()`: save clipboard → simulate Ctrl+C → read → restore clipboard.
- `Clipboard`: read/write the Windows clipboard.

**Manual checklist (run on a real Windows machine):**
- [ ] Register each configured hotkey; a taken combo shows a clear settings warning, app still runs.
- [ ] Trigger capture → screen freezes with dimming → drag rectangle → correct region returned.
- [ ] Press ESC during capture → no popup, action cancelled silently.
- [ ] `TextSelection.get()` returns the highlighted text and the original clipboard content is restored afterward.
- [ ] Clipboard read/write round-trips arbitrary Unicode text.

**Acceptance criteria:**
- Pure logic within these modules (e.g. rectangle math, clipboard save/restore bookkeeping) has unit tests where feasible with Win32 calls mocked.
- The manual checklist is executed and all items pass on Windows.

**Implementation notes:**
- Isolate any testable pure logic (crop-rect computation, save/restore sequencing) from the raw Win32 calls so it can be unit-tested with the OS calls mocked.

- [ ] **Step 1:** Write unit tests for the extractable pure logic (Win32 mocked).
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement the Windows modules (your design).
- [ ] **Step 4:** Run unit tests (green) AND execute the manual checklist on Windows.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/platform/windows/ docs/superpowers/manual-checklists/windows.md
  #   git commit -m "feat(platform/windows): hotkeys, capture, selection, clipboard"
  ```

---

## Task 14: GNOME/Wayland platform implementations (manual verification)

**Files:**
- Create: `src/ocr_translator/platform/linux_gnome/__init__.py`, `.../hotkeys.py`, `.../capture.py`, `.../selection.py`, `.../clipboard.py`
- Test:   `docs/superpowers/manual-checklists/gnome-wayland.md` (manual checklist — needs a real GNOME/Wayland session)

**Interfaces:**
- Consumes: the interfaces in `platform/base.py` (Task 6)
- Produces: concrete GNOME/Wayland implementations discoverable by `factory.py`.

**Behavior contract:**
- `GlobalHotkeys`: no direct grab. The app exposes the exact `ocr-translator --action=<x>` commands for the user to bind as GNOME custom shortcuts (shown in settings); optionally attempt the `GlobalShortcuts` XDG portal.
- `ScreenCapture.select_region()`: use the XDG Screenshot portal in interactive mode — GNOME's own UI freezes the screen and selects the region, returning the image; ESC/cancel → `None`. Portal denied/unavailable → raise a clear error the UI can explain.
- `TextSelection.get()`: read the primary selection via `wl-paste --primary`.
- `Clipboard`: read/write via `wl-clipboard`.

**Manual checklist (run on GNOME-on-Wayland):**
- [ ] Bind the shown commands as GNOME custom shortcuts; triggering each delivers the action to the live instance via IPC.
- [ ] Capture via portal freezes the screen, lets you select a region, returns the correct image.
- [ ] Cancel the portal → action aborts silently (no error popup).
- [ ] Portal permission denied → clear message explaining the portal permission is needed.
- [ ] `wl-paste --primary` returns the current primary selection.
- [ ] Clipboard read/write round-trips Unicode text.

**Acceptance criteria:**
- Testable pure logic (e.g. building the shortcut command strings, parsing `wl-paste` output) has unit tests with subprocess/portal calls mocked.
- The manual checklist is executed and all items pass on GNOME/Wayland.

**Implementation notes:**
- Wrap `wl-paste`/`wl-copy` and the portal `dbus` calls behind thin functions so the surrounding logic is unit-testable with them mocked.

- [ ] **Step 1:** Write unit tests for extractable pure logic (subprocess/portal mocked).
- [ ] **Step 2:** Run — confirm failure.
- [ ] **Step 3:** Implement the GNOME modules (your design).
- [ ] **Step 4:** Run unit tests (green) AND execute the manual checklist on GNOME/Wayland.
- [ ] **Step 5:** Stage + suggest commit:
  ```bash
  git add src/ocr_translator/platform/linux_gnome/ docs/superpowers/manual-checklists/gnome-wayland.md
  #   git commit -m "feat(platform/gnome): portal capture, primary selection, clipboard, hotkey instructions"
  ```

---

## Notes on this format (why it reads this way)

- **Interfaces blocks are the hard contract.** They are the only channel between isolated executors; keeping signatures exact is what lets independently-implemented tasks compose.
- **Behavior contract + Test scenarios replace dictated code.** Vagueness is still banned — but at the contract level ("invalid input → raises X"), not by pasting the implementation. The executor writes tests from the scenarios, watches them fail, then designs the code.
- **Implementation notes carry code only where ambiguity is costly** (e.g. Task 3's non-obvious Google response shape). Everywhere else, the how is the executor's to decide.
- **Two-stage review still applies** — spec compliance (does it satisfy the contract?) then code quality — so the executor's freedom is bounded by acceptance criteria and review, not by transcription.
