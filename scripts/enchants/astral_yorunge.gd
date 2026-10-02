extends "res://scripts/enchant_behavior.gd"

## Astral Yörünge (Bumerang / Arcane Asası) - bkz. EnchantDefs "astral_yorunge". İsabet eden mermi yörüngeye girer:
## sahibinin çevresinde dönen bir nesne (enchant_area "orbit_blade" + astral_orb sayfası, sahibini izler - diğer oyuncular
## kuklanın çevresinde görür), değdiğine silah hasarının %40'ı. Bumerang yörüngeye girince geri dönmez (mermi "yakalanmış"
## sayılır, silah yeniden atabilir); Arcane mermisi zaten isabette biter.
##  - Seviye 2: 2 nesne + yörünge çemberi düşman mermilerini yok eder (player.gd set_enchant_ward).
##  - Seviye 3: %40 hızlı döner + geri iter.  Seviye 4: 3 nesne; 3 nesne dönerken +%15 hareket hızı ve %10 hasar azaltma.
##  - Final: 3 nesne birleşip 5 sn kozmik disk (enchant_area "cosmic" + cosmic_disk sayfası): çeker, 0,3 sn'de bir %90,
##    bitince dışa patlar. Birleşince nesneler her yerde anında kaybolur ("id" + enchant_fx "area_end").

const ORBIT_RADIUS := 62.0
const ORBIT_SPEED := 3.2
const WARD_REFRESH := 0.3
const DISK_RADIUS := 90.0
const DISK_TIME := 5.0

var _orbiters: Array = [] ## {id, until}
var _next: int = 1
var _ward_t: float = 0.0
var _disk_until_msec: int = 0


func _alive() -> Array:
	var now: int = Time.get_ticks_msec()
	var out: Array = []
	for o in _orbiters:
		if now < int(o["until"]):
			out.append(o)
	_orbiters = out
	return out


func hit_extra(_t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj == null or not is_instance_valid(proj) or proj.has_meta("astral_done") or not can_act():
		return
	if Time.get_ticks_msec() < _disk_until_msec:
		return
	var alive: Array = _alive()
	if alive.size() >= maxi(1, n("orbit_max", 1)):
		return
	proj.set_meta("astral_done", true)
	var pl: Node2D = owner_player() as Node2D
	if pl == null:
		return
	var id: String = "astral_%d_%d_%d" % [my_peer(), weapon.get_instance_id(), _next]
	_next += 1
	var dur: float = f("orbit_dur", 3.0)
	area("orbit_blade", pl.global_position, {"id": id, "follow": true, "orbit_radius": ORBIT_RADIUS,
		"orbit_speed": ORBIT_SPEED * f("orbit_speed", 1.0), "angle": TAU * float(alive.size()) / 3.0, "touch": 24.0,
		"damage": wdmg() * f("orbit_dmg", 0.4), "knock": f("orbit_knock"), "duration": dur,
		"sheet": "astral_orb", "sheet_scale": 1.0, "color": Color(0.75, 0.55, 1.0)})
	_orbiters.append({"id": id, "until": Time.get_ticks_msec() + int(dur * 1000.0)})
	## Bumerang geri dönmez: yakalanmış sayılır (weapon.gd'nin "havadaki mermi bitti" bildirimi) - fizik sinyali içindeyiz.
	if proj.has_method("_finish"):
		proj.call_deferred("_finish")
	if f("cosmic") > 0.0 and _alive().size() >= 3:
		_merge()


func _merge() -> void:
	var pl: Node2D = owner_player() as Node2D
	if pl == null:
		return
	for o in _orbiters:
		fx("area_end", pl.global_position, {"id": str(o["id"])})
	_orbiters.clear()
	_disk_until_msec = Time.get_ticks_msec() + int(DISK_TIME * 1000.0)
	area("cosmic", pl.global_position, {"follow": true, "radius": DISK_RADIUS, "tick": 0.3, "damage": wdmg() * f("cosmic"),
		"duration": DISK_TIME, "sheet": "cosmic_disk", "sheet_scale": DISK_RADIUS / (74.0 * 1.212)})


func process_extra(delta: float) -> void:
	_ward_t -= delta
	if _ward_t > 0.0:
		return
	_ward_t = WARD_REFRESH
	var count: int = _alive().size()
	if count <= 0:
		return
	if flag("orbit_ward"):
		set_ward(ORBIT_RADIUS + 16.0, WARD_REFRESH + 0.15)
	if flag("orbit_full_buff") and count >= 3:
		## Evrim buff kanalı (player.gd _evo_move_bonus "speed") - apply_temp_speed_boost diğer geçici hızları (Elara Q...) ezerdi.
		var pl: Node = owner_player()
		if pl and pl.has_method("apply_evo_buff") and float(pl.call("_evo_buff", "speed")) <= 0.15:
			pl.apply_evo_buff("speed", 0.15, WARD_REFRESH + 0.15)


func on_owner_damaged(amount: float, _source: Node) -> float:
	if flag("orbit_full_buff") and _alive().size() >= 3:
		return amount * 0.9
	return amount
