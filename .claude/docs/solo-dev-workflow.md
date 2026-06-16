# Solo Dev Lean Workflow

**Rule 0: Ship code, not documents. Documents only exist when they prevent future mistakes.**

This project is maintained by one developer. The default Claude Code Game Studios pipeline
is designed for teams of 5-10. This document overrides that pipeline for solo use.

## Decision Tree — Pick Your Tier

```
Is it a bug fix, tweak, or refactor < 2 files?
  YES → TIER 1 (just do it)
  NO  ↓

Does a story file already exist in sprint-status.yaml?
  YES → TIER 2 (/dev-story)
  NO  ↓

Is the feature small enough to describe in one sentence?
  YES → TIER 3 (describe → implement → commit)
  NO  ↓

TIER 4 (new system — lean GDD + stories + /dev-story)
```

---

## TIER 1 — Bug fix / tweak / small refactor

**When**: ≤2 files changed, intent obvious, no new API surface.

```bash
# Just implement it, then:
rtk git add <files> && rtk git commit -m "fix: ..."
```

**Skip everything**: story file, /story-readiness, /dev-story, /story-done, /code-review.
Update sprint-status.yaml only if the story already exists there.

Examples: is_alive() fix (S7-13), ADR errata (S7-14), text corrections (S7-15),
signal renames (S7-09), timer refactor (S7-07).

---

## TIER 2 — Known story (exists in sprint-status.yaml)

**When**: Story file exists, task is well-defined.

```
/dev-story <story-file>
```

That's it. /dev-story handles: reads story → implements → runs tests → commits → pushes.

**Skip**: /story-readiness, /code-review, separate /story-done, GitHub issue comment.

Examples: S7-05 (SpellVFX pool), S7-06 stories (Audio System).

---

## TIER 3 — New feature (no story yet)

**When**: Feature is clear but not yet in backlog.

```
Describe it in chat → implement → commit → add to sprint-status.yaml
```

**Skip**: /brainstorm, /quick-design, /create-epics, /create-stories, /qa-plan.
**GDD**: only if the mechanic has rules complex enough to forget in 2 weeks.
**ADR**: only if the decision will constrain code choices in future files.

---

## TIER 4 — New system (complex, multiple stories)

**When**: System spans 3+ files, requires defined data contracts, or has non-trivial rules.

```
1. Write lean GDD (4 sections only — see below)
2. Write story entries directly into sprint-status.yaml
3. /dev-story per story
4. Commit per story
```

**Skip**: /create-epics (overhead), /story-readiness, /qa-plan, /smoke-check,
/gate-check (unless milestone handoff).

Examples: Audio System (S7-06), future combat reworks.

### Lean GDD Format (4 sections, not 8)

```markdown
## Overview
One paragraph: what this system does and why.

## Rules
Unambiguous mechanics. Bullet points. No prose padding.

## Formulas
All math defined. If no math, omit this section.

## Acceptance Criteria
Testable conditions. Each AC maps to a test or manual check.
```

Omit for now: Player Fantasy, Edge Cases, Tuning Knobs, Dependencies.
Add them back only when a playtest reveals they're missing.

---

## Skills — Permanently Cut for Solo Dev

| Skill | Reason |
|---|---|
| `/story-readiness` | You wrote the story. You know if it's ready. |
| `/code-review` per story | You are the code reviewer. Do it inline. |
| `/qa-plan` per sprint | Replaced by: "do tests pass?" |
| `/smoke-check` | Just run the test suite directly. |
| `/gate-check` | Only before real milestone handoffs. |
| `/review-all-gdds` | Once per milestone max, never per sprint. |
| `/architecture-review` | Only when something is architecturally broken. |
| `/create-epics` separate from stories | Write story files directly. |
| GitHub issue comment after story | You are the stakeholder. Skip it. |
| session-state updates mid-session | End of session only. |

## Skills — Kept

| Skill | When |
|---|---|
| `/dev-story` | Every Tier 2+ story |
| `/sprint-plan` | Start of sprint |
| `/sprint-status` | Quick check anytime (Haiku — cheap) |
| `/retrospective` | End of milestone (not sprint) |
| `/gate-check` | Before milestone handoffs only |
| `/qa-plan` | Before external playtests only |

---

## Sprint Cadence

```
Sprint start : glance at sprint-status.yaml → pick top 3 → start coding
During sprint: Tier 1/2/3/4 as appropriate → commit → next story
Sprint end   : update sprint-status.yaml status fields → done
Pre-playtest : run test suite → fix failures → playtest
```

No mandatory DAY 1 GATE. No mandatory /qa-plan. No mandatory gate-check per sprint.

---

## Test Suite (run directly, no wrapper skill needed)

```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/unit --ignoreHeadlessMode
```

---

## Token Budget Targets

| Task | Target |
|---|---|
| Bug fix (Tier 1) | ~0 overhead |
| Known story (Tier 2) | 3-5k tokens |
| New feature (Tier 3) | 5-8k tokens |
| New system (Tier 4) | 15-20k tokens |
