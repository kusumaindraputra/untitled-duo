# Coding Standards

- All game code must include doc comments on public APIs
- Every system must have a corresponding architecture decision record in `docs/architecture/`
- Gameplay values must be data-driven (external config), never hardcoded
- All public methods must be unit-testable (dependency injection over singletons)
- Commits must reference the relevant design document or task ID
- **Commit messages**: Use Conventional Commits format — `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`. Reference the story or task ID in the body (e.g., `Story: EPIC-001-S02`).
- **Verification-driven development**: Write tests first when adding gameplay systems.
  For UI changes, verify with screenshots. Compare expected output to actual output
  before marking work complete. Every implementation should have a way to prove it works.

# Design Document Standards

- All design docs use Markdown
- Each mechanic has a dedicated document in `design/gdd/`
- Documents must include these 8 required sections:
  1. **Overview** -- one-paragraph summary
  2. **Player Fantasy** -- intended feeling and experience
  3. **Detailed Rules** -- unambiguous mechanics
  4. **Formulas** -- all math defined with variables
  5. **Edge Cases** -- unusual situations handled
  6. **Dependencies** -- other systems listed
  7. **Tuning Knobs** -- configurable values identified
  8. **Acceptance Criteria** -- testable success conditions
- Balance values must link to their source formula or rationale

# Testing Standards

## Test Evidence by Story Type

All stories must have appropriate test evidence before they can be marked Done:

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| **Logic** (formulas, AI, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| **Integration** (multi-system) | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| **Visual/Feel** (animation, VFX, feel) | Screenshot + lead sign-off | `production/qa/evidence/` | ADVISORY |
| **UI** (menus, HUD, screens) | Manual walkthrough doc OR interaction test | `production/qa/evidence/` | ADVISORY |
| **Config/Data** (balance tuning) | Smoke check pass | `production/qa/smoke-[date].md` | ADVISORY |

## Automated Test Rules

- **Naming**: `[system]_[feature]_test.[ext]` for files; `test_[scenario]_[expected]` for functions
- **Determinism**: Tests must produce the same result every run — no random seeds, no time-dependent assertions
- **Isolation**: Each test sets up and tears down its own state; tests must not depend on execution order
- **No hardcoded data**: Test fixtures use constant files or factory functions, not inline magic numbers
  (exception: boundary value tests where the exact number IS the point)
- **Independence**: Unit tests do not call external APIs, databases, or file I/O — use dependency injection

## What NOT to Automate

- Visual fidelity (shader output, VFX appearance, animation curves)
- "Feel" qualities (input responsiveness, perceived weight, timing)
- Platform-specific rendering (test on target hardware, not headlessly)
- Full gameplay sessions (covered by playtesting, not automation)

## CI/CD Rules

- Automated test suite runs on every push to main and every PR
- No merge if tests fail — tests are a blocking gate in CI
- Never disable or skip failing tests to make CI pass — fix the underlying issue
- Engine-specific CI commands:
  - **Godot**: CI uses `gdUnit4-action@v1` (see `.github/workflows/tests.yml`). Local headless run: `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode`. Do NOT use `--script tests/gdunit4_runner.gd` — that file is documentation-only and does not inherit from MainLoop.
  - **Unity**: `game-ci/unity-test-runner@v4` (GitHub Actions)
  - **Unreal**: headless runner with `-nullrhi` flag

## Godot 4 Scene Wiring Rule

**Cross-sibling `@export Node` references must be wired programmatically in the parent node's
`_ready()`, not via NodePath text overrides in `.tscn`, when the target node appears after the
referencing node in scene order.**

Root cause: Godot 4 initializes nodes in the order they appear in the `.tscn` file. If node A
(e.g., CombatHUD under CanvasLayer) appears before node B (e.g., PlayerController) in the file,
then A's `_ready()` fires before B even exists — NodePath resolution for B silently returns null.

**Correct pattern**: wire in the shared parent's `_ready()`, which fires after ALL children have
completed their own `_ready()` calls:

```gdscript
# In the parent scene's _ready() (e.g., debug_game_loop.gd):
func _ready() -> void:
    var hud: CombatHUD = $CanvasLayer/CombatHUD
    hud.player_controller = $PlayerController   # B is guaranteed ready by now
    hud.fayde_node = $PlayerController
```

If the receiving node needs to react to assignment (e.g., connect a signal), use a GDScript
property setter with an `is_node_ready()` guard:

```gdscript
@export var player_controller: PlayerController = null:
    set(pc):
        # disconnect previous if needed
        player_controller = pc
        if is_instance_valid(pc) and is_node_ready():
            pc.some_signal.connect(_on_some_signal)
```

First documented fix: `debug_game_loop.gd` wiring CombatHUD → PlayerController (S5-05/S5-06, 2026-06-15).

## Node Teardown in Headless Tests (Godot — GdUnit4)

Use `node.free()` (not `node.queue_free()`) for nodes created with `.new()` that are **never added
to the scene tree**. `queue_free()` requires a running SceneTree to process the deletion queue —
orphaned nodes in headless tests never get freed, causing GdUnit4 to report orphan warnings and
exit code 101. See `.claude/rules/test-standards.md` for the full rule and pattern.
