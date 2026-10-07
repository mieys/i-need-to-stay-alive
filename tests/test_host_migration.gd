extends Node

## HOST DEVRİ (2026-10-08, kullanıcı isteği: "host çıkınca host devri de olsun"): sıra listesi / aday seçimi kuralları (host_migration.gd),
## devir paketi (enemy_spawner.gd export_handover / import_handover), devir başlatma koşulları (network_manager.gd). Gerçek ağ akışı (host ölür ->
## yeni host seçilir -> diğerleri geri katılır) üç süreçli `tools/mp_audit/run_audit.ps1 -Mode migration [-Kill crash|close] [-Net epic]`.

const MigrationScript := preload("res://scripts/net/host_migration.gd")
const SpawnerScript := preload("res://scripts/enemy_spawner.gd")

var _saved: Dictionary = {}


func _begin() -> void:
	_saved = {"active": NetworkManager.is_multiplayer_active, "host": NetworkManager.is_host, "in_game": NetworkManager._is_game_in_progress,
		"roster": NetworkManager._migration_roster.duplicate(true), "migration": NetworkManager._migration.duplicate(true),
		"handover": NetworkManager.migration_handover.duplicate(true)}


func _end() -> void:
	NetworkManager.is_multiplayer_active = _saved.get("active", false)
	NetworkManager.is_host = _saved.get("host", false)
	NetworkManager._is_game_in_progress = _saved.get("in_game", false)
	NetworkManager._migration_roster = _saved.get("roster", [])
	NetworkManager._migration = _saved.get("migration", {})
	NetworkManager.migration_handover = _saved.get("handover", {})


# ------------------------------------------------------------------ sıra listesi

func _players() -> Dictionary:
	return {1: {"name": "Host", "char_id": 5}, 700: {"name": "Birinci", "char_id": 13}, 300: {"name": "İkinci", "char_id": 2}, 900: {"name": "Yabancı", "char_id": 1}}


func test_roster_keeps_persistent_order_host_first_and_only_connected_game_peers() -> void:
	var uid := {1: "uid_host", 700: "uid_b", 300: "uid_c", 900: "uid_stranger"}
	var addr := {700: "192.168.1.20", 300: "192.168.1.21"}
	var eos := {700: "eos_b"}
	## Kalıcı sıra: katılım sırası (peer id'ye DEĞİL) - 700 önce katılmıştı.
	var roster: Array = MigrationScript.build_roster(_players(), uid, addr, eos, ["uid_host", "uid_b", "uid_c"], [1, 300, 700])
	assert(roster.size() == 3, "bağlı oyun peer'leri: %d" % roster.size())
	assert(str(roster[0]["uid"]) == "uid_host" and str(roster[1]["uid"]) == "uid_b" and str(roster[2]["uid"]) == "uid_c", "host ilk, sonra katılım sırası")
	assert(str(roster[1]["addr"]) == "192.168.1.20" and str(roster[1]["eos"]) == "eos_b" and int(roster[1]["char"]) == 13 and str(roster[1]["name"]) == "Birinci", "alanlar")
	assert(MigrationScript.host_uid(roster) == "uid_host", "roster'ın ilki host")
	## Sırada olmayan bağlı kimlik sona eklenir; kimliği bilinmeyen / bağlı olmayan peer girmez.
	var r2: Array = MigrationScript.build_roster(_players(), uid, addr, eos, ["uid_host"], [1, 300, 700, 12345])
	assert(r2.size() == 3 and str(r2[0]["uid"]) == "uid_host", "kimliksiz peer (12345) girmez")
	var r3: Array = MigrationScript.build_roster(_players(), uid, addr, eos, ["uid_host", "uid_b", "uid_c"], [1, 700])
	assert(r3.size() == 2 and str(r3[1]["uid"]) == "uid_b", "ayrılan (c) listeden düşer")


func test_candidates_exclude_the_lost_host_and_everyone_agrees_on_the_order() -> void:
	var roster: Array = [{"uid": "h"}, {"uid": "b"}, {"uid": "c"}, {"uid": "d"}]
	var cands: Array = MigrationScript.candidates(roster, "h")
	assert(cands.size() == 3 and str(cands[0]["uid"]) == "b", "ilk aday: sıradaki ilk istemci")
	## Her istemci kendi kopyasından AYNI listeyi çıkarır -> kendi sırasını bulur, hepsi aynı kişiyi ilk aday görür.
	assert(MigrationScript.index_of(cands, "b") == 0 and MigrationScript.index_of(cands, "c") == 1 and MigrationScript.index_of(cands, "d") == 2, "dizinler")
	assert(MigrationScript.index_of(cands, "h") == -1 and MigrationScript.index_of(cands, "x") == -1, "host/yabancı aday değil")
	assert(MigrationScript.candidates([], "h").is_empty() and MigrationScript.host_uid([]) == "", "boş liste güvenli")
	## Tek kalan oyuncu: kendisi tek aday -> kendisi host olur
	var solo: Array = MigrationScript.candidates([{"uid": "h"}, {"uid": "b"}], "h")
	assert(solo.size() == 1 and MigrationScript.index_of(solo, "b") == 0, "tek kalan oyuncu host olur")


func test_port_and_address_helpers() -> void:
	assert(MigrationScript.parse_port("192.168.1.5:7821") == 7821, "ip:port")
	assert(MigrationScript.parse_port("LAN:7777") == 7777, "LAN:port")
	assert(MigrationScript.parse_port("İnternet (Epic) - Ali") == 7777, "port yok: yedek")
	assert(MigrationScript.parse_port("host:abc", 9000) == 9000, "geçersiz port: yedek")
	assert(MigrationScript.usable_addr("") == "127.0.0.1" and MigrationScript.usable_addr("10.0.0.2") == "10.0.0.2", "boş adres yerel")
	assert(MigrationScript.ATTEMPT_WINDOW_ONLINE_SEC > MigrationScript.ATTEMPT_WINDOW_SEC and MigrationScript.TOTAL_TIMEOUT_ONLINE_SEC > MigrationScript.TOTAL_TIMEOUT_SEC,
		"Epic pencereleri LAN'dan uzun")
	assert(MigrationScript.HOST_SILENCE_LIMIT_MSEC > 5000, "kalp atışı sessizliği yanlış alarm vermeyecek kadar uzun")


# ------------------------------------------------------------------ devir koşulları

func test_migration_only_starts_for_a_running_game_with_a_roster_that_includes_me() -> void:
	_begin()
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = false
	NetworkManager._is_game_in_progress = true
	NetworkManager._migration_roster = [{"uid": "h", "addr": "", "eos": ""}, {"uid": NetworkManager.local_player_uid, "addr": "", "eos": ""}]
	## Test düğümü current_scene ama adı "Main" değil -> devir başlamaz (yükleme/lobi/menüde host düşmesi eski akışta kalır)
	assert(not NetworkManager._can_migrate(), "sahne Main değilken devir olmaz")
	NetworkManager._is_game_in_progress = false
	assert(not NetworkManager._try_begin_host_migration(), "oyun sürmüyorken devir başlamaz")
	NetworkManager._is_game_in_progress = true
	NetworkManager._migration_roster = []
	assert(not NetworkManager._try_begin_host_migration(), "sıra listesi yokken devir başlamaz")
	assert(NetworkManager.is_host_migrating() == false, "hiçbiri devri başlatmadı")
	NetworkManager.is_host = true
	NetworkManager._migration_roster = [{"uid": "h"}, {"uid": "b"}]
	assert(not NetworkManager._can_migrate(), "host kendi devrini başlatmaz")
	_end()


func test_main_rpc_targets_are_empty_while_migrating() -> void:
	_begin()
	NetworkManager._migration = {"status": "connecting"}
	assert(NetworkManager.main_rpc_targets().is_empty(), "devir sürerken kimseye gönderim yok")
	NetworkManager._migration = {}
	_end()


# ------------------------------------------------------------------ spawner devir paketi

func _spawner() -> Node:
	var sp: Node = SpawnerScript.new()
	add_child(sp)
	return sp


func test_spawner_handover_roundtrip_restores_hidden_counters() -> void:
	var a: Node = _spawner()
	a._boss_tiers_spawned = {3: true, 6: true}
	a._elite_spawned_tiers = {1: true, 2: true}
	a._final_gate_opened = true
	a._held_total = 42.5
	a._spawn_tier = 7
	a._announced_tier = 7
	a._endless_bosses_spawned = {2: true}
	a._endless_elite_spawned = {1: true}
	var packed: Dictionary = a.export_handover()
	assert(packed["boss_tiers"].has(3) and packed["boss_tiers"].has(6), "ölü/yok bosslar 'doğdu' olarak taşınır")
	var b: Node = _spawner()
	b.import_handover(packed)
	assert(b._boss_tiers_spawned.has(3) and b._boss_tiers_spawned.has(6), "boss kademeleri aktarıldı")
	assert(b._elite_spawned_tiers.has(1) and b._elite_spawned_tiers.has(2), "elit kademeleri aktarıldı")
	assert(b._final_gate_opened and is_equal_approx(b._held_total, 42.5) and b._spawn_tier == 7 and b._announced_tier == 7, "kapı/tutulan süre/kademe")
	assert(b._endless_bosses_spawned.has(2) and b._endless_elite_spawned.has(1), "sonsuz mod sayaçları")
	for n in [a, b]:
		n.free()


func test_handover_respawns_a_living_tier_boss_and_the_final_before_victory() -> void:
	var a: Node = _spawner()
	a._boss_tiers_spawned = {3: true, 6: true}
	var alive := Node2D.new()
	add_child(alive)
	alive.set("name", "yasayan_boss")
	a._tier_bosses = {6: [alive]} ## 6. kademenin bossu hâlâ yaşıyor (is_dead alanı yok -> yaşıyor sayılır)
	a._final_spawned = true ## Final doğdu, zafer henüz yok
	a._run_phase = SpawnerScript.RunPhase.NORMAL
	var packed: Dictionary = a.export_handover()
	assert(packed["boss_tiers"].has(3) and not packed["boss_tiers"].has(6), "yaşayan bossun kademesi 'doğdu' sayılmaz (yeni Main'de yeniden doğar)")
	var b: Node = _spawner()
	b.import_handover(packed)
	assert(not b._final_spawned, "zaferden önce Final bossları yeni Main'de yok -> Final yeniden doğar")
	assert(b._boss_tiers_spawned.has(3) and not b._boss_tiers_spawned.has(6), "6. kademe bossu yeniden doğabilir")
	## Zaferden SONRA (sonsuz mod) Final tekrar doğmaz
	var c: Node = _spawner()
	var after_victory: Dictionary = packed.duplicate(true)
	after_victory["run_phase"] = SpawnerScript.RunPhase.ENDLESS
	after_victory["endless_layer"] = 2
	c.import_handover(after_victory)
	assert(c._final_spawned and c._run_phase == SpawnerScript.RunPhase.ENDLESS and c._endless_layer == 2, "sonsuz modda Final bayrağı kalır")
	for n in [a, b, c, alive]:
		n.free()


func test_handover_travels_as_a_plain_dictionary_between_peers() -> void:
	## RPC ile giden paket (Dictionary/Array/int/float/bool) var_to_bytes ile gidip gelebilmeli - Obje içermemeli.
	var a: Node = _spawner()
	a._boss_tiers_spawned = {3: true}
	var packed: Dictionary = {"spawner": a.export_handover()}
	var round_trip = bytes_to_var(var_to_bytes(packed))
	assert(round_trip is Dictionary and (round_trip["spawner"] as Dictionary).has("boss_tiers"), "paket serileşir")
	a.free()
