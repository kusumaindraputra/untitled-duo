# The Last Cipher

> 2D isometric roguelike — Godot 4.6 · GDScript · Solo dev · Production (First Playable)

A roguelike where Fayde composes spells by arranging Prana types in a 3×3 drag-and-drop grid. Each room is a two-phase cycle: **Preparation** (peek the wave → arrange the grid to exploit enemy elemental affinities) then **Combat** (move, dash, cast the pre-arranged combo). The skill ceiling is understanding the 5 Prana types and how they interact — not reflexes.

---

## Development Status

**Stage**: Production · Sprint 3 · First Playable target: 2026-06-14

| Layer | System | Status |
|-------|--------|--------|
| Foundation | Prana Data (GameEnums + PranaCatalog + 5 .tres) | ✅ Complete |
| Foundation | Enemy Data (EnemyCatalog + 4 .tres) | ✅ Complete |
| Foundation | Game State & Scene Flow (GSM + SceneManager + IsometricRoom) | ✅ Complete |
| Core | Health & Damage (Autoload #5 — full pipeline) | ✅ Complete · 32 tests |
| Core | Player Controller (movement, dash, footsteps, audio) | ✅ Complete · 37 tests |
| Core | Enemy Instance (FP AI + contact + death) | ✅ Complete · 37 tests |
| Core | Status Effects (Freeze + Burn + Stun stub) | 🟡 Story files created — implementing (S3-05) |
| Core | WaveManager (1 hardcoded wave, win condition) | 🔵 Story files pending (S3-06) |
| Core | Spell Casting & Effects (basic cast → apply_damage) | 🔵 Story files pending (S3-08) |
| Core | Combination Resolution | 🔵 Should Have (S3-15/16 — after Must Have complete) |
| Core | Prana Grid | ⚠️ Deferred — ADR-0013 engine verification pending (S3-02) |

**Test suite**: 288 unit/integration tests across 20 suites, all passing headless (GdUnit4 v6.1.3 · Godot 4.6.2)

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
| Drifter | Seeker — pursues Fayde at constant speed | Shadow/Voidblue | 20 | Low |
| Charger | Rusher — directional burst toward Fayde | Ice/Deepfrost | 35 | High |
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
| 5 | HealthAndDamage | Central HP registry — sole owner of all HP state |
| 6–10 | StatusEffectsManager, CombinationResolution, SpellCastingEffects, AudioSystem, RunManager | Planned — not yet implemented |

**13 accepted ADRs** covering: isometric view, autoload architecture, signal-driven design, float accumulator timers, persistent HUD, GameEnums, H&D singleton, PranaCatalog immutability, SC&E stat broker, player group convention, StatusEffects API, AudioSystem contract, PranaGrid dual-input focus model. Plus ADR-0014 (H&D↔WaveManager registration contract).

---

## Running Tests

```bash
# All tests headless
godot --headless --path . \
  -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/ \
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

Sprint tracking: `production/sprints/sprint-3.md`  
Epic index: `production/epics/index.md`  
Gate checks: `production/gate-checks/`

---

## License

MIT
