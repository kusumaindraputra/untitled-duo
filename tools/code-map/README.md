# Code Map

Maps the GDScript in `src/`: which autoloads each file uses, which `class_name`
types it references, what it `preload`s, and where every signal is declared,
emitted and connected. Writes `docs/architecture/code-map.md` with Mermaid
diagrams and tables.

Static text analysis only: Python 3.10+ standard library, no Godot, no LLM, so it
runs in a cloud session or in CI in about a second.

```bash
python3 tools/code-map/code_map.py                 # writes docs/architecture/code-map.md
python3 tools/code-map/code_map.py --json map.json # also writes the raw data
python3 tools/code-map/code_map.py --stdout        # print, write nothing
```

Re-run it after a refactor and commit the report, so the diff shows how coupling
changed.

## What the report shows

- **Autoloads**: how many files use each one, which other autoloads it uses, and
  any **cycles** between autoloads.
- **Large files** (over 800 lines), with fan-out (what they depend on) and fan-in
  (what depends on them): the refactor candidates.
- **Top fan-in / fan-out** files.
- **Signals never connected** in `src/` (dead, or only used by tests) and **never
  emitted**.

## Limits

- Text based: comments and strings are ignored, and it cannot follow a signal
  reached through an untyped variable. A signal passed as a value or named as
  `&"name"` counts as an indirect use and is left out of the dead-signal lists.
- A signal name declared in more than one file is marked ambiguous and not checked.
- `tests/` is not scanned, so a signal listened to only by tests shows as never
  connected.
