# Epic: Audio System

> **Layer**: Foundation
> **GDD**: design/gdd/audio-system.md
> **Architecture Module**: AudioSystem
> **Status**: Ready — Priority: Vertical Slice (deferred — implement after First Playable gameplay loop is validated)
> **Stories**: Not yet created — run `/create-stories audio-system`

## Overview

Implements the 4-bus audio architecture (Master, Music, SFX, UI, AMB), the AudioEventRegistry for data-driven audio event dispatch, A/B crossfade music FSM with Tween-based transitions, and the 24-node SFX pool with priority-based oldest-first eviction. AudioSystem is Autoload #5, connecting to GameStateManager signals for music state transitions and to HealthAndDamage signals for reactive SFX. All callers dispatch via `play_event(id: StringName)` and `play_stinger(id: StringName)` — no direct AudioStreamPlayer access outside this module.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Autoload Architecture | AudioSystem registered at Autoload position 5 — after GameStateManager | LOW |
| ADR-0012: Audio System Implementation Contract | 4-bus architecture, SFX pool eviction, music FSM states, process mode assignments, volume clamp invariants | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-AS-001 | 4-bus architecture: Master, Music, SFX, UI, AMB — bus names as StringName constants | ADR-0012 ✅ |
| TR-AS-002 | SFX pool: 24 nodes, priority-based eviction (oldest LOW first, then NORMAL; HIGH never evicted unless all HIGH) | ADR-0012 ✅ |
| TR-AS-003 | Music A/B crossfade via `Tween.set_parallel(true)` — simultaneous fade; kill prior tween first | ADR-0012 ✅ |
| TR-AS-004 | `play_event()` routes by `AudioEventData.bus` field; `&'AMB'` → error (use `play_ambient()` instead) | ADR-0012 ✅ |
| TR-AS-005 | Process modes: Music/Ambient/UI/Stinger `ALWAYS`; SFX pool 24 nodes `PAUSABLE` | ADR-0012 ✅ |
| TR-AS-006 | `set_music_volume()` clamped to max -3.0 dB — Prana SFX headroom invariant | ADR-0012 ✅ |
| TR-AS-007 | `set_amb_volume()` clamped to max -10.0 dB — 'world breathes softly' sonic identity | ADR-0012 ✅ |
| TR-AS-008 | END_VICTORY and END_DEFEAT must be non-looping — `finished` signal required for auto-transition | ADR-0012 ✅ |
| TR-AS-009 | DYING state minimum hold: `DYING_MIN_HOLD_SEC = 1.5s` before transitioning to END_DEFEAT | ADR-0012 ✅ |
| TR-AS-010 | AudioSystem registered after GameStateManager (#5) — connects to GSM signals in `_ready()` | ADR-0012 ✅ |
| TR-AS-011 | Stinger player: non-pooled, `PROCESS_MODE_ALWAYS` — plays in all states including PAUSED | ADR-0012 ✅ |
| TR-AS-012 | Pool timestamp oldest-first eviction: `_timestamps[i] = 0` at startup | ADR-0012 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/audio-system.md` are verified
- All Logic stories have passing test files in `tests/unit/audio/`
- Music FSM state transitions verified: all 7 states × valid trigger inputs
- SFX pool eviction policy verified: pool exhaustion with mixed priority levels produces correct eviction order
- Volume clamp invariants verified: `set_music_volume()` rejects values above -3.0 dB; `set_amb_volume()` rejects above -10.0 dB

## Next Step

Run `/create-stories audio-system` to break this epic into implementable stories.
**Note**: Defer this epic until after First Playable gameplay loop (Prana Grid, Combination Resolution, Spell Casting) is validated.
