## HazardSpec — data for one environmental hazard in a room (ADR-0020).
##
## Room templates list hazards in RoomTemplate.hazards. IsometricRoom builds one
## StageHazard node per spec. Every hazard is idle during preparation and only
## runs while GameStateManager is in combat, so a room clear is always safe.
##
## GDD: design/gdd/stage-layout.md
class_name HazardSpec
extends Resource

enum Kind {
	TURRET = 0,        ## Static emplacement that fires a BulletPattern at Fayde.
	SWEEP_LASER = 1,   ## Pylon with rotating beam arms; pillars block the beam.
	FLOOR_ZONE = 2,    ## Floor vent that cycles off → telegraph → burning.
	CLOSING_RING = 3,  ## Danger band that closes in from the room edge over time.
}

@export var kind: Kind = Kind.TURRET

## Room-local position. Ignored when random_position is true (and for CLOSING_RING).
@export var position: Vector2 = Vector2.ZERO

## Pick a free interior floor tile instead of [member position].
@export var random_position: bool = false

## Damage per hit on Fayde. CONTACT source, so dash i-frames and post-hit grace apply.
@export var damage: float = 8.0

## Main hazard colour (beam, vent glow, ring band).
@export var color: Color = Color(1.0, 0.35, 0.2, 1.0)

@export_group("Turret")
## Pattern the turret fires. Its interval, shape and bullets work as for enemies.
@export var pattern: BulletPattern = null

@export_group("Sweep Laser")
## Number of beam arms, spread evenly around the pylon.
@export var arm_count: int = 2
## Arm length in pixels (before pillars cut it short).
@export var arm_length: float = 320.0
## Rotation speed in degrees per second. Negative spins counter-clockwise.
@export var rotation_deg_per_sec: float = 38.0
## Beams start this far from the pylon (px). Lets a pylon sit inside a walled core
## (RING layout) with its beams starting at the core's rim.
@export var arm_inner_radius: float = 0.0
## Beams stop at arena walls. Turn off for a pylon inside a walled core, whose own
## rim would otherwise block every beam.
@export var stop_at_walls: bool = true
## Beam half-width in pixels.
@export var beam_width: float = 5.0
## Seconds of harmless telegraph line after combat starts.
@export var warmup_sec: float = 1.5

@export_group("Floor Zone")
## Vent radius in screen pixels (iso ellipse: vertical radius is half).
@export var zone_radius: float = 56.0
## Seconds the vent is dormant each cycle.
@export var off_sec: float = 2.2
## Seconds of warning glow before it burns.
@export var telegraph_sec: float = 0.9
## Seconds the vent burns.
@export var on_sec: float = 1.3
## Cycle offset in seconds, so several vents in one room take turns.
@export var phase_offset: float = 0.0

@export_group("Closing Ring")
## Seconds after combat starts before the ring moves.
@export var ring_delay_sec: float = 6.0
## Seconds the ring takes to reach its minimum size.
@export var ring_close_sec: float = 24.0
## Safe area at the start, as a fraction of the room diamond.
@export var ring_start_scale: float = 0.95
## Safe area at the end, as a fraction of the room diamond.
@export var ring_min_scale: float = 0.45
