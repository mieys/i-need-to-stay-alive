extends Node

## Topuz "Yer Sarsıntısı" (madde 235; prototip madde 232 A): yana park + turuncu halka yerine kaldır-indir, pişmiş iz/yer/üst
## efekti, hasar temas anında. Ortak plan scripts/topuz_slam_math.gd (weapon.gd + remote_player.gd aynı dosyayı kullanır).

const TopuzSlamMath := preload("res://scripts/topuz_slam_math.gd")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const CONTACT_HEAD := Vector2(-4.0, 1.0)


## İkonun dönüşümünden başın dünya noktası (tutma noktası + erim x baş yönü; ezilmesiz anlarda).
func _head_of(icon: Sprite2D, forward: float) -> Vector2:
	var art: float = icon.texture.get_width() / TopuzSlamMath.ART_SIZE
	var off: Vector2 = (Vector2(TopuzSlamMath.ART_SIZE, TopuzSlamMath.ART_SIZE) * 0.5 - TopuzSlamMath.GRIP_PX) * art
	var grip: Vector2 = TopuzSlamMath.grip_of(icon, off)
	var texel: float = icon.global_scale.x
	return grip + Vector2.from_angle(icon.global_rotation + forward) * TopuzSlamMath.HEAD_REACH_PX * art * texel


func test_only_the_mace_uses_the_slam() -> void:
	for pair: Array in [["res://scenes/weapon_topuz.tscn", true], ["res://scenes/weapon_uzunkilic.tscn", false],
			["res://scenes/weapon_pence.tscn", false], ["res://scenes/weapon_dagger.tscn", false]]:
		var w: Node2D = (load(str(pair[0])) as PackedScene).instantiate() as Node2D
		add_child(w)
		assert(w.get("_is_topuz") == pair[1], "%s _is_topuz %s olmalı" % [pair[0], pair[1]])
		if pair[1]:
			assert(w.get("melee") == true, "topuz configure_melee görmeden yakın dövüş (kukla kopyası için)")
		w.free()


func test_plan_lands_the_head_on_the_target_and_mirrors() -> void:
	var target := Vector2(300.0, 100.0)
	var plan: Dictionary = TopuzSlamMath.make_plan(Vector2(1.0, 0.3), target, 1.0, TopuzSlamMath.REF_OWNER_SCALE)
	var hit: Vector2 = TopuzSlamMath.point(plan, CONTACT_HEAD)
	assert(hit.distance_to(target) < 6.0, "baş hedefe iner: %s" % hit)
	var lift: Vector2 = TopuzSlamMath.point(plan, TopuzSlamMath.STEPS[1][1])
	assert(lift.y < target.y - 35.0 and lift.x < target.x - 30.0, "geri gerilmede baş hedefin üstünde ve oyuncu tarafında: %s" % lift)
	## Sola saldırıda x ve açı aynalanır; çerçeve dönmez (yukarı/aşağı saldırıda da baş üstten iner).
	var left: Dictionary = TopuzSlamMath.make_plan(Vector2(-1.0, 0.2), target, 1.0, TopuzSlamMath.REF_OWNER_SCALE)
	var lift_l: Vector2 = TopuzSlamMath.point(left, TopuzSlamMath.STEPS[1][1])
	assert(is_equal_approx(lift_l.x - target.x, -(lift.x - target.x)) and is_equal_approx(lift_l.y, lift.y), "sola saldırı aynalı: %s" % lift_l)
	assert(is_equal_approx(TopuzSlamMath.angle(left, 40.0), PI - deg_to_rad(40.0)))
	var down: Dictionary = TopuzSlamMath.make_plan(Vector2.DOWN, target, 1.0, TopuzSlamMath.REF_OWNER_SCALE)
	assert(TopuzSlamMath.point(down, TopuzSlamMath.STEPS[1][1]).is_equal_approx(lift), "aşağı saldırıda da kaldırış üstte")
	## Boyut çarpanı (alan çarpanları) mesafeleri büyütür; efekt dalgası k = 1'de alan sınırına (95) gider.
	var big: Dictionary = TopuzSlamMath.make_plan(Vector2.RIGHT, target, 2.0, TopuzSlamMath.REF_OWNER_SCALE)
	assert(is_equal_approx(float(big["k"]), 2.0))


func test_timeline_and_speed() -> void:
	var t: float = 0.0
	for i in range(TopuzSlamMath.STEPS.size()):
		t += float(TopuzSlamMath.STEPS[i][0])
		if i == 1:
			assert(is_equal_approx(t, TopuzSlamMath.SMEAR_AT), "iz inişin başında: %s" % t)
		if i == 2:
			assert(is_equal_approx(t, TopuzSlamMath.CONTACT), "temas inişin sonunda: %s" % t)
	assert(is_equal_approx(TopuzSlamMath.contact_delay(2.0), TopuzSlamMath.contact_delay(1.0) * 0.5), "hız 2 kat -> temas 2 kat erken")
	assert(TopuzSlamMath.busy_duration(1.0) + TopuzSlamMath.RETURN < 1.1111 / 0.7, "animasyon vuruş aralığına sığar")


func test_fx_layers() -> void:
	var plan: Dictionary = TopuzSlamMath.make_plan(Vector2(-1.0, 0.0), Vector2(50.0, 80.0), 1.0, TopuzSlamMath.REF_OWNER_SCALE)
	for spec: Array in [[TopuzSlamMath.GroundFxScene, -1, 30.0, true], [TopuzSlamMath.TopFxScene, 60, 30.0, false],
			[TopuzSlamMath.SmearFxScene, 0, 60.0, false]]:
		var fx: AnimatedSprite2D = TopuzSlamMath.spawn_fx(spec[0], self, plan, 1.5)
		assert(fx != null, "efekt oluşmalı")
		assert(fx.global_position.is_equal_approx(plan["origin"]))
		assert(is_zero_approx(fx.global_rotation), "efekt dönmez")
		assert(fx.flip_h, "sola saldırıda aynalı")
		assert(is_equal_approx(fx.global_scale.x, TopuzSlamMath.FX_WORLD_PX), "1 sanat px = 0,575 dünya px: %s" % fx.global_scale.x)
		assert(is_equal_approx(fx.speed_scale, 1.5), "efekt saldırı hızıyla hızlanır")
		assert(fx.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "piksel sanatı")
		assert(fx.z_index == int(spec[1]), "z %d olmalı: %d" % [spec[1], fx.z_index])
		var frames: SpriteFrames = fx.sprite_frames
		assert(frames.has_animation("play") and not frames.get_animation_loop("play"), "tek seferlik")
		assert(is_equal_approx(frames.get_animation_speed("play"), float(spec[2])), "pişirme fps'i")
		assert((fx.get_node_or_null("Sound") != null) == bool(spec[3]), "darbe sesi yalnız yer katmanında (temasta)")
		## Kareler merkeze göre simetrik kırpıldı (flip_h aynalaması merkez etrafında doğru olsun).
		var tex: Texture2D = frames.get_frame_texture("play", 0)
		assert(tex.get_width() % 2 == 0, "kare genişliği çift (merkez = hedef)")
		fx.free()


func test_slam_moves_the_icon_and_spawns_fx_on_time() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_topuz.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	var target: Vector2 = weapon.global_position + Vector2(90.0, 10.0)
	var before: int = get_child_count()
	weapon._start_topuz_slam(Vector2.RIGHT, target)
	var tw: Tween = weapon.get("_melee_swing_tween")
	assert(tw != null and tw.is_valid(), "vuruş tween'i çalışmalı")
	tw.pause()
	var icon: Sprite2D = weapon.get("icon_sprite")
	var forward: float = deg_to_rad(float(weapon.get("sprite_forward_angle_deg")))
	var plan: Dictionary = TopuzSlamMath.make_plan(Vector2.RIGHT, target, weapon._topuz_size_mult(), 0.5)
	tw.custom_step(TopuzSlamMath.SMEAR_AT - 0.001)
	var lift: Vector2 = _head_of(icon, forward)
	assert(lift.distance_to(TopuzSlamMath.point(plan, TopuzSlamMath.STEPS[1][1])) < 1.0, "geri gerilmede baş yukarıda: %s" % lift)
	assert(get_child_count() == before, "iz henüz çıkmamalı")
	tw.custom_step(0.002)
	assert(get_child_count() == before + 1, "iz inişin başında çıkar")
	tw.custom_step(TopuzSlamMath.CONTACT - TopuzSlamMath.SMEAR_AT - 0.001) ## tam temas anı (iniş sonu hızlı: 1 ms = ~2 px)
	var hit: Vector2 = _head_of(icon, forward)
	var want: Vector2 = TopuzSlamMath.point(plan, CONTACT_HEAD)
	assert(hit.distance_to(want) < 1.0, "temas anında baş hedefte: %s / %s" % [hit, want])
	tw.custom_step(0.002)
	assert(get_child_count() == before + 3, "temasta yer + üst efekti")
	tw.custom_step(0.02)
	assert(absf(icon.skew) > 0.001 or not icon.scale.is_equal_approx(weapon.get("_icon_base_scale")), "tutuklukta topuz ezilir")
	tw.custom_step(2.0)
	assert(icon.position.is_equal_approx(Vector2.ZERO), "sonunda dinlenme yerine döner: %s" % icon.position)
	assert(icon.scale.is_equal_approx(weapon.get("_icon_base_scale")), "ölçek tabana döner")
	assert(is_zero_approx(icon.skew), "çarpıklık sıfırlanır")
	assert(absf(angle_difference(icon.rotation, deg_to_rad(float(weapon.get("melee_icon_rest_rotation_deg"))))) < 0.01, "dinlenme açısı")
	owner_node.free()
	for c in get_children():
		c.free()
	get_tree().current_scene = prev_scene


## MP: uzak kukla topuzu yakın dövüş sayar (bayrak weapon.gd _ready'de - geçici kopya configure_melee görmez) ve "weapon_fire"
## verisiyle kasterle AYNI noktaya iner.
func test_puppet_plays_the_same_slam() -> void:
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate() as Node2D
	add_child(puppet)
	puppet.setup(77, 5, "Dost")
	puppet.global_position = Vector2(3000.0, 3000.0)
	puppet.call("update_weapon_visuals", ["topuz"])
	assert((puppet.get("_weapon_melee") as Array)[0] == true, "kukla topuzu yakın dövüş saymalı")
	var target := Vector2(2920.0, 3010.0) ## sola saldırı
	var dir: Vector2 = (target - puppet.global_position).normalized()
	puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": dir.x, "direction_y": dir.y,
		"target_pos_x": target.x, "target_pos_y": target.y, "hold_duration": 0.0, "topuz_size": 1.0, "topuz_speed": 1.0})
	var tw: Tween = (puppet.get("_weapon_fire_tweens") as Array)[0]
	assert(tw != null and tw.is_valid(), "kukla vuruş tween'i")
	tw.pause()
	tw.custom_step(TopuzSlamMath.CONTACT)
	var icon: Sprite2D = (puppet.get("_weapon_icons") as Array)[0]
	var forward: float = deg_to_rad(float((puppet.get("_weapon_forward_angle_deg") as Array)[0]))
	var plan: Dictionary = TopuzSlamMath.make_plan(dir, target, 1.0, puppet.scale.x)
	var want: Vector2 = TopuzSlamMath.point(plan, CONTACT_HEAD)
	assert(_head_of(icon, forward).distance_to(want) < 1.0, "kukla başı aynı noktaya iner: %s / %s" % [_head_of(icon, forward), want])
	puppet.free()


## Hasar temas anında (_topuz_contact): ana hedef tam, alandaki ikinci yaratık yarı hasar.
func test_contact_hits_target_and_area() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var weapon: Node2D = (load("res://scenes/weapon_topuz.tscn") as PackedScene).instantiate() as Node2D
	add_child(weapon)
	weapon.call("configure_melee", 120.0, 95.0, 0.5, [], "res://scenes/fx_topuz_slash.tscn", 8.0, 0.0, 1, 1.0, -12.0, true, true)
	var foes: Array = []
	for p: Vector2 in [Vector2(4000.0, 4000.0), Vector2(4050.0, 4020.0)]:
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
	weapon.call("_topuz_contact", foes[0], (foes[0] as Node2D).global_position, true, 100.0, false, 0.0, Vector2.RIGHT)
	var d0: float = float(hp0[0]) - float(foes[0].health)
	var d1: float = float(hp0[1]) - float(foes[1].health)
	assert(d0 > 0.0, "ana hedef temasta hasar alır")
	assert(absf(d1 / d0 - 0.5) < 0.05, "alandaki yaratık yarı hasar: %.2f / %.2f" % [d1, d0])
	for c in get_children():
		c.free()
	get_tree().current_scene = prev_scene


## Madde 239 (kullanıcı: "topuzun efsununun patlama alanı topuzun vuruşunun merkezinde olmalı karakterin merkezinde değil"):
## Sismik Dalga ana hedefin konumunda açılır - hedefin yanındaki yaratık vurulur, karakterin yanındaki (hedeften uzak) vurulmaz.
func test_seismic_wave_opens_on_the_strike_point() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	var saved: Array = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("topuz", 1, 0)]
	var p: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(p)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	p.global_position = Vector2(3000.0, 3000.0)
	p.max_health = 100000.0
	p.health = 100000.0
	assert(p.buy_weapon_copy("topuz", 1))
	var beh: Node = p.owned_weapon_nodes[0].get("enchant_behavior")
	assert(beh != null and str((beh.get("stats") as Dictionary).get("id", "")) == "sismik_dalga", "topuzun özelliği Sismik Dalga")
	(beh.get("stats") as Dictionary)["seis_chance"] = 1.0
	var r: float = float(beh.call("f", "seis_radius", 110.0))
	var foes: Array = []
	for pos: Vector2 in [Vector2(3110.0, 3000.0), Vector2(3110.0 + r * 0.8, 3000.0), Vector2(3000.0 - r * 0.6, 3000.0)]:
		var e: Node2D = EnemyScene.instantiate()
		add_child(e)
		e.global_position = pos
		e.set("speed", 0.0)
		e.max_health = 600000.0
		e.health = 600000.0
		foes.append(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	beh.call("hit_extra", foes[0], 10.0, true, null)
	await get_tree().physics_frame
	assert(float(foes[1].health) < 600000.0, "hedefin yanındaki (karakterden %d px) dalgayla vurulur" % int(110.0 + r * 0.8))
	assert(is_equal_approx(float(foes[2].health), 600000.0), "karakterin yanındaki (hedeften %d px) vurulmaz" % int(110.0 + r * 0.6))
	for n in foes + [p]:
		if is_instance_valid(n):
			n.free()
	GameManager.owned_weapons = saved
	get_tree().current_scene = prev_scene


## 2026-10-19 (maç analizi): dalga hedef sınırı - merkeze en yakın 8 düşman tam hasar, sonrakiler %35. Sarsma herkese uygulanır.
func test_seismic_wave_caps_full_damage_targets() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = 1
	GameManager.selected_character = int(Characters.DEFS[1]["skill"])
	var saved: Array = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("topuz", 1, 0)]
	var p: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	add_child(p)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	p.global_position = Vector2(3000.0, 3000.0)
	p.max_health = 100000.0
	p.health = 100000.0
	p.damage_bonus = 1000.0
	assert(p.buy_weapon_copy("topuz", 1))
	var beh: Node = p.owned_weapon_nodes[0].get("enchant_behavior")
	(beh.get("stats") as Dictionary)["seis_chance"] = 1.0
	var foes: Array = []
	for i in range(12): ## hepsi 110 birimlik yarıçap içinde; i büyüdükçe merkezden uzaklaşır
		var e: Node2D = EnemyScene.instantiate()
		add_child(e)
		e.global_position = Vector2(3110.0 + 6.0 * float(i), 3000.0)
		e.set("speed", 0.0)
		e.max_health = 600000.0
		e.health = 600000.0
		foes.append(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	beh.call("hit_extra", foes[0], 10.0, true, null)
	await get_tree().physics_frame
	var full_loss: float = 600000.0 - float(foes[0].health)
	assert(full_loss > 100.0, "ana hedef dalgayla vurulur: %s" % full_loss)
	for i in range(8):
		assert(is_equal_approx(600000.0 - float(foes[i].health), full_loss), "ilk 8 düşman tam hasar alır (#%d): %s" % [i, 600000.0 - float(foes[i].health)])
	for i in range(8, 12):
		var loss: float = 600000.0 - float(foes[i].health)
		assert(loss > 0.0 and absf(loss - full_loss * 0.35) < full_loss * 0.01, "9. ve sonrası %%35 hasar alır (#%d): %s / %s" % [i, loss, full_loss])
	for n in foes + [p]:
		if is_instance_valid(n):
			n.free()
	GameManager.owned_weapons = saved
	get_tree().current_scene = prev_scene
