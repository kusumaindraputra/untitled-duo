# Level Design Roadmap — The Last Cipher

> **Created**: 2026-06-18
> **Author**: Kusuma Putra + Claude (Level Design Expert)
> **Scope**: FP → VS → MVP (full procedural dungeon generation)
> **Pillars**: Pillar 1 (Every Run Tells a Different Story), Pillar 3 (Chaos Has Consequences)

---

## Overview

Roadmap ini menerjemahkan masukan level design expert menjadi urutan kerja yang bisa ditrack.
Dibagi dalam 4 fase: **Foundation** (FP polish, heal debt), **Preparation** (VS paper design),
**Core** (VS implementation), **Polish** (MVP+ layer identity dan memory anchors).

Setiap task punya ID, estimated effort, dependency, dan acceptance criteria.

---

## Fase 1: Foundation — FP Polish & Heal Debt (Sprint 10–11)

*Tidak menambah scope FP. Memperbaiki fondasi untuk VS.*

| ID | Task | Effort | Depends On | AC |
|----|------|--------|------------|-----|
| **LD-01** | Refactor `_generate_debris_positions()` — parameterized valid zone | S (0.5d) | — | Function accepts `valid_zone: Callable` or zone rect param; default behavior unchanged; existing tests pass |
| **LD-02** | Extract obstacle config constants ke data resource (.tres) | S (0.5d) | LD-01 | `ObstacleConfig.tres` holds count range, clearance distances, inner scale; `IsometricRoom` reads from it; tests pass |
| **LD-03** | Extract enemy pool config ke data resource (.tres) | S (0.5d) | — | `EnemyPoolConfig.tres` holds threat budget range, pool, guarantee types, costs; `WaveManager` reads from it; tests pass |
| **LD-04** | GDD → code sync: update `level-generation.md` tuning knobs table agar match actual code constants | XS (0.25d) | — | GDD table values match `isometric_room.gd` and `wave_manager.gd` constants exactly |
| **LD-05** | Refactor `_build_wave_composition()` — seed injection untuk test determinism | S (0.5d) | LD-03 | `_build_wave_composition(seed: int = -1)` — seed -1 = random, else deterministic; tests bisa assert exact composition |

**Fase 1 total**: ~2.25 hari | **Gate**: semua test hijau, tidak ada regression

---

## Fase 2: Preparation — Paper Design & Template Authoring (Sprint 11–12)

*Belum ada kode. Output adalah dokumen dan sketsa.*

| ID | Task | Effort | Depends On | AC |
|----|------|--------|------------|-----|
| **LD-06** | Design room type taxonomy doc | S (0.5d) | — | Dokumen di `design/room-type-taxonomy.md`: definisi tiap room type (Combat, Elite, Memory, Rest, Boss Gate), parameter per type (prep time, wave count, reward table), frequency distribution |
| **LD-07** | Design Layer 1 template pool — paper sketch 10–15 arena shapes | M (2d) | LD-06 | 10-15 sketsa thumbnail (bisa ASCII atau gambar); setiap shape punya: nama, one-sentence identity, deskripsi prep readability, valid zone shape |
| **LD-08** | Select 5 best Layer 1 templates for blockout | S (0.5d) | LD-07 | 5 template terpilih dengan rationale; sisanya archived untuk VS+ |
| **LD-09** | Design room connection model doc | S (0.5d) | LD-06 | Dokumen di `design/room-connection-model.md`: branching logic, map preview UX, corridor transition spec, backtracking rules |
| **LD-10** | Design anchor object catalog (memory fragments) | S (0.5d) | — | Dokumen di `design/anchor-objects.md`: 8-10 anchor objects, masing-masing dengan visual description, placement rules, triggered memory, narrative logic |
| **LD-11** | Design layer identity spec — Layer 1 & 2 | M (1d) | LD-06, LD-07 | Dokumen di `design/layer-identity.md`: mechanical identity per layer (template pool, obstacle palette, enemy palette, visual character, "what does this layer teach?") |

**Fase 2 total**: ~5 hari | **Gate**: semua dokumen reviewed dan approved

---

## Fase 3: Core — VS Procedural Dungeon Implementation

*Ini yang membangun sistem procedural dungeon sebenarnya.*

### Fase 3a: Room Template System

| ID | Task | Effort | Depends On | AC |
|----|------|--------|------------|-----|
| **LD-12** | Implement `RoomTemplate` resource class | M (1d) | LD-08 | `.tres` resource: tile layout, valid zone polygon, spawn marker positions, default obstacle config; `RoomTemplate.new()` creates empty template |
| **LD-13** | Implement `RoomTemplate` editor tooling (Godot plugin) | M (2d) | LD-12 | Godot editor plugin: visual template authoring, tile painting, valid zone drawing, spawn marker placement, preview with obstacles |
| **LD-14** | Blockout 5 Layer 1 templates as `.tres` | M (1.5d) | LD-12, LD-13 | 5 `.tres` files dari 5 template LD-08; minimal: tile layout + valid zone + spawn markers; validated di editor |
| **LD-15** | Implement `TemplateRoom` scene — generic room host | M (1d) | LD-12 | Scene yang load `RoomTemplate.tres`, build floor/walls/nav dari tile data, place obstacles via zone-aware `_generate_debris_positions()`, expose spawn markers |

### Fase 3b: Dungeon Generator

| ID | Task | Effort | Depends On | AC |
|----|------|--------|------------|-----|
| **LD-16** | Implement `DungeonGraph` — room node & edge data structure | S (0.5d) | LD-06, LD-09 | `DungeonGraph` class: nodes (room type, template ref, state), edges (corridor, direction), `add_room()`, `connect()`, `traverse()` |
| **LD-17** | Implement `PathBuilder` — branching path algorithm | M (2d) | LD-16, LD-09 | Generate branching path graph: start → N rooms → boss; enforce Rest room before Boss; 2-3 branch points per layer; no dead ends |
| **LD-18** | Implement `RoomSelector` — template picker with type distribution | M (1d) | LD-16, LD-14 | Pick room templates from pool; enforce type distribution (60% Combat, 15% Elite, 10% Memory, 10% Rest, 5% Boss); prevent same template twice in one run |
| **LD-19** | Implement `DungeonGenerator` orchestrator | M (1.5d) | LD-17, LD-18, LD-15 | Wire PathBuilder + RoomSelector + TemplateRoom; generate full layer; emit `layer_generated` signal |
| **LD-20** | Implement room transition system | M (1d) | LD-19 | Corridor/transition between rooms; door trigger; camera transition; enemy cleanup on exit; preserve the duo state |

### Fase 3c: Anchor Objects

| ID | Task | Effort | Depends On | AC |
|----|------|--------|------------|-----|
| **LD-22** | Implement `AnchorObject` resource + placement | M (1d) | LD-10, LD-15 | `.tres` resource: visual description, trigger condition, memory ID; placed in Memory Chamber rooms by RoomPopulator |
| **LD-23** | Implement memory fragment trigger system | M (1.5d) | LD-22 | The duo proximity → Memo dialog → memory fragment fires; integration with narrative system; one-shot per run |

**Fase 3 total**: ~13.5 hari | **Gate**: full procedural dungeon playable — branch, pick path, clear rooms, reach boss

---

## Fase 4: Polish — Layer Identity & Memory Anchors (MVP)

| ID | Task | Effort | Depends On | AC |
|----|------|--------|------------|-----|
| **LD-24** | Implement obstacle palette per layer | S (1d) | LD-11, LD-15 | Each layer loads its own obstacle config; Layer 1 = rusted barrels + scrap piles (half-cover); Layer 2 = + conveyor belts (full-cover line shapes) |
| **LD-25** | Author Layer 2 templates | M (2d) | LD-14, LD-11 | 5-7 Layer 2 templates: corridor shapes, choke points; registered in template pool with layer tag |
| **LD-26** | Implement layer transition visual + mechanical | M (1.5d) | LD-19, LD-11 | Layer boss → next layer; visual transition (fade, new tileset); enemy palette switch; difficulty ramp |
| **LD-27** | Playtest + tuning: Layer 1 pacing & room readability | S (0.5d) | LD-19 | Internal playtest session; document: prep readability per template, combat pacing, difficulty curve feedback |
| **LD-28** | Playtest + tuning: Layer 1 → 2 transition feel | S (0.5d) | LD-26 | Internal playtest; document: transition clarity, difficulty jump appropriateness |

**Fase 4 total**: ~5.5 hari | **Gate**: dua layer procedural dungeon dengan identitas berbeda, memory anchor objects berfungsi

---

## Dependency Graph

```
Fase 1 (Foundation) ──────────────────────────────────────┐
LD-01 ──→ LD-02                                           │
LD-03 ──→ LD-05                                           │
LD-04                                                      │
                                                           │
Fase 2 (Preparation) ─────────────────────────────────────┤
LD-06 ──→ LD-07 ──→ LD-08                                 │
LD-06 ──→ LD-09                                            │
LD-06 ──→ LD-11 ──→ LD-07                                 │
LD-10                                                      │
       ┊                                                   │
       ┊──→ Fase 3a ──────────────────────────────────────┤
            LD-12 ──→ LD-13 ──→ LD-14                     │
            LD-12 ──→ LD-15                                │
                           ┊                               │
                           ┊──→ Fase 3b ──────────────────┤
                                LD-16 ──→ LD-17 ──→ LD-19 │
                                LD-14 ──→ LD-18 ──→ LD-19 │
                                LD-19 ──→ LD-20           │
                                               ┊           │
                                               ┊──→ Fase 3c
                                                    LD-15 ──→ LD-22 ──→ LD-23
                                                                           ┊
                                                                           ┊──→ Fase 4
                                                                                LD-15 ──→ LD-24
                                                                                LD-14 ──→ LD-25
                                                                                LD-19 ──→ LD-26
                                                                                LD-19 ──→ LD-27, LD-28
```

---

## Effort Summary

| Fase | Tasks | Total Effort | Scope |
|------|-------|-------------|-------|
| Fase 1 — Foundation | LD-01 → LD-05 | 2.25d | FP polish |
| Fase 2 — Preparation | LD-06 → LD-11 | 5d | Paper design |
| Fase 3a — Template System | LD-12 → LD-15 | 5.5d | VS core |
| Fase 3b — Dungeon Generator | LD-16 → LD-20 | 6d | VS core |
| Fase 3c — Anchor Objects | LD-22 → LD-23 | 2.5d | VS core |
| Fase 4 — Polish | LD-24 → LD-28 | 5.5d | MVP polish |
| **Total** | **27 tasks** | **~26.75 hari** | FP → MVP |

> **Solo dev note**: 28.75 hari ≈ 6 minggu kalender dengan 5 hari kerja/minggu, atau ~8-10 minggu dengan overhead sprint rituals dan bug fixing. Fase 1 bisa dikerjakan segera; Fase 2 bisa parallel dengan Sprint 10–11.

---

## Quick Wins (Bisa Dikerjakan Sekarang)

Ini 3 task yang bisa langsung dieksekusi tanpa menunggu Fase 2:

1. **LD-04** (XS, 0.25d) — sync GDD tuning knobs dengan code. Purely documentation.
2. **LD-01** (S, 0.5d) — parameterize valid zone. Small refactor, big future value.
3. **LD-03** (S, 0.5d) — extract enemy pool config ke `.tres`. Data-driven design.

Total quick wins: **1.25 hari**. Tidak mengubah behavior. Memperkuat fondasi.
