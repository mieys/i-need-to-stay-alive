extends "res://scripts/enchant_behavior.gd"

## Sersemletici Bomba (EnchantDefs "fisek_sersem"): patlamanın vurdukları sersemler (temel sınıf stun_on_hit; bosslar
## hariç), alan temel sınıfta. Sersemleyene süreli savunmasızlık (enemy "vuln"), bosslara yavaşlatma, sersemleme sonrası
## yavaşlama. Final (Deri Çizme) Işık Bombası: patlama dışarı iter + 2 sn şaşkın dolaşma (enemy "fear"), sahibine hız.


func hit_extra(t: Node, _dmg: float, _is_primary: bool, _proj: Node2D) -> void:
	if not is_enemy(t):
		return
	var boss: bool = t.get("is_boss") == true
	if boss:
		if f("boss_slow") > 0.0:
			t.apply_element("slow", {"pct": f("boss_slow"), "dur": 2.0, "boss": true})
		return
	if f("stun_vuln") > 0.0:
		t.apply_element("vuln", {"pct": f("stun_vuln"), "dur": f("stun_on_hit", 0.8) + 2.0})
	if f("stun_slow") > 0.0:
		t.apply_element("slow", {"pct": f("stun_slow"), "dur": f("stun_on_hit", 0.8) + 2.0})


func on_explode(proj: Node2D, pos: Vector2) -> void:
	if not flag("flashbang"):
		return
	var r: float = float(proj.get("splash_radius")) if "splash_radius" in proj else 66.0
	for e in enemies_near(pos, r * 1.2):
		if e.get("is_boss") == true:
			continue
		var away: Vector2 = e.global_position - pos
		e.apply_element("knock", {"dir": away.normalized() if away.length() > 1.0 else Vector2.RIGHT.rotated(randf() * TAU), "dist": 60.0, "quiet": true})
		e.apply_element("fear", {"dur": 2.0})
	fx("holy", pos, {"radius": r * 1.2, "color": Color(1.0, 1.0, 0.9), "duration": 0.35})
	var p: Node = owner_player()
	if p and p.has_method("enchant_speed_buff"):
		p.enchant_speed_buff(0.2, 2.0)
