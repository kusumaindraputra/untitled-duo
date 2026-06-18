# Layer 1 Template Pool — Deep Scrap Yard

> **Status**: Draft | **Fase**: 2 — Paper Design (LD-07)
> **Created**: 2026-06-18
> **Arena**: Diamond 1280×768 game-px (WALL_HALF_X=640, WALL_HALF_Y=384)
> **Obstacle zone**: Inner 82% diamond. Obstacles = half-cover debris (block movement, not Prana).
> **Tile size**: 64×32px isometric. Tile grid: ±16 tx, ±20 ty.

---

## Template Design Principles

1. **Readable dalam 5 detik** — player di prep phase harus langsung paham "apa shape ruangan ini?"
2. **Valid zone berbeda per template** — bukan cuma inner diamond, tapi zone spesifik shape.
3. **Spawn marker di posisi yang fair** — musuh tidak spawn di belakang player.
4. **Movement flow intentional** — setiap template menciptakan pola movement berbeda.
5. **Prep decision impact** — layout memengaruhi keputusan Prana arrangement.

---

## Template Catalog (12 designs)

### 1. THE DIAMOND — "Classic Open Arena"

```
              ╱‾‾‾‾‾╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾╲
         ‾‾‾‾‾○‾‾○‾‾‾‾‾‾‾
          ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
           ‾‾‾‾○‾‾‾○‾‾‾‾
            ‾‾‾‾‾‾‾‾‾‾‾
             ‾‾‾‾‾‾‾‾
```

- **Identitas**: Arena terbuka klasik. Obstacle tersebar merata di inner diamond.
- **Prep readability**: SANGAT MUDAH — tidak ada struktur dominan, player fokus ke enemy composition.
- **Valid zone**: Full inner diamond (82%).
- **Movement flow**: Circular bebas. Dash bisa ke segala arah.
- **Enemy lanes**: Musuh mendekat dari semua arah, sedikit funneling.
- **Mengajarkan**: Baseline. Template untuk room Combat pertama (warm-up).
- **Obstacle count**: 5-7 (lower end — fewer obstacles, more open).

### 2. THE SPLIT — "Two Lanes"

```
              ╱‾‾‾‾‾╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾╲
         ‾‾‾‾‾‾███‾‾‾‾‾‾‾
          ‾‾‾‾‾███‾‾‾‾‾‾
           ‾‾‾‾███‾‾‾‾‾
            ‾‾‾‾‾‾‾‾‾‾‾
             ‾‾‾‾‾‾‾‾
```

- **Identitas**: Tembok debris vertikal di tengah membelah arena jadi jalur KIRI dan KANAN.
- **Prep readability**: MUDAH — player langsung lihat "ok, dua jalur, musuh datang dari kiri atau kanan."
- **Valid zone**: Dua strip vertikal di kiri dan kanan center line. Center strip (40px wide) excluded.
- **Movement flow**: Player memilih kiri atau kanan. Dash bisa crossing antar jalur.
- **Enemy lanes**: Musuh terbelah dua — setengah lewat kiri, setengah kanan. SEEKER dari kedua sisi = bahaya.
- **Mengajarkan**: Lane commitment. Dash crossing. Posisi awareness.
- **Obstacle count**: 7-9 (higher end — wall debris + side obstacles).

### 3. THE CROSS — "Four Corners"

```
              ╱‾‾‾‾‾╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾╲
         ‾‾‾‾‾‾‾█‾‾‾‾‾‾‾‾
          ‾‾‾‾███‾‾‾‾‾‾‾
           ‾‾‾‾‾█‾‾‾‾‾‾‾
            ‾‾‾‾‾‾‾‾‾‾‾
             ‾‾‾‾‾‾‾‾
```

- **Identitas**: Dua baris debris silang (+) membentuk 4 kuadran terpisah.
- **Prep readability**: SEDANG — 4 kuadran jelas, tapi player butuh sejenak membaca mana yang open.
- **Valid zone**: 4 zona persegi di tiap kuadran. Cross center excluded.
- **Movement flow**: Circular terbatas — player harus bergerak antar kuadran lewat celah cross.
- **Enemy lanes**: Musuh terkonsentrasi di kuadran terdekat spawn marker. Enemies dari kuadran berbeda = flank attack.
- **Mengajarkan**: Kuadran control. Movement terbatas = positioning kritis.
- **Obstacle count**: 6-8.

### 4. THE CORRIDOR — "Narrow Passage"

```
              ╱‾‾‾‾‾╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱‾‾‾█████████‾‾‾‾╲
         ‾‾‾‾█████████‾‾‾
          ‾‾‾‾█████████‾
           ‾‾‾‾‾‾‾‾‾‾‾‾
            ‾‾‾‾‾‾‾‾‾‾‾
             ‾‾‾‾‾‾‾‾
```

- **Identitas**: Dua kluster debris besar di kiri-kanan, menyisakan koridor sempit di tengah.
- **Prep readability**: MUDAH — "jalan lurus di tengah."
- **Valid zone**: Dua area lebar di kiri dan kanan. Center corridor (80px wide) clear.
- **Movement flow**: Linear — player bergerak maju-mundur di koridor. Dash ke samping mentok di debris.
- **Enemy lanes**: Musuh funnel ke koridor = semua dari depan/belakang. SWARMER di koridor sempit = sangat berbahaya.
- **Mengajarkan**: Kiting linear. Zoning spell di koridor. RUSHER di ruang sempit = timing kritis.
- **Obstacle count**: 8-9 (dense clusters).

### 5. THE ARENA — "Open Center"

```
              ╱‾‾‾‾‾╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾╲
         ‾‾‾██‾‾‾‾‾‾‾██‾‾‾
          ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
           ‾‾‾‾‾‾‾‾‾‾‾‾‾
            ‾‾██‾‾‾‾‾██‾
             ‾‾‾‾‾‾‾‾
```

- **Identitas**: Center kosong lebar. Obstacle hanya di pinggir — seperti colosseum mini.
- **Prep readability**: SANGAT MUDAH — "ruang dansa."
- **Valid zone**: Hanya outer ring (15-30% dari tepi diamond). Center 50% clear wajib.
- **Movement flow**: Circular bebas maksimum. Dash bisa ke segala arah tanpa obstacle.
- **Enemy lanes**: Musuh dari segala arah, tidak ada funnel. SHOOTER di ruang terbuka = bahaya (tidak ada cover).
- **Mengajarkan**: Open space combat. No cover = movement is defense. SHOOTER counterplay.
- **Obstacle count**: 5-6 (lower end, hanya di pinggir).

### 6. THE L-WEDGE — "Corner Fortress"

```
              ╱‾‾‾‾‾╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾╲
         ‾‾‾‾‾‾‾‾‾‾‾‾████
          ‾‾‾‾‾‾‾‾‾‾████
           ‾‾‾‾‾‾‾‾████
            ‾‾‾‾‾‾‾‾‾‾‾
             ‾‾‾‾‾‾‾‾
```

- **Identitas**: Blok debris besar berbentuk L di satu sudut, menyisakan area open berbentuk L terbalik.
- **Prep readability**: SEDANG — player harus membaca "ok, area open di sisi yang mana?"
- **Valid zone**: Bentuk L-block di satu kuadran. Sisa arena clear.
- **Movement flow**: Asimetris — satu sisi ruangan lebih terbuka. Player condong ke area open.
- **Enemy lanes**: Musuh dari arah open harus melewati choke di dekat L-block. Spawn di belakang L-block = ambush.
- **Mengajarkan**: Asymmetry awareness. Cover usage. Movement bias ke area aman.
- **Obstacle count**: 6-8 (concentrated in one zone).

### 7. THE PILLARS — "Scattered Posts"

```
              ╱‾‾‾‾‾╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾╲
         ‾‾‾‾█‾‾‾‾‾‾█‾‾‾‾
          ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
           ‾‾‾‾‾█‾‾‾‾‾‾‾‾
            ‾‾‾‾‾‾‾‾‾‾‾‾
             ‾‾‾‾█‾‾‾█‾‾
```

- **Identitas**: 4-6 debris pillar terisolasi, tersebar merata. Masing-masing small radius, tapi banyak.
- **Prep readability**: MUDAH — "pilar-pilar, gesit aja."
- **Valid zone**: Full inner diamond, tapi tiap pillar harus terpisah ≥100px (lebih renggang dari default 75px).
- **Movement flow**: Weaving — player bergerak zig-zag antar pillar. Dash pendek antar pillar.
- **Enemy lanes**: Musuh terpecah oleh pillar. SEEKER harus navigate pillar. RUSHER charge bisa kena pillar.
- **Mengajarkan**: Pillar dancing. Micro-positioning. RUSHER charge collision dengan pillar.
- **Obstacle count**: 5-6 (tapi spread merata, bukan cluster).

### 8. THE GAUNTLET — "Firing Lane"

```
              ╱‾‾‾‾‾╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱‾‾‾‾██‾‾‾‾██‾‾‾‾╲
         ‾‾‾‾██‾‾‾‾██‾‾‾‾
          ‾‾‾‾██‾‾‾‾██‾‾
           ‾‾‾‾██‾‾‾‾██‾
            ‾‾‾‾‾‾‾‾‾‾‾‾
             ‾‾‾‾‾‾‾‾
```

- **Identitas**: Dua baris debris sejajar membentuk "lorong tembak" di tengah. Seperti corridor tapi lebih lebar.
- **Prep readability**: MUDAH — "lorong lurus, musuh dari depan."
- **Valid zone**: Dua strip di kiri dan kanan (tempat debris baris). Center lane 100px wide clear.
- **Movement flow**: Linear dengan sedikit ruang lateral. Funneling jelas.
- **Enemy lanes**: Semua musuh harus melewati lorong. Perfect untuk Prana AOE. RUSHER di lorong = tidak bisa menghindar.
- **Mengajarkan**: AOE value. Funnel = spell efficiency. Positioning for max targets.
- **Obstacle count**: 7-9 (baris kiri-kanan).

### 9. THE ISLANDS — "Three Zones"

```
              ╱‾‾‾‾‾╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱‾‾‾███‾‾‾‾███‾‾‾╲
         ‾‾‾███‾‾‾‾███‾‾‾
          ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
           ‾‾‾‾‾‾‾‾‾‾‾‾‾
            ‾‾‾‾███‾‾‾‾‾
             ‾‾‾‾‾‾‾‾
```

- **Identitas**: Tiga kluster debris besar membentuk "pulau" — 2 di atas, 1 di bawah (atau sebaliknya).
- **Prep readability**: SEDANG — "ada tiga pulau, aku di tengah."
- **Valid zone**: 3 zona terpisah (masing-masing ~150px radius).
- **Movement flow**: Player bergerak di celah antara 3 pulau — figur-8 atau circular.
- **Enemy lanes**: Musuh mengalir di celah antar pulau. Funneling di 2-3 choke point.
- **Mengajarkan**: Multi-directional threat. Choke point control. Movement antara cover.
- **Obstacle count**: 7-9 (terkonsentrasi di 3 pulau).

### 10. THE MAZE — "Tight Weave"

```
              ╱‾‾‾‾‾╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱‾█‾‾█‾‾‾‾█‾‾█‾‾‾╲
         ‾█‾‾█‾‾‾‾█‾‾█‾‾‾
          ‾‾█‾‾‾‾‾‾‾‾█‾‾
           ‾‾█‾‾‾‾‾‾‾‾█‾
            ‾‾‾█‾‾‾‾█‾‾‾
             ‾‾‾‾‾‾‾‾
```

- **Identitas**: Banyak obstacle kecil membentuk jalur berliku. Obstacle count tertinggi.
- **Prep readability**: SULIT — layout rumit, player butuh 8-10 detik membaca. Khusus Elite room.
- **Valid zone**: Full inner diamond dengan minimum clearance antar obstacle diturunkan ke 60px (default 75px).
- **Movement flow**: Tight, banyak belokan. Dash pendek-pendek. Positioning presisi.
- **Enemy lanes**: Musuh terpecah dan mengalir di jalur sempit. RUSHER di maze = chaos (charge kena wall).
- **Mengajarkan**: Tight-space combat. Micro-dodge. RUSHER weakness di ruang sempit.
- **Obstacle count**: 9 (maximum).
- **⚠ Hanya untuk Elite room** — terlalu kompleks untuk Combat biasa.

### 11. THE SANCTUM — "Reverse Arena"

```
              ╱██████╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾╲
         ‾‾███████████‾‾‾
          ‾‾███████████‾‾
           ‾‾‾‾‾‾‾‾‾‾‾‾‾
            ‾‾‾‾‾‾‾‾‾‾‾
             ╲‾‾‾‾‾‾╱
```

- **Identitas**: Ring debris mengelilingi pinggir arena. Center kosong. Kebalikan dari Diamond.
- **Prep readability**: MUDAH — "aku di tengah, musuh di luar."
- **Valid zone**: Outer ring only (60-82% dari center). Center 55% clear.
- **Movement flow**: Player di tengah, musuh mendekat dari segala arah melewati ring debris.
- **Enemy lanes**: Musuh harus melewati ring = funneling di gap antar debris. Tapi setelah lewat = open.
- **Mengajarkan**: Center control. 360° awareness. Ring sebagai buffer zone.
- **Obstacle count**: 7-9 (membentuk ring).

### 12. THE CHOKE — "Single Gate"

```
              ╱‾‾‾‾‾╲
           ╱‾‾‾‾‾‾‾‾‾‾‾╲
        ╱██████████████████╲
         ‾‾‾‾‾‾‾‾‾‾‾‾████
          ‾‾‾‾‾‾‾‾‾‾████
           ‾‾‾‾‾‾‾‾████
            ‾‾‾‾‾‾████
             ‾‾‾‾████
```

- **Identitas**: Dinding debris besar dengan satu celah sempit (60-80px). Arena terbelah jadi dua area besar.
- **Prep readability**: SANGAT MUDAH — "satu pintu."
- **Valid zone**: Dua zone besar terpisah. Hanya connected lewat celah.
- **Movement flow**: Player harus melewati choke untuk berpindah area. Choke = danger zone.
- **Enemy lanes**: Semua musuh harus lewat choke yang sama = death funnel (untuk player, atau untuk musuh?).
- **Mengajarkan**: Choke point = spell value. AOE di choke. Risk assessment — kapan lewat choke.
- **⚠ Hanya untuk Elite room** — terlalu punishing untuk Combat biasa.

---

## Selection: 5 Best for Blockout

Setelah review 12 template, 5 yang paling direkomendasikan untuk blockout (LD-14):

| # | Template | Type | Alasan Dipilih |
|---|----------|------|----------------|
| 1 | **The Diamond** | Combat | Baseline universal. Semua player familiar. Warm-up room. |
| 2 | **The Split** | Combat/Elite | Lane-based = decision meaningful. Readability tinggi. |
| 4 | **The Corridor** | Combat/Elite | Linear flow = kontras dengan circular templates. Funneling. |
| 5 | **The Arena** | Combat | Open space = movement celebration. Kontras dengan Corridor. |
| 8 | **The Gauntlet** | Elite | AOE value + linear flow. Spawn funnel = spell satisfaction. |

**Rasionale**: 5 template ini cover spectrum **Open (Arena) → Lane (Split) → Linear (Corridor/Gauntlet) → Default (Diamond)**. Setiap template menciptakan decision berbeda di prep phase dan movement pattern berbeda di combat phase. Tidak ada yang redundant.

Template 6-12 disimpan untuk VS+ (Layer 2+ atau post-playtest iteration).

---

## Template Parameters (untuk LD-14 blockout)

| Template | Type | Obstacle Count | Valid Zone | Spawn Markers | Min Clearance |
|----------|------|---------------|------------|---------------|---------------|
| Diamond | Combat | 5-7 | Full inner 82% diamond | 3 (120° apart) | Default (90/110/75) |
| Split | Combat/Elite | 7-9 | 2 side strips, center excluded | 3 (left, right, top/bottom) | Default |
| Corridor | Combat/Elite | 8-9 | 2 side blocks, center clear | 3 (front, back, side) | Default |
| Arena | Combat | 5-6 | Outer ring only (15-30% edge) | 3 (evenly spread) | Wider between (100px) |
| Gauntlet | Elite | 7-9 | 2 side strips, center lane clear | 3 (front, back, 1 side) | Default |

> **Note**: Spawn marker positioning is per-template. Current `_place_spawn_markers()` uses
> centroid + 120° target angles. Each template will override with template-specific marker
> positions in the `.tres` file (LD-12).
