# Art Bible — The Last Cipher

*Created: 2026-05-21*
*Updated: 2026-06-11 — ADR-0001 (Isometric 2D View, Accepted 2026-05-26) applied: top-down perspective replaced with isometric dimetric; sprite height targets updated to 32–48px; tile resolution updated to 64×32px; FFT/Disgaea added as isometric reference (Section 9, Reference 6).*
*Status: Complete*

> **Art Director Sign-Off (AD-ART-BIBLE)**: Skipped — Lean review mode.

---

## 1. Visual Identity Statement

**One-Line Visual Rule:** The world breathes softly; magic screams.

The layers are serene and mysterious — soft earth tones, warm atmospheric haze, a world that has been quietly asleep for centuries. Prana shatters that stillness with vivid jewel-tone explosions. The contrast is the drama.

**Kids-friendly constraint (hard):** All visual elements must be appropriate for players aged 7+. No blood, gore, or body horror. Enemy defeat is always a dissolve/particle effect, never physical impact.

### Principle 1: Serene World, Violent Magic
Environments use warm-neutral, low-saturation earth tones with gentle atmospheric depth. Prana effects use full-saturation jewel tones: particle bursts, screen-filling color, vivid light that belongs to a different world than the metal around it.

*Pillar anchor:* Chaos Has Consequences — a quiet world makes every spell effect immediately legible as signal, not noise.

*Design test:* Place a Prana-cast screenshot next to an environment screenshot. If a stranger cannot instantly identify which is the magic, the environment is too busy or the effect is too subtle.

### Principle 2: Every Prana Type Has a Color Name
Each Prana type owns one exclusive jewel tone, applied consistently to its icon, cast particle burst, damage numbers, synergy glow, and UI highlights. Color IS the Prana type's identity — the grid must be readable at a glance without labels.

*Pillar anchor:* Power is Earned Through Understanding — color-as-identity is the shortcut from first glance to mastery.

*Design test:* Cover all Prana text labels. Can a new playtester identify all 5 Prana types by color alone within 30 seconds?

### Principle 3: Whimsy Lives in the Details
Every room contains at least one non-interactive background detail — drifting spores, moss in the stonework, a small creature disappearing into shadow — that makes the world feel inhabited and quietly wondrous.

*Pillar anchor:* Memory Returns — environmental curiosity signals that discovery is rewarded, before the player ever finds a memory fragment.

*Design test:* Does every room contain at least one background detail that has no gameplay function but rewards a player who pauses to notice it?

---

## 2. Mood & Atmosphere

### Mood Target per Game State

**2.1 Main Menu / Title Screen**
- **Primary Emotion:** Curiosity on the edge of a threshold — standing before a locked door that is already slightly ajar
- **Lighting:** Warm-cool split: deep indigo ambient with a single warm lantern glow at center. Low contrast, low brightness. Soft vignette.
- **Energy Level:** Contemplative
- **Atmospheric Descriptors:** Ancient, hushed, inviting, layered, secretive
- **Mood-Carrying Element:** The title Prana type glows in the idle Prana palette (last-used Prana type, or slow cycle on first launch). Pulse rate: one breath per two seconds. Doorway mist behind it has a subtle 2-frame ambient shimmer.

**2.2 Preparation Phase**
- **Primary Emotion:** The held breath before a chess move — I know what is coming, but not all of it
- **Lighting:** Neutral-warm, medium contrast. Room fully lit. Prana grid panel receives a slightly cooler inner glow, marking it as the space of thought.
- **Energy Level:** Measured
- **Atmospheric Descriptors:** Still, deliberate, expectant, focused, charged
- **Mood-Carrying Element:** Enemy silhouettes visible in the doorway — not advancing, just waiting. Prana grid is the brightest point in the frame. Hierarchy: room (medium brightness) → grid (bright) = decision space is visually declared.

**2.3 Combat Phase**
- **Primary Emotion:** The adrenaline surge when a plan executes exactly right — and the spike of fear when it doesn't
- **Lighting:** Dynamic, spell-reactive. Ambient drops 15–20% at wave start (room dims slightly). High contrast. Spell bursts own the brightness budget.
- **Energy Level:** Frenetic
- **Atmospheric Descriptors:** Explosive, kinetic, vivid, chaotic, legible
- **Mood-Carrying Element:** Multiple jewel-tone Prana colors firing simultaneously create a stained-glass burst effect against the low-saturation environment. Enemy defeat = color bloom outward from center, never violent impact.

> **Prep→Combat transition:** A 0.3s ambient-dim at wave start marks the threshold from "thinking" to "fighting."

**2.4 Victory / Room Clear**
- **Primary Emotion:** The exhale — relief with a warm tail of satisfaction, not triumph
- **Lighting:** Brief warm shift: ambient temperature rises one notch post-combat. Soft gold wash, 1–2 seconds, then returns to neutral.
- **Energy Level:** Measured, decelerating
- **Atmospheric Descriptors:** Warm, settling, brief, earned, quiet
- **Mood-Carrying Element:** Prana drops land one by one, each pulsing its Prana color once then settling. Background whimsy details (spores, rust dust) reassert themselves — the world exhaled too.

**2.5 Defeat / Death Screen**
- **Primary Emotion:** Bittersweet sting of a story cut short — not shame, not punishment, but "I want to know how it ends"
- **Lighting:** Desaturated, cool-blue shift. World drains of warmth. The last-active Prana type in Fayde's hand holds the only remaining warm color.
- **Energy Level:** Contemplative, quiet
- **Atmospheric Descriptors:** Faded, cool, wistful, unfinished, still
- **Mood-Carrying Element:** Last active Prana type on the grid slowly desaturates as the overlay settles. "Try Again" appears only after desaturation completes (~1.5s) — weight without being maudlin.

**2.6 Run Summary / Post-Run Screen**
- **Primary Emotion:** Quiet pride of reading your own diary — curiosity about the shape of what just happened
- **Lighting:** Warm, steady, low-energy. Like a campfire room at the dungeon entrance. No combat urgency.
- **Energy Level:** Contemplative
- **Atmospheric Descriptors:** Reflective, warm, narrative, earned, anticipatory
- **Mood-Carrying Element:** The run's most-used combo displayed at visual center in full jewel-tone color — the run's signature. Ties Principle 2 (Every Prana Type Has a Color Name) to the emotional beat of "I built that."

**2.7 Boss Encounter**
- **Primary Emotion:** Awe-dread of something genuinely larger — not terror, but the feeling of standing at the base of a mountain you chose to climb
- **Lighting:** Boss's reserved color (one unique color per boss, outside the Prana palette) bleeds into room ambient. High contrast, deeper shadows. Boss presence fills the brightness budget.
- **Energy Level:** Frenetic with ceremonial gravity
- **Atmospheric Descriptors:** Vast, tense, electric, ceremonial, vivid
- **Mood-Carrying Element:** Boss owns one reserved color that appears nowhere else in the game — not a Prana color, not a UI color. Player's familiar jewel-tones appear as acts of defiance against the boss's chromatic authority. Color contrast = power narrative. *(Dependency: Section 4 Color System must reserve boss color slots.)*

### Cross-State Consistency Rules

1. **Environment saturation cap:** Backgrounds stay below 40% saturation in all game states — menus included.
2. **Transitions must be felt:** Prep→Combat (0.3s ambient dim) and Combat→Victory (1–2s warm wash) each have a visual transition beat. Changes in energy level are not instant cuts.
3. **Jewel tones belong to magic exclusively:** If any UI element, environment detail, or background prop reaches full jewel-tone saturation, it must be associated with Prana or a spell. No decorative full-saturation environment elements.

---

## 3. Shape Language

### 3.1 Foundational Shape Grammar

Three shape families with strict roles:

| Family | Base Shapes | Used For | Emotional Signal |
|--------|-------------|----------|------------------|
| **Arcs** | Circles, ellipses, organic curves | Prana types, UI grid, spell particles, player character | Familiar, approachable, alive |
| **Irregular Polygons** | Uneven pentagons/hexagons, broken stone | Dungeon walls, floors, environment | Ancient, imperfect, formed not built |
| **Sharp Spikes** | Triangles, explosion shapes, crystals | Spell VFX, aggressive enemy effects, hazard indicators | Uncontrollable energy — "magic screams" |

**Golden rule:** Arcs dominate things you touch and control. Irregular polygons dominate spaces you traverse. Sharp spikes appear only when something violent is happening.

### 3.2 Character Silhouette Philosophy

All characters must be identifiable at 32×32 px in 0.3 seconds mid-combat.

**Player — Fayde**
- Shape: Compact oval body + single vertical accent (small Prana-focus or short staff)
- Not a warrior silhouette — approachable, slightly frail. The contrast between "looks fragile, casts devastatingly" is the player fantasy.
- In-combat identifier: only character that emits jewel-tone color from their hands. Moving light source = the player.
- Design test: Silhouette-only screenshot. Is the player instantly distinct from all three enemy types?

**Enemy Archetype A — The Drifter** (ranged/projectile)
- Shape: Wide and flat — horizontal mass, floating limbs, diffuse edges
- Silhouette keyword: Wide low rectangle
- Communicates: Passive ambient threat; attacks from distance

**Enemy Archetype B — The Charger** (melee/rush)
- Shape: Tall and narrow — vertical spike cluster, forward-leaning head, coiled legs
- Silhouette keyword: Tall vertical spike
- Communicates: Kinetic danger arriving imminently

**Enemy Archetype C — The Cluster** (swarm/summoner)
- Shape: Central oval mass + orbiting small circle units. Swarm units are identical to each other (legibility through repetition).
- Silhouette keyword: Central mass + satellites
- Communicates: Overwhelming, requires AoE thinking

**Triangle of contrast:** Drifter (wide flat), Charger (tall narrow), Cluster (central+orbiting) — three shapes that cannot be confused for one another at any zoom level.

**Boss — The Warped Warden**
- Shape: Deliberately asymmetric large irregular polygon. One side heavier than the other. Arc remnants at the edges suggest what the machine was before it changed.
- A single spiral/broken-Prana mark at visual center is the first focal point.
- Asymmetry reads as "transformation in progress," not broken sprite. One vertical axis may be symmetric; horizontal axis is intentionally imbalanced.
- Communicates: Vast, tragic, something that was once normal.

### 3.3 Environment Geometry

**Dominant geometry:** Irregular polygon with preference for obtuse angles (100–150°). Nothing sharper than 80° in decorative features.

- **Floors:** Tile grid with organic edge variation. Cracks, slightly raised tiles, surfaces that have settled. Not all tile edges align perfectly.
- **Walls:** Uneven thickness, profile varies every 4–6 tiles. No wall section is perfectly straight for more than 6 tiles.
- **Corners:** No true right angles anywhere. All corners have a chamfer or 1–2px radius (pixel art scale).
- **Doorways/Arches:** Oval or ogival arch shape — never rectangular. Arches do not need to be perfectly symmetric.

Irregular environment geometry creates automatic contrast with regular Prana/UI geometry. When a spell burst (arc + spike) appears against irregular metal or stone, shape contrast reinforces colour contrast.

### 3.4 UI Shape Grammar

UI uses **regularized polygons** — derived from dungeon shapes but smoothed. Like dungeon stone that has been sanded down.

| UI Element | Shape | Derived From | Reason |
|------------|-------|--------------|--------|
| Main panels | Rounded rectangle (medium radius) | Smoothed stone | Structured but organic enough to feel in-world |
| Buttons | Rounded rectangle (large radius) | Polished pebble | Clearly pressable, all-ages approachability |
| Tooltips | Soft irregular rect (one corner more rounded) | Small stone chip | Light, easy to dismiss |
| Health/status bar | Capsule | Arc of the Prana system | Connects player status to the Prana world |

**Prana Grid — "The Space of Decision"**

- **Container:** Octagonal frame (8 sides). Visually distinct from every other UI and environment element. Communicates: this is an instrument, not an inventory.
- **Slots:** Perfect circles. Empty slot = potential. Filled slot = Prana type within arc slot. Shapes nest naturally.
- **Slot spacing:** Minimum 3–4 px gap between slots — each slot reads as a discrete unit.
- **Frame accents:** Four small Prana-fragment ornaments at octagonal corners (non-functional, reinforce "sacred instrument" read).

Hexagonal/honeycomb association signals precision and expertise — appropriate for *Power is Earned Through Understanding*.

**All-ages compliance:** No UI shape has angles below 60°. No shape that reads as a threatening or aggressive symbol cross-culturally.

### 3.5 Visual Hierarchy by Game State

**Hierarchy rule: The more important an element, the more geometrically regular its shape.** This works before colour registers.

**During Preparation Phase:**
1. Prana grid (most regular shape on screen — octagonal container, perfect circle slots)
2. Player character (compact oval, unique among angular environment)
3. Enemy silhouettes in doorway (present as threat signal, not fully resolved)
4. Environment (most irregular — background by definition)

**During Combat Phase:**
1. Spell VFX (arc burst + spike — most dynamic and shape-contrasting element on screen)
2. Enemy being hit (jewel-tone outline highlights the target)
3. Player character (stable rounded anchor amid chaos)
4. Prana grid (purposefully dim during combat — "not your turn to arrange Prana")

**Shape hierarchy rules (never break):**
- No environment element may be more regular than any UI element
- Spike shapes never appear in UI — they compete with spell VFX for attention
- The octagonal grid container shape is unique in the entire game — no other element uses 8 sides

### 3.6 Shape Language Quick Reference

| Asset Category | Dominant Shape | Forbidden Shapes | Emotional Keyword |
|----------------|---------------|------------------|-------------------|
| Player | Arc/oval + vertical | Spike, right angle | Scholar, approachable |
| Enemy Drifter | Wide flat polygon | Vertical spikes | Ambient threat |
| Enemy Charger | Vertical spike cluster | Round/wide | Kinetic danger |
| Enemy Cluster unit | Small circle mass | Sharp angles | Overwhelming |
| Boss | Asymmetric large polygon | Perfect symmetry | Tragic, vast |
| Dungeon floor/wall | Irregular polygon | True right angles | Ancient, settled |
| Doorway/arch | Oval or ogival arc | Square frame | Invitation |
| Prana grid frame | Regular octagon | Rectangle, square | Deliberate, sacred |
| Prana slot | Perfect circle | Any polygon | Potential |
| UI button/panel | Rounded rectangle | Sharp corners | Approachable |
| Spell VFX | Arc burst + spike | Regular polygon | Screaming, violent |
| Prana particle | Small arc cluster | Spike | Jewel, identity |

---

## 4. Color System

### 4.1 Environment Palette — "The Canvas"

All 7 colors stay at or below 40% saturation in all game states. These are the silence that makes magic scream.

| ID | Name | HSL | Hex | Role | Appears On |
|----|------|-----|-----|------|-----------|
| E1 | **Dungeon Stone** | HSL(30, 12%, 22%) | `#3A3530` | Primary wall surface | Walls, wall tops |
| E2 | **Worn Slate** | HSL(220, 8%, 30%) | `#474B52` | Deep recesses, shadow faces | Wall shadow sides, ceiling |
| E3 | **Hearthstone** | HSL(28, 25%, 38%) | `#5E4E3D` | Structural elements | Door frames, pillars, raised blocks |
| E4 | **Ancient Floor** | HSL(35, 18%, 28%) | `#4A4038` | Primary floor tile | Floor (dominant) |
| E5 | **Weathered Floor** | HSL(40, 22%, 35%) | `#5C5040` | Floor variation | Cracks, raised tiles |
| E6 | **Atmosphere Haze** | HSL(240, 15%, 12%) | `#1B1B22` | Void color — deepest background | Ceiling voids, door interiors, deep shadow |
| E7 | **Warm Lantern Bleed** | HSL(38, 30%, 55%) | `#8E7358` | Only warm accent in environment | Sconces, moss glow, floor ambient spill |

**Usage rules:**
- E7 is the only warm-accent environment color. Glowing environmental props (plants, moss, carvings) use E7 or a desaturated tint — never a jewel tone.
- During Boss Encounter (Mood 2.7): environment ambient shifts toward the boss's reserved color; environment palette desaturates a further ~10% to make boss color feel invasive.

### 4.2 Magic / Prana Palette — 5 Prana Colors

Each Prana type owns one exclusive jewel tone. The color appears on: Prana icon, cast particle burst, damage numbers, synergy glow, and any UI highlight tied to that Prana type. No other element in the game uses these colors at full saturation.

All Prana colors: HSL saturation 85–100%, lightness 50–65% — reads as jewel tone against E6 background.

| Prana | Name | Element | HSL | Hex | Semantic Identity |
|------|------|---------|-----|-----|------------------|
| R1 | **Ashfire** | Fire / Destruction | HSL(14, 95%, 55%) | `#F24C1D` | Ambition that burns everything — including plans. Force without precision. |
| R2 | **Voidblue** | Shadow / Void | HSL(235, 90%, 62%) | `#4A5EF5` | Silence that reveals what was always there. Control, concealment, deception. |
| R3 | **Stormgold** | Lightning / Speed | HSL(48, 100%, 55%) | `#FFCC00` | Reflex made visible. Reaction, disruption, momentum. |
| R4 | **Deepfrost** | Ice / Time | HSL(195, 85%, 60%) | `#3DD9F0` | Patience imposed on a world that resists it. Slowing, crystallizing, trapping. |
| R5 | **Verdant** | Nature / Growth | HSL(138, 80%, 48%) | `#1AC953` | Life that adapts faster than destruction. Healing, terrain manipulation, persistence. |

**Hue separation:** P1(14°) / P2(235°) / P3(48°) / P4(195°) / P5(138°). P1–P3 are closest at 34° — backup cues required (see Section 4.5).

### 4.3 Boss Reserved Colors

Each boss gets one exclusive color outside the Prana palette. This color tints the arena ambient during the encounter, then desaturates to 0% on boss death.

**Rule:** Boss color must be outside all 5 Prana hue zones by at least 40°, or distinguished by saturation+lightness if hue gap is narrower.

| Slot | Boss | Name | HSL | Hex | Notes |
|------|------|------|-----|-----|-------|
| B1 | Warped Warden (MVP) | **Corruption Violet** | HSL(285, 70%, 48%) | `#9B2ED4` | Violet-magenta. Not achievable by mixing any two Prana colors. Reads as "wrong" against the warm environment and clean jewel-tone vocabulary. |
| B2 | TBD (Vertical Slice) | Reserved | ~165–180° zone | — | Teal-green, distinct from Verdant (138°) |
| B3 | TBD (Vertical Slice) | Reserved | ~340–355° zone | — | Rose-crimson, distinct from Ashfire (14°) |

**Boss color rules:**
1. Boss color appears only on: room ambient tint, boss sprite accent, boss attack particles. Never on UI, Prana effects, or Fayde.
2. Boss color desaturates to 0% on death — the arena exhales the corruption.

### 4.4 UI Palette

UI draws from environment palette and Prana palette only. No new colors introduced — except health red (see below).

| UI Element | Color | Source | Reason |
|------------|-------|--------|--------|
| Prana grid frame | E3 Hearthstone `#5E4E3D` + E7 inner glow | Environment | Frame reads as dungeon artifact, not magic. Slots (magic) contrast against it. |
| Prana grid background (empty slot) | E6 Atmosphere Haze `#1B1B22` at 80% opacity | Environment | Void = potential. Awaits filling. |
| Prana slot (filled) | Prana type's assigned color (P1–P5), full saturation | Prana palette | Color IS the Prana identity. |
| Prana slot (active/selected) | Prana color + 2px white inner rim highlight | Prana palette | Distinguishes active from inactive without adding a new color. |
| Health bar fill | HSL(6, 90%, 50%) `#E61A0D` — dedicated health red | Dedicated | Darker and more red (less orange) than Ashfire. Controlled deviation — health semantic is too important to mute. |
| Health bar: low health (<25%) | Pulse between health red and E6, at 1.5 Hz | Health red + E6 | Draws attention without a new color. 1.5 Hz is well below seizure-risk threshold. |
| Main UI panels | E1 Dungeon Stone `#3A3530` at 90% opacity | Environment | Panels feel carved from the dungeon. |
| Panel border accent | E7 Warm Lantern Bleed `#8E7358` | Environment | Presence without brightness. |
| Active/hover state | E7 brightened to 70% lightness | Environment | "Touched by warmth" — not a magic color. |
| Inactive/disabled state | E2 Worn Slate `#474B52` at 60% opacity | Environment | Recedes visually. |
| Damage numbers | Casting Prana type's color (P1–P5) | Prana palette | Numbers echo what caused them — reinforces Prana identity. |
| Victory flash | White `#FFFFFF` → E7 fade (0.5s) | Highlight + Environment | White = universal victory; fades to warm lantern for "exhale" mood. |
| Hazard/trap indicator | White `#FFFFFF` outline, 2 Hz pulse | Highlight | Maximum contrast, no Prana confusion. White reserved for hazard and victory flash only. |
| UI text / labels | `#D4C9B8` warm off-white | Neutral | Reads in any context, doesn't compete with jewel tones. |

### 4.5 Colorblind Safety

**Target conditions:** Deuteranopia (~6% male players, red-green) and Protanopia (~2% male players, red-green).

#### Prana Pair Risk Assessment

| Pair | Risk | Failure Mode | Backup Cue |
|------|------|-------------|------------|
| P1 Ashfire (red) + P5 Verdant (green) | **HIGH** | Both may appear brown/yellow-brown under deuteranopia/protanopia | Mandatory shape icon (see below) + VFX burst shape + audio |
| P1 Ashfire + P3 Stormgold | **MEDIUM** | Both warm tones; P1 may shift toward P3 under protanopia | Shape icon + luminance split (P3 brighter at L=55%) |
| P2 Voidblue + P4 Deepfrost | **LOW** | Blue-family; minor tritanopia risk (rare, ~0.01%) | Shape icon still applied |
| All other pairs | LOW | No significant confusion predicted | Shape icons applied universally |

#### Mandatory Icon System (per-Prana slot, 8×8 px)

Every Prana slot displays a small icon that is silhouette-readable without color. Icons are black on Prana-color background.

| Prana Type | Icon Shape | Principle |
|------------|-----------|-----------|
| P1 Ashfire | 3-spike upward flame cluster | "Flame" — aggressive upward points |
| P2 Voidblue | Inward spiral / eye shape | "Void" — pulls inward |
| P3 Stormgold | Forked lightning bolt | "Electricity" — universal symbol |
| P4 Deepfrost | Hexagonal crystal / snowflake | "Ice" — crystalline structure |
| P5 Verdant | Tri-leaf / spiral growth | "Nature" — organic, expanding |

**Validation rule:** Each icon must be recognizable in silhouette at 8×8 px. If it cannot be read at that size, the icon must be simplified before shipping.

#### Additional Redundancy Cues

| Cue | Implementation |
|-----|---------------|
| **VFX burst shape** | R1=spike burst, R2=inward swirl, R3=forked ray, R4=crystalline fractal, R5=expanding ring |
| **Audio signature** | Distinct cast sound per Prana type: Ashfire=crackle-whoosh, Voidblue=low drone resonance, Stormgold=sharp crack, Deepfrost=crystalline chime, Verdant=organic bloom |
| **Cast animation** | P1=upward sweep, P2=pull-back/release, P3=snap point, P4=slow push, P5=spreading palm |

**Optional colorblind mode (settings toggle):** Increase Prana slot icon from 8×8 to 12×12 px + single-letter label below slot (A, V, S, D, G). Flag for `ui-programmer` implementation.

**Seizure safety:** Only pulsing element is the low-health bar (1.5 Hz). All other transitions are one-shot fades or single-frame bursts. No strobing exceeds 3 Hz.

---

## 5. Character Design Direction

### 5.1 Player Character Visual Archetype — Fayde (The Cipher)

**Archetype direction:** Discoverer, not fighter. Silhouette reads "child carrying something slightly too big for them." Power was inherited, not trained for.

**Proportions:**
- Chibi-adjacent, not comedic: head-to-body ratio ~1:2.5 at sprite scale. Slightly large head aids expression readability.
- Compact oval body with one clear vertical accent (tall collar, hood peak, or held rod). This accent is the silhouette anchor distinguishing Fayde from all enemy types.
- No exaggerated musculature. Slender, slightly uncertain limbs. Power lives in hands and mind.

**Costume / design vocabulary:**
- Layered travelling clothes: tunic/shirt beneath a longish coat or robe falling to mid-calf at sprite scale.
- Practical scholar details: small pouches, a satchel strap, slightly ill-fitting gear not made for combat.
- One unique accessory appearing nowhere on enemies: a Prana-sensing lens, Prana clasp, or circuit-trace-stitched gloves. This is the "I am the protagonist" visual signal.
- Color: warm neutrals from environment palette as base, with one small accent glow matching the currently-active Prana type (collar glow, pocket light — highlight only, never dominant color). Roots the player in the world while connecting them to the Prana system.

**All-ages approachability:** Default expression is curious or slightly worried, never aggressive. No sharp silhouette angles except the vertical accent. No realistic weapon silhouettes. No exposed skin beyond face and hands.

**Camera distance readability (isometric dimetric, 32–48px native — non-negotiable):**
1. Vertical accent (hood/collar peak or held item upright)
2. Coat/robe hem — single-pixel-wide dark line separating from legs
3. Face dot cluster — two-pixel eyes minimum
4. Hand position — forward/outward when casting, tucked at idle

All costume detail (pouches, clasps, stitching) exists only in portrait/promo art.

### 5.2 Enemy Design Rules Per Archetype

**Governing tone:** Enemies are machines that have been changed — warped by exposure, not built to kill. "Something went wrong here" not "this was designed as a weapon." Serves Pillar 5 (Memory Returns) and the all-ages constraint simultaneously: a transformed machine is sympathetic; a murder machine is not.

**Transformation visual language (at least one marker per enemy):**
- *Prana-scarring* — geometric cracks or circuit-trace lines on the surface, desaturated Prana color. Dormant at rest, glow when agitated.
- *Color bleed* — a Prana color washing into the natural palette (jewel tone at 50–60% saturation max on enemies — never full saturation, which is reserved for player magic).
- *Fragmentation* — one edge of the silhouette is broken, or a small shard orbits the entity.

**Per-archetype vocabulary:**

**Drifter** (wide/flat, ranged/projectile)
- Origin implied: peaceful floater, slow ambient machine
- Transformation marker: color bleed — natural warm neutral stained by a Prana color on one edge
- Motion: slow, wobbling body mass that sags and re-inflates. Lethargy, not aggression.
- Texture: soft rounded pixel clusters, no hard edges on the silhouette
- Native sprite: 16×16 px

**Charger** (tall/narrow, melee/rush)
- Origin implied: rigid utility machine, tower-like
- Transformation marker: Prana-scarring — geometric cracks along spike edges pulse before charge animation
- Motion: perfectly still at rest (reads as environment detail), then sudden violent forward lean. Stillness-to-movement contrast is the danger signal.
- Texture: hard, faceted pixel edges. The sharpest non-boss silhouette in the game. Angularity = all-ages-safe "danger" signal.
- Native sprite: ~12×20 px

**Cluster** (central oval + orbiting circles, swarm/summoner)
- Origin implied: modular machine — parts that found a center
- Transformation marker: fragmentation (the design IS fragmentation — orbiting pieces are literally the entity coming apart)
- Motion: core pulses slowly; orbiters drift at slightly different speeds, desynchronized. Unsettled, nervous.
- Texture: hard core (more opaque/saturated) + soft orbiters (fade at edges)
- Native sprite: 24×24 px (orbiters need surrounding space to read)

**Boss — The Warped Warden** (asymmetric large polygon)
- Origin implied: ancient guardian machine, construct with a purpose. Asymmetry suggests centuries of change.
- Transformation markers: all three layered. Prana-scarring is prominent — the broken-Prana mark at center IS the scar that opened it.
- Motion: broken-Prana mark pulses independently of the body. Body has its own slow breathing cycle. Two separate animation cycles = internal conflict visual.
- Scale: never less than 3× the area of the largest standard enemy sprite. Size gap must be readable with no other enemies on screen for comparison.
- Native sprite: 48×48 px

**Colour hierarchy on enemies:** Enemy base palettes use warm or cool neutrals (≤40% saturation). Transformation markers use jewel tones at 50–60% saturation max — never full saturation. Full jewel-tone saturation belongs exclusively to Fayde's Prana and projectile effects.

### 5.3 Expression and Pose Style

**Register: Exaggerated-readable.** SNES/GBA RPG clarity (every pose telegraphs meaning in silhouette alone) + Ghibli warmth (curious, approachable). Not stiff, not comedic.

At 32–48px native (isometric dimetric angle), anatomical realism is still limited. Every pose must read in silhouette alone — exaggeration is the tool.

**Fayde state poses:**

| State | Silhouette Change | Key Animation Beat |
|-------|------------------|--------------------|
| Idle | Slight sway, vertical accent stays upright | Weight shift + 1 frame of coat breath-expansion |
| Run | Forward lean; coat hem trails; accent tilts back | 4-frame cycle minimum; hem 1 frame behind body |
| Cast | Both hands extend forward/upward; body shifts back | Wind-up: hands pull back. Release: arms extended, coat blown back 1px |
| Hit | Body contracts inward for 2 frames | "Startled" read — not pain. All limbs pull toward center. |
| Defeat | Knees bend, arms drop, head dips — held 8–12 frames | Transition into bloom-dissolve sequence |

**Enemy state minimum:**
- Idle (looping ambient motion)
- Agitated/Aggro (faster pulse, color bleed brightens — visually distinct from idle in silhouette)
- Attack wind-up (telegraph must be readable in silhouette alone at native res)
- Defeat (archetype slump → bloom → dissolve)

**All-ages defeat protocol (3-stage sequence):**

| Stage | Duration | Description |
|-------|----------|-------------|
| 1. Crumple pose | 8–12 frames | Entity slumps into archetype-specific "exhausted" pose. Fayde: knees bent, arms loose, head down. Drifter: spreads flat. Charger: spikes droop. Cluster: orbiters slow and fall inward. Boss: mark goes dark. Reads as exhausted, not dead. |
| 2. Bloom | 4–6 frames | Rapid outward expansion of corruption/magic color from sprite center. Single-frame bright flash at peak, then color blooms outward in a circle. "Something is releasing." |
| 3. Dissolve | 8–16 frames | Sprite breaks into 2–4px particle clusters that float upward and fade. Particle color matches bloom color. Floor remains clean — entity is fully gone. |

The bloom beat is critical. Defeat reads as "transformation or dispersal," not death.

### 5.4 LOD Philosophy

**Design for game distance first.** Portrait detail is a bonus, never a driver.

**Two-distance rule:** Every sprite designed for (1) game distance — native res, isometric dimetric camera (~26.57° angle, 2:1 tile ratio per ADR-0001); and (2) portrait/detail distance — 4–8x upscale in menus or promo art. Details that only read at portrait distance must not drive the game-distance silhouette.

**Target sprite resolutions:**

All sprites are drawn from the isometric dimetric angle (~26.57°). Heights below are measured vertically in screen space, consistent with the 32–48px sprite target from ADR-0001. Validate silhouette readability against a 64×32px floor tile before art production begins (Reference 6).

| Entity | Native Sprite Size |
|--------|-------------------|
| Fayde (The Cipher) | 16×32 px |
| Drifter | 16×24 px |
| Charger | 12×32 px |
| Cluster | 24×32 px |
| Boss | 48×64 px |

All sprites snap to an 8px position grid.

**Must read at game distance (non-negotiable):**
- Fayde: vertical accent, coat/leg boundary, hand position
- Drifter: horizontal spread wider than player, soft edge
- Charger: taller than wide, ≥2 visible spike angles, hard edges
- Cluster: distinct core circle + ≥2 orbiting shapes with visible gap
- Boss: no axis of symmetry, broken-Prana mark as darker central shape

**Pixel art rendering rules:**
- No anti-aliasing. Hard pixel boundaries.
- Palette limit: player = 8 colors max (incl. transparency), standard enemy = 6 colors, boss = 12 colors.
- Outline: 1px, color = darkened version of dominant sprite color (~30% luminance of base). Not black — keeps sprites from looking pasted onto the background.
- Shadow: flat shadow ellipse beneath each entity (2px opacity blob). No dynamic lighting on sprite layers — lighting lives in the environment layer.

---

## 6. Environment Design Language

### 6.1 Architectural Style

The dungeon is a ruined facility — stone fortress colonised by machine infrastructure. Cut stone forms the bones; embedded conduit channels, mounting brackets, and defunct mechanisms are the scar tissue. The world reads as "ancient stone palace that tried to become a machine, and failed at both."

**Three-layer environment read:**
1. **Structural** — walls, floor, ceiling. Irregular stone, Section 3.3 geometry. E1 dominant.
2. **Machine trace** — embedded pipes, conduit channels, bracket stubs. E2 and E3 accent.
3. **Organic intrusion** — moss at floor edges, drifting spores, roots finding cracks. E7 warm glow (bioluminescence). This layer is where Principle 3 (*Whimsy Lives in Details*) lives architecturally.

Every room must include at least one element from layer 3. Rooms that lack it read as dead sets, not living dungeons.

Shape rule: organic/stone elements follow irregular polygon grammar from Section 3.3; machine elements introduce geometric accents that have been partially absorbed — never crisp and modern, always weathered, dented, or split.

### 6.2 Surface Variation System

Rooms progress through surface tiers based on dungeon depth. Tier establishes the visual vocabulary of a zone; it is a visual descriptor, not a mechanic.

| Tier | Name | Visual Character | When Used |
|------|------|-----------------|-----------|
| 1 | Quarried Stone | Bare cut stone, cracks only, no organic layer | Entrance floors, tutorial area |
| 2 | Weathered | Moss at wall bases, rust bleed from metal fittings, cracked floor tiles | Most MVP rooms |
| 3 | Active | Tier 2 + one pulsing conduit (E7 glow, 2-frame loop), functional bracket remnants | Rooms adjacent to boss antechamber |
| 4 | Corrupted | Boss color bleeds into walls; geometry more erratic; organic layer suppressed | Boss antechamber — **Vertical Slice scope** |

**Tier 4 is deferred to Vertical Slice.** MVP ships Tiers 1–3. A Tier 4 art spec stub may be written now, but production assets are blocked until VS begins.

### 6.3 Texture Philosophy

Pixel art, hand-authored. No procedural texture generation, no filter-based effects on static tiles.

- **Base resolution:** 64×32 px per isometric floor tile (2:1 dimetric diamond — matches TileSet `tile_size = Vector2i(64, 32)`, per ADR-0001)
- **Palette:** E1–E7 only. No new colors on environment tiles.
- **Shading:** Dithering for surface transitions (stone cracks, moss spread) at 2–3 px density. Selective color-cluster shading (dark/light E1 variants) for depth on wall faces.
- **Variation:** All tilesets have at least 2 variant frames minimum — no purely repeating patterns.

**Forbidden texture techniques:**
- Linear interpolation (Godot import: Nearest filter, always)
- Smooth gradients (use 2–3-step dithered palette blends only)
- Uniformly repeating tiles with no variation

### 6.4 Prop Density Rules

Prop count is deliberately restrained — "the quiet world makes magic scream."

| Room Type | Background Prop Count | Required Ambient Element |
|-----------|-----------------------|--------------------------|
| Corridor (≤6 tiles wide) | 1–2 | Optional (moss patch, pipe exhale) |
| Arena (≥8×8 tiles) | 3–5 | Required — at least 1 ambient animation (see below) |
| Boss room | 0 background props | 1 architectural accent only (cracked column, void alcove) |
| Transition/doorway | 0 | Archway shape alone carries weight |

**Required ambient animation (arena rooms):** One of the following must appear in every arena room — drifting spore particles, slow-exhale steam from a conduit crack, moss breathing (4–8 frame expand/contract), or a small creature silhouette vanishing into shadow.

All ambient animations use E7 tint or desaturated Prana-tint only. Never full jewel-tone — that register belongs to magic.

### 6.5 Environmental Storytelling Guidelines

Every room may carry one optional narrative detail. These are never labeled, never interactive — they reward the player who stops.

**Recurring environmental vocabulary:**
- **Mounting brackets without a mount** — something was here, removed or fled
- **Partially etched glyphs** — matching Prana-script on Fayde's gear; someone was learning the same things
- **Scale calibration markings** — suggesting a much larger machine was once measured here
- **Asymmetric scorch patterns** — not from combat; from something that used to live here

**Never narrate directly:** No in-world text or signage in MVP (reserved for the Lore Fragments system at Alpha scope). The environment implies; lore fragments explain.

**Doorway visual language:**
- Every room exit is an ogival arch (Section 3.3)
- Arch interior = E6 Atmosphere Haze `#1B1B22` — pure void
- "What's ahead" tint signal: Tier 1 = neutral void; Tier 2 = subtle E7 warm presence; Tier 3 = faint E7 pulse
- **Never a jewel tone in a doorway interior** — jewel tones in passageways would read as active Prana

### 6.6 Wall Geometry Reference (from Section 3.3)

- No wall section perfectly straight for more than 6 tiles (Tier 1 baseline)
- Wall profile varies every 4–6 tiles; uneven thickness throughout
- No true right angles in decorative features; all corners chamfered or radius-softened
- Doorways and arches: oval or ogival — never rectangular

---

## 7. UI/HUD Visual Direction

### 7.1 HUD Philosophy

**Screen-space, styled diegetically.** The HUD occupies a separate canvas layer from the game world but uses the same visual vocabulary — stone textures, arc shapes, no sharp corners. The intent: "instrument panel built into the dungeon itself," not a floating game overlay.

**All-ages, high-priority constraint:** All HUD elements must be legible without relying on color alone. Icon + shape redundancy from Section 4.5 applies to all HUD icons.

### 7.2 HUD Layout

Two permanent zones, one conditional zone:

```
┌──────────────────────────────────────────────────────┐
│  [HEALTH BAR ──────────]      [WAVE COUNTER · · · ]  │  ← Top strip (permanent)
│                                                       │
│                  GAME WORLD                           │
│                                       ┌────────────┐  │
│                           [WAVE PEEK  │            │  │  ← Right panel (prep phase only)
│                             PANEL]   └────────────┘  │
│  [STATUS EFFECTS ○○○○]          [PRANA GRID PANEL]   │  ← Bottom strip (permanent)
└──────────────────────────────────────────────────────┘
```

**Bottom-right — Prana Grid Panel:** The game's primary input instrument. Always visible. Octagonal frame (Section 3.4). Preparation Phase: full brightness, E7 inner glow active. Combat Phase: dimmed to 60% opacity — "locked in; arranging is over." Slots display at 16×16 px (icons 8×8 at 2× scale).

**Bottom-left — Status Effects:** Row of up to 4 active icons, each 12×12 px. Icon = Prana-type shape on Prana-color background. Duration shown as radial fill draining around icon. Row reads left to right in application order.

**Top-left — Health Bar:** Horizontal capsule (Section 3.4), approximately ¼ screen width. E1 background track, health-red fill (Section 4.4). Low-health pulse at 1.5 Hz. No numeric health value displayed — the visual fill is the signal.

**Top-right — Wave Counter:** "Wave 2 / 5" label in warm off-white `#D4C9B8` on E1 panel. Small. Enemy type composition of the current wave shown as 8×8 px archetype silhouette icons — no text.

**Conditional — Wave Peek Panel (Preparation Phase only):** Slides in from screen-right at Preparation Phase start; slides out when Combat Phase begins (0.3s transition). Shows upcoming enemies by archetype silhouette + Prana affiliation color per slot. This is the largest single HUD element during Preparation — information is the product of this phase.

### 7.3 Typography

No decorative fonts. The UI is Fayde's practical interface with an ancient dungeon.

- **Font type:** Pixel-art bitmap font, 8px base unit. No anti-aliasing, no sub-pixel rendering.
- **Scale:** 8px or 16px (2× scale) only. No odd intermediate scaling — pixel alignment must be maintained.
- **Color:** `#D4C9B8` warm off-white for all static labels. Prana colors for value highlights only (damage numbers, elemental labels in Wave Peek).
- **Damage numbers:** Float up 8–12 px from sprite center, fade over 0.5s. Color = casting Prana type. 1.5× scale on critical. Same bitmap font — no decorative numerals.

**Three-level hierarchy only:**
1. **Screen titles / critical alerts** — 16px: wave clear banner, defeat screen label
2. **HUD labels / tooltip headers** — 8px at 2× display: Prana type names in Wave Peek
3. **Small counters / durations** — 8px: wave number, status duration ticks

### 7.4 Iconography Style

All icons are flat silhouettes: dark icon on color-filled background. No outlines, no gradients, no drop shadows.

| Icon Context | Base Size | Display Size | Shape Source |
|-------------|-----------|--------------|-------------|
| Prana icons in grid | 8×8 px | 16×16 px (2×) | Section 4.5 icon set |
| Status effect icons | 12×12 px | 12×12 px (1×) | Effect silhouette (snowflake, flame, etc.) |
| Enemy type in Wave Counter / Wave Peek | 8×8 px | 8×8 px (1×) | Archetype silhouette (flat/tall/orbit) |

**No photorealistic or illustrated icons.** All icons are silhouettes consistent with pixel art register.

### 7.5 UI Animation Timing

Transitions are measured, not flashy. Dungeon instruments move with purpose.

| UI Event | Animation | Duration |
|----------|-----------|----------|
| Wave Peek panel enter | Slide from right | 0.3s ease-out |
| Wave Peek panel exit | Slide to right | 0.3s ease-in |
| Prana grid dim (combat start) | Fade to 60% opacity | 0.3s (synchronised with ambient dim) |
| Prana grid brighten (prep start) | Fade to 100% opacity | 0.3s |
| Status effect applied | Icon drops in from above its slot | 0.2s |
| Status effect expires | Icon shrinks to center point | 0.15s |
| Damage number | Float up, fade out | 0.5s |
| Wave clear banner | Fade in → hold → fade out | ~2.5s total |

**No bounce, spring, or rubber-band easing on any UI element.** No personality physics. Exception: the Victory warm wash (Section 2.4) has one brightness pulse at peak — the single sanctioned UI exclamation.

### 7.6 Prana Grid Visual State Contract

| State | Visual |
|-------|--------|
| Preparation (active) | 100% opacity, E7 frame inner glow, slot icons vivid |
| Combat (locked) | 60% opacity, frame glow suppressed, slots readable but receded |
| Slot filled | Full Prana color + icon |
| Slot empty | E6 `#1B1B22` background, no icon |
| Active combo slots | 2px white inner rim on participating slots (Section 4.4) |
| Hovered slot (mouse) | E7 brightened background on that slot |

---

## 8. Asset Standards

### 8.1 File Format Standards

| Asset Type | Source Format | Export Format | Notes |
|-----------|--------------|--------------|-------|
| Sprite sheets | ASEPRITE / layered PSB | PNG (lossless, RGBA) | Never JPEG |
| Tileset textures | ASEPRITE / layered | PNG (lossless) | 16×16 px per tile |
| UI elements | ASEPRITE / layered | PNG (lossless, RGBA) | Premultiplied alpha off |
| Background / parallax art | Layered | PNG (lossless) | Separate from interactive layers |
| Music | DAW project | OGG Vorbis (quality 6–7) | Godot's native streaming format |
| SFX (short ≤2s) | DAW project | WAV (16-bit mono) | Mono for positional audio candidates |
| SFX (long >2s) | DAW project | OGG Vorbis (quality 6) | Per above |
| Pixel art fonts | ASEPRITE / BMFont | `.tres` BitmapFont resource | No TTF — pixel art only |

### 8.2 Naming Conventions

Follows snake_case to match GDScript conventions (Section 4 of coding standards).

- **Sprites:** `[entity]_[animation]_[frame_count]f.png` — e.g., `fayde_run_4f.png`, `enemy_drifter_idle_2f.png`
- **Tilesets:** `tileset_t[tier]_[variant].png` — e.g., `tileset_t2_stone.png`
- **UI elements:** `ui_[element]_[state].png` — e.g., `ui_prana_grid_frame.png`, `ui_btn_idle.png`
- **SFX:** `sfx_[category]_[name].[ext]` — e.g., `sfx_prana_ashfire_cast.wav`, `sfx_enemy_charger_aggro.ogg`
- **Music:** `music_[area]_[state].ogg` — e.g., `music_dungeon_combat.ogg`, `music_menu_idle.ogg`
- **Scenes:** `PascalCase.tscn` matching root node name — e.g., `PlayerController.tscn`, `EnemyDrifter.tscn`

**Asset directory layout:**
```
assets/
├── art/
│   ├── sprites/
│   │   ├── player/        # fayde_*
│   │   ├── enemies/       # enemy_[archetype]_*
│   │   ├── environment/   # tileset_*, prop_*
│   │   ├── ui/            # ui_*
│   │   └── vfx/           # vfx_*
│   └── tilesets/          # .tres TileSet resources
├── audio/
│   ├── music/             # music_*
│   └── sfx/               # sfx_*
└── fonts/                 # bitmap font resources
```

### 8.3 Godot 4.6 Texture Import Settings

**Non-negotiable — verify on every imported texture:**

| Setting | Required Value | Reason |
|---------|---------------|--------|
| Filter | **Nearest** | Linear = blurred pixels; destroys pixel art |
| Mipmaps | **Off** | Mipmaps + Nearest creates visible artifacts at non-native scale |
| Compress | **Lossless** (or VRAM Lossless) | Lossy compression degrades Prana jewel-tone precision |
| Repeat | **Off** (unless tile explicitly repeats) | Prevents edge bleeding |
| sRGB | **Enabled** for color textures | Correct color space for jewel tones |

**Atlas policy:** Character animation sprites packed into SpriteFrames atlas. Sprites sharing a draw-call context share a texture atlas (e.g., all 5 Prana particle types in one VFX atlas). Required to stay within the 200 draw-call budget.

### 8.4 Node and Scene Usage (Godot 4.6)

| Use This | Not This | Reason |
|----------|----------|--------|
| `TileMapLayer` | `TileMap` | TileMap deprecated since Godot 4.3; TileMapLayer is the replacement |
| `AnimatedSprite2D` | `Sprite2D` + manual frame index | AnimatedSprite2D handles SpriteFrames natively |
| `CPUParticles2D` | `GPUParticles2D` | Compatibility renderer has limited GPU particle support |
| GDShader (`ShaderMaterial`) | VisualShader | Godot shading language only; no Vulkan-specific extensions on Compatibility |
| `CanvasGroup` | Per-sprite blend overrides | Use sparingly — each CanvasGroup adds a draw pass |
| `AudioStreamPlayer` | — | Non-positional: music, UI sounds |
| `AudioStreamPlayer2D` | — | Positional: Prana cast SFX, enemy audio |

**Audio bus structure:** Master → Music bus / Master → SFX bus. Dungeon reverb applied on SFX bus only. Never on Music bus.

### 8.5 Performance Budget

| Budget | Limit | How to Check |
|--------|-------|-------------|
| Draw calls per frame | **< 200** | Godot Debugger → Render → Draw Calls |
| Single atlas texture | **Max 2048×2048 px** | Checked at import time |
| CPUParticles2D count per emitter | **≤ 150 particles** | Per emitter; stacks across simultaneous emitters |
| Simultaneous music streams | **Max 2** (crossfade) | AudioStreamPlayer management |
| Total memory | **< 512 MB** | Godot Profiler → Memory |

**Draw call reduction rules:**
- All enemies of the same archetype share a texture atlas
- UI elements group onto one CanvasLayer with shared atlas where possible
- Every new CPUParticles2D system must be profiled on first implementation — particles are the largest variable in the draw-call budget

### 8.6 Sprite Technical Specs

(Complements Section 5.4 LOD Philosophy)

| Entity | Native Size | Atlas Policy | Palette Cap |
|--------|-------------|--------------|-------------|
| Fayde | 16×32 px | Player atlas | 8 colors |
| Enemy Drifter | 16×24 px | Enemy atlas (all standard enemies) | 6 colors |
| Enemy Charger | 12×32 px | Enemy atlas | 6 colors |
| Enemy Cluster | 24×32 px | Enemy atlas | 6 colors |
| Boss (Warped Warden) | 48×64 px | Boss-solo atlas | 12 colors |
| Prana particles | ≤ 16×16 px per frame | VFX atlas (per Prana type) | 4 colors |
| UI elements | Powers of 2, ≤ 256 px | UI atlas | Full palette (no cap) |
| Environment tiles | 64×32 px | Per-tier tileset atlas | 7 colors (E1–E7) |

**Pixel art rendering rules (from Section 5.4):**
- No anti-aliasing anywhere — hard pixel boundaries
- 1px outline per sprite: darkened version of dominant sprite color (~30% luminance), not black
- Flat shadow ellipse beneath entities (2px opacity blob) — no dynamic lighting on sprite layers

---

## 9. Reference Direction

Five references. Each specifies exactly what to take, what to avoid, and the distilled rule so future visual decisions can invoke the reference by name.

---

### Reference 1 — Octopath Traveler (Square Enix / Acquire, 2018 & 2023)

**What to take:**
- The visual hierarchy principle: vivid, saturated character effects against a toned-down, muted world. Octopath's pixel characters glow against their atmospheric environments — the contrast is the aesthetic, not an accident.
- Saturated skill/magic effects that read as belonging to a different visual register than the world they appear in. This maps directly to our jewel-tone Prana vs. E1–E7 environment split.
- Atmospheric depth through layer separation — foreground action stays vivid; background breathes with haze and diffusion.

**What to avoid:**
- The HD-2D 3D depth and parallax technique — we are flat 2D on the Compatibility renderer.
- Baroque, ornate UI frames and heavy chrome — The Last Cipher's UI is practical dungeon-artifact styling.
- Character-driven cutscene narrative structure — our world breathes through environmental fragments.

**Rule:** The environment is negative space. Prana effects and Fayde are the signal.

---

### Reference 2 — Hyper Light Drifter (Heart Machine, 2016)

**What to take:**
- "Something ancient was here" environmental language — sparse props, readable silhouettes, a world with history that never explains itself outright. The player constructs meaning from visual evidence.
- Protagonist-as-glowing-anomaly: the Drifter's bright outline stands out from everything around them. Fayde should achieve this via her Prana-cast glow — the only saturated presence in the arena when no spell is being cast.
- Zone color temperature shifts that establish location without a map marker or text label.

**What to avoid:**
- HLD's specific pixel art resolution and smooth-edged style — our sprites are harder-edged.
- The magenta/pink palette — our colors derive from the Prana palette (Section 4.2), not HLD's.
- Silent voiceless narrative — lore fragments in The Last Cipher are findable text/symbol objects.

**Rule:** A protagonist who emits color owns the screen.

---

### Reference 3 — Dead Cells (Motion Twin, 2018)

**What to take:**
- Enemy silhouette clarity at small sprite sizes — every Dead Cells enemy reads in silhouette alone. This is non-negotiable for top-down combat where enemies must be identifiable mid-action.
- Attack telegraph readability: wind-up animations legible at game scale without UI prompts (directly informs our enemy state animation requirements in Section 5.3).
- Enemy defeat as particle dissolve — fast, clean, and satisfying without gore. Directly models our all-ages defeat protocol (Section 5.3).

**What to avoid:**
- The gritty grey-green-brown palette. We want warm earth tones against jewel tones.
- Body-horror implied enemy design. All-ages constraint rules these out categorically.
- Combat pacing built for 2D platformer rhythm — top-down spatial logic is different.

**Rule:** Enemy defeat is resolution, not impact. Particle dissolve over collision response.

---

### Reference 4 — Slay the Spire (MegaCrit Games, 2019)

*Cited in prototype REPORT.md as the closest mechanical analog to the Preparation Phase.*

**What to take:**
- Pre-combat information architecture: hand/deck display, enemy intent display. The clarity of "here is what is coming; here is what you have" in one screen before the fight. This is the direct model for our Wave Peek panel (System #13).
- Color-coded action semantics: color represents category of effect. Maps to Prana-as-color-identity (Sections 2.1 and 4.2).
- Run summary design: the post-run screen shows the shape of your decisions. Our Run Summary Screen (System #23) should meet this bar.

**What to avoid:**
- Card-game UI chrome — thick card frames, rarity systems, extensive stat overlays.
- Static turn-based spatial presentation. We are real-time with movement.
- Heavy tooltip dependency. Our system should be learnably visual first.

**Rule:** The Preparation phase UI answers one question instantly — "What am I facing, and what do I have?"

---

### Reference 5 — Celeste (Maddy Thorson / Matt Makes Games, 2018)

**What to take:**
- Expressiveness at micro resolution: Madeline's sprite is small but emotional state reads in every pose. Fayde must meet this bar — every animation frame carries meaning.
- Accessible visual feedback for success/failure — no ambiguity about what just happened. Celeste's defeat sequence (bloom → dissolve) is clear, fast, and age-appropriate. Directly models our 3-stage defeat protocol (Section 5.3).
- "Small sprite, full personality" pixel art philosophy: exaggeration in service of readability.

**What to avoid:**
- Platformer spatial logic — not relevant to top-down.
- Pink/pastel palette — lighter and more cheerful than our aesthetic target.
- Fast-restart death loop — roguelike run loss has different emotional weight; our defeat sequence is longer and more deliberate.

**Rule:** At 16px, every animation frame is a word. Write precisely.

---

### Reference 6 — Final Fantasy Tactics (Square, 1997) & Disgaea (Nippon Ichi, 2003)

*Primary isometric sprite angle and tile-to-character ratio reference — cited in ADR-0001.*

**What to take:**
- **Tile-to-character size ratio:** characters 32–40px tall against 64×32px isometric tiles. This ratio is the proven readable proportion for dimetric pixel art — validate all sprite silhouettes against it before art production begins.
- **Ground contact shadow:** flat dark ellipse beneath each entity, drawn below the sprite. This single detail converts a floating sprite into a grounded isometric character. Non-negotiable for depth readability.
- **Per-tile ground detail:** each floor tile has subtle interior variation (slight colour gradient from front edge to back, a single crack line, or a 2px edge shadow at the front face) that separates it from adjacent tiles without adding visual noise.
- **Y-sort overlap legibility:** sprites at the same Y-depth position are designed so their silhouettes separate cleanly — characters share tile space without merging into one visual blob.

**What to avoid:**
- FFT's specific art aesthetic (Western-fantasy armour, painted portrait cutscenes) — The Last Cipher uses its own environment and character vocabulary from this art bible.
- Disgaea's extreme chibi proportions (head-to-body ratio closer to 1:1) — our target is the 1:2.5 ratio specified in Section 5.1.
- Chess-grid tactical room layouts — our dungeon is irregular organic stone (Section 6.3), not symmetric tactical maps.
- FFT's high-contrast blue sky / outdoor lighting — our palette is dungeon earth tones (E1–E7) with jewel-tone magic.

**Rule:** 64×32px floor tile + 32–48px character height is the proven readable isometric ratio. Ground-contact shadow is mandatory — it is what makes characters read as *on* the floor rather than *above* it.
