extends "res://scripts/enchant_behavior.gd"

## Alevli Ok (EnchantDefs "yay_alev"): yakma / yanan bonusu / delme / yanma yığını temel sınıfta. II: isabet noktasında
## küçük alev (çevredekiler de yanar). Final (Vitamin): her 4. ok her şeyi delen, büyük, alev izli bir "Anka" okudur -
## yaktığı her düşman 0,5 can.

var _phoenix_shot: bool = false
var _heal_acc: float = 0.0


func fire_start(_target: Node2D, is_extra: bool) -> void:
	_phoenix_shot = not is_extra and n("phoenix_every") > 0 and every(n("phoenix_every"))


func damage_extra(dmg: float, _t: Node2D) -> float:
	return dmg * 1.5 if _phoenix_shot else dmg


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if _phoenix_shot:
		proj.set("pierce_count", 99)
		proj.set("pierce_damage_percent", 1.0)
		proj.set_meta("enchant_phoenix", true)


func look_extra(proj: Node2D, d: Dictionary) -> Dictionary:
	if proj.has_meta("enchant_phoenix"):
		d["tint"] = Color(1.0, 0.62, 0.28)
		d["trail"] = "fire"
		d["scale"] = 1.7
		d["pierce"] = 99
	return d


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_enemy(t):
		return
	if is_primary and f("flame_splash") > 0.0:
		for e in enemies_near(t.global_position, f("flame_splash"), t):
			apply_burn_to(e)
		fx("burst", t.global_position, {"palette": "fire", "count": 10, "speed": 80.0, "life": 0.35})
	if proj != null and proj.has_meta("enchant_phoenix"):
		_heal_acc += 0.5 * power
		if _heal_acc >= 1.0:
			heal_owner(floorf(_heal_acc))
			_heal_acc -= floorf(_heal_acc)
