extends Node

## Yakın dövüş ZİNCİRİ (madde 347): vuruştan sonra silah dinlenme yerine dönmeden bekler, sonraki vuruş o pozdan başlar; hız katı
## yalnız vuruş hareketini aralığa sığdırır. Tek kaynak scripts/melee_chain_math.gd (weapon.gd + remote_player.gd + 6 vuruş modülü).

const MeleeChainMath := preload("res://scripts/melee_chain_math.gd")
const SwordSwingMath := preload("res://scripts/sword_swing_math.gd")
const DaggerStabMath := preload("res://scripts/dagger_stab_math.gd")
const TopuzSlamMath := preload("res://scripts/topuz_slam_math.gd")
const PenceHookMath := preload("res://scripts/pence_hook_math.gd")
const MizrakThrustMath := preload("res://scripts/mizrak_thrust_math.gd")
const KalkanBashMath := preload("res://scripts/kalkan_bash_math.gd")

const BASE_WAIT := 1.1111 / 0.7 ## yakın dövüş taban aralığı (fire_rate / WEAPON_ATTACK_SPEED_MULT)


func _modules() -> Array:
	return [SwordSwingMath, DaggerStabMath, TopuzSlamMath, PenceHookMath, MizrakThrustMath, KalkanBashMath]


## Taban ve x2 saldırı hızında vuruşlar hız 1'de (eskiden x2'de iki kat hızlı oynuyordu); x4'te bile hareket aralığa sığar.
func test_speed_only_fits_the_strike() -> void:
	for m in _modules():
		var busy_1x: float = m.busy_duration(1.0)
		assert(busy_1x > 0.1 and busy_1x < 0.6, "%s hareket süresi: %s" % [m.resource_path, busy_1x])
		assert(is_equal_approx(MeleeChainMath.anim_speed(busy_1x, BASE_WAIT), 1.0), "taban hızda x1")
		assert(is_equal_approx(MeleeChainMath.anim_speed(busy_1x, BASE_WAIT / 2.0), 1.0), "x2 saldırı hızında da x1: %s" % m.resource_path)
		var busy_fn := func(s: float) -> float: return m.busy_duration(s)
		for rate in [4.0, 5.5, 7.0]:
			var wait: float = BASE_WAIT / rate
			var sp: float = MeleeChainMath.fit_speed(busy_fn, wait)
			assert(sp >= 1.0 and sp <= MeleeChainMath.SPEED_MAX)
			## Pençe ana pozları kareden kısa kalmaz (madde 304 MIN_POSE) - FILL'i biraz aşabilir; şart: sonraki vuruştan önce biter.
			assert(m.busy_duration(sp) < wait or is_equal_approx(sp, MeleeChainMath.SPEED_MAX),
				"x%s: hareket sonraki vuruştan önce biter (%s: %s / %s)" % [rate, m.resource_path, m.busy_duration(sp), wait])
			if m != PenceHookMath:
				assert(m.busy_duration(sp) <= wait * MeleeChainMath.FILL + 0.002, "x%s: hareket aralığın FILL'ine sığar" % rate)


## Hızlı vuruşta bekleme bir sonraki vuruşun anını aşar (dönmeden zincirlenir); yavaşta silah eskisi gibi dinlenme yerine döner.
func test_hold_spans_to_the_next_attack_only_when_attacks_are_close() -> void:
	for m in _modules():
		for rate in [2.0, 3.0, 4.0]:
			var wait: float = BASE_WAIT / rate
			var sp: float = MeleeChainMath.anim_speed(m.busy_duration(1.0), wait)
			var busy: float = m.busy_duration(sp)
			var hold: float = MeleeChainMath.hold_time(busy, wait)
			assert(hold >= 0.0 and hold <= MeleeChainMath.HOLD_MAX)
			if wait - busy + MeleeChainMath.GRACE <= MeleeChainMath.HOLD_MAX:
				assert(busy + hold >= wait + MeleeChainMath.GRACE - 0.001, "x%s sonraki vuruş beklemede gelir (%s)" % [rate, m.resource_path])
		var slow_busy: float = m.busy_duration(1.0)
		assert(slow_busy + MeleeChainMath.hold_time(slow_busy, BASE_WAIT) + m.RETURN < BASE_WAIT,
			"taban hızda bekleme + dönüş aralığa sığar, silah dinlenir (%s)" % m.resource_path)


## Kaster (weapon.gd): x2 saldırı hızında kılıç x1 hızla savrulur, savuruş bitince YERİNDE bekler, ikinci savuruş beklenen pozdan
## başlar (dinlenme yerine sıçramaz); sonraki vuruş gelmezse dinlenme yerine döner.
func test_sword_waits_at_the_target_and_chains_from_there() -> void:
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_uzunkilic.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	weapon.call("set_fire_rate_mult", 0.5)
	var sp: float = weapon.call("_melee_effect_speed_scale")
	assert(is_equal_approx(sp, 1.0), "x2 saldırı hızında savuruş x1 hızda (eskiden x2): %s" % sp)
	var hold: float = weapon.call("_melee_chain_hold", sp)
	assert(hold > 0.3, "aralık 0,79 sn, savuruş 0,32 sn -> sonraki vuruşa kadar bekler: %s" % hold)
	var icon: Node2D = weapon.get("icon_sprite")
	var target: Vector2 = weapon.global_position + Vector2(80.0, 0.0)
	weapon.call("_start_sword_swing", Vector2.RIGHT, target)
	var tw: Tween = weapon.get("_melee_swing_tween")
	tw.pause()
	tw.custom_step(SwordSwingMath.busy_duration(sp) + 0.01)
	var d0: float = icon.position.length()
	tw.custom_step(hold * 0.5)
	var held: Vector2 = icon.global_position
	var d1: float = icon.position.length()
	assert(d1 > 20.0, "savuruştan sonra dinlenme yerine dönmedi: %s" % icon.position)
	assert(absf(d1 - d0) < 0.5, "kılıç beklerken SABİT durur (geri kayma yalnız bıçakta): %s -> %s" % [d0, d1])
	weapon.call("_start_sword_swing", Vector2.RIGHT, target)
	var tw2: Tween = weapon.get("_melee_swing_tween")
	tw2.pause()
	tw2.custom_step(0.001)
	assert(icon.global_position.distance_to(held) < 2.0, "ikinci savuruş beklenen pozdan başlar: %s / %s" % [icon.global_position, held])
	tw2.custom_step(SwordSwingMath.busy_duration(sp) + hold + SwordSwingMath.RETURN + 0.05)
	assert(icon.position.length() < 0.5, "sonraki vuruş gelmezse dinlenme yerine döner: %s" % icon.position)
	owner_node.free()


## Yalnız bıçak boştayken sabit durmaz: dinlenme yerine doğru yavaşça kayar - ama ancak DRIFT_MAX kadar (2026-10-21).
func test_only_the_dagger_drifts_back_while_waiting() -> void:
	var host := Node2D.new()
	add_child(host)
	var icon := Sprite2D.new()
	host.add_child(icon)
	var target := Vector2(80.0, 0.0)
	var plan: Dictionary = DaggerStabMath.make_plan(Vector2.RIGHT, target, 1.0, DaggerStabMath.REF_OWNER_SCALE)
	var tw: Tween = DaggerStabMath.play(host, icon, plan, 0.0, Vector2.ZERO, 0.0, Vector2.ONE, 1.0, false, host, 0.45)
	tw.pause()
	tw.custom_step(DaggerStabMath.busy_duration(1.0) + 0.005)
	var d0: float = icon.position.length()
	var r0: float = icon.rotation
	tw.custom_step(0.25)
	var d1: float = icon.position.length()
	assert(d1 < d0 - 1.0, "bıçak beklerken geri kayar: %s -> %s" % [d0, d1])
	assert(d1 > d0 * (1.0 - MeleeChainMath.DRIFT_MAX) - 0.5, "hafif kayar, dönmez: %s -> %s" % [d0, d1])
	assert(absf(icon.rotation) < absf(r0) or is_zero_approx(r0), "açı da dinlenme açısına doğru döner: %s -> %s" % [r0, icon.rotation])
	assert(MeleeChainMath.drift_at(0.0) == 0.0 and MeleeChainMath.drift_at(10.0) <= MeleeChainMath.DRIFT_MAX)
	host.free()


## MP: kukla kasterin gönderdiği "chain_hold" ile aynı süre bekler; eski sürüm göndermezse hemen döner.
func test_puppet_holds_with_the_casters_hold() -> void:
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate() as Node2D
	add_child(puppet)
	puppet.setup(77, 5, "Dost")
	puppet.global_position = Vector2(3000.0, 3000.0)
	puppet.call("update_weapon_visuals", ["dagger"])
	var icon: Node2D = (puppet.get("_weapon_icons") as Array)[0]
	var target := Vector2(3080.0, 2990.0)
	var dir: Vector2 = (target - puppet.global_position).normalized()
	var base: Dictionary = {"slot_index": 0, "direction_x": dir.x, "direction_y": dir.y, "target_pos_x": target.x, "target_pos_y": target.y,
		"hold_duration": 0.0, "dagger_size": 1.0, "dagger_speed": 1.0}
	var with_hold: Dictionary = base.duplicate()
	with_hold["chain_hold"] = 0.4
	puppet.call("_animate_weapon_fire_full", with_hold)
	var tw: Tween = (puppet.get("_weapon_fire_tweens") as Array)[0]
	tw.pause()
	var busy: float = DaggerStabMath.busy_duration(1.0)
	tw.custom_step(busy + DaggerStabMath.RETURN + 0.05)
	var held: Vector2 = icon.position
	var slots: Array = puppet.get("WEAPON_ICON_SLOTS")
	var slot0: Vector2 = slots[0]
	assert(held.distance_to(slot0) > 10.0, "kukla bıçağı beklemede, dinlenme yerinde değil: %s" % held)
	tw.custom_step(0.4)
	assert(icon.position.distance_to(slot0) < 0.5, "bekleme bitince döner: %s" % icon.position)
	puppet.call("_animate_weapon_fire_full", base)
	var tw2: Tween = (puppet.get("_weapon_fire_tweens") as Array)[0]
	tw2.pause()
	tw2.custom_step(busy + DaggerStabMath.RETURN + 0.05)
	assert(icon.position.distance_to(slot0) < 0.5, "chain_hold yoksa eskisi gibi hemen döner: %s" % icon.position)
	puppet.free()
