# ADR-0015: SpellVFX Particle Pool

## Status
Accepted

## Date
2026-06-16

## Last Verified
2026-06-16

## Decision Makers
Kusuma Putra (solo dev)

## Summary
`SpellVFX` was calling `GPUParticles2D.new()` on every spell hit (PERF-C1), creating and
freeing one node per hit and stressing the allocator mid-frame. This ADR establishes a
pre-pool of 5 `GPUParticles2D` nodes — one per `VfxBurstShape` — initialized at `_ready()`
and reused via interrupt-and-restart on each hit.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering / VFX |
| **Knowledge Risk** | LOW — `GPUParticles2D`, `ParticleProcessMaterial`, `emitting` property, and `restart()` method are stable since Godot 4.0. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None — all APIs in training data range. |
| **Verification Required** | Confirm `GPUParticles2D.restart()` in Godot 4.6 resets the particle timeline (not just toggles emitting). Verify in-editor: cast spell, observe burst restarts cleanly on rapid same-type hits. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Autoload Architecture — SpellVFX is Autoload #10) |
| **Depends On** | ADR-0003 (Signal-Driven Architecture — pool reuse triggered by `spell_hit_element` signal) |
| **Enables** | None |
| **Blocks** | None |
| **Ordering Note** | Pool must be fully initialized before any `spell_hit_element` signal fires. `_ready()` order guarantees: SpellVFX (Autoload #10) initializes after SpellCastingEffects (Autoload #9). |

## Context

### Problem Statement

`SpellVFX._spawn_hit_burst()` called `GPUParticles2D.new()` and `add_child()` on every
spell hit, then connected `finished → queue_free` to auto-delete. This creates and frees
one node per hit, triggering allocator pressure and object churn inside `_physics_process`
adjacent frames. Logged as PERF-C1 in the Sprint 7 deep audit.

### Current State

`_spawn_hit_burst(pos, type_data)` creates a new `GPUParticles2D`, adds it as a child,
configures shape params via `_configure_burst()`, then emits and auto-frees. 5 VfxBurstShape
values exist: BURST_FLAME=0, BURST_SPIRAL=1, BURST_LIGHTNING=2, BURST_CRYSTAL=3, BURST_VINE=4.

### Options Considered

**Option A: Pre-pool 5 nodes, one per shape, interrupt-and-restart on reuse.**
- Pool is a `Dictionary` keyed by `VfxBurstShape` int value.
- On hit: move node to target position, call `restart()`, set `emitting = true`.
- Concurrent hits of the same shape: restart interrupts the previous burst — acceptable
  because same-type concurrent hits are extremely rare in normal gameplay.
- Simple, zero allocation on hot path.

**Option B: Ring buffer (2-3 nodes per shape).**
- 10-15 pre-allocated nodes total.
- Handles concurrent same-type hits cleanly.
- Overkill for current encounter density. Defer to performance profiling if Option A
  shows visual artifacts in stress tests.

**Option C: Object pool with idle/active queues.**
- Maximum flexibility but highest code complexity.
- Premature for a 2D pixel-art game at this stage.

## Decision

**Adopt Option A.** Pre-pool 5 `GPUParticles2D` nodes at `_ready()`, indexed by
`VfxBurstShape` int. On each `spell_hit_element` signal: look up the pool node,
teleport to `target.global_position`, call `restart()`, set `emitting = true`.
No `GPUParticles2D.new()` on the hot path after initialization.

### Pool Specification

| Field | Value |
|---|---|
| **Pool size** | 5 nodes (one per `GameEnums.VfxBurstShape` value) |
| **Pool structure** | `Dictionary` — key: `int` (VfxBurstShape value), value: `GPUParticles2D` |
| **Initialization** | `_init_pool()` called in `_ready()` after signal connections |
| **Reuse strategy** | Interrupt-and-restart: `node.restart()` then `node.emitting = true` |
| **Concurrent hits** | Same-shape: restart (burst resets). Different-shape: independent nodes, no conflict. |
| **Auto-free** | Removed — pool nodes persist for the lifetime of the Autoload |
| **Layer** | `src/ui/` — unchanged. SpellVFX is a visual routing layer, not game logic. |
| **Autoload position** | #10 — unchanged. |

## Consequences

### Positive
- Zero allocation per spell hit after initialization.
- 5 long-lived nodes instead of N transient nodes — trivial GC impact.
- Simpler lifecycle: no `finished` signal connection, no `queue_free`.

### Negative
- Rapid same-type hits restart the burst early (visual artifact). Acceptable at
  current encounter density; revisit if enemy count scales to 10+.
- Pool nodes always in scene tree — 5 persistent GPUParticles2D with `emitting = false`
  when idle. Negligible cost.

### Neutral
- `_configure_burst()` and `_apply_burst_shape_params()` logic is unchanged.
  Pool pre-configures using the same code path.

## GDD Requirements Addressed

- PERF-C1 (SpellVFX particle allocation per hit) — resolved by this ADR.
