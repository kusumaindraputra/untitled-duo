## HudToastTuning — timings and layout of the corner HUD toasts (ADR-0046).
##
## Authored as assets/data/hud_toast_tuning.tres and read by HudToaster through a
## preload const. Sizes are in HUD px at 100 % HUD scale.
class_name HudToastTuning
extends Resource

## Seconds a toast stays fully visible before it fades.
@export var hold_sec: float = 2.6
## Seconds of the slide-in and of the fade-out.
@export var in_sec: float = 0.18
@export var out_sec: float = 0.4
## How far a toast slides in from the left edge, in px (none with Reduce motion).
@export var slide_px: float = 18.0
## Toasts shown at once; later ones wait in a queue.
@export var max_visible: int = 3
## Longest the queue may grow; older queued toasts are dropped beyond it.
@export var max_queued: int = 6
## Gap from the screen corner and between stacked toasts, in px.
@export var margin: float = 12.0
@export var gap: float = 6.0
## Toast text size before the Text size setting scales it.
@export var font_size: int = 16
