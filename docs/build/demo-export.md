# Demo Export — The Last Cipher

How to produce the playable demo builds from `export_presets.cfg`.
Verified 2026-09-24 with Godot 4.6.2-stable (headless, Linux host).

## Presets

| Preset | Output | Template needed |
|--------|--------|-----------------|
| `Windows Desktop` | `build/windows/TheLastCipher.exe` + `.pck` | `windows_release_x86_64.exe` |
| `Linux/X11` | `build/linux/TheLastCipher.x86_64` + `.pck` | `linux_release.x86_64` |
| `Web` | `build/web/index.html` (+ `.wasm`, `.pck`, `.js`) | `web_nothreads_release.zip` |

`build/` is gitignored. All three presets share one exclude filter so the shipped
`.pck` carries no test code:

```
addons/gdUnit4/*, tests/*, prototypes/*, reports/*, build/*
```

GdUnit4 is an editor plugin only; no autoload or runtime script references it, so
excluding it is safe. Pack size drops from ~17.0 MB to ~15.7 MB.

The Web preset uses the **no-threads** variant (`variant/thread_support=false`), so
it runs on itch.io and plain static hosts without COOP/COEP headers.

## One-time setup: export templates

Editor: **Editor → Manage Export Templates → Download and Install** (4.6.2).

Headless / CI: download `Godot_v4.6.2-stable_export_templates.tpz` from the
Godot GitHub release and unzip its `templates/` folder into:

| OS | Path |
|----|------|
| Linux | `~/.local/share/godot/export_templates/4.6.2.stable/` |
| Windows | `%APPDATA%\Godot\export_templates\4.6.2.stable\` |
| macOS | `~/Library/Application Support/Godot/export_templates/4.6.2.stable/` |

Only the three template files in the table above are needed for these presets.

## Build

Editor: **Project → Export → Export All** (Release).

Command line (run from the repo root; create the output folders first):

```bash
mkdir -p build/windows build/linux build/web
godot --headless --path . --import
godot --headless --path . --export-release "Windows Desktop"
godot --headless --path . --export-release "Linux/X11"
godot --headless --path . --export-release "Web"
```

The only expected warning is
`Detected another project.godot at res://prototypes/rune-grid-concept` —
that prototype is intentionally ignored.

## Smoke check

```bash
# Boots the exported build to the main menu and quits after 600 frames
./build/linux/TheLastCipher.x86_64 --headless --quit-after 600
```

Expect exit code 0 and no `SCRIPT ERROR` lines. Then do one manual run on real
hardware: title → Begin Run → clear a room → pause (ESC) → win or lose screen.

To test the Web build locally, serve the folder over HTTP (opening the file
directly will not work):

```bash
python3 -m http.server --directory build/web 8000
```

## Distributing

Zip each platform folder as-is (`.exe`/binary and `.pck` must stay side by side).
For itch.io, upload `build/web/` zipped with `index.html` at the root and tick
"This file will be played in the browser".
