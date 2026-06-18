# Room Type Taxonomy — The Last Cipher

> **Status**: Draft
> **Created**: 2026-06-18
> **Fase**: 2 — Paper Design (LD-06)
> **Roadmap**: design/level-design-roadmap.md

---

## Overview

Setiap room di procedural dungeon punya satu dari empat type. Type menentukan:
geometry kompleksitas, threat budget, wave count, reward, dan pacing position.

Story/narrative delivery (Memory Chamber, anchor objects, memory fragments) akan
dikerjakan setelah gameplay loop solid. Untuk sekarang: 4 type gameplay-only.

---

## Room Types

| # | Type | Freq | Prep Time | Combat Time | Intensi Desain |
|---|------|------|-----------|-------------|----------------|
| 1 | **Combat** | 65% | 5-8 detik | 15-25 detik | Arena combat standar — 1 wave, threat budget normal. Core gameplay loop. |
| 2 | **Elite Combat** | 15% | 8-12 detik | 25-40 detik | Arena lebih sulit — layout lebih kompleks, threat budget ×1.5, wave 2×. Risk/reward. |
| 3 | **Rest / Memo Room** | 15% | — | — | Safe zone. Heal 20% HP. Memo beri hint tanpa reveal mystery. Player pause/jeda. |
| 4 | **Boss Gate** | 5% | Full (15+ detik) | 40-60 detik | Arena boss — encounter khusus. Selalu posisi terakhir layer, setelah Rest room. |

> **Frequency notes**: Percentages are target distributions, not hard per-layer minimums.
>   At 5 rooms: 3 Combat + 1 Rest + 1 Boss = no Elite. At 7 rooms: 4 Combat + 1 Elite + 1 Rest + 1 Boss.
>   Elite may be absent on shorter layers; Combat and Rest are always present.

---

## Parameters Per Type

| Type | Wave Count | Threat Budget | Reward | Anchor Object |
|------|-----------|---------------|--------|---------------|
| Combat | 1 | Normal (10–18) | 1 Prana drop, 30% chance | None |
| Elite | 2 | 1.5× (15–27) | 1 guaranteed Prana drop | None |
| Rest | 0 | — | Heal 20% HP | None |
| Boss | 1 (boss) | Fixed per boss | Layer transition | None |

---

## Pacing Logic

```
Layer flow (7 rooms):
  [Combat] → [Combat] → [Elite] → [Combat] → [Combat] → [Rest] → [Boss Gate]
     ↑                     ↑                                      ↑
   warm-up              difficulty peak                       recovery → climax
```

Prinsip pacing:
1. **Boss Gate selalu di akhir layer** — didahului oleh Rest room sebagai recovery.
2. **Rest room selalu sebelum Boss** — player masuk boss fight dengan HP penuh/pulih.
3. **Elite di tengah layer** — sebagai difficulty spike pertengahan.
4. **Combat pertama selalu lebih mudah** — warm-up, 2-3 musuh.
5. **Tidak boleh 2 template identik berturut-turut** — variasi visual dan spasial.

---

## Room Selector Algorithm (Fase 3)

`RoomSelector` menerima `layer_room_count: int` dan `available_templates: Array[RoomTemplate]`
lalu menghasilkan ordered room list:

```
1. Reserve slot terakhir = Boss Gate
2. Reserve slot sebelum Boss = Rest room
3. Hitung slot tersisa = count - 2
4. Elite = 1 if slot_tersisa >= 5 else 0
5. Combat = slot_tersisa - elite_count
6. Assign template per slot (no consecutive identical)
7. Return ordered list
```

---

## Edge Cases

- **Layer pendek (5 room)**: 3 Combat + 1 Rest + 1 Boss. Tidak ada Elite.
- **Layer panjang (8+ room)**: 2 Elite, 2 Rest (satu di tengah, satu sebelum Boss).
- **Rest room double**: Jika 8+ room, Rest tambahan di posisi tengah sebagai checkpoint.
- **Template collision**: Jika hanya 1 template tersedia untuk suatu type, izinkan reuse
  dengan gap minimal 2 room (bukan consecutive ban).
