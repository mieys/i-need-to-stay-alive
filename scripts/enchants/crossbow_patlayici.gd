extends "res://scripts/enchant_behavior.gd"

## Patlayıcı Cıvata (EnchantDefs "crossbow_patlayici"): cıvata vurduğu yere saplanıp gecikmeli patlar (enchant_area.gd
## "sticky_bomb"). II: aynı düşmana kısa sürede 3 cıvata = büyük patlama; IV: patlama yakar; final (Şanslı Zar)
## Zincirleme Reaksiyon - patlamada ölen düşman da patlar, %3 ihtimalle 1 altın (enemy.gd "chain_bomb").

const TRIPLE_WINDOW := 1.5

func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if not is_primary or not is_enemy(t):
		return
	var mult: float = 1.0
	var r: float = f("sticky_radius", 60.0)
	if flag("sticky_triple") and track_stacks(t, 1, 3, TRIPLE_WINDOW) >= 3:
		track_stacks(t, -3, 3, TRIPLE_WINDOW)
		mult = 2.0
		r *= 1.3
		fx("text", t.global_position, {"text": "Üçlü", "color": Color(1.0, 0.7, 0.3)})
	area("sticky_bomb", t.global_position, {"delay": f("sticky_delay", 1.0), "radius": r,
		"damage": ap() * f("sticky_pct", 0.6) * pw("area") * mult, "burn": flag("sticky_burn"),
		"burn_tick": ap() * 0.10 * pw("area"), "ap": ap(), "chain": flag("chain_explode"), "gold": 0.03})
