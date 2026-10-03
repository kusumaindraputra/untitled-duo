## BalanceBotConfig — knobs for the headless balance bot (ADR-0051).
##
## The bot's play style (how it holds range, dodges and casts) and the per-screen time a
## human spends that the bot skips. Authored as tools/balance-bot/balance_bot_config.tres.
class_name BalanceBotConfig
extends Resource

@export_group("Play style")
## Spells hit in a cone along Fayde's facing. The bot closes to this share of the
## current spell's reach before it stops advancing.
@export_range(0.2, 1.0) var reach_share: float = 0.75
## Move strength toward the target once in reach (keeps facing without closing in).
@export_range(0.0, 1.0) var aim_nudge: float = 0.35
## Casts only while the target is within this angle of Fayde's facing.
@export var aim_tolerance_deg: float = 30.0
## Chance to land a mid-chain press in the Perfect window (else it waits for Normal).
@export_range(0.0, 1.0) var perfect_rate: float = 0.5
## Bullets closer than this push the bot away; closer than dash_radius it may dash.
@export var dodge_radius: float = 70.0
@export var dash_radius: float = 26.0
@export var dodge_weight: float = 1.6
## Chance per threatening frame that the bot actually dashes (a human misses some).
@export_range(0.0, 1.0) var dash_chance: float = 0.15
## Lasers and mortar shells closer than this push the bot away.
@export var hazard_radius: float = 60.0

## Moving less than stuck_px over stuck_sec while approaching counts as stuck; the bot
## then sidesteps for detour_sec.
@export var stuck_sec: float = 0.75
@export var stuck_px: float = 12.0
@export var detour_sec: float = 0.8

@export_group("Flow")
## Seconds with no enemy losing HP before a room counts as stalled (see balance_bot.gd).
@export var stall_sec: float = 20.0
## Seconds the bot waits before acting on a screen (lets the UI build).
@export var bot_ui_delay_sec: float = 0.3
## Seconds without getting closer to a door before the bot takes it directly.
@export var door_stuck_sec: float = 3.0
## A run is abandoned after this many simulated minutes.
@export var max_run_minutes: float = 45.0
## Seconds of simulated time between progress lines on stdout.
@export var log_every_sec: float = 30.0

@export_group("Human overhead")
## Extra seconds a player spends per room in the prep phase (reading, arranging Prana).
@export var human_prep_sec: float = 6.0
## Extra seconds per paused screen (sigil offer, Wayshrine, summary).
@export var human_screen_sec: float = 4.0
## Extra seconds per sigil pick (reading three cards).
@export var human_sigil_sec: float = 5.0
