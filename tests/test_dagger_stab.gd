extends Node

## Bıçak "Kıvılcım Saplama" (madde 231; prototip madde 228 B): zikzak + boyalı X yerine üç saplama, pişmiş efekt, hasar
## parçaları temas anlarında. Ortak plan scripts/dagger_stab_math.gd (weapon.gd + remote_player.gd aynı dosyayı kullanır).

const DaggerStabMath := preload("res://scripts/dagger_stab_math.gd")


func test_only_the_dagger_uses_the_stab() -> void:
	for pair: Array in [["res://scenes/weapon_dagger.tscn", true], ["res://scenes/weapon_uzunkilic.tscn", false],
			["res://scenes/weapon_pence.tscn", false], ["res://scenes/weapon_topuz.tscn", false]]:
		var w: Node2D = (load(str(pair[0])) as PackedScene).instantiate() as Node2D
		add_child(w)
		assert(w.get("_is_dagger") == pair[1], "%s _is_dagger %s olmalı" % [pair[0], pair[1]])
		w.free()


func test_plan_stabs_into_the_target() -> void:
	var target := Vector2(300.0, 100.0)
	var dir := Vector2(1.0, 0.0)
	var plan: Dictionary = DaggerStabMath.make_plan(dir, target, 1.0, DaggerStabMath.REF_OWNER_SCALE)
	assert((plan["origin"] as Vector2).is_equal_approx(target - dir * DaggerStabMath.STRIKE_BACK), "vuruş merkezi hedefin 8 px önü")
	var stabs: Array = []
	var backs: Array = []
	for st: Array in DaggerStabMath.STEPS:
		if typeof(st[1]) == TYPE_NIL:
			continue
		(stabs if str(st[2]) == "in" else backs).append(DaggerStabMath.point(plan, st[1]))
	assert(stabs.size() == 3, "üç saplama: %d" % stabs.size())
	for b: Vector2 in backs:
		assert(b.x < target.x - 15.0, "geri çekiliş hedefin gerisinde: %s" % b)
	for s: Vector2 in stabs:
		assert(s.distance_to(target) < 10.0, "saplama ikonu hedefe girer (uç hedefte): %s" % s)
	assert((stabs[2] as Vector2).x > (stabs[0] as Vector2).x, "son saplama daha derin")
	## Çerçeve saldırı yönüyle döner; boyut çarpanı mesafeleri büyütür.
	var down: Dictionary = DaggerStabMath.make_plan(Vector2.DOWN, target, 1.0, DaggerStabMath.REF_OWNER_SCALE)
	assert(DaggerStabMath.point(down, Vector2(-14.0, 0.0)).is_equal_approx(target + Vector2(0.0, -22.0)), "aşağı saldırıda geri çekiliş yukarıda")
	var big: Dictionary = DaggerStabMath.make_plan(dir, target, 2.0, DaggerStabMath.REF_OWNER_SCALE)
	assert(is_equal_approx(target.distance_to(big["origin"]), DaggerStabMath.STRIKE_BACK * 2.0))


func test_contacts_match_the_steps_and_scale_with_speed() -> void:
	var t: float = 0.0
	var ends: Array = []
	for st: Array in DaggerStabMath.STEPS:
		t += float(st[0])
		if typeof(st[1]) != TYPE_NIL and str(st[2]) == "in":
			ends.append(t)
	assert(ends.size() == DaggerStabMath.CONTACTS.size())
	for i in ends.size():
		assert(is_equal_approx(float(ends[i]), float(DaggerStabMath.CONTACTS[i])), "temas %d saplama sonunda: %s / %s" % [i, ends[i], DaggerStabMath.CONTACTS[i]])
		assert(is_equal_approx(DaggerStabMath.contact_delay(i, 2.0), DaggerStabMath.contact_delay(i, 1.0) * 0.5), "hız 2 kat -> temas 2 kat erken")
	assert(is_equal_approx(DaggerStabMath.segment_gap(1.0), 0.1), "parçalar saplama aralığıyla (0,1 sn)")
	assert(DaggerStabMath.busy_duration(1.0) < 1.1111 / 0.7, "animasyon vuruş aralığına sığar")


func test_fx_sits_on_the_strike_center_and_rotates() -> void:
	var dir := Vector2(1.0, 1.0).normalized()
	var plan: Dictionary = DaggerStabMath.make_plan(dir, Vector2(50.0, 80.0), 1.0, DaggerStabMath.REF_OWNER_SCALE)
	var fx: AnimatedSprite2D = DaggerStabMath.spawn_fx(self, plan, 1.5)
	assert(fx != null, "efekt oluşmalı")
	assert(fx.global_position.is_equal_approx(plan["origin"]))
	assert(is_equal_approx(fx.global_rotation, dir.angle()))
	assert(is_equal_approx(fx.global_scale.x, DaggerStabMath.FX_WORLD_PX), "1 sanat px = 0,575 dünya px: %s" % fx.global_scale.x)
	assert(is_equal_approx(fx.speed_scale, 1.5), "efekt saldırı hızıyla hızlanır")
	assert(fx.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "piksel sanatı")
	var frames: SpriteFrames = fx.sprite_frames
	assert(frames.has_animation("play") and not frames.get_animation_loop("play"), "tek seferlik")
	assert(is_equal_approx(frames.get_animation_speed("play"), 30.0), "30 fps (pişirme zaman çizelgesi)")
	## Pişmiş sayfa saldırı başından itibaren: son saplama (0,33 sn) karesi sayfanın içinde kalmalı.
	assert(frames.get_frame_count("play") / 30.0 > float(DaggerStabMath.CONTACTS[2]) + 0.1, "sayfa son saplamadan sonra da sürer")
	fx.free()


func test_stab_moves_the_icon_through_the_stabs() -> void:
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_dagger.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	var target: Vector2 = weapon.global_position + Vector2(80.0, 0.0)
	weapon._start_dagger_stab(Vector2.RIGHT, target)
	var tw: Tween = weapon.get("_melee_swing_tween")
	assert(tw != null and tw.is_valid(), "saplama tween'i çalışmalı")
	tw.pause()
	var icon: Node2D = weapon.get("icon_sprite")
	var plan: Dictionary = DaggerStabMath.make_plan(Vector2.RIGHT, target, weapon._dagger_size_mult(), 0.5)
	var forward: float = deg_to_rad(float(weapon.get("sprite_forward_angle_deg")))
	tw.custom_step(float(DaggerStabMath.CONTACTS[0]))
	var p1: Vector2 = DaggerStabMath.point(plan, DaggerStabMath.STEPS[1][1])
	assert(icon.global_position.distance_to(p1) < 0.6, "1. temas anında ikon 1. saplama noktasında: %s / %s" % [icon.global_position, p1])
	assert(absf(angle_difference(icon.global_rotation + forward, (target - icon.global_position).angle())) < 0.02, "bıçak hedefe bakar")
	tw.custom_step(float(DaggerStabMath.CONTACTS[2]) - float(DaggerStabMath.CONTACTS[0]))
	var p3: Vector2 = DaggerStabMath.point(plan, DaggerStabMath.STEPS[7][1])
	assert(icon.global_position.distance_to(p3) < 0.6, "3. temas anında ikon derin saplamada: %s / %s" % [icon.global_position, p3])
	assert(icon.scale.x > float((weapon.get("_icon_base_scale") as Vector2).x) * 1.1, "son saplamada ölçek darbesi")
	tw.custom_step(2.0)
	assert(icon.position.is_equal_approx(Vector2.ZERO), "sonunda dinlenme yerine döner: %s" % icon.position)
	assert(icon.scale.is_equal_approx(weapon.get("_icon_base_scale")), "ölçek tabana döner")
	owner_node.free()


## MP: uzak kukla bıçağı yakın dövüş sayar (bayrak weapon.gd _ready'de - geçici kopya configure_melee görmez) ve "weapon_fire"
## verisiyle kasterle AYNI saplama noktalarına gider.
func test_puppet_plays_the_same_stab() -> void:
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate() as Node2D
	add_child(puppet)
	puppet.setup(77, 5, "Dost")
	puppet.global_position = Vector2(3000.0, 3000.0)
	puppet.call("update_weapon_visuals", ["dagger"])
	assert((puppet.get("_weapon_melee") as Array)[0] == true, "kukla bıçağı yakın dövüş saymalı")
	var target := Vector2(3080.0, 2990.0)
	var dir: Vector2 = (target - puppet.global_position).normalized()
	puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": dir.x, "direction_y": dir.y,
		"target_pos_x": target.x, "target_pos_y": target.y, "hold_duration": 0.0, "dagger_size": 1.0, "dagger_speed": 1.0})
	var tw: Tween = (puppet.get("_weapon_fire_tweens") as Array)[0]
	assert(tw != null and tw.is_valid(), "kukla saplama tween'i")
	tw.pause()
	tw.custom_step(float(DaggerStabMath.CONTACTS[0]))
	var icon: Node2D = (puppet.get("_weapon_icons") as Array)[0]
	var plan: Dictionary = DaggerStabMath.make_plan(dir, target, 1.0, puppet.scale.x)
	var p1: Vector2 = DaggerStabMath.point(plan, DaggerStabMath.STEPS[1][1])
	assert(icon.global_position.distance_to(p1) < 0.6, "kukla ikonu 1. saplama noktasında: %s / %s" % [icon.global_position, p1])
	puppet.free()


const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")


## Hasar parçaları saplama aralığıyla (seg_gap) gelir - ilk parça temas anında (_dagger_contact), kalanlar aralıkla.
func test_damage_segments_follow_the_stab_gap() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var weapon: Node2D = (load("res://scenes/weapon_dagger.tscn") as PackedScene).instantiate() as Node2D
	add_child(weapon)
	weapon.call("configure_melee", 110.0, 60.0, 0.5, [], "", 8.0, 0.0, 3, 1.0, -12.0, false, false)
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	e.global_position = Vector2(4000.0, 4000.0)
	e.set("speed", 0.0)
	e.set("max_health", 600000.0)
	e.set("health", 600000.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hp0: float = float(e.health)
	weapon.call("_dagger_contact", e, e.global_position, true, 90.0, false, 0.0, 0.06)
	var d1: float = hp0 - float(e.health)
	assert(d1 > 0.0, "ilk parça temas anında: %.2f" % d1)
	await get_tree().create_timer(0.03).timeout
	assert(absf(hp0 - float(e.health) - d1) < d1 * 0.05, "ikinci parça henüz gelmemeli (aralık 0,06)")
	await get_tree().create_timer(0.14).timeout
	var total: float = hp0 - float(e.health)
	assert(absf(total / d1 - 3.0) < 0.05, "üç eşit parça: %.2f / %.2f" % [total, d1])
	e.free()
	weapon.free()
	get_tree().current_scene = prev_scene
