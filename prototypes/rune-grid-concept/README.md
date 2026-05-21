# Rune Grid — Concept Prototype

**Hypothesis:** Player under combat pressure will spontaneously rearrange the rune grid
(not just mash cast) — proving it feels like a strategic mechanic, not an inventory screen.

## How to Run

1. Open Godot 4.6
2. Import this folder as a project (`project.godot`)
3. Press F5 (or the Play button)

## Controls

| Input | Action |
|-------|--------|
| **Drag runes** | Rearrange rune slots in the 3×3 grid |
| **SPACE** | Cast the current combo |
| **R** | Restart |

## Combos

| Rune Combo | Effect |
|------------|--------|
| Fire × 3 | Mega Inferno — massive AoE |
| Fire × 2 | Inferno — AoE fire burst |
| Ice + Lightning | Blizzard — slow + damage |
| Fire + Ice | Steam Cloud — damage zone |
| Shadow + Earth | Void Spike — piercing bolt |
| Anything else | Basic Bolt — single target |

## What to Observe

After playing, report back:
1. Did the hypothesis hold? (CONFIRMED / PARTIALLY / REFUTED)
2. Best moment — when did it feel like it was working?
3. Worst moment — what was frustrating or confusing?
4. Surprise — anything unexpected?
5. Verdict: PROCEED / PIVOT / KILL

## Notes

- After each cast, 3 random grid slots get new runes (partial refresh)
- Enemies spawn every 3.5 seconds; speed increases with score
- This is throwaway code — never merge into src/
