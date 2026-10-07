extends "res://scripts/enchant_behavior.gd"

## Yankılanan Büyü (Arcane Asası, kalıcı özellik) - bkz. EnchantDefs "yankilanan_buyu". Küre isabeti echo_chance ihtimalle
## (echo_pity isabette bir kesin) hedefin yerinde bir "yankı" bırakır; echo_delay sn sonra aynı noktada ikinci bir küre patlar
## (silah hasarı x echo_dmg, echo_radius). Çift Yankı: 0,5 sn sonra bir kez daha (yarı hasar). Final: patlamaya yakalananlar
## echo_stun sn sersemler. Hasar/görsel `blast` ile (yerel + diğer oyunculara aynı efekt).

const REPEAT_GAP := 0.5
const ECHO_COLOR := Color(0.88, 0.55, 1.0)


func hit_extra(t: Node, _dmg: float, is_primary: bool, proj: Node2D) -> void:
	if not is_primary or proj == null or not is_enemy(t) or not can_act():
		return
	if not roll_pity("echo", f("echo_chance", 0.25), n("echo_pity", 4)):
		return
	var at: Vector2 = (t as Node2D).global_position
	fx("ring", at, {"radius": f("echo_radius", 45.0) * 0.75, "color": ECHO_COLOR, "duration": f("echo_delay", 0.8)})
	get_tree().create_timer(f("echo_delay", 0.8), false).timeout.connect(_pop.bind(at, 1.0, n("echo_repeat")))


func _pop(at: Vector2, mult: float, repeats_left: int) -> void:
	if not is_instance_valid(self) or not is_instance_valid(weapon) or not can_act():
		return
	var victims: Array = blast(at, f("echo_radius", 45.0), wdmg() * f("echo_dmg", 0.7) * mult, ECHO_COLOR)
	if f("echo_stun") > 0.0:
		for e in victims:
			if is_enemy(e):
				e.apply_element("stun", {"dur": f("echo_stun")})
	if repeats_left > 0:
		get_tree().create_timer(REPEAT_GAP, false).timeout.connect(_pop.bind(at, mult * 0.5, repeats_left - 1))
