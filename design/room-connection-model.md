# Room Connection Model — The Last Cipher

> **Status**: Draft | **Fase**: 2 — Paper Design (LD-09)
> **Created**: 2026-06-18

---

## Overview

Bagaimana rooms terhubung dalam satu layer procedural dungeon. Model ini menentukan:
branching logic, player choice UX, corridor transition, dan aturan backtracking.

---

## Core Model: Forward Branching (Hades-like)

```
                       ┌──→ [Combat A] ──→ [Elite] ──┐
  [Start] ──→ [Combat] ┤                            ├──→ [Rest] ──→ [Boss]
                       └──→ [Combat B] ─────────────┘
```

**Prinsip utama**:
- Player **selalu maju ke depan**, tidak pernah mundur.
- Di branch point, player melihat 2-3 **exit door**, masing-masing dengan info cukup
  untuk membuat keputusan strategis.
- Keputusan **permanen** — tidak bisa backtrack.
- Setiap jalur punya **reward preview** (room type + hint).

---

## Door UX: Informasi yang Player Butuhkan

Di setiap exit room, player melihat door(s) yang menampilkan:

| Informasi | Tampil? | Format |
|-----------|---------|--------|
| Room type icon | ✅ Selalu | Combat (⚔), Elite (💀), Rest (♥), Boss (👑) |
| Estimated difficulty | ✅ Selalu | Bintang 1-3 atau teks "Dangerous", "Deadly" |
| Enemy archetype hint | ✅ Combat/Elite | "Swarmers nearby", "Something fast", "Projectiles ahead" |
| Reward preview | ✅ Elite | "Prana drop guaranteed", indikator elemen |
| Rest room info | ✅ Rest | "Heal 20% HP" |

**Contoh tampilan**:
```
   ┌─────────────────────┐     ┌─────────────────────┐
   │ ⚔ Combat            │     │ 💀 Elite             │
   │ ★★☆☆                │     │ ★★★★                │
   │ "Chargers ahead"    │     │ "Swarmers nearby"    │
   │ 1 wave              │     │ 2 waves              │
   │                     │     │ 🔮 Prana drop        │
   └─────────────────────┘     └─────────────────────┘
```

---

## Branching Rules

1. **Branch points**: terjadi di room ke-2 dan ke-4 (sekitar pertengahan layer).
2. **Max 2-3 exit per room**. Tidak boleh 4+ pilihan = analysis paralysis.
3. **Semua jalur bertemu kembali** sebelum Rest room. Rest room selalu single-entry.
4. **Jalur tidak sama panjang**. Jalur kiri mungkin 2 room, kanan 3 room. Player
   memutuskan: longer path = more rewards? Atau shorter = lebih aman?
5. **Room count per path**: beda max 1 room. Tidak ada jalur 1 room vs 4 room.

### Path Length Table

| Layer Room Count | Branch at | Left Path | Right Path | Regroup at |
|-----------------|-----------|-----------|------------|------------|
| 5 rooms | — (no branch) | — | — | Linear all |
| 6 rooms | Room 2 | 2 rooms | 2 rooms | Room 4 (Rest) |
| 7 rooms | Room 2 | 3 rooms | 3 rooms | Room 5 (Rest) |
| 8 rooms | Room 2 | 3 rooms | 3 rooms | Room 5; Rest at Room 7 |

> **Linear exception**: Layer dengan 5 room tidak ada branch — murni linear.
>   Ini hanya terjadi di Layer 1 (tutorial layer pendek) atau layer pendek random.

---

## Corridor Transition

### Visual & Gameplay

Setiap transisi antar room adalah **short corridor** (2-3 detik walk time):

```
  [Room A] ──═ [corridor 2-3 detik] ═── [Room B]
     ↑                                      ↑
  Arena combat                          Arena combat
  (800×500px)                          (800×500px)
```

**Corridor adalah safe zone**. Tidak ada musuh, tidak ada hazard. Player bisa pause,
cek inventory, atau sekedar bernafas.

### Spesifikasi corridor:
- **Panjang**: 2-3 detik walk (sekitar 400-600px di move speed normal).
- **Visual**: Lorong sempit dengan tile yang match tema layer.
- **Transisi**: Camera mengikuti the duo. Tidak ada scene reload — room dan corridor
  adalah bagian dari scene yang sama, hanya camera yang pan.

### Alternative: Scene per Room (jika template-based scene)

Jika tiap room adalah scene terpisah (seperti Hades):
- Corridor = scene transition trigger.
- Saat the duo menyentuh exit trigger → `SceneManager.change_room()` → load room baru.
- Player spawn di entry point room baru.
- Transisi 0.5-1 detik (fade atau screen wipe).

**Rekomendasi**: Scene per room. Lebih clean untuk template-based generation. Tiap
`TemplateRoom` adalah scene terpisah. `SceneManager` sudah menangani ini.

---

## Backtracking Rules

### Default: No Backtracking

Pintu di belakang player **tertutup permanen** setelah player melewati corridor.
Ini menjaga pacing tight — player selalu maju.

### Exception: Rest Room Hub

Rest room bisa punya **portal/shortcut** kembali ke room sebelumnya jika layer
berbentuk hub-and-spoke. Tapi ini fitur VS+, tidak untuk MVP.

---

## Map Preview (Pre-Run)

Sebelum layer dimulai, player melihat **mini-map** seluruh layer:

```
   Layer 1 — Deep Scrap Yard
   
   [Start] ──→ [⚔] ──┬──→ [⚔] ──→ [💀] ──┐
                       │                    ├──→ [♥] ──→ [👑]
                       └──→ [⚔] ──────────┘
   
   "Choose your path wisely. There's no turning back."
```

Map preview:
- Ditampilkan hanya **sekali** di awal layer (bisa di-skip).
- Player tidak bisa pause untuk melihat map lagi setelah layer dimulai
  (kecuali di Rest room — bisa lihat map).
- Map tidak reveal enemy composition detail — hanya room type.

> **MVP concern**: Map preview mungkin over-scope untuk MVP. Alternatif minimal:
>   player hanya lihat 2-3 door label saat di branch point. Map preview ditambahkan
>   di VS+ setelah full procedural dungeon solid.

---

## Implementation Impact (Fase 3)

| Komponen | Responsibility | File |
|----------|---------------|------|
| Branch point logic | `PathBuilder` | `src/systems/path_builder.gd` |
| Door UX rendering | `RoomExitDoor` | `src/ui/room_exit_door.gd` (Control node) |
| Door label data | `WaveManager` / `EnemyCatalog` | Enemy archetype hint text |
| Corridor scene | `CorridorScene` | `src/scenes/CorridorScene.tscn` |
| Scene transition | `SceneManager` (existing) | `src/systems/scene_manager.gd` |
| Map preview | `LayerMapPreview` | `src/ui/layer_map_preview.gd` |

---

## Acceptance Criteria

| ID | Criterion | Test Type |
|----|-----------|-----------|
| AC-CM-01 | Branch point menampilkan 2-3 door dengan type icon + difficulty + hint | Manual |
| AC-CM-02 | Player memilih door → corridor → room baru; pintu sebelumnya tidak bisa diakses | Integration |
| AC-CM-03 | Rest room selalu muncul sebelum Boss Gate | Integration |
| AC-CM-04 | Semua jalur bertemu sebelum Rest room | Integration |
| AC-CM-05 | Corridor adalah safe zone — tidak ada enemy spawn | Integration |
| AC-CM-06 | Tidak ada branch dengan 4+ pilihan | Unit |
| AC-CM-07 | Room count per path difference max 1 | Unit |
