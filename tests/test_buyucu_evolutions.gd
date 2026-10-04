extends Node

## Kullanıcı isteği (2026-10-04): Büyücü Kız yeni pasifi "Büyü Dalgası" + yetenek evrimleri (bkz. scripts/skill_evolutions.gd
## DEFS[4], player.gd "Büyücü Kız (2026-10-04)" + Büyücü bloğu, weapon.gd arcane_surge, enemy.gd apply_frost_slow, evo_area.gd
## "buyucu_crater", buyucu_levitate.gd). GERÇEK Player / silah / yaratık sahneleri + sahte yaratıklarla sayıları doğrular.
## Temel değişiklik: Don Nova artık dondurmuyor, 6 sn %80 yavaşlatıyor (R finali ilk 3 sn dondurur).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")
const WeaponScene: PackedScene = preload("res://scenes/weapon_arcane.tscn")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_agac1.tscn")
const Evolutions: GDScript = preload("res://scripts/skill_evolutions.gd")
const BUYUCU := 4

var _spawned: Array = []
var _prev_char_id: int = 1
var _prev_character: int = 1


class FakeEnemy extends Node2D:
	var is_dead: bool = false
	var is_boss: bool = false
	var hits: Array = []
	var area_flags: Array = []
	var frost_slows: Array = []
	var freezes: Array = []
	var pushes: Array = [] ## [yön, mesafe]
	var stuns: Array = []
	var elements: Array = [] ## [tür, parametre]
	var burns: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _pen: float = 0.0, is_area: bool = false) -> void:
		hits.append(amount)
		area_flags.append(is_area)

	func apply_frost_slow(percent: float, duration: float) -> void:
		frost_slows.append([percent, duration])

	func apply_freeze_full(duration: float, _allow_boss: bool = false) -> void:
		freezes.append(duration)

	func apply_skill_push(dir: Vector2, distance: float) -> void:
		pushes.append([dir, distance])

	func apply_stun(duration: float) -> void:
		stuns.append(duration)

	func apply_element(kind: String, p: Dictionary) -> void:
		elements.append([kind, p])

	func apply_burn(tick: float, duration: float) -> void:
		burns.append([tick, duration])


## owned_weapon_nodes'a konan casus: pasifin her yetenekte silahlara ne gönderdiğini kaydeder.
class SurgeSpy extends Node:
	var calls: Array = []

	func arcane_surge(mult: float) -> void:
		calls.append(mult)


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = BUYUCU
	GameManager.selected_character = 3
	NetworkManager.is_multiplayer_active = false
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(1000.0, 1000.0)
	p.damage_bonus = 100.0
	p.crit_chance_bonus = -p.ABILITY_BASE_CRIT_CHANCE ## kritik yok: hasar sayıları tam
	p.item_shield_max = 10000.0
	p.item_shield_hp = 10000.0
	return p


func _make_enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	add_child(e)
	e.global_position = pos
	_spawned.append(e)
	return e


func _cleanup() -> void:
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _evo(p: Node, ids: Array) -> void:
	for id in ids:
		p.apply_skill_evolution(str(id), true)


# ------------------------------------------------------------------ kart havuzu
func test_defs_shape_and_pool_rules() -> void:
	assert(Evolutions.has_evolutions(BUYUCU), "Büyücü evrimleri tanımlı")
	assert(Evolutions.slot_list(BUYUCU, "skill").size() == 5, "Q: 4 geliştirme + final")
	assert(Evolutions.slot_list(BUYUCU, "skill2").size() == 5, "E: 4 geliştirme + final")
	assert(Evolutions.slot_list(BUYUCU, "skill3").size() == 3, "R: 2 geliştirme + final")
	var seen: Dictionary = {}
	for slot in Evolutions.SLOTS:
		var list: Array = Evolutions.slot_list(BUYUCU, slot)
		for i in range(list.size()):
			var e: Dictionary = list[i]
			assert(not seen.has(e["id"]) and str(e["id"]).begins_with("buyucu_"), "benzersiz buyucu_ id: %s" % e["id"])
			seen[e["id"]] = true
			assert(bool(e.get("final", false)) == (i == list.size() - 1), "sadece sonuncu final: %s" % e["id"])
	## Seviye 5: Q ve E (Büyücü'de 1. seviyede açık) var, R (10) yok, finaller yok.
	for e in Evolutions.available(BUYUCU, {}, 5):
		assert(str(e["slot"]) != "skill3" and not bool(e.get("final", false)), "seviye 5 havuzu: %s" % e["id"])
	var has_r: bool = false
	for e in Evolutions.available(BUYUCU, {}, 10):
		has_r = has_r or str(e["slot"]) == "skill3"
	assert(has_r, "seviye 10'da R evrimleri havuzda")


# ------------------------------------------------------------------ pasif "Büyü Dalgası"
func test_every_skill_use_surges_weapons() -> void:
	var p: Node = _make_player()
	var spy := SurgeSpy.new()
	add_child(spy)
	_spawned.append(spy)
	p.owned_weapon_nodes.append(spy)
	p._skill_buyucu_switch_variation() ## Q da yetenek sayılır
	assert(spy.calls == [p.BUYUCU_PASSIVE_SHOT_MULT], "Q (set değişimi) silahları ateşler: %s" % str(spy.calls))
	_make_enemy(Vector2(1100.0, 1000.0))
	await get_tree().physics_frame
	p._skill_buyucu_switch_variation() ## Set 1 (Arcane Lanet)
	spy.calls.clear()
	p._buyucu_try_activate_variation()
	assert(spy.calls == [1.3], "E kullanımı da: %s" % str(spy.calls))
	p.owned_weapon_nodes.erase(spy)
	await get_tree().create_timer(0.4).timeout ## sekme coroutine'i bitsin (serbest kalmış oyuncuda devam etmesin)
	_cleanup()


func test_weapon_surge_resets_timer_and_fires_with_bonus() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var w: Node2D = WeaponScene.instantiate()
	add_child(w)
	_spawned.append(w)
	w.global_position = Vector2(500.0, 500.0)
	w.hitscan = true ## hasar senkron take_damage ile gelsin (mermi uçuşu beklenmesin)
	w.impact_scene = null
	w.crit_chance = 0.0
	var e: FakeEnemy = _make_enemy(Vector2(540.0, 500.0))
	await get_tree().physics_frame
	w._fire_at(e)
	assert(e.hits.size() == 1, "normal atış vurdu")
	var normal: float = float(e.hits[0])
	e.hits.clear()
	w.fire_timer.stop()
	w.arcane_surge(1.3)
	assert(e.hits.size() == 1 and is_equal_approx(float(e.hits[0]), normal * 1.3),
		"güçlendirme hemen ateşler, +%%30: %s vs %.2f" % [str(e.hits), normal])
	assert(not w.fire_timer.is_stopped(), "saldırı bekleme süresi baştan kuruldu")
	assert(w._surge_pending_mult == 1.0, "güçlendirme tüketildi")
	w._fire_at(e)
	assert(is_equal_approx(float(e.hits[-1]), normal), "sonraki atış normal")
	## Hedef yokken güçlendirme bekler, ilk fırsattaki atışa kalır.
	e.free()
	await get_tree().physics_frame
	w.arcane_surge(1.3)
	assert(w._surge_pending_mult == 1.3, "hedefsiz: bekliyor")
	var e2: FakeEnemy = _make_enemy(Vector2(540.0, 500.0))
	w._fire_at(e2)
	assert(e2.hits.size() == 1 and is_equal_approx(float(e2.hits[0]), normal * 1.3), "bekleyen güçlendirme ilk atışta: %s" % str(e2.hits))
	_cleanup()


# ------------------------------------------------------------------ Q evrimleri
func test_q1_shield_on_switch_with_cooldown() -> void:
	var p: Node = _make_player()
	_evo(p, ["buyucu_q1"])
	p.item_shield_hp = 5000.0
	p._skill_buyucu_switch_variation()
	var expected: float = 5000.0 + 10000.0 * p.EVO_BUYUCU_Q1_SHIELD_RATIO * p.heal_power_mult()
	assert(is_equal_approx(p.item_shield_hp, expected), "set değişimi %%10 kalkan: %.1f vs %.1f" % [p.item_shield_hp, expected])
	p._skill_buyucu_switch_variation()
	assert(is_equal_approx(p.item_shield_hp, expected), "10 sn bekleme: hemen ikinci kez yok")
	_cleanup()


func test_q2_speed_q3_cooldowns_q4_cost() -> void:
	var p: Node = _make_player()
	var base_speed: float = p._evo_move_bonus()
	_evo(p, ["buyucu_q2", "buyucu_q3"])
	p._skill_buyucu_switch_variation()
	assert(is_equal_approx(p._evo_move_bonus(), base_speed + 0.2), "her yetenekte +%20 hız")
	assert(is_equal_approx(float(p._skill_timing_for(3)["cooldown"]), 0.85), "Q bekleme -%15")
	assert(is_equal_approx(float(p._skill2_timing_for(25)["cooldown"]), 120.0 * 0.85), "Meteor bekleme -%15")
	## Tutumlu Büyü: E bedeli x0,75 (Hortum - hedef gerektirmez).
	var e_shield0: float = p.item_shield_hp
	p._buyucu_try_activate_variation() ## şu an Set 2: Hortum
	var full_cost: float = e_shield0 - p.item_shield_hp
	for t in p._buyucu_active_tornadoes:
		if is_instance_valid(t):
			t.free()
	p._buyucu_active_tornadoes.clear()
	_evo(p, ["buyucu_q4"])
	p._buyucu_variation_cooldowns[2] = 0.0
	var shield1: float = p.item_shield_hp
	p._buyucu_try_activate_variation()
	var cut_cost: float = shield1 - p.item_shield_hp
	assert(full_cost > 0.0 and is_equal_approx(cut_cost, full_cost * 0.75), "bedel %%25 az: %.1f vs %.1f" % [cut_cost, full_cost])
	for t in p._buyucu_active_tornadoes:
		if is_instance_valid(t):
			t.free()
	_cleanup()


func test_qf_enchant_every_five_uses_and_empowered_cast() -> void:
	var p: Node = _make_player()
	_evo(p, ["buyucu_qf"])
	for i in range(4):
		p._buyucu_on_skill_used("skill2", 0)
	for i in range(3):
		p._buyucu_on_skill_used("skill", -1) ## Q sayılmaz
	assert(p._buyucu_enchanted.is_empty(), "4 kullanımda efsun yok")
	p._buyucu_on_skill_used("skill3", 1)
	assert(p._buyucu_enchanted.size() == 1, "5. kullanımda bir yetenek efsunlandı")
	for v in p._buyucu_enchanted:
		assert(int(v) == 0 or int(v) == 2, "R kilitliyken (seviye 1) sadece E varyasyonları: %s" % str(v))
	## Efsunlu Don Nova: alan ve hasar x1,25 (320 -> 400) - 360 px'teki yaratığa ancak efsunluyken ulaşır.
	p._buyucu_enchanted = {1: true}
	assert(p.is_buyucu_slot_enchanted("skill3") and not p.is_buyucu_slot_enchanted("skill2"), "Set 1'in R butonu parıldar")
	p._skill_buyucu_switch_variation()
	assert(p.is_buyucu_slot_enchanted("skill") and not p.is_buyucu_slot_enchanted("skill3"), "diğer sette: Q sönük ipucu")
	p._skill_buyucu_switch_variation()
	var e: FakeEnemy = _make_enemy(Vector2(1360.0, 1000.0))
	await get_tree().physics_frame
	p._buyucu_try_activate_variation_r()
	assert(e.hits.size() == 1 and is_equal_approx(float(e.hits[0]), 125.0), "efsunlu Don Nova 400 px, x1,25 hasar: %s" % str(e.hits))
	assert(not p._buyucu_enchanted.has(1), "efsun tüketildi")
	assert(p._buyucu_cast_power == 1.0, "döküm sonrası çarpan sıfırlandı")
	_cleanup()


# ------------------------------------------------------------------ E evrimleri
func test_e2_e3_ef_numbers() -> void:
	var p: Node = _make_player()
	_evo(p, ["buyucu_e2", "buyucu_e3", "buyucu_ef"])
	assert(is_equal_approx(float(p._skill2_timing_for(22)["cooldown"]), 4.0 * 0.8), "Arcane bekleme -%20")
	assert(is_equal_approx(float(p._skill2_timing_for(24)["cooldown"]), 30.0 * 0.8), "Hortum bekleme -%20")
	assert(is_equal_approx(float(p._skill2_timing_for(23)["cooldown"]), 45.0), "R varyasyonları etkilenmez")
	assert(is_equal_approx(p._buyucu_arcane_ratio(), 0.8 * 1.3) and is_equal_approx(p._buyucu_tornado_ratio(), 0.9 * 1.3), "oranlar x1,3")
	assert(p._buyucu_arcane_bounce_count() == 7, "7 sekme")
	p._skill_buyucu_switch_variation() ## Set 2: Hortum
	p._buyucu_try_activate_variation()
	assert(p._buyucu_active_tornadoes.size() == 5, "5 hortum: %d" % p._buyucu_active_tornadoes.size())
	for t in p._buyucu_active_tornadoes:
		if is_instance_valid(t):
			t.free()
	_cleanup()


func test_e1_e4_arcane_blast_push_and_tornado_touch() -> void:
	var p: Node = _make_player()
	_evo(p, ["buyucu_e1", "buyucu_e4"])
	var target: FakeEnemy = _make_enemy(Vector2(1100.0, 1000.0))
	var near: FakeEnemy = _make_enemy(Vector2(1150.0, 1000.0)) ## patlama yarıçapında (75)
	var far: FakeEnemy = _make_enemy(Vector2(1300.0, 1000.0))
	await get_tree().physics_frame
	p._buyucu_try_activate_variation() ## Set 1: Arcane Lanet - ilk isabet senkron
	assert(target.hits.size() == 1 and is_equal_approx(float(target.hits[0]), 80.0), "ilk sekme %%80: %s" % str(target.hits))
	assert(near.hits.size() == 1 and is_equal_approx(float(near.hits[0]), 60.0) and bool(near.area_flags[0]),
		"patlama: isabetin %%75'i, alan hasarı: %s" % str(near.hits))
	assert(far.hits.is_empty(), "patlama alanının dışı etkilenmez")
	assert(target.pushes.size() == 1 and float(target.pushes[0][1]) == p.EVO_BUYUCU_ARCANE_PUSH, "isabet edilen geri itilir")
	var t_enemy: FakeEnemy = _make_enemy(Vector2(900.0, 1000.0))
	p.buyucu_tornado_touch(t_enemy)
	assert(t_enemy.elements.size() == 1 and str(t_enemy.elements[0][0]) == "vuln" and is_equal_approx(float(t_enemy.elements[0][1]["pct"]), 0.2),
		"hortum teması +%%20 alınan hasar: %s" % str(t_enemy.elements))
	assert(t_enemy.stuns == [1.0], "hortum teması 1 sn sersemletir")
	await get_tree().create_timer(0.6).timeout ## kalan sekmeler bitsin
	_cleanup()


# ------------------------------------------------------------------ R evrimleri
func test_r1_airborne_untargetable_and_nova_push() -> void:
	var p: Node = _make_player()
	p._skill_buyucu_switch_variation() ## Set 2: Meteor
	p._skill_buyucu_meteor()
	assert(not p.is_buyucu_airborne(), "evrimsiz meteor kanalı yerde")
	p._buyucu_meteor_channel_active = false
	p.is_buyucu_channeling = false
	_evo(p, ["buyucu_r1"])
	p._skill_buyucu_meteor()
	assert(p.is_buyucu_airborne() and p.is_invisible_now(), "Yükseliş: havada + hedef alınamaz")
	assert(p.get_node_or_null("BuyucuLevitate") != null, "yükselme görseli kuruldu")
	var hp0: float = p.health
	var sh0: float = p.item_shield_hp
	p.take_damage(50.0)
	assert(p.health == hp0 and p.item_shield_hp == sh0, "havadayken hasar işlenmez")
	p._buyucu_meteor_channel_active = false
	p.is_buyucu_channeling = false
	assert(not p.is_buyucu_airborne(), "kanal bitince iner")
	## Don Nova itmesi: 100 px'teki yaratık alanın kenarının dışına (320 + 24 - 100 = 244).
	p._skill_buyucu_switch_variation() ## Set 1
	var e: FakeEnemy = _make_enemy(Vector2(1100.0, 1000.0))
	await get_tree().physics_frame
	p._buyucu_try_activate_variation_r()
	assert(e.pushes.size() == 1 and is_equal_approx(float(e.pushes[0][1]), 244.0) and (e.pushes[0][0] as Vector2).x > 0.0,
		"Don Nova dışarı iter: %s" % str(e.pushes))
	_cleanup()


func test_r2_free_nova_and_faster_meteors() -> void:
	var p: Node = _make_player()
	_evo(p, ["buyucu_r2"])
	var sh0: float = p.item_shield_hp
	p._buyucu_try_activate_variation_r() ## Set 1: Don Nova (hedefsiz de bedel/bekleme normalde ödenir)
	assert(p.item_shield_hp == sh0, "Don Nova bedelsiz")
	p._skill_buyucu_switch_variation()
	p._skill_buyucu_meteor()
	p._process_buyucu_meteor(0.01)
	assert(is_equal_approx(p._buyucu_meteor_spawn_timer, p.BUYUCU_METEOR_INTERVAL / 1.3), "meteor aralığı /1,3: %.3f" % p._buyucu_meteor_spawn_timer)
	p._buyucu_meteor_channel_active = false
	p.is_buyucu_channeling = false
	await get_tree().create_timer(0.7).timeout ## düşen meteor coroutine'i bitsin
	_cleanup()


func test_rf_nova_freeze_and_meteor_crater() -> void:
	var p: Node = _make_player()
	_evo(p, ["buyucu_rf"])
	var e: FakeEnemy = _make_enemy(Vector2(1100.0, 1000.0))
	await get_tree().physics_frame
	p._buyucu_try_activate_variation_r()
	assert(e.freezes == [p.EVO_BUYUCU_NOVA_FREEZE_TIME] and e.frost_slows.size() == 1, "itmesiz: hemen 3 sn donma + yavaşlatma: %s" % str(e.freezes))
	## Krater: meteor düşünce (0,5 sn telegraph) yerinde evo_area "buyucu_crater"; içindeki yaratık yanar (3 sn, AP x0,3).
	p._buyucu_meteor_origin = p.global_position
	p._spawn_buyucu_meteor_strike()
	var deadline: int = Time.get_ticks_msec() + 2000
	var crater: Node2D = null
	while crater == null and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		for c in get_tree().current_scene.get_children():
			if c.get("kind") == "buyucu_crater":
				crater = c
	assert(crater != null, "meteor krater bıraktı")
	if crater != null:
		_spawned.append(crater)
		var victim: FakeEnemy = _make_enemy(crater.global_position + Vector2(10.0, 0.0))
		await get_tree().physics_frame
		crater.call("_crater_tick") ## kraterin kendi tiki de o arada yakmış olabilir - her yanma aynı değerde olmalı
		var burns_ok: bool = not victim.burns.is_empty()
		for b in victim.burns:
			burns_ok = burns_ok and is_equal_approx(float(b[0]), 30.0) and is_equal_approx(float(b[1]), 3.0)
		assert(burns_ok, "krater yakar (3 sn, saniyede AP x0,3): %s" % str(victim.burns))
	_cleanup()


# ------------------------------------------------------------------ yaratık: buz yavaşlatması (gerçek sahne)
func test_real_enemy_frost_slow_tint_and_boss_immunity() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	NetworkManager.is_multiplayer_active = false
	var en: Node = EnemyScene.instantiate()
	add_child(en)
	_spawned.append(en)
	en.global_position = Vector2(300.0, 300.0)
	await get_tree().physics_frame
	en.apply_frost_slow(0.8, 6.0)
	assert(is_equal_approx(en._slow_percent, 0.8) and is_equal_approx(en._slow_timer, 6.0), "%%80 yavaş (eşya tavanı %%75'i aşar): %.2f" % en._slow_percent)
	assert(en._frost_chill_active(), "buz kristalleri kuruldu")
	assert(en._status_tint_color() == en.FROST_SLOW_TINT_COLOR, "mavimsi ton")
	en.apply_slow(0.9, 2.0) ## Kitelama Seti yolu hâlâ %75 tavanlı - frost yüksek değeri korunur
	assert(is_equal_approx(en._slow_percent, 0.8), "daha düşük tavanlı yavaşlatma ezmez")
	var boss: Node = EnemyScene.instantiate()
	add_child(boss)
	_spawned.append(boss)
	boss.is_boss = true
	await get_tree().physics_frame
	boss.apply_frost_slow(0.8, 6.0)
	assert(boss._slow_percent == 0.0 and not boss._frost_chill_active(), "bosslar bağışık")
	_cleanup()


# ------------------------------------------------------------------ uzak kukla + HUD
func test_remote_puppet_flies_and_is_untargetable() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var rp: Node = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(97, BUYUCU, "Büyücü")
	rp.update_extra_state_from_net(100.0, 100.0, 0.0, 0.0, false, false, [], {"byc_fly": true})
	assert(rp.is_invisible and rp.is_buyucu_airborne(), "kukla havada: hedef alınamaz")
	assert(rp.get_node_or_null("BuyucuLevitate") != null, "kuklada da yükselme görseli")
	rp.update_extra_state_from_net(100.0, 100.0, 0.0, 0.0, false, false, [], {})
	assert(not rp.is_invisible and not rp.is_buyucu_airborne(), "indi")
	_cleanup()


func test_skill_icon_enchant_glow_draws() -> void:
	var ic: Control = (load("res://scripts/skill_icon.gd") as GDScript).new()
	ic.size = Vector2(66.0, 66.0)
	add_child(ic)
	_spawned.append(ic)
	ic.set_enchant_glow(1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(ic._enchant_glow == 1.0 and ic._enchant_glow_t > 0.0, "parıltı açık ve canlanıyor")
	ic.set_enchant_glow(0.0)
	_cleanup()
