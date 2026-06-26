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
