---
name: project-perf-targets
description: Performance budgets and platform targets for The Last Cipher
metadata:
  type: project
---

Target framerate: 60fps / 16.6ms frame budget.
Memory ceiling: <512MB (to be confirmed after first profiling session).
Draw calls: <200 per frame (2D pixel art; well within Godot 2D renderer capacity).
Platform: PC (Steam / itch.io), Keyboard/Mouse primary, partial Gamepad.
Renderer: Compatibility renderer (2D pixel art — no Forward+ or Mobile).

**Why:** Set in technical-preferences.md; solo dev pre-alpha, no profiling data yet.
**How to apply:** Flag any finding that risks breaking these ceilings at current or projected entity counts (10+ enemies is the near-term target).
