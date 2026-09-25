extends "res://scripts/enchant_behavior.gd"

## Kuyruklu Yıldız (EnchantDefs "arcane_kuyruklu"): güdüm / hız / ikili atış temel sınıfta. Mermi vurduğunda geldiği yol
## boyunca hasar veren bir iz kalır (enchant_area.gd "line" mode arcane - V'te İşaret de bırakır). Final (Kaos Kitabı)
## Yıldız Yağmuru: vurduğu yere gökten yıldız düşer (enchant_area.gd "meteor").

const ARCANE := Color(0.78, 0.55, 1.0)
const TRAIL_MAX := 320.0

var _origin: Vector2 = Vector2.ZERO


func fire_start(_target: Node2D, _is_extra: bool) -> void:
	_origin = weapon.global_position


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	proj.set_meta("enchant_origin", _origin)


func look_extra(_proj: Node2D, d: Dictionary) -> Dictionary:
	d["trail"] = "missile"
	return d


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj == null or not is_enemy(t):
		return
	var pos: Vector2 = t.global_position
	var from: Vector2 = Vector2(proj.get_meta("enchant_origin", weapon.global_position))
	if from.distance_to(pos) > TRAIL_MAX:
		from = pos + (from - pos).normalized() * TRAIL_MAX
	if f("trail_dur") > 0.0:
		area("line", from, {"to": pos, "width": 16.0 * f("trail_width", 1.0), "duration": f("trail_dur"), "tick": 1.0,
			"damage": ap() * 0.2 * pw("area"), "mode": "arcane", "mark": flag("trail_mark"), "color": ARCANE})
	if flag("starfall"):
		area("meteor", pos, {"delay": 0.5, "radius": 130.0, "damage": ap() * 1.8 * pw("area")})
