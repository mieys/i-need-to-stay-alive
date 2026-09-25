extends "res://scripts/enchant_behavior.gd"

## Keskin Kenar (EnchantDefs "bumerang_kenar"): kanama / kanayana bonus / boyut / hızlı kanama temel sınıfta. II: dönüşte
## (boomerang_projectile.gd: is_primary = gidiş) daha çok kanama; final (Vampir Dişi) Kan Çarkı - yakalayınca 3 sn
## etrafında dönen, can çeken bir çark (enchant_area.gd "orbit_blade").

const BLOOD := Color(0.9, 0.2, 0.25)


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	var extra: int = n("return_bleed") - n("bleed_stacks", 1)
	if not is_primary and extra > 0 and is_enemy(t):
		apply_bleed_to(t, extra)


func on_boomerang_caught(_proj: Node2D) -> void:
	if not flag("blood_wheel") or own_count("wheel") > 0:
		return
	var p: Node = owner_player()
	if p == null:
		return
	tagged_area("wheel", "orbit_blade", p.global_position, {"follow": true, "duration": 3.0, "orbit_radius": 60.0,
		"orbit_speed": 6.0, "touch": 26.0, "damage": ap() * 0.5 * pw("bleed"), "drain": 0.3, "color": BLOOD})
