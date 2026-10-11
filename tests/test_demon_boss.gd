extends Node

## Uçan Şeytan (FİNAL bossu, 2026-10-09): masaüstü `uçan şeytan` paketi + "boss ve yetenekleri.txt" (can 1.000.000, kalkan 1.200.000, soğurma %90, 4x boy + parıltı; seri ateş topları 200 + yanma 50/sn;
## kozmik ışın 100/0,5 sn; uçarak saldırı 150; %50 canda faz 2: kırmızı gözler, daha sık, iyileşme büyüsü %1/sn) + kullanıcı: "final bossu öldürdükten sonra sonsuz mod açılacak".
## Kapsam: sayfa/sahne/tablo/stat/boyut/parıltı, Final akışı (tüm kademeler -> Uçan Şeytan -> ölünce zafer -> Sonsuza Devam -> sonsuz mod), ateş topu salvosu + isabet + yanma, ışın dönüşü/hasar ticki,
## uçarak saldırı, faz 2 geçişi + iyileşme.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const AbilitiesScript: GDScript = preload("res://scripts/enemy_abilities.gd")
const KitScript: GDScript = preload("res://scripts/demon_boss.gd")
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


func _cleanup() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for c: Node in get_children():
		if is_instance_valid(c) and c.get_script() != null and (str(c.get_script().resource_path).contains("demon_fireball") or str(c.get_script().resource_path).contains("cosmic_beam")):
			c.free()
	GameManager.bosses_enabled = false
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
	sp.tier_duration = 100.0 ## testler 100 sn'lik kademelere göre yazıldı (varsayılan 2026-10-10'da 150 oldu; kademe süresi bu testlerin konusu değil)
	return sp


func _player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	_add(p)
	p.global_position = pos
	return p


func _boss(sp: Node, pos: Vector2) -> Node:
	var b: Node = sp._spawn_creature("ucansetan1", pos, 555001)
	b.add_to_group("boss")
	sp._setup_boss_enemy(b, "ucansetan1", 16, 1)
	b._init_abilities()
	return b


func _fx(script_part: String) -> Array:
	var out: Array = []
	for c: Node in get_children():
		if is_instance_valid(c) and c.get_script() != null and str(c.get_script().resource_path).contains(script_part):
			out.append(c)
	return out


func test_sheets_scene_tables_stats_size_and_glow() -> void:
	var sheets: Dictionary = {"fly": 4, "attack": 5, "cast": 6, "death": 6, "hurt": 2}
	for k: String in sheets.keys():
		var tex: Texture2D = load("res://assets/enemies/demon/demon_%s.png" % k) as Texture2D
		assert(tex != null and tex.get_height() == 320 and tex.get_width() == 80 * int(sheets[k]), "sayfa %s" % k)
	var shot: Texture2D = load("res://assets/fx/demon/fire_shot.png") as Texture2D
	assert(shot != null and shot.get_width() == 128 and shot.get_height() == 24, "ateş topu şeridi")
	assert(SpawnerScript.SCENES.has("ucansetan1") and SpawnerScript.ID_FAMILY["ucansetan1"] == "ucansetan" and AbilitiesScript.family_has_ability("ucansetan"), "tablolar")
	assert(SpawnerScript.NEW_FINAL_BOSSES == ["ucansetan1"], "yeni Final")
	assert(BossBarArtScript.display_name("ucansetan1") == "UÇAN ŞEYTAN", "boss barı adı")
	var sp: Node = _spawner()
	var b: Node = _boss(sp, Vector2(500, 500))
	assert(b.max_health == 1000000.0 and b.item_shield_max == 1200000.0, "can/kalkan: %.0f / %.0f" % [b.max_health, b.item_shield_max])
	assert(is_equal_approx(b.shield_protection, 0.9) and is_equal_approx(b.contact_damage, 150.0 * SpawnerScript.CREATURE_DAMAGE_CUT), "soğurma %90, saldırı 150 x0,8 (2026-10-11)")
	assert(absf(b.frame_sprite.scale.x - 1.6 * EntityScale.SIZE * EntityScale.BOSS_EXTRA * 4.0) < 0.001, "4x boyut")
	assert(b.get_node_or_null("BossGlow") != null and b.no_body_block, "dışa parıltı + içinden geçilebilir")
	_cleanup()


func test_final_flow_demon_spawns_after_the_tiers_and_killing_it_opens_endless() -> void:
	var sp: Node = _spawner()
	_player(Vector2(1000, 1000))
	assert(sp._final_active() and sp._final_ids() == ["ucansetan1"], "Final aktif, tek boss")
	GameManager.game_time = 1400.0
	sp._check_final_tier()
	assert(not sp._final_spawned and sp.get_endless_layer() == 0, "Kademe XV bitmeden Final yok")
	GameManager.game_time = 1501.0
	assert(sp._final_pending() or sp._final_gate_open(), "kapı açılır")
	sp._check_final_tier()
	assert(sp._final_spawned and sp._final_bosses.size() == 1, "Uçan Şeytan doğdu")
	var boss: Node = sp._final_bosses[0]
	assert(str(boss.get_meta("creature_id")) == "ucansetan1" and boss.is_boss, "Final bossu")
	assert(sp.get_endless_layer() == 0, "boss sağken sonsuz yok")
	sp._check_victory()
	assert(sp.get_run_phase() == sp.RunPhase.NORMAL, "boss sağken zafer yok")
	boss.is_dead = true
	sp._check_victory()
	assert(sp.get_run_phase() == sp.RunPhase.VICTORY, "boss ölünce zafer penceresi")
	assert(sp.begin_endless() and sp.get_run_phase() == sp.RunPhase.ENDLESS and sp.get_endless_layer() == 1, "Sonsuza Devam Et -> sonsuz mod Kat 1")
	## Kapatılınca eski davranış: Kademe XV bitince doğrudan sonsuz.
	var sp2: Node = _spawner()
	sp2.new_final_enabled = false
	_player(Vector2(1000, 1000))
	GameManager.game_time = 1501.0
	sp2._check_final_tier()
	assert(not sp2._final_active() and sp2.get_endless_layer() == 1 and not sp2._final_spawned, "new_final_enabled=false: doğrudan sonsuz")
	_cleanup()


func test_fireball_salvo_hits_for_200_and_the_player_burns_for_50_per_second() -> void:
	var sp: Node = _spawner()
	var player: FakePlayer = _player(Vector2(330, 0))
	var boss: Node = _boss(sp, Vector2(0, 0))
	await get_tree().process_frame
	var kit: RefCounted = boss._abilities._boss_kit
	assert(kit != null and kit.get_script() == KitScript and kit.blocks_melee(), "kit")
	kit._fire_cd = 0.0
	kit._beam_cd = 999.0
	kit._melee_cd = 999.0
	kit._t = 1.0
	for i in range(8):
		kit.process(0.1, null, INF)
	assert(kit._state == KitScript.S.FIRE or kit._fired > 0, "ateş topu salvosu başladı")
	for i in range(80):
		kit.process(0.02, null, INF)
	var balls: int = _fx("demon_fireball").size()
	assert(balls + 0 >= 1 and kit._fired == KitScript.FIRE_COUNT, "salvoda %d top atıldı (%d)" % [KitScript.FIRE_COUNT, kit._fired])
	## Toplar oyuncuya uçar, isabette 200 "demonfire"
	for i in range(60 * 3):
		for b: Node in _fx("demon_fireball"):
			if is_instance_valid(b) and not b.is_queued_for_deletion():
				b._physics_process(1.0 / 60.0)
	var hits200: int = 0
	for h: Array in player.hits:
		if h[1] == "demonfire" and h[0] == KitScript.FIREBALL_DAMAGE:
			hits200 += 1
	assert(hits200 >= 1, "ateş topu FIREBALL_DAMAGE (160) hasar: %s" % str(player.hits))
	## Yanma: gerçek oyuncuda "demonfire" isabeti 50/sn yakar
	var real: Node = PlayerScene.instantiate()
	_add(real)
	await get_tree().process_frame
	real.is_indoors = false
	real.max_health = 5000.0
	real.health = 5000.0
	real.take_special_damage(200.0, null, "demonfire")
	assert(real._enemy_burn_timer > 0.0 and is_equal_approx(real._enemy_burn_dps, 50.0), "yanma 50/sn (x0,8 iptal): %.1f" % real._enemy_burn_dps)
	_cleanup()


func test_cosmic_beam_rotates_a_full_turn_and_ticks_100_every_half_second() -> void:
	_spawner()
	var player: FakePlayer = _player(Vector2(300, 0))
	var far: FakePlayer = _player(Vector2(-300, 0))
	far.remove_from_group("player")
	far.add_to_group("remote_players")
	var src := Node2D.new()
	_add(src)
	var beam := Node2D.new()
	beam.set_script(load("res://scripts/cosmic_beam.gd"))
	beam.set("data", {"angle": 0.0, "sign": 1.0, "half_angle": 0.35, "length": 820.0, "warn": 1.2, "spin_time": 10.0, "tick": 0.5, "boss": 0})
	beam.set("authoritative", true)
	beam.set("damage", 100.0)
	beam.set("source", src)
	_add(beam)
	beam.global_position = Vector2.ZERO
	## Uyarı süresince hasar yok
	for i in range(int(1.1 * 60.0)):
		beam._physics_process(1.0 / 60.0)
	assert(player.hits.is_empty(), "uyarıda hasar yok")
	assert(is_equal_approx(beam.current_angle(), 0.0), "uyarıda yön sabit")
	## Işın başlayınca oyuncu dilimin içinde: ilk tikte vurur; dilim döndükçe dışarıda kalır
	for i in range(int(1.5 * 60.0)):
		beam._physics_process(1.0 / 60.0)
	assert(player.hits.size() >= 1 and player.hits[0][0] == 100.0 and player.hits[0][1] == "cosmic", "ışın tiki 100: %s" % str(player.hits))
	assert(player.hits.size() <= 3, "dilim döndü, oyuncu içinde kalmadı: %d" % player.hits.size())
	var before: int = player.hits.size()
	## Yarım tur sonra ışın ters tarafta: oyuncu(300,0) dışarıda, uzak oyuncu(-300,0) içinde
	for i in range(int(3.0 * 60.0)):
		beam._physics_process(1.0 / 60.0)
	assert(absf(absf(beam.current_angle()) - PI) < 1.0, "yarım tur civarı: %.2f" % beam.current_angle())
	assert(player.hits.size() == before or player.hits.size() <= before + 1, "oyuncu ışının önünden geçip gitti")
	assert(far.hits.size() >= 1 and far.hits[0][1] == "cosmic", "dilim uzak oyuncuya ulaştı: %s" % str(far.hits))
	assert(beam._in_beam(Vector2(-300, 0)) == (absf(angle_difference((Vector2(-300, 0)).angle(), beam.current_angle())) <= 0.35 + 0.09), "isabet kuralı tutarlı")
	_cleanup()


func test_flying_melee_hits_once_for_150_then_retreats() -> void:
	var sp: Node = _spawner()
	var player: FakePlayer = _player(Vector2(200, 0))
	var boss: Node = _boss(sp, Vector2(0, 0))
	await get_tree().process_frame
	var kit: RefCounted = boss._abilities._boss_kit
	kit._fire_cd = 999.0
	kit._beam_cd = 999.0
	kit._melee_cd = 0.0
	kit._t = 1.0
	var seen: Dictionary = {}
	for i in range(60 * 6):
		kit.process(1.0 / 60.0, null, INF)
		seen[kit._state] = true
	assert(seen.has(KitScript.S.DASH_IN) and seen.has(KitScript.S.STRIKE) and seen.has(KitScript.S.DASH_OUT), "uçarak saldırı döngüsü: %s" % str(seen.keys()))
	var slashes: int = 0
	for h: Array in player.hits:
		if h[1] == "demonslash" and h[0] == KitScript.MELEE_DAMAGE:
			slashes += 1
	assert(slashes == 1, "uçarak saldırı TEK vuruş MELEE_DAMAGE (120): %s" % str(player.hits))
	assert(boss.global_position.distance_to(player.global_position) > 150.0, "saldırıdan sonra geri çekildi: %.0f" % boss.global_position.distance_to(player.global_position))
	_cleanup()


func test_phase_two_below_half_health_turns_red_attacks_faster_and_heals_one_percent_per_second() -> void:
	var sp: Node = _spawner()
	var player: FakePlayer = _player(Vector2(330, 0))
	var boss: Node = _boss(sp, Vector2(0, 0))
	await get_tree().process_frame
	var kit: RefCounted = boss._abilities._boss_kit
	assert(not kit._phase2, "başta faz 1")
	kit.process(0.02, null, INF)
	assert(not kit._phase2, "can tam: faz 1")
	boss.health = boss.max_health * 0.49
	kit.process(0.02, null, INF)
	assert(kit._phase2, "%50 altı: faz 2")
	assert(boss.frame_sprite.self_modulate.g < 0.9 and boss.frame_sprite.self_modulate.b < 0.9, "gözler kırmızılaştı")
	assert(is_equal_approx(kit._cd_mult(), KitScript.CD_MULT_P2), "özellikler daha sık")
	## İyileşme büyüsü: saldırmaz, saniyede %1
	kit._heal_cd = 0.0
	kit._beam_cd = 999.0
	kit._melee_cd = 999.0
	kit._fire_cd = 0.0 ## hazır olsa bile iyileşme önceliği
	kit._go(KitScript.S.HOVER)
	kit._t = 1.0
	kit.process(0.02, null, INF)
	assert(kit._state == KitScript.S.HEAL, "iyileşme büyüsü başladı: %d" % kit._state)
	var hp0: float = boss.health
	for i in range(100):
		kit.process(0.02, null, INF)
	var gained: float = boss.health - hp0
	assert(absf(gained - boss.max_health * KitScript.HEAL_PER_SEC * 2.0) < boss.max_health * 0.002, "2 sn'de %%2 can: +%.0f" % gained)
	assert(_fx("demon_fireball").is_empty() and _fx("cosmic_beam").is_empty(), "iyileşirken saldırmaz")
	assert(player.hits.is_empty())
	_cleanup()
