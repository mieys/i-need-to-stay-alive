extends "res://scripts/enchant_behavior.gd"

## Kasırga Bumerang (EnchantDefs "bumerang_kasirga"): uç noktada durma (apex_pause - boomerang_projectile.gd aynı
## düşmanları 1/3 sn'de bir keser) / boyut temel sınıfta. Durduğu yerde çekim (hasarsız kasırga alanı) ve yavaşlatma;
## final (Deri Çizme) Hortum Çarkı - yakalayınca 4 sn seni izleyen hortum (enchant_area.gd "tornado" follow).

const PULL_RADIUS := 110.0


func on_boomerang_apex(proj: Node2D) -> void:
	var pos: Vector2 = proj.global_position
	var dur: float = f("apex_pause", 1.0)
	if flag("apex_pull"):
		area("tornado", pos, {"duration": dur, "speed": 0.0, "radius": PULL_RADIUS, "damage": 0.0})
	if f("apex_slow") > 0.0:
		for e in enemies_near(pos, PULL_RADIUS):
			e.apply_element("slow", {"pct": f("apex_slow"), "dur": dur + 0.5})


func on_boomerang_caught(_proj: Node2D) -> void:
	if not flag("tornado_follow") or own_count("hortum") > 0:
		return
	var p: Node = owner_player()
	if p:
		tagged_area("hortum", "tornado", p.global_position, {"follow": true, "duration": 4.0, "radius": 70.0,
			"damage": ap() * 0.4 * power})
