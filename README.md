# The Last Cipher

> 2D isometric roguelike — Godot 4.6 · GDScript · Solo dev · Production (First Playable)

A roguelike where two android brothers, Ayden (power) and Faith (control), share one Prana core, swap in and out of every fight, and compose spells by arranging Prana types in a 3×3 drag-and-drop grid. Each room is a two-phase cycle: **Preparation** (peek the wave → arrange the grid to exploit enemy elemental affinities) then **Combat** (move, cast the pre-arranged combo, swap brothers; only Faith dashes). The skill ceiling is understanding the 5 Prana types and how they interact — not reflexes.

---

## Development Status

**Stage**: Production · Sprint 10 (First Playable fix pass) → wrapping up · Milestone: First Playable

| Layer | System | Status |
|-------|--------|--------|
| Foundation | Prana Data (GameEnums + PranaCatalog + 5 .tres) | ✅ Complete |
| Foundation | Enemy Data (EnemyCatalog + 6 .tres incl. Vault Sentinel & Warped Warden bosses) | ✅ Complete |
| Foundation | Game State & Scene Flow (GSM + SceneManager + IsometricRoom) | ✅ Complete |
| Foundation | Audio System (SFX registry + music FSM) | ✅ Complete |
| Core | Health & Damage · Player Controller · Enemy Instance · Status Effects | ✅ Complete |
| Core | Prana Grid (3×3 drag-and-drop + gamepad focus, ADR-0013) | ✅ Complete · live gamepad check pending |
| Core | Combination Resolution + Reaction & Cascade layer (ADR-0016) | ✅ Complete |
| Core | Spell Casting & Effects + SpellVFX pool (ADR-0015) | ✅ Complete |
| Feature | WaveManager (budgeted waves, per-floor enemy caps) | ✅ Complete |
| Feature | Level Generation (7 room templates, 5 layout styles) | ✅ Complete |
| Feature | RunManager (3 floors, bosses, rest rooms, sigils) | ✅ Complete |
| Presentation | CombatHUD, title / pause / win-loss screens | ✅ Complete |

**Test suite**: 1,120 unit/integration tests across 99 suites, all passing headless with 0 skipped and 0 orphans (GdUnit4 v6.1.3 · Godot 4.6.2)

**Demo build**: Windows / Linux / Web export presets verified headless — see [`docs/build/demo-export.md`](docs/build/demo-export.md).

**Still manual**: editor validation pass, ADR-0013 live gamepad test, external (non-developer) playtest — tracked in `production/sprint-status.yaml` (S9-01…S9-03).

---

## The Game

**Core loop**: Preparation phase → peek the incoming enemy wave → arrange 5 Prana types in a 3×3 grid to maximise elemental match-ups → Combat phase begins → move, dash, cast the locked combo.

**5 Prana types**:

| Prana | Color | Status Effect | Notes |
|-------|-------|--------------|-------|
| Ashfire | Crimson | Burn (DoT 2s) | Highest base damage |
| Voidblue | Deep indigo | Blind (50% miss chance) | 0.90× damage modifier |
| Stormgold | Amber | Stun (0.8s interrupt) | 1.15× damage modifier |
| Deepfrost | Ice blue | Freeze (root + 50% slow 2s) | 0.80× damage + guaranteed lockdown |
| Verdant | Emerald | Regenerate (HP over 3s) | 0.70× damage + sustain |

**3 enemy archetypes (First Playable)**:

| Enemy | Archetype | Affiliation | HP | Threat |
|-------|-----------|-------------|-----|--------|
| Drifter | Seeker — pursues the active brother at constant speed | Shadow/Voidblue | 20 | Low |
| Charger | Rusher — directional burst toward the active brother | Ice/Deepfrost | 35 | High |
| Cluster | Swarmer — moves in loose formation | Lightning/Stormgold | 12 | Low (swarm) |

FP wave: 3 Drifter + 2 Charger + 5 Cluster — Charger is Deepfrost-weak, making Freeze lockdown the smart play against the highest-threat unit.

---

## Architecture

**Engine**: Godot 4.6 · GDScript · Compatibility renderer (2D pixel art)
**Test framework**: GdUnit4 v6.1.3

**Autoload order** (ADR-0002):

| # | Autoload | Purpose |
|---|---------|---------|
| 1 | PranaCatalog | Immutable Prana type definitions |
| 2 | EnemyCatalog | Immutable enemy type definitions |
| 3 | GameStateManager | Game state machine (MAIN_MENU → PREPARATION → COMBAT → …) |
| 4 | SceneManager | Room swaps via SubSceneRoot |
| 5 | AudioSystem | SFX registry + music state machine |
| 6 | HealthAndDamage | Central HP registry — sole owner of all HP state |
| 7 | StatusEffectsManager | Freeze / Burn / Stun / Blind / Regenerate |
| 8 | CombinationResolution | Grid → SpellEffect, incl. Reactions & Cascade |
| 9 | SpellCastingEffects | Cast pipeline + stat broker |
| 10 | SpellVFX | Pooled spell/impact VFX and juice |
| 11 | RunManager | Floors, rooms, sigils, run win/loss |

**16 accepted ADRs** in `docs/architecture/` covering: isometric view, autoload architecture, signal-driven design, float accumulator timers, persistent HUD, GameEnums, H&D singleton, PranaCatalog immutability, SC&E stat broker, player group convention, StatusEffects API, AudioSystem contract, PranaGrid dual-input focus model, H&D↔WaveManager registration contract, SpellVFX particle pool, and the Prana Reaction & Cascade layer.

---

## Running Tests

```bash
# All tests headless
godot --headless --path . \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/unit -a res://tests/integration \
  --ignoreHeadlessMode

# Single suite
godot --headless --path . \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/unit/health-damage/health_damage_skeleton_test.gd \
  --ignoreHeadlessMode
```

Requires Godot 4.6.x in PATH. GdUnit4 addon is checked in at `addons/gdUnit4/`.

---

## Design Documents

| Document | Status |
|----------|--------|
| `design/gdd/prana-data.md` | Approved |
| `design/gdd/combination-resolution.md` | Approved |
| `design/gdd/spell-casting-effects.md` | Approved |
| `design/gdd/player-controller.md` | Approved |
| `design/gdd/health-damage.md` | Approved |
| `design/gdd/status-effects.md` | Approved |
| `design/gdd/enemy-ai.md` | Approved |
| `design/gdd/enemy-data.md` | Approved |
| `design/gdd/wave-encounter-system.md` | Approved |
| `design/gdd/combat-hud.md` | Approved |
| `design/gdd/game-state-scene-flow.md` | Approved |
| `design/gdd/run-management.md` | Approved |
| `design/gdd/audio-system.md` | Approved |
| `design/art/art-bible.md` | Complete (9 sections) |
| `design/ux/hud.md`, `main-menu.md`, `pause-menu.md` | All Approved |
| `design/accessibility-requirements.md` | Basic tier committed |
| `production/milestones/first-playable.md` | Defined |

---

## Project Management

Built with [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) — a 49-agent AI studio framework for Claude Code. All design reviews, architecture decisions, sprint planning, and code implementation are coordinated through the framework's skill pipeline.

Sprint tracking: `production/sprints/sprint-10-tasks.md`, `production/sprint-status.yaml`  
Epic index: `production/epics/index.md`  
Gate checks: `production/gate-checks/`

---

## License

MIT
