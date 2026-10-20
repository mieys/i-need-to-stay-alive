extends Node

## Kalkan (madde 338; prototip madde 330/333, kullanıcı seçimi: görünüş B "Şövalye", efekt D "Hayalet Kalkan"): ikon dönmez, yüzü
## baktığı yöne dönük görünüş (8 yön), geniş darbe önündeki herkese tam hasar + 45 px itme, özellik "Siper" sabit kalkan doldurur.
## Ortak plan scripts/kalkan_bash_math.gd (weapon.gd + remote_player.gd aynı dosyayı kullanır), özellik scripts/weapon_traits/siper.gd.

const K := preload("res://scripts/kalkan_bash_math.gd")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const WeaponTierArt := preload("res://scripts/weapon_tier_art.gd")
const Catalog := preload("res://scripts/weapon_catalog.gd")
const INTERVAL := 1.1111 / 0.7


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


func _region_x(icon: Sprite2D) -> float:
	return (icon.texture as AtlasTexture).region.position.x if icon.texture is AtlasTexture else -1.0


func test_only_the_shield_is_a_shield() -> void:
	for pair: Array in [["res://scenes/weapon_kalkan.tscn", true], ["res://scenes/weapon_mizrak.tscn", false], ["res://scenes/weapon_topuz.tscn", false]]:
		var w: Node2D = (load(str(pair[0])) as PackedScene).instantiate() as Node2D
		add_child(w)
		assert(w.get("_is_kalkan") == pair[1], "%s _is_kalkan %s olmalı" % [pair[0], pair[1]])
		if pair[1]:
			assert(w.get("melee") == true, "kalkan configure_melee görmeden yakın dövüş (kukla kopyası için)")
			assert(is_equal_approx(float(w.get("attack_range")), 110.0), "menzil 110: %s" % w.get("attack_range"))
			assert(is_equal_approx(float(w.get("card_damage_bonus_ratio")), 1.25), "%125 saldırı gücü (2026-10-20: %80 -> %100 kullanıcı onayı, denge turu %100 -> %125, BALANCE_REV 94)")
			assert(is_equal_approx(float(w.call("damage_stat_mult")), 1.0), "yakın dövüş ek çarpanı yok: gerçek oran %125")
			assert(float(w.get("sprite_forward_angle_deg")) == 0.0, "önden dik sanat")
			assert((w.get("icon_sprite") as Sprite2D).texture.resource_path.ends_with("kalkan_L1.png"), "1. seviye sanatı")
		w.free()
	for lv in range(1, 6):
		assert(WeaponTierArt.texture("kalkan", lv) != null, "kalkan_L%d.png" % lv)
		for i in range(5):
			assert(K.view_texture(lv, i) != null and K.ghost_texture(lv, i) != null, "görünüş/hayalet L%d v%d" % [lv, i])
	assert("kalkan" in Catalog.KEYS and "kalkan" in Catalog.MELEE_KEYS and Catalog.ICONS.has("kalkan") and Catalog.DESCRIPTIONS.has("kalkan"))
	assert(WeaponTierArt.key_from_scene("res://scenes/weapon_kalkan.tscn") == "kalkan")


## Kalkan saldırı hızından TAM yararlanır (madde 340'taki yarı oran madde 342'de geri alındı).
func test_attack_speed_is_normal_for_the_shield() -> void:
	var sh: Node2D = (load("res://scenes/weapon_kalkan.tscn") as PackedScene).instantiate() as Node2D
	add_child(sh)
	var base_sh: float = float(sh.call("_effective_fire_wait"))
	assert(absf(base_sh - 1.1111 / GameManager.WEAPON_ATTACK_SPEED_MULT) < 0.001, "kalkan taban aralığı diğer yakın dövüşlerle aynı: %.3f" % base_sh)
	sh.call("set_fire_rate_mult", 0.5) ## kart/eşya: +%100 saldırı hızı
	assert(absf(float(sh.call("_effective_fire_wait")) / base_sh - 0.5) < 0.001, "kalkan tam hızlanır")
	sh.free()


## 8 dilim + ayna + dilim sınırında titreme önleyici.
func test_sectors_and_views() -> void:
	assert(K.sector_of(Vector2.DOWN) == 0 and K.sector_of(Vector2.RIGHT) == 2 and K.sector_of(Vector2.UP) == 4 and K.sector_of(Vector2.LEFT) == 6)
	assert(K.sector_of(Vector2(1.0, 1.0)) == 1 and K.sector_of(Vector2(-1.0, 1.0)) == 7 and K.sector_of(Vector2(1.0, -1.0)) == 3)
	assert(K.view_of_sector(2) == [2, false] and K.view_of_sector(6) == [2, true] and K.view_of_sector(4) == [4, false] and K.view_of_sector(5) == [3, true])
	## sağdan (90) yukarı doğru 120 dereceye: sınır 112,5 + 8 = 120,5 -> hâlâ yan; 125 -> sağ-yukarı
	var d120 := Vector2(sin(deg_to_rad(120.0)), cos(deg_to_rad(120.0)))
	var d125 := Vector2(sin(deg_to_rad(125.0)), cos(deg_to_rad(125.0)))
	assert(K.sector_of(d120, 2) == 2, "titreme önleyici: yan görünüşte kalır")
	assert(K.sector_of(d125, 2) == 3, "sınırı geçince değişir")
	assert(K.sector_of(d120) == 3, "önceki yokken en yakın dilim")
	var icon := Sprite2D.new()
	add_child(icon)
	icon.rotation = 0.7
	K.face(icon, 3, Vector2.LEFT)
	assert(is_equal_approx(_region_x(icon), 96.0) and icon.flip_h and is_zero_approx(icon.rotation), "sol = yan görünüş aynalı, dönmez")
	K.face(icon, 3, Vector2.UP)
	assert(is_equal_approx(_region_x(icon), 192.0) and not icon.flip_h, "yukarı = arka yüz")
	icon.free()


func test_plan_and_timeline() -> void:
	var t: float = 0.0
	var starts: Array = []
	for st: Array in K.STEPS:
		starts.append(t)
		t += float(st[0])
	assert(absf(K.CONTACT - (float(starts[2]) + float(K.STEPS[2][0]))) < 0.0001, "temas = çarpmanın sonu")
	assert(is_equal_approx(K.contact_delay(2.0), K.CONTACT * 0.5), "hız 2 kat -> temas 2 kat erken")
	assert(t + K.RETURN < INTERVAL, "darbe vuruş aralığına sığar: %.2f" % (t + K.RETURN))
	var target := Vector2(300.0, 100.0)
	var plan: Dictionary = K.make_plan(Vector2.RIGHT, target, 1.0, K.REF_OWNER_SCALE)
	assert((plan["origin"] as Vector2).is_equal_approx(target + K.ANCHOR))
	assert(K.contact_point(plan).is_equal_approx(target + K.ANCHOR + Vector2(-13.0, 0.0)), "temas noktası hedefin 13 px önü")
	assert(int(plan["sector"]) == 2, "sağa darbe yan görünüş")
	var big: Dictionary = K.make_plan(Vector2.RIGHT, target, 2.0, K.REF_OWNER_SCALE)
	assert(is_equal_approx(float(big["k"]), 2.0))
	## ezilme: yatay darbede x ekseni hareket yönü
	var s: Vector2 = K._axis_scale(0.8, 1.12, Vector2.RIGHT)
	assert(s.is_equal_approx(Vector2(0.8, 1.12)))
	assert(K._axis_scale(0.8, 1.12, Vector2.DOWN).is_equal_approx(Vector2(1.12, 0.8)))


## Geniş darbe: temas noktası çevresinde 40 px, önünde; geride ve uzakta olan yok. Final: karakterin çevresinde 360°.
func test_victims_wide_front_and_wall() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var t := Vector2(5000.0, 5000.0)
	## temas noktası = t + ANCHOR - 13x
	var foes: Array = [_foe(t), _foe(t + Vector2(-6.0, -26.0)), _foe(t + Vector2(-4.0, 28.0)), _foe(t + Vector2(-40.0, 0.0)),
		_foe(t + Vector2(60.0, 0.0))]
	await get_tree().physics_frame
	await get_tree().physics_frame
	var plan: Dictionary = K.make_plan(Vector2.RIGHT, t, 1.0, K.REF_OWNER_SCALE, false, t - Vector2(70.0, 0.0))
	var v: Array = K.victims(get_tree(), plan, foes[0])
	assert(v.size() == 3 and v[0] == foes[0] and foes[1] in v and foes[2] in v, "hedef + 2 yandaki: %s" % str(v))
	assert(not (foes[3] in v), "temasın 27 px gerisindeki (karakter tarafı) vurulmaz")
	assert(not (foes[4] in v), "73 px uzaktaki vurulmaz")
	var wall: Dictionary = K.make_plan(Vector2.RIGHT, t, 1.0, K.REF_OWNER_SCALE, true, t - Vector2(70.0, 0.0))
	var vw: Array = K.victims(get_tree(), wall, foes[0])
	assert(vw.size() == 5, "Final: 140 px içindeki herkes: %d" % vw.size())
	## itme yönleri: hedef ileri, yandaki yana açılır, Final dışa
	assert(K.push_dir(plan, foes[0].global_position).x > 0.95)
	assert(K.push_dir(plan, foes[1].global_position).y < -0.3, "üstteki yukarı açılır")
	assert(K.push_dir(wall, foes[3].global_position).x > 0.9 and is_equal_approx(K.push_distance(wall), 90.0))
	_cleanup(prev_scene)


## Temas: önündeki herkes TAM hasar alır ve itilir, ayaklarında halka; dışındaki almaz; hayalet hedefte vuruş yok.
func test_contact_full_damage_push_and_rings() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var weapon: Node2D = (load("res://scenes/weapon_kalkan.tscn") as PackedScene).instantiate() as Node2D
	add_child(weapon)
	var t := Vector2(6000.0, 6000.0)
	var foes: Array = [_foe(t), _foe(t + Vector2(-6.0, -26.0)), _foe(t + Vector2(60.0, 0.0))]
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hp0: Array = foes.map(func(e: Node2D) -> float: return float(e.health))
	var x0: float = foes[0].global_position.x
	var plan: Dictionary = K.make_plan(Vector2.RIGHT, t, 1.0, K.REF_OWNER_SCALE)
	weapon.call("_kalkan_contact", foes[0], t, true, 100.0, false, 0.0, Vector2.RIGHT, plan)
	var d0: float = float(hp0[0]) - float(foes[0].health)
	var d1: float = float(hp0[1]) - float(foes[1].health)
	assert(d0 > 0.0 and absf(d1 / d0 - 1.0) < 0.05, "yandaki de tam hasar: %.1f / %.1f" % [d1, d0])
	assert(is_equal_approx(float(hp0[2]), float(foes[2].health)), "uzaktaki vurulmaz")
	var rings: int = 0
	for c in get_children():
		if c is AnimatedSprite2D and c.scene_file_path == "res://scenes/fx_kalkan_ring.tscn":
			rings += 1
	assert(rings == 2, "vurulan iki yaratığın ayağında halka: %d" % rings)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 400:
		await get_tree().physics_frame
	assert(foes[0].global_position.x - x0 > 20.0, "hedef geri itildi: %.1f" % (foes[0].global_position.x - x0))
	var hp_after: float = foes[0].health
	weapon.call("_kalkan_contact", foes[0], t, false, 100.0, false, 0.0, Vector2.RIGHT, plan)
	assert(is_equal_approx(hp_after, float(foes[0].health)), "hayalet hedefte (Talon salvosu) vuruş yok")
	_cleanup(prev_scene)


## Darbe: yüzü hedefe dönük görünüş, kurulma, temasta hayalet + ezilme, sonra dinlenme yerine döner. Sola darbe aynalı.
func test_bash_moves_the_icon_and_spawns_the_ghost() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var owner_node := Node2D.new()
	owner_node.scale = Vector2(0.5, 0.5)
	add_child(owner_node)
	var weapon: Node2D = (load("res://scenes/weapon_kalkan.tscn") as PackedScene).instantiate() as Node2D
	owner_node.add_child(weapon)
	weapon.scale = owner_node.scale ## oyunda silah kökü (top_level) sahibin ölçeğini hover takibinden alır
	var target: Vector2 = owner_node.global_position + Vector2(90.0, 0.0)
	weapon._start_kalkan_bash(Vector2.RIGHT, target)
	var tw: Tween = weapon.get("_melee_swing_tween")
	assert(tw != null and tw.is_valid(), "darbe tween'i")
	assert(not bool((weapon.get("_kalkan_plan") as Dictionary)["wall"]), "özelliksiz kalkan Final yapmaz")
	tw.pause()
	var icon: Sprite2D = weapon.get("icon_sprite")
	var plan: Dictionary = weapon.get("_kalkan_plan")
	var base: Vector2 = weapon.get("_icon_base_scale")
	assert(is_equal_approx(_region_x(icon), 96.0) and not icon.flip_h, "sağa darbe: yan görünüş")
	tw.custom_step(float(K.STEPS[0][0]) + float(K.STEPS[1][0]) - 0.001)
	assert(icon.global_position.distance_to(K.point(plan, -31.0)) < 1.0, "kurulmuş (hedefin 31 px önü): %s" % icon.global_position)
	var ghosts_before: int = get_children().filter(func(c: Node) -> bool: return c.name.begins_with("KalkanHayalet")).size()
	assert(ghosts_before == 0)
	tw.custom_step(K.CONTACT - (float(K.STEPS[0][0]) + float(K.STEPS[1][0])) + 0.002)
	var ghosts: Array = get_children().filter(func(c: Node) -> bool: return c.name.begins_with("KalkanHayalet"))
	assert(ghosts.size() == 1, "temasta bir hayalet")
	assert((ghosts[0] as Sprite2D).global_position.distance_to(K.contact_point(plan)) < 1.0, "hayalet temas noktasında")
	assert(icon.scale.x < absf(base.x) * 0.85 and icon.scale.y > absf(base.y) * 1.05, "duraklamada hareket yönünde ezilme: %s" % icon.scale)
	tw.custom_step(2.0)
	assert(icon.position.is_equal_approx(Vector2.ZERO) and icon.scale.is_equal_approx(Vector2(absf(base.x), absf(base.y))), "dinlenme yerine döner")
	weapon._start_kalkan_bash(Vector2.LEFT, owner_node.global_position - Vector2(90.0, 0.0))
	assert(icon.flip_h and is_equal_approx(_region_x(icon), 96.0), "sola darbe aynalı yan görünüş")
	(weapon.get("_melee_swing_tween") as Tween).kill()
	owner_node.free()
	_cleanup(prev_scene)


## MP: kukla kalkanı yakın dövüş sayar, dönmeyen ikon işaretlidir ve "weapon_fire" verisiyle kasterle AYNI darbeyi oynatır.
func test_puppet_plays_the_same_bash() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate() as Node2D
	add_child(puppet)
	puppet.setup(77, 5, "Dost")
	puppet.global_position = Vector2(3000.0, 3000.0)
	puppet.call("update_weapon_visuals", ["kalkan"])
	assert((puppet.get("_weapon_melee") as Array)[0] == true, "kukla kalkanı yakın dövüş saymalı")
	var icon: Sprite2D = (puppet.get("_weapon_icons") as Array)[0]
	assert(icon.has_meta("kalkan"), "kalkan ikonu işaretli")
	puppet.call("_wf_face", 0, icon, Vector2.RIGHT, 1.0)
	assert(is_equal_approx(_region_x(icon), 96.0) and is_zero_approx(icon.rotation), "kukla nişanı dönmez, görünüş değiştirir")
	var target := Vector2(2910.0, 3000.0) ## sola darbe
	var dir: Vector2 = (target - puppet.global_position).normalized()
	puppet.call("_animate_weapon_fire_full", {"slot_index": 0, "direction_x": dir.x, "direction_y": dir.y,
		"target_pos_x": target.x, "target_pos_y": target.y, "hold_duration": 0.0, "kalkan_size": 1.0, "kalkan_speed": 1.0, "kalkan_tier": 4})
	var tw: Tween = (puppet.get("_weapon_fire_tweens") as Array)[0]
	assert(tw != null and tw.is_valid(), "kukla darbe tween'i")
	tw.pause()
	tw.custom_step(K.CONTACT - 0.0001)
	var plan: Dictionary = K.make_plan(dir, target, 1.0, puppet.scale.x)
	assert(icon.global_position.distance_to(K.point(plan, -10.0)) < 1.5, "kukla kalkanı temas anında aynı yerde: %s / %s" % [icon.global_position, K.point(plan, -10.0)])
	assert(icon.flip_h, "sola darbe aynalı")
	assert((icon.texture as AtlasTexture).atlas == K.ViewSheets[3], "kasterin kademesi (4) kullanılır")
	tw.kill()
	puppet.free()
	_cleanup(prev_scene)


## Siper (gerçek oyuncu + silah): sabit kalkan, darbe üst sınırı, elit 2 sayılır, dosta yok; tam çözüm: Taşan Siper havuzu hasarı
## önce karşılar ve söner, Ağır Kenar, Final sayacı + iki kat kalkan.
func test_siper_trait() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	var saved: Array = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("kalkan", 1, 0)]
	var p: Node2D = PlayerScene.instantiate()
	add_child(p)
	p.global_position = Vector2(8000.0, 8000.0)
	for w in p.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	p.owned_weapon_nodes.clear()
	assert(p.buy_weapon_copy("kalkan", 1), "kalkan verilemedi")
	var w: Node = p.owned_weapon_nodes[0]
	var beh: Node = w.get("enchant_behavior")
	assert(beh != null and beh.get_script().resource_path == "res://scripts/weapon_traits/siper.gd", "doğuştan Siper")
	var st: Dictionary = beh.get("stats")
	assert(is_equal_approx(float(st["siper_per"]), 1.0) and is_equal_approx(float(st["siper_cap"]), 3.0) and int(st["siper_wall"]) == 0)
	var foes: Array = []
	for i in range(5):
		foes.append(_foe(Vector2(8100.0 + 20.0 * i, 8000.0)))
	await get_tree().physics_frame
	p.item_shield_max = 100.0
	p.item_shield_hp = 50.0
	beh.call("on_bash", [foes[0], foes[1]], false)
	assert(is_equal_approx(float(p.item_shield_hp), 52.0), "düşman başına 1 sabit kalkan: %s" % p.item_shield_hp)
	beh.call("on_bash", foes, false)
	assert(is_equal_approx(float(p.item_shield_hp), 55.0), "darbe başına en fazla 3: %s" % p.item_shield_hp)
	foes[0].set("is_elite", true)
	assert(is_equal_approx(float(beh.call("bash_gain", [foes[0]], false)), 2.0), "elit 2 sayılır")
	assert(is_equal_approx(float(beh.call("bash_damage_mult", false)), 1.0), "Ağır Kenar alınmadan çarpan yok")
	## tam dolu çözüm
	var full: Dictionary = EnchantDefs.resolve({"id": "siper", "ups": [0, 1, 2, 3], "final": true}, "kalkan")
	assert(is_equal_approx(float(full["siper_per"]), 2.0) and is_equal_approx(float(full["siper_cap"]), 5.0))
	assert(is_equal_approx(float(full["siper_surplus"]), 15.0) and is_equal_approx(float(full["siper_heavy"]), 0.3))
	assert(is_equal_approx(float(full["siper_slow"]), 0.25) and int(full["siper_wall"]) == 5)
	for k in full:
		st[k] = full[k]
	## Ağır Kenar: kalkan %50 üstünde -> %80 -> %110; Final x1,5
	assert(is_equal_approx(float(beh.call("bash_damage_mult", false)), 1.3), "kalkan %55: Ağır Kenar darbe hasarı x1,3")
	assert(is_equal_approx(float(beh.call("bash_damage_mult", true)), 1.5 * 1.3))
	p.item_shield_hp = 40.0
	assert(is_equal_approx(float(beh.call("bash_damage_mult", false)), 1.0), "kalkan %40: Ağır Kenar yok")
	## Taşan Siper: kalkan doluyken 3 düşman x 2 = 5 (üst sınır) -> hepsi havuza
	foes[0].set("is_elite", false)
	p.item_shield_hp = 100.0
	beh.call("on_bash", [foes[1], foes[2], foes[3]], false)
	assert(is_equal_approx(float(beh.call("surplus")), 5.0), "taşan kalkan havuzda: %s" % beh.call("surplus"))
	assert(is_equal_approx(float(beh.call("on_owner_damaged", 8.0, null)), 3.0), "havuz hasarı kalkandan önce karşılar")
	assert(is_zero_approx(float(beh.call("surplus"))))
	beh.call("on_bash", [foes[1], foes[2], foes[3]], false)
	beh.set("_surplus_until_msec", Time.get_ticks_msec() - 1)
	assert(is_zero_approx(float(beh.call("surplus"))) and is_equal_approx(float(beh.call("on_owner_damaged", 8.0, null)), 8.0), "4 sn darbesiz söner")
	## Final sayacı: 5. darbe; kalkan + üst sınır x2 (3 düşman x 2 x 2 = 12 -> üst sınır 10)
	beh.set("attacks", 4)
	assert(not beh.call("wants_wall"))
	beh.set("attacks", 5)
	assert(beh.call("wants_wall"), "5. darbe Yıkılmaz Duvar")
	assert(is_equal_approx(float(beh.call("bash_gain", [foes[1], foes[2], foes[3]], true)), 10.0))
	GameManager.owned_weapons = saved
	p.free()
	_cleanup(prev_scene)
