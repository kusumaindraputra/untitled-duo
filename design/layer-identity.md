# Layer Identity Spec — The Last Cipher

> **Status**: Draft | **Fase**: 2 — Paper Design (LD-11)
> **Created**: 2026-06-18

---

## Overview

Setiap layer di The Last Cipher punya **mechanical identity**, bukan cuma visual skin.
Layer identity = template pool × obstacle palette × enemy palette × visual character ×
"what does this layer teach?"

Dokumen ini mendefinisikan Layer 1 (Deep Scrap Yard — FP ke VS) dan Layer 2
(Functional Corridors — VS scope). Layer 3+ didefinisikan setelah playtest Layer 1-2.

---

## Layer 1: Deep Scrap Yard

### Identity Statement
> *"Belajar membaca ruangan. Setiap layout adalah problem baru."*

Layer 1 mengajarkan fundamental: membaca layout di prep phase, memilih Prana yang tepat,
positioning dasar, dan perbedaan perilaku antar archetype.

### Template Pool

| Template | Type | Freq Weight | Intensi |
|----------|------|-------------|---------|
| The Diamond | Combat | 3 | Baseline tutorial — "ini cara baca room" |
| The Split | Combat/Elite | 2 | Lane commitment — "pilih kiri atau kanan" |
| The Corridor | Combat/Elite | 2 | Linear funnel — "musuh dari satu arah" |
| The Arena | Combat | 2 | Open space — "tidak ada cover = movement is defense" |
| The Gauntlet | Elite | 1 | AOE value — "satu lorong, semua musuh" |

> **Weight**: Higher = lebih sering muncul. Diamond template tetap yang paling sering
>   (1.5× dari Split/Corridor/Arena) sehingga player membangun baseline mental lewat
>   Diamond — tapi ketiga shape lain kini sama-sama umum, jadi sebuah floor terasa lebih
>   beragam. Variety window (RoomSelector.variety_window = 2) juga menjamin tidak ada
>   shape yang sama muncul dalam tiga room berturut-turut.

### Obstacle Palette

| Obstacle | Cover Type | Visual | Gameplay |
|----------|------------|--------|----------|
| Scrap pile | Half-cover | Rusted metal, kabel putus, abu-abu kecoklatan | Block movement. Prana tembus. |
| Broken barrel | Half-cover | Barrel remuk, minyak tumpah, warna karat | Sama. Variasi visual. |
| Rusted pillar | Half-cover | Tiang besi bengkok, lebih tinggi dari debris | Sama. Lebih tipis (radius 18px vs 22px). |

> **Rule**: Layer 1 TIDAK punya full-cover obstacle selain arena walls.
>   Half-cover only — player belajar bahwa Prana selalu bisa tembus debris.

### Enemy Palette

| Archetype | Type ID | Cost | Availability | Freq Weight |
|-----------|---------|------|-------------|-------------|
| SEEKER (Drifter) | 0 | 1 | Always | 1.5 |
| SWARMER (Cluster) | 2 | 1 | Always | 1.0 |
| RUSHER (Charger) | 1 | 2 | Mulai room ke-3 | 1.0 |
| SHOOTER (Rifter) | 4 | 1 | **Tidak muncul di Layer 1** | 0 |

> **Availability rules**:
> - RUSHER tidak muncul di room pertama (warm-up). Mulai room ke-3+.
> - SHOOTER tidak muncul di Layer 1. Diperkenalkan di Layer 2.
> - SEEKER selalu ada (guaranteed + pool weight boost).
> - SWARMER selalu ada (guaranteed).

### Visual Character
- **Tile**: `iso_floor_stone2.png` — abu-abu hangat, tekstur batu kasar
- **Atmosfer**: Gelap tapi hangat. Pencahayaan redup dengan aksen karat dan tembaga.
- **Warna debris**: Coklat karat, abu-abu metal, hitam oli
- **Prana kontras**: Jewel-tone terang melawan background gelap — "magic screams"

### "What Does This Layer Teach?"

| Room # | Pelajaran |
|--------|-----------|
| Room 1 (Diamond) | Baseline — cara baca layout 5 detik, cara arrange Prana, cara cast |
| Room 2 (Split/Arena) | Layout memengaruhi decision — Split: pilih jalur, Arena: cover = defense |
| Room 3 (any + RUSHER) | Enemy archetype berbeda = threat berbeda. RUSHER = timing dodge. |
| Room 4-5 (Elite) | Difficulty spike. Wave 2×. Prep decision lebih kritis. |
| Rest → Boss | Recovery → klimaks. Boss = test semua yang sudah dipelajari. |

### Difficulty Curve

```
  Intensity
    10 ┤                                    ██ Boss
     9 ┤                                    ██
     8 ┤                              ██    ██
     7 ┤                        ██    ██    ██ Elite
     6 ┤                              ██    ██
     5 ┤            ██    ██    ██    ██    ██
     4 ┤      ██    ██    ██    ██    ██    ██
     3 ┤██    ██    ██    ██    ██    ██    ██
     2 ┤██    ██    ██    ██    ██    ██    ██
     1 ┤██    ██    ██    ██    ██    ██    ██
       ──────────────────────────────────────────
        R1    R2    R3    R4    R5   Rest  Boss
       Diamond Split +Rush Elite  Arena   ♥    👑
```

---

## Layer 2: Functional Corridors

> *"Musuh memanfaatkan geometri. Ruangan tidak netral — ia memihak."*

Layer 2 memperkenalkan SHOOTER archetype dan obstacle yang membentuk lane.
Geometri lebih intentional — corridor, choke, conveyor belt sebagai full-cover.

### Template Pool (preliminary — dari catalog LD-07)

| Template | Type | Freq Weight | Intensi |
|----------|------|-------------|---------|
| The Corridor (L2 variant) | Combat | 3 | Lane primer — "geometri mengarahkan aliran" |
| The Choke | Combat/Elite | 2 | Gate control — "satu pintu = satu keputusan" |
| The Gauntlet (L2 variant) | Combat | 2 | AOE lane — "semua funnel ke sini" |
| The Islands | Combat/Elite | 2 | Multi-zone — "pilih pulau mana" |
| The Maze | Elite | 1 | Tight weave — "tidak ada ruang untuk salah" |
| The Wedge (L-Wedge) | Combat | 1 | Asymmetry — "satu sisi safe, satu sisi death" |

### Obstacle Palette

| Obstacle | Cover Type | Visual | Gameplay |
|----------|------------|--------|----------|
| Scrap pile | Half-cover | (carry dari L1) | Block movement |
| Broken barrel | Half-cover | (carry dari L1) | Block movement |
| **Conveyor belt** | **Full-cover** | Belt logam rusak, horizontal/vertikal | **Block movement + block Prana**. Line-shaped. |
| **Broken machine** | **Full-cover** | Mesin besar, tidak tembus, 1-tile lebar | **Block movement + block Prana**. Persegi besar. |

> **Gameplay shift**: Full-cover conveyor belts memaksa player untuk repositioning.
>   Tidak bisa cuma tembak lewat debris. Harus cari angle clear.

### Enemy Palette

| Archetype | Type ID | Cost | Availability | Freq Weight |
|-----------|---------|------|-------------|-------------|
| SEEKER (Drifter) | 0 | 1 | Always | 1.0 |
| SWARMER (Cluster) | 2 | 1 | Always | 0.8 |
| RUSHER (Charger) | 1 | 2 | Always | 1.2 |
| **SHOOTER (Rifter)** | 4 | 1 | **Mulai room ke-2** | 1.5 |

> **Key changes dari L1**:
> - SHOOTER muncul pertama kali di sini — player belajar line-of-sight dan cover usage.
> - SHOOTER weight 1.5 = sering muncul. Layer 2 = "welcome to projectiles."
> - SWARMER weight turun ke 0.8 (fokus ke SHOOTER + RUSHER).

### Visual Character
- **Tile**: Lebih terang dari L1 — abu-abu metalik, garis-garis industrial
- **Atmosfer**: Fungsional, pabrik. Pipa-pipa, conveyor belt, panel kontrol rusak.
- **Warna debris**: Metal abu-abu, tembaga, aksen biru industrial
- **Full-cover visual**: Conveyor belt = berbeda jelas dari half-cover — player langsung tahu "ini tidak bisa ditembus."

### "What Does This Layer Teach?"

| Room # | Pelajaran |
|--------|-----------|
| Room 1 (Corridor) | SHOOTER introduction — "projectile bisa dihindari, cover melindungi" |
| Room 2-3 | Full-cover vs half-cover — "tidak semua debris sama" |
| Room 4 (Choke/Elite) | Line-of-sight management + AOE timing di choke |
| Room 5-6 (Gauntlet) | Funneling = spell value. Tapi juga risk (semua musuh di satu lane) |
| Rest → Boss | Recovery → Layer 2 boss |

---

## Layer Identity Comparison

| Aspek | Layer 1 — Deep Scrap Yard | Layer 2 — Functional Corridors |
|--------|--------------------------|-------------------------------|
| **Cover types** | Half-cover only | Half-cover + Full-cover (conveyor belt) |
| **Enemy intro** | SEEKER, SWARMER, RUSHER (late) | + SHOOTER |
| **Geometry** | Open to moderately constrained | Lane-based, corridor, choke |
| **Difficulty** | Easy to moderate | Moderate to hard |
| **Pelajaran** | Baca room, prep decision, archetype basics | Cover usage, line-of-sight, funneling |
| **Room count** | 5-7 | 6-8 |
| **Visual** | Gelap, hangat, rust, chaos | Lebih terang, industrial, functional |
| **Feel** | "Aku belajar sistem." | "Sistem mengujiku." |

---

## Future Layers (Preliminary)

| Layer | Setting | Mechanical Identity | Key Introduction |
|-------|---------|---------------------|-----------------|
| L3 — AI Architecture | Aristokratik, sleek, dingin | Open geometry, precision pillars, energy barriers | Multi-phase boss, Prana resonance objects |
| L4 — Surface | AI Kingdom proper | Verticality, multiple levels, turret enemies | Elevation mechanics, Prana full-penetration |
| L5 — Throne | First King's chamber | Boss-only layer, transforming arena | Plot twist delivery, final boss |

> L3-L5 specs ditulis setelah L1-L2 playtest solid.

---

## Acceptance Criteria (Layer Identity)

| ID | Criterion | Layer | Test Type |
|----|-----------|-------|-----------|
| AC-LI-01 | Layer 1 tidak punya full-cover obstacle selain walls | L1 | Unit |
| AC-LI-02 | SHOOTER tidak muncul di Layer 1 enemy composition | L1 | Unit |
| AC-LI-03 | RUSHER tidak muncul di room pertama Layer 1 | L1 | Unit |
| AC-LI-04 | SHOOTER muncul di Layer 2 room 2+ | L2 | Unit |
| AC-LI-05 | Layer 2 punya minimal 1 full-cover obstacle type | L2 | Manual |
| AC-LI-06 | Setiap template di L1 dan L2 punya valid zone berbeda | L1, L2 | Unit |
