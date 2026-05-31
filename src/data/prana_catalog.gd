## PranaCatalog — Autoload #1. Loads and serves immutable PranaType definitions.
##
## Contract (ADR-0008):
##   - `get_type(id)` always returns `original.duplicate_deep()` — never a direct reference.
##   - `get_all_types()` returns a fully-duplicated array; mutations are invisible to the catalog.
##   - All startup guards use `push_error()`, NOT `assert()` — survives Godot 4.6 release exports.
##   - `_initialized` must be false until `_validate_all()` completes in `_ready()`.
##
## Loading strategy (AC-2 / ImageTexture):
##   `.tres` files are the primary authoring format (Story 004). Until those assets exist,
##   `_load_types()` falls back to synthesised stubs with placeholder ImageTexture icons
##   and an empty AudioStreamWAV so that startup validation passes in the test harness.
##   The stub branch executes when .tres files are absent; it becomes unreachable once
##   Story 004 assets land in res://assets/data/prana_types/.
##
## Registration: Autoload #1 in Project Settings → AutoLoad (ADR-0002).
##   Node name in Project Settings: "PranaCatalog". No class_name — Godot 4 rejects
##   class_name matching the Autoload node name ("hides autoload singleton" parse error).
##   Access in game code: PranaCatalog.get_type(id)  (via Autoload path, not class_name).
##   Access in tests: preload("res://src/data/prana_catalog.gd").new()
extends Node

# ── Constants ─────────────────────────────────────────────────────────────────

## Path to the directory that holds the five PranaType .tres files (Story 004).
const _TYPES_DIR: String = "res://assets/data/prana_types/"

## Ordered list of .tres basenames. ID corresponds to array index.
const _TYPE_FILES: Array[String] = [
	"prana_fire.tres",
	"prana_shadow.tres",
	"prana_lightning.tres",
	"prana_ice.tres",
	"prana_nature.tres",
]

# ── Private state ─────────────────────────────────────────────────────────────

## Set to true only after `_validate_all()` completes in `_ready()`.
## All public methods guard against reads before this flag is true.
var _initialized: bool = false

## Catalog entries indexed by id. Never exposed directly; always duplicated on read.
var _types: Array[PranaType] = []

# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	_load_types()
	_validate_all()
	_initialized = true


# ── Public API ────────────────────────────────────────────────────────────────

## Returns an independent deep copy of the PranaType with the given [param id].
##
## The caller may mutate any property on the returned instance without affecting
## the catalog or other callers (ADR-0008: duplicate_deep() isolation guarantee).
##
## Returns [code]null[/code] and pushes an error in two cases:
##   - Called before [code]_ready()[/code] completes ([param _initialized] == false)
##   - [param id] is out of bounds for the loaded catalog
func get_type(id: int) -> PranaType:
	if not _initialized:
		push_error("PranaCatalog.get_type() called before _ready() — check Autoload order (ADR-0002)")
		return null
	if id < 0 or id >= _types.size():
		push_error(
			"PranaCatalog.get_type(): invalid ID %d (catalog has %d types)" % [id, _types.size()]
		)
		return null
	return _types[id].duplicate_deep()


## Returns an independent deep copy of every PranaType in catalog order.
##
## Each element is an isolated duplicate; mutations are invisible to the catalog.
## Callers that need a snapshot of all types for combo resolution or UI population
## should call this once and cache the result, not call get_type() in a loop per frame.
func get_all_types() -> Array[PranaType]:
	if not _initialized:
		push_error("PranaCatalog.get_all_types() called before _ready() — check Autoload order (ADR-0002)")
		return []
	var result: Array[PranaType] = []
	for t: PranaType in _types:
		result.append(t.duplicate_deep())
	return result


## Returns the number of PranaType entries in the catalog.
##
## Valid IDs are in the range [code][0, count())[/code].
func count() -> int:
	return _types.size()


# ── Private methods ───────────────────────────────────────────────────────────

## Loads PranaType resources from [constant _TYPES_DIR].
##
## Falls back to synthesised placeholder stubs when the .tres files have not yet
## been authored (pre-Story-004). Stubs use ImageTexture icons so that AC-2
## validation (icon != null) is satisfied without requiring real art assets.
func _load_types() -> void:
	_types.clear()

	var loaded_any: bool = false
	for i: int in range(_TYPE_FILES.size()):
		var path: String = _TYPES_DIR + _TYPE_FILES[i]
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path)
			if res is PranaType:
				_types.append(res as PranaType)
				loaded_any = true
			else:
				push_error(
					"PranaCatalog._load_types(): resource at '%s' is not a PranaType" % path
				)
				_types.append(_make_stub(i))
		else:
			# .tres not authored yet — insert a runtime stub (pre-Story-004 path).
			_types.append(_make_stub(i))

	if not loaded_any:
		push_error(
			"PranaCatalog._load_types(): no .tres files found in '%s'. "
			% _TYPES_DIR
			+ "Stubs are active. Author PranaType assets in Story 004."
		)


## Creates a minimal PranaType stub for index [param index] with non-null asset fields
## so that startup validation passes in test and editor contexts before Story 004.
##
## icon: [ImageTexture] from a 1×1 white pixel — satisfies non-null icon check without
## requiring any file on disk (AC-2 strategy approved 2026-05-30).
## audio_signature: empty [AudioStreamWAV] — satisfies non-null audio check without
## requiring any audio asset on disk.
func _make_stub(index: int) -> PranaType:
	var stub: PranaType = PranaType.new()
	stub.id = index
	stub.name = "Prana_%d_stub" % index
	stub.element = "stub"
	stub.semantic_identity = "Placeholder — author in Story 004"
	stub.base_damage_modifier = 1.0

	# 1×1 white ImageTexture — smallest valid Texture2D for the non-null icon check.
	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	stub.icon = ImageTexture.create_from_image(img)

	# Empty AudioStreamWAV — smallest valid AudioStream for the non-null audio check.
	stub.audio_signature = AudioStreamWAV.new()

	return stub


## Validates all loaded PranaType entries and pushes errors for any violations.
##
## Uses `push_error()` throughout — logs to the engine error stream in both debug
## and release builds. Does NOT crash; the catalog continues loading remaining
## valid types even when one entry is malformed (ADR-0008 startup validation).
func _validate_all() -> void:
	for expected_id: int in range(_types.size()):
		var t: PranaType = _types[expected_id]
		if t == null:
			push_error("PranaCatalog._validate_all(): type at index %d is null" % expected_id)
			continue
		if t.id != expected_id:
			push_error(
				"PranaCatalog._validate_all(): type at index %d has wrong id %d"
				% [expected_id, t.id]
			)
		if t.base_damage_modifier <= 0.0:
			push_error(
				"PranaCatalog._validate_all(): type %d ('%s') has base_damage_modifier <= 0 (%f)"
				% [t.id, t.name, t.base_damage_modifier]
			)
		if t.name.is_empty():
			push_error(
				"PranaCatalog._validate_all(): type %d has empty name" % t.id
			)
		if t.audio_signature == null:
			push_error(
				"PranaCatalog._validate_all(): type %d ('%s') has null audio_signature"
				% [t.id, t.name]
			)
		if t.icon == null:
			push_error(
				"PranaCatalog._validate_all(): type %d ('%s') has null icon" % [t.id, t.name]
			)
