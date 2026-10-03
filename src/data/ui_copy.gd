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
@export var prep_hint: String = "Drag Prana into the grid"
## Second prep-hint line by device (U8): keyboard (place / discard / cycle keys) and pad.
@export var prep_controls_format: String = "Arrows move · %s place · %s discard · %s cycle"
@export var prep_controls_pad: String = "D-pad move · A place · B discard · RB cycle"

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
@export var dash_hint_format: String = "%s — Dash"
## Pad variant (%s = bound pad button, ADR-0031).
@export var dash_hint_pad: String = "%s — Dash"

## Banner word shown when a Cascade fires this wave (ADR-0016 recognition layer).
## Rendered as "✦ {cascade_label} ×{mult}" by the Combat HUD callout.
@export var cascade_label: String = "CASCADE"

## Callout floated when a basic attack lands in the Perfect rhythm window.
## A streak renders as "{perfect_label} ×N".
@export var perfect_label: String = "PERFECT"

## Label beside the Special meter while it charges.
@export var special_label: String = "SPECIAL"

## Label beside the Special meter when it is full (names the keyboard + pad bindings).
@export var special_ready_format: String = "SPECIAL READY — %s / RMB"
@export var special_ready_pad: String = "SPECIAL READY — %s"

@export_group("Bullet Hell (ADR-0018)")

## Prefix on an elite enemy's preview name label (e.g. "★ Rifter").
@export var elite_prefix: String = "★ "

## Callout floated when a boss enters a new pattern phase. Renders "{label} {n}".
@export var boss_phase_label: String = "PHASE"

@export_group("Fast Pace (ADR-0019)")

## Callout floated on a Perfect Dodge.
@export var perfect_dodge_label: String = "PERFECT DODGE"
## ADR-0058 duo swap. Callout when the tag-in i-frames take a hit.
@export var perfect_swap_label: String = "PERFECT SWAP"
## Callout where the brothers' two elements react (Link Reaction).
@export var link_label: String = "LINK!"
## Callout when a swap lands on the shared heartbeat.
@export var resonance_label: String = "RESONANCE"
## Prep preview line for the duo: Ayden's core, Faith's core (palm faces).
@export var duo_cores_format: String = "AYDEN %s · FAITH %s"
## Prep preview suffix naming the Link Reaction of the two cores.
@export var duo_link_format: String = "  → LINK: %s"
## Callout when dash is pressed as Ayden: only Faith dashes.
@export var dash_blocked_label: String = "SWAP TO DASH"
## HUD duo row beside the brothers' faces (which show who waits in the link), when a
## swap is ready: active brother, then the swap key on the second line.
@export var duo_row_format: String = "%s\n[%s] swap"
## HUD duo row on cooldown: active brother, seconds left on the swap.
@export var duo_row_cooldown_format: String = "%s\nswap in %.1fs"
## HUD duo row while a boss has the link severed: active brother, hits left to relink.
@export var duo_row_severed_format: String = "%s\nlink cut: hit %d more"
## Dash row while Ayden is in the arena: only Faith dashes (ADR-0058).
@export var dash_hint_benched: String = "No dash: swap to Faith"
## Callout when the Special becomes a Link Burst (both brothers join it).
@export var link_burst_label: String = "LINK BURST!"
## Callout when Ayden breaks a warded foe's ward.
@export var foe_broken_label: String = "BROKEN!"
## Callout when a duo foe resists the brother in the arena: the brother who beats it.
@export var foe_swap_format: String = "SWAP TO %s"
## Callout when a severed link reconnects.
@export var relinked_label: String = "RELINKED!"

## Label beside the style meter. The live rank letter follows it.
@export var style_label: String = "STYLE"

## Room-clear rank banner; %s is the rank letter.
@export var room_rank_format: String = "RANK %s"

## Big word that punches in when the last enemy of a room falls (ADR-0041).
@export var room_clear_banner: String = "CLEAR"

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
@export var quick_continue_hint_pad: String = "No new Prana — press Y to continue"

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

## ADR-0052 Ascension. Main-menu button while Hard Mode is on (%d = level, %d = highest
## unlocked); pressing it steps through the unlocked levels.
@export var ascension_button_format: String = "Ascension %d / %d"
## Button text at level 0.
@export var ascension_off: String = "Ascension: off  (press to raise)"
## Shown under the Hard Mode toggle before the first Hard Mode win.
@export var ascension_locked: String = "Win on Hard Mode to unlock Ascension"
## End screen line when a win opens the next level (%d = level).
@export var ascension_unlocked_format: String = "ASCENSION %d UNLOCKED — pick it from the main menu"
## What each level adds, Ascension 1 first. The menu shows the picked level's line.
@export var ascension_level_descs: Array[String] = [
	"Enemies have 10% more HP",
	"Enemy bullets fly 8% faster",
	"Elites appear more often",
	"Bosses have 15% more HP",
	"Healing is 25% weaker",
	"One more enemy in every wave",
	"Enemies fire 10% more often, with shorter warnings",
	"Enemies and bosses have 10% more HP again",
]
## Menu line under the picked level's own change (%d = highest level below it).
@export var ascension_stacks_format: String = "· plus everything from Ascension 1–%d"
## Shard bonus line under the level list (%d = percent).
@export var ascension_shard_format: String = "+%d%% Cipher Shards on top of Hard Mode"

## Line on the core-pick screen naming the equipped Heirloom (%s = sigil title).
@export var heirloom_active_format: String = "Heirloom: %s"

@export_group("Cipher Cores (ADR-0033)")

## Core-pick screen: heading, section labels and the hint under the Prana row.
@export var core_pick_heading: String = "CHOOSE YOUR CORE"
@export var core_pick_core_label: String = "CIPHER CORE — a passive for the whole run"
@export var core_pick_prana_label: String = "CORE PRANA — anchors the centre slot. Pick one to begin."
## Core names and passives by CoreFrame id (assets/data/cores/core_roster.tres).
@export var core_titles: Dictionary = {
	"steady": "Steady Core",
	"glass": "Glass Core",
	"gale": "Gale Core",
	"echo": "Echo Core",
	"anvil": "Anvil Core",
	"kite": "Kite Core",
	"tether": "Tether Core",
}
@export var core_descs: Dictionary = {
	"steady": "No passive. Nothing to lose.",
	"glass": "+30% spell damage, but you take +25% damage.",
	"gale": "+1 dash charge and +10% move speed, but -15% spell damage.",
	"echo": "Sigil offers show 4 cards and one free reroll, but -10% spell damage.",
	"anvil": "Ayden hits +30% harder, but Faith hits -20%.",
	"kite": "Faith hits +30% harder, but Ayden hits -20%.",
	"tether": "Swap 40% sooner and LINK reaches +30% further, but -10% spell damage.",
}
## Pause build view line naming this run's Core (%s = Core name).
@export var core_active_format: String = "Core: %s"

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
## Sigil overlay reroll button (ADR-0033): priced in HP (%d), free, or refused.
@export var sigil_reroll_format: String = "Reroll  (-%d HP)"
@export var sigil_reroll_free: String = "Reroll  (free)"
@export var sigil_reroll_too_weak: String = "Reroll  (too weak)"

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
	"SEPARATION IS THE WEAPON — land hits to find each other",
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
## Comfort toggle: no fades or typewriter text, still menu backdrop (U9).
@export var settings_reduce_motion: String = "Reduce motion"
@export var settings_audio_heading: String = "Audio"
@export var settings_master: String = "Master"
@export var settings_music: String = "Music"
@export var settings_sfx: String = "SFX"
@export var settings_controls_heading: String = "Controls"
## Column headings over the key and pad buttons.
@export var settings_keyboard_column: String = "Keyboard"
@export var settings_gamepad_heading: String = "Gamepad"
## Pad column for movement, which stays on the stick.
@export var settings_pad_stick: String = "Left stick"
@export var settings_press_button: String = "Press…"
@export var settings_reset_pad: String = "Reset buttons"
## Rumble strength slider (0 % turns it off).
@export var settings_rumble: String = "Rumble"
## Names of GameSettings.REMAPPABLE actions, same order.
@export var settings_action_names: Array[String] = [
	"Move up", "Move down", "Move left", "Move right", "Dash", "Cast", "Special",
	"Swap brother",
]
@export var settings_press_key: String = "Press a key…"
@export var settings_reset_keys: String = "Reset keys"
## Under the gamepad bindings: how to cancel, and what stays fixed.
@export var settings_gamepad_note: String = "Start or Esc cancels a rebind."
@export var settings_back: String = "Back  (Esc)"

@export_group("Release")

## Version line on the main menu (%s = application/config/version).
@export var version_format: String = "v%s"

@export_group("Combat Tutorial")

## Small counter above each tutorial hint (%d = hint number, %d = total).
@export var coach_heading: String = "TIP %d / %d"

## Tutorial hints (ADR-0031), one shown at a time when it matters. Order matches
## TutorialCoach.STEPS. %s, when present, is the bound key or button for the step.
@export var coach_steps_kb: Array[String] = [
	"Arrange your Prana, then press %s to fight.",
	"Move with %s.",
	"Press %s to cast. Your grid picks the spell.",
	"Faith can dash: press %s. Ayden can't, so swap to her.",
	"3+ Prana of one type make a stronger spell.",
	"Perfect Dodge: dash (%s) right through a bullet.",
	"Perfect Cast: press %s again as the ring closes.",
	"Meter full? Press %s for your Special.",
]
@export var coach_steps_pad: Array[String] = [
	"Arrange your Prana, then press %s to fight.",
	"Move with the left stick.",
	"Press %s to cast. Your grid picks the spell.",
	"Faith can dash: press %s. Ayden can't, so swap to her.",
	"3+ Prana of one type make a stronger spell.",
	"Perfect Dodge: dash (%s) right through a bullet.",
	"Perfect Cast: press %s again as the ring closes.",
	"Meter full? Press %s for your Special.",
]

## Shown when every hint is done.
@export var coach_done: String = "Nice. You know everything. Go get them."

## Pause-menu button that turns the coach back on.
@export var coach_replay_button: String = "Replay Tutorial"

@export_group("Tutorial Room")

## Counter above each guided-room lesson (%d = lesson number, %d = total). ADR-0055.
@export var tutorial_heading: String = "TRAINING %d / %d"

## Guided first-room lessons, in TutorialRoom.STEPS order. %s, when present, is the
## bound key or button (the pad "place" line takes two: cycle, then place).
@export var tutorial_steps_kb: Array[String] = [
	"Drag a Prana from YOUR PRANA into an empty slot.",
	"Put a different Prana in Ayden's palm (left of the centre).",
	"Press %s to lock the grid and fight.",
	"Move with %s.",
	"Press %s to dash. Only Faith can dash.",
	"Press %s to cast at a training target.",
	"Dash (%s) through a shot just before it hits.",
	"Press %s to swap to Ayden.",
	"Hit a target, swap (%s), hit it again: LINK!",
	"Swap (%s) when the heart glows: RESONANCE!",
]
@export var tutorial_steps_pad: Array[String] = [
	"Pick a Prana with %s, then press %s on an empty slot.",
	"Put a different Prana in Ayden's palm (left of the centre).",
	"Press %s to lock the grid and fight.",
	"Move with the left stick.",
	"Press %s to dash. Only Faith can dash.",
	"Press %s to cast at a training target.",
	"Dash (%s) through a shot just before it hits.",
	"Press %s to swap to Ayden.",
	"Hit a target, swap (%s), hit it again: LINK!",
	"Swap (%s) when the heart glows: RESONANCE!",
]
## Smaller second line under each lesson (same order).
@export var tutorial_details: Array[String] = [
	"Matching types make a stronger spell.",
	"Each brother casts the Prana in his palm.",
	"The grid decides which spell you cast.",
	"Walk over to the training targets.",
	"You can't be hit while dashing.",
	"Your spell comes from the grid you built.",
	"A Perfect Dodge slows time and fills your Special.",
	"Ayden hits hard and can't dash. Swap back to escape.",
	"Two brothers, two elements: they react together.",
	"Swapping on the beat makes the next hit a Perfect.",
]
## Skip prompt on the lesson card (%s = key or button to hold).
@export var tutorial_skip_format: String = "Hold %s to skip training"
## Shown when the last lesson is done.
@export var tutorial_done: String = "Training complete."
## Room banner as the room's real wave arrives after the lessons.
@export var tutorial_now_real: String = "NOW FOR REAL"

@export_group("Spell Preview (prep panel)")

## Preview text before the centre slot holds a Prana.
@export var spell_preview_empty: String = "Place a Prana in the centre. It decides your spell."

## Preview title: element name, tier, max tier, hits per cast.
@export var spell_preview_title_format: String = "%s   Tier %d of %d   ·   %d-hit combo"

## What each element does as the core spell, in type_id order (0–4).
@export var prana_cast_summaries: Array[String] = [
	"Close range, high damage. Sets enemies on fire.",
	"Mid range. Blinds enemies so their shots miss.",
	"Long range. Stuns enemies.",
	"Mid range, low damage. Slows, then freezes.",
	"Close range, low damage. Heals you over time.",
]

## Two hands (ADR-0057): labels beside the grid's left and right columns.
@export var hand_ayden_label: String = "AYDEN\npower"
@export var hand_faith_label: String = "FAITH\ncontrol"
## Preview lines for the hands: bonus percent for Ayden (damage) and Faith (status time).
@export var hand_power_format: String = "Ayden's hand  +%d%% damage"
@export var hand_control_format: String = "Faith's hand  +%d%% status time"
## Appended when both hands hold the same number of Prana: the touch multiplier.
@export var hands_touch_format: String = "Hands touch  ×%.1f"

## Next-tier hint: how many more of the core element, its name, the tier reached.
@export var spell_preview_next_tier_format: String = "Add %d more %s for Tier %d"

## Shown when the core is at the highest tier.
@export var spell_preview_max_tier: String = "Highest tier reached"

## What each element adds when placed around the core, in type_id order (0–4).
@export var prana_modifier_summaries: Array[String] = [
	"Special sets enemies on fire",
	"Special blinds enemies",
	"Special arcs and stuns, longer combo window",
	"Casts chill, Special freezes",
	"Special heals you",
]

## Suffix on a modifier line when that element is at modifier tier 2.
@export var spell_preview_modifier_strong: String = "  (strong)"

## Short player-facing text per Prana Reaction id (see assets/data/reactions/).
@export var reaction_summaries: Dictionary = {
	&"REACT_THERMAL_SHOCK": "First hit on each enemy cracks for extra damage",
	&"REACT_WILDFIRE": "Burn spreads to the nearest enemy",
	&"REACT_WITCHFIRE": "Burning enemies are also blinded",
	&"REACT_DETONATE": "The first kill explodes",
	&"REACT_PERMAFROST": "You heal faster while an enemy is frozen",
	&"REACT_SHORT_CIRCUIT": "The first stun also stuns a second enemy",
	&"REACT_SIPHON": "Hits on blinded enemies heal you",
	&"REACT_SUPERCONDUCT": "Hits on slowed enemies arc to one more",
	&"REACT_SURGE": "Longer combo window, chain hits heal you",
	&"REACT_WHITEOUT": "Blinded and slowed enemies miss far more",
}

## Label in front of an active reaction line.
@export var spell_preview_reaction_label: String = "Reaction"

## Cascade line: damage multiplier of the burst after the combo.
@export var spell_preview_cascade_format: String = "Cascade: burst after the combo, %.1f× damage"

@export_group("Run Summary (end of run)")

## End-screen titles for a win and a death.
@export var summary_win_title: String = "RUN COMPLETE"
@export var summary_loss_title: String = "YOU DIED"
## Under the title: floor reached, rooms cleared.
@export var summary_subtitle_format: String = "Floor %d  ·  %d rooms cleared"
## Stat row labels.
@export var summary_time: String = "Time"
@export var summary_enemies: String = "Enemies slain"
@export var summary_best_combo: String = "Best combo"
@export var summary_bosses: String = "Bosses beaten"
@export var summary_ranks: String = "Room ranks"
## Shown in the ranks row when no room was ranked.
@export var summary_no_ranks: String = "—"
## ADR-0058: the duo's run, under the other stats.
@export var summary_swaps: String = "Swaps"
@export var summary_links: String = "Link Reactions"
@export var summary_resonances: String = "Resonances"
## Heading of the sigil list, and the text when none were taken.
@export var summary_sigils_title: String = "SIGILS THIS RUN"
@export var summary_no_sigils: String = "None this run"
## Buttons.
@export var summary_run_again: String = "Run Again  (R)"
@export var summary_main_menu: String = "Main Menu"
## Opens the beta feedback form (ADR-0045). Hidden while no form URL is set.
@export var summary_feedback: String = "Send Feedback"
## Shown under the title when the run used any Assist option (F2).
@export var summary_assist_note: String = "Assist on"

@export_group("Pause (build view)")

## Pause overlay title and buttons.
@export var pause_title: String = "PAUSED"
@export var pause_resume: String = "Resume  (Esc)"
@export var pause_restart: String = "Restart Run  (R)"
@export var pause_main_menu: String = "Main Menu"
@export var pause_quit: String = "Quit Game"
## Build card: heading, sigil heading, and text when no sigil was taken yet.
@export var pause_build_title: String = "YOUR BUILD"
@export var pause_sigils_title: String = "SIGILS"
@export var pause_no_sigils: String = "No sigils yet. Clear a room to earn one."
## One sigil line: title, stack suffix, description. %s stack suffix is empty for one stack.
@export var pause_sigil_format: String = "%s%s — %s"
@export var pause_sigil_stack_format: String = " ×%d"

@export_group("Main Menu (layout)")

## Title, tagline and the main buttons, top to bottom (Settings uses settings_button).
@export var menu_title: String = "THE LAST CIPHER"
@export var menu_subtitle: String = "Two brothers. One link."
@export var menu_play: String = "PLAY"
## ADR-0048: shown above Play when a run was saved mid-way (%d = floor, %d = room).
@export var menu_continue_format: String = "CONTINUE  (FLOOR %d, ROOM %d)"
## Banner when a saved run resumes at the start of its last room.
@export var run_resumed_banner: String = "RUN RESUMED"
@export var menu_heirlooms: String = "HEIRLOOMS"
@export var menu_quit: String = "QUIT"
## Opens the beta feedback form (ADR-0045). Hidden while no form URL is set.
@export var menu_feedback: String = "SEND FEEDBACK"
## Heirloom screen heading, shard line and back button.
@export var heirloom_screen_title: String = "HEIRLOOMS"
@export var heirloom_shards_format: String = "Cipher Shards  %d"
@export var heirloom_back: String = "Back  (Esc)"

@export_group("Button prompts (U8)")

## Control summary on the main menu and the title card: move keys, swap, cast, dash,
## special. Only Faith dashes (ADR-0058), so the dash names her.
@export var controls_format: String = "%s  Move      %s  Swap      %s  Cast      %s  Dash (Faith)      %s  Special      Enter  Confirm"
## Pad variant: swap, cast, dash and special buttons (rebindable, ADR-0031).
@export var controls_pad: String = "Stick  Move      %s  Swap      %s  Cast      %s  Dash (Faith)      %s  Special      Y  Confirm"
## Grid controls line on the title card.
@export var grid_controls_kb: String = "Arrows select a grid slot · E places · Q clears · C cycles Prana"
@export var grid_controls_pad: String = "D-pad selects a grid slot · A places · B clears · RB cycles Prana"
## Pad variants of buttons whose keyboard text names a key.
@export var pause_resume_pad: String = "Resume  (Start)"
@export var pause_restart_pad: String = "Restart Run"
@export var summary_run_again_pad: String = "Run Again"
@export var heirloom_back_pad: String = "Back  (B)"
## Names of gamepad buttons, indexed by JoyButton (A, B, X, Y, Back, Guide, Start,
## L3, R3, LB, RB). Xbox layout, matching the other pad prompts.
@export var pad_button_names: Array[String] = [
	"A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB",
]

@export_group("Spellbook (F1)")

## Menu / pause button (%d found, %d total) and the panel heading.
@export var spellbook_button_format: String = "SPELLBOOK  %d/%d"
@export var spellbook_title: String = "SPELLBOOK"
## Section tabs, in order: spells, reactions, sigils, enemies.
@export var spellbook_sections: Array[String] = ["Spells", "Reactions", "Sigils", "Enemies"]
## Locked entry title and body.
@export var spellbook_locked: String = "? ? ?"
@export var spellbook_locked_spell: String = "Put this Prana in the centre of your grid and fight to learn its spell."
@export var spellbook_locked_reaction: String = "Place two Prana next to each other to find this reaction."
@export var spellbook_locked_sigil: String = "Take this sigil after a room to learn it."
@export var spellbook_locked_enemy: String = "Defeat this enemy to learn it."
## Detail lines.
@export var spellbook_spell_core: String = "As your core"
@export var spellbook_spell_modifier: String = "Beside your core"
@export var spellbook_reaction_pair_format: String = "%s + %s"
@export var spellbook_enemy_hp_format: String = "HP %d"
@export var spellbook_tabs_hint: String = "Q / E  switch section"
@export var spellbook_tabs_hint_pad: String = "LB / RB  switch section"
@export var spellbook_back: String = "Back  (Esc)"
@export var spellbook_back_pad: String = "Back  (B)"
## Enemy kinds by GameEnums.EnemyArchetype (Seeker, Rusher, Swarmer, Boss, Shooter).
@export var spellbook_archetypes: Array[String] = ["Seeker", "Rusher", "Swarmer", "Boss", "Shooter"]
## One line per enemy type id: how it fights.
@export var spellbook_enemy_notes: Dictionary = {
	0: "Drifts toward you and fires slow spreads.",
	1: "Lines up, winds up, then charges in a straight line.",
	2: "Comes in groups and swarms your position.",
	3: "Floor 2 boss. Warps the arena between bullet waves.",
	4: "Opens rifts that fire when you stand in line.",
	5: "Floor 1 boss. Guards the vault with sweeping walls of bullets.",
	6: "Spins in place, spraying a turning spiral.",
	7: "Aims a laser, then fires along it. Step out of the line.",
	8: "Lobs shells that land where you stood.",
	9: "Weaves between others and fires crossing lines.",
	10: "Splits into smaller copies when it dies.",
	11: "Floor 3 boss. The keeper of the last cipher.",
	12: "Rings out slow double rings of frost. Slip through the gaps.",
	13: "Keeps its distance and sends seeking shots. Outturn them.",
	14: "Rears back, then looses a stacked lance. Step aside, not back.",
}

@export_group("Assist (F2)")

## Settings section heading and rows.
@export var settings_assist_heading: String = "Assist"
@export var settings_assist_enabled: String = "Assist on"
@export var settings_assist_damage: String = "Damage taken"
@export var settings_assist_speed: String = "Game speed"
@export var settings_assist_auto_dash: String = "Auto-dash out of bullets"
@export var settings_assist_note: String = "Runs with Assist on are marked on the summary."

@export_group("Records (F3)")

## Menu records line: best winning run and runs played, then one entry per boss.
@export var records_best_run_format: String = "Best run  %s"
@export var records_boss_format: String = "%s  %s"
@export var records_runs_format: String = "Runs  %d"
@export var records_none: String = "—"
## Summary lines when a record falls (assisted runs never set records).
@export var record_new_run_format: String = "New record!  Run  %s"
@export var record_new_boss_format: String = "New record!  %s  %s"

@export_group("Heirlooms by runs played (F4)")

## Heirloom button while hidden behind runs played: title, runs needed.
@export var heirloom_runs_locked_format: String = "%s\n%d runs"
## Description hint while hidden behind runs played.
@export var heirloom_hint_runs_format: String = "play %d runs to unlock"
## Run summary line when the runs played reveal an Heirloom.
@export var heirloom_revealed_format: String = "New Heirloom available:  %s"

@export_group("Readability and accessibility (ADR-0032)")

## Run summary death recap: attacker, then attacker and attack.
@export var death_by_format: String = "Killed by %s"
@export var death_by_attack_format: String = "Killed by %s  ·  %s"
@export var death_unknown: String = "The brothers fell."
## Attack names by DeathRecap.ATTACK_* id.
@export var death_attack_names: Dictionary = {
	"contact": "up close",
	"slam": "its ground slam",
	"aimed": "an aimed shot",
	"fan": "a fan of bullets",
	"ring": "a bullet ring",
	"spiral": "a bullet spiral",
	"homing": "homing bullets",
	"wave": "weaving bullets",
	"laser": "its laser",
	"mortar": "a mortar shell",
	"vent": "a burning vent",
	"closing_ring": "the closing ring",
	"sweep": "a sweeping beam",
}
## Stage hazard names by DeathRecap.HAZARD_ATTACKERS id.
@export var death_hazard_names: Dictionary = {
	"hazard_turret": "a turret",
	"hazard_sweep_laser": "a laser pylon",
	"hazard_floor_zone": "a floor vent",
	"hazard_closing_ring": "the room's edge",
}

## Pause floor map card: heading, then legend rows.
@export var map_title: String = "FLOOR MAP"
## Room type names by DungeonGraph room type (Combat, Elite, Rest, Boss).
@export var map_room_names: Array[String] = ["Combat", "Elite", "Rest", "Boss"]
## Room modifier names by RoomModifiers value (index 0 = none).
@export var map_mod_names: Array[String] = ["", "Challenge", "Cursed"]
@export var map_you_are_here: String = "You are here"
@export var map_visited: String = "Visited  (dim = not yet)"
@export var map_threats_title: String = "ENEMY ICONS"
## Threat icon names by ThreatIcon.Kind.
@export var threat_names: Array[String] = [
	"Chases you", "Charges", "Swarm", "Shoots bullets", "Laser", "Mortar", "Splits on death", "Boss",
]

## Settings rows.
@export var settings_text_size: String = "Text size"
@export var settings_bullet_outline: String = "High-contrast bullets"

## ADR-0046 Settings rows: the HUD heading, HUD scale, card opacity and run timer.
@export var settings_hud_heading: String = "HUD"
@export var settings_hud_scale: String = "HUD size"
@export var settings_hud_opacity: String = "HUD card opacity"
@export var settings_run_timer: String = "Show run timer"
## ADR-0046 corner toasts (%s = sigil title; %d = shards gained, %d = bonus shards
## this run).
@export var toast_sigil_format: String = "Sigil gained · %s"
@export var toast_shards_format: String = "+%d Cipher Shards · %d this run"
## Colour-blind Prana palette row (ADR-0047) and its choices by GameSettings.ColorMode.
@export var settings_color_mode: String = "Prana colours"
@export var settings_color_modes: Array[String] = [
	"Default", "Deuteranopia", "Protanopia", "Tritanopia",
]
