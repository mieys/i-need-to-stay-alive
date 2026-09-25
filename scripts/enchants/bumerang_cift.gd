extends "res://scripts/enchant_behavior.gd"

## Çift Bumerang (EnchantDefs "bumerang_cift"): her atışta başka düşmanlara ek bumeranglar (weapon.fire_enchant_shot -
## her biri havadaki bumerang sayacına girer, hepsi dönünce yeni atış). Hız / menzil temel sınıfta; yakalayınca kısa
## saldırı hızı. Final (Kaos Kitabı): her bumerang uç noktada ikiye bölünür, parça yakındaki başka düşmana gider
## (sahibine döner, sayaca girmez, kendisi bir daha bölünmez).


func fire_extra(target: Node2D, is_extra: bool) -> void:
	if is_extra or n("extra_boomerangs") <= 0 or not is_instance_valid(target):
		return
	var rng: float = float(weapon.get("attack_range"))
	var others: Array = enemies_near(weapon.global_position, rng, target)
	others.shuffle()
	for k in range(n("extra_boomerangs")):
		var t: Node2D = others[k] if k < others.size() else target
		var ang: float = 0.0 if k < others.size() else deg_to_rad(25.0) * float(k + 1) * (1.0 if k % 2 == 0 else -1.0)
		weapon.fire_enchant_shot(t, 0.06 * float(k + 1), 1.0, ang)


func on_boomerang_caught(_proj: Node2D) -> void:
	if f("catch_buff") > 0.0:
		haste(f("catch_buff"), 2.0)


func on_boomerang_apex(proj: Node2D) -> void:
	if not flag("split_return") or proj.has_meta("enchant_split_child"):
		return
	var pos: Vector2 = proj.global_position
	var other: Node = nearest_enemy(pos, 260.0)
	var dir: Vector2 = dir_to(pos, other) if other else Vector2(proj.get("direction")).rotated(PI * 0.5)
	var child: Node2D = weapon._spawn_enchant_projectile_now(pos, dir, float(proj.get("damage")), [], projectile_look(proj),
		{"enchant_split_child": true})
	if child == null:
		return
	child.set("player_node", proj.get("player_node"))
	child.set("throw_distance", float(proj.get("throw_distance")) * 0.6)
	if "speed" in child:
		child.set("speed", float(proj.get("speed")))
