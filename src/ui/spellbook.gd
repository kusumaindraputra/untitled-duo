## Spellbook — the entries of the codex (beta plan F1), built from what the player has
## discovered in MetaProgress.
##
## Four sections: Spells (one per Prana type, learned by casting it as core),
## Reactions (one per ReactionDef, learned by arming it), Sigils (the stat and
## behaviour catalog, learned by taking one) and Enemies (learned by defeating one).
## Pure and static so it is unit-testable; SpellbookPanel only draws what it returns.
class_name Spellbook
extends RefCounted

enum Section { SPELLS, REACTIONS, SIGILS, ENEMIES }

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
const _SIGILS: SigilConfig = preload("res://assets/data/sigil_config.tres")
const REACTIONS_DIR: String = "res://assets/data/reactions/"


## Every entry of [param section] in display order. Each is a Dictionary:
## { "id": Variant, "known": bool, "title": String, "subtitle": String, "body": String }.
## Locked entries carry the locked title and a hint in body.
static func entries(section: Section, p: MetaProgress) -> Array[Dictionary]:
	match section:
		Section.SPELLS:
			return _spells(p)
		Section.REACTIONS:
			return _reactions(p)
		Section.SIGILS:
			return _sigils(p)
		_:
			return _enemies(p)


## Found and total entries across all sections: Vector2i(found, total).
static func progress(p: MetaProgress) -> Vector2i:
	var found: int = 0
	var total: int = 0
	for s: int in Section.values():
		for e: Dictionary in entries(s as Section, p):
			total += 1
			if e["known"]:
				found += 1
	return Vector2i(found, total)


## Reaction resources in file-name order.
static func reaction_defs() -> Array[ReactionDef]:
	var out: Array[ReactionDef] = []
	var dir := DirAccess.open(REACTIONS_DIR)
	if dir == null:
		return out
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for f: String in files:
		# Exported builds list ".tres.remap"; load by the original name.
		var name: String = f.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var r := load(REACTIONS_DIR + name) as ReactionDef
		if r != null:
			out.append(r)
	return out


## "VaultSentinel" → "Vault Sentinel".
static func display_name(raw: String) -> String:
	var out: String = ""
	for i in raw.length():
		var c: String = raw[i]
		if i > 0 and c == c.to_upper() and c != c.to_lower() and raw[i - 1] != " ":
			out += " "
		out += c
	return out


## Discoveries in a confirmed grid: {"core": int, "reactions": Array[StringName]}.
## [param slots] holds 9 type ids or null (PranaGrid.get_slot_types()).
static func discoveries_from_grid(slots: Array) -> Dictionary:
	var out: Dictionary = {"core": -1, "reactions": [] as Array[StringName]}
	if slots.size() < 9 or slots[4] == null:
		return out
	out["core"] = int(slots[4])
	var fragments: Array = []
	fragments.resize(9)
	for i in 9:
		if slots[i] != null:
			var f := PranaFragment.new()
			f.type_id = int(slots[i])
			fragments[i] = f
	var recognition: Dictionary = CombinationResolution.compute_recognition(fragments)
	for r: Variant in recognition.get("reactions", []):
		var def := r as ReactionDef
		if def != null:
			(out["reactions"] as Array[StringName]).append(def.id)
	return out


static func _entry(id: Variant, known: bool, title: String, subtitle: String, body: String,
		locked_hint: String) -> Dictionary:
	if not known:
		return {"id": id, "known": false, "title": _COPY.spellbook_locked, "subtitle": "", "body": locked_hint}
	return {"id": id, "known": true, "title": title, "subtitle": subtitle, "body": body}


static func _type_name(id: int) -> String:
	var pt: PranaType = PranaCatalog.get_type(id)
	return pt.name if pt != null else "?"


static func _spells(p: MetaProgress) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: int in PranaCatalog.type_count():
		var cast: String = _COPY.prana_cast_summaries[t] if t < _COPY.prana_cast_summaries.size() else ""
		var mod: String = _COPY.prana_modifier_summaries[t] if t < _COPY.prana_modifier_summaries.size() else ""
		var body: String = "%s: %s\n%s: %s" % [_COPY.spellbook_spell_core, cast, _COPY.spellbook_spell_modifier, mod]
		out.append(_entry(t, p.codex_spells.has(t), _type_name(t), "", body, _COPY.spellbook_locked_spell))
	return out


static func _reactions(p: MetaProgress) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: ReactionDef in reaction_defs():
		var pair: String = _COPY.spellbook_reaction_pair_format % [_type_name(r.type_a), _type_name(r.type_b)]
		var body: String = str(_COPY.reaction_summaries.get(r.id, r.description))
		out.append(_entry(r.id, p.codex_reactions.has(r.id), r.name, pair, body, _COPY.spellbook_locked_reaction))
	return out


static func _sigils(p: MetaProgress) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s: Dictionary in _SIGILS.sigils:
		var id: StringName = StringName(s.get("id", &""))
		out.append(_entry(id, p.codex_sigils.has(id), str(s.get("title", id)), "",
			str(s.get("desc", "")), _COPY.spellbook_locked_sigil))
	return out


static func _enemies(p: MetaProgress) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Enemy type ids run 0..count-1 (EnemyCatalog._ENTRY_FILES).
	for id in EnemyCatalog.count():
		var et: EnemyType = EnemyCatalog.get_type(id)
		if et == null:
			continue
		var kind: String = _COPY.spellbook_archetypes[et.archetype] \
			if et.archetype >= 0 and et.archetype < _COPY.spellbook_archetypes.size() else ""
		var sub: String = "%s  ·  %s" % [kind, _COPY.spellbook_enemy_hp_format % et.base_hp]
		out.append(_entry(id, p.codex_enemies.has(id), display_name(et.name), sub,
			str(_COPY.spellbook_enemy_notes.get(id, "")), _COPY.spellbook_locked_enemy))
	return out
