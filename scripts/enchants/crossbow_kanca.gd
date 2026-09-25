extends "res://scripts/enchant_behavior.gd"

## Kanca Cıvatası (EnchantDefs "crossbow_kanca"): her N. cıvata vurduğu düşmanı sahibine doğru çeker (host "knock"),
## sersemletir, yolundakilere çarpar, ikinci düşmanı da çeker, sonra kısa hasar azaltma. Final (Kitelama Seti) Harpun:
## çekmek yerine çiviler (kök; bosslar neredeyse durur) ve 2 sn +%30 hasar alır (enemy.gd "root" + "vuln").

var _hook_shot: bool = false


func fire_start(_target: Node2D, is_extra: bool) -> void:
	_hook_shot = not is_extra and every(n("hook_every", 5))


func projectile_extra(proj: Node2D, _target: Node2D, _is_extra: bool) -> void:
	if _hook_shot:
		proj.set_meta("enchant_hook", true)


func look_extra(proj: Node2D, d: Dictionary) -> Dictionary:
	if proj.has_meta("enchant_hook"):
		d["tint"] = Color(0.85, 0.85, 0.95)
		d["scale"] = 1.25
	return d


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj == null or not proj.has_meta("enchant_hook") or not is_enemy(t):
		return
	proj.remove_meta("enchant_hook")
	var p: Node = owner_player()
	var victims: Array = [t]
	if n("hook_targets", 1) >= 2:
		var other: Node = nearest_enemy(t.global_position, 120.0, [t])
		if other:
			victims.append(other)
	for v in victims:
		fx("chain", p.global_position, {"to": v.global_position, "color": Color(0.85, 0.85, 0.95)})
		if flag("harpoon"):
			v.apply_element("root", {"dur": 2.0})
			v.apply_element("vuln", {"pct": 0.3, "dur": 2.0})
			continue
		var to_p: Vector2 = p.global_position - v.global_position
		if v.get("is_boss") != true and to_p.length() > 40.0:
			v.apply_element("knock", {"dir": to_p.normalized(), "dist": minf(f("hook_pull", 80.0), to_p.length() - 30.0), "quiet": true})
		if f("hook_stun") > 0.0:
			v.apply_element("stun", {"dur": f("hook_stun")})
		if f("hook_collide") > 0.0:
			var path_mid: Vector2 = v.global_position + to_p.normalized() * f("hook_pull", 80.0) * 0.5
			for e in enemies_near(path_mid, f("hook_pull", 80.0) * 0.5, v):
				hit(e, ap() * f("hook_collide") * pw("hit"))
	if f("hook_dr") > 0.0 and p.has_method("enchant_damage_reduction"):
		p.enchant_damage_reduction(f("hook_dr"), 2.0)
