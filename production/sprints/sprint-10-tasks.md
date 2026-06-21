# Sprint 10 — First Playable Fix Tasks

Source: Opus professional review, 2026-06-20
Priority order: player-experience impact

---

## STATUS — verified against code 2026-06-21 (demo push)

Most of this list is already shipped. Verified live in `src/`:

| Task | Status | Notes |
|------|--------|-------|
| T01 enemy count cap | ✅ Done | `EnemyPoolConfig.enemy_count_max`, clamp in `wave_manager.gd`, floor3=10 |
| T02 damage numbers + popup | ✅ Done | wired in `combat_hud.gd` / `spell_vfx.gd` |
| T03 trap loadout guard | ✅ Done | `_fire_secondary_effect` implements Verdant heal + Deepfrost glacial field; undefined combos `push_error` (logs, no crash) |
| T04 room shape variety | ✅ Done | `RoomSelector` weighted pools → 5 layout styles via `IsometricRoom._resolve_layout_cells()` |
| T05 REST visual feedback | ✅ Done | `REST_HEAL_VISUAL_DELAY` + floating "+N HP" |
| T06 boss distance selection | ✅ Done | `_select_boss_attack(dist, enraged)` |
| T07 SALVO player-aimed | ✅ Done | `_fire_salvo()` aims at Fayde |
| T08 Rifter rebalance | ✅ Done | `base_damage = 12.0` |
| T09 audio registry | ✅ Done | 30 audio files, music FSM wired |
| T10 win/loss screen | ✅ Done | colored overlay + title + `Floor X · N Rooms Cleared` + replay |
| T11 WarpedWarden | ✅ Done | wired as Floor-2 mid-boss (`enemy_pool_boss_f2.tres`) |

**Remaining for a shippable demo (not in the original list):**
- ✅ Title / start screen — added `_show_title_screen()` in `debug_game_loop.gd` (2026-06-21).
- ⏳ Export presets + packaged build (Windows / Linux / HTML5) — requires the Godot editor; do locally.
- ⏳ (optional) ESC pause menu — `GameStateManager.pause_game()` exists but is unbound to input.

---

## BLOCKER (harus selesai sebelum first playable)

### T01 — Cap Floor 3 Enemy Count
**File:** `enemy_pool_floor3.tres`, `src/gameplay/wave_manager.gd:255-289`
**Problem:** Budget 18–26 + costs 1–2 + no cap = bisa spawn 20+ enemy di 3 marker.
**Fix:**
- Tambah field `enemy_count_max` ke `EnemyPoolConfig` resource
- Clamp di `_build_wave_composition` sebelum loop selesai
- Tambah 2–3 spawn marker di combat rooms
- Set `enemy_count_max = 10` untuk Floor 3
**Test:** unit test bahwa wave tidak pernah melebihi cap apapun budget-nya

---

### T02 — Combat Legibility: Damage Numbers + Affiliation Popup
**File:** `src/gameplay/spell_casting_effects.gd:435`, `src/ui/`
**Problem:** 2× affiliation bonus terjadi tanpa feedback. Player tidak tahu mengapa damage tinggi.
**Fix:**
- Floating damage number di atas enemy saat hit (warna per element)
- Popup "WEAK 2×" saat affiliation match (line 435 adalah trigger point)
- Chain indicator di HUD yang bergerak saat combo chaining aktif
**Test:** visual — tidak perlu automated test, tapi harus terlihat di layar

---

### T03 — Guard Trap Loadouts
**File:** `src/gameplay/spell_casting_effects.gd:496-500`
**Problem:** Verdant T2, Deepfrost T3, dan modifier==0.0 cases `push_warning` lalu tidak ada yang terjadi. Loadout valid secara UI tapi no-op secara gameplay.
**Fix:**
- Implementasi `_fire_secondary_effect` stubs yang ada (minimum: Verdant T2 heal-amp, Deepfrost T3 glacial field)
- ATAU tambah guard di combination_resolution: jika loadout resolve ke all-stub secondaries, tampilkan "Incomplete combination" warning di grid
**Test:** unit test bahwa setiap tier/modifier combo produce non-zero effect atau explicit error

---

### T04 — Room Shape Variety
**File:** `src/systems/room_transition_manager.gd:195`
**Problem:** `_resolve_packed_scene()` return `IsometricRoom.tscn` untuk semua template. 6 room shapes dirancang, 2 yang muncul.
**Fix:** Author distinct `layout_style` dan `tile_cells` per template (Diamond=0, Arena=1, Corridor=2, Split=3, Rest=4) dan branch di RTM berdasarkan template type. Atau: buat separate .tscn per room type.
**Test:** jalankan dungeon generation 10x, pastikan player melihat ≥3 layout berbeda per floor

---

## HIGH (harusnya ada di first playable)

### T05 — REST Room Visual Feedback
**File:** `src/gameplay/wave_manager.gd:222-233`
**Problem:** `_apply_rest_heal()` heal 10–20%, langsung emit `wave_cleared`. Player tidak tahu apa yang terjadi.
**Fix:**
- Tambah short delay sebelum `wave_cleared.emit()` (0.5s)
- Emit angka heal sebagai floating text "+15 HP" dengan warna hijau
- Tambah green wash / screen tint singkat (mirip room-clear wash yang sudah ada)
**Test:** sinyal `health_restored` harus diikuti visual event sebelum door unlock

---

### T06 — Boss Pattern: Distance-Driven Selection
**File:** `src/gameplay/enemy_instance.gd:673-784`
**Problem:** Fixed round-robin `(_boss_attack + 1) % 3`. Hafal dalam 30 detik.
**Fix:** Ganti selection logic:
- Jarak dekat (< 80px) → pilih SLAM
- Jarak jauh (> 150px) → pilih CHARGE
- Jarak menengah → pilih SALVO
- Enrage: sama tapi semua threshold dikurangi 20px
**Test:** unit test boss pattern selection berdasarkan mocked distance

---

### T07 — Boss SALVO: Random Rotation + Player-Aimed
**File:** `src/gameplay/enemy_instance.gd` (SALVO block)
**Problem:** Fixed 6-spoke star. Berdiri di antara spoke = gratis.
**Fix:** Tambah random `rotation_offset = randf() * PI / 6` saat SALVO fire, atau aim satu spoke ke player position saat fire
**Test:** playtest — tidak ada safe static position

---

### T08 — Rifter Rebalance
**File:** `assets/data/enemies/enemy_rifter.tres`
**Problem:** 1.5 base damage vs 100 HP player. Noise, bukan ancaman.
**Fix:** Naikkan base_damage ke 6–8, atau naikkan threat_cost ke 3 (jujur sama kontribusinya)
**Test:** balance smoke test — Floor 1 dengan Rifter masih winnable solo

---

## MEDIUM (polish sebelum external playtest)

### T09 — Audio: Populate Event Registry
**File:** `src/audio/` — `_load_music_cues()` stub
**Problem:** Semua audio hooks sudah terwire dan null-safe. Tinggal isi event registry.
**Fix:** Populate minimal sound events: hit_light, hit_heavy, player_dash, enemy_death, boss_slam_telegraph, boss_charge, boss_salvo, rest_heal, run_win, run_lose
**Note:** Bahkan placeholder sfx (beep/boop) jauh lebih baik dari silence untuk feel testing

---

### T10 — Win/Loss Screen Polish
**File:** scene/UI yang menampilkan RUN_SUMMARY dan DEATH_SCREEN
**Problem:** ColorRect hitam + "Press R" adalah kesan terakhir player setelah menyelesaikan run.
**Fix:** Minimal: nama screen, floor yang dicapai, total enemies defeated, warna yang sesuai (gold untuk win, dark red untuk loss), tombol "Play Again" yang proper
**Test:** visual

---

### T11 — WarpedWarden Cleanup
**File:** `assets/data/enemies/` — type_id=3 resource
**Problem:** Warden adalah dead data. type_id=5 Vault Sentinel yang spawn via boss pool.
**Fix:** Hapus atau wire sebagai Floor-2 mini-boss. Jangan biarkan jadi sumber kebingungan.

---

## Urutan Pengerjaan yang Disarankan

```
T01 (density cap) → T02 (damage numbers) → T03 (trap loadout guard)
→ T04 (room shapes) → T05 (REST feedback) → T06 (boss pattern)
→ T07 (SALVO rotation) → T08 (Rifter damage) → T09 (audio)
→ T10 (win/loss screen) → T11 (Warden cleanup)
```

T01–T03 adalah blocker paling berdampak pada player experience.
T09 (audio) bisa dikerjakan paralel kapan saja karena tidak ada dependency.
