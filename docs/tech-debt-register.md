# Tech Debt Register

Items are logged here when a story closes with ADVISORY deviations the developer
accepts rather than fixes immediately. Format: `[date] (story): description`.

---

- **2026-05-30** (Story 003 — PranaCatalog Autoload): No `class_name PranaCatalog` in `src/data/prana_catalog.gd`. Story AC and ADR-0008 Implementation snippet both specify `class_name PranaCatalog extends Node`, but Godot 4.6 raises a parse error ("hides autoload singleton") when class_name matches the Autoload node name. Implementation is correct for Godot 4.6. Required action: update ADR-0008 code snippet and Story-003 AC to document the no-class_name constraint explicitly. — tracked from `production/epics/prana-data/story-003-prana-catalog-autoload.md`

- **2026-05-30** (Story 003 — PranaCatalog Autoload): G4 — push_error() assertions absent from AC-3/AC-5/AC-6 guard tests. GdUnit4 v6 has no push_error capture API; null-return assertions cover the observable contract. Required action: investigate GdUnit4 v6 error-monitoring APIs; if a capture mechanism exists in a future version, add push_error assertions to those 4 tests. — tracked from `production/epics/prana-data/story-003-prana-catalog-autoload.md`

- **2026-05-30** (Story 004 — Five Prana Type .tres Data Files): Filename spec mismatch — story AC specified `prana_type_0.tres`–`prana_type_4.tres` but `prana_catalog.gd` uses element-named paths (`prana_fire.tres` etc.). Files were authored using catalog's expected names (correct for runtime). Required action: update Story 004 AC wording and any downstream story specs that reference the old filenames to use element-named convention. — tracked from `production/epics/prana-data/story-004-prana-type-tres-files.md`

- **2026-05-30** (Story 002 — EnemyCatalog Autoload): `Dictionary` untyped used instead of `Dictionary[int, EnemyType]`. Code review recommended typed Dictionary (supported in Godot 4.4+), but Godot 4.6.2 headless fails to resolve custom class_name types in typed Dictionary declarations during Autoload parse phase. Reverted to untyped `Dictionary` with typed loop variables for safety. Required action: re-test typed Dictionary with a minimal repro in Godot editor mode; if it works there, apply the typed form and add a note that typed Dictionary requires editor-mode or post-scan Autoload registration. — tracked from `production/epics/enemy-data/story-002-enemy-catalog-autoload.md`

- **2026-05-30** (Story 002 — EnemyCatalog Autoload): Godot class cache (`global_script_class_cache.cfg`) not updated for scripts created outside the editor. `enemy_type.gd` was written by AI file tools without opening the Godot editor; its `class_name EnemyType` was not added to `.godot/global_script_class_cache.cfg`. Required action: establish a workflow note — after creating new GDScript files with `class_name` outside the editor, either (a) open the Godot project in the editor once to trigger a rescan, or (b) manually add the class entry to `global_script_class_cache.cfg` for headless CI. Add this to the CI/CD setup documentation. — tracked from `production/epics/enemy-data/story-002-enemy-catalog-autoload.md`
