extends Node

## Necromancer YENİ ULTİ - Lanetli Kafatası (id 44, kullanıcı isteği 2026-09-24) + rastgele yürüyen korku + çağırma efekti.
## (Ağ tarafı - kozmetik kafatasının bacakları, korku göstergesinin diğer istemcide görünmesi - gerçek 2 pencereli testle
## doğrulanmalı; burası kurallar ve tek istemcili davranış.)

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
	src.source_code = "extends Node2D\nvar damage_bonus: float = %s\n" % ap
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
	assert(is_equal_approx(SkullScript.DAMAGE_AP_RATIO, 1.10) and is_equal_approx(SkullScript.FEAR_DURATION, 3.0))
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
	## rastgele yön: birkaç yeniden seçimde en az iki farklı yön
	var dirs: Array = []
	for i in 6:
		e._fear_wander_retarget = 0.0
		e._fear_wander_velocity(0.016)
		dirs.append(e._fear_wander_dir)
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
	var skull: Node2D = SkullScript.new()
	add_child(skull)
	skull.caster = caster
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
		assert(e.is_feared and e._fear_wander, "alan içindeki yaratık korkmalı")
	assert(is_equal_approx(outside.health, 10000.0) and not outside.is_feared, "alan dışı etkilenmemeli")
	for n in [near_a, near_b, outside, skull, caster]:
		n.queue_free()
