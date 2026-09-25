extends "res://scripts/enchant_behavior.gd"

## Ağır Darbe (EnchantDefs "topuz_agir"): her N. vuruş çok güçlü; II: kalkan deler; IV: bosslara ekstra; V: ardından kısa
## hasar azaltma (player.enchant_damage_reduction). Final (Keskin Uçlar): Kafatası Kırıcı - ağır darbe hedefte kalıcı
## çatlak bırakır, her çatlak o düşmanın aldığı TÜM hasarı +%10 artırır (host, enemy.gd crack_stacks).

var _heavy: bool = false


func fire_start(_target: Node2D, is_extra: bool) -> void:
	_heavy = not is_extra and every(n("heavy_every", 4))


func damage_extra(dmg: float, t: Node2D) -> float:
	if not _heavy:
		return dmg
	var m: float = f("heavy_mult", 2.0)
	if f("heavy_boss") > 0.0 and status(t, "boss"):
		m *= 1.0 + f("heavy_boss")
	return dmg * m


func pen_extra() -> float:
	return f("heavy_pen") if _heavy else 0.0


func hit_extra(t: Node, _dmg: float, is_primary: bool, _proj: Node2D) -> void:
	if not _heavy or not is_primary or not is_enemy(t):
		return
	if flag("crack"):
		t.apply_element("crack", {"stacks": 1})
	fx("wave", t.global_position, {"radius": 55.0, "color": Color(0.85, 0.85, 0.9), "duration": 0.3})
	if f("heavy_dr") > 0.0:
		var p: Node = owner_player()
		if p and p.has_method("enchant_damage_reduction"):
			p.enchant_damage_reduction(f("heavy_dr"), 1.0)
