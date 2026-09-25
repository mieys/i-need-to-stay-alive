extends "res://scripts/enchant_behavior.gd"

## Buz Mermisi (EnchantDefs "tufek_buz"): yavaşlatma / N isabette donma / donmuşa bonus temel sınıfta. IV: donmuş düşmana
## isabet buzu parçalar (ek hasar + 3 kıymık); final (Kitelama Seti) Mutlak Sıfır - mermi yolu boyunca 3 sn buz koridoru
## (enchant_area.gd "line" mode ice: içine giren donar, bosslar yavaşlar).

const ICE := Color(0.75, 0.9, 1.0)

var _origin: Vector2 = Vector2.ZERO


func fire_start(_target: Node2D, _is_extra: bool) -> void:
	_origin = weapon.global_position


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	proj.set_meta("enchant_origin", _origin)


## Parçalama "isabetten önce donmuş muydu"ya bakar - aynı isabetin genel donması (temel sınıf) saymasın.
func on_hit(t: Node, dmg: float, is_primary: bool, proj: Node2D) -> void:
	var was_frozen: bool = status(t, "frozen")
	super.on_hit(t, dmg, is_primary, proj)
	if flag("shatter_hit") and is_primary and was_frozen and is_enemy(t):
		hit(t, ap() * 0.8 * pw("hit"))
		var pts: Array = [t.global_position]
		for e in random_enemies(t.global_position, 140.0, 3, t):
			hit(e, ap() * 0.3 * pw("hit"))
			pts.append(e.global_position)
		fx("bursts", t.global_position, {"points": pts, "palette": "spark", "count": 8})


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or not flag("ice_corridor") or proj == null or not is_enemy(t):
		return
	var pos: Vector2 = t.global_position
	var from: Vector2 = Vector2(proj.get_meta("enchant_origin", weapon.global_position))
	var dir: Vector2 = (pos - from).normalized() if pos.distance_to(from) > 1.0 else Vector2(proj.get("direction"))
	area("line", from, {"to": pos + dir * 200.0, "width": 24.0, "duration": 3.0, "tick": 0.5, "damage": 0.0,
		"mode": "ice", "color": ICE})
