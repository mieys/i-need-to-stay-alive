extends Node

## Pençe "Kanca Çekiş" (madde 237; prototip madde 236 B): yana süpürme + iri pembe çizgiler yerine atıl-saplan-çekerek yırt,
## pişmiş iz/üst/yer efekti, iki hasar parçası temas anlarında. Ortak plan scripts/pence_hook_math.gd (weapon.gd + remote_player.gd
## aynı dosyayı kullanır).

const PenceHookMath := preload("res://scripts/pence_hook_math.gd")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const DIG := Vector2(4.0, 0.0) ## saplanmada ikon merkezi (STEPS[1])


func test_only_the_claw_uses_the_hook() -> void:
	for pair: Array in [["res://scenes/weapon_pence.tscn", true], ["res://scenes/weapon_topuz.tscn", false],
			["res://scenes/weapon_uzunkilic.tscn", false], ["res://scenes/weapon_dagger.tscn", false]]:
		var w: Node2D = (load(str(pair[0])) as PackedScene).instantiate() as Node2D
		add_child(w)
		assert(w.get("_is_pence") == pair[1], "%s _is_pence %s olmalı" % [pair[0], pair[1]])
		if pair[1]:
			assert(w.get("melee") == true, "pençe configure_melee görmeden yakın dövüş (kukla kopyası için)")
		w.free()


func test_plan_pounces_into_the_target_and_mirrors() -> void:
	var target := Vector2(300.0, 100.0)
	var dir := Vector2(1.0, 0.3).normalized()
	var plan: Dictionary = PenceHookMath.make_plan(dir, target, 1.0, PenceHookMath.REF_OWNER_SCALE)
	var dig: Vector2 = PenceHookMath.point(plan, DIG)
	assert(dig.distance_to(target) < 8.0, "pençe hedefe saplanır: %s" % dig)
	assert((dig - target).dot(dir) > 0.0, "saplanma hedefin biraz gerisinde (içinde)")
	var crouch: Vector2 = PenceHookMath.point(plan, PenceHookMath.STEPS[0][1])
	assert((crouch - target).dot(dir) < -20.0, "geri sinme oyuncu tarafında: %s" % crouch)
	var rip: Vector2 = PenceHookMath.point(plan, PenceHookMath.STEPS[5][1])
	assert((rip - dig).dot(dir) < -25.0, "yırtma oyuncuya doğru çeker: %s" % rip)
	## Sola saldırıda çerçeve yönle döner + dikte aynalanır: sağa saldırının yatay aynası (yükseklik aynı).
	var right: Dictionary = PenceHookMath.make_plan(Vector2.RIGHT, target, 1.0, PenceHookMath.REF_OWNER_SCALE)
	var left: Dictionary = PenceHookMath.make_plan(Vector2.LEFT, target, 1.0, PenceHookMath.REF_OWNER_SCALE)
	var o: Vector2 = right["origin"]
	for p: Vector2 in [PenceHookMath.STEPS[0][1], PenceHookMath.STEPS[4][1]]:
		var r: Vector2 = PenceHookMath.point(right, p) - o
		var l: Vector2 = PenceHookMath.point(left, p) - o
		assert(l.is_equal_approx(Vector2(-r.x, r.y)), "sola saldırı sağın aynası: %s / %s" % [l, r])
	assert(is_equal_approx(wrapf(PenceHookMath.angle(left, 12.0), -PI, PI), wrapf(PI - deg_to_rad(12.0), -PI, PI)))
	var big: Dictionary = PenceHookMath.make_plan(Vector2.RIGHT, target, 2.0, PenceHookMath.REF_OWNER_SCALE)
	assert(is_equal_approx(float(big["k"]), 2.0))


func test_timeline_and_speed() -> void:
	var t: float = 0.0
	var starts: Array = []
	for st: Array in PenceHookMath.STEPS:
		starts.append(t)
		t += float(st[0])
	assert(is_equal_approx(float(starts[1]), PenceHookMath.SMEAR_AT), "iz atılışın başında")
	assert(is_equal_approx(float(starts[2]), float(PenceHookMath.CONTACTS[0])), "1. temas atılışın sonunda (saplanma)")
	assert(float(PenceHookMath.CONTACTS[1]) > float(starts[4]) and float(PenceHookMath.CONTACTS[1]) < float(starts[5]), "2. temas yırtarken")
	assert(is_equal_approx(PenceHookMath.contact_delay(0, 1.0), float(PenceHookMath.CONTACTS[0])), "hız 1: 1. temas taban çizelgede")
	assert(is_equal_approx(PenceHookMath.contact_delay(1, 1.0), float(PenceHookMath.CONTACTS[1])), "hız 1: 2. temas taban çizelgede")
	assert(PenceHookMath.contact_delay(0, 2.0) < PenceHookMath.contact_delay(0, 1.0), "hız artınca temas erken gelir")
	assert(is_equal_approx(PenceHookMath.segment_gap(1.0), 0.09))
	assert(PenceHookMath.busy_duration(1.0) + PenceHookMath.RETURN < 1.1111 / 0.7, "animasyon vuruş aralığına sığar")


## Hızlı vuruş (2026-10-19, "hızlı vurunca animasyonu tuhaflaşıyor"): saldırı hızı katı 3'te bile atıl / ezil / titre / yırt pozları en az
## ~2 kare (60 fps) görünür; eskiden hepsi bir kareden kısaydı (0,01-0,018 sn) ve pençe poz atlayıp ışınlanıyordu.
func test_fast_attacks_keep_every_pose_visible() -> void:
	for i in range(PenceHookMath.STEPS.size()):
		assert(is_equal_approx(PenceHookMath.step_time(i, 1.0), float(PenceHookMath.STEPS[i][0])), "hız 1'de adım %d taban süre" % i)
	for speed: float in [1.5, 2.0, 3.0]:
		for i in range(PenceHookMath.ACTION_FIRST, PenceHookMath.ACTION_LAST + 1):
			var floor_t: float = minf(float(PenceHookMath.STEPS[i][0]), PenceHookMath.MIN_POSE)
			assert(PenceHookMath.step_time(i, speed) >= floor_t - 0.0001, "hız %.1f adım %d en az %.3f sn: %.4f" % [speed, i, floor_t, PenceHookMath.step_time(i, speed)])
	assert(PenceHookMath.step_time(0, 3.0) < PenceHookMath.step_time(0, 1.0) * 0.5, "geri sin hızla kısalır")
	assert(PenceHookMath.step_time(6, 3.0) < PenceHookMath.step_time(6, 1.0) * 0.5, "bekle hızla kısalır")
	## 3 kat saldırı hızında (animasyon hızı üst sınırı) tüm hareket vuruş aralığına hâlâ sığar (aralık = 1,1111 / 0,7 / 3).
	assert(PenceHookMath.busy_duration(3.0) + PenceHookMath.RETURN / 3.0 < 1.1111 / 0.7 / 3.0, "3 kat hızda animasyon aralığa sığar")
	## Temas ve efekt anları aynı adım noktalarında: 1. temas = atılış adımının sonu, 2. temas = yırtma adımının içi.
	for speed: float in [1.0, 2.0, 3.0]:
		var starts: Array = []
		var t: float = 0.0
		for i in range(PenceHookMath.STEPS.size()):
			starts.append(t)
			t += PenceHookMath.step_time(i, speed)
		assert(is_equal_approx(PenceHookMath.contact_delay(0, speed), float(starts[2])), "hız %.1f: 1. temas atılışın sonunda" % speed)
		assert(PenceHookMath.contact_delay(1, speed) > float(starts[4]) and PenceHookMath.contact_delay(1, speed) < float(starts[5]), "hız %.1f: 2. temas yırtarken" % speed)
		assert(PenceHookMath.segment_gap(speed) > 0.0)


## Kesilen vuruşun ezilmesi / açısı bir sonrakine aynen devredilir (hızlı art arda ya da çift atışta ikon bir kareye ezilip patlamasın).
func test_interrupted_hook_continues_from_its_pose() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_pence.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	var icon: Sprite2D = weapon.get("icon_sprite")
	var target: Vector2 = weapon.global_position + Vector2(90.0, 10.0)
	var plan: Dictionary = PenceHookMath.make_plan(Vector2.RIGHT, target, 1.0, 0.5)
	var fwd: float = deg_to_rad(float(weapon.get("sprite_forward_angle_deg")))
	var rest_rot: float = deg_to_rad(float(weapon.get("melee_icon_rest_rotation_deg")))
	var base_scale: Vector2 = weapon.get("_icon_base_scale")
	var tw1: Tween = PenceHookMath.play(weapon, icon, plan, fwd, Vector2.ZERO, rest_rot, base_scale, 1.0, false, self)
	tw1.pause()
	tw1.custom_step(0.172) ## ezil adımının sonu: boy 0,85 / en 1,12 (en çarpık an)
	var before: Transform2D = icon.global_transform
	tw1.kill()
	var tw2: Tween = PenceHookMath.play(weapon, icon, plan, fwd, Vector2.ZERO, rest_rot, base_scale, 1.0, false, self)
	tw2.pause()
	tw2.custom_step(0.0001)
	var after: Transform2D = icon.global_transform
	assert(after.origin.distance_to(before.origin) < 0.5, "konum sürekli: %s / %s" % [before.origin, after.origin])
	## Eksen UZUNLUKLARI değil sütunların kendisi karşılaştırılır: ikon çapraz dokulu, boy/en ezilmesi uzunluğu değil yönü oynatır.
	assert((after.x - before.x).length() < 0.03 * before.x.length(), "boy ezilmesi / açı sıçramaz (x ekseni): %s / %s" % [before.x, after.x])
	assert((after.y - before.y).length() < 0.03 * before.y.length(), "en ezilmesi / açı sıçramaz (y ekseni): %s / %s" % [before.y, after.y])
	tw2.kill()
	owner_node.free()
	for c in get_children():
		c.free()
	get_tree().current_scene = prev_scene


func test_fx_layers() -> void:
	var plan: Dictionary = PenceHookMath.make_plan(Vector2(-1.0, 0.0), Vector2(50.0, 80.0), 1.0, PenceHookMath.REF_OWNER_SCALE)
	for spec: Array in [[PenceHookMath.SmearFxScene, 0, 60.0], [PenceHookMath.TopFxScene, 60, 30.0], [PenceHookMath.GroundFxScene, -1, 30.0]]:
		var fx: AnimatedSprite2D = PenceHookMath.spawn_fx(spec[0], self, plan, 1.5)
		assert(fx != null, "efekt oluşmalı")
		assert(fx.global_position.is_equal_approx(plan["origin"]))
		assert(absf(angle_difference(fx.global_rotation, PI)) < 0.001, "efekt saldırı yönüyle döner: %s" % fx.global_rotation)
		assert(fx.flip_v, "sola saldırıda dikey aynalı (toz aşağıda kalsın)")
		assert(is_equal_approx(absf(fx.global_scale.x), PenceHookMath.FX_WORLD_PX), "1 sanat px = 0,575 dünya px: %s" % fx.global_scale.x)
		assert(is_equal_approx(fx.speed_scale, 1.5), "efekt saldırı hızıyla hızlanır")
		assert(fx.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "piksel sanatı")
		assert(fx.z_index == int(spec[1]), "z %d olmalı: %d" % [spec[1], fx.z_index])
		var frames: SpriteFrames = fx.sprite_frames
		assert(frames.has_animation("play") and not frames.get_animation_loop("play"), "tek seferlik")
		assert(is_equal_approx(frames.get_animation_speed("play"), float(spec[2])), "pişirme fps'i")
		## Kareler merkeze göre simetrik kırpıldı (dönme + flip_v merkez etrafında doğru olsun).
		var tex: Texture2D = frames.get_frame_texture("play", 0)
		assert(tex != null and tex.get_width() % 2 == 0 and tex.get_height() % 2 == 0, "kare boyu çift (merkez = orijin)")
		fx.free()


func test_hook_moves_the_icon_and_spawns_fx_on_time() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_pence.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	var target: Vector2 = weapon.global_position + Vector2(90.0, 10.0)
	var before: int = get_child_count()
	weapon._start_pence_hook(Vector2.RIGHT, target)
	var tw: Tween = weapon.get("_melee_swing_tween")
	assert(tw != null and tw.is_valid(), "vuruş tween'i çalışmalı")
	tw.pause()
	var icon: Sprite2D = weapon.get("icon_sprite")
	var plan: Dictionary = PenceHookMath.make_plan(Vector2.RIGHT, target, weapon._pence_size_mult(), 0.5)
	tw.custom_step(PenceHookMath.SMEAR_AT - 0.001)
	assert(icon.global_position.distance_to(PenceHookMath.point(plan, PenceHookMath.STEPS[0][1])) < 1.0, "geri sinmiş: %s" % icon.global_position)
	assert(get_child_count() == before, "iz henüz çıkmamalı")
	tw.custom_step(0.002)
	assert(get_child_count() == before + 1, "iz atılışın başında çıkar")
	tw.custom_step(float(PenceHookMath.CONTACTS[0]) - PenceHookMath.SMEAR_AT - 0.0011) ## saplanmadan 0,1 ms önce (atılış sonu hızlı)
	var want: Vector2 = PenceHookMath.point(plan, DIG)
	assert(icon.global_position.distance_to(want) < 1.0, "temas anında pençe hedefte: %s / %s" % [icon.global_position, want])
	assert(get_child_count() == before + 1, "üst katman henüz çıkmamalı")
	tw.custom_step(0.0002)
	assert(get_child_count() == before + 2, "1. temasta üst katman")
	tw.custom_step(0.015)
	assert(absf(icon.skew) > 0.001 or not icon.scale.is_equal_approx(weapon.get("_icon_base_scale")), "saplanınca pençe ezilir")
	tw.custom_step(float(PenceHookMath.CONTACTS[1]) - float(PenceHookMath.CONTACTS[0]) - 0.015 + 0.001)
	assert(get_child_count() == before + 3, "2. temasta yer katmanı")
	tw.custom_step(2.0)
	assert(icon.position.is_equal_approx(Vector2.ZERO), "sonunda dinlenme yerine döner: %s" % icon.position)
	assert(icon.scale.is_equal_approx(weapon.get("_icon_base_scale")), "ölçek tabana döner")
	assert(is_zero_approx(icon.skew), "çarpıklık sıfırlanır")
	assert(absf(angle_difference(icon.rotation, deg_to_rad(float(weapon.get("melee_icon_rest_rotation_deg"))))) < 0.01, "dinlenme açısı")
	owner_node.free()
	for c in get_children():
		c.free()
	get_tree().current_scene = prev_scene


## MP: uzak kukla pençeyi yakın dövüş sayar (bayrak weapon.gd _ready'de - geçici kopya configure_melee görmez) ve "weapon_fire"
## verisiyle kasterle AYNI noktaya saplanır.
func test_puppet_plays_the_same_hook() -> void:
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate() as Node2D
	add_child(puppet)
	puppet.setup(77, 5, "Dost")
	puppet.global_position = Vector2(3000.0, 3000.0)
	puppet.call("update_weapon_visuals", ["pence"])
	assert((puppet.get("_weapon_melee") as Array)[0] == true, "kukla pençeyi yakın dövüş saymalı")
	var target := Vector2(2920.0, 3010.0) ## sola saldırı
	var dir: Vector2 = (target - puppet.global_position).normalized()
	puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": dir.x, "direction_y": dir.y,
		"target_pos_x": target.x, "target_pos_y": target.y, "hold_duration": 0.0, "pence_size": 1.0, "pence_speed": 1.0})
	var tw: Tween = (puppet.get("_weapon_fire_tweens") as Array)[0]
	assert(tw != null and tw.is_valid(), "kukla vuruş tween'i")
	tw.pause()
	tw.custom_step(float(PenceHookMath.CONTACTS[0]) - 0.0001)
	var icon: Sprite2D = (puppet.get("_weapon_icons") as Array)[0]
	var plan: Dictionary = PenceHookMath.make_plan(dir, target, 1.0, puppet.scale.x)
	var want: Vector2 = PenceHookMath.point(plan, DIG)
	assert(icon.global_position.distance_to(want) < 1.0, "kukla pençesi aynı noktaya saplanır: %s / %s" % [icon.global_position, want])
	puppet.free()


## Hasar temas anlarında (_pence_contact): ana hedef 2 parça (saplanma + seg_gap sonra yırtma), alandaki ikinci yaratık yarı hasar.
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
	weapon.call("_pence_contact", foes[0], (foes[0] as Node2D).global_position, true, 100.0, false, 0.0, 0.05, Vector2.RIGHT)
	var first: float = float(hp0[0]) - float(foes[0].health)
	assert(first > 0.0, "ana hedef saplanmada hasar alır")
	await get_tree().create_timer(0.12).timeout
	var d0: float = float(hp0[0]) - float(foes[0].health)
	var d1: float = float(hp0[1]) - float(foes[1].health)
	assert(absf(d0 / first - 2.0) < 0.05, "2. parça yırtmada gelir: %.2f / %.2f" % [d0, first])
	assert(absf(d1 / d0 - 0.5) < 0.05, "alandaki yaratık yarı hasar: %.2f / %.2f" % [d1, d0])
	for c in get_children():
		c.free()
	get_tree().current_scene = prev_scene


## FARKLI AÇILARDAN (2026-10-21, "pençe hep aynı şekilde çizmesin"): her vuruş hedefe TILT_CYCLE sırasıyla farklı açıyla gelir;
## + = yukarıdan aşağı (sola saldırıda aynalı), hedef noktası ve aynalama değişmez.
func test_tilt_rotates_the_strike_around_the_target() -> void:
	var target := Vector2(200.0, 100.0)
	for d: Vector2 in [Vector2.RIGHT, Vector2.LEFT]:
		var flat: Dictionary = PenceHookMath.make_plan(d, target, 1.0, PenceHookMath.REF_OWNER_SCALE)
		var tilted: Dictionary = PenceHookMath.make_plan(d, target, 1.0, PenceHookMath.REF_OWNER_SCALE, 30.0)
		assert(tilted["origin"] == flat["origin"] and tilted["side"] == flat["side"], "hedef ve aynalama aynı")
		assert((tilted["dir"] as Vector2).y > 0.4, "+ açı yukarıdan aşağı gelir: %s" % tilted["dir"])
		var wind_t: Vector2 = PenceHookMath.point(tilted, PenceHookMath.STEPS[0][1])
		var wind_f: Vector2 = PenceHookMath.point(flat, PenceHookMath.STEPS[0][1])
		assert(wind_t.y < wind_f.y - 5.0, "geri sinme noktası yukarıda: %s / %s" % [wind_t, wind_f])
	assert(is_zero_approx(float(PenceHookMath.TILT_CYCLE[0])), "ilk vuruş düz")
	var n: int = PenceHookMath.TILT_CYCLE.size()
	for i in range(n):
		assert(absf(float(PenceHookMath.TILT_CYCLE[i]) - float(PenceHookMath.TILT_CYCLE[(i + 1) % n])) >= 15.0, "ardışık vuruşlar belirgin farklı açıdan")


## Kaster sırayla açı seçer ve kukla gönderilen "pence_tilt" ile AYNI noktalardan geçer.
func test_caster_cycles_tilt_and_puppet_follows_it() -> void:
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_pence.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	var t: Vector2 = weapon.global_position + Vector2(90.0, 10.0)
	weapon._start_pence_hook(Vector2.RIGHT, t)
	assert(int(weapon.get("_pence_tilt_i")) == 0, "ilk vuruş düz")
	weapon._start_pence_hook(Vector2.RIGHT, t)
	assert(int(weapon.get("_pence_tilt_i")) == 1, "ikinci vuruş sıradaki açıdan")
	owner_node.free()
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate() as Node2D
	add_child(puppet)
	puppet.setup(77, 5, "Dost")
	puppet.global_position = Vector2(3000.0, 3000.0)
	puppet.call("update_weapon_visuals", ["pence"])
	var target := Vector2(3080.0, 3010.0)
	var dir: Vector2 = (target - puppet.global_position).normalized()
	puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": dir.x, "direction_y": dir.y,
		"target_pos_x": target.x, "target_pos_y": target.y, "hold_duration": 0.0, "pence_size": 1.0, "pence_speed": 1.0, "pence_tilt": 22.0})
	var tw: Tween = (puppet.get("_weapon_fire_tweens") as Array)[0]
	tw.pause()
	tw.custom_step(PenceHookMath.SMEAR_AT - 0.001)
	var icon: Sprite2D = (puppet.get("_weapon_icons") as Array)[0]
	var plan: Dictionary = PenceHookMath.make_plan(dir, target, 1.0, puppet.scale.x, 22.0)
	var want: Vector2 = PenceHookMath.point(plan, PenceHookMath.STEPS[0][1])
	assert(icon.global_position.distance_to(want) < 1.0, "kukla aynı açıdan geri siner: %s / %s" % [icon.global_position, want])
	puppet.free()
