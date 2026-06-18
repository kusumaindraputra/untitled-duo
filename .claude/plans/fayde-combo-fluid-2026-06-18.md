# Rencana: Fayde Combo Fluidity & Game Feel

**Tanggal**: 2026-06-18
**Tier**: 3 (feature polish pada sistem existing)
**Cakupan**: 4 area perbaikan — hitbox melee, input buffer, knockback, combo feedback

---

## Ringkasan Perubahan

### A. Hitbox Cone (ganti raycast)
**File**: `src/systems/spell_casting_effects.gd`

- Ganti `_select_primary_target()` dari `intersect_ray` → `intersect_shape` dengan cone shape
- Cone didefinisikan di `PlayerController` sebagai properti:
  - **Melee types** (Ashfire): 90° spread, radius = `ASHFIRE_MELEE_RANGE` (80px)
  - **Ranged types**: 45° spread, radius = `CAST_MAX_RANGE` (150px)
- Cone `ConvexPolygonShape2D` di-generate dari facing direction
- Return nearest enemy dalam cone (bukan first-ray-hit)
- **Raycast tetap dipertahankan** untuk targeting model non-default:
  - `LINE_THROUGH_TARGET`, `SINGLE_NEAREST`, `ALL_ON_SCREEN` (pakai Area2D query)
  - Hanya `DIRECTIONAL_FACING` yang diganti ke cone

**File**: `src/gameplay/player_controller.gd`

- Tambah method `get_melee_cone_shape(spread_angle: float, range: float) → ConvexPolygonShape2D`
- Generate cone points: origin (0,0) + arc di depan facing direction
- 6-8 points untuk aproksimasi cone arc

### B. Input Buffer + Cast Lock Jadi Slow
**File**: `src/systems/spell_casting_effects.gd`

- **Input buffer**: 
  - Konstanta `INPUT_BUFFER_WINDOW: float = 0.15` detik
  - Variable `_buffer_pressed: bool = false` dan `_buffer_timer: float = 0.0`
  - Saat SPACE ditekan saat `_cast_lock_timer > 0`: set `_buffer_pressed = true`, `_buffer_timer = INPUT_BUFFER_WINDOW`
  - Di `_process()`: jika `_buffer_pressed` dan `_cast_lock_timer <= 0` → auto-fire `_trigger_cast()`
  - Buffer expire setelah `INPUT_BUFFER_WINDOW` habis

**File**: `src/gameplay/player_controller.gd`

- Cast lock behavior: ganti dari `velocity = Vector2.ZERO` ke **velocity dampened**
- Konstanta baru: `CAST_LOCK_SPEED_FACTOR: float = 0.25` (25% speed selama lock)
- Di `_physics_process()`: saat `CAST_LOCKED`, apply `velocity *= CAST_LOCK_SPEED_FACTOR` setelah movement calculation
- Dash tetap membatalkan lock (existing behavior)

**File**: `src/systems/spell_casting_effects.gd` (signal)

- `cast_hit_started` signal: tambah parameter `slow_factor: float = 0.25`
- PlayerController membaca slow_factor dari signal

### C. Knockback + Hit Reaction
**File**: `src/systems/spell_casting_effects.gd`

- Setelah `apply_damage` sukses, panggil `_apply_knockback(target, knockback_power)`
- `knockback_power = tier_attack_modifier * KNCKBACK_BASE` (12px base)
- Knockback di-clamp ke `KNCKBACK_MAX` (20px)
- Arah: dari Fayde position ke target position
- Implementasi: tween `target.global_position` selama 0.1s dengan easing out

**File**: `src/gameplay/enemy_instance.gd`

- Tambah method `apply_knockback(direction: Vector2, distance: float)` 
- Untuk CharacterBody2D enemies: gunakan position tween
- Untuk StaticBody2D (DummyEnemy): juga gunakan position tween

**File**: `src/gameplay/dummy_enemy.gd`

- Tambah method `apply_knockback(direction: Vector2, distance: float)` (position tween)

### D. Combo Feedback Visual
**File**: `src/ui/combat_hud.gd`

- **Combo counter text**: Label "2x", "3x" muncul di atas chain dots saat chain_index > 1
  - Animasi: scale pop (0.8→1.2→1.0) + fade out setelah 0.5s
  - Warna mengikuti prana type color
- **Chain dots improvement**: 
  - Active dot: tambah scale pulse (1.0→1.3→1.0) looping
  - Completed dots (dilewati): ubah dari gray ke warna type (solid, no animation)

**File**: `src/ui/spell_vfx.gd`

- **Combo ender**: Saat `combo_index == combo_attack_count` (final attack):
  - Hit VFX radius 1.5× lebih besar
  - Screen shake amplitude 1.5× lebih kuat
  - Hitstop duration 1.5× lebih lama
- Signal baru: `combo_ender_fired` atau baca `chain_index_changed` untuk deteksi final

---

## Detail Implementasi per File

### 1. `src/systems/spell_casting_effects.gd`

**Constants baru**:
```gdscript
const INPUT_BUFFER_WINDOW: float = 0.15
const KNCKBACK_BASE: float = 12.0
const KNCKBACK_MAX: float = 20.0
const CONE_ANGLE_MELEE: float = 90.0    # Ashfire
const CONE_ANGLE_RANGED: float = 45.0   # all other types
```

**Variables baru**:
```gdscript
var _buffer_pressed: bool = false
var _buffer_timer: float = 0.0
```

**`_process()` changes**:
- Tambah input buffer countdown
- Cek buffer auto-fire saat lock expires

**`_select_primary_target()` rewrite**:
- Generate cone shape dari PlayerController
- Gunakan `PhysicsDirectSpaceState2D.intersect_shape()`
- Filter hasil ke enemies dalam group `"enemy"`
- Return nearest

**`_fire_attack()` changes**:
- Setelah `apply_damage`, panggil `_apply_knockback()`

**Method baru `_apply_knockback()`**:
- Hitung arah dan jarak knockback
- Panggil `target.apply_knockback()` atau position tween

### 2. `src/gameplay/player_controller.gd`

**Constants baru**:
```gdscript
const CAST_LOCK_SPEED_FACTOR: float = 0.25
const CONE_ANGLE_MELEE: float = 90.0
const CONE_ANGLE_RANGED: float = 45.0
```

**State changes**:
- `CAST_LOCKED` sub-state: tambah `_cast_lock_slow_factor: float`
- `_on_cast_hit_started` signal signature diperluas

**Method baru**:
```gdscript
func get_melee_cone(angle_deg: float, range_px: float) -> ConvexPolygonShape2D
```

### 3. `src/ui/combat_hud.gd`

**Variables baru**:
```gdscript
var _combo_label: Label = null
```

**`_on_chain_index_changed` changes**:
- Spawn combo counter label saat index > 1
- Trigger combo ender saat index == count

**`_rebuild_dots` changes**:
- Completed dots: active color (bukan gray)
- Active dot: scale pulse animation

### 4. `src/ui/spell_vfx.gd`

**`_on_spell_hit_element` changes**:
- Deteksi apakah ini combo ender (via chain state)
- Amplify VFX: radius 1.5×, shake 1.5×, hitstop 1.5×

### 5. `src/gameplay/enemy_instance.gd` + `dummy_enemy.gd`

**Method baru**:
```gdscript
func apply_knockback(direction: Vector2, distance: float) -> void
```
- Tween posisi dengan durasi 0.1s

---

## Yang TIDAK Berubah

- Damage formula (Formula 3) — semua Steps 1-10 tetap sama
- ATTACK_DATA table — modifier values tetap
- Status effect application — tetap setelah damage
- Cast lock DURATION — tetap 0.12s/0.20s, hanya behavior yang berubah (slow vs stop)
- Combo continuation window — tetap 2.0s
- ADJ_ECHO, ADJ_DOUBLE_HIT, dll — tidak disentuh
- PranaGrid / CombinationResolution — tidak disentuh

---

## Urutan Implementasi

1. **Knockback** (paling independen) — enemy_instance.gd, dummy_enemy.gd, spell_casting_effects.gd
2. **Cast lock → movement slow** — player_controller.gd
3. **Input buffer** — spell_casting_effects.gd
4. **Cone hitbox** — spell_casting_effects.gd, player_controller.gd
5. **Combo feedback visual** — combat_hud.gd, spell_vfx.gd
6. **Tests** — update SC&E tests, PlayerController tests

---

## Testing

- **Unit tests**: Update AC-SC-07 (targeting), AC-SC-10 (cast lock), dan tambah test baru untuk:
  - Input buffer (press SPACE 0.1s early → still fires)
  - Cone targeting (enemy di 45° offset masih terdeteksi)
  - Knockback (enemy position berubah setelah hit)
  - Slow factor (velocity dikalikan 0.25 selama lock)
- **Manual test**: TrainingRoom.tscn — test combo fluiditas dengan dummy
