extends Node

## Kullanıcı isteği (2026-10-05): Final'in 13 bossunu yenince ZAFER, ardından "Sonsuza Devam Et" ile SONSUZ MOD (kat kat güçlenen
## yaratıklar + her 3 katta boss dalgası). Host/tek oyunculu mantığı enemy_spawner.gd "ZAFER + SONSUZ MOD" bloğunda.

const SpawnerScript: GDScript = preload("res://scripts/enemy_spawner.gd")
const TIER_SECONDS := 100.0
const FINAL_TIME := TIER_SECONDS * 15.0 + 1.0
const RUN_START := 1700.0 ## sonsuz modun başladığı oyun saati (testlerde)


class FakePlayer extends Node2D:
	var is_dead: bool = false
	var velocity: Vector2 = Vector2.ZERO


## Final bossu taklidi (sadece is_dead okunuyor).
class FakeBoss extends Node:
	var is_dead: bool = false


var _made: Array[Node] = []
var _victory_heard: int = 0
var _endless_heard: int = 0
var _layers_heard: Array = []
var _died_heard: int = 0


func _on_victory(_t: float) -> void:
	_victory_heard += 1


func _on_endless_started() -> void:
	_endless_heard += 1


func _on_layer(layer: int) -> void:
	_layers_heard.append(layer)


func _on_enemy_died(_pos: Vector2) -> void:
	_died_heard += 1


func _cleanup() -> void:
	for sig_pair in [[NetworkManager.victory_reached, _on_victory], [NetworkManager.endless_started, _on_endless_started],
			[NetworkManager.endless_layer_reached, _on_layer], [GameManager.enemy_died, _on_enemy_died]]:
		if (sig_pair[0] as Signal).is_connected(sig_pair[1]):
			(sig_pair[0] as Signal).disconnect(sig_pair[1])
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.free()
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	GameManager.bosses_enabled = false
	GameManager.game_time = 0.0
	GameManager.victory_reached = false
	GameManager.endless_active = false
	GameManager.endless_layer = 0
	GameManager.run_kills = 0
	GameManager.run_max_tier = 1
	NetworkManager.is_multiplayer_active = false


## 2026-10-08: boss sistemi varsayılan KAPALI (GameManager.bosses_enabled, bkz. CLAUDE.md madde 39) - bu dosya boss/Final akışını sınar, bu yüzden geçici açar
func _spawner() -> Node:
	_cleanup()
	GameManager.bosses_enabled = true
	_victory_heard = 0
	_endless_heard = 0
	_layers_heard.clear()
	_died_heard = 0
	NetworkManager.victory_reached.connect(_on_victory)
	NetworkManager.endless_started.connect(_on_endless_started)
	NetworkManager.endless_layer_reached.connect(_on_layer)
	GameManager.enemy_died.connect(_on_enemy_died)
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	sp.max_concurrent_enemies = 100000 ## kapasite testlerin konusu değil
	get_tree().current_scene = self ## _spawn_creature current_scene'e ekliyor
	_made.append(sp)
	return sp


func _player(pos: Vector2 = Vector2.ZERO) -> FakePlayer:
	var p := FakePlayer.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = pos
	_made.append(p)
	return p


func _boss(dead: bool = false) -> FakeBoss:
	var b := FakeBoss.new()
	b.is_dead = dead
	add_child(b)
	_made.append(b)
	return b


## Zafer evresine geçir (sahte, ölü bir Final bossu ile).
func _force_victory(sp: Node) -> void:
	sp._final_spawned = true
	sp._final_bosses = [_boss(true)]
	sp._check_victory()


func _start_endless(sp: Node) -> void:
	GameManager.game_time = RUN_START
	_force_victory(sp)
	assert(sp.begin_endless(), "zafer sonrası sonsuz mod başlamalı")


func _real_bosses() -> Array[Node]:
	var out: Array[Node] = []
	for e: Node in get_tree().get_nodes_in_group("boss"):
		if is_instance_valid(e) and e.get("is_boss") == true:
			out.append(e)
	return out


func test_no_victory_until_every_final_boss_is_dead() -> void:
	var sp: Node = _spawner()
	var a := _boss()
	var b := _boss()
	sp._final_spawned = true
	sp._final_bosses = [a, b]
	sp._check_victory()
	assert(sp.get_run_phase() == SpawnerScript.RunPhase.NORMAL and _victory_heard == 0, "iki boss da sağken zafer yok")
	a.is_dead = true
	sp._check_victory()
	assert(sp.get_run_phase() == SpawnerScript.RunPhase.NORMAL and _victory_heard == 0, "biri sağken zafer yok")
	b.is_dead = true
	sp._check_victory()
	assert(sp.get_run_phase() == SpawnerScript.RunPhase.VICTORY, "ikisi de ölünce zafer")
	assert(_victory_heard == 1 and GameManager.victory_reached, "herkese TEK zafer bildirimi + GameManager bayrağı")
	sp._check_victory()
	assert(_victory_heard == 1, "zafer ikinci kez yayınlanmamalı")
	_cleanup()


func test_a_freed_final_boss_counts_as_dead() -> void:
	var sp: Node = _spawner()
	var a := _boss()
	var b := _boss(true)
	sp._final_spawned = true
	sp._final_bosses = [a, b]
	a.free() ## ölüm animasyonu bitip queue_free olmuş boss
	sp._check_victory()
	assert(sp.get_run_phase() == SpawnerScript.RunPhase.VICTORY, "silinmiş boss ölü sayılmalı (kilitlenme olmasın)")
	_cleanup()


func test_no_victory_when_final_never_spawned() -> void:
	var sp: Node = _spawner()
	sp._final_spawned = true
	sp._final_bosses = []
	sp._check_victory()
	assert(sp.get_run_phase() == SpawnerScript.RunPhase.NORMAL, "Final doğmadıysa (boş liste) boş-doğruluk zaferi OLMAMALI")
	sp._final_spawned = false
	sp._final_bosses = [_boss(true)]
	sp._check_victory()
	assert(sp.get_run_phase() == SpawnerScript.RunPhase.NORMAL, "Final tetiklenmediyse zafer yok")
	_cleanup()


func test_final_is_retried_when_nothing_could_spawn() -> void:
	var sp: Node = _spawner() ## canlı oyuncu yok -> boss doğamaz
	GameManager.game_time = FINAL_TIME
	sp._check_final_tier()
	assert(not sp._final_spawned, "hiç boss doğmadıysa Final 'doğdu' sayılmamalı (yoksa zafer hiç gelmez)")
	assert(sp._final_bosses.is_empty())
	_cleanup()


func test_final_spawn_registers_all_thirteen_and_victory_follows_their_death() -> void:
	var sp: Node = _spawner()
	_player()
	GameManager.game_time = FINAL_TIME
	sp._check_final_tier()
	assert(sp._final_spawned, "Final doğmalı")
	assert(sp._final_bosses.size() == SpawnerScript.FINAL_CREATURES.size(), "13 bossun hepsi kayıtlı: %d" % sp._final_bosses.size())
	for boss in sp._final_bosses:
		assert(boss.is_in_group("boss"), "Final bosslar 'boss' grubunda")
	sp._check_victory()
	assert(sp.get_run_phase() == SpawnerScript.RunPhase.NORMAL, "bosslar sağken zafer yok")
	for boss in sp._final_bosses:
		boss.set("is_dead", true)
	sp._check_victory()
	assert(sp.get_run_phase() == SpawnerScript.RunPhase.VICTORY, "13'ü de ölünce zafer")
	_cleanup()


func test_victory_dissolves_living_creatures_without_rewards_or_kills() -> void:
	var sp: Node = _spawner()
	_player()
	var rat: Node = sp._spawn_creature("rat1", Vector2(300, 0), 1)
	assert(rat != null and rat.get("is_dead") != true)
	sp._rpc_victory_dissolve()
	assert(rat.get("is_dead") == true, "kalan yaratık dağılmalı")
	assert(_died_heard == 0, "dağılma 'öldürme' sayılmamalı (görev sayacı enemy_died dinler)")
	assert(GameManager.run_kills == 0, "dağılma koşu öldürme sayacını artırmamalı")
	await get_tree().create_timer(2.5).timeout ## ölüm animasyonu + solma
	assert(not is_instance_valid(rat), "yaratık solup silinmeli")
	_cleanup()


func test_spawns_pause_during_victory() -> void:
	var sp: Node = _spawner()
	_player()
	GameManager.game_time = RUN_START
	_force_victory(sp)
	assert(sp.spawn_mission_wave(Vector2.ZERO, 300.0, 5) == 0, "zafer penceresi açıkken görev dalgası doğmamalı")
	var before: int = get_tree().get_nodes_in_group("enemies").size()
	sp._process(0.016) ## spawn kapısı: zafer evresinde hiçbir şey doğmamalı
	assert(get_tree().get_nodes_in_group("enemies").size() == before, "zafer evresinde normal doğuş durmalı")
	_cleanup()


func test_begin_endless_only_after_victory_and_only_once() -> void:
	var sp: Node = _spawner()
	assert(not sp.begin_endless(), "zafer olmadan sonsuz mod başlamamalı")
	_force_victory(sp)
	assert(sp.begin_endless(), "zaferden sonra başlamalı")
	assert(sp.get_run_phase() == SpawnerScript.RunPhase.ENDLESS and sp.get_endless_layer() == 1, "Kat 1'de ENDLESS")
	assert(GameManager.endless_active and GameManager.endless_layer == 1, "herkeste bayrak + kat")
	assert(_endless_heard == 1, "herkese TEK 'sonsuz başladı' bildirimi")
	assert(not sp.begin_endless(), "ikinci kez başlatılamaz")
	assert(_endless_heard == 1)
	_cleanup()


func test_layers_advance_with_game_time_and_are_announced() -> void:
	var sp: Node = _spawner()
	_start_endless(sp)
	sp._process_endless()
	GameManager.game_time = RUN_START + 99.0
	sp._process_endless()
	assert(sp.get_endless_layer() == 1 and _layers_heard.is_empty(), "Kat 1 bitmeden yeni kat yok")
	GameManager.game_time = RUN_START + 100.0
	sp._process_endless()
	assert(sp.get_endless_layer() == 2 and _layers_heard == [2] and GameManager.endless_layer == 2, "100 sn sonra Kat 2")
	sp._process_endless()
	assert(_layers_heard == [2], "aynı kat tekrar duyurulmamalı")
	GameManager.game_time = RUN_START + 405.0
	sp._process_endless()
	assert(sp.get_endless_layer() == 5 and _layers_heard == [2, 5], "Kat 5'e atlandı: %s" % str(_layers_heard))
	_cleanup()


func test_scale_tier_follows_the_layer_while_roster_tier_is_untouched() -> void:
	var sp: Node = _spawner()
	assert(sp._scale_tier_for(7) == 7, "normalde ölçek = roster kademesi")
	_start_endless(sp)
	assert(sp._scale_tier_for(15) == 16, "Kat 1: Final'in ölçeği (16)")
	sp._endless_layer = 4
	assert(sp._scale_tier_for(15) == 19, "Kat 4: 19")
	_cleanup()


func test_regular_spawns_in_endless_use_the_scaled_tier_but_the_tier_15_roster() -> void:
	var sp: Node = _spawner()
	_player()
	_start_endless(sp)
	GameManager.game_time = RUN_START + 250.0
	sp._process_endless()
	assert(sp.get_endless_layer() == 3)
	sp._spawn_regular_enemy()
	var spawned: Array[Node] = []
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.get("is_boss") != true:
			spawned.append(e)
	assert(spawned.size() >= 1, "sonsuzda normal yaratık doğmalı")
	for e in spawned:
		assert(int(e.get("_current_tier")) == 18, "Kat 3 yaratığının ölçek kademesi 18 olmalı: %d" % int(e.get("_current_tier")))
		assert(int(e.get_meta("spawn_tier", 0)) == 15, "roster kademesi (meta) 15'te kalmalı")
		assert(SpawnerScript.TIER_ROSTER[15].has(str(e.get_meta("creature_id", ""))), "roster 15'ten: %s" % str(e.get_meta("creature_id", "")))
	_cleanup()


func test_endless_boss_wave_spawns_once_at_the_right_time_with_scaled_stats() -> void:
	var sp: Node = _spawner()
	_player()
	_start_endless(sp)
	GameManager.game_time = RUN_START + 150.0 ## Kat 2: boss katı değil
	sp._process_endless()
	sp._check_endless_boss_wave()
	assert(_real_bosses().is_empty(), "Kat 2'de boss dalgası yok")
	GameManager.game_time = RUN_START + 260.0 ## Kat 3 ama katın %75'i (275) henüz gelmedi
	sp._process_endless()
	sp._check_endless_boss_wave()
	assert(_real_bosses().is_empty(), "Kat 3'te dalga 275. saniyeden önce gelmemeli")
	GameManager.game_time = RUN_START + 280.0
	sp._process_endless()
	sp._check_endless_boss_wave()
	var wave: Array[Node] = _real_bosses()
	assert(wave.size() == 3, "ilk dalga 3 boss: %d" % wave.size())
	for b in wave:
		assert(int(b.get("_current_tier")) == 18, "boss ölçeği Kat 3 = 18: %d" % int(b.get("_current_tier")))
		assert(SpawnerScript.FINAL_CREATURES.has(str(b.get_meta("creature_id", ""))), "boss Final havuzundan")
	sp._check_endless_boss_wave()
	assert(_real_bosses().size() == 3, "aynı kat için ikinci dalga olmamalı")
	_cleanup()


func test_endless_has_no_tier_boss_hold() -> void:
	var sp: Node = _spawner()
	_start_endless(sp)
	var boss := _boss()
	sp._tier_bosses[15] = [boss] ## Kademe 15'in bossu sağ gibi (kapı normalde saati tutar)
	GameManager.game_time = RUN_START + 500.0
	sp._process_endless()
	assert(sp.get_endless_layer() == 6, "sonsuz kat saati boss kapısına takılmamalı: Kat %d" % sp.get_endless_layer())
	_cleanup()


func test_one_elite_per_layer() -> void:
	var sp: Node = _spawner()
	_start_endless(sp)
	GameManager.game_time = RUN_START + 99.0 ## Kat 1'in sonu: vade (en geç %70) çoktan geldi
	assert(sp._roll_endless_elite(), "Kat 1'in eliti doğmalı")
	assert(not sp._roll_endless_elite(), "aynı katta ikinci elit olmamalı")
	sp._endless_layer = 2
	GameManager.game_time = RUN_START + 199.0
	assert(sp._roll_endless_elite(), "Kat 2'nin kendi eliti")
	assert(not sp._roll_endless_elite())
	_cleanup()


func test_elite_waits_for_its_window_inside_the_layer() -> void:
	var sp: Node = _spawner()
	_start_endless(sp)
	GameManager.game_time = RUN_START + 5.0 ## vade en erken katın %10'u (10 sn)
	assert(not sp._roll_endless_elite(), "katın ilk saniyelerinde elit doğmamalı")
	_cleanup()


func test_normal_elite_rule_is_unchanged_outside_endless() -> void:
	var sp: Node = _spawner()
	GameManager.game_time = 205.0 ## Kademe 3'ün başı: vade (ilk doğumdan en az %10 sonra) henüz gelmedi
	assert(not sp._roll_elite_for(3), "normal modda elit vadesinden önce doğmamalı")
	GameManager.game_time = 295.0 ## Kademe 3'ün sonu: vade (en geç bitişten 10 sn önce) geldi
	assert(sp._roll_elite_for(3), "normal modda Kademe başına elit hâlâ çalışmalı (sonsuz kuralı bunu bozmamalı)")
	assert(not sp._roll_elite_for(3), "aynı Kademe'de ikinci elit olmamalı")
	_cleanup()


func test_catchup_state_restores_flags_for_a_late_joiner() -> void:
	_spawner()
	NetworkManager.sync_run_phase_state(true, true, 4, 16)
	assert(GameManager.victory_reached and GameManager.endless_active and GameManager.endless_layer == 4, "kat 4 durumu geri yüklenmeli")
	assert(GameManager.run_max_tier == 16, "en yüksek kademe de taşınmalı")
	assert(_layers_heard == [4], "kat bildirimi (HUD) tetiklenmeli: %s" % str(_layers_heard))
	NetworkManager.sync_run_phase_state(true, false, 0, 16)
	assert(GameManager.victory_reached and not GameManager.endless_active and GameManager.endless_layer == 0, "zafer penceresi açıkken girenin durumu")
	assert(_victory_heard == 1, "zafer penceresi tetiklenmeli")
	_cleanup()
