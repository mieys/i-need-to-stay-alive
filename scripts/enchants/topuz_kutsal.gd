extends "res://scripts/enchant_behavior.gd"

## Kutsal Topuz (EnchantDefs "topuz_kutsal"): vurulan düşman başına kalkan; kalkan doluyken bonus temel sınıfta. III:
## her N. vuruşta kutsal ışık çevredeki dostları iyileştirir (uzak oyunculara player._apply_heal_to_ally ile - co-op
## iyileştirme). Final (Kalkan Yüzüğü): ışık düşmanlara da vurur, dostlara kalkan verir; kalkan kırılınca kendiliğinden
## çıkar (15 sn).

const MAX_SHIELD_HITS_PER_SWING := 8
const LIGHT_RADIUS := 150.0
const BREAK_COOLDOWN := 15.0

var _swing_hits: int = 0
var _last_shield: float = 0.0
var _break_cd: float = 0.0


func fire_start(_target: Node2D, _is_extra: bool) -> void:
	_swing_hits = 0


func hit_extra(t: Node, _dmg: float, _is_primary: bool, _proj: Node2D) -> void:
	if not is_enemy(t) or _swing_hits >= MAX_SHIELD_HITS_PER_SWING:
		return
	_swing_hits += 1
	var p: Node = owner_player()
	if p and p.has_method("heal_shield"):
		p.heal_shield(f("shield_per_hit", 1.0) * power)


func fire_extra(_target: Node2D, is_extra: bool) -> void:
	if not is_extra and n("light_every") > 0 and every(n("light_every")):
		_holy_light()


func process_extra(delta: float) -> void:
	_break_cd = maxf(0.0, _break_cd - delta)
	if not flag("light_final"):
		return
	var p: Node = owner_player()
	if p == null:
		return
	var hp: float = float(p.get("item_shield_hp"))
	if _last_shield > 0.0 and hp <= 0.0 and _break_cd <= 0.0 and can_act():
		_break_cd = BREAK_COOLDOWN
		_holy_light()
	_last_shield = hp


func _holy_light() -> void:
	var p: Node = owner_player()
	if p == null:
		return
	var pos: Vector2 = p.global_position
	var amount: float = f("light_heal", 10.0) * power
	var final: bool = flag("light_final")
	heal_owner(amount)
	if final and p.has_method("heal_shield"):
		p.heal_shield(amount)
	for ally in get_tree().get_nodes_in_group("remote_players"):
		if not is_instance_valid(ally) or ally.global_position.distance_to(pos) > LIGHT_RADIUS:
			continue
		if p.has_method("_apply_heal_to_ally"):
			p._apply_heal_to_ally(ally, amount)
		if final and p.has_method("_apply_shield_heal_to_ally"):
			p._apply_shield_heal_to_ally(ally, amount)
	if final:
		for e in enemies_near(pos, LIGHT_RADIUS):
			hit(e, ap() * 1.5 * power)
	fx("holy", pos, {"radius": LIGHT_RADIUS, "color": Color(1.0, 0.92, 0.55), "duration": 0.6})
