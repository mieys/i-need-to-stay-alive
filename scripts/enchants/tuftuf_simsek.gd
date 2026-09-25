extends "res://scripts/enchant_behavior.gd"

## Şimşek Dikeni (EnchantDefs "tuftuf_simsek"): şok / şoklu bonus / kıvılcım temel sınıfta (shock_*). Final (Yetenek
## Kitabı): isabet noktasına 4 sn sonra patlayan elektrik kovanı (enchant_area.gd "hive"); oyuncu bir yetenek
## kullanınca (player.gd _notify_enchants_skill_used) tüm kovanlar anında patlar.


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if is_primary and flag("hive") and is_enemy(t):
		area("hive", t.global_position, {"delay": 4.0, "radius": 120.0, "damage": ap() * 1.2 * pw("shock"), "shock": shock_params()})


func on_skill_used() -> void:
	for h in get_tree().get_nodes_in_group(EnchantArea.HIVE_GROUP):
		if is_instance_valid(h) and h.has_method("explode_hive"):
			h.explode_hive()
