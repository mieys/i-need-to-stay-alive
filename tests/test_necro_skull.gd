extends Node

## Necromancer ULTİ - Lanetli Kafatası (id 44, kullanıcı isteği 2026-09-24; 2026-10-11 REWORK: pasif etrafında dönen %50 küçük kafatası,
## R'de %100 büyür) + rastgele yürüyen korku (artık yalnız evrim "Korku Darbesi") + çağırma efekti.
## (Ağ tarafı - kozmetik kafatasının bacakları, korku göstergesinin diğer istemcide görünmesi - gerçek 2 pencereli testle
## doğrulanmalı; burası kurallar ve tek istemcili davranış.)

const EnemyWorldBridgeScript: GDScript = preload("res://scripts/enemy_world/enemy_world_bridge.gd")
const PlayerScript = preload("res://scripts/player.gd")
const SkullScript = preload("res://scripts/necro_skull.gd")
const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")


class FakeTarget extends Node2D:
	var hits: int = 0
	func take_damage(_amount: float, _src: Node = null) -> void:
		hits += 1


func _spawn_enemy(pos: Vector2, boss: bool = false) -> Node2D:
	var e: Node2D = EnemyScene.instantiate() as Node2D
	add_child(e)
	e.global_position = pos
	e.is_boss = boss
	e.set_physics_process(false)
	return e


func _fake_caster(pos: Vector2, ap: float) -> Node2D:
	var c := Node2D.new()
	var src := GDScript.new()
	src.source_code = "extends Node2D\nvar damage_bonus: float = %s\nvar evos: Dictionary = {}\nvar marked: Array = []\nfunc has_evo(id: String) -> bool:\n\treturn evos.has(id)\nfunc _necro_curse_mark(e: Node, _d: float) -> void:\n\tmarked.append(e)\n" % ap
	src.reload()
	c.set_script(src)
	add_child(c)
	c.global_position = pos
	return c


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.remove_from_group("enemies")
			e.queue_free()


func test_necromancer_r_is_the_skull() -> void:
	var d: Dictionary = Characters.DEFS[11]
	assert(int(d["skill3"]) == 44, "Necromancer R artık Lanetli Kafatası (44) olmalı")
	assert(ResourceLoader.exists(str(d["skill3_icon"])), "R ikonu bulunmalı: %s" % d["skill3_icon"])
	var t: Dictionary = PlayerScript.SKILL3_TIMING[44]
	assert(is_equal_approx(float(t["duration"]), SkullScript.DURATION) and is_equal_approx(SkullScript.DURATION, 10.0), "10sn çarpma")
	assert(is_equal_approx(float(t["cooldown"]), 60.0), "60sn bekleme")
	assert(is_equal_approx(SkullScript.PASSIVE_DAMAGE_AP_RATIO, 0.50) and is_equal_approx(SkullScript.ACTIVE_DAMAGE_AP_RATIO, 1.25), "pasif 0.50 / aktif 1.25")
	assert(is_equal_approx(SkullScript.PASSIVE_SCALE, 0.5) and is_equal_approx(SkullScript.EVO_FEAR_DURATION, 1.0), "yarı boy, korku yalnız evrimle 1sn")
	var src: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	assert(src.contains("44: _skill_necro_skull()"), "skill3 match'i kafatasını çağırmalı")


## Kullanıcı isteği (2026-09-24): "iskelet Q golem E kafatası da R olmalı yarasayı ... yok et".
func test_kit_is_skeleton_golem_skull_and_bats_are_gone() -> void:
	var d: Dictionary = Characters.DEFS[11]
	assert(int(d["skill"]) == 19 and int(d["skill2"]) == 20 and int(d["skill3"]) == 44, "Q iskelet / E golem / R kafatası")
	assert(ResourceLoader.exists(str(d["skill2_icon"])), "E ikonu bulunmalı")
	assert(PlayerScript.SKILL2_TIMING.has(20) and not PlayerScript.SKILL2_TIMING.has(35), "golem E zamanlaması var, yarasa yok")
	assert(not PlayerScript.SKILL3_TIMING.has(20), "golem artık R'de değil")
	assert(not ResourceLoader.exists("res://scenes/necro_bat.tscn") and not ResourceLoader.exists("res://scripts/necro_bat.gd"), "yarasa dosyaları silinmiş olmalı")
	var src: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	for gone in ["_necro_toggle_bats", "_process_necro_bats", "_launch_necro_bats", "NecroBatScene", "_necro_bats_active"]:
		assert(not src.contains(gone), "yarasa kodu kalmamalı: %s" % gone)
	assert(src.contains("func _necro_golem_can_summon()"), "golem ön kontrolü E'de")


func test_baked_resources() -> void:
	var expect := {"skull": ["fly", "appear", "vanish", "shadow"], "impact": ["play"], "summon": ["play"], "trail": ["play"], "fear": ["loop"]}
	for n in expect:
		var sf: SpriteFrames = load("res://assets/fx/necro/%s_frames.tres" % n) as SpriteFrames
		assert(sf != null, "%s_frames.tres yüklenemedi (import?)" % n)
		for a in expect[n]:
			assert(sf.has_animation(a) and sf.get_frame_count(a) > 0, "%s/%s" % [n, a])
	assert(load("res://scenes/fx_necro_summon.tscn") != null and load("res://scenes/fx_fear_status.tscn") != null)


func test_wander_fear_blocks_damage_and_expires() -> void:
	_clear_enemies()
	var e: Node2D = _spawn_enemy(Vector2(200, 200))
	e.apply_fear_wander(3.0)
	assert(e.is_feared and e._fear_wander, "rastgele yürüme korkusu başlamalı")
	assert(e._fear_status_fx != null and is_instance_valid(e._fear_status_fx), "başının üstünde korku göstergesi olmalı")
	## zamanlanmış yakın dövüş vuruşu korkmuşken iptal
	var tgt := FakeTarget.new()
	add_child(tgt)
	tgt.global_position = e.global_position
	await e._schedule_melee_hit(0.0, tgt)
	assert(tgt.hits == 0, "korkmuş yaratık hasar verememeli")
	## rastgele yön (yaratık yeniden yazımı: korku-dolaşma hareketi C++ EnemyWorld'de, 0,45-1 sn'de bir yeni yön): köprüyü
	## elle adımlayıp 0,5 sn'lik hareket yönlerini örnekle - en az iki farklı yön.
	await get_tree().process_frame ## köprü ertelenerek eklenir
	var bridge: Node = EnemyWorldBridgeScript._instance
	assert(bridge != null and int(e.get("_ew_slot")) >= 0, "yaratık C++'a kaydolmalı")
	bridge.set_physics_process(false)
	var dirs: Array = []
	for i in 4:
		var p0: Vector2 = e.global_position
		for k in 30:
			bridge._physics_process(1.0 / 60.0)
		dirs.append((e.global_position - p0).normalized())
	bridge.set_physics_process(true)
	var distinct := false
	for d in dirs:
		if d.distance_to(dirs[0]) > 0.1:
			distinct = true
	assert(distinct, "korku yönü rastgele değişmeli")
	e._process_fear(3.1)
	assert(not e.is_feared and not e._fear_wander, "3sn sonra biter")
	await get_tree().process_frame
	assert(e._fear_status_fx == null, "gösterge kalkmalı")
	tgt.queue_free()
	e.queue_free()


func test_bosses_are_not_feared_by_default() -> void:
	_clear_enemies()
	var b: Node2D = _spawn_enemy(Vector2(0, 0), true)
	b.apply_fear_wander(3.0, SkullScript.FEAR_AFFECTS_BOSSES)
	assert(not b.is_feared, "varsayılan: bosslar korkmaz (Melek korkusuyla aynı kural)")
	b.apply_fear_wander(3.0, true)
	assert(b.is_feared, "affect_boss=true iken boss da korkar")
	b.queue_free()


func test_skull_prefers_crowds_then_bosses() -> void:
	_clear_enemies()
	await get_tree().process_frame
	var caster: Node2D = _fake_caster(Vector2.ZERO, 100.0)
	var skull: Node2D = SkullScript.new()
	add_child(skull)
	skull.caster = caster
	skull.global_position = Vector2.ZERO
	var lone: Node2D = _spawn_enemy(Vector2(60, 0))
	var crowd: Array = []
	for off in [Vector2(0, 0), Vector2(20, 10), Vector2(-15, 12), Vector2(10, -18)]:
		crowd.append(_spawn_enemy(Vector2(300, 100) + off))
	var p: Variant = skull._pick_target_point()
	assert(p != null and (p as Vector2).distance_to(Vector2(300, 100)) < 40.0, "kalabalığa gitmeli (bulunan %s)" % [p])
	var boss: Node2D = _spawn_enemy(Vector2(-350, 0), true)
	p = skull._pick_target_point()
	assert(p != null and (p as Vector2).distance_to(boss.global_position) < 1.0, "boss önceliği kalabalığı geçmeli (bulunan %s)" % [p])
	var far: Node2D = _spawn_enemy(Vector2(SkullScript.SEEK_RANGE + 200, 0), true)
	p = skull._pick_target_point()
	assert((p as Vector2).distance_to(far.global_position) > 1.0, "menzil dışı boss seçilmemeli")
	for n in crowd + [lone, boss, far, skull, caster]:
		n.queue_free()


func test_impact_damages_and_fears_everything_in_radius() -> void:
	_clear_enemies()
	await get_tree().process_frame
	var caster: Node2D = _fake_caster(Vector2.ZERO, 100.0)
	caster.evos["necro_r1"] = true ## Korku Darbesi
	var skull: Node2D = SkullScript.new()
	add_child(skull)
	skull.caster = caster
	skull.set_active(SkullScript.DURATION) ## aktif: tam boy vuruş alanı (pasifte yarısı)
	var near_a: Node2D = _spawn_enemy(Vector2(500, 500))
	var near_b: Node2D = _spawn_enemy(Vector2(500 + SkullScript.IMPACT_RADIUS - 5.0, 500))
	var outside: Node2D = _spawn_enemy(Vector2(500 + SkullScript.IMPACT_RADIUS + 30.0, 500))
	for e in [near_a, near_b, outside]:
		e.health = 10000.0
		e.max_health = 10000.0
		e.shield_protection = 0.0
	skull._impact(Vector2(500, 500))
	for e in [near_a, near_b]:
		assert(e.health < 10000.0, "alan içindeki yaratık hasar almalı (can %s)" % e.health)
		assert(e.is_feared and e._fear_wander, "Korku Darbesi evrimiyle alan içindeki yaratık korkmalı")
		assert(e._fear_timer <= SkullScript.EVO_FEAR_DURATION + 0.01, "korku 1sn")
	assert(is_equal_approx(outside.health, 10000.0) and not outside.is_feared, "alan dışı etkilenmemeli")
	for n in [near_a, near_b, outside, skull, caster]:
		n.queue_free()


func test_passive_is_half_size_and_weaker_than_active() -> void:
	var skull: Node2D = SkullScript.new()
	add_child(skull)
	assert(not skull.is_active())
	assert(is_equal_approx(skull._impact_radius(), SkullScript.IMPACT_RADIUS * 0.5), "pasif vuruş alanı yarım")
	assert(is_equal_approx(skull._damage_ratio(), 0.50) and skull._seek_range() < SkullScript.SEEK_RANGE)
	skull.set_active(SkullScript.DURATION)
	assert(skull.is_active() and is_equal_approx(skull._impact_radius(), SkullScript.IMPACT_RADIUS), "aktif: vuruş alanı yüzde 100 artar")
	assert(is_equal_approx(skull._damage_ratio(), 1.25) and is_equal_approx(skull._seek_range(), SkullScript.SEEK_RANGE))
	skull._active_left = 0.0
	assert(is_equal_approx(skull._damage_ratio(), 0.50), "süre bitince pasife döner")
	skull.queue_free()


func test_no_fear_or_curse_without_evolutions() -> void:
	_clear_enemies()
	await get_tree().process_frame
	var caster: Node2D = _fake_caster(Vector2.ZERO, 100.0)
	var skull: Node2D = SkullScript.new()
	add_child(skull)
	skull.caster = caster
	var e: Node2D = _spawn_enemy(Vector2(500, 500))
	e.health = 10000.0
	e.max_health = 10000.0
	e.shield_protection = 0.0
	skull._impact(Vector2(500, 500))
	assert(e.health < 10000.0, "pasif vuruş da hasar verir")
	assert(not e.is_feared, "korku artık temel yetenekte YOK")
	assert(caster.marked.is_empty(), "lanet evrimsiz işaretlenmez")
	for n in [e, skull, caster]:
		n.queue_free()


func test_curse_evolution_marks_and_makes_enemy_vulnerable() -> void:
	_clear_enemies()
	await get_tree().process_frame
	var caster: Node2D = _fake_caster(Vector2.ZERO, 100.0)
	caster.evos["necro_rf"] = true
	var skull: Node2D = SkullScript.new()
	add_child(skull)
	skull.caster = caster
	var e: Node2D = _spawn_enemy(Vector2(500, 500))
	e.health = 10000.0
	e.max_health = 10000.0
	e.shield_protection = 0.0
	skull._impact(Vector2(500, 500))
	assert(caster.marked.has(e), "lanetli yaratık oyuncuya işaretlenmeli (ölürse iskelet şansı)")
	assert(e._vuln_pct >= 0.0999, "lanetli yaratık yüzde 10 fazla hasar almalı: %f" % e._vuln_pct)
	for n in [e, skull, caster]:
		n.queue_free()


func test_hit_speed_scales_with_attack_speed_only_with_evolution() -> void:
	var caster: Node2D = _fake_caster(Vector2.ZERO, 50.0)
	var src := GDScript.new()
	src.source_code = "extends Node2D\nvar damage_bonus: float = 50.0\nvar evos: Dictionary = {}\nvar ivl: float = 0.5\nfunc has_evo(id: String) -> bool:\n\treturn evos.has(id)\nfunc get_attack_interval_mult() -> float:\n\treturn ivl\n"
	src.reload()
	caster.set_script(src)
	var skull: Node2D = SkullScript.new()
	add_child(skull)
	skull.caster = caster
	assert(is_equal_approx(skull._speed_mult(), 1.0), "evrimsiz vuruş hızı saldırı hızına bağlı değil")
	caster.evos["necro_r2"] = true
	assert(is_equal_approx(skull._speed_mult(), 2.0), "aralık çarpanı 0.5 -> vuruş hızı x2")
	skull.queue_free()
	caster.queue_free()


func test_idle_skull_orbits_close_to_owner() -> void:
	_clear_enemies()
	await get_tree().process_frame
	var caster: Node2D = _fake_caster(Vector2(300, 300), 50.0)
	var skull: Node2D = SkullScript.new()
	add_child(skull)
	skull.caster = caster
	skull.global_position = Vector2(300, 300)
	var max_d: float = 0.0
	for i in 240:
		skull._process(1.0 / 60.0)
		max_d = maxf(max_d, skull.global_position.distance_to(caster.global_position))
	assert(max_d > 8.0, "boştaki kafatası sahibinin etrafında dönmeli (hareket etmiyor: %f)" % max_d)
	assert(max_d < SkullScript.ORBIT_RADIUS * 1.5, "yörünge sahibe yakın kalmalı: %f" % max_d)
	skull.queue_free()
	caster.queue_free()


func test_skull_becomes_passive_again_after_active_time() -> void:
	var skull: Node2D = SkullScript.new()
	add_child(skull)
	var caster: Node2D = _fake_caster(Vector2.ZERO, 10.0)
	skull.caster = caster
	skull.set_active(0.5)
	for i in 20:
		skull._process(1.0 / 60.0)
	assert(skull.is_active(), "0.5sn dolmadan aktif")
	for i in 40:
		skull._process(1.0 / 60.0)
	assert(not skull.is_active(), "süre dolunca pasife dönmeli")
	skull.queue_free()
	caster.queue_free()
