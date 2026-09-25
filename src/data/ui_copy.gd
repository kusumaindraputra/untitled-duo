## UICopy — centralized player-facing UI strings for the demo.
##
## A single config resource holding the user-facing copy that was previously
## hardcoded across UI scripts (prana grid preparation panel, combat HUD hints,
## Prana type token abbreviations). Centralizing here gives one place to edit copy
## and is the staging point for a real localization pass: each field becomes the
## default value of a translation key when the l10n pipeline lands (see /localize).
##
## Authored as assets/data/ui_copy.tres and consumed via a preload const so it is
## available in headless tests without an Autoload (e.g. PranaTypeToken._COPY).
##
## NOTE (demo debt): this is centralization, NOT localization — strings are still
## a single hardcoded locale. Full i18n (tr() keys + translation tables) is a
## separate project-wide effort tracked by the /localize skill.
class_name UICopy
extends Resource

@export_group("Prana Type Tokens")

## Short element abbreviations shown on Prana tokens and grid readouts, in type_id
## order (0–4). Colours come from PranaCatalog (canonical) — only these short labels
## live here, since the catalog stores full names ("Ashfire"), not abbreviations.
@export var type_abbrevs: Array[String] = ["ASH", "VOID", "STRM", "DEEP", "VERD"]

@export_group("Preparation (Prana Grid)")

## Header label at the top of the preparation panel.
@export var prep_header: String = "PREPARATION PHASE"

## Instructional hint under the preparation header.
@export var prep_hint: String = "Drag a Prana into a slot, or use Arrows + E (place) / Q (discard) / C (cycle)  •  Then Confirm"

## Divider label above the player's Prana bag tray.
@export var bag_label: String = "─── YOUR PRANA ───"

## Hint shown when every grid slot is filled.
@export var full_grid_hint: String = "Grid full — right-click a slot to discard and make room."

## "Clear all placed Prana" button label.
@export var clear_all_button: String = "Clear All"

## Confirm-loadout button label.
@export var confirm_button: String = "Confirm"

## Error shown when confirming with an empty centre slot.
@export var error_center_slot: String = "Place a fragment in the centre slot"

## Prefix for the gamepad control strip.
@export var pad_prefix: String = "PAD: "

## Type-indicator text when the bag holds no selectable fragment.
@export var bag_empty: String = "BAG EMPTY"

## Type-indicator text when the bag has fragments but none is selected yet.
@export var select_prana: String = "SELECT PRANA"

@export_group("Combat HUD")

## First-combat dash hint (AC-DH-03).
@export var dash_hint: String = "Shift / LT — Dash"

## Banner word shown when a Cascade fires this wave (ADR-0016 recognition layer).
## Rendered as "✦ {cascade_label} ×{mult}" by the Combat HUD callout.
@export var cascade_label: String = "CASCADE"

## Callout floated when a basic attack lands in the Perfect rhythm window.
## A streak renders as "{perfect_label} ×N".
@export var perfect_label: String = "PERFECT"

## Label beside the Special meter while it charges.
@export var special_label: String = "SPECIAL"

## Label beside the Special meter when it is full (names the keyboard + pad bindings).
@export var special_ready_label: String = "SPECIAL READY — F / RMB / Y"

@export_group("Bullet Hell (ADR-0018)")

## Prefix on an elite enemy's preview name label (e.g. "★ Rifter").
@export var elite_prefix: String = "★ "

## Callout floated when a boss enters a new pattern phase. Renders "{label} {n}".
@export var boss_phase_label: String = "PHASE"

@export_group("Fast Pace (ADR-0019)")

## Callout floated on a Perfect Dodge.
@export var perfect_dodge_label: String = "PERFECT DODGE"

## Label beside the style meter. The live rank letter follows it.
@export var style_label: String = "STYLE"

## Room-clear rank banner; %s is the rank letter.
@export var room_rank_format: String = "RANK %s"

@export_group("Floors (ADR-0020)")

## Floor names, in floor order (floor 1 first). Shown in the HUD and the floor intro.
@export var floor_names: Array[String] = ["Deep Scrap Yard", "Functional Corridors", "Cipher Core"]

## HUD floor label: floor number, then floor name.
@export var floor_label_format: String = "Floor %d · %s"

## Banner shown when a floor starts: floor number, then floor name.
@export var floor_intro_format: String = "FLOOR %d\n%s"

## Room-clear reward line; the first %d is HP healed, the second the Special head start.
@export var room_rank_reward_format: String = "+%d HP   +%d Special next room"

## Confirm button label when nothing changed since the last room (quick continue).
@export var quick_continue_button: String = "Continue ▶"

## Hint shown in the preparation panel when quick continue is available.
@export var quick_continue_hint: String = "No new Prana — press Space or Enter to continue"

@export_group("Meta Progression (ADR-0025)")

## Menu progress line: shards, runs, wins, best floor.
@export var progress_line_format: String = "Cipher Shards  %d      Runs  %d      Wins  %d      Best Floor  %d"

## Header above the Heirloom row on the main menu.
@export var heirloom_header: String = "HEIRLOOM — a sigil you start every run with"

## Heirloom button, locked: title, then shard cost.
@export var heirloom_locked_format: String = "%s\n%d shards"

## Heirloom button, unlocked but not equipped.
@export var heirloom_unlocked_format: String = "%s\nEquip"

## Heirloom button, equipped.
@export var heirloom_equipped_format: String = "%s\n✔ Equipped"

## Description line under the Heirloom row: sigil description, then the state hint.
@export var heirloom_desc_format: String = "%s  —  %s"

## State hints for the Heirloom description line.
@export var heirloom_hint_buy: String = "press to unlock"
@export var heirloom_hint_poor: String = "not enough shards yet"
@export var heirloom_hint_equip: String = "press to equip"
@export var heirloom_hint_unequip: String = "press to unequip"

## Hard Mode toggle label (shown once unlocked).
@export var hard_mode_label: String = "Hard Mode  (faster bullets, more elites, +50% shards)"

## Shown instead of the toggle while Hard Mode is locked.
@export var hard_mode_locked: String = "Win a run to unlock Hard Mode"

## End-of-run stat row label for the shard payout.
@export var shards_earned_label: String = "Cipher Shards"

## Line on the end screen the first time Hard Mode unlocks.
@export var hard_mode_unlocked_banner: String = "HARD MODE UNLOCKED — switch it on from the main menu"

## Line on the core-pick screen naming the equipped Heirloom (%s = sigil title).
@export var heirloom_active_format: String = "Heirloom: %s"
