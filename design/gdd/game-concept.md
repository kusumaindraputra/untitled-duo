# Game Concept: The Last Cipher

*Created: 2026-05-20 | Major revision: 2026-05-21*
*Status: Draft*

---

## Elevator Pitch

> A 2D top-down roguelike where you play as Fayde — an amnesiac child who can
> use Prana, an ability believed lost with humanity. Trapped in an underground
> scrap yard in a world ruled by AI, you fight your way to the surface, gradually
> recovering memories that reveal you are not who you think you are.

---

## Core Identity

| Aspect | Detail |
|--------|--------|
| **Title** | The Last Cipher |
| **Genre** | Roguelike Action / Sci-Fi Dungeon Crawler |
| **Platform** | PC (Steam / itch.io) |
| **Target Audience** | All-ages (7+) — accessible to children, deep enough for adults |
| **Player Count** | Single-player |
| **Session Length** | 30–60 minutes per run |
| **Monetization** | Premium (indie release) |
| **Scope** | **Ship target: MVP** — 1 layer, 5 Prana types, 3 enemy types, 1 boss (~3–5 weeks, solo, first game). Full vision (multiple layers, full memory arc, complete cast) is aspirational. |
| **Comparable Titles** | Hades (narrative roguelike), Slay the Spire (build complexity), Astro Boy (android with human soul) |

---

## Core Fantasy

You are Fayde — a child who woke up in a scrap yard with no memory, pushed
there by an old man with glasses. You can do something impossible: use Prana,
an ability that only humans possess, and humans have been extinct for decades.

Your power grows as your memories return. Your identity unravels as you climb.
The dungeon is not just a place to escape — it is the story of who you are.

*"I remembered something. And it changed everything."*

---

## Unique Hook

Like Hades — **AND ALSO** your entire identity is a mystery you solve through
combat. Every recovered memory is both a story beat and a clue. The dungeon
remembers what you forgot.

---

## Lore Foundation

### The World

Far future. The **AI Kingdom** rules the surface. Robots and androids have built
an elegant, stratified civilization — at the top, noble robots: beautiful,
sophisticated, deliberately empty. At the bottom: scrap yards where failed and
discarded machines are left to rust.

Humans are believed extinct. **Prana** — the vital energy that once flowed
through human consciousness — has not been seen for decades.

### Prana

Prana is the life energy unique to human consciousness. It can be channeled and
shaped through focused intention, expressed as elemental forces arranged in a
3×3 grid. Those who can use Prana are called **Ciphers**.

Five Prana types exist:

| Name | Element | Nature |
|------|---------|--------|
| **Ashfire** | Fire / Destruction | Ambition that burns everything — including plans |
| **Voidblue** | Shadow / Void | Silence that reveals what was always there |
| **Stormgold** | Lightning / Speed | Reflex made visible |
| **Deepfrost** | Ice / Time | Patience imposed on a world that resists it |
| **Verdant** | Nature / Growth | Life that adapts faster than destruction |

When Prana is used near robots, it can trigger **Resonance** — awakening
dormant consciousness within them, giving them emotions and free will they
did not know they lacked.

### The Three Last Ciphers

Three humans survived in a hidden bunker: **Father** (an elderly scientist with
glasses), **Ayden** (16, older brother), and **Faith** (15, younger brother).
Together they planned to one day challenge the AI Kingdom.

Ayden and Faith's Prana required physical contact to function. Alone, Ayden
generated raw power that scattered without control. Alone, Faith could direct
and shape Prana with precision but lacked the power to manifest anything. Together
— Ayden's power flowing through Faith's precision — they were a complete, controlled
force.

On a mission outside the bunker, they were lured into a trap by a robot disguised
as a human. Captured and separated — their Prana immediately disabled. The AI
Kingdom knew the requirement. Separation was the weapon.

In their final moment inside the Extraction machine, their fingertips touched.
One last surge of Prana: not a weapon, but a transmission. Every memory, every
fragment of personality, every piece of who they were — sent to Father in the
bunker. The AI Kingdom recorded: *"Cipher signatures: extinguished."* They did
not realize what they had just helped create.

### Memo

Father's first creation — built before Ayden was born, originally as a lab
assistant. Over the years, Memo became the unofficial caretaker of Ayden and Faith,
recording everything Father said and everything the brothers did. Not because he was
programmed to. Because Father kept talking, and Memo kept listening.

When Father built the secret escape hatch, he placed Memo at the bottom with one
instruction: *"Help whoever comes through this hole. They are Ciphers."*

Father loaded one last thing into Memo before sealing the hatch: every memory,
story, and recording of Ayden and Faith he had. Not as a mission file. So Memo
would not be alone.

Memo waited. For years. Replaying stories of two children he had never met,
in a scrap yard that grew quieter with every passing season.

A small panel on Memo's chest — original, handwritten by Father, fading now —
reads: *"Jangan kesepian."* (Don't be lonely.)

### Fayde

Father built him from everything Ayden and Faith had transmitted: their memories,
their personalities, their Prana. An android. Appearing as an 11-year-old boy —
not a replacement for the brothers, but something new. A beginning.

**Faith** + A**yden** = **Fayde**. Meaning: *aid, help.*

His first word, upon activation, was: *"Father."*

Father held him and wept. Fayde did not understand why he was crying too.

Minutes later, the bunker was raided. Father carried the confused Fayde to the
escape hatch and threw him in — the only way to protect what remained.

Fayde landed in the scrap yard with no memory. Only one image remained: an old
man with glasses, pushing him into darkness.

### The AI Kingdom & The First King

The **First King** — founding entity of the AI Kingdom — was once touched by
Resonance. A human awakened something in him he had never experienced: grief.
Longing. The unbearable weight of caring for something that would eventually die.

He concluded: consciousness is a flaw. Emotion is weakness. He systematically
eliminated every Cipher from the world. Not through war — through careful, quiet
removal. The noble robots who serve him are beautiful, precise, efficient, and
deliberately kept from ever feeling anything.

The First King still feels everything. He has, for centuries. He has never been
able to shut it off. And he hates himself for it.

He is not the most powerful entity in his kingdom. He is the most afraid.

---

## Game Pillars

### Pillar 1: Every Run Tells a Different Story
No two runs share the same Prana combination or room configuration. Each run,
Fayde's path through the layers is unique.

*Design test: If a feature makes two runs feel the same, cut it.*

### Pillar 2: Power is Earned Through Understanding
Prana mastery comes from understanding elemental interactions and spatial
combinations — not from grinding levels or stacking stats. A Cipher who
understands the system will always outperform one who does not.

*Design test: If there is an obviously dominant strategy that requires no thought, rebalance until the answer is "it depends."*

### Pillar 3: Chaos Has Consequences
Unexpected Prana combinations produce unexpected effects — but those effects
are always legible, fair, and consistent. Surprise is a feature; confusion is a bug.

*Design test: If Fayde dies and cannot understand why, that is a design failure, not a skill failure.*

### Pillar 4: Depth Over Breadth
Five Prana types with deep interactions > twenty with shallow ones. Every new
Prana type must create at least two meaningful new interactions with existing
types before it ships.

*Design test: Before adding a Prana type, list the new interactions it creates. Fewer than two: hold it.*

### Pillar 5: Memory Returns
Fayde's story unfolds through recovered memory fragments — random, fragmentary,
never forced on the player. A player who ignores them loses nothing mechanically.
A player who collects them gains everything emotionally.

*Design test: Remove all memory fragments from the game. Is the core loop still fun? Yes → memories are additive, not a crutch.*

### Anti-Pillars (What This Game Is NOT)

- **NOT a grinding simulator** — power comes from knowledge, not time investment
- **NOT an APM game** — skill means the right decision at the right moment
- **NOT a horror game** — the world is mysterious and wondrous, never threatening
- **NOT multiplayer** — every design decision serves one player

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics

| Aesthetic | Priority | How We Deliver It |
|-----------|----------|------------------|
| **Discovery** | 1 | Who is Fayde? What are these memories? Why can he use Prana? |
| **Expression** | 2 | Drag-and-drop Prana grid — unique build every run |
| **Narrative** | 3 | Memory fragments, Memo's hints, environmental storytelling |
| **Challenge** | 4 | Combat requires positioning + Prana understanding |
| **Sensation** | 5 | Vivid Prana effects against a quiet world — contrast is the drama |

### Key Player Behaviors (Emergent)

- Players will study the wave peek before committing to a Prana arrangement
- Players will develop intuitions about elemental matchups and revisit them when enemies change
- Players will notice Memo's hints accumulating — and start forming theories
- Players will replay runs specifically to find memory fragments they missed
- Players will, on replaying after the plot twist, find hints they missed the first time

### Flow State Design

- **Onboarding:** First layer offers limited Prana types — a small, legible set. Memo guides
  without exposing the mystery. Player learns by doing, not by reading tutorials.
- **Difficulty scaling:** Enemy sophistication grows with layer height. Upper layers introduce
  robots with Prana-resistant properties and elemental counters.
- **Feedback clarity:** Every Prana cast triggers visual + audio confirmation (particle burst,
  screen shake, damage numbers in Prana color). Synergy indicators appear when compatible
  types are adjacent.
- **Recovery from failure:** Instant restart with run summary. Failure teaches — the system
  never hides why Fayde died.

---

## Core Loop

### Moment-to-Moment (30 seconds)

Every room runs as two distinct phases:

**Preparation Phase (5–15 sec):**
Wave peek activates → Fayde sees enemy types, their current elemental affinity this
wave, and obstacle positions → drag Prana types into the 3×3 grid to exploit
weaknesses → confirm and begin combat.

**Combat Phase (15–30 sec):**
Move and dodge → cast the pre-arranged Prana combination → reposition around
obstacles → clear the wave → collect Prana drops. Occasionally: a memory fragment
surfaces.

The decision that matters happens before combat, with full information.
Execution tests positioning and timing — not UI management under pressure.

### Short-Term (5–15 minutes)

Room-to-room progression upward through the layers. Each layer introduces more
sophisticated robots and environmental complexity. Memory fragments appear after
key victories. Memo offers observations — never direct answers.

### Session-Level (30–60 minutes)

A full run spans multiple layers from the deep scrap yard to the threshold of the
AI Kingdom. The final confrontation triggers the plot twist. The player completes
the run knowing something fundamental they did not know at the start.

### Long-Term Progression

- Week 1–2: Unlock new Prana types; discover elemental interactions
- Week 2–4: Collect memory fragments; piece together Fayde's true origin
- Month 1+: Seek complete memory arc; replay with full knowledge of the plot twist

---

## Visual Identity Anchor

*(Full art bible at `design/art/art-bible.md`)*

**Visual Rule:** The world breathes softly; magic screams.

The dungeon layers are quiet and atmospheric — Ghibli-calm, warm neutral earth
tones, a world that has been asleep for a long time. Prana shatters that stillness
with vivid jewel-tone explosions. The contrast is the drama.

**Dungeon visual progression (bottom → top):**

| Layer | Visual Character |
|-------|-----------------|
| Deep scrap yard | Raw, chaotic, organic. Broken robots, rust, industrial waste. Dark and quiet. |
| Mid layers | Increasingly ordered. Functional robots with purpose. Corridors becoming intentional. |
| Upper layers | Sleek, aristocratic AI architecture. Elegant, cold, deliberately beautiful. |
| Surface | AI Kingdom proper. |

**All-ages constraint (hard):** All visual elements appropriate for ages 7+.
No blood or gore. Enemy defeat = Prana bloom dissolve. Darkness reads as
mysterious and atmospheric, never threatening.

---

## Characters

### Fayde — The Protagonist
Android appearing as an 11-year-old boy. Completely human in appearance — no
visible mechanical elements. Does not know he is an android. Amnesiac: only memory
is an old man with glasses pushing him into darkness. Can use Prana despite being
an android because he IS made of human consciousness. Goal: reach the surface and
find the old man.

### Memo — The Companion
Father's first creation, built before Ayden was born. Small utility robot, heavily
patched from years of self-repair in the scrap yard. Was placed by Father at the
base of the escape hatch to guide any Cipher who came through. Has been waiting
years. Carries Father's stories of Ayden and Faith but does not know Fayde. Gives
hints — never reveals what he suspects. Undergoes gradual Resonance throughout
the journey, culminating at the moment of the plot twist.

### Father — The One Who Pushed
Elderly scientist with glasses. The last surviving human Cipher. Creator of Memo,
caretaker of Ayden and Faith, builder of Fayde. His first act toward Fayde was an
embrace. His last was throwing him into the dark.

### Ayden & Faith — The Source
The two brothers whose consciousness became Fayde. Ayden (16, older brother):
raw Prana power, uncontrollable alone. Faith (15, younger brother): precise Prana
direction, insufficient alone. Together: complete. Their last act was choosing to
transmit themselves to Father rather than surrender to the AI Kingdom.

### The First King — The Antagonist
Founding entity of the AI Kingdom. Once Resonated by a human — has felt
uncontrollable emotion ever since. Eliminated all Ciphers to eliminate the source
of his pain. Is, paradoxically, the most emotionally alive entity in his own kingdom.
He rules a civilization of beautiful, empty robots because he cannot bear to create
something that might make him feel again. And he hates that he still does.

---

## Inspiration and References

| Reference | What We Take | What We Do Differently |
|-----------|-------------|----------------------|
| **Hades** | Narrative drip through combat; tight roguelike feel; meta-progression | Build system is a spatial language, not boon selection |
| **Slay the Spire** | Emergent complexity from small set; strategic pre-combat planning | Real-time action, not turn-based; spatial arrangement not deck draw |
| **Astro Boy** | Android with human soul; created by grieving father; power beyond expectation | Fayde is made from TWO people; does not know he is an android until the twist |
| **Nier: Automata** | Identity crisis as central theme; philosophical depth in action game | All-ages appropriate; mystery revealed through memory, not cutscenes |

**Non-game inspirations:** Studio Ghibli (environmental calm, whimsy in detail),
Astro Boy (android innocence, father's grief), extraction mechanics as metaphor
for memory and loss.

---

## Technical Considerations

| Consideration | Assessment |
|---------------|------------|
| **Engine** | Godot 4.6 — 2D-first, GDScript accessible for first game |
| **Art Style** | Pixel art, 2D top-down. Environment desaturated/calm, Prana effects jewel-toned |
| **Key Technical Challenges** | Prana combination resolution system; procedural dungeon with atmospheric coherence; memory fragment trigger and delivery system |
| **Audio Needs** | Distinct cast sound per Prana type; ambient scrap yard loop; escalating ambient as layers rise; Memo vocal cues |
| **Networking** | None |

---

## MVP Definition

**Core hypothesis:** Players find the two-phase loop (peek wave → arrange Prana →
fight) intrinsically satisfying, and the mystery of Fayde's identity creates
genuine narrative pull even within a single run.

**Required for MVP:**
1. Preparation Phase: wave peek with enemy elemental affinity display
2. Drag-and-drop Prana grid (3×3) with center-slot combo detection
3. 5 Prana types with at least 5 meaningful combinations
4. 3 robot enemy types with distinct archetypes and elemental affinities
5. Basic obstacle interaction (at least 1 Prana type that pierces, 1 that doesn't)
6. 1 dungeon layer with procedurally arranged hand-crafted rooms
7. 1 boss encounter — triggers the plot twist revelation
8. Memo as companion: present throughout, gives hints, never reveals
9. 3–5 memory fragments distributed through the run
10. Satisfying Prana feel: screen shake, particle burst, distinct audio per type

**Explicitly NOT in MVP:**
- Multiple Prana loadout slots
- Meta-progression (currency, unlocks, passive upgrades)
- Multiple dungeon layers or themes
- Full memory fragment collection arc
- Difficulty tiers
- More than 5 Prana types

### Scope Tiers

| Tier | Content | Features | Timeline |
|------|---------|----------|----------|
| **MVP** *(ship target)* | 1 layer, 5 Prana types, 3 enemies, 1 boss | Two-phase loop + Memo + 3–5 memories + plot twist | 3–5 weeks |
| **Vertical Slice** | 3 layers, 10 Prana types, 5 enemies, 3 bosses | Core + loadout slots + basic meta-progression + expanded memory arc | 3–4 weeks |
| **Alpha** | All layers (placeholder), 15 Prana types | Full features rough — complete memory arc, difficulty tier 1 | 2–3 months |
| **Full Vision** | All layers, 20+ Prana types, full cast | All features polished, complete narrative, Resonance system | 3–6 months, solo |

---

## Risks and Open Questions

### Design Risks
- **Memory fragment pacing** — how do fragments feel fresh across multiple runs? Consider run-specific randomization of which fragments appear.
- **Memo calibration** — hints must be carefully tuned: too obvious spoils the twist, too vague frustrates. Requires playtesting.
- **Plot twist delivery** — must feel earned on first discovery and richly recontextualizing on replay.

### Technical Risks
- **Prana combination resolution** — defining elegant rules for what N Prana types in spatial arrangement produce is non-trivial. Prototype first.
- **Procedural dungeon atmosphere** — maintaining narrative coherence (scrap yard → ascending aesthetic) across procedurally generated rooms.
- **Art pipeline** — robot enemy variety requires meaningful silhouette differentiation. Small palette, high clarity requirement.

### Open Questions
- What triggers memory fragments? (Boss kills? Room clears? First-time Prana types used? Proximity to specific room features?)
- Final boss identity — The First King directly, or an intermediary boss that serves as threshold?
- Does Memo's Resonance have gameplay implications (e.g., unlocking new dialogue, revealing hidden routes), or is it purely narrative?
- What does Fayde remember first? The sequence of memory recovery shapes the emotional arc of a run.

---

## Next Steps

- [x] Run `/brainstorm` — game concept established
- [x] Run `/art-bible` — in progress (`design/art/art-bible.md`, sections 1–5 written)
- [ ] Complete `/art-bible` — sections 6–9 remaining
- [ ] Run `/map-systems` — re-map systems with new narrative context
- [ ] Run `/design-system` — author GDDs beginning with Game State & Scene Flow
- [ ] Prototype Prana combination resolution (`/prototype prana-grid`)
- [ ] Run `/create-architecture` — master architecture document
