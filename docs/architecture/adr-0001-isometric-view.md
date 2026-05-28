# ADR-0001: Isometric 2D View — Pengganti Top-Down 2D

## Status
Accepted

## Date
2026-05-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering |
| **Knowledge Risk** | HIGH — versi post-LLM-cutoff (May 2025) |
| **References Consulted** | `docs/engine-reference/godot/modules/rendering.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | `TileMapLayer` (pengganti `TileMap`, diperkenalkan 4.x); `Node2D.y_sort_enabled` |
| **Verification Required** | Konfirmasi TileMapLayer isometric mode berfungsi di Compatibility renderer Godot 4.6; verifikasi Y-sort tidak menyebabkan z-fighting pada overlapping sprites |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR berikutnya untuk movement, collision, dan camera system — semuanya harus mempertimbangkan isometric coordinate space |
| **Blocks** | Produksi aset seni (semua sprite harus menunggu ADR ini Accepted sebelum art pipeline dimulai) |
| **Ordering Note** | ADR ini harus Accepted sebelum art-bible diselesaikan dan sebelum story implementasi sprite dibuat |

## Context

### Problem Statement
Game Concept (`design/gdd/game-concept.md`) mendefinisikan The Last Cipher sebagai "2D top-down" pixel art. Sebelum produksi aset dimulai, keputusan final tentang perspektif kamera harus dibuat — karena ini menentukan seluruh art pipeline, tilemap setup, dan rendering system.

### Constraints
- Engine: Godot 4.6, Compatibility renderer (OpenGL 3.3) — dipertahankan untuk broadest hardware support
- Art style: Pixel art — tidak berubah
- Target platform: PC (Steam/itch.io)
- Scope: MVP solo development (~3–5 minggu) — perubahan perspektif harus tidak menambah kompleksitas teknis berlebihan
- Semua GDD yang sudah ada (game-concept, health-damage, prana-data, audio-system, game-state-scene-flow) dirancang untuk top-down; perlu re-review jika perspektif berubah

### Requirements
- Perspektif baru harus tetap kompatibel dengan drag-and-drop Prana Grid (2D screen-space UI — tidak berubah)
- Karakter dan musuh harus terbaca jelas dari perspektif baru pada ukuran sprite target (~32–48px native)
- Draw call budget tetap <200/frame
- Gameplay logic (posisi, collision, pathfinding) harus tetap bisa diimplementasi di 2D space

## Decision

**The Last Cipher menggunakan perspektif isometric 2D dimetric** — menggantikan top-down 2D yang dideskripsikan di Game Concept.

Implementasi teknis:
- **TileMapLayer** dengan `TileSet.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC` untuk environment
- **Y-sort** aktif (`Node2D.y_sort_enabled = true`) di setiap dungeon room agar sprite karakter/musuh ter-sort otomatis berdasarkan posisi Y
- **Koordinat gameplay** tetap 2D cartesian di logika internal; konversi ke isometric screen-space dilakukan hanya di layer rendering
- **Sprite angle**: dimetric projection (~26.57° — rasio 2:1 lebar:tinggi per tile); tile size **64×32px**
- **Sprite target**: karakter dan musuh **32–48px** tinggi — cukup untuk keterbacaan wajah, siluet, dan animasi ekspresif (referensi: FFT ~32px, Disgaea ~48px)
- **Movement**: screen-space (WASD = atas/bawah/kiri/kanan relatif layar) — tidak ada remapping diagonal; isometric adalah perspektif visual saja, bukan input coordinate space
- **Renderer**: Compatibility (OpenGL 3.3) — dipertahankan, isometric mode tidak butuh Forward+

### Architecture Diagram

```
[Gameplay Logic Layer — cartesian 2D coordinates]
         |
         v
[IsometricRoom node — TileMapLayer (TILE_SHAPE_ISOMETRIC) + y_sort_enabled]
         |
    ┌────┴────┐
    │         │
[Tilemap]  [Entities: Fayde, Enemies, Obstacles]
(floor/wall)  (sorted by Y position for correct draw order)
         |
         v
[Camera2D — fixed isometric angle, no rotation needed]
         |
         v
[Screen — CanvasLayer UI: Prana Grid, HUD (tidak berubah)]
```

### Key Interfaces
- `IsometricRoom.gd`: node root tiap room, mengatur `y_sort_enabled` dan TileMapLayer
- `world_to_iso(pos: Vector2) -> Vector2`: utility function konversi cartesian → screen isometric (jika diperlukan untuk gameplay logic yang membutuhkan screen position)
- Semua node karakter harus menjadi children dari node dengan `y_sort_enabled = true`

## Alternatives Considered

### Alternative A: Tetap Top-Down 2D
- **Description**: Tidak ada perubahan. Game tetap seperti di game-concept.md saat ini.
- **Pros**: Tidak ada rework aset; semua GDD yang sudah ada tetap valid; lebih sederhana teknis
- **Cons**: Kehilangan kedalaman visual dan spatial reading yang isometric berikan; kurang membedakan game dari top-down roguelike lainnya
- **Rejection Reason**: Keputusan pengguna untuk mengganti ke isometric; dilakukan sebelum art pipeline dimulai sehingga biaya rework minimal

### Alternative B: 2.5D (3D World + 2D Sprites)
- **Description**: Environment 3D dengan kamera isometric fixed, sprite karakter tetap 2D billboard
- **Pros**: Lighting dan depth gratis dari engine 3D; lebih imersif
- **Cons**: Butuh pindah dari Compatibility ke Forward+ renderer; kompleksitas teknis jauh lebih tinggi untuk solo dev; bertentangan dengan "2D-first, pixel art" dari technical-preferences.md
- **Rejection Reason**: Overkill untuk MVP scope; bertentangan dengan renderer yang sudah dipilih

### Alternative C: Pseudo-Isometric (Top-Down Miring)
- **Description**: Kamera top-down di-tilt ~30° secara visual, gameplay tetap flat
- **Pros**: Minimal art rework; gameplay logic tidak berubah
- **Cons**: Tidak memberikan kedalaman visual isometric yang sesungguhnya; ambiguous secara visual
- **Rejection Reason**: Tidak memberikan manfaat visual yang cukup untuk justifikasi perubahan

### Alternative D: Middle Ground 4:3 (~36.9°, tile 64×48px)
- **Description**: Proporsi tile lebih tinggi dari 2:1; tile 64×48px memberi sudut ~36.9°, lebih dekat ke feel Hades
- **Pros**: Lebih sinematik; depth lebih terasa; karakter punya ruang vertikal lebih besar
- **Cons**: Hampir tidak ada pixel art game terkenal yang menggunakannya; tooling, tutorial, dan referensi pixel art sangat terbatas
- **Rejection Reason**: Dievaluasi secara eksplisit sebelum ADR ini Accepted. Feel yang diinginkan (FFT/Disgaea-like) dapat dicapai dengan 2:1 dimetric + sprite 32–48px, yang memiliki jauh lebih banyak referensi, tool support, dan tutorial pixel art tersedia

## Consequences

### Positive
- Kedalaman visual lebih besar: dungeon layers (scrap yard → AI Kingdom) lebih berkesan dalam isometric
- Karakter dan musuh memiliki "berat" dan kehadiran lebih kuat di ruang isometric
- Differensiasi visual dari roguelike top-down yang lebih umum
- Keputusan dibuat sebelum satu pun aset produksi dibuat — biaya rework = nol

### Negative
- Semua sprite harus digambar dari sudut dimetric — lebih banyak angle per karakter (umumnya 4–8 arah)
- TileMap dungeon harus dirancang dalam format isometric sejak awal
- Art bible perlu direvisi: ukuran sprite, angle referensi, pivot rules, tile spec
- Game Concept perlu diupdate: "2D top-down" → "2D isometric (dimetric)"
- Y-sort harus dijaga konsisten di seluruh scene — bug mudah terjadi jika node hierarchy tidak benar

### Risks
- **Y-sort edge case**: Sprite besar (boss 48×48px) mungkin memiliki pivot point yang salah → render order glitch. *Mitigasi*: definisikan aturan pivot point di art spec; uji dengan boss sprite awal
- **TileMapLayer isometric di Godot 4.6 belum diverifikasi**: LLM tidak memiliki data post-cutoff tentang perubahan API spesifik. *Mitigasi*: wajib verifikasi dengan Godot editor sebelum implementasi room pertama
- **Silhouette readability**: Sprite 32–48px di sudut dimetric harus diverifikasi sebelum art produksi penuh. *Mitigasi*: test readability dini dengan grey-box sprite; ukuran 32px+ sudah terbukti terbaca di referensi (FFT, Disgaea)

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| game-concept.md | "Art Style: Pixel art, 2D top-down" | Diubah ke "Pixel art, 2D isometric (dimetric)" — ADR ini adalah keputusan formal perubahan tersebut |
| game-concept.md | "Karakter terbaca di ukuran 32–48px native" (direvisi dari 16–24px) | Sprite 32–48px terbukti terbaca di referensi dimetric (FFT, Disgaea); verifikasi grey-box wajib sebelum art produksi |
| health-damage.md | Spatial positioning untuk combat | Gameplay logic 2D cartesian tetap valid; isometric hanya layer visual |

## Performance Implications
- **CPU**: Tidak berubah — gameplay logic tetap 2D cartesian
- **Memory**: Tidak berubah signifikan — sprite isometric lebih besar per angle, tapi dalam budget pixel art
- **Load Time**: Tidak berubah
- **Draw Calls**: Tidak berubah — TileMapLayer isometric tidak menambah draw calls vs. top-down mode

## Migration Plan
1. Update `design/gdd/game-concept.md`: "top-down" → "isometric 2D (dimetric)" *(selesai bersamaan dengan ADR ini)*
2. Update `design/art/art-bible.md`: tambah isometric spec (tile ratio, sprite angle, pivot rules, camera distance readability dari isometric view)
3. Verifikasi TileMapLayer isometric di Godot 4.6 dengan quick test project sebelum implementasi room pertama
4. Definisikan isometric tile size (64×32px) dan sprite target (32–48px) di art spec sebelum asset produksi dimulai

## Validation Criteria
- TileMapLayer isometric mode berjalan di Compatibility renderer tanpa error
- Y-sort mem-produce draw order yang benar untuk karakter yang berjalan di depan dan belakang walls
- Grey-box sprite 32px terbaca dengan jelas dari isometric angle — wajah, siluet, dan arah gerakan terbaca
- Gameplay logic (collision, hitbox) berfungsi sama di isometric coordinate space

## Related Decisions
- `design/gdd/game-concept.md` — sumber keputusan perspektif asli (diupdate bersamaan)
- `design/art/art-bible.md` — art spec perlu direvisi dengan isometric constraints (Migration Plan step 2)
