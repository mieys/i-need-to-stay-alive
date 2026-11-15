extends Node

## MEDUSA (madde 682, 2026-11-14, Altın Kumlar K10 = son boss). Kapsam: sayfa/sahne/tablo, K10 yuva statları (yuvanın %20 üstü), taşlaştıran bakış
## (yelpaze, ışın içi/dışı, duvarda biter), GERÇEK oyuncuda karar: ona doğru yürürken taşlaşma (2 sn sersem + rozet), yürümüyorken %30 yavaşlama
## (2 sn), ikisinde de hasar; Yılan Kırbacı konisi + zehir + taşlaşmışa x2; faz 2 çifte bakış + 3. bakışta 360° halka; Kum Süzülüşü.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const AbilitiesScript: GDScript = preload("res://scripts/enemy_abilities.gd")
const KitScript: GDScript = preload("res://scripts/medusa_boss.gd")
const BossBarArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")
const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _made: Array[Node] = []


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var is_indoors: bool = false
	var hits: Array = []

	func take_special_damage(amount: float, _source: Node2D, kind: String) -> void:
		hits.append([amount, kind])

	func take_damage(amount: float, _source: Node2D = null) -> void:
		hits.append([amount, "plain"])


func _cleanup() -> void:
	for g: String in ["enemies", "summons", "guards"]:
		for e: Node in get_tree().get_nodes_in_group(g):
			if is_instance_valid(e):
				e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for c: Node in get_children():
		if is_instance_valid(c) and c.get_script() != null and str(c.get_script().resource_path).get_file() == "medusa_gaze.gd":
			c.free()
	GameManager.game_time = 0.0
	NetworkManager.is_multiplayer_active = false


func _add(n: Node) -> Node:
	add_child(n)
	_made.append(n)
	return n


func _spawner() -> Node:
	_cleanup()
	get_tree().current_scene = self
	var sp: Node = SpawnerScript.new()
	sp.name = "EnemySpawner"
	_add(sp)
	sp.max_concurrent_enemies = 100000
	sp.tier_duration = 100.0
	return sp


func _player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	_add(p)
	p.global_position = pos
	return p


func _boss(sp: Node, pos: Vector2 = Vector2(500, 500)) -> Node:
	var b: Node = sp._spawn_creature("medusa1", pos, 779001)
	b.add_to_group("boss")
	sp._setup_boss_enemy(b, "medusa1", 10, 1)
	b._init_abilities()
	return b


func _gazes() -> Array:
	var out: Array = []
	for c: Node in get_children():
		if is_instance_valid(c) and not c.is_queued_for_deletion() and c.get_script() != null and str(c.get_script().resource_path).get_file() == "medusa_gaze.gd":
			out.append(c)
	return out


func _quiet(kit: RefCounted) -> void:
	kit._gaze_cd = 999.0
	kit._snake_cd = 999.0
	kit._dash_cd = 999.0


func _step(node: Node, seconds: float) -> void:
	for i in int(ceil(seconds * 60.0)):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			return
		node._physics_process(1.0 / 60.0)


func test_sheets_scene_tables_and_k10_stats() -> void:
	var sheets: Dictionary = {"medusa_walk": 4, "medusa_idle": 4, "medusa_gaze": 7, "medusa_snake": 6, "medusa_hurt": 2, "medusa_death": 6}
	for k: String in sheets.keys():
		var tex: Texture2D = load("res://assets/enemies/medusa/%s.png" % k) as Texture2D
		assert(tex != null and tex.get_height() == 512 and tex.get_width() == 128 * int(sheets[k]), "sayfa %s" % k)
	assert(SpawnerScript.SCENES.has("medusa1") and SpawnerScript.ID_FAMILY["medusa1"] == "medusa" and AbilitiesScript.family_has_ability("medusa"), "tablolar")
	assert(BossBarArtScript.display_name("medusa1") == "MEDUSA", "boss barı adı")
	var sp: Node = _spawner()
	var b: Node = _boss(sp)
	assert(b.max_health == 360000.0 and b.item_shield_max == 480000.0, "K10: yuvanın %%20 üstü: %.0f / %.0f" % [b.max_health, b.item_shield_max])
	assert(is_equal_approx(b.shield_protection, 0.9) and is_equal_approx(b.contact_damage, 180.0), "soğurma %90, ısırık 180")
	assert(is_equal_approx(float(b.get_meta("boss_damage_mult", 0.0)), 1.0), "kendi yuvasında x1")
	b.play_special_anim("gaze", 0.8)
	assert(b.frame_sprite.hframes == 7, "bakış klibi 7 kare")
	_cleanup()


func test_gaze_fans_out_hits_players_in_a_beam_and_misses_between_far_beams() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 500))
	var target: FakePlayer = _player(Vector2(500, 800))
	var side: FakePlayer = _player(Vector2(500 + 700, 500)) ## 90° yanda: 100°'lik yelpazenin dışı
	side.remove_from_group("player")
	side.add_to_group("remote_players")
	var kit: RefCounted = boss._abilities._boss_kit
	_quiet(kit)
	kit._gaze_cd = 0.0
	kit.process(0.05, target, 300.0)
	var g: Array = _gazes()
	assert(g.size() == 1 and (g[0].get("data")["angles"] as Array).size() == KitScript.GAZE_BEAMS, "%d ışınlı yelpaze" % KitScript.GAZE_BEAMS)
	assert(kit._busy > 0.0 and boss.ability_move_lock > 0.0, "bakarken durur")
	_step(g[0], KitScript.GAZE_WARN * 0.5)
	assert(target.hits.is_empty(), "uyarı süresinde hasar yok")
	_step(g[0], 1.0)
	assert(target.hits.size() == 1 and target.hits[0][1] == "medusa_gaze" and target.hits[0][0] == KitScript.GAZE_DAMAGE, "hedef bakışa yakalandı: %s" % str(target.hits))
	assert(side.hits.is_empty(), "yelpaze dışı etkilenmez")
	_cleanup()


func test_walking_into_the_gaze_petrifies_otherwise_it_slows() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 200))
	var real: Node = PlayerScene.instantiate()
	_add(real)
	await get_tree().process_frame
	real.global_position = Vector2(500, 500)
	real.max_health = 100000.0 ## ardışık isabetlerde ölmesin
	real.health = 100000.0
	## Medusa'ya doğru (yukarı) yürüyor
	real.velocity = Vector2(0, -150)
	var hp0: float = real.health + real.item_shield_hp
	real._last_damage_taken_at_msec = -1000000 ## temas dokunulmazlığı (CONTACT_DAMAGE_IFRAME_MS) testte ardışık isabeti yutmasın
	real.take_special_damage(100.0, boss, "medusa_gaze")
	assert(real.health + real.item_shield_hp < hp0, "taşlaşırken de hasar")
	assert(real.is_stunned and is_equal_approx(real._petrify_left, 2.0), "ona doğru yürürken 2 sn taşlaşma")
	assert(real.get_status_effects().any(func(d: Dictionary) -> bool: return d["kind"] == "petrify"), "taşlaşma rozeti")
	assert(real._pvp_slow_left <= 0.0, "taşlaşmada yavaşlama yok")
	var fx_found: bool = false
	for c: Node in real.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("fx_petrify.gd"):
			fx_found = true
	assert(fx_found, "taş kabuğu görseli")
	for i in range(130):
		real._process_stun(1.0 / 60.0)
	assert(not real.is_stunned and real._petrify_left <= 0.0, "2 sn sonra çözülür")
	## Yana yürüyor -> yavaşlama
	real.velocity = Vector2(150, 0)
	var hp1: float = real.health + real.item_shield_hp
	real._last_damage_taken_at_msec = -1000000 ## temas dokunulmazlığı (CONTACT_DAMAGE_IFRAME_MS) testte ardışık isabeti yutmasın
	real.take_special_damage(100.0, boss, "medusa_gaze")
	assert(real.health + real.item_shield_hp < hp1, "yavaşlarken de hasar")
	assert(not real.is_stunned and is_equal_approx(real._pvp_slow_pct, 0.3) and is_equal_approx(real._pvp_slow_left, 2.0), "yürümüyorken 2 sn %%30 yavaş")
	assert(real.get_status_effects().any(func(d: Dictionary) -> bool: return d["kind"] == "stone_slow"), "taş ağırlığı rozeti")
	## Duruyor -> yavaşlama (taşlaşma değil)
	real._pvp_slow_left = 0.0
	real.velocity = Vector2.ZERO
	real._last_damage_taken_at_msec = -1000000 ## temas dokunulmazlığı (CONTACT_DAMAGE_IFRAME_MS) testte ardışık isabeti yutmasın
	real.take_special_damage(100.0, boss, "medusa_gaze")
	assert(not real.is_stunned and real._pvp_slow_left > 0.0, "dururken yavaşlama")
	_cleanup()


func test_snake_lash_hits_the_cone_poisons_and_doubles_on_stone() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 500))
	var front: FakePlayer = _player(Vector2(500, 620))
	var behind: FakePlayer = _player(Vector2(500, 380))
	behind.remove_from_group("player")
	behind.add_to_group("remote_players")
	var kit: RefCounted = boss._abilities._boss_kit
	_quiet(kit)
	kit._snake_cd = 0.0
	kit.process(0.05, front, 120.0)
	assert(kit._busy > 0.0, "yılan kırbacı başladı")
	for i in range(30):
		kit.process(0.02, front, 120.0)
	assert(front.hits.size() == 1 and front.hits[0][1] == "medusa_snake" and front.hits[0][0] == KitScript.SNAKE_DAMAGE, "önündeki: %s" % str(front.hits))
	assert(behind.hits.is_empty(), "arkasındaki koni dışında")
	assert(boss._abilities.handle_melee_hit(front) and front.hits[-1][1] == "medusa_snake", "ısırık da aynı tür")
	## Gerçek oyuncu: zehir + taşken x2
	var real: Node = PlayerScene.instantiate()
	_add(real)
	await get_tree().process_frame
	real.max_health = 100000.0
	real.health = 100000.0
	var h0: float = real.health + real.item_shield_hp
	real._last_damage_taken_at_msec = -1000000
	real.take_special_damage(100.0, boss, "medusa_snake")
	var plain: float = h0 - (real.health + real.item_shield_hp)
	assert(real._enemy_poison_timer > 0.0 and is_equal_approx(real._enemy_poison_dps, 30.0), "yılan zehri 30/sn")
	real.apply_petrify(2.0)
	var h1: float = real.health + real.item_shield_hp
	real._last_damage_taken_at_msec = -1000000
	real.take_special_damage(100.0, boss, "medusa_snake")
	var stone: float = h1 - (real.health + real.item_shield_hp)
	assert(stone > plain * 1.8, "taşlaşmışa x2 (taş kırılması): %.1f / %.1f" % [stone, plain])
	_cleanup()


func test_phase_two_double_gaze_and_every_third_is_a_full_ring() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 500))
	var target: FakePlayer = _player(Vector2(500, 800))
	boss.health = boss.max_health * 0.3
	boss.item_shield_hp = 0.0
	var kit: RefCounted = boss._abilities._boss_kit
	assert(kit._phase2() and is_equal_approx(kit._haste(), KitScript.PHASE2_CD_MULT), "faz 2")
	_quiet(kit)
	kit._gaze_cd = 0.0
	kit.process(0.05, target, 300.0) ## 1. bakış: yelpaze + ikinci bakış
	for i in range(int(KitScript.GAZE_SECOND_DELAY / 0.02) + 3):
		kit._run_queue(0.02)
	var g: Array = _gazes()
	assert(g.size() == 2, "faz 2: ikinci bakış: %d" % g.size())
	assert((g[0].get("data")["angles"] as Array).size() == KitScript.GAZE_BEAMS_P2, "faz 2 yelpazesi genişler")
	for n in g:
		n.free()
	kit._gaze_count = KitScript.GAZE_RING_EVERY - 1
	kit._busy = 0.0
	kit._gaze_cd = 0.0
	kit.process(0.05, target, 300.0)
	g = _gazes()
	assert(g.size() == 1 and (g[0].get("data")["angles"] as Array).size() == KitScript.GAZE_RING_BEAMS, "3. bakış: 360° taş halkası")
	_cleanup()


func test_sand_glide_speeds_toward_a_far_target_then_lashes() -> void:
	var sp: Node = _spawner()
	var boss: Node = _boss(sp, Vector2(500, 500))
	var far: FakePlayer = _player(Vector2(500, 1100))
	var kit: RefCounted = boss._abilities._boss_kit
	_quiet(kit)
	kit._dash_cd = 0.0
	kit.process(0.05, far, 600.0)
	for i in range(25):
		kit.process(0.02, far, 600.0)
	assert(is_equal_approx(boss.gate_rush_mult, KitScript.DASH_MULT) and kit._dash_left > 0.0, "süzülüyor: x%.1f" % boss.gate_rush_mult)
	kit.process(0.02, far, 100.0) ## yetişti
	assert(is_equal_approx(boss.gate_rush_mult, 1.0) and kit._snake_cd <= 0.0, "yaklaşınca süzülüş biter, yılan kırbacı hazır")
	_cleanup()
