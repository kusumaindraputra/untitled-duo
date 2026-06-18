---
name: project-the-last-cipher-context
description: Core project context for The Last Cipher — game identity, pillars, audience, and platform constraints relevant to UX decisions
metadata:
  type: project
---

Game title: The Last Cipher. Genre: 2D top-down roguelike. Engine: Godot 4.6. Platform: PC (Steam / itch.io).

**Why:** All UX decisions must pass through these constraints. The target audience and platform constraints are the hardest UX constraints on the project.

**How to apply:** Use these as the first filter on any UX proposal. If a design pattern fails the 7+ legibility test or requires hover-only interaction, reject it before presenting to the user.

## Audience
All-ages (7+). Accessible to children, deep enough for adults. Solo developer (Kusuma Putra). Session length: 30–60 minutes per run.

## Platform and Input
- Primary: Keyboard/Mouse (drag-and-drop Prana grid is mouse-optimized)
- Secondary: Gamepad (partial support — no hover-only interactions, all UI keyboard navigable)
- No touch support

## Core Loop
Preparation Phase (enemies visible in arena at start positions, arrange Prana grid 3x3) → Combat Phase (move, dodge, cast). Decision happens before combat with full information. Execution tests positioning, not UI management under pressure.

## Game Pillars (UX-relevant)
- Pillar 3: Chaos Has Consequences — "If Fayde dies and cannot understand why, that is a design failure." Every system must communicate cause clearly.
- Pillar 2: Power is Earned Through Understanding — UI must expose system logic, not obscure it.

## Key Characters
- Fayde: android child protagonist, appears 11 years old, amnesiac
- Memo: companion robot, provides hints (never answers), undergoes Resonance

## Art Constraint (hard)
All-ages visual requirement: no blood/gore. Enemy defeat = Prana bloom dissolve. Darkness reads as mysterious, not threatening.

## Visual Identity
World: quiet, desaturated, calm (Ghibli-influenced). Prana effects: vivid jewel-tone. Contrast is the drama. UX must not fight this contrast — state transitions should reinforce it.

## Accessibility Standards (project-level)
- Usable with keyboard only
- Usable with gamepad only
- Text readable at minimum font size
- Functional without reliance on color alone
- No flashing content without warning
- Subtitles available for all dialogue
- UI scales at all supported resolutions

## Scope
MVP: 1 layer, 5 Prana types, 3 enemy types, 1 boss. No pause menu in MVP (Vertical Slice scope). No meta-progression in MVP.

## Key Systems Index
Game State & Scene Flow GDD: `design/gdd/game-state-scene-flow.md`
Systems index: `design/gdd/systems-index.md`
UX specs directory (to be authored): `design/ux/`
