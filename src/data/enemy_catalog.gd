## EnemyCatalog — Autoload #2. Loads and serves immutable EnemyType definitions.
##
## Contract (ADR-0008, Story 002):
##   - `get_type(id)` always returns `original.duplicate_deep()` — never a direct reference.
##   - `get_active_types()` and `get_spawnable_types()` return fully-duplicated arrays.
##   - All startup guards use `push_error()`, NOT `assert()` — survives Godot 4.6 release exports.
##   - `_initialized` must be false until `_validate_all()` completes in `_ready()`.
##
## Loading strategy:
##   `.tres` files are the primary authoring format (Story 003). Until those assets exist,
##   `_load_catalog()` falls back to synthesised stubs so that startup validation passes
##   in the test harness. The stub branch becomes unreachable once Story 003 assets land
##   in res://assets/data/enemy_types/.
##
## Registration: Autoload #2 in Project Settings → AutoLoad (ADR-0002).
##   Node name in Project Settings: "EnemyCatalog". No class_name — Godot 4 rejects
##   class_name matching the Autoload node name ("hides autoload singleton" parse error).
##   Access in game code: EnemyCatalog.get_type(id)  (via Autoload path, not class_name).
##   Access in tests: preload("res://src/data/enemy_catalog.gd").new()
extends Node

# ── Constants ─────────────────────────────────────────────────────────────────

## Path to the directory that holds the four EnemyType .tres files (Story 003).
const _CATALOG_PATH: String = "res://assets/data/enemy_types/"

## Basenames of the four EnemyType .tres files authored in Story 003.
## Must match the actual filenames Story 003 creates — mismatch causes silent stub fallback.
const _ENTRY_FILES: Array[String] = [
	"enemy_drifter.tres",
	"enemy_charger.tres",
	"enemy_cluster.tres",
	"enemy_warped_warden.tres",
	"enemy_rifter.tres",
	"enemy_vault_sentinel.tres",
	# ADR-0018 bullet-hell roster — ids 6..10 follow list order so stubs line up.
	"enemy_spinner.tres",
	"enemy_sniper.tres",
	"enemy_mortar.tres",
	"enemy_weaver.tres",
	"enemy_splitter.tres",
	# ADR-0026 final boss (Floor 3), id 11.
	"enemy_cipher_keeper.tres",
	# ADR-0053 one new enemy per floor: Pulsar (F1) 12, Wisp (F2) 13, Lancer (F3) 14.
	"enemy_pulsar.tres",
	"enemy_wisp.tres",
	"enemy_lancer.tres",
]

# ── Private state ─────────────────────────────────────────────────────────────

## Set to true only after `_validate_all()` completes in `_ready()`.
## All public methods guard against reads before this flag is true.
var _initialized: bool = false

## Catalog entries keyed by EnemyType.id. Never exposed directly; always duplicated on read.
var _types: Dictionary = {}

# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	_load_catalog()
	_validate_all()
	_initialized = true


# ── Public API ────────────────────────────────────────────────────────────────

## Returns an independent deep copy of the EnemyType with the given [param id].
##
## The caller may mutate any property on the returned instance without affecting
## the catalog or other callers (ADR-0008: duplicate_deep() isolation guarantee).
##
## Returns [code]null[/code] and pushes an error in two cases:
##   - Called before [code]_ready()[/code] completes ([param _initialized] == false)
##   - [param id] is not present in the loaded catalog
func get_type(id: int) -> EnemyType:
	if not _initialized:
		push_error("EnemyCatalog.get_type() called before _ready() — check Autoload order (ADR-0002)")
		return null
	if not _types.has(id):
		push_error(
			"EnemyCatalog.get_type(): invalid ID %d (not found in catalog)" % id
		)
		return null
	return _types[id].duplicate_deep()


## Returns an independent deep copy of every EnemyType with [code]status == ACTIVE[/code].
##
## Excludes VS_SCOPE and INACTIVE entries. Each element is an isolated duplicate.
## Never includes entries with status != ACTIVE (AC-ED-12, AC-ED-13).
func get_active_types() -> Array[EnemyType]:
	if not _initialized:
		push_error("EnemyCatalog.get_active_types() called before _ready() — check Autoload order (ADR-0002)")
		return []
	var result: Array[EnemyType] = []
	for entry: EnemyType in _types.values():
		if entry.status == GameEnums.EnemyStatus.ACTIVE:
			result.append(entry.duplicate_deep())
	return result


## Returns an independent deep copy of every EnemyType that is both ACTIVE and
## has a non-null [code]wave_threat_value[/code] (i.e. is spawnable in waves).
##
## Boss-tier entries with VS_SCOPE status or null wave_threat_value are excluded (AC-ED-16).
func get_spawnable_types() -> Array[EnemyType]:
	if not _initialized:
		push_error("EnemyCatalog.get_spawnable_types() called before _ready() — check Autoload order (ADR-0002)")
		return []
	var result: Array[EnemyType] = []
	for entry: EnemyType in _types.values():
		if entry.status == GameEnums.EnemyStatus.ACTIVE and entry.wave_threat_value != null:
			result.append(entry.duplicate_deep())
	return result


## Returns the total number of EnemyType entries in the catalog (all statuses included).
func count() -> int:
	if not _initialized:
		push_error("EnemyCatalog.count() called before _ready() — check Autoload order (ADR-0002)")
		return 0
	return _types.size()


# ── Private methods ───────────────────────────────────────────────────────────

## Loads EnemyType resources from [constant _CATALOG_PATH].
##
## Falls back to synthesised placeholder stubs when the .tres files have not yet
## been authored (pre-Story-003). Stubs carry valid non-default field values so that
## startup validation passes in the test harness without requiring real data assets.
func _load_catalog() -> void:
	_types.clear()

	var loaded_any: bool = false
	for i: int in range(_ENTRY_FILES.size()):
		var path: String = _CATALOG_PATH + _ENTRY_FILES[i]
		if ResourceLoader.exists(path):
			var res: Resource = ResourceLoader.load(path)
			if res is EnemyType:
				var et: EnemyType = res as EnemyType
				_types[et.id] = et
				loaded_any = true
			else:
				push_error(
					"EnemyCatalog._load_catalog(): resource at '%s' is not an EnemyType" % path
				)
				var stub: EnemyType = _make_stub(i)
				_types[stub.id] = stub
		else:
			# .tres not authored yet — insert a runtime stub (pre-Story-003 path).
			var stub: EnemyType = _make_stub(i)
			_types[stub.id] = stub

	if not loaded_any:
		push_error(
			"EnemyCatalog._load_catalog(): no .tres files found in '%s'. "
			% _CATALOG_PATH
			+ "Stubs are active. Author EnemyType assets in Story 003."
		)


## Creates a minimal EnemyType stub for index [param index] with valid non-default
## field values so that startup validation passes in test and editor contexts before Story 003.
func _make_stub(index: int) -> EnemyType:
	var stub: EnemyType = EnemyType.new()
	stub.id = index
	stub.prana_affiliation = GameEnums.DamageClass.NONE
	stub.base_hp = 10
	stub.base_damage = 1.0
	stub.base_move_speed = 60.0
	stub.status = GameEnums.EnemyStatus.ACTIVE
	stub.wave_threat_value = 1
	# Per-archetype differentiation — colour + stat tuning per enemy role.
	match index:
		0:  # Drifter — steady pursuer
			stub.name = "Drifter"
			stub.archetype = GameEnums.EnemyArchetype.SEEKER
			stub.debug_color = Color(1.0, 0.2, 0.2)      # red
			stub.base_move_speed = 60.0
		1:  # Charger — fast rusher
			stub.name = "Charger"
			stub.archetype = GameEnums.EnemyArchetype.RUSHER
			stub.debug_color = Color(1.0, 0.5, 0.0)      # orange
			stub.base_move_speed = 100.0
			stub.base_damage = 2.0
		2:  # Cluster — weak swarmer
			stub.name = "Cluster"
			stub.archetype = GameEnums.EnemyArchetype.SWARMER
			stub.debug_color = Color(1.0, 0.9, 0.1)      # yellow
			stub.base_hp = 5
			stub.base_move_speed = 80.0
			stub.base_damage = 0.5
		3:  # Warped Warden — boss
			stub.name = "WarpedWarden"
			stub.archetype = GameEnums.EnemyArchetype.BOSS
			stub.debug_color = Color(0.6, 0.1, 0.8)      # purple
			stub.base_hp = 50
			stub.base_move_speed = 40.0
			stub.base_damage = 3.0
		4:  # Rifter — ranged shooter
			stub.name = "Rifter"
			stub.archetype = GameEnums.EnemyArchetype.SHOOTER
			stub.debug_color = Color(0.2, 0.4, 1.0)      # blue
			stub.base_hp = 8
			stub.base_move_speed = 35.0
			stub.base_damage = 1.5
		5:  # Vault Sentinel — boss
			stub.name = "VaultSentinel"
			stub.archetype = GameEnums.EnemyArchetype.BOSS
			stub.debug_color = Color(0.4, 0.0, 0.8)      # deep purple
			stub.base_hp = 250
			stub.base_move_speed = 65.0
			stub.base_damage = 25.0
			stub.wave_threat_value = 20
			stub.base_scale = 2.5
		_:
			stub.name = "EnemyStub_%d" % index
			stub.archetype = GameEnums.EnemyArchetype.SEEKER
			stub.debug_color = Color.WHITE
	return stub


## Validates all loaded EnemyType entries and pushes errors for any violations.
##
## Uses `push_error()` throughout — logs to the engine error stream in both debug
## and release builds. Does NOT crash; validation continues past corrupt entries
## (ADR-0008 startup validation — non-blocking).
##
## Checks per entry:
##   - id >= 0 (negative IDs are invalid)
##   - name is non-empty
##   - archetype is within the EnemyArchetype enum range
##   - Advisory: if status == ACTIVE, wave_threat_value should be non-null
func _validate_all() -> void:
	var archetype_min: int = GameEnums.EnemyArchetype.SEEKER
	var archetype_max: int = GameEnums.EnemyArchetype.SHOOTER

	for entry: EnemyType in _types.values():
		if entry == null:
			push_error("EnemyCatalog._validate_all(): catalog entry is null")
			continue

		if entry.id < 0:
			push_error(
				"EnemyCatalog._validate_all(): entry has invalid id %d (must be >= 0)" % entry.id
			)

		if entry.name.is_empty():
			push_error(
				"EnemyCatalog._validate_all(): entry %d has empty name" % entry.id
			)

		if entry.archetype < archetype_min or entry.archetype > archetype_max:
			push_error(
				"EnemyCatalog._validate_all(): entry %d ('%s') has invalid archetype %d"
				% [entry.id, entry.name, entry.archetype]
			)

		if entry.status == GameEnums.EnemyStatus.ACTIVE and entry.wave_threat_value == null:
			push_error(
				"EnemyCatalog._validate_all(): ACTIVE entry %d ('%s') has null wave_threat_value — "
				% [entry.id, entry.name]
				+ "set a threat value or change status to VS_SCOPE"
			)
