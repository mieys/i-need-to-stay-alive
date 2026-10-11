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
	## NERF (2026-10-10, "kılıç inanılmaz güçlü"): 1,62 -> 1,2 (diğer yakın dövüş silahları 0,765-0,945 ile aynı atış aralığında).
	assert(is_equal_approx(weapon.card_damage_bonus_ratio, 1.2) and is_equal_approx(weapon.card_damage_bonus_ratio, weapon.SWORD_AP_RATIO), "Saldırı gücü oranı 1.2: %s" % weapon.card_damage_bonus_ratio)
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


const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")


## NERF: süpürülen alandaki ikincil hedefler artık ana hedefin %70'ini alır (eskiden %100), kılıç hasarı = saldırı gücü x 1,2.
func test_secondary_targets_take_70_percent_and_damage_scales_with_1_2_ap() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var PlayerScript: GDScript = load("res://scripts/player.gd")
	assert(is_equal_approx(float(PlayerScript.UZUNKILIC_AOE_PERCENT), 0.7), "alan hasarı yüzdesi 0,7")
	var weapon: Node2D = (load("res://scenes/weapon_uzunkilic.tscn") as PackedScene).instantiate() as Node2D
	add_child(weapon)
	weapon.call("configure_melee", 115.0, 55.0, float(PlayerScript.UZUNKILIC_AOE_PERCENT), [], "", 8.0, 0.0, 1, 1.0, -12.0, false, false)
	weapon.call("set_damage_bonus", 50.0)
	assert(is_equal_approx(float(weapon.get("damage")), 60.0), "kılıç hasarı = 50 x 1,2: %s" % weapon.get("damage"))
	var enemies: Array = []
	for off: Vector2 in [Vector2.ZERO, Vector2(20.0, 0.0), Vector2(0.0, 30.0)]:
		var e: Node2D = EnemyScene.instantiate()
		add_child(e)
		e.global_position = Vector2(4000.0, 4000.0) + off
		e.set("speed", 0.0)
		e.set("max_health", 600000.0)
		e.set("health", 600000.0)
		enemies.append(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hp0: float = float(enemies[0].health)
	weapon.call("_melee_strike", enemies[0], enemies[0].global_position, true, 100.0, false, 0.0)
	var primary: float = hp0 - float(enemies[0].health)
	var side1: float = hp0 - float(enemies[1].health)
	var side2: float = hp0 - float(enemies[2].health)
	assert(primary > 0.0 and side1 > 0.0 and side2 > 0.0, "ana hedef ve çevresindekiler hasar alır: %.1f / %.1f / %.1f" % [primary, side1, side2])
	assert(absf(side1 / primary - 0.7) < 0.02 and absf(side2 / primary - 0.7) < 0.02, "ikincil hedefler ana hasarın %%70'ini alır: %.3f / %.3f" % [side1 / primary, side2 / primary])
	for e: Node in enemies:
		e.free()
	weapon.free()
	get_tree().current_scene = prev_scene
