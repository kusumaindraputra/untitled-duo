## audio_event_data.gd — Per-event audio descriptor resource.
## Consumed by AudioSystem.play_event() and AudioSystem.play_stinger() (ADR-0012).
## Authored by the audio-director and serialised into AudioEventRegistry.tres.
class_name AudioEventData
extends Resource

## AudioStream asset. Null = silent placeholder — AudioSystem plays nothing but does not crash.
@export var stream: AudioStream
## Target bus. BUS_SFX = pool (PAUSABLE); BUS_UI = dedicated player (ALWAYS).
## AMB events must NOT use play_event() — route via play_ambient() instead.
@export var bus: StringName = &"SFX"
## Priority tier: 0=LOW, 1=NORMAL, 2=HIGH. Out-of-range values clamped to NORMAL at registration.
@export var priority: int = 1
## Music ducking depth applied while a stinger plays on this event (dB).
@export var duck_depth_db: float = -6.0
## Time to restore music volume after stinger completes (seconds).
@export var restore_duration_sec: float = 0.5
## Stinger priority class: 0=COMBAT, 1=NARRATIVE. Used by Story 006 stinger API.
@export var stinger_priority: int = 0
## Minimum real seconds between two plays of this event. Calls inside the window are
## dropped, so a 40-bullet ring or a burst of graze ticks reads as one sound, not a
## wall of noise that evicts every other SFX from the pool. 0 = no throttle.
@export var min_interval_sec: float = 0.0
## Random pitch spread per play: pitch_scale is drawn from 1.0 ± pitch_jitter.
## Keeps rapid repeats (bullets, orbs) from sounding machine-gunned. 0 = fixed pitch.
@export_range(0.0, 0.5) var pitch_jitter: float = 0.0
## Per-event gain applied to the pool player (dB). Lets busy cues sit under the mix.
@export var volume_db: float = 0.0
