extends "res://scripts/enchant_behavior.gd"

## Prizm (Buz Asası / Arcane Asası) - bkz. EnchantDefs "prizm". İsabetler şansa bağlı olarak hedefin yerinde bir kristal
## bırakır (crystal_ice / crystal_arcane sayfası, süreli döngü - diğer oyuncular da görür). Bu silahın kristalden geçen her
## mermisi (kopyalar hariç) crystal_split kopyaya bölünüp yelpaze gibi saçılır (weapon.gd _spawn_enchant_projectile_now -
## uzak kopyalar broadcast_projectile ile). Final: kopyalar en yakın düşmana güdümlenir (ortak _homing), kristal bitince
## 6 delici şarapnel (enchant_area "blade") saçar. Kristaller sadece bu makinede sayılır (bölünme kasterin mermisinde olur).

const SPREAD := 0.5 ## kopyaların toplam yelpaze açısı (radyan)
const SHRAPNEL_RANGE := 180.0

var _crystals: Array = [] ## {pos, until, id}
var _projs: Array = []
var _next_id: int = 1


func _sheet() -> String:
	return "crystal_arcane" if weapon_key() == "arcane" else "crystal_ice"


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	_projs.append(proj)


func hit_extra(t: Node, _dmg: float, _is_primary: bool, proj: Node2D) -> void:
	if proj == null or not is_instance_valid(proj) or proj.has_meta("prizm_copy") or not is_enemy(t) or not can_act():
		return
	if randf() >= f("crystal_chance"):
		return
	var at: Vector2 = (t as Node2D).global_position + Vector2(0.0, -6.0)
	var dur: float = f("crystal_dur", 4.0)
	var size_k: float = f("crystal_size", 24.0) / 24.0
	sprite(_sheet(), at, {"loop_time": dur, "scale": size_k, "z": 8})
	_crystals.append({"pos": at, "until": Time.get_ticks_msec() + int(dur * 1000.0), "id": _next_id})
	_next_id += 1


func process_extra(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if not _crystals.is_empty():
		var keep: Array = []
		for c in _crystals:
			if now >= int(c["until"]):
				_crystal_expire(c)
			else:
				keep.append(c)
		_crystals = keep
	if _projs.is_empty():
		return
	var alive: Array = []
	for pr in _projs:
		if not is_instance_valid(pr):
			continue
		alive.append(pr)
		for c in _crystals:
			var key: String = "prizm_%d" % int(c["id"])
			if pr.has_meta(key):
				continue
			if (pr as Node2D).global_position.distance_to(Vector2(c["pos"])) <= f("crystal_size", 24.0):
				pr.set_meta(key, true)
				_split(pr, Vector2(c["pos"]))
	_projs = alive


func _split(pr: Node2D, at: Vector2) -> void:
	var dir: Vector2 = Vector2(pr.get("direction")) if "direction" in pr else Vector2.RIGHT
	var cnt: int = maxi(1, n("crystal_split", 2))
	var dmg: float = float(pr.get("damage")) * f("split_ratio", 0.5) if "damage" in pr else ap() * 0.5
	sprite("crystal_burst", at, {"scale": 0.6, "z": 9})
	for k in range(cnt):
		var off: float = 0.0 if cnt == 1 else lerpf(-SPREAD, SPREAD, float(k) / float(cnt - 1))
		var d: Vector2 = dir.rotated(off)
		## Güdüm hedefi kopya doğmadan seçilir: kimliği görünüm verisiyle gider, uzak kopya da aynı hedefe yönelir
		## (projectile.gd "home_id") - eskiden uzak ekranlarda kopyalar düz uçuyordu.
		var tgt: Node = nearest_enemy(at + d * 60.0, 260.0) if flag("split_homing") else null
		var look: Dictionary = projectile_look(pr)
		if tgt:
			look["home_id"] = int(tgt.get_meta("network_enemy_id", 0))
		var copy: Node2D = weapon.call("_spawn_enchant_projectile_now", at, d, dmg, [], look, {"prizm_copy": true})
		if copy and tgt:
			_homing.append([copy, tgt])


func _crystal_expire(c: Dictionary) -> void:
	if f("shrapnel") <= 0.0 or not can_act():
		return
	var at: Vector2 = Vector2(c["pos"])
	sprite("crystal_burst", at, {"z": 9})
	for i in range(6):
		var d: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / 6.0 + 0.3)
		area("blade", at, {"dir": d, "speed": 460.0, "range": SHRAPNEL_RANGE, "width": 12.0, "damage": ap() * f("shrapnel"),
			"sheet": _sheet() + "_shard", "sheet_scale": 1.0, "sheet_rot": d.angle() + PI * 0.5})
