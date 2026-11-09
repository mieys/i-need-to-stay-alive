extends Node

## Tırpan "Kara Hasat" (madde 512; prototip madde 507 v2 D3): eski Pençe'nin Kanca Çekiş'i yerine saptan dönen 260 derecelik biçme,
## hayalet bıçak + koyu hilal + kesik/kor + saydam duman (pişmiş), iki hasar parçası temas anlarında, sola saldırıda ikon aynalı
## (bıçak önde). Ortak plan scripts/tirpan_reap_math.gd (weapon.gd + remote_player.gd aynı dosyayı kullanır).

const TirpanReapMath := preload("res://scripts/tirpan_reap_math.gd")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const BLADE_TIP_PX := Vector2(31.0, 30.5) ## tirpan.png bıçak ucu (prototip BLADE_PX son nokta)


func _tip_world(icon: Sprite2D) -> Vector2:
	var sz: Vector2 = icon.texture.get_size()
	var p: Vector2 = BLADE_TIP_PX - sz * 0.5
	if icon.flip_h:
		p.x = -p.x
	return icon.global_transform * p


func test_only_the_scythe_reaps_and_mirrors() -> void:
	for pair: Array in [["res://scenes/weapon_pence.tscn", true], ["res://scenes/weapon_topuz.tscn", false],
			["res://scenes/weapon_uzunkilic.tscn", false], ["res://scenes/weapon_dagger.tscn", false]]:
		var w: Node2D = (load(str(pair[0])) as PackedScene).instantiate() as Node2D
		add_child(w)
		assert(w.get("_is_pence") == pair[1], "%s _is_pence %s olmalı" % [pair[0], pair[1]])
		if pair[1]:
			assert(w.get("melee") == true, "tırpan configure_melee görmeden yakın dövüş (kukla kopyası için)")
			assert(w.get("mirror_icon_when_aiming_left") == true, "tırpan sola bakınca aynalanır (bıçak önde)")
		w.free()
	assert(not ResourceLoader.exists("res://scripts/pence_hook_math.gd"), "eski Kanca Çekiş silindi")


func test_plan_and_mirror() -> void:
	var r: Dictionary = TirpanReapMath.make_plan(Vector2(1.0, 0.0), Vector2(100.0, 50.0), 1.0, TirpanReapMath.REF_OWNER_SCALE)
	var l: Dictionary = TirpanReapMath.make_plan(Vector2(-1.0, 0.0), Vector2(100.0, 50.0), 1.0, TirpanReapMath.REF_OWNER_SCALE)
	assert((r["origin"] as Vector2).is_equal_approx(Vector2(100.0, 50.0) + TirpanReapMath.ANCHOR))
	assert(float(r["side"]) == 1.0 and float(l["side"]) == -1.0)
	var p := Vector2(-22.0, 2.0)
	assert(TirpanReapMath.point(r, p).is_equal_approx(Vector2(78.0, 48.5)), "sağa: %s" % TirpanReapMath.point(r, p))
	assert(TirpanReapMath.point(l, p).is_equal_approx(Vector2(122.0, 48.5)), "sola aynalı: %s" % TirpanReapMath.point(l, p))
	assert(absf(angle_difference(TirpanReapMath.angle(r, 98.0), deg_to_rad(98.0))) < 0.001)
	assert(absf(angle_difference(TirpanReapMath.angle(l, 98.0), PI - deg_to_rad(98.0))) < 0.001, "sola: açı aynalı")
	var big: Dictionary = TirpanReapMath.make_plan(Vector2.RIGHT, Vector2.ZERO, 1.5, 1.0)
	assert(is_equal_approx(float(big["k"]), 3.0) and is_equal_approx(float(big["size"]), 1.5), "boyut + sahip ölçeği")


func test_timeline_and_speed() -> void:
	assert(is_equal_approx(TirpanReapMath.busy_duration(1.0), 0.43))
	assert(is_equal_approx(TirpanReapMath.busy_duration(2.0), 0.215), "doğrusal hızlanır (iz sayfası bıçakla aynı saatte)")
	var t0: float = float(TirpanReapMath.STEPS[0][0]) + float(TirpanReapMath.STEPS[1][0])
	var t1: float = t0 + float(TirpanReapMath.STEPS[2][0])
	assert(is_equal_approx(TirpanReapMath.FX_AT, float(TirpanReapMath.STEPS[0][0])), "efektler 1. adımın sonunda")
	for c in TirpanReapMath.CONTACTS:
		assert(float(c) > t0 and float(c) <= t1 + 0.0001, "temaslar biçme adımında: %s" % c)
	assert(is_equal_approx(TirpanReapMath.contact_delay(0, 2.0), float(TirpanReapMath.CONTACTS[0]) / 2.0))
	assert(TirpanReapMath.segment_gap(1.0) > 0.0)
	assert(float(TirpanReapMath.STEPS[2][2]) - float(TirpanReapMath.STEPS[1][2]) >= 250.0, "geniş açılı biçme (260 derece)")
	assert(TirpanReapMath.rest_pose(-0.5, true, true) == [0.5, true] and TirpanReapMath.rest_pose(-0.5, true, false) == [-0.5, false])
	assert(TirpanReapMath.rest_pose(-0.5, false, true) == [-0.5, false], "aynalanmayan ikon dokunulmaz")


func test_fx_layers() -> void:
	var plan: Dictionary = TirpanReapMath.make_plan(Vector2(-1.0, 0.0), Vector2(50.0, 80.0), 1.0, TirpanReapMath.REF_OWNER_SCALE)
	for spec: Array in [[TirpanReapMath.TrailFxScene, 0, 60.0], [TirpanReapMath.TopFxScene, 60, 30.0], [TirpanReapMath.GroundFxScene, -1, 30.0]]:
		var fx: AnimatedSprite2D = TirpanReapMath.spawn_fx(spec[0], self, plan, 1.5)
		assert(fx != null, "efekt oluşmalı")
		assert(fx.global_position.is_equal_approx(plan["origin"]))
		assert(absf(angle_difference(fx.global_rotation, PI)) < 0.001, "efekt saldırı yönüyle döner: %s" % fx.global_rotation)
		assert(fx.flip_v, "sola saldırıda dikey aynalı")
		assert(is_equal_approx(absf(fx.global_scale.x), TirpanReapMath.FX_WORLD_PX), "1 sanat px = 0,575 dünya px")
		assert(is_equal_approx(fx.speed_scale, 1.5), "efekt saldırı hızıyla hızlanır")
		assert(fx.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "piksel sanatı")
		assert(fx.z_index == int(spec[1]), "z %d olmalı: %d" % [spec[1], fx.z_index])
		var frames: SpriteFrames = fx.sprite_frames
		assert(frames.has_animation("play") and not frames.get_animation_loop("play"), "tek seferlik")
		assert(is_equal_approx(frames.get_animation_speed("play"), float(spec[2])), "pişirme fps'i")
		var tex: Texture2D = frames.get_frame_texture("play", 0)
		assert(tex != null and tex.get_width() % 2 == 0 and tex.get_height() % 2 == 0, "kare boyu çift (merkez = orijin)")
		fx.free()
	## duman çabuk söner (kullanıcı: "dumanlar daha çabuk solsun"): yer katmanı 0,4 sn'yi geçmez
	var gf: SpriteFrames = (TirpanReapMath.GroundFxScene.instantiate() as AnimatedSprite2D).sprite_frames
	assert(gf.get_frame_count("play") / gf.get_animation_speed("play") <= 0.4, "duman %d kare" % gf.get_frame_count("play"))


func _reap_weapon() -> Array:
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_pence.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	weapon.scale = owner_node.scale ## silah top_level: oyunda _update_hover_follow her karede sahip ölçeğini verir (test kare işlemez)
	return [owner_node, weapon]


func test_reap_moves_the_icon_and_spawns_fx_on_time() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	for dx: float in [90.0, -90.0]:
		var pair: Array = _reap_weapon()
		var weapon: Node2D = pair[1]
		var target: Vector2 = weapon.global_position + Vector2(dx, 10.0)
		var before: int = get_child_count()
		weapon._start_tirpan_reap((target - weapon.global_position).normalized(), target)
		var tw: Tween = weapon.get("_melee_swing_tween")
		assert(tw != null and tw.is_valid(), "vuruş tween'i çalışmalı")
		tw.pause()
		var icon: Sprite2D = weapon.get("icon_sprite")
		assert(icon.flip_h == (dx < 0.0), "sola saldırıda ikon aynalı (bıçak önde)")
		assert(weapon.get("_icon_flipped") == (dx < 0.0), "nişan kuralı aynalamayı bilir")
		tw.custom_step(TirpanReapMath.FX_AT - 0.001)
		assert(get_child_count() == before, "efektler henüz çıkmamalı")
		tw.custom_step(0.002)
		assert(get_child_count() == before + 3, "iz + üst + yer katmanı gerilmenin başında: %d" % (get_child_count() - before))
		tw.custom_step(float(TirpanReapMath.CONTACTS[0]) - TirpanReapMath.FX_AT - 0.001)
		var plan: Dictionary = TirpanReapMath.make_plan((target - weapon.global_position).normalized(), target, weapon._pence_size_mult(), 0.5)
		var tip: Vector2 = _tip_world(icon)
		assert(tip.distance_to(plan["origin"]) < 6.0 * float(plan["k"]), "1. temasta bıçağın ucu hedefte (%s): %s / %s" % [dx, tip, plan["origin"]])
		tw.custom_step(2.0)
		assert(icon.position.is_equal_approx(Vector2.ZERO), "sonunda dinlenme yerine döner: %s" % icon.position)
		assert(icon.scale.is_equal_approx(weapon.get("_icon_base_scale")), "ölçek tabana döner")
		var rest: float = deg_to_rad(float(weapon.get("melee_icon_rest_rotation_deg")))
		assert(absf(angle_difference(icon.rotation, -rest if dx < 0.0 else rest)) < 0.01, "dinlenme açısı (aynalıda -rest)")
		assert(absf(angle_difference(icon.rotation + TirpanReapMath.forward_of(deg_to_rad(float(weapon.get("sprite_forward_angle_deg"))), icon.flip_h),
			-PI / 2.0)) < 0.01, "sap dinlenmede dik")
		(pair[0] as Node).free()
		for c in get_children():
			c.free()
	get_tree().current_scene = prev_scene


## MP: uzak kukla "weapon_fire" verisiyle kasterle AYNI planı oynar - bıçak ucu aynı anda aynı noktada, sola aynalı.
func test_puppet_plays_the_same_reap() -> void:
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate() as Node2D
	add_child(puppet)
	puppet.setup(77, 5, "Dost")
	puppet.global_position = Vector2(3000.0, 3000.0)
	puppet.call("update_weapon_visuals", ["pence"])
	assert((puppet.get("_weapon_melee") as Array)[0] == true, "kukla tırpanı yakın dövüş saymalı")
	assert((puppet.get("_weapon_mirror_aim") as Array)[0] == true, "kukla aynalama bayrağını sahneden okur")
	var target := Vector2(2920.0, 3010.0) ## sola saldırı
	var dir: Vector2 = (target - puppet.global_position).normalized()
	puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": dir.x, "direction_y": dir.y,
		"target_pos_x": target.x, "target_pos_y": target.y, "hold_duration": 0.0, "pence_size": 1.0, "pence_speed": 1.0})
	var tw: Tween = (puppet.get("_weapon_fire_tweens") as Array)[0]
	assert(tw != null and tw.is_valid(), "kukla vuruş tween'i")
	tw.pause()
	tw.custom_step(float(TirpanReapMath.CONTACTS[0]) - 0.0005)
	var icon: Sprite2D = (puppet.get("_weapon_icons") as Array)[0]
	assert(icon.flip_h and (puppet.get("_weapon_icon_flipped") as Array)[0] == true, "kukla ikonu sola aynalı")
	var plan: Dictionary = TirpanReapMath.make_plan(dir, target, 1.0, puppet.scale.x)
	var tip: Vector2 = _tip_world(icon)
	assert(tip.distance_to(plan["origin"]) < 6.0 * float(plan["k"]), "kukla tırpanı aynı noktayı biçer: %s / %s" % [tip, plan["origin"]])
	puppet.free()


## Hasar temas anlarında (_pence_contact): ana hedef 2 parça (bıçak geçişi + seg_gap sonra biçme sonu), alandaki yaratık yarı hasar.
func test_contact_hits_target_twice_and_area() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var weapon: Node2D = (load("res://scenes/weapon_pence.tscn") as PackedScene).instantiate() as Node2D
	add_child(weapon)
	weapon.call("configure_melee", 110.0, 80.0, 0.5, [], "res://scenes/fx_pence_slash.tscn", 8.0, 0.0, 2, 1.0, -12.0, false, false)
	var foes: Array = []
	for p: Vector2 in [Vector2(4000.0, 4000.0), Vector2(4040.0, 4020.0)]:
		var e: Node2D = EnemyScene.instantiate()
		add_child(e)
		e.global_position = p
		e.set("speed", 0.0)
		e.set("max_health", 600000.0)
		e.set("health", 600000.0)
		foes.append(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hp0: Array = foes.map(func(e: Node2D) -> float: return float(e.health))
	weapon.call("_pence_contact", foes[0], (foes[0] as Node2D).global_position, true, 100.0, false, 0.0,
		TirpanReapMath.segment_gap(1.0), Vector2.RIGHT)
	var first: float = float(hp0[0]) - float(foes[0].health)
	assert(first > 0.0, "ana hedef bıçak geçişinde hasar alır")
	await get_tree().create_timer(0.12).timeout
	var d0: float = float(hp0[0]) - float(foes[0].health)
	var d1: float = float(hp0[1]) - float(foes[1].health)
	assert(absf(d0 / first - 2.0) < 0.05, "2. parça biçme sonunda gelir: %.2f / %.2f" % [d0, first])
	assert(absf(d1 / d0 - 0.5) < 0.05, "alandaki yaratık yarı hasar: %.2f / %.2f" % [d1, d0])
	for c in get_children():
		c.free()
	get_tree().current_scene = prev_scene
