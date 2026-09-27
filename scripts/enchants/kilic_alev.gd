extends "res://scripts/enchant_behavior.gd"

## Alevli Kılıç (EnchantDefs "kilic_alev"): yakma / yanana bonus / yanma yığını temel sınıfta. Her N savuruşta (on_revolution -
## weapon.gd _sword_contact) sahibinin çevresinde, kılıcın erişim mesafesinde süreli alev halkası (enchant_area.gd "field" ring,
## sahibini izler).
## Final (Sigara) Ateş Kılıcı: vuruş alanı x2 (aoe_mult, temel sınıf) + her turda çevreye alev dalgası.

const FIRE := Color(1.0, 0.55, 0.2)
const RING_WIDTH := 26.0


## 2026-09-26: kılıç artık etrafta dönmüyor (eskiden oyuncu-kılıç mesafesi = yörünge yarıçapı) - halka kılıcın erişim
## mesafesinin (attack_range) ~%70'inde, savuruşların düştüğü bantta.
func _orbit_radius() -> float:
	var reach: float = float(weapon.get("attack_range")) if is_instance_valid(weapon) else 115.0
	return clampf(reach * 0.7, 60.0, 180.0)


func revolution_extra(_pos: Vector2) -> void:
	if not can_act():
		return
	var p: Node2D = owner_player() as Node2D
	var r: float = _orbit_radius()
	if n("flame_ring_every") > 0 and every(n("flame_ring_every")):
		var bp: Dictionary = burn_area_params()
		area("field", p.global_position, {"follow": true, "radius": r + RING_WIDTH * 0.5, "ring": RING_WIDTH,
			"duration": f("ring_dur", 1.0), "tick": 0.5, "damage": ap() * 0.05 * pw("burn"), "mode": "fire",
			"burn_tick": float(bp["burn_tick"]), "ap": ap(), "color": FIRE})
	if flag("fire_sword") and every(2):
		for e in blast(p.global_position, r + 40.0, ap() * 0.6 * pw("burn"), FIRE, "wave"):
			apply_burn_to(e)
