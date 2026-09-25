extends "res://scripts/enchant_behavior.gd"

## Seri Ateş (EnchantDefs "tabanca_seri"): seri atış / yelpaze / saldırı hızı temel sınıfta (volley_*). Burada: seri
## mermileri büyük, seri anında koşu hızı, final (Eldiven) seriden sonra 2 sn +%50 saldırı hızı.


func projectile_extra(proj: Node2D, _target: Node2D, is_extra: bool) -> void:
	if is_extra and f("volley_scale", 1.0) != 1.0:
		proj.scale *= f("volley_scale")


func fire_extra(_target: Node2D, is_extra: bool) -> void:
	if is_extra or n("volley_every") <= 0 or not every(n("volley_every")):
		return
	if f("volley_speed") > 0.0:
		var p: Node = owner_player()
		if p and p.has_method("enchant_speed_buff"):
			p.enchant_speed_buff(f("volley_speed"), 2.0)
	if f("frenzy") > 0.0:
		haste(f("frenzy"), 2.0 + f("volley_delay", 0.09) * float(n("volley_count", 3)))
