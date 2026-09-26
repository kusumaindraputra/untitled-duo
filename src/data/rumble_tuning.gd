## RumbleTuning — data-driven gamepad rumble strengths (ADR-0031).
##
## Authored as assets/data/rumble_tuning.tres and read by Rumble through a preload
## const. Motor strengths are 0–1 before the player's Rumble setting scales them.
class_name RumbleTuning
extends Resource

@export_group("Impacts")

## Camera trauma below this makes no rumble (small nudges stay silent in the hands).
@export var min_trauma: float = 0.15
## Strong (low-frequency) motor per unit of camera trauma.
@export var trauma_strong: float = 0.9
## Weak (high-frequency) motor per unit of camera trauma.
@export var trauma_weak: float = 0.5
## Pulse length at trauma 0 and at trauma 1, in seconds.
@export var trauma_min_sec: float = 0.08
@export var trauma_max_sec: float = 0.35

@export_group("Moves")

## Short, light buzz on a Perfect Dodge.
@export var perfect_dodge_weak: float = 0.6
@export var perfect_dodge_strong: float = 0.0
@export var perfect_dodge_sec: float = 0.1
## Heavier thump when the Special fires.
@export var special_weak: float = 0.4
@export var special_strong: float = 0.8
@export var special_sec: float = 0.25
