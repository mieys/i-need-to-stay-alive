extends "res://scripts/enchant_behavior.gd"

## Yıldırım Bumerang (EnchantDefs "bumerang_yildirim"): bumerang havadayken sahibiyle arasında elektrik hattı - 0,5 sn'de
## bir kısa ömürlü "line" alanı (anında hasar + şok; yeni hat öncekinin yerini alır, uzak oyuncular da görür). Şok /
## şokluya bonus temel sınıfta. VI: yakalayınca hat 2 sn kalır; final (Hasat Çantası) Enerji Kırbacı - gidilen yol 3 sn
## elektrik ağı olarak kalır, değdiği tecrübe kürelerini sahibine çeker.

const TETHER_INTERVAL := 0.5
const SHOCK := Color(1.0, 0.92, 0.4)

var _flying: Array = []
var _tether_timer: float = 0.0


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	_flying.append(proj)
	proj.set_meta("enchant_origin", weapon.global_position)


func on_boomerang_apex(proj: Node2D) -> void:
	proj.set_meta("enchant_apex", proj.global_position)


func process_extra(delta: float) -> void:
	_tether_timer -= delta
	if _tether_timer > 0.0 or _flying.is_empty():
		return
	_tether_timer = TETHER_INTERVAL
	var alive: Array = []
	var p: Node = owner_player()
	for proj in _flying:
		if not is_instance_valid(proj) or p == null:
			continue
		alive.append(proj)
		area("line", p.global_position, {"to": proj.global_position, "width": 12.0 * f("tether_width", 1.0),
			"duration": TETHER_INTERVAL + 0.05, "instant": ap() * f("tether_dmg", 0.2) * pw("area"), "mode": "shock",
			"ap": ap(), "color": SHOCK})
	_flying = alive


func on_boomerang_caught(proj: Node2D) -> void:
	var p: Node = owner_player()
	if p == null:
		return
	var apex: Vector2 = Vector2(proj.get_meta("enchant_apex", proj.global_position))
	if flag("tether_linger"):
		area("line", p.global_position, {"to": apex, "width": 12.0 * f("tether_width", 1.0), "duration": 2.0, "tick": 0.5,
			"damage": ap() * f("tether_dmg", 0.2) * pw("area") * 0.5, "mode": "shock", "ap": ap(), "color": SHOCK})
	if flag("tether_net"):
		var origin: Vector2 = Vector2(proj.get_meta("enchant_origin", p.global_position))
		area("line", origin, {"to": apex, "width": 18.0, "duration": 3.0, "tick": 0.5,
			"damage": ap() * f("tether_dmg", 0.2) * pw("area") * 0.5, "mode": "shock", "ap": ap(), "collect_xp": true,
			"color": Color(1.0, 0.95, 0.65)})
