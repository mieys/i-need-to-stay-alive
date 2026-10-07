extends "res://scripts/enchant_behavior.gd"

## Kırık Buz (Buz Asası, kalıcı özellik) - bkz. EnchantDefs "kirik_buz". Dondurma ortak freeze_after/freeze_dur anahtarlarıyla
## (enchant_behavior.gd _generic_hit -> freeze); burada dondurduğumuz düşmanlar kaydedilir ve DONMUŞKEN ölünce (kim öldürürse
## öldürsün: GameManager.enemy_died her peer'de gelir, kayıtlı ölü düşman o konumda mı diye bakılır) parçalanır: shatter_radius
## içindekilere saldırı gücü x shatter_ap hasar + shatter_slow yavaşlama. Final (shatter_freeze): parçaların vurduğu komşular donar.

const SHARD_SLOW_FALLBACK := 1.0
const ICE_COLOR := Color(0.55, 0.85, 1.0)
const MATCH_DIST := 8.0

var _frozen: Dictionary = {} ## düşman kimliği -> {"node", "until"}


func _on_setup() -> void:
	if not GameManager.enemy_died.is_connected(_on_enemy_died):
		GameManager.enemy_died.connect(_on_enemy_died)


func _exit_tree() -> void:
	if GameManager.enemy_died.is_connected(_on_enemy_died):
		GameManager.enemy_died.disconnect(_on_enemy_died)


func freeze(t: Node, dur: float) -> void:
	super.freeze(t, dur)
	if is_enemy(t) and t.get("is_boss") != true:
		_frozen[t.get_instance_id()] = {"node": t, "until": Time.get_ticks_msec() + int(dur * 1000.0)}
		if _frozen.size() > 120:
			_prune()


func _prune() -> void:
	var now: int = Time.get_ticks_msec()
	for id in _frozen.keys():
		var rec: Dictionary = _frozen[id]
		if now > int(rec["until"]) or not is_instance_valid(rec["node"]):
			_frozen.erase(id)


func _on_enemy_died(pos: Vector2) -> void:
	if _frozen.is_empty() or not is_instance_valid(weapon) or not can_act():
		return
	var now: int = Time.get_ticks_msec()
	for id in _frozen.keys():
		var rec: Dictionary = _frozen[id]
		var nd = rec["node"]
		if not is_instance_valid(nd):
			_frozen.erase(id)
			continue
		if nd.get("is_dead") != true or now > int(rec["until"]) + 100:
			continue
		if (nd as Node2D).global_position.distance_to(pos) > MATCH_DIST:
			continue
		_frozen.erase(id)
		_shatter(pos, nd)
		return


func _shatter(pos: Vector2, dead: Node) -> void:
	var radius: float = f("shatter_radius", 90.0)
	sprite("crystal_burst", pos, {"scale": Vector2.ONE * radius / 24.0, "z": 9})
	fx("ring", pos, {"radius": radius, "color": ICE_COLOR, "duration": 0.4})
	for e in enemies_near(pos, radius, dead):
		hit(e, ap() * f("shatter_ap", 1.0))
		if not is_enemy(e):
			continue
		e.apply_element("slow", {"pct": f("shatter_slow", 0.4), "dur": f("shatter_slow_dur", SHARD_SLOW_FALLBACK)})
		if flag("shatter_freeze"):
			freeze(e, 1.5)
