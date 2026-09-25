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

@export_group("Room Variety (ADR-0026)")

## Door labels for modified destinations (Rest rooms are always Wayshrines).
@export var door_challenge: String = "⚔ Challenge"
@export var door_cursed: String = "☠ Cursed"
@export var door_wayshrine: String = "♥ Wayshrine"

## Banner when entering a Challenge room.
@export var challenge_banner: String = "CHALLENGE — clear it without a hit"
## Banner the first time Fayde is hit in a Challenge room.
@export var challenge_lost: String = "Challenge lost"
## Banner after a flawless Challenge clear (%d = bonus shards).
@export var challenge_won_format: String = "FLAWLESS — +%d shards and an extra sigil"
## Banner when entering a Cursed room.
@export var cursed_banner: String = "CURSED — tougher foes, two sigils"

## Sigil overlay suffix when more than one pick is owed (%d of %d).
@export var sigil_pick_format: String = "  (%d of %d)"

## Wayshrine panel (Rest rooms).
@export var wayshrine_heading: String = "WAYSHRINE"
@export var wayshrine_body: String = "The shrine asks for blood. Offer it to inscribe a sigil?"
@export var wayshrine_trade_format: String = "Offer %d HP"
@export var wayshrine_leave: String = "Walk on"
@export var wayshrine_too_weak: String = "Too weak to offer blood"

@export_group("Floor Bosses (ADR-0026, ADR-0028)")

## Banner for each Vault Sentinel phase (Floor 1).
@export var sentinel_phase_banners: Array[String] = [
	"The vault's defences wake — turrets online",
	"LOCKDOWN — the Sentinel draws its laser cross",
]
## Banner for each Warped Warden phase (Floor 2).
@export var warden_phase_banners: Array[String] = [
	"Space folds — the floor starts to burn",
	"Rifts open — shells rain down",
	"TIME COLLAPSES — the field goes quiet, then breaks",
]
## Banner for each Cipher Keeper phase (1st, 2nd, 3rd HP threshold crossed).
@export var keeper_phase_banners: Array[String] = [
	"The first lock breaks — a beam pylon rises",
	"The vault closes in",
	"THE LAST CIPHER — hold on",
]
## Per-run boss variant names, keyed by BossVariant.id. Shown after the boss name
## ("Vault Sentinel · Overclocked").
@export var boss_variant_titles: Dictionary = {
	"bulwark": "Bulwark",
	"overclocked": "Overclocked",
	"lockdown": "Lockdown",
	"mirrored": "Mirrored",
	"hunting": "Hunting",
	"unstable": "Unstable",
	"gilded": "Gilded",
	"fractured": "Fractured",
	"tempest": "Tempest",
}
## Joins a boss name and its variant title.
@export var boss_variant_format: String = "%s · %s"

@export_group("Settings (ADR-0026)")

@export var settings_button: String = "SETTINGS"
@export var settings_title: String = "SETTINGS"
@export var settings_display_heading: String = "Display"
@export var settings_fullscreen: String = "Fullscreen"
@export var settings_window_size: String = "Window size"
@export var settings_vsync: String = "V-Sync"
@export var settings_comfort_heading: String = "Comfort"
@export var settings_screen_shake: String = "Screen shake"
@export var settings_reduce_flashes: String = "Reduce screen flashes"
@export var settings_audio_heading: String = "Audio"
@export var settings_master: String = "Master"
@export var settings_music: String = "Music"
@export var settings_sfx: String = "SFX"
@export var settings_controls_heading: String = "Keyboard"
## Names of GameSettings.REMAPPABLE actions, same order.
@export var settings_action_names: Array[String] = [
	"Move up", "Move down", "Move left", "Move right", "Dash", "Cast", "Special",
]
@export var settings_press_key: String = "Press a key…"
@export var settings_reset_keys: String = "Reset keys"
@export var settings_gamepad_note: String = "Gamepad buttons are fixed for now."
@export var settings_back: String = "Back  (Esc)"

@export_group("Release")

## Version line on the main menu (%s = application/config/version).
@export var version_format: String = "v%s"

@export_group("Combat Tutorial")

## Heading of the in-combat coach panel.
@export var coach_heading: String = "LEARN TO FIGHT"

## Coach steps, in display order. Each line is shown with a checkbox and ticks when
## the player actually does it. Order matches TutorialCoach.STEPS.
@export var coach_steps: Array[String] = [
	"Move  —  WASD / left stick",
	"Cast  —  SPACE / A  (your grid picks the spell)",
	"Dash  —  SHIFT / X  (you can't be hit mid-dash)",
	"Perfect Dodge  —  dash THROUGH a bullet",
	"Perfect Cast  —  press again as the ring closes",
	"Special  —  F / right mouse / Y when the meter is full",
]

## Shown when every step is ticked.
@export var coach_done: String = "Nice. You know everything — go get them."

## Pause-menu button that turns the coach back on.
@export var coach_replay_button: String = "Replay Tutorial"

@export_group("Memory Fragments")

## Small header above a newly recovered fragment.
@export var memory_header: String = "MEMORY RECOVERED"

## Position of a fragment in the story (%d = number, %d = total).
@export var memory_count_format: String = "Memory %d of %d"

## Dismiss hint under a fragment or ending.
@export var memory_continue_hint: String = "Press any key to continue"

## Title and text for an anchor whose memory is not part of the story yet.
@export var memory_unknown_title: String = "A Memory Stirs"
@export var memory_unknown_body: String = "Something here feels familiar, but the memory slips away before it takes shape."

## Header above the ending that plays with fragments still missing.
@export var ending_header: String = "ENDING"

## Header above the ending that plays once every fragment is recovered.
@export var ending_true_header: String = "TRUE ENDING"

## Line under the partial ending (%d = found, %d = total).
@export var ending_partial_hint_format: String = "%d of %d memories recovered. Find the rest to learn the whole truth."

## Main-menu button that opens the archive (%d = found, %d = total).
@export var memories_button_format: String = "MEMORIES  %d/%d"

## Archive heading.
@export var memories_title: String = "MEMORIES"

## Archive entry for a fragment not recovered yet.
@export var memories_locked: String = "? ? ?"

## Archive text for a fragment not recovered yet.
@export var memories_locked_body: String = "Not recovered yet. Clear floors, and keep going even when you fall."

## Archive entries for the two endings once seen.
@export var memories_ending_label: String = "Ending"
@export var memories_true_ending_label: String = "True Ending"

## Archive close button.
@export var memories_back: String = "Back  (Esc)"
