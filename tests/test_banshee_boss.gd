extends Node

## Banshee (Kademe 15 bossu, 2026-10-09): masaüstü `banshee` paketi + "boss ve yetenekleri.txt" (can 300.000, kalkan 480.000, 3x boy, zifiri gecede doğar ve var olduğu sürece gündüz olmaz, içinden geçerek
## atılma, durup uyarılı çığlık şeritleri, duvar arkasından geçemez). Kapsam: sayfa/sahne/tablo sözleşmesi, statlar+boyut, gece kilidi (matematik + atmosphere.gd + doğuş kapısı), atılış durum makinesi
## (uykuya alma, içinden geçiş, atılış başına tek isabet, atılıştan sonra yavaşlama), çığlık şeritleri (3 şerit/oyuncu, duvara kısalma, tek isabet 130), oyuncuların içinden geçebilme bayrağı.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const AbilitiesScript: GDScript = preload("res://scripts/enemy_abilities.gd")
const KitScript: GDScript = preload("res://scripts/banshee_boss.gd")
const BossBarArtScript: GDScript = preload("res://scripts/boss_bar_art.gd")
const AtmosphereMath: GDScript = preload("res://scripts/atmosphere_math.gd")
const AtmosphereScript: GDScript = preload("res://scripts/atmosphere.gd")
const EnemyWorldBridgeScript: GDScript = preload("res://scripts/enemy_world/enemy_world_bridge.gd")

var _made: Array[Node] = []


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var is_indoors: bool = false
	var hits: Array = []

	func take_special_damage(amount: float, _source: Node2D, kind: String) -> void:
		hits.append([amount, kind])


class StubAtmosphere extends Node:
	var locked: bool = false
	var deep: bool = false

	func set_night_lock(on: bool) -> bool:
		locked = on
		return true

	func is_deep_night() -> bool:
		return deep


func _cleanup() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for c: Node in get_children():
		if is_instance_valid(c) and c.get_script() != null and str(c.get_script().resource_path).contains("banshee_wave"):
			c.free()
	GameManager.bosses_enabled = false
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
	var b: Node = sp._spawn_creature("banshee1", pos, 999001)
	b.add_to_group("boss")
	sp._setup_boss_enemy(b, "banshee1", 15, 1)
	b._init_abilities()
	return b


func _world() -> Object:
	return EnemyWorldBridgeScript.fog_world(get_tree())


func test_sheets_scene_tables_stats_and_size() -> void:
	var sheets: Dictionary = {"walk": 4, "idle": 4, "attack": 6, "scream": 7, "appear": 5, "death": 5, "hurt": 2}
	for k: String in sheets.keys():
		var tex: Texture2D = load("res://assets/enemies/banshee/banshee_%s.png" % k) as Texture2D
		assert(tex != null and tex.get_height() == 320 and tex.get_width() == 80 * int(sheets[k]), "sayfa %s" % k)
	assert(SpawnerScript.SCENES.has("banshee1") and SpawnerScript.ID_FAMILY["banshee1"] == "banshee" and AbilitiesScript.family_has_ability("banshee"), "tablolar")
	assert(SpawnerScript.NEW_BOSS_TIERS.get(15) == ["banshee1"] and SpawnerScript.NIGHT_BOSS_TIERS == [15], "Kademe 15 gece bossu")
	assert(BossBarArtScript.display_name("banshee1") == "BANSHEE", "boss barı adı")
	var sp: Node = _spawner()
	var b: Node = _boss(sp, Vector2(500, 500))
	assert(b.max_health == 300000.0 and b.item_shield_max == 480000.0, "can/kalkan: %.0f / %.0f" % [b.max_health, b.item_shield_max])
	assert(absf(b.frame_sprite.scale.x - 1.6 * EntityScale.SIZE * EntityScale.BOSS_EXTRA * 1.47) < 0.001, "1,47x boyut (3x -> 2,1x 2026-10-10 -> 1,47x 2026-10-19, ikisi de %30 küçültme)")
	assert(b.special_textures.has("dash") and b.special_textures.has("scream") and b.special_textures.has("appear"), "özel dokular")
	_cleanup()


func test_night_lock_math_flows_to_midnight_and_holds_from_day_and_dawn() -> void:
	for start: float in [100.0, 300.0, 550.0, 590.0, 10.0]:
		var t: float = start
		for i in range(2000):
			t = AtmosphereMath.night_lock_step(t, 0.05)
		assert(absf(t - AtmosphereMath.NIGHT_LOCK_TIME) < 0.01, "başlangıç %.0f -> gece yarısında durur: %.2f" % [start, t])
	assert(AtmosphereMath.is_deep_night(465.0) and not AtmosphereMath.is_deep_night(200.0) and not AtmosphereMath.is_deep_night(560.0), "derin gece aralığı")
	var t2: float = 100.0
	var secs: float = 0.0
	while t2 < AtmosphereMath.NIGHT_DEEP_MIN:
		t2 = AtmosphereMath.night_lock_step(t2, 0.1)
		secs += 0.1
	assert(secs < 8.0, "gündüzden derin geceye ~7 sn: %.1f" % secs)


func test_atmosphere_lock_releases_itself_when_no_boss_remains() -> void:
	var atmo := Node2D.new()
	atmo.set_script(AtmosphereScript)
	_add(atmo)
	atmo.cycle_time = 100.0
	assert(atmo.set_night_lock(true), "tekli oyunda yetkili")
	var boss := Node2D.new()
	boss.add_to_group("night_lock_boss")
	_add(boss)
	for i in range(200):
		atmo._process(0.1)
	assert(atmo.is_deep_night() and atmo.night_lock, "kilit açık: derin gece, boss var")
	assert(absf(atmo.cycle_time - AtmosphereMath.NIGHT_LOCK_TIME) < 0.5, "gece yarısında sabit: %.2f" % atmo.cycle_time)
	boss.remove_from_group("night_lock_boss")
	for i in range(30):
		atmo._process(0.1)
	assert(not atmo.night_lock, "boss kalmayınca kilit kendiliğinden açıldı")
	var t0: float = atmo.cycle_time
	atmo._process(1.0)
	assert(atmo.cycle_time > t0, "saat yeniden akıyor")
	_cleanup()


func test_boss_spawn_waits_for_deep_night_and_requests_the_lock() -> void:
	var sp: Node = _spawner()
	var stub := StubAtmosphere.new()
	stub.add_to_group("atmosphere")
	_add(stub)
	assert(not sp._night_ready_for_boss() and stub.locked, "gündüz: kilit istendi, derin gece yok -> bekle")
	stub.deep = true
	assert(sp._night_ready_for_boss(), "derin gece olunca hazır")
	stub.remove_from_group("atmosphere")
	assert(sp._night_ready_for_boss(), "atmosfer yoksa (test/menü) engel yok")
	_cleanup()


func test_dash_flies_through_the_player_hits_once_and_slows_down() -> void:
	var sp: Node = _spawner()
	var stub := StubAtmosphere.new()
	stub.add_to_group("atmosphere")
	_add(stub)
	var player: FakePlayer = _player(Vector2(300, 0))
	var boss: Node = _boss(sp, Vector2(0, 0))
	await get_tree().process_frame
	var kit: RefCounted = boss._abilities._boss_kit
	assert(kit != null and kit.get_script() == KitScript, "banshee kiti")
	assert(stub.locked and boss.is_in_group("night_lock_boss") and boss.no_body_block, "gece kilidi istendi, gece-boss grubunda, içinden geçilir")
	assert(kit.blocks_melee() and boss._abilities.melee_blocked(), "temas saldırısı bastırılır")
	kit._state = KitScript.S.APPROACH
	var min_x: float = 0.0
	var max_x: float = 0.0
	var passed: bool = false
	for i in range(60 * 8):
		kit.process(1.0 / 60.0, null, INF)
		max_x = maxf(max_x, boss.global_position.x)
		if boss.global_position.x > player.global_position.x + 40.0:
			passed = true
		if passed and kit._state == KitScript.S.PAUSE:
			break
	assert(_world() != null and _world().is_dormant(int(boss._ew_slot)), "C++'ta uykuda (oyuncuya takılmaz)")
	assert(passed, "boss oyuncunun İÇİNDEN geçip öbür tarafa çıktı: max x %.0f" % max_x)
	var banshee_hits: int = 0
	for h: Array in player.hits:
		if h[1] == "banshee" and is_equal_approx(h[0], 336.0 * SpawnerScript.CREATURE_DAMAGE_CUT):
			banshee_hits += 1
	assert(banshee_hits == 1, "atılış başına TEK isabet 240 x0,8 = 192 (2026-10-11): %s" % str(player.hits))
	assert(kit._dash_count == 1 and kit._v.length() < 30.0, "atılıştan sonra yavaşladı")
	_cleanup()


func test_scream_lanes_warn_then_hit_once_and_are_clipped_by_walls() -> void:
	var sp: Node = _spawner()
	var player: FakePlayer = _player(Vector2(380, 0))
	var other: FakePlayer = _player(Vector2(380, 520)) ## birinci oyuncunun 5 şeridinin (+-36 derece) dışında
	other.remove_from_group("player")
	other.add_to_group("remote_players")
	var boss: Node = _boss(sp, Vector2(0, 0))
	await get_tree().process_frame
	var kit: RefCounted = boss._abilities._boss_kit
	kit._state = KitScript.S.SCREAM
	kit._t = 0.0
	kit.process(1.0 / 60.0, null, INF)
	var lanes: Array = []
	for c: Node in get_children():
		if c.get_script() != null and str(c.get_script().resource_path).contains("banshee_wave"):
			lanes.append(c)
	assert(lanes.size() == 2 * KitScript.LANE_COUNT and KitScript.LANE_COUNT == 5, "iki oyuncu x 5 şerit: %d" % lanes.size())
	assert(boss._special_tex != null, "scream animasyonu")
	for l: Node in lanes:
		assert(float(l.data["length"]) <= KitScript.LANE_LENGTH + 0.01 and float(l.data["warn"]) == KitScript.LANE_WARN, "şerit uzunluğu/uyarısı")
	## Uyarı süresince hasar yok; sonra merkez şerit oyuncuya TEK kez 130
	for i in range(int(KitScript.LANE_WARN * 60.0) - 5):
		for l: Node in lanes:
			l._physics_process(1.0 / 60.0)
	assert(player.hits.is_empty() and other.hits.is_empty(), "uyarı sırasında hasar yok")
	for i in range(int((KitScript.LANE_FIRE + 0.2) * 60.0) + 10):
		for l: Node in lanes:
			if is_instance_valid(l) and not l.is_queued_for_deletion():
				l._physics_process(1.0 / 60.0)
	var scream_hits: int = 0
	for h: Array in player.hits:
		if h[1] == "scream" and h[0] == KitScript.SCREAM_DAMAGE:
			scream_hits += 1
	assert(scream_hits == 1, "oyuncu çığlıktan TEK kez SCREAM_DAMAGE (260) aldı: %s" % str(player.hits))
	assert(other.hits.size() == 1 and other.hits[0][1] == "scream", "ikinci oyuncunun kendi şeridi ona vurdu: %s" % str(other.hits))
	_cleanup()


func test_wave_lane_geometry_is_a_thick_straight_strip() -> void:
	_spawner()
	var wave := Node2D.new()
	wave.set_script(load("res://scripts/banshee_wave.gd"))
	wave.set("data", {"dir": Vector2.RIGHT, "length": 400.0, "width": 44.0, "warn": 1.0, "fire": 0.4})
	wave.set("authoritative", true)
	wave.position = Vector2(100, 100)
	_add(wave)
	assert(wave._in_lane(Vector2(300, 100)) and wave._in_lane(Vector2(300, 115)), "şerit içi")
	assert(not wave._in_lane(Vector2(300, 160)) and not wave._in_lane(Vector2(560, 100)) and not wave._in_lane(Vector2(40, 100)), "şerit dışı (yan, ileri, geri)")
	_cleanup()


## 2026-10-10 (kullanıcı: "banshee çok güçsüzdü, boyutunu %30 küçültüp daha agresif daha hızlı olmalı, hasarını 2 kat arttır").
func test_hits_are_doubled_and_the_boss_is_far_more_aggressive_than_before() -> void:
	assert(float(SpawnerScript.FIXED_BOSS_STATS["banshee1"]["damage"]) == 336.0 and KitScript.SCREAM_DAMAGE == 364.0, "atılış 336, çığlık 364 (x0,8 iptal 2026-10-11)")
	assert(is_equal_approx(float(SpawnerScript.FIXED_BOSS_STATS["banshee1"]["scale"]), 3.0 * KitScript.BODY_SCALE_REL), "boyut x0,7: tablo ve kit aynı oran")
	## eskiden: yaklaşma 190, atılış 580, nişan 0,55, bekleme 0,3, çığlık her 3 atılışta
	assert(KitScript.APPROACH_SPEED >= 300.0 and KitScript.DASH_MAX_SPEED >= 800.0 and KitScript.WINDUP_TIME <= 0.35 and KitScript.PAUSE_TIME <= 0.15, "daha hızlı")
	assert(KitScript.SCREAM_EVERY <= 2 and KitScript.LANE_WARN <= 0.85, "daha sık çığlık, daha kısa uyarı")
	var sp: Node = _spawner()
	var player: FakePlayer = _player(Vector2(400, 0))
	var boss: Node = _boss(sp, Vector2(0, 0))
	await get_tree().process_frame
	var kit: RefCounted = boss._abilities._boss_kit
	kit._state = KitScript.S.APPROACH
	kit._t = 0.0
	## 8 sn'de kaç atılış? (eski değerlerle ~2: ölçüm 3 sn/atılış + çığlık; yenilerle ~4)
	for i in range(60 * 8):
		kit.process(1.0 / 60.0, null, INF)
	assert(kit._dash_count >= 3, "8 sn'de en az 3 atılış (çığlık fazı dahil): %d" % kit._dash_count)
	_cleanup()
