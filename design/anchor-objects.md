# Anchor Object Catalog — The Last Cipher

> **Created**: 2026-06-19
> **Scope**: Fase 3c — Memory Chamber rooms (VS+)
> **Author**: Kusuma Putra + Claude
> **Implements**: LD-10 (design task), consumed by LD-22 (implementation)

---

## Overview

Anchor objects are static environmental objects placed in Memory Chamber rooms.
Fayde approaches them, triggering a recovered memory fragment — a brief, fragmentary
glimpse of who Fayde was before the dungeon. Each anchor triggers at most once per run.

Tone: mysterious and wondrous, never melancholy. The memories feel like rediscovery,
not loss.

---

## Placement Rules

- Max **1 anchor object per Memory Chamber room**.
- Placed by `RoomPopulator` (LD-22 implementation).
- Minimum **80px** clearance from enemy spawn markers.
- Minimum **60px** clearance from arena wall boundary.
- Must be inside the walkable zone polygon.
- **One-shot per run**: once triggered, the anchor does not re-trigger on the
  same room re-visit (if re-visit is ever added). Triggered state is stored
  on `AnchorObjectNode._triggered`, reset only on new run.

---

## Trigger Condition

Default: **PROXIMITY** — Fayde's CharacterBody2D enters the anchor's Area2D
(radius = `AnchorObject.trigger_radius`, default 48px).

Future (LD-23+): `ROOM_CLEARED` — memory fragment fires after wave is cleared,
not on approach.

---

## Catalog

| ID | Display Name | Visual Description | Trigger Memory | Narrative Logic |
|----|-------------|-------------------|----------------|-----------------|
| `worn_journal` | Worn Journal | A tattered leather journal left open. Handwriting inside looks familiar. | Fayde as a child, writing in an identical journal — first lessons in Prana theory | Establishes that Fayde was educated, not self-taught |
| `fractured_mirror` | Fractured Mirror | A floor-length mirror, cracked across the center. The reflection is subtly wrong. | Fayde staring into this mirror and not recognizing the face staring back | Plants the question: was Fayde always who they are now? |
| `abandoned_cipher` | Abandoned Cipher | A brass mechanism — wheels and pins — that clicks when Fayde moves nearby. | Fayde solving this exact cipher as a lesson, being told "the cipher is the key" | Connects to the game's title; Fayde has solved this before |
| `faded_portrait` | Faded Portrait | A painting propped against the wall. The subject's face has faded to white. | Fayde standing before this portrait with someone whose name won't come | Hints at a companion or mentor Fayde has forgotten |
| `rusted_key` | Rusted Key | An ornate iron key hanging from a peg. Fits no lock in sight. | Someone pressing this key into Fayde's hand with the words "only when you're ready" | A promise or inheritance — creates a sense of responsibility |
| `prana_crystal_cluster` | Crystal Cluster | A cluster of dormant Prana crystals arranged in a careful arc. | These crystals glowing warm and soft — a place Fayde called home | Establishes that Prana was once safe and familiar to Fayde |
| `carved_toy` | Carved Toy | A small wooden animal — a fox, worn smooth by years of handling. | Fayde holding this same toy, young, unafraid, laughing | Grounds Fayde's humanity — there was joy before the cipher |
| `coded_tablet` | Coded Tablet | A flat stone tablet incised with early Prana notation. | Fayde learning to read this script from a teacher — "each symbol is a breath" | Deepens Prana lore; it has a language, a pedagogy |
| `empty_vessel` | Empty Vessel | A ceramic cup, ceremonially crafted, traces of Prana residue inside. | Fayde drinking from this vessel as part of a ritual — others watching | Hints at community, ceremony, belonging — all now absent |
| `map_fragment` | Map Fragment | A torn piece of a larger map. One location is circled in faded ink. | Being shown this map: "This is where you came from. Don't forget." | Implies Fayde was displaced deliberately — not lost, removed |

---

## Memory Fragment IDs

Each `memory_id` maps to a narrative event consumed by the Memory Fragment Trigger
System (LD-23). IDs follow the pattern `mem_[anchor_id]`.

| Anchor ID | Memory ID |
|-----------|-----------|
| `worn_journal` | `mem_worn_journal` |
| `fractured_mirror` | `mem_fractured_mirror` |
| `abandoned_cipher` | `mem_abandoned_cipher` |
| `faded_portrait` | `mem_faded_portrait` |
| `rusted_key` | `mem_rusted_key` |
| `prana_crystal_cluster` | `mem_prana_crystal_cluster` |
| `carved_toy` | `mem_carved_toy` |
| `coded_tablet` | `mem_coded_tablet` |
| `empty_vessel` | `mem_empty_vessel` |
| `map_fragment` | `mem_map_fragment` |

---

## Acceptance Criteria (LD-10)

- [ ] Catalog contains 8-10 distinct anchor objects
- [ ] Each entry has: visual description, placement rules reference, memory ID, narrative logic
- [ ] Memory IDs follow `mem_[anchor_id]` convention
- [ ] Tone consistent with game-concept.md Pillar 5 (wondrous, not melancholy)
