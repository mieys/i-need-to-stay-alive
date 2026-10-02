extends "res://scripts/enchant_behavior.gd"

## Earthquake (Topuz) - bkz. EnchantDefs "earthquake". Her N. ana hedef isabetinde vuruş yönünde bir sarsıntı hattı:
## hattaki düşmanlara hasar + sersemletme; görsel quake_tile karoları (diğer oyuncular da görür). Final: hat 3 sn yarık kalır
## (enchant_area "line" + rift_tile: %30 yavaşlatma, saniyede %15) ve ucunda kaya sütunu (pillar sayfası, 80 birim %150).

const PILLAR_RADIUS := 80.0

var _hits: int = 0


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj != null or not is_enemy(t) or not can_act():
		return
	_hits += 1
	if _hits % maxi(1, n("quake_every", 4)) != 0:
		return
	var pl: Node2D = owner_player() as Node2D
	if pl == null:
		return
	var dir: Vector2 = dir_to(pl.global_position, t)
	var a: Vector2 = pl.global_position + dir * 14.0
	var b: Vector2 = a + dir * f("quake_len", 200.0)
	var half_w: float = f("quake_width", 40.0) * 0.5 + 8.0
	fx("tiles", a, {"sheet": "quake_tile", "to": b, "step": 20.0, "rot": 0.0})
	for e in enemies_near((a + b) * 0.5, a.distance_to(b) * 0.5 + half_w):
		if e.global_position.distance_to(Geometry2D.get_closest_point_to_segment(e.global_position, a, b)) > half_w:
			continue
		hit(e, ap() * f("quake_ap"))
		e.apply_element("stun", {"dur": f("quake_stun", 0.5)})
	if flag("rift"):
		area("line", a, {"to": b, "width": half_w, "tick": 1.0, "damage": ap() * 0.15, "slow": 0.3, "duration": 3.0,
			"sheet": "rift_tile_wide", "sheet_scale": Vector2(1.0, f("quake_width", 40.0) / 40.0)})
	if f("pillar") > 0.0:
		sprite("pillar", b, {"offset": Vector2(0.0, -40.0), "z": 9})
		for e in enemies_near(b, PILLAR_RADIUS):
			hit(e, ap() * f("pillar"))
