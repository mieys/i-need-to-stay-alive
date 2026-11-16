extends Node

## TEST HARİTASI (madde 731, kullanıcı 2026-11-16): yalnız debug derlemesinde seçilen, hiçbir yaratığın kendiliğinden doğmadığı, debug menüsünden
## istenen yaratığın / bossun (Üç Kardeş = üçü birlikte) doğduğu harita. Profil + bayraklar, doğuş noktası (gerçek ana harita zemininde açık),
## doğurucu kapısı, debug doğuşu (boss kademesi, üçlü, temizleme, minyon), kayıt kapıları, debug aç/kapa, dünya haritası düğmesi, debug menüsü.

const MapProfiles: GDScript = preload("res://scripts/map_profiles.gd")
const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const Screen: GDScript = preload("res://scripts/world_map_screen.gd")
const DebugMenuScript: GDScript = preload("res://scripts/debug_menu.gd")
const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")
const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")
const TRIO := ["kardes_kilic1", "kardes_ok1", "kardes_buyu1"]

var _made: Array[Node] = [] ## (çalıştırıcı her dosyayı ayrı süreçte koşar; _begin/_end kancası yok - her test kendi durumunu geri koyar)


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var velocity: Vector2 = Vector2.ZERO


func _cleanup() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	NetworkManager.is_multiplayer_active = false
	GameManager.debug_mode_unlocked = false
	GameManager.test_map_forced_debug = false
	GameManager.debug_enemy_spawns_enabled = true
	GameManager.is_game_over = false
	GameManager.invasion_pending = false


func _add(n: Node) -> Node:
	add_child(n)
	_made.append(n)
	return n


func _env_map_set() -> bool:
	return OS.get_environment("HARITA") != "" ## geliştirme ortam değişkeni seçimi ezer


## Doğurucu: harita seçimi `_ready`'den ÖNCE yapılmalı (test haritası bayrağı orada okunur).
func _spawner(map_id: String) -> Node:
	_cleanup()
	GameManager.selected_map = map_id
	get_tree().current_scene = self
	var sp: Node = SpawnerScript.new()
	sp.name = "EnemySpawner"
	_add(sp)
	sp.max_concurrent_enemies = 100000
	return sp


func _player(pos: Vector2) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	_add(p)
	p.global_position = pos
	return p


func _living(group: String) -> Array:
	var out: Array = []
	for e: Node in get_tree().get_nodes_in_group(group):
		if is_instance_valid(e) and e.get("is_dead") != true:
			out.append(e)
	return out


func test_profile_is_hidden_main_ground_with_spawning_systems_off() -> void:
	if _env_map_set():
		return
	assert(MapProfiles.has_profile(MapProfiles.TEST_ID))
	assert(not MapProfiles.is_selectable(MapProfiles.TEST_ID), "seçilebilir değil: oylama / harita listesi görmez")
	assert(not MapProfiles.selectable_ids().has(MapProfiles.TEST_ID))
	assert(not Screen.map_ids().has(MapProfiles.TEST_ID), "dünya haritasında satırı yok (yalnız düğme)")
	assert(MapProfiles.is_test_map_id(MapProfiles.TEST_ID) and not MapProfiles.is_test_map_id("ana") and not MapProfiles.is_test_map_id("yok"))
	assert(MapProfiles.preview_id(MapProfiles.TEST_ID) == "ana" and MapProfiles.preview_id("col") == "col")
	GameManager.selected_map = MapProfiles.TEST_ID
	assert(MapProfiles.current_id() == MapProfiles.TEST_ID and MapProfiles.is_test_map() and not MapProfiles.is_main_map())
	## yaratık doğuran / ana haritaya özgü kapalı sistemler
	for f: String in ["ev_acilisi", "seyyar_satici", "gorevler", "kenar_bekcileri", "zindan_etkilesim", "bataklik_fx", "col_fx", "kis_fx"]:
		assert(not MapProfiles.feature(f), "test haritasında kapalı: " + f)
	## zemin + görünüm ana haritanınki ("taban"): tanımlı ve tanımsız bayraklar ana haritadaki gibi
	for f: String in ["orman_gorselleri", "hava", "madenler", "calilik", "su_efekti", "zemin_gecisi", "harita_ayiklama", "tanimsiz_bayrak"]:
		assert(MapProfiles.feature(f), "test haritasında ana haritadaki gibi açık: " + f)
	assert(not MapProfiles.swamp_hazards() and not MapProfiles.cold_climate() and not MapProfiles.sandstorm() and not MapProfiles.water_walkable())
	assert(MapProfiles.spawn_position() == MapProfiles.TEST_SPAWN)
	assert(MapProfiles.preload_paths().is_empty(), "ayrı sahne yok: main.tscn'in haritası")
	assert(SpawnerScript.boss_tiers_for_map(MapProfiles.TEST_ID).is_empty(), "kademe bossu yok")
	assert(not SpawnerScript.boss_tiers_for_map("ana").is_empty(), "ana haritanın bossları duruyor")
	## Main'deki harita aynı kalır; görev / ev / satıcı düğümleri çıkarılır
	var main := Node2D.new()
	for nm: String in ["Harita", "HouseInterior", "TravelingMerchant", "WorldEventManager", "EnemySpawner"]:
		var n := Node2D.new()
		n.name = nm
		main.add_child(n)
	var harita: Node = main.get_node("Harita")
	assert(not MapProfiles.install(main), "harita değişmez")
	assert(main.get_node("Harita") == harita)
	for nm: String in ["HouseInterior", "TravelingMerchant", "WorldEventManager"]:
		assert(main.get_node_or_null(nm) == null, "kaldırıldı: " + nm)
	assert(main.get_node_or_null("EnemySpawner") != null)
	main.free()
	GameManager.selected_map = "ana"
	assert(MapProfiles.feature("ev_acilisi") and MapProfiles.feature("gorevler"), "ana harita etkilenmez")


## Doğuş noktası GERÇEK ana harita zemininde açık (boss için yer var) + debug doğuş noktası engele düşmez.
func test_spawn_point_is_open_on_the_real_main_map() -> void:
	_cleanup()
	get_tree().current_scene = self
	var h: Node = HaritaScene.instantiate()
	h.name = "Harita"
	_add(h)
	GameManager.reset() ## arazi katmanı önbelleği bu haritadan kurulsun
	var c: Vector2 = MapProfiles.TEST_SPAWN
	assert(not GameManager.is_position_blocked_by_walls(c) and not GameManager.is_position_blocked_by_terrain(c), "doğuş açık")
	var total := 0
	var bad := 0
	var y := -400.0
	while y <= 400.0:
		var x := -400.0
		while x <= 400.0:
			if x * x + y * y <= 160000.0:
				total += 1
				var p := c + Vector2(x, y)
				if GameManager.is_position_blocked_by_walls(p) or GameManager.is_position_blocked_by_terrain(p):
					bad += 1
			x += 32.0
		y += 32.0
	assert(float(bad) / float(total) < 0.1, "400 px çevre büyük ölçüde açık: %d / %d engelli" % [bad, total])
	var sp: Node = SpawnerScript.new() ## ağaca eklenmeden: yalnız nokta seçimi
	for i in range(40):
		var boss: bool = i % 2 == 0
		var q: Vector2 = sp.debug_spawn_spot(c, boss)
		assert(not GameManager.is_position_blocked_by_walls(q) and not GameManager.is_position_blocked_by_terrain(q), "debug doğuşu engele düşmez: %s" % str(q))
		var d: float = q.distance_to(c)
		assert(d >= (160.0 if boss else 60.0) - 0.01 and d <= (260.0 if boss else 220.0) + 0.01, "mesafe: %.1f" % d)
	sp.free()
	h.free()
	_made.clear()
	GameManager.reset()


## Kendiliğinden doğuş YOK: normal akış, kademe bossu, "Yaratık spawnları" anahtarı. Aynı kurulum ana haritada doğurur (test boş geçmesin).
func test_spawner_never_spawns_on_its_own() -> void:
	if _env_map_set():
		return
	var control: Node = _spawner("ana")
	_player(Vector2(500, 500))
	assert(control.get("_test_map") == false)
	for i in range(20):
		control.set("_spawn_timer", 0.0)
		control._process(0.3)
	assert(not _living("enemies").is_empty(), "kontrol: ana haritada aynı kurulum yaratık doğurur")
	var sp: Node = _spawner(MapProfiles.TEST_ID)
	_player(Vector2(500, 500))
	assert(sp.get("_test_map") == true)
	GameManager.debug_enemy_spawns_enabled = true ## debug anahtarı açık olsa bile
	for t: float in [0.0, 480.0, 1490.0, 3000.0]:
		GameManager.game_time = t
		for i in range(10):
			sp.set("_spawn_timer", 0.0)
			sp._process(0.3)
		sp._check_boss_tiers()
	assert(_living("enemies").is_empty(), "test haritasında hiçbir yaratık / boss kendiliğinden doğmaz: %d" % _living("enemies").size())
	GameManager.game_time = 0.0


func test_debug_spawns_the_whole_trio_once_with_real_k10_stats() -> void:
	var sp: Node = _spawner(MapProfiles.TEST_ID)
	_player(Vector2(500, 500))
	## hangi kardeş istenirse istensin üçü birlikte; adet yok sayılır
	assert(sp.debug_spawn_creature("kardes_ok1", 10, 25, Vector2(500, 500)) == 3, sp.debug_last_error)
	var bosses: Array = _living("boss")
	assert(bosses.size() == 3, "tam üç kardeş: %d" % bosses.size())
	var ids: Array = bosses.map(func(b: Node) -> String: return str(b.get_meta("creature_id", "")))
	ids.sort()
	var want: Array = TRIO.duplicate()
	want.sort()
	assert(ids == want, "Kılıç + Ok + Büyü: %s" % str(ids))
	for b: Node in bosses:
		assert(b.get("is_boss") == true and float(b.max_health) == 140000.0 and float(b.item_shield_max) == 180000.0, "K10 kardeş statı")
		b.call("_init_abilities") ## oyunda ilk karede kurulur (enemy.gd); burada kare beklemeden
		assert(b.is_in_group("kardes_boss"), "kardeş kiti kuruldu (öfke / imza devri)")
		assert((b as Node2D).global_position.distance_to(Vector2(500, 500)) >= 159.0, "oyuncunun dibinde değil")
	## üç ayrı yönden
	var a0: float = ((bosses[0] as Node2D).global_position - Vector2(500, 500)).angle()
	for k in range(1, 3):
		var ak: float = ((bosses[k] as Node2D).global_position - Vector2(500, 500)).angle()
		assert(absf(angle_difference(a0, ak)) > 0.8, "kardeşler ayrı yönlerden")
	## sahada kardeş varken ikinci üçlü doğmaz
	assert(sp.debug_spawn_creature("kardes_kilic1", 10, 1, Vector2(500, 500)) == 0 and str(sp.debug_last_error) != "")
	assert(_living("boss").size() == 3)
	## sahayı temizle: hepsi ödülsüz gider, sonra yeni üçlü doğar
	assert(sp.debug_clear_creatures() == 3)
	assert(_living("enemies").is_empty(), "temizlik herkesi kaldırdı")
	assert(sp.debug_spawn_creature("kardes_buyu1", 10, 1, Vector2(500, 500)) == 3)
	_cleanup()


func test_debug_boss_tier_is_the_in_game_tier_and_bosses_are_real() -> void:
	var want := {"minotaur1": 5, "kardes_kilic1": 10, "kardes_ok1": 10, "kardes_buyu1": 10, "gonca1": 5, "banshee1": 10, "underground1": 5,
			"medusa1": 10, "balkabagi1": 5, "ucansetan1": 10, "wendigo1": 10}
	for id: String in want:
		assert(SpawnerScript.debug_boss_ids().has(id), "boss listesinde: " + id)
		assert(SpawnerScript.debug_boss_tier(id) == int(want[id]), "%s oyundaki kademe %d (bulunan %d)" % [id, want[id], SpawnerScript.debug_boss_tier(id)])
	assert(SpawnerScript.debug_boss_ids().size() == want.size(), "yeni boss eklendiyse bu tabloya da ekle: %s" % str(SpawnerScript.debug_boss_ids()))
	var sp: Node = _spawner(MapProfiles.TEST_ID)
	_player(Vector2(500, 500))
	assert(sp.debug_spawn_creature("minotaur1", 5, 1, Vector2(500, 500)) == 1)
	var b: Node = _living("boss")[0]
	assert(b.get("is_boss") == true and float(b.max_health) == 50000.0 and float(b.item_shield_max) == 60000.0, "K5 yuva statı: %s / %s" % [b.max_health, b.item_shield_max])
	assert(str(b.get_meta("boss_id", "")) == "minotaur1", "boss müziği kimliği")
	_cleanup()


func test_debug_summon_gets_minion_setup() -> void:
	var sp: Node = _spawner(MapProfiles.TEST_ID)
	_player(Vector2(500, 500))
	assert(sp.debug_spawn_creature("kabak1", 3, 2, Vector2(500, 500)) == 2)
	for e: Node in _living("enemies"):
		assert(e.is_in_group("summons") and not e.has_meta("spawn_tier"), "minyon kurulumu (spawn_summon ile aynı)")
	_cleanup()


func test_progress_is_never_written_on_the_test_map() -> void:
	if _env_map_set():
		return
	GameManager.selected_map = MapProfiles.TEST_ID
	var m: Node = (load("res://scripts/main.gd") as GDScript).new()
	assert(str(m._record_skip_reason()).contains("test haritası"), "rekor / kıymık / başarım yok")
	m.free()
	assert(BalanceLogScript.disabled_reason().contains("test haritası"), "balans kaydı yok")
	GameManager.selected_map = "ana"
	assert(not BalanceLogScript.disabled_reason().contains("test haritası"))


func test_test_map_turns_debug_on_and_leaving_turns_it_back_off() -> void:
	_cleanup()
	GameManager.selected_map = MapProfiles.TEST_ID
	GameManager.enter_test_map()
	assert(GameManager.run_debug_used, "anahtar / ilerleme yok")
	if GameManager.debug_allowed():
		assert(GameManager.debug_mode_unlocked and GameManager.test_map_forced_debug, "editörde DEBUG baştan açık")
	GameManager.debug_immortal = true
	GameManager.reset() ## yeni koşu: haritanın açtığı debug kapanır
	assert(not GameManager.debug_mode_unlocked and not GameManager.test_map_forced_debug and not GameManager.debug_immortal)
	assert(not GameManager.run_debug_used)
	## kullanıcının kendi açtığı debug'a dokunulmaz
	if GameManager.debug_allowed():
		GameManager.debug_mode_unlocked = true
		GameManager.enter_test_map()
		assert(not GameManager.test_map_forced_debug)
		GameManager.leave_test_map()
		assert(GameManager.debug_mode_unlocked, "chat koduyla açılan debug kalır")
	_cleanup()
	GameManager.selected_map = "ana"


func test_world_map_button_only_in_debug_build_and_for_host() -> void:
	NetworkManager.is_host = false
	var s: Control = Screen.new()
	s.initial_map = "ana"
	add_child(s)
	await get_tree().process_frame
	var tb: Button = s.find_child("TestMap", true, false)
	assert((tb != null) == MapProfiles.test_map_allowed(), "düğme yalnız debug açılabilen derlemede")
	assert(s.find_child("Row_" + MapProfiles.TEST_ID, true, false) == null, "liste satırı yok")
	var chosen: Array = []
	s.connect("chosen", func(id: String) -> void: chosen.append(id))
	if tb != null:
		tb.pressed.emit()
		assert(chosen == [MapProfiles.TEST_ID], "tek tık test haritasını seçer: %s" % str(chosen))
	s.queue_free()
	await get_tree().process_frame
	## oylama: istemcide yok, host'ta var (oylamayı atlar)
	for host: bool in [false, true]:
		NetworkManager.is_host = host
		var v: Control = Screen.new()
		v.voting = true
		v.can_cancel = host
		v.initial_map = "ana"
		add_child(v)
		await get_tree().process_frame
		var vb: Button = v.find_child("TestMap", true, false)
		assert((vb != null) == (host and MapProfiles.test_map_allowed()), "oylamada yalnız host: host=%s" % str(host))
		var got: Array = []
		v.connect("chosen", func(id: String) -> void: got.append(id))
		if vb != null:
			vb.pressed.emit()
			assert(got == [MapProfiles.TEST_ID])
		v.queue_free()
		await get_tree().process_frame
	NetworkManager.is_host = false


## Debug menüsü: bosslar ayrı bölümde, Üç Kardeş TEK düğme, boss seçilince kademe oyundakine geçer, SPAWNLA üçünü doğurur, test haritasında
## "Yaratık spawnları" anahtarı kapalı ve basılamaz.
func test_debug_menu_boss_section_trio_button_and_spawn_toggle() -> void:
	var sp: Node = _spawner(MapProfiles.TEST_ID)
	var menu: Control = DebugMenuScript.new()
	_add(menu)
	var buttons: Dictionary = menu.get("_creature_buttons")
	assert(buttons.has("kardes_kilic1") and not buttons.has("kardes_ok1") and not buttons.has("kardes_buyu1"), "Üç Kardeş tek düğme")
	assert(buttons.has("minotaur1") and buttons.has("goblin1"))
	menu.call("_select_creature", "minotaur1")
	assert(int(menu.get("_tier")) == 5, "Minotaur seçilince Kademe 5")
	menu.call("_select_creature", "kardes_kilic1")
	assert(int(menu.get("_tier")) == 10, "Üç Kardeş seçilince Kademe 10")
	var spawns_btn: Button = menu.get("_spawns_btn")
	assert(spawns_btn != null and spawns_btn.disabled and spawns_btn.text.contains("test haritası"), "anahtar test haritasında kapalı")
	_player(Vector2(500, 500))
	menu.call("_on_spawn_pressed")
	assert(_living("boss").size() == 3, "SPAWNLA üç kardeşi doğurur")
	menu.call("_on_clear_pressed")
	assert(_living("enemies").is_empty())
	_cleanup()
