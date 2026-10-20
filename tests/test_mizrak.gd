extends Node

## Mızrak (madde 305; prototip madde 300, kullanıcı seçimi: görünüş D "Püsküllü", efekt A "Işık Hattı"): düz saplama, hattaki
## herkese tam hasar (hedef + arkasındakiler), özellik "Cirit" her N. saplamada fırlatma. Ortak plan scripts/mizrak_thrust_math.gd
## (weapon.gd + remote_player.gd aynı dosyayı kullanır), cirit hasarı scripts/weapon_traits/cirit.gd.

const M := preload("res://scripts/mizrak_thrust_math.gd")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")


func _tip(icon: Node2D, forward_deg: float) -> Vector2:
	## ikonun dünya dönüşümünden ucun yeri: doku ekseninde ileri (forward) x TIP / doku ölçeği
	var f: float = deg_to_rad(forward_deg)
	var texel: float = icon.global_transform.x.length()
	var local: Vector2 = Vector2.RIGHT.rotated(f) * (M.TIP / maxf(0.0001, WeaponTierArt.WORLD_PX))
	return icon.global_transform * local if texel > 0.0 else icon.global_position


func test_only_the_spear_is_a_spear() -> void:
	for pair: Array in [["res://scenes/weapon_mizrak.tscn", true], ["res://scenes/weapon_uzunkilic.tscn", false], ["res://scenes/weapon_pence.tscn", false]]:
		var w: Node2D = (load(str(pair[0])) as PackedScene).instantiate() as Node2D
		add_child(w)
		assert(w.get("_is_mizrak") == pair[1], "%s _is_mizrak %s olmalı" % [pair[0], pair[1]])
		if pair[1]:
			assert(w.get("melee") == true, "mızrak configure_melee görmeden yakın dövüş (kukla kopyası için)")
			assert(is_equal_approx(float(w.get("attack_range")), 150.0), "menzil 150: %s" % w.get("attack_range"))
			assert(is_equal_approx(float(w.get("card_damage_bonus_ratio")), 1.2), "%120 saldırı gücü")
			assert(is_equal_approx(float(w.call("damage_stat_mult")), 1.0), "yakın dövüş ek çarpanı (x1,4) mızrakta yok: gerçek oran %120")
			assert(float(w.get("sprite_forward_angle_deg")) == -45.0, "Zanaatkâr çapraz sanat")
			assert((w.get("icon_sprite") as Sprite2D).texture.resource_path.ends_with("mizrak_L1.png"), "1. seviye sanatı")
		w.free()
	for lv in range(1, 6):
		assert(WeaponTierArt.texture("mizrak", lv) != null, "mizrak_L%d.png" % lv)


func test_plan_geometry_and_mirror() -> void:
	var target := Vector2(300.0, 100.0)
	var dir := Vector2(1.0, 0.25).normalized()
	var plan: Dictionary = M.make_plan(dir, target, 1.0, M.REF_OWNER_SCALE)
	var o: Vector2 = plan["origin"]
	assert(o.is_equal_approx(target + M.ANCHOR))
	## saplamada (STEPS[2]) uç hedeften 16 px geçer, yaklaşmada 20 px önde durur
	var thrust_tip: float = (M.point(plan, M.STEPS[2][1]) - o).dot(dir) + M.TIP * float(M.STEPS[2][3])
	assert(absf(thrust_tip - 16.0) < 0.2, "saplamada uç +16: %.2f" % thrust_tip)
	var set_tip: float = (M.point(plan, M.STEPS[0][1]) - o).dot(dir) + M.TIP
	assert(absf(set_tip + 20.0) < 0.2, "yaklaşmada uç -20: %.2f" % set_tip)
	var seg: Array = M.line_segment(plan)
	assert(absf(((seg[1] as Vector2) - o).dot(dir) - 80.0) < 0.01, "hat hedefin 80 px gerisine")
	var right: Dictionary = M.make_plan(Vector2.RIGHT, target, 1.0, M.REF_OWNER_SCALE)
	var left: Dictionary = M.make_plan(Vector2.LEFT, target, 1.0, M.REF_OWNER_SCALE)
	var r: Vector2 = M.point(right, Vector2(-20.0, 5.0)) - (right["origin"] as Vector2)
	var l: Vector2 = M.point(left, Vector2(-20.0, 5.0)) - (left["origin"] as Vector2)
	assert(l.is_equal_approx(Vector2(-r.x, r.y)), "sola saldırı sağın aynası: %s / %s" % [l, r])
	var big: Dictionary = M.make_plan(Vector2.RIGHT, target, 2.0, M.REF_OWNER_SCALE)
	assert(is_equal_approx(float(big["k"]), 2.0))


func test_timeline() -> void:
	var t: float = 0.0
	var starts: Array = []
	for st: Array in M.STEPS:
		starts.append(t)
		t += float(st[0])
	assert(is_equal_approx(float(starts[2]), M.SMEAR_AT), "hat efekti saplamanın başında")
	## temas = ucun hedefi geçtiği an ("in" = karesel): geri çekilmiş uç -27, saplamada +16
	var want: float = M.SMEAR_AT + sqrt(27.0 / 43.0) * float(M.STEPS[2][0])
	assert(absf(M.CONTACT - want) < 0.001, "temas %.4f / %.4f" % [M.CONTACT, want])
	assert(is_equal_approx(M.contact_delay(2.0), M.CONTACT * 0.5), "hız 2 kat -> temas 2 kat erken")
	assert(t + M.RETURN < 1.1111 / 0.7, "saplama vuruş aralığına sığar")
	var throw: Dictionary = M.make_plan(Vector2.RIGHT, Vector2(500.0, 0.0), 1.0, M.REF_OWNER_SCALE, {"range": 280.0, "speed": 760.0, "from": Vector2(400.0, 0.0)})
	var rel: Vector2 = M.release_point(throw)
	assert(is_equal_approx(float(throw["travel"]), 280.0 - (rel.x - 400.0)), "cirit karakterden 280 px'e kadar: %s" % throw["travel"])
	assert(is_equal_approx(M.throw_end(throw).x, 680.0), "son: %s" % M.throw_end(throw))
	assert(absf(M.throw_contact_delay(throw, 1.0) - (M.RELEASE_AT + 34.0 / 760.0)) < 0.0001, "uçan uç hedefin üstünde")
	var total: float = M.RELEASE_AT + M.flight_duration(throw) + M.REAPPEAR + M.POP
	assert(total < 1.1111 / 0.7, "cirit de aralığa sığar: %.2f" % total)


func test_fx_layers() -> void:
	var plan: Dictionary = M.make_plan(Vector2.LEFT, Vector2(50.0, 80.0), 1.0, M.REF_OWNER_SCALE)
	for spec: Array in [[M.LineFxScene, 60.0], [M.HitFxScene, 30.0], [M.EndFxScene, 30.0]]:
		var fx: AnimatedSprite2D = M.spawn_fx(spec[0], self, plan, 1.5)
		assert(fx != null, "efekt oluşmalı")
		assert(absf(angle_difference(fx.global_rotation, PI)) < 0.001, "saldırı yönüyle döner")
		assert(fx.flip_v, "sola saldırıda dikey aynalı")
		assert(is_equal_approx(absf(fx.global_scale.x), M.FX_WORLD_PX), "1 sanat px = 0,575 dünya px")
		assert(is_equal_approx(fx.speed_scale, 1.5))
		assert(fx.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and fx.z_index == 60)
		var frames: SpriteFrames = fx.sprite_frames
		assert(frames.has_animation("play") and not frames.get_animation_loop("play"), "tek seferlik")
		assert(is_equal_approx(frames.get_animation_speed("play"), float(spec[1])), "pişirme fps'i")
		var tex: Texture2D = frames.get_frame_texture("play", 0)
		assert(tex.get_width() % 2 == 0 and tex.get_height() % 2 == 0, "kare boyu çift (merkez = orijin)")
		fx.free()
	assert(M.TrailFrames.get_animation_loop("play"), "cirit izi döngü")


func _foe(pos: Vector2, hp: float = 600000.0) -> Node2D:
	var e: Node2D = EnemyScene.instantiate()
	add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.set("max_health", hp)
	e.set("health", hp)
	return e


func _cleanup(prev_scene: Node) -> void:
	for c in get_children():
		c.free()
	get_tree().current_scene = prev_scene


## Hat: hedef + 36 / 70 px gerisindekiler; 30 px yandaki ve 128 px gerideki (hattın dışı) yok; hedefin önündeki 30 px de yok.
func test_line_victims() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var t := Vector2(5000.0, 5000.0)
	var foes: Array = [_foe(t), _foe(t + Vector2(36.0, 3.0)), _foe(t + Vector2(70.0, -4.0)), _foe(t + Vector2(26.0, 30.0)),
		_foe(t + Vector2(128.0, 2.0)), _foe(t + Vector2(-30.0, 0.0))]
	await get_tree().physics_frame
	await get_tree().physics_frame
	var plan: Dictionary = M.make_plan(Vector2.RIGHT, t, 1.0, M.REF_OWNER_SCALE)
	var v: Array = M.line_victims(get_tree(), plan, foes[0])
	assert(v.size() == 3 and v[0] == foes[0] and v[1] == foes[1] and v[2] == foes[2], "hat kurbanları sıralı 3 olmalı: %s" % str(v))
	_cleanup(prev_scene)


## Temas: hattaki herkes TAM hasar alır, ışık çizgisi geçtikçe sırayla; hattın dışındaki almaz.
func test_contact_pierces_the_line_with_full_damage() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var weapon: Node2D = (load("res://scenes/weapon_mizrak.tscn") as PackedScene).instantiate() as Node2D
	add_child(weapon)
	var t := Vector2(6000.0, 6000.0)
	var foes: Array = [_foe(t), _foe(t + Vector2(36.0, 3.0)), _foe(t + Vector2(70.0, -4.0)), _foe(t + Vector2(26.0, 30.0))]
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hp0: Array = foes.map(func(e: Node2D) -> float: return float(e.health))
	var plan: Dictionary = M.make_plan(Vector2.RIGHT, t, 1.0, M.REF_OWNER_SCALE)
	weapon.call("_mizrak_contact", foes[0], t, true, 100.0, false, 0.0, Vector2.RIGHT, plan, 1.0)
	var d_first: float = float(hp0[0]) - float(foes[0].health)
	assert(d_first > 0.0, "hedef temas anında vurulur")
	assert(is_equal_approx(float(hp0[2]), float(foes[2].health)), "70 px gerideki henüz vurulmadı (çizgi ilerliyor)")
	await get_tree().create_timer(0.12).timeout
	var d: Array = []
	for i in range(foes.size()):
		d.append(float(hp0[i]) - float(foes[i].health))
	assert(absf(float(d[1]) / d_first - 1.0) < 0.05 and absf(float(d[2]) / d_first - 1.0) < 0.05, "arkadakiler tam hasar: %s" % str(d))
	assert(is_zero_approx(float(d[3])), "hattın 30 px yanındaki vurulmaz: %s" % str(d))
	weapon.call("_mizrak_contact", foes[0], t, false, 100.0, false, 0.0, Vector2.RIGHT, plan, 1.0)
	assert(is_equal_approx(float(hp0[0]) - float(foes[0].health), d_first), "hayalet hedefte (Talon salvosu) vuruş yok")
	_cleanup(prev_scene)


func test_thrust_moves_the_icon_and_spawns_the_line() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_mizrak.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	weapon.scale = owner_node.scale ## oyunda silah kökü (top_level) sahibin ölçeğini hover takibinden alır
	var target: Vector2 = weapon.global_position + Vector2(110.0, 12.0)
	var dir: Vector2 = (target - weapon.global_position).normalized()
	var before: int = get_child_count()
	weapon._start_mizrak_thrust(dir, target)
	var tw: Tween = weapon.get("_melee_swing_tween")
	assert(tw != null and tw.is_valid(), "saplama tween'i")
	assert(not bool((weapon.get("_mizrak_plan") as Dictionary)["throw"]), "özelliksiz silah fırlatmaz")
	tw.pause()
	var icon: Sprite2D = weapon.get("icon_sprite")
	var plan: Dictionary = weapon.get("_mizrak_plan")
	tw.custom_step(M.SMEAR_AT - 0.001)
	assert(icon.global_position.distance_to(M.point(plan, M.STEPS[1][1])) < 1.0, "geri çekilmiş: %s" % icon.global_position)
	assert(get_child_count() == before, "hat efekti henüz çıkmamalı")
	tw.custom_step(0.002)
	assert(get_child_count() == before + 1, "hat efekti saplamanın başında")
	tw.custom_step(M.CONTACT - M.SMEAR_AT - 0.0011)
	var tip_x: float = (_tip(icon, -45.0) - (plan["origin"] as Vector2)).dot(dir)
	assert(absf(tip_x) < 2.0, "temas anında uç hedefte: %.2f" % tip_x)
	tw.custom_step(2.0)
	assert(icon.position.is_equal_approx(Vector2.ZERO) and icon.scale.is_equal_approx(weapon.get("_icon_base_scale")), "dinlenme yerine döner")
	assert(is_zero_approx(icon.skew))
	owner_node.free()
	_cleanup(prev_scene)


## Cirit animasyonu: bırakışta iz, uçuş sonunda uçta, sonra gizli (ölçek ~0), REAPPEAR sonra dinlenme yerinde belirir.
func test_throw_flies_the_icon_and_brings_it_back() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_mizrak.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	weapon.scale = owner_node.scale ## oyunda silah kökü (top_level) sahibin ölçeğini hover takibinden alır
	var icon: Sprite2D = weapon.get("icon_sprite")
	var target: Vector2 = owner_node.global_position + Vector2(100.0, 0.0)
	var plan: Dictionary = M.make_plan(Vector2.RIGHT, target, 1.0, 0.5, {"range": 280.0, "speed": 760.0, "from": owner_node.global_position})
	var released: Array = [0]
	var tw: Tween = M.play(weapon, icon, plan, deg_to_rad(-45.0), Vector2.ZERO, deg_to_rad(-45.0), weapon.get("_icon_base_scale"), 1.0, false,
		self, func() -> void: released[0] += 1)
	tw.pause()
	tw.custom_step(M.RELEASE_AT - 0.001)
	assert(released[0] == 0 and icon.get_node_or_null("MizrakCiritTrail") == null, "bırakıştan önce iz yok")
	tw.custom_step(0.002)
	assert(released[0] == 1, "bırakış geri çağrısı bir kez")
	assert(icon.get_node_or_null("MizrakCiritTrail") != null, "uçarken iz ikonun çocuğu")
	tw.custom_step(M.flight_duration(plan) - 0.003)
	var tip: Vector2 = _tip(icon, -45.0)
	assert(tip.distance_to(M.throw_end(plan)) < 3.0, "uçuş sonunda uç hattın sonunda: %s / %s" % [tip, M.throw_end(plan)])
	assert(tip.distance_to(owner_node.global_position) > 270.0, "karakterden ~280 px uzakta")
	tw.custom_step(M.THROW_FADE + 0.05)
	assert(icon.get_node_or_null("MizrakCiritTrail") == null or (icon.get_node("MizrakCiritTrail") as Node).is_queued_for_deletion(), "iz söndü")
	assert(icon.global_transform.x.length() < 0.05, "söndü (gizli): %s" % icon.global_transform.x.length())
	tw.custom_step(M.REAPPEAR + M.POP)
	assert(icon.position.is_equal_approx(Vector2.ZERO) and icon.scale.is_equal_approx(weapon.get("_icon_base_scale")), "dinlenme yerinde belirdi: %s" % icon.scale)
	owner_node.free()
	_cleanup(prev_scene)


## MP: kukla mızrağı yakın dövüş sayar ve "weapon_fire" verisiyle kasterle AYNI saplamayı / fırlatmayı oynatır.
func test_puppet_plays_the_same_thrust_and_throw() -> void:
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate() as Node2D
	add_child(puppet)
	puppet.setup(77, 5, "Dost")
	puppet.global_position = Vector2(3000.0, 3000.0)
	puppet.call("update_weapon_visuals", ["mizrak"])
	assert((puppet.get("_weapon_melee") as Array)[0] == true, "kukla mızrağı yakın dövüş saymalı")
	var target := Vector2(2900.0, 3010.0) ## sola saldırı
	var dir: Vector2 = (target - puppet.global_position).normalized()
	puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": dir.x, "direction_y": dir.y,
		"target_pos_x": target.x, "target_pos_y": target.y, "hold_duration": 0.0, "mizrak_size": 1.0, "mizrak_speed": 1.0})
	var tw: Tween = (puppet.get("_weapon_fire_tweens") as Array)[0]
	assert(tw != null and tw.is_valid(), "kukla saplama tween'i")
	tw.pause()
	tw.custom_step(M.CONTACT - 0.0001)
	var icon: Sprite2D = (puppet.get("_weapon_icons") as Array)[0]
	var plan: Dictionary = M.make_plan(dir, target, 1.0, puppet.scale.x)
	var tip_x: float = (_tip(icon, -45.0) - (plan["origin"] as Vector2)).dot(dir)
	assert(absf(tip_x) < 2.0, "kukla ucu temas anında hedefte: %.2f" % tip_x)
	tw.kill()
	puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": dir.x, "direction_y": dir.y,
		"target_pos_x": target.x, "target_pos_y": target.y, "hold_duration": 0.0, "mizrak_size": 1.0, "mizrak_speed": 1.0,
		"mizrak_travel": 200.0, "mizrak_fly": 760.0})
	tw = (puppet.get("_weapon_fire_tweens") as Array)[0]
	tw.pause()
	tw.custom_step(M.RELEASE_AT + 200.0 / 760.0 - 0.003)
	var tplan: Dictionary = M.make_plan(dir, target, 1.0, puppet.scale.x, {"speed": 760.0})
	tplan["travel"] = 200.0
	assert(_tip(icon, -45.0).distance_to(M.throw_end(tplan)) < 3.0, "kukla cirit ucu aynı yerde biter")
	puppet.free()


## Cirit özelliği (gerçek oyuncu + silah): her N. saplamada fırlatır, uç yolundaki herkese bir kez vurur; final ilk 3'ü sürükler + sersemletir.
func test_cirit_trait_hits_the_path_and_final_skewers() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	var saved: Array = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("mizrak", 1, 0)]
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	p.global_position = Vector2(8000.0, 8000.0)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	assert(p.buy_weapon_copy("mizrak", 1), "mızrak verilemedi")
	var w: Node = p.owned_weapon_nodes[0]
	var beh: Node = w.get("enchant_behavior")
	assert(beh != null and str((beh.get("stats") as Dictionary).get("id", "")) == "cirit", "doğuştan Cirit")
	assert(beh.get_script().resource_path == "res://scripts/weapon_traits/cirit.gd")
	var st: Dictionary = beh.get("stats")
	assert(int(st["cirit_every"]) == 4 and is_equal_approx(float(st["cirit_range"]), 280.0) and is_equal_approx(float(st["cirit_ap"]), 0.9))
	## sayaç: 4. saldırı fırlatma
	beh.set("attacks", 3)
	assert(not beh.call("wants_throw"))
	beh.set("attacks", 4)
	assert(beh.call("wants_throw"), "4. saplama cirit")
	## tam dolu (4 geliştirme + final) çözüm
	var full: Dictionary = EnchantDefs.resolve({"id": "cirit", "ups": [0, 1, 2, 3], "final": true}, "mizrak")
	assert(int(full["cirit_every"]) == 3 and is_equal_approx(float(full["cirit_range"]), 360.0) and is_equal_approx(float(full["cirit_speed"]), 1.25))
	assert(is_equal_approx(float(full["cirit_ap"]), 1.2) and is_equal_approx(float(full["cirit_vuln"]), 0.15) and int(full["cirit_skewer"]) == 3)
	for k in full:
		st[k] = full[k]
	var start := Vector2(8100.0, 8000.0)
	var foes: Array = []
	for x in [30.0, 60.0, 90.0, 120.0]:
		foes.append(_foe(start + Vector2(x, 0.0)))
	var side: Node2D = _foe(start + Vector2(190.0, 45.0)) ## yoldan 45 px yanda (uç değmez), sona 46 px
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hp0: Array = foes.map(func(e: Node2D) -> float: return float(e.health))
	var x0: Array = foes.map(func(e: Node2D) -> float: return e.global_position.x)
	var side_hp: float = side.health
	beh.call("release_cirit", start, Vector2.RIGHT, 200.0, 760.0, 1.0)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 600:
		await get_tree().physics_frame
	for i in range(foes.size()):
		assert(float(hp0[i]) - float(foes[i].health) > 0.0, "yoldaki %d. düşman vuruldu" % i)
	assert(int(beh.get("throws")) == 1)
	var moved: int = 0
	for i in range(3):
		if (foes[i] as Node2D).global_position.x - float(x0[i]) > 20.0:
			moved += 1
	assert(moved >= 2, "ilk 3 düşman yolun sonuna sürüklenir: %d" % moved)
	assert(side.health < side_hp, "çakıldığı yerin çevresindeki %50 pay")
	## Yarık Zırh: vurulan düşman mızraktan %15 fazla hasar alır
	assert(is_equal_approx(float(beh.call("vuln_mult", foes[3])), 1.15), "yarık zırh")
	GameManager.owned_weapons = saved
	p.free()
	_cleanup(prev_scene)
