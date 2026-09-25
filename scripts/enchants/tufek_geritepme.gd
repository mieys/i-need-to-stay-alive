extends "res://scripts/enchant_behavior.gd"

## Geri Tepme (EnchantDefs "tufek_geritepme"): itme / sersemletme temel sınıfta (knockback, stun_on_hit). Burada: atış
## sonrası kısa hasar azaltma, itilen düşmanın arkasındakilere çarpması, final (Steroid) her 4. atış dev gülle - her şeyi
## deler, düşmanları sürükler, her delişte +%20.

const COLLIDE_RADIUS := 50.0

var _cannon_shot: bool = false


func fire_start(_target: Node2D, is_extra: bool) -> void:
	_cannon_shot = not is_extra and n("cannon_every") > 0 and every(n("cannon_every"))


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if not _cannon_shot:
		return
	proj.set("pierce_count", 99)
	proj.set("pierce_damage_percent", 1.0)
	proj.scale *= 2.0
	proj.set_meta("enchant_cannon", true)


func look_extra(proj: Node2D, d: Dictionary) -> Dictionary:
	if proj.has_meta("enchant_cannon"):
		d["pierce"] = 99
		d["tint"] = Color(0.75, 0.75, 0.8)
		d["trail"] = "missile"
	return d


func fire_extra(_target: Node2D, is_extra: bool) -> void:
	if is_extra or f("recoil_dr") <= 0.0:
		return
	var p: Node = owner_player()
	if p and p.has_method("enchant_damage_reduction"):
		p.enchant_damage_reduction(f("recoil_dr"), 0.5)


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_enemy(t) or proj == null:
		return
	var dir: Vector2 = Vector2(proj.get("direction")).normalized()
	if proj.has_meta("enchant_cannon"):
		proj.set("damage", float(proj.get("damage")) * 1.2)
		if t.get("is_boss") != true:
			t.apply_element("knock", {"dir": dir, "dist": 60.0, "quiet": true})
	if is_primary and f("push_collide") > 0.0:
		var behind: Vector2 = t.global_position + dir * COLLIDE_RADIUS
		for e in enemies_near(behind, COLLIDE_RADIUS, t):
			hit(e, ap() * f("push_collide") * pw("hit"))
		fx("burst", behind, {"palette": "dust", "count": 8, "speed": 90.0, "life": 0.3})
