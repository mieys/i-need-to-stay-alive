extends Node

## Uzunkılıç (2026-09-26): etrafta dönen kılıç -> hedefe savrulan kılıç. Eski test_uzunkilic_orbit.gd'nin yerine.
## Ortak savuruş matematiği scripts/sword_swing_math.gd (weapon.gd + remote_player.gd aynı dosyayı kullanır).

const SwordSwingMath := preload("res://scripts/sword_swing_math.gd")


func test_sword_is_a_melee_weapon_now() -> void:
	var weapon: Node2D = (load("res://scenes/weapon_uzunkilic.tscn") as PackedScene).instantiate() as Node2D
	add_child(weapon)
	assert(weapon.get("_is_uzunkilic") == true, "Uzunkılıç kendini tanımalı")
	assert(weapon.melee == true, "Kılıç artık yakın dövüş silahı (hedefe savrulur), dönmez")
	assert(is_equal_approx(weapon.attack_range, 115.0), "Kılıç menzili 115: %s" % weapon.attack_range)
	assert(is_equal_approx(weapon.card_damage_bonus_ratio, 1.62), "Saldırı gücü oranı 1.62: %s" % weapon.card_damage_bonus_ratio)
	assert(not weapon.has_method("_process_uzunkilic_orbit"), "Eski yörünge kodu kaldırılmış olmalı")
	assert(weapon.hit_impact_scene != null and weapon.hit_impact_scene.resource_path == "res://scenes/fx_sword_hit.tscn",
		"Kılıç isabeti kendi çelik kesik efekti olmalı (eski kırmızı çizgiler değil)")
	weapon.queue_free()


func test_plan_sweeps_across_the_target() -> void:
	var target := Vector2(300.0, 100.0)
	var dir := Vector2(1.0, 0.0)
	var plan: Dictionary = SwordSwingMath.make_plan(dir, target, 1.0, 1.0, SwordSwingMath.REF_OWNER_SCALE)
	var pivot: Vector2 = plan["pivot"]
	## El (pivot) hedefin saldırana dönük tarafında, bıçak ucu hedefin biraz ötesinden geçer.
	assert(pivot.is_equal_approx(target - dir * SwordSwingMath.PIVOT_BACK), "pivot: %s" % pivot)
	assert(SwordSwingMath.TIP_RADIUS > SwordSwingMath.PIVOT_BACK, "bıçak ucu hedefin üstünden geçmeli")
	## Yay hedef yönüne göre simetrik, toplam 150 derece.
	assert(is_equal_approx(float(plan["a1"]) - float(plan["a0"]), SwordSwingMath.HALF_SPAN * 2.0))
	assert(is_equal_approx((float(plan["a0"]) + float(plan["a1"])) * 0.5, dir.angle()))
	## Ters yönlü savuruş aynı yayı öbür uçtan çizer.
	var back: Dictionary = SwordSwingMath.make_plan(dir, target, -1.0, 1.0, SwordSwingMath.REF_OWNER_SCALE)
	assert(is_equal_approx(float(back["a0"]), float(plan["a1"])) and is_equal_approx(float(back["a1"]), float(plan["a0"])))
	## Boyut: menzil/alan çarpanı ve sahibin ölçeği planı orantılı büyütür.
	var big: Dictionary = SwordSwingMath.make_plan(dir, target, 1.0, 2.0, SwordSwingMath.REF_OWNER_SCALE)
	assert(is_equal_approx(target.distance_to(big["pivot"]), SwordSwingMath.PIVOT_BACK * 2.0))


func test_contact_is_mid_sweep_and_scales_with_speed() -> void:
	var d1: float = SwordSwingMath.contact_delay(1.0)
	assert(is_equal_approx(d1, SwordSwingMath.APPROACH + SwordSwingMath.SWEEP * 0.5), "temas süpürmenin ortasında: %s" % d1)
	assert(is_equal_approx(SwordSwingMath.contact_delay(2.0), d1 * 0.5), "saldırı hızı 2 kat -> temas 2 kat erken")


func test_sweep_fx_matches_plan_and_mirrors() -> void:
	var dir := Vector2(0.0, 1.0)
	var plan: Dictionary = SwordSwingMath.make_plan(dir, Vector2(50.0, 80.0), -1.0, 1.0, SwordSwingMath.REF_OWNER_SCALE)
	var fx: AnimatedSprite2D = SwordSwingMath.spawn_sweep_fx(self, plan, 1.0)
	assert(fx != null, "hilal oluşmalı")
	assert(fx.global_position.is_equal_approx(plan["pivot"]))
	assert(is_equal_approx(fx.global_rotation, dir.angle()))
	assert(fx.flip_v, "ters yönlü savuruşta hilal aynalanmalı")
	assert(is_equal_approx(fx.global_scale.x, SwordSwingMath.TIP_RADIUS / SwordSwingMath.SWEEP_BAKED_RADIUS))
	assert(fx.is_playing() and not fx.sprite_frames.get_animation_loop("play"), "tek seferlik oynamalı")
	fx.queue_free()


func test_swing_moves_icon_along_arc_and_alternates() -> void:
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_uzunkilic.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	var side_before: float = weapon.get("_sword_side")
	weapon._start_sword_swing(Vector2.RIGHT, weapon.global_position + Vector2(80.0, 0.0))
	assert(not is_equal_approx(float(weapon.get("_sword_side")), side_before), "her savuruşta yay yönü değişmeli")
	var tw: Tween = weapon.get("_melee_swing_tween")
	assert(tw != null and tw.is_valid(), "savuruş tween'i çalışmalı")
	owner_node.queue_free()
