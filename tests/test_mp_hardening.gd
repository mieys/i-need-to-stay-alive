extends Node

## ÇOK OYUNCULU SAĞLAMLAŞTIRMA (2026-10-08 MP denetimi, bkz. CLAUDE.md madde 28-29): yaratık paketi ikili biçimi + sıra numaraları, gerçek oyuncu
## sayısı (hayalet yabancı yaratık canını şişirmesin), Main'i hazır peer kaydı, host-only RPC koruması (tekli oyunda yerel çağrı geçer),
## geri katılana drop yakalaması. Gerçek ağ davranışı (yabancı atma, sahte RPC reddi) iki/üç süreçli `tools/mp_audit/run_audit.ps1 -Mode security`.

const CodecScript := preload("res://scripts/enemy_sync_codec.gd")

var _saved: Dictionary = {}


func _begin() -> void:
	_saved = {"active": NetworkManager.is_multiplayer_active, "host": NetworkManager.is_host, "lobby": NetworkManager.lobby_players.duplicate(true),
		"game_peers": NetworkManager._game_peers.duplicate(), "ready": NetworkManager._main_ready_peers.duplicate(),
		"visual": NetworkManager._visual_drops.duplicate()}


func _end() -> void:
	NetworkManager.is_multiplayer_active = _saved.get("active", false)
	NetworkManager.is_host = _saved.get("host", false)
	NetworkManager.lobby_players = _saved.get("lobby", {})
	NetworkManager._game_peers = _saved.get("game_peers", {})
	NetworkManager._main_ready_peers = _saved.get("ready", {})
	for id in NetworkManager._visual_drops.keys():
		if not (_saved.get("visual", {}) as Dictionary).has(id):
			var d = NetworkManager._visual_drops[id]
			if is_instance_valid(d):
				d.free()
			NetworkManager._visual_drops.erase(id)
	for g in ["gold_drops", "weapon_shard_drops", "xp_orbs", "food_drops", "chest_drops", "magnet_drops"]:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.free()


# ------------------------------------------------------------------ yaratık paketi

func _sample_states() -> Array:
	return [
		[7, Vector2(123.456, -789.125), false, 42.5, 10.25, false, 0, 0],
		[1000000, Vector2(-20000.0, 20000.0), true, 0.0, 0.0, true, 3, 2147483000],
		[12, Vector2(0.0, 0.0), false, 1.0e6, 5.5e5, true, 255, 0],
	]


func test_codec_round_trips_every_field() -> void:
	var states: Array = _sample_states()
	var data: PackedByteArray = CodecScript.encode(65535, states)
	var dec: Dictionary = CodecScript.decode(data)
	assert(int(dec["tick"]) == 65535, "tur sayısı")
	var out: Array = dec["states"]
	assert(out.size() == 3, "3 yaratık")
	for i in 3:
		var a: Array = states[i]
		var b: Array = out[i]
		assert(int(b[0]) == int(a[0]), "kimlik %d" % i)
		assert((b[1] as Vector2).distance_to(a[1] as Vector2) < 0.1, "konum 1/8 piksel içinde %d" % i)
		assert(b[2] == a[2] and b[5] == a[5], "ölü/öfkeli bayrakları %d" % i)
		assert(is_equal_approx(float(b[3]), float(a[3])) and is_equal_approx(float(b[4]), float(a[4])), "can/kalkan %d" % i)
		assert(int(b[6]) == int(a[6]) and int(b[7]) == int(a[7]), "chill/son vuran %d" % i)


func test_codec_is_much_smaller_than_variant_arrays() -> void:
	var states: Array = []
	for i in CodecScript.BATCH:
		states.append([1000 + i, Vector2(i * 31.7, i * -12.3), false, 100.0 + i, 20.0, false, 0, 0])
	var bin: PackedByteArray = CodecScript.encode(5, states)
	var variant_bytes: int = var_to_bytes(states).size()
	assert(bin.size() == CodecScript.HEADER_BYTES + CodecScript.BATCH * CodecScript.RECORD_BYTES, "kayıt başı 22 bayt: %d" % bin.size())
	assert(variant_bytes > bin.size() * 3, "eski biçim en az 3 kat büyük (eski %d, yeni %d)" % [variant_bytes, bin.size()])
	## En kötü durum (hepsi son vuran taşır) bile Epic paket sınırının (~1100) altında kalır.
	var worst: Array = []
	for i in CodecScript.BATCH:
		worst.append([i + 1, Vector2.ZERO, true, 1.0, 1.0, true, 1, 12345])
	assert(CodecScript.encode(1, worst).size() < 1100, "tam dolu paket Epic sınırının altında")


func test_codec_decode_survives_garbage() -> void:
	assert((CodecScript.decode(PackedByteArray())["states"] as Array).is_empty(), "boş paket")
	var short := PackedByteArray([1, 0, 9, 9, 9])
	assert((CodecScript.decode(short)["states"] as Array).is_empty(), "kısa kayıt yok sayılır")
	var data: PackedByteArray = CodecScript.encode(3, _sample_states())
	data.resize(data.size() - 3) ## son kayıt kesik
	var dec: Dictionary = CodecScript.decode(data)
	assert((dec["states"] as Array).size() == 2, "kesik son kayıt atılır, öncekiler korunur: %d" % (dec["states"] as Array).size())


func test_tick_and_sequence_ordering_handles_wraparound() -> void:
	assert(not CodecScript.is_stale(5, -1), "ilk paket her zaman geçer")
	assert(not CodecScript.is_stale(10, 10), "aynı tur (başka paket grubu) geçer")
	assert(not CodecScript.is_stale(11, 10), "yeni tur geçer")
	assert(not CodecScript.is_stale(9, 10), "bir tur geride hâlâ geçer (turun paketleri sırasız gelebilir)")
	assert(CodecScript.is_stale(7, 10), "daha eski tur atılır")
	assert(not CodecScript.is_stale(2, 65534), "sarma: 65534 -> 2 yeni")
	assert(CodecScript.is_stale(65530, 3), "sarma: 3'ten sonra 65530 eski")
	assert(CodecScript.seq_newer(11, 10) and not CodecScript.seq_newer(10, 10) and not CodecScript.seq_newer(9, 10), "seq_newer temel")
	assert(CodecScript.seq_newer(1, 65535) and not CodecScript.seq_newer(65535, 1), "seq_newer sarma")


# ------------------------------------------------------------------ oyuncu sayısı + hazır peer'ler

func test_game_player_count_ignores_ghost_lobby_peers() -> void:
	_begin()
	NetworkManager.is_multiplayer_active = false
	assert(NetworkManager.game_player_count() == 1, "tekli oyun 1")
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = true
	NetworkManager.lobby_players = {1: {"name": "H"}, 2: {"name": "C"}, 3: {"name": "Yabancı"}}
	NetworkManager._game_peers = {}
	assert(NetworkManager.game_player_count() == 3, "oyun kaydı yokken (lobi/testler) lobi sayısı")
	NetworkManager._game_peers = {1: true, 2: true}
	assert(NetworkManager.game_player_count() == 2, "lobideki hayalet yabancı sayılmaz")
	NetworkManager._game_peers[3] = true
	assert(NetworkManager.game_player_count() == 3, "kabul edilen geri katılımcı sayılır")
	NetworkManager._game_peers.erase(2)
	assert(NetworkManager.game_player_count() == 2, "ayrılan sayıdan düşer")
	_end()


func test_spawner_uses_the_real_player_count_for_enemy_health() -> void:
	_begin()
	var sp: Node = load("res://scripts/enemy_spawner.gd").new()
	add_child(sp)
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = true
	NetworkManager.lobby_players = {1: {}, 2: {}, 3: {}, 4: {}}
	NetworkManager._game_peers = {1: true, 2: true}
	assert(sp._player_count() == 2, "spawner gerçek oyuncu sayısını kullanır")
	var scene: PackedScene = load("res://scenes/creatures/enemy_agac1.tscn") as PackedScene
	var a: Node = scene.instantiate()
	var b: Node = scene.instantiate()
	add_child(a)
	add_child(b)
	sp._apply_global_buff(a) ## host: kendi sayısı (2)
	sp._apply_global_buff(b, 2) ## istemci: host'un yolladığı sayı
	assert(int(a.get_meta("mp_player_count")) == 2 and int(b.get_meta("mp_player_count")) == 2, "yaratığa yazılan sayı")
	assert(is_equal_approx(float(a.max_health), float(b.max_health)), "host ve istemci kopyasının canı aynı")
	var c: Node = scene.instantiate()
	add_child(c)
	sp._apply_global_buff(c, 4) ## 4 oyunculu çarpan daha yüksek can verir
	assert(float(c.max_health) > float(a.max_health), "oyuncu sayısı çarpanı çalışıyor")
	for n in [a, b, c, sp]:
		n.free()
	_end()


func test_game_ready_peers_only_returns_peers_whose_main_exists() -> void:
	_begin()
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = true
	var me: int = multiplayer.get_unique_id()
	NetworkManager.lobby_players = {me: {}, 2: {}, 3: {}, 4: {}}
	NetworkManager._game_peers = {}
	NetworkManager._main_ready_peers = {}
	var fallback: Array = NetworkManager.game_ready_peers()
	assert(fallback.has(2) and fallback.has(3) and fallback.has(4) and not fallback.has(me), "oyun kaydı yokken tüm uzak lobi peer'leri, host hariç")
	NetworkManager._game_peers = {me: true, 2: true, 3: true}
	assert(NetworkManager.game_ready_peers().is_empty(), "Main'i henüz kurulmamış peer'e yayın gitmez")
	NetworkManager._main_ready_peers = {2: true, 4: true}
	var ready: Array = NetworkManager.game_ready_peers()
	assert(ready == [2], "sadece oyunda VE Main'i hazır olan: %s" % str(ready)) ## 4 oyunda değil (yabancı)
	NetworkManager.is_multiplayer_active = false
	assert(NetworkManager.game_ready_peers().is_empty(), "tekli oyunda kimse yok")
	_end()


func test_main_rpc_targets_broadcast_until_the_roster_arrives_then_only_connected_ready_peers() -> void:
	_begin()
	var saved_known: bool = NetworkManager._ready_roster_known
	var saved_roster: Array = NetworkManager._ready_roster.duplicate()
	NetworkManager.is_multiplayer_active = false
	assert(NetworkManager.main_rpc_targets() == [0], "tekli oyun: yayın (hiç çağrılmaz ama zararsız)")
	NetworkManager.is_multiplayer_active = true
	NetworkManager._ready_roster_known = false
	assert(NetworkManager.main_rpc_targets() == [0], "liste gelene kadar herkese yayın (eski davranış)")
	NetworkManager._ready_roster_known = true
	NetworkManager._ready_roster = [1, 2, 3]
	## Çevrimdışı eşte bağlı peer yok: bağlı olmayanlara gönderim yapılmaz
	assert(NetworkManager.main_rpc_targets().is_empty(), "bağlı olmayan peer'e gönderilmez")
	NetworkManager._ready_roster_known = saved_known
	NetworkManager._ready_roster = saved_roster
	_end()


func test_host_only_guard_passes_local_calls_in_single_player() -> void:
	_begin()
	NetworkManager.is_multiplayer_active = false
	assert(NetworkManager._from_host(), "tekli oyunda yerel çağrı (gönderen 1 görünse bile) geçer")
	GameManager.is_game_over = false
	NetworkManager.sync_game_over() ## doğrudan yerel çağrı da korumadan geçer
	assert(GameManager.is_game_over, "sync_game_over tekli oyunda çalışır")
	GameManager.is_game_over = false
	_end()


# ------------------------------------------------------------------ drop yakalaması

func test_drop_catchup_lists_real_drops_and_visual_copy_is_idempotent() -> void:
	_begin()
	var gold = load("res://scenes/gold_drop.tscn").instantiate()
	gold.amount = 7
	gold.global_position = Vector2(100, 200)
	gold.set_meta("drop_network_id", 501)
	add_child(gold)
	var shard = load("res://scenes/weapon_shard_drop.tscn").instantiate()
	shard.amount = 3
	shard.global_position = Vector2(-50, 60)
	shard.set_meta("drop_network_id", 502)
	add_child(shard)
	var visual = load("res://scenes/gold_drop.tscn").instantiate() ## görsel kopya (network_spawned) yakalamaya girmez
	visual.set_meta("network_spawned", true)
	visual.set_meta("drop_network_id", 503)
	add_child(visual)
	var entries: Array = NetworkManager.collect_drop_catchup()
	var by_id: Dictionary = {}
	for e in entries:
		by_id[int(e[3])] = e
	assert(by_id.has(501) and by_id.has(502) and not by_id.has(503), "gerçek drop'lar listelenir, görsel kopya listelenmez: %s" % str(by_id.keys()))
	assert(str(by_id[501][0]) == "gold" and int(by_id[501][2]) == 7 and (by_id[501][1] as Vector2) == Vector2(100, 200), "altın kaydı")
	assert(str(by_id[502][0]) == "weapon_shard" and int(by_id[502][2]) == 3, "parçacık kaydı")
	## İstemci tarafı: aynı kimlik iki kez gelse bile TEK görsel kopya
	NetworkManager.is_multiplayer_active = true
	NetworkManager._spawn_visual_drop("gold", Vector2(10, 10), 4, 9001)
	NetworkManager._spawn_visual_drop("gold", Vector2(10, 10), 4, 9001)
	var copies: int = 0
	for n in get_tree().get_nodes_in_group("gold_drops"):
		if int(n.get_meta("drop_network_id", 0)) == 9001:
			copies += 1
	assert(copies == 1, "yakalama tekrarı çift drop yaratmaz: %d" % copies)
	assert(NetworkManager._visual_drops.has(9001) and bool(NetworkManager._visual_drops[9001].get_meta("network_spawned")), "görsel kopya kayıtlı")
	for n in [gold, shard, visual]:
		n.free()
	_end()
