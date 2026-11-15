extends Node

## DÜNYA HARİTASI OYLAMASI (madde 620, kullanıcı: "multiplayerda harita seçme ekranını diğer oyuncular da görsün ve oylama ile seçilsin harita").
## Host tarafı kurallar NetworkManager üzerinde doğrudan sınanır (OfflineMultiplayerPeer: call_local RPC'ler yerelde çalışır, kimlik 1);
## istemci RPC gövdeleri tek tek çağrılır. İki süreçli gerçek doğrulama ayrı (tools/mp_audit).

const MapProfiles := preload("res://scripts/map_profiles.gd")

var _resolved: Array = []
var _finished: Array = []
var _changed: int = 0


func _ids() -> Array:
	return MapProfiles.selectable_ids()


func _host_room(peers: Array) -> void:
	_cleanup()
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = true
	NetworkManager._host_peer = 1
	var lp: Dictionary = {}
	for p in peers:
		lp[p] = {"name": "Oyuncu%d" % p, "char_id": 1, "is_ready": true, "is_host": p == 1}
	NetworkManager.lobby_players = lp
	_resolved.clear()
	_finished.clear()
	_changed = 0
	if not NetworkManager.world_map_vote_resolved.is_connected(_on_resolved):
		NetworkManager.world_map_vote_resolved.connect(_on_resolved)
	if not NetworkManager.world_map_vote_finished.is_connected(_on_finished):
		NetworkManager.world_map_vote_finished.connect(_on_finished)
	if not NetworkManager.world_map_votes_changed.is_connected(_on_changed):
		NetworkManager.world_map_votes_changed.connect(_on_changed)


func _on_resolved(id: String, tie: bool) -> void:
	_resolved.append([id, tie])


func _on_finished(id: String) -> void:
	_finished.append(id)


func _on_changed() -> void:
	_changed += 1


func _cleanup() -> void:
	NetworkManager._world_map_reset_votes()
	NetworkManager.world_map_open = false
	NetworkManager.lobby_players = {}
	NetworkManager.is_multiplayer_active = false
	NetworkManager.is_host = false
	NetworkManager._host_peer = 0


func test_decide_majority_tie_and_fallback() -> void:
	var ids: Array = _ids()
	assert(ids.size() >= 3, "en az üç seçilebilir harita")
	var a: String = ids[0]
	var b: String = ids[1]
	var c: String = ids[2]
	assert(NetworkManager.world_map_decide({}, c, 5) == [c, false], "hiç oy yok: yedek harita")
	assert(NetworkManager.world_map_decide({1: a}, c, 5) == [a, false], "tek oy")
	assert(NetworkManager.world_map_decide({1: a, 2: b, 3: b}, c, 0) == [b, false], "çoğunluk kazanır (roll etkisiz)")
	## eşitlik: eşit olanlar profil sırasıyla dizilir, roll ile seçilir (ikisi de beraberlik işaretli)
	assert(NetworkManager.world_map_decide({1: b, 2: a}, c, 0) == [a, true], "eşitlik roll 0 -> profil sırasında ilk")
	assert(NetworkManager.world_map_decide({1: b, 2: a}, c, 1) == [b, true], "eşitlik roll 1 -> ikinci")
	assert(NetworkManager.world_map_decide({1: b, 2: a}, c, 3) == [b, true], "roll eşit sayıya göre döner")
	assert(NetworkManager.world_map_decide({1: a, 2: b, 3: c, 4: c}, a, 7) == [c, false], "3 oy dağılımı: en çok alan")


func test_vote_needed_only_with_two_or_more_players() -> void:
	_host_room([1])
	assert(not NetworkManager.world_map_vote_needed(), "tek kişilik odada oylama yok (host seçer)")
	NetworkManager.lobby_players[77] = {"name": "x", "char_id": 1, "is_ready": true}
	assert(NetworkManager.world_map_vote_needed(), "iki kişi: oylama")
	NetworkManager.host_begin_world_map_vote("ana")
	assert(NetworkManager.world_map_open and NetworkManager._world_map_vote_live)
	_cleanup()
	_host_room([1])
	NetworkManager.host_begin_world_map_vote("ana")
	assert(not NetworkManager._world_map_vote_live and not NetworkManager.world_map_open, "tek kişilikte host_begin hiçbir şey yapmaz")
	_cleanup()


func test_everyone_voted_resolves_then_host_starts_after_hold() -> void:
	var ids: Array = _ids()
	_host_room([1, 77, 88])
	NetworkManager.host_begin_world_map_vote(ids[0])
	assert(NetworkManager.world_map_vote_time_left == NetworkManager.WORLD_MAP_VOTE_TIMEOUT)
	NetworkManager.cast_world_map_vote(ids[1]) ## host'un kendi oyu
	NetworkManager._host_record_world_map_vote(77, ids[1])
	assert(_resolved.is_empty() and NetworkManager.world_map_vote_winner == "", "herkes oy vermeden bitmemeli")
	NetworkManager._host_record_world_map_vote(88, ids[2])
	assert(_resolved == [[ids[1], false]], "herkes oy verdi: çoğunluk kazanır: %s" % str(_resolved))
	assert(NetworkManager.world_map_vote_winner == ids[1])
	assert(_finished.is_empty(), "kazanan önce gösterilir, oyun hemen başlamaz")
	NetworkManager.update_world_map_vote_timer(NetworkManager.WORLD_MAP_RESULT_HOLD * 0.5)
	assert(_finished.is_empty())
	NetworkManager.update_world_map_vote_timer(NetworkManager.WORLD_MAP_RESULT_HOLD)
	assert(_finished == [ids[1]], "gösterim süresi dolunca host oyunu başlatır")
	NetworkManager.update_world_map_vote_timer(NetworkManager.WORLD_MAP_RESULT_HOLD * 3.0)
	assert(_finished.size() == 1, "bir kez")
	_cleanup()


func test_vote_can_change_until_result_and_invalid_votes_are_ignored() -> void:
	var ids: Array = _ids()
	_host_room([1, 77, 88])
	NetworkManager.host_begin_world_map_vote(ids[0])
	NetworkManager._host_record_world_map_vote(77, ids[0])
	NetworkManager._host_record_world_map_vote(77, ids[2]) ## oyunu değiştirdi
	assert(NetworkManager.world_map_votes[77] == ids[2], "son oy geçerli")
	NetworkManager._host_record_world_map_vote(999, ids[1]) ## odada olmayan
	NetworkManager._host_record_world_map_vote(88, "yok_boyle_harita") ## geçersiz harita
	assert(not NetworkManager.world_map_votes.has(999) and not NetworkManager.world_map_votes.has(88))
	NetworkManager.cast_world_map_vote("yok_boyle_harita")
	assert(not NetworkManager.world_map_votes.has(1), "geçersiz harita oy sayılmaz")
	## sonuçtan sonra oy kabul edilmez
	NetworkManager.cast_world_map_vote(ids[0])
	NetworkManager._host_record_world_map_vote(88, ids[0])
	assert(NetworkManager.world_map_vote_winner == ids[0])
	NetworkManager.cast_world_map_vote(ids[1])
	NetworkManager._host_record_world_map_vote(77, ids[1])
	assert(NetworkManager.world_map_votes[77] == ids[2] and NetworkManager.world_map_votes[1] == ids[0], "sonuç sonrası oy değişmez")
	_cleanup()


func test_timeout_counts_only_cast_votes() -> void:
	var ids: Array = _ids()
	_host_room([1, 77, 88])
	NetworkManager.host_begin_world_map_vote(ids[0])
	NetworkManager._host_record_world_map_vote(77, ids[2])
	NetworkManager.update_world_map_vote_timer(NetworkManager.WORLD_MAP_VOTE_TIMEOUT - 1.0)
	assert(_resolved.is_empty(), "süre dolmadan bitmez")
	NetworkManager.update_world_map_vote_timer(1.5)
	assert(_resolved == [[ids[2], false]], "süre doldu: oy veren tek kişinin haritası: %s" % str(_resolved))
	_cleanup()


func test_timeout_without_votes_falls_back_to_hosts_last_map() -> void:
	var ids: Array = _ids()
	_host_room([1, 77])
	var old: String = GameManager.selected_map
	GameManager.selected_map = ids[1]
	NetworkManager.host_begin_world_map_vote(ids[1])
	NetworkManager.update_world_map_vote_timer(NetworkManager.WORLD_MAP_VOTE_TIMEOUT + 1.0)
	assert(_resolved == [[ids[1], false]], "hiç oy yok: host'un son seçimi: %s" % str(_resolved))
	GameManager.selected_map = old
	_cleanup()


func test_leaving_voter_drops_vote_and_can_complete_the_vote() -> void:
	var ids: Array = _ids()
	_host_room([1, 77, 88])
	NetworkManager.host_begin_world_map_vote(ids[0])
	NetworkManager._host_record_world_map_vote(1, ids[0])
	NetworkManager._host_record_world_map_vote(77, ids[1])
	assert(_resolved.is_empty(), "88 henüz oy vermedi")
	NetworkManager.lobby_players.erase(88) ## 88 koptu
	NetworkManager._on_world_map_voter_left(88)
	assert(_resolved.size() == 1 and _resolved[0][1] == true, "kalanlar oy verdi, eşitlik: %s" % str(_resolved))
	_cleanup()
	## oy vermiş oyuncu koparsa oyu düşer
	_host_room([1, 77, 88])
	NetworkManager.host_begin_world_map_vote(ids[0])
	NetworkManager._host_record_world_map_vote(1, ids[0])
	NetworkManager._host_record_world_map_vote(77, ids[1])
	NetworkManager.lobby_players.erase(77)
	NetworkManager._on_world_map_voter_left(77)
	assert(not NetworkManager.world_map_votes.has(77) and _resolved.is_empty(), "oyu düşer, 88 hâlâ bekleniyor")
	_cleanup()


func test_cancel_resets_everything_and_never_starts_the_game() -> void:
	var ids: Array = _ids()
	_host_room([1, 77])
	NetworkManager.host_begin_world_map_vote(ids[0])
	NetworkManager._host_record_world_map_vote(77, ids[1])
	NetworkManager.broadcast_world_map(false) ## host GERİ dedi
	assert(NetworkManager.world_map_votes.is_empty() and not NetworkManager._world_map_vote_live and not NetworkManager.world_map_open)
	NetworkManager.update_world_map_vote_timer(100.0)
	assert(_resolved.is_empty() and _finished.is_empty(), "iptal edilen oylama sonuçlanmaz")
	## sonuç gösterilirken iptal: oyun başlamaz
	NetworkManager.host_begin_world_map_vote(ids[0])
	NetworkManager.cast_world_map_vote(ids[0])
	NetworkManager._host_record_world_map_vote(77, ids[0])
	assert(_resolved.size() == 1)
	NetworkManager.broadcast_world_map(false)
	NetworkManager.update_world_map_vote_timer(100.0)
	assert(_finished.is_empty(), "gösterim sırasında iptal: oyun başlamaz")
	_cleanup()


func test_client_rpc_bodies_validate_and_keep_my_pending_vote() -> void:
	var ids: Array = _ids()
	_cleanup()
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = false
	NetworkManager._host_peer = 1
	NetworkManager.world_map_open = true
	var me: int = NetworkManager.multiplayer.get_unique_id()
	## host yayını: geçersiz harita atılır, süre kopyalanır
	NetworkManager._rpc_world_map_votes(PackedInt32Array([5, 6, 7]), PackedStringArray([ids[0], "yok_boyle", ids[1]]), 12.5)
	assert(NetworkManager.world_map_votes == {5: ids[0], 7: ids[1]}, "geçersiz harita yok sayılır: %s" % str(NetworkManager.world_map_votes))
	assert(is_equal_approx(NetworkManager.world_map_vote_time_left, 12.5))
	## host yayını benim son oyumdan önce üretildiyse bekleyen oyum ezilmez
	NetworkManager._world_map_my_vote = ids[2]
	NetworkManager._rpc_world_map_votes(PackedInt32Array([5]), PackedStringArray([ids[0]]), 10.0)
	assert(NetworkManager.world_map_votes.get(me, "") == ids[2] and NetworkManager.my_world_map_vote() == ids[2], "bekleyen oyum korunur")
	## sonuç: kazanan + beraberlik bayrağı + sinyal; sonra gelen oy listesi yok sayılır
	NetworkManager._rpc_world_map_vote_result(ids[1], true)
	assert(NetworkManager.world_map_vote_winner == ids[1] and NetworkManager.world_map_vote_tie)
	NetworkManager._rpc_world_map_votes(PackedInt32Array([5]), PackedStringArray([ids[0]]), 3.0)
	assert(NetworkManager.world_map_votes.get(me, "") == ids[2], "sonuçtan sonra liste değişmez")
	## yeni açılış önceki oylamayı sıfırlar
	NetworkManager.world_map_open = false
	NetworkManager._rpc_world_map(true, ids[0])
	assert(NetworkManager.world_map_votes.is_empty() and NetworkManager.world_map_vote_winner == "" and NetworkManager.my_world_map_vote() == "")
	_cleanup()
