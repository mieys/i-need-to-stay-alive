extends "res://scripts/enchant_behavior.gd"

## Buhar Ustası (EnchantDefs "ates_buhar"): her N. atış buz-ateş mermisi - ana hedefi önce dondurur, sonra yakar; host'ta
## donma + yanma = Buhar Patlaması tepkimesi (element_reactions.gd). Tepkimenin alan/yavaşlatma/yakma/sis ayarları yanma
## parametresindeki "steam" sözlüğüyle düşmana yazılır (enemy.gd _enchant_flags["steam"]). Bosslar donmadığı için
## onlarda tepkime çıkmaz (kart metni bunu söylüyor). Tepkime gücü temel sınıfta (reaction_power).

const ICE_FIRE_TINT := Color(0.8, 0.85, 1.0)

var _steam_shot: bool = false


func fire_start(_target: Node2D, is_extra: bool) -> void:
	_steam_shot = not is_extra and every(n("steam_every", 4))


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if _steam_shot:
		proj.set_meta("enchant_steam", true)


func look_extra(proj: Node2D, d: Dictionary) -> Dictionary:
	if proj.has_meta("enchant_steam"):
		d["tint"] = ICE_FIRE_TINT
		d["trail"] = "ice"
		d["scale"] = 1.2
	return d


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj == null or not proj.has_meta("enchant_steam") or not is_enemy(t):
		return
	proj.remove_meta("enchant_steam")
	freeze(t, 1.0)
	## "radius" burada çarpan (element_reactions.gd: 80 px x radius). Efsun gücü tepkime gücüne eklenir.
	apply_burn_to(t, {"steam": {"radius": f("steam_radius", 1.0), "slow": f("steam_slow", 0.3),
		"burn": flag("steam_burn"), "fog": flag("steam_fog")},
		"rp": GameManager.enchant_reaction_power + f("reaction_power") + (power - 1.0)})
