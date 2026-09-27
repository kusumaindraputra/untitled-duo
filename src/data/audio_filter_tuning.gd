## AudioFilterTuning — data-driven low-pass "muffle" for pause and critical HP (ADR-0044).
##
## Authored as assets/data/audio_filter_tuning.tres and read by AudioSystem through a
## preload const. The filter sits on the buses in [member buses]; the UI bus stays
## dry so pause-menu clicks remain crisp.
class_name AudioFilterTuning
extends Resource

## Master switch. When false, AudioSystem never engages the filter.
@export var enabled: bool = true

## Buses that receive the low-pass filter. UI is left out on purpose.
@export var buses: Array[StringName] = [&"Music", &"SFX", &"AMB"]

@export_group("Cutoff")

## Cutoff while nothing muffles the mix. At this value the filter is bypassed entirely.
@export_range(1000.0, 22050.0, 10.0, "suffix:Hz") var open_cutoff_hz: float = 20500.0
## Cutoff while the game is paused. Low = heavily muffled, "the world is on hold".
@export_range(100.0, 22050.0, 10.0, "suffix:Hz") var pause_cutoff_hz: float = 700.0
## Cutoff while Fayde is in the DESPERATE HP zone. Milder than pause so combat stays readable.
@export_range(100.0, 22050.0, 10.0, "suffix:Hz") var critical_cutoff_hz: float = 2200.0
## Filter resonance (Q). 0.5 is flat; higher adds a slight peak at the cutoff.
@export_range(0.1, 1.0, 0.01) var resonance: float = 0.6

@export_group("Timing")

## Seconds to sweep the cutoff down when a muffle engages.
@export_range(0.0, 2.0, 0.01, "suffix:s") var engage_sec: float = 0.2
## Seconds to sweep the cutoff back up when a muffle releases.
@export_range(0.0, 2.0, 0.01, "suffix:s") var release_sec: float = 0.45


## Returns the cutoff the filter should settle on for the given muffle sources.
## The darker (lower) source wins when both are active; neither returns [member open_cutoff_hz].
func target_cutoff(paused: bool, critical: bool) -> float:
	var cutoff: float = open_cutoff_hz
	if paused:
		cutoff = minf(cutoff, pause_cutoff_hz)
	if critical:
		cutoff = minf(cutoff, critical_cutoff_hz)
	return cutoff
