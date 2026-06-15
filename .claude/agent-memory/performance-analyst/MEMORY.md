# Memory Index — Performance Analyst

- [Project Performance Targets](project_perf_targets.md) — 60fps / 16.6ms frame budget / <512MB memory target
- [Hot-Path Audit 2026-06-16](project_hotpath_audit_2026-06-16.md) — First full audit of 8 hot-path files; key findings: SEM .duplicate() per entity per frame, combat_hud chain-dot alloc per cast, SpellVFX ParticleProcessMaterial.new() per hit
