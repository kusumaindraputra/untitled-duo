## death_recap_test.gd — What killed Fayde, on the run summary (ADR-0032).
##
## Coverage:
##   DR-01: bullet patterns map to attacks by kind, then motion, then shape
##   DR-02: hazards map to their own attacker and attack ids
##   DR-03: the recap line names attacker and attack; unknown attack or cause falls back
##   DR-04: HealthAndDamage keeps the cause of the last hit that hurt Fayde
##   DR-05: a hit that deals no damage (i-frames) does not replace the cause
##   DR-06: the run summary shows the recap on a loss only
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const HealthAndDamageScript = preload("res://src/systems/health_and_damage.gd")


func _pattern(kind: BulletPattern.Kind, shape: BulletPattern.Shape,
		motion: BulletPattern.Motion = BulletPattern.Motion.STRAIGHT) -> BulletPattern:
	var p := BulletPattern.new()
	p.kind = kind
	p.shape = shape
	p.motion = motion
	return p


func _make_hd() -> Node:
	var hd: Node = HealthAndDamageScript.new()
	hd.set_process(false)
	return hd


func _make_fayde() -> Node:
	var node := Node.new()
	node.add_to_group(&"player")
	return node


# ── DR-01 ─────────────────────────────────────────────────────────────────────

func test_attack_for_pattern_kind_then_motion_then_shape() -> void:
	var B := BulletPattern
	assert_str(String(DeathRecap.attack_for_pattern(_pattern(B.Kind.LASER, B.Shape.RING)))).is_equal("laser")
	assert_str(String(DeathRecap.attack_for_pattern(_pattern(B.Kind.MORTAR, B.Shape.FAN)))).is_equal("mortar")
	assert_str(String(DeathRecap.attack_for_pattern(
		_pattern(B.Kind.BULLETS, B.Shape.RING, B.Motion.HOMING)))).is_equal("homing")
	assert_str(String(DeathRecap.attack_for_pattern(
		_pattern(B.Kind.BULLETS, B.Shape.FAN, B.Motion.SINE)))).is_equal("wave")
	assert_str(String(DeathRecap.attack_for_pattern(_pattern(B.Kind.BULLETS, B.Shape.FAN)))).is_equal("fan")
	assert_str(String(DeathRecap.attack_for_pattern(_pattern(B.Kind.BULLETS, B.Shape.RING)))).is_equal("ring")
	assert_str(String(DeathRecap.attack_for_pattern(_pattern(B.Kind.BULLETS, B.Shape.SPIRAL)))).is_equal("spiral")
	assert_str(String(DeathRecap.attack_for_pattern(_pattern(B.Kind.BULLETS, B.Shape.AIMED)))).is_equal("aimed")
	assert_str(String(DeathRecap.attack_for_pattern(null))).is_equal("aimed")


func test_every_attack_id_has_player_text() -> void:
	for id: StringName in [DeathRecap.ATTACK_CONTACT, DeathRecap.ATTACK_SLAM, DeathRecap.ATTACK_AIMED,
			DeathRecap.ATTACK_FAN, DeathRecap.ATTACK_RING, DeathRecap.ATTACK_SPIRAL,
			DeathRecap.ATTACK_HOMING, DeathRecap.ATTACK_WAVE, DeathRecap.ATTACK_LASER,
			DeathRecap.ATTACK_MORTAR, DeathRecap.ATTACK_VENT, DeathRecap.ATTACK_CLOSING_RING,
			DeathRecap.ATTACK_SWEEP]:
		assert_bool(COPY.death_attack_names.has(String(id))).override_failure_message(String(id)).is_true()


# ── DR-02 ─────────────────────────────────────────────────────────────────────

func test_hazards_have_attacker_and_attack() -> void:
	assert_str(DeathRecap.hazard_attacker(HazardSpec.Kind.FLOOR_ZONE)).is_equal("hazard_floor_zone")
	assert_str(String(DeathRecap.attack_for_hazard(HazardSpec.Kind.FLOOR_ZONE))).is_equal("vent")
	assert_str(String(DeathRecap.attack_for_hazard(HazardSpec.Kind.SWEEP_LASER))).is_equal("sweep")
	assert_str(String(DeathRecap.attack_for_hazard(HazardSpec.Kind.CLOSING_RING))).is_equal("closing_ring")
	for id: StringName in DeathRecap.HAZARD_ATTACKERS:
		assert_bool(COPY.death_hazard_names.has(String(id))).is_true()


# ── DR-03 ─────────────────────────────────────────────────────────────────────

func test_line_names_attacker_and_attack() -> void:
	var line: String = DeathRecap.line(DeathRecap.cause("VaultSentinel", DeathRecap.ATTACK_SPIRAL), COPY)

	assert_str(line).is_equal(COPY.death_by_attack_format % ["Vault Sentinel", COPY.death_attack_names["spiral"]])


func test_line_uses_hazard_name() -> void:
	var line: String = DeathRecap.line(DeathRecap.cause("hazard_floor_zone", DeathRecap.ATTACK_VENT), COPY)

	assert_str(line).contains(str(COPY.death_hazard_names["hazard_floor_zone"]))


func test_line_falls_back_without_attack_or_cause() -> void:
	assert_str(DeathRecap.line({"attacker": "Charger", "attack": &"nope"}, COPY)).is_equal(COPY.death_by_format % "Charger")
	assert_str(DeathRecap.line({}, COPY)).is_equal(COPY.death_unknown)


# ── DR-04 / DR-05 ─────────────────────────────────────────────────────────────

func test_health_and_damage_keeps_last_cause() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()

	hd.apply_damage(fayde, 5.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT,
		DeathRecap.cause("Charger", DeathRecap.ATTACK_CONTACT))
	hd.apply_damage(fayde, 5.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT,
		DeathRecap.cause("Sniper", DeathRecap.ATTACK_LASER))

	assert_str(str(hd.last_player_hit["attacker"])).is_equal("Sniper")
	assert_str(String(hd.last_player_hit["attack"])).is_equal("laser")
	fayde.free()
	hd.free()


func test_blocked_hit_keeps_previous_cause() -> void:
	var hd: Node = _make_hd()
	var fayde: Node = _make_fayde()
	hd.apply_damage(fayde, 5.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT,
		DeathRecap.cause("Charger", DeathRecap.ATTACK_CONTACT))

	# The first CONTACT hit armed i-frames, so this one deals nothing.
	hd.apply_damage(fayde, 5.0, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT,
		DeathRecap.cause("Drifter", DeathRecap.ATTACK_FAN))

	assert_str(str(hd.last_player_hit["attacker"])).is_equal("Charger")
	fayde.free()
	hd.free()


# ── DR-06 ─────────────────────────────────────────────────────────────────────

func test_summary_shows_recap_on_loss_only() -> void:
	var line: String = DeathRecap.line(DeathRecap.cause("Mortar", DeathRecap.ATTACK_MORTAR), COPY)
	var loss := RunSummaryPanel.new()
	add_child(loss)
	loss.setup({"win": false, "death": line})
	var win := RunSummaryPanel.new()
	add_child(win)
	win.setup({"win": true, "death": line})

	assert_object(loss.death_label).is_not_null()
	assert_str(loss.death_label.text).is_equal(line)
	assert_object(win.death_label).is_null()
	remove_child(loss)
	loss.free()
	remove_child(win)
	win.free()
