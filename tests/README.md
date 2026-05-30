# Test Infrastructure

**Engine**: Godot 4.6
**Test Framework**: GdUnit4 (GDScript-native, integrated in Godot editor)
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-05-30

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, pure logic)
  integration/    # Cross-system and signal-chain tests
  smoke/          # Critical path checklist for /smoke-check gate
  evidence/       # Screenshots and manual test sign-off records
```

## Running Tests

**In-editor (development):**
1. Open the Godot editor
2. Click the GdUnit4 panel (bottom bar after plugin is enabled)
3. Right-click any test file or directory → Run

**Headless (CI / command line):**
```
godot --headless --script tests/gdunit4_runner.gd
```

## Installing GdUnit4

1. Open Godot → AssetLib → search "GdUnit4" → Download & Install
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Restart the editor
4. Verify: `res://addons/gdunit4/` exists in your project

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]()`
- **Example**: `health_damage_test.gd` → `test_apply_damage_reduces_hp_by_expected_amount()`

## Story Type → Required Test Evidence

| Story Type | Required Evidence | Location | Gate Level |
|---|---|---|---|
| **Logic** (formulas, state machines) | Automated unit test — must pass | `tests/unit/[system]/` | BLOCKING |
| **Integration** (multi-system) | Integration test OR documented playtest | `tests/integration/[system]/` | BLOCKING |
| **Visual/Feel** (animation, VFX) | Screenshot + lead sign-off | `tests/evidence/` | ADVISORY |
| **UI** (menus, HUD) | Manual walkthrough doc OR interaction test | `tests/evidence/` | ADVISORY |
| **Config/Data** (balance tuning) | Smoke check pass | `production/qa/smoke-*.md` | ADVISORY |

## Required Tests (per coding-standards.md)

Before any sprint ships, the following must have passing unit tests:
- Prana combination resolution (all formula variants)
- Meta-progression currency math
- Dungeon generation sanity checks
- Enemy state machines (IDLE → PURSUING → ATTACKING → STUNNED → DEAD transitions)

## Test Isolation Rules

- Each test sets up and tears down its own state — no cross-test dependencies
- No random seeds unless explicitly testing RNG distribution
- No time-dependent assertions — use deterministic inputs
- Unit tests do not call AudioSystem, load `.tres` files, or depend on Autoloads
  being initialized — use dependency injection or mock objects

## CI

Tests run automatically on every push to `main` and on every pull request.
A failing test suite blocks merging. Never skip or disable a failing test to
make CI pass — fix the underlying issue.
