# Art Bible — Runebind

*Created: 2026-05-21*
*Status: In Progress*

> **Art Director Sign-Off (AD-ART-BIBLE)**: Skipped — Lean review mode.

---

## 1. Visual Identity Statement

**One-Line Visual Rule:** The world breathes softly; magic screams.

The dungeon is serene and mysterious — soft earth tones, warm atmospheric haze, a world that has been quietly asleep for centuries. Rune magic shatters that stillness with vivid jewel-tone explosions. The contrast is the drama.

**Kids-friendly constraint (hard):** All visual elements must be appropriate for players aged 7+. No blood, gore, or body horror. Enemy defeat is always a dissolve/particle effect, never physical impact.

### Principle 1: Serene World, Violent Magic
Environments use warm-neutral, low-saturation earth tones with gentle atmospheric depth. Rune effects use full-saturation jewel tones: particle bursts, screen-filling color, vivid light that belongs to a different world than the stone around it.

*Pillar anchor:* Chaos Has Consequences — a quiet world makes every spell effect immediately legible as signal, not noise.

*Design test:* Place a rune-cast screenshot next to an environment screenshot. If a stranger cannot instantly identify which is the magic, the environment is too busy or the effect is too subtle.

### Principle 2: Every Rune Has a Color Name
Each rune type owns one exclusive jewel tone, applied consistently to its icon, cast particle burst, damage numbers, synergy glow, and UI highlights. Color IS the rune's identity — the grid must be readable at a glance without labels.

*Pillar anchor:* Power is Earned Through Understanding — color-as-identity is the shortcut from first glance to mastery.

*Design test:* Cover all rune text labels. Can a new playtester identify all 5 rune types by color alone within 30 seconds?

### Principle 3: Whimsy Lives in the Details
Every room contains at least one non-interactive background detail — drifting spores, moss in the stonework, a small creature disappearing into shadow — that makes the world feel inhabited and quietly wondrous.

*Pillar anchor:* The Rune-Keeper's Secret — environmental curiosity signals that discovery is rewarded, before the player ever finds a lore fragment.

*Design test:* Does every room contain at least one background detail that has no gameplay function but rewards a player who pauses to notice it?

---

## 2. Mood & Atmosphere

### Mood Target per Game State

**2.1 Main Menu / Title Screen**
- **Primary Emotion:** Curiosity on the edge of a threshold — standing before a locked door that is already slightly ajar
- **Lighting:** Warm-cool split: deep indigo ambient with a single warm lantern glow at center. Low contrast, low brightness. Soft vignette.
- **Energy Level:** Contemplative
- **Atmospheric Descriptors:** Ancient, hushed, inviting, layered, secretive
- **Mood-Carrying Element:** The title rune glows in the idle rune palette (last-used rune, or slow cycle on first launch). Pulse rate: one breath per two seconds. Doorway mist behind it has a subtle 2-frame ambient shimmer.

**2.2 Preparation Phase**
- **Primary Emotion:** The held breath before a chess move — I know what is coming, but not all of it
- **Lighting:** Neutral-warm, medium contrast. Room fully lit. Rune grid panel receives a slightly cooler inner glow, marking it as the space of thought.
- **Energy Level:** Measured
- **Atmospheric Descriptors:** Still, deliberate, expectant, focused, charged
- **Mood-Carrying Element:** Enemy silhouettes visible in the doorway — not advancing, just waiting. Rune grid is the brightest point in the frame. Hierarchy: room (medium brightness) → grid (bright) = decision space is visually declared.

**2.3 Combat Phase**
- **Primary Emotion:** The adrenaline surge when a plan executes exactly right — and the spike of fear when it doesn't
- **Lighting:** Dynamic, spell-reactive. Ambient drops 15–20% at wave start (room dims slightly). High contrast. Spell bursts own the brightness budget.
- **Energy Level:** Frenetic
- **Atmospheric Descriptors:** Explosive, kinetic, vivid, chaotic, legible
- **Mood-Carrying Element:** Multiple jewel-tone rune colors firing simultaneously create a stained-glass burst effect against the low-saturation environment. Enemy defeat = color bloom outward from center, never violent impact.

> **Prep→Combat transition:** A 0.3s ambient-dim at wave start marks the threshold from "thinking" to "fighting."

**2.4 Victory / Room Clear**
- **Primary Emotion:** The exhale — relief with a warm tail of satisfaction, not triumph
- **Lighting:** Brief warm shift: ambient temperature rises one notch post-combat. Soft gold wash, 1–2 seconds, then returns to neutral.
- **Energy Level:** Measured, decelerating
- **Atmospheric Descriptors:** Warm, settling, brief, earned, quiet
- **Mood-Carrying Element:** Rune drops land one by one, each pulsing its rune color once then settling. Background whimsy details (spores, moss) reassert themselves — the world exhaled too.

**2.5 Defeat / Death Screen**
- **Primary Emotion:** Bittersweet sting of a story cut short — not shame, not punishment, but "I want to know how it ends"
- **Lighting:** Desaturated, cool-blue shift. World drains of warmth. The last-active rune in the player's hand holds the only remaining warm color.
- **Energy Level:** Contemplative, quiet
- **Atmospheric Descriptors:** Faded, cool, wistful, unfinished, still
- **Mood-Carrying Element:** Last active rune on the grid slowly desaturates as the overlay settles. "Try Again" appears only after desaturation completes (~1.5s) — weight without being maudlin.

**2.6 Run Summary / Post-Run Screen**
- **Primary Emotion:** Quiet pride of reading your own diary — curiosity about the shape of what just happened
- **Lighting:** Warm, steady, low-energy. Like a campfire room at the dungeon entrance. No combat urgency.
- **Energy Level:** Contemplative
- **Atmospheric Descriptors:** Reflective, warm, narrative, earned, anticipatory
- **Mood-Carrying Element:** The run's most-used combo displayed at visual center in full jewel-tone color — the run's signature. Ties Principle 2 (Every Rune Has a Color Name) to the emotional beat of "I built that."

**2.7 Boss Encounter**
- **Primary Emotion:** Awe-dread of something genuinely larger — not terror, but the feeling of standing at the base of a mountain you chose to climb
- **Lighting:** Boss's reserved color (one unique color per boss, outside the rune palette) bleeds into room ambient. High contrast, deeper shadows. Boss presence fills the brightness budget.
- **Energy Level:** Frenetic with ceremonial gravity
- **Atmospheric Descriptors:** Vast, tense, electric, ceremonial, vivid
- **Mood-Carrying Element:** Boss owns one reserved color that appears nowhere else in the game — not a rune color, not a UI color. Player's familiar jewel-tones appear as acts of defiance against the boss's chromatic authority. Color contrast = power narrative. *(Dependency: Section 4 Color System must reserve boss color slots.)*

### Cross-State Consistency Rules

1. **Environment saturation cap:** Backgrounds stay below 40% saturation in all game states — menus included.
2. **Transitions must be felt:** Prep→Combat (0.3s ambient dim) and Combat→Victory (1–2s warm wash) each have a visual transition beat. Changes in energy level are not instant cuts.
3. **Jewel tones belong to magic exclusively:** If any UI element, environment detail, or background prop reaches full jewel-tone saturation, it must be associated with a rune or spell. No decorative full-saturation environment elements.

---

## 3. Shape Language

### 3.1 Foundational Shape Grammar

Three shape families with strict roles:

| Family | Base Shapes | Used For | Emotional Signal |
|--------|-------------|----------|------------------|
| **Arcs** | Circles, ellipses, organic curves | Runes, UI grid, spell particles, player character | Familiar, approachable, alive |
| **Irregular Polygons** | Uneven pentagons/hexagons, broken stone | Dungeon walls, floors, environment | Ancient, imperfect, formed not built |
| **Sharp Spikes** | Triangles, explosion shapes, crystals | Spell VFX, aggressive enemy effects, hazard indicators | Uncontrollable energy — "magic screams" |

**Golden rule:** Arcs dominate things you touch and control. Irregular polygons dominate spaces you traverse. Sharp spikes appear only when something violent is happening.

### 3.2 Character Silhouette Philosophy

All characters must be identifiable at 32×32 px in 0.3 seconds mid-combat.

**Player — The Rune-Keeper**
- Shape: Compact oval body + single vertical accent (small rune-totem or short staff)
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
- Shape: Deliberately asymmetric large irregular polygon. One side heavier than the other. Arc remnants at the edges suggest what the creature was before the dungeon changed it.
- A single spiral/broken-rune ornament at visual center is the first focal point.
- Asymmetry reads as "transformation in progress," not broken sprite. One vertical axis may be symmetric; horizontal axis is intentionally imbalanced.
- Communicates: Vast, tragic, something that was once normal.

### 3.3 Environment Geometry

**Dominant geometry:** Irregular polygon with preference for obtuse angles (100–150°). Nothing sharper than 80° in decorative features.

- **Floors:** Tile grid with organic edge variation. Cracks, slightly raised tiles, surfaces that have settled. Not all tile edges align perfectly.
- **Walls:** Uneven thickness, profile varies every 4–6 tiles. No wall section is perfectly straight for more than 6 tiles.
- **Corners:** No true right angles anywhere. All corners have a chamfer or 1–2px radius (pixel art scale).
- **Doorways/Arches:** Oval or ogival arch shape — never rectangular. Arches do not need to be perfectly symmetric.

Irregular environment geometry creates automatic contrast with regular rune/UI geometry. When a spell burst (arc + spike) appears against irregular stone, shape contrast reinforces colour contrast.

### 3.4 UI Shape Grammar

UI uses **regularized polygons** — derived from dungeon shapes but smoothed. Like dungeon stone that has been sanded down.

| UI Element | Shape | Derived From | Reason |
|------------|-------|--------------|--------|
| Main panels | Rounded rectangle (medium radius) | Smoothed stone | Structured but organic enough to feel in-world |
| Buttons | Rounded rectangle (large radius) | Polished pebble | Clearly pressable, all-ages approachability |
| Tooltips | Soft irregular rect (one corner more rounded) | Small stone chip | Light, easy to dismiss |
| Health/status bar | Capsule | Arc of the rune system | Connects player status to the rune world |

**Rune Grid — "The Space of Decision"**

- **Container:** Octagonal frame (8 sides). Visually distinct from every other UI and environment element. Communicates: this is an instrument, not an inventory.
- **Slots:** Perfect circles. Empty slot = potential. Filled slot = arc rune within arc slot. Shapes nest naturally.
- **Slot spacing:** Minimum 3–4 px gap between slots — each slot reads as a discrete unit.
- **Frame accents:** Four small rune-fragment ornaments at octagonal corners (non-functional, reinforce "sacred instrument" read).

Hexagonal/honeycomb association signals precision and expertise — appropriate for *Power is Earned Through Understanding*.

**All-ages compliance:** No UI shape has angles below 60°. No shape that reads as a threatening or aggressive symbol cross-culturally.

### 3.5 Visual Hierarchy by Game State

**Hierarchy rule: The more important an element, the more geometrically regular its shape.** This works before colour registers.

**During Preparation Phase:**
1. Rune grid (most regular shape on screen — octagonal container, perfect circle slots)
2. Player character (compact oval, unique among angular environment)
3. Enemy silhouettes in doorway (present as threat signal, not fully resolved)
4. Environment (most irregular — background by definition)

**During Combat Phase:**
1. Spell VFX (arc burst + spike — most dynamic and shape-contrasting element on screen)
2. Enemy being hit (jewel-tone outline highlights the target)
3. Player character (stable rounded anchor amid chaos)
4. Rune grid (purposefully dim during combat — "not your turn to arrange runes")

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
| Rune grid frame | Regular octagon | Rectangle, square | Deliberate, sacred |
| Rune slot | Perfect circle | Any polygon | Potential |
| UI button/panel | Rounded rectangle | Sharp corners | Approachable |
| Spell VFX | Arc burst + spike | Regular polygon | Screaming, violent |
| Rune particle | Small arc cluster | Spike | Jewel, identity |

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

### 4.2 Magic / Rune Palette — 5 Rune Colors

Each rune type owns one exclusive jewel tone. The color appears on: rune icon, cast particle burst, damage numbers, synergy glow, and any UI highlight tied to that rune. No other element in the game uses these colors at full saturation.

All rune colors: HSL saturation 85–100%, lightness 50–65% — reads as jewel tone against E6 background.

| Rune | Name | Element | HSL | Hex | Semantic Identity |
|------|------|---------|-----|-----|------------------|
| R1 | **Ashfire** | Fire / Destruction | HSL(14, 95%, 55%) | `#F24C1D` | Ambition that burns everything — including plans. Force without precision. |
| R2 | **Voidblue** | Shadow / Void | HSL(235, 90%, 62%) | `#4A5EF5` | Silence that reveals what was always there. Control, concealment, deception. |
| R3 | **Stormgold** | Lightning / Speed | HSL(48, 100%, 55%) | `#FFCC00` | Reflex made visible. Reaction, disruption, momentum. |
| R4 | **Deepfrost** | Ice / Time | HSL(195, 85%, 60%) | `#3DD9F0` | Patience imposed on a world that resists it. Slowing, crystallizing, trapping. |
| R5 | **Verdant** | Nature / Growth | HSL(138, 80%, 48%) | `#1AC953` | Life that adapts faster than destruction. Healing, terrain manipulation, persistence. |

**Hue separation:** R1(14°) / R2(235°) / R3(48°) / R4(195°) / R5(138°). R1–R3 are closest at 34° — backup cues required (see Section 4.5).

### 4.3 Boss Reserved Colors

Each boss gets one exclusive color outside the rune palette. This color tints the arena ambient during the encounter, then desaturates to 0% on boss death.

**Rule:** Boss color must be outside all 5 rune hue zones by at least 40°, or distinguished by saturation+lightness if hue gap is narrower.

| Slot | Boss | Name | HSL | Hex | Notes |
|------|------|------|-----|-----|-------|
| B1 | Warped Warden (MVP) | **Corruption Violet** | HSL(285, 70%, 48%) | `#9B2ED4` | Violet-magenta. Not achievable by mixing any two rune colors. Reads as "wrong" against the warm dungeon and clean jewel-tone vocabulary. |
| B2 | TBD (Vertical Slice) | Reserved | ~165–180° zone | — | Teal-green, distinct from Verdant (138°) |
| B3 | TBD (Vertical Slice) | Reserved | ~340–355° zone | — | Rose-crimson, distinct from Ashfire (14°) |

**Boss color rules:**
1. Boss color appears only on: room ambient tint, boss sprite accent, boss attack particles. Never on UI, rune effects, or player.
2. Boss color desaturates to 0% on death — the arena exhales the corruption.

### 4.4 UI Palette

UI draws from environment palette and rune palette only. No new colors introduced — except health red (see below).

| UI Element | Color | Source | Reason |
|------------|-------|--------|--------|
| Rune grid frame | E3 Hearthstone `#5E4E3D` + E7 inner glow | Environment | Frame reads as dungeon artifact, not magic. Slots (magic) contrast against it. |
| Rune grid background (empty slot) | E6 Atmosphere Haze `#1B1B22` at 80% opacity | Environment | Void = potential. Awaits filling. |
| Rune slot (filled) | Rune's assigned color (R1–R5), full saturation | Rune palette | Color IS the rune identity. |
| Rune slot (active/selected) | Rune color + 2px white inner rim highlight | Rune palette | Distinguishes active from inactive without adding a new color. |
| Health bar fill | HSL(6, 90%, 50%) `#E61A0D` — dedicated health red | Dedicated | Darker and more red (less orange) than Ashfire. Controlled deviation — health semantic is too important to mute. |
| Health bar: low health (<25%) | Pulse between health red and E6, at 1.5 Hz | Health red + E6 | Draws attention without a new color. 1.5 Hz is well below seizure-risk threshold. |
| Main UI panels | E1 Dungeon Stone `#3A3530` at 90% opacity | Environment | Panels feel carved from the dungeon. |
| Panel border accent | E7 Warm Lantern Bleed `#8E7358` | Environment | Presence without brightness. |
| Active/hover state | E7 brightened to 70% lightness | Environment | "Touched by warmth" — not a magic color. |
| Inactive/disabled state | E2 Worn Slate `#474B52` at 60% opacity | Environment | Recedes visually. |
| Damage numbers | Casting rune's color (R1–R5) | Rune palette | Numbers echo what caused them — reinforces rune identity. |
| Victory flash | White `#FFFFFF` → E7 fade (0.5s) | Highlight + Environment | White = universal victory; fades to warm lantern for "exhale" mood. |
| Hazard/trap indicator | White `#FFFFFF` outline, 2 Hz pulse | Highlight | Maximum contrast, no rune confusion. White reserved for hazard and victory flash only. |
| UI text / labels | `#D4C9B8` warm off-white | Neutral | Reads in any context, doesn't compete with jewel tones. |

### 4.5 Colorblind Safety

**Target conditions:** Deuteranopia (~6% male players, red-green) and Protanopia (~2% male players, red-green).

#### Rune Pair Risk Assessment

| Pair | Risk | Failure Mode | Backup Cue |
|------|------|-------------|------------|
| R1 Ashfire (red) + R5 Verdant (green) | **HIGH** | Both may appear brown/yellow-brown under deuteranopia/protanopia | Mandatory shape icon (see below) + VFX burst shape + audio |
| R1 Ashfire + R3 Stormgold | **MEDIUM** | Both warm tones; R1 may shift toward R3 under protanopia | Shape icon + luminance split (R3 brighter at L=55%) |
| R2 Voidblue + R4 Deepfrost | **LOW** | Blue-family; minor tritanopia risk (rare, ~0.01%) | Shape icon still applied |
| All other pairs | LOW | No significant confusion predicted | Shape icons applied universally |

#### Mandatory Icon System (per-rune slot, 8×8 px)

Every rune slot displays a small icon that is silhouette-readable without color. Icons are black on rune-color background.

| Rune | Icon Shape | Principle |
|------|-----------|-----------|
| R1 Ashfire | 3-spike upward flame cluster | "Flame" — aggressive upward points |
| R2 Voidblue | Inward spiral / eye shape | "Void" — pulls inward |
| R3 Stormgold | Forked lightning bolt | "Electricity" — universal symbol |
| R4 Deepfrost | Hexagonal crystal / snowflake | "Ice" — crystalline structure |
| R5 Verdant | Tri-leaf / spiral growth | "Nature" — organic, expanding |

**Validation rule:** Each icon must be recognizable in silhouette at 8×8 px. If it cannot be read at that size, the icon must be simplified before shipping.

#### Additional Redundancy Cues

| Cue | Implementation |
|-----|---------------|
| **VFX burst shape** | R1=spike burst, R2=inward swirl, R3=forked ray, R4=crystalline fractal, R5=expanding ring |
| **Audio signature** | Distinct cast sound per rune: fire=crackle-whoosh, void=low drone resonance, lightning=sharp crack, frost=crystalline chime, nature=organic bloom |
| **Cast animation** | R1=upward sweep, R2=pull-back/release, R3=snap point, R4=slow push, R5=spreading palm |

**Optional colorblind mode (settings toggle):** Increase rune slot icon from 8×8 to 12×12 px + single-letter label below slot (F, V, S, Fr, G). Flag for `ui-programmer` implementation.

**Seizure safety:** Only pulsing element is the low-health bar (1.5 Hz). All other transitions are one-shot fades or single-frame bursts. No strobing exceeds 3 Hz.

---

## 5. Character Design Direction

### 5.1 Player Character Visual Archetype — The Rune-Keeper

**Archetype direction:** Discoverer, not fighter. Silhouette reads "scholar carrying something slightly too big for them." Power was found, not trained for.

**Proportions:**
- Chibi-adjacent, not comedic: head-to-body ratio ~1:2.5 at sprite scale. Slightly large head aids expression readability.
- Compact oval body with one clear vertical accent (tall collar, hood peak, or held rod). This accent is the silhouette anchor distinguishing the Rune-Keeper from all enemy types.
- No exaggerated musculature. Slender, slightly uncertain limbs. Power lives in hands and mind.

**Costume / design vocabulary:**
- Layered travelling clothes: tunic/shirt beneath a longish coat or robe falling to mid-calf at sprite scale.
- Practical scholar details: small pouches, a satchel strap, slightly ill-fitting gear not made for combat.
- One unique accessory appearing nowhere on enemies: a rune-reading lens, runic clasp, or circuit-trace-stitched gloves. This is the "I am the protagonist" visual signal.
- Color: warm neutrals from environment palette as base, with one small accent glow matching the currently-active rune type (collar glow, pocket light — highlight only, never dominant color). Roots the player in the world while connecting them to the magic system.

**All-ages approachability:** Default expression is curious or slightly worried, never aggressive. No sharp silhouette angles except the vertical accent. No realistic weapon silhouettes. No exposed skin beyond face and hands.

**Camera distance readability (top-down, 16–24px native — non-negotiable):**
1. Vertical accent (hood/collar peak or held item upright)
2. Coat/robe hem — single-pixel-wide dark line separating from legs
3. Face dot cluster — two-pixel eyes minimum
4. Hand position — forward/outward when casting, tucked at idle

All costume detail (pouches, clasps, stitching) exists only in portrait/promo art.

### 5.2 Enemy Design Rules Per Archetype

**Governing tone:** Enemies are dungeon inhabitants that have been changed — warped by corruption, not built to kill. "Something went wrong here" not "this was designed as a weapon." Serves Pillar 5 (The Rune-Keeper's Secret) and the all-ages constraint simultaneously: a transformed creature is sympathetic; a murder machine is not.

**Corruption visual language (at least one marker per enemy):**
- *Rune-scarring* — geometric cracks or circuit-trace lines on the surface, desaturated rune color. Dormant at rest, glow when agitated.
- *Color bleed* — a rune color washing into the natural palette (jewel tone at 50–60% saturation max on enemies — never full saturation, which is reserved for player magic).
- *Fragmentation* — one edge of the silhouette is broken, or a small shard orbits the entity.

**Per-archetype vocabulary:**

**Drifter** (wide/flat, ranged/projectile)
- Origin implied: peaceful floater, slow ambient thing
- Corruption marker: color bleed — natural warm neutral stained by a rune color on one edge
- Motion: slow, wobbling body mass that sags and re-inflates. Lethargy, not aggression.
- Texture: soft rounded pixel clusters, no hard edges on the silhouette
- Native sprite: 16×16 px

**Charger** (tall/narrow, melee/rush)
- Origin implied: crystalline or root formation that grew tall and still
- Corruption marker: rune-scarring — geometric cracks along spike edges pulse before charge animation
- Motion: perfectly still at rest (reads as environment detail), then sudden violent forward lean. Stillness-to-movement contrast is the danger signal.
- Texture: hard, faceted pixel edges. The sharpest non-boss silhouette in the game. Angularity = all-ages-safe "danger" signal.
- Native sprite: ~12×20 px

**Cluster** (central oval + orbiting circles, swarm/summoner)
- Origin implied: colony creature — swarm that found a center
- Corruption marker: fragmentation (the design IS fragmentation — orbiting pieces are literally the entity coming apart)
- Motion: core pulses slowly; orbiters drift at slightly different speeds, desynchronized. Unsettled, nervous.
- Texture: hard core (more opaque/saturated) + soft orbiters (fade at edges)
- Native sprite: 24×24 px (orbiters need surrounding space to read)

**Boss — The Warped Warden** (asymmetric large polygon)
- Origin implied: ancient guardian, construct with a purpose. Asymmetry suggests centuries of change.
- Corruption markers: all three layered. Rune-scarring is prominent — the broken-rune ornament at center IS the scar that opened it.
- Motion: broken-rune ornament pulses independently of the body. Body has its own slow breathing cycle. Two separate animation cycles = internal conflict visual.
- Scale: never less than 3× the area of the largest standard enemy sprite. Size gap must be readable with no other enemies on screen for comparison.
- Native sprite: 48×48 px

**Colour hierarchy on enemies:** Enemy base palettes use warm or cool neutrals (≤40% saturation). Corruption markers use jewel tones at 50–60% saturation max — never full saturation. Full jewel-tone saturation belongs exclusively to player magic and projectile effects.

### 5.3 Expression and Pose Style

**Register: Exaggerated-readable.** SNES/GBA RPG clarity (every pose telegraphs meaning in silhouette alone) + Ghibli warmth (curious, approachable). Not stiff, not comedic.

At 16–24px native, anatomical realism is impossible. Every pose must read in silhouette alone — exaggeration is the tool.

**Rune-Keeper state poses:**

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
| 1. Crumple pose | 8–12 frames | Entity slumps into archetype-specific "exhausted" pose. Rune-Keeper: knees bent, arms loose, head down. Drifter: spreads flat. Charger: spikes droop. Cluster: orbiters slow and fall inward. Boss: ornament goes dark. Reads as exhausted, not dead. |
| 2. Bloom | 4–6 frames | Rapid outward expansion of corruption/magic color from sprite center. Single-frame bright flash at peak, then color blooms outward in a circle. "Something is releasing." |
| 3. Dissolve | 8–16 frames | Sprite breaks into 2–4px particle clusters that float upward and fade. Particle color matches bloom color. Floor remains clean — entity is fully gone. |

The bloom beat is critical. Defeat reads as "transformation or dispersal," not death.

### 5.4 LOD Philosophy

**Design for game distance first.** Portrait detail is a bonus, never a driver.

**Two-distance rule:** Every sprite designed for (1) game distance — native res, top-down camera; and (2) portrait/detail distance — 4–8x upscale in menus or promo art. Details that only read at portrait distance must not drive the game-distance silhouette.

**Target sprite resolutions:**

| Entity | Native Sprite Size |
|--------|-------------------|
| Player (Rune-Keeper) | 16×24 px |
| Drifter, Charger | 16×16 px (Charger may use 12×20) |
| Cluster | 24×24 px |
| Boss | 48×48 px |

All sprites snap to an 8px position grid.

**Must read at game distance (non-negotiable):**
- Player: vertical accent, coat/leg boundary, hand position
- Drifter: horizontal spread wider than player, soft edge
- Charger: taller than wide, ≥2 visible spike angles, hard edges
- Cluster: distinct core circle + ≥2 orbiting shapes with visible gap
- Boss: no axis of symmetry, broken-rune ornament as darker central shape

**Pixel art rendering rules:**
- No anti-aliasing. Hard pixel boundaries.
- Palette limit: player = 8 colors max (incl. transparency), standard enemy = 6 colors, boss = 12 colors.
- Outline: 1px, color = darkened version of dominant sprite color (~30% luminance of base). Not black — keeps sprites from looking pasted onto the background.
- Shadow: flat shadow ellipse beneath each entity (2px opacity blob). No dynamic lighting on sprite layers — lighting lives in the environment layer.

---

## 6. Environment Design Language

[To be designed]

---

## 7. UI/HUD Visual Direction

[To be designed]

---

## 8. Asset Standards

[To be designed]

---

## 9. Reference Direction

[To be designed]
