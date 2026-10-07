extends Node

## Kullanıcı isteği (2026-10-08): "bir arkadaş öldüğünde ve hiç canı kalmadığında canının 5 dakikalık bekleme süresi yanında bulunan ve onu
## diriltmek için yanında bekleyen her arkadaş başına %80 hızlansın." Kural GameManager'da (revive_regen_rate / revive_assist_count /
## _process_revive_regen): hakkı 0 olan, ÖLÜ/YERDE YATAN oyuncunun cesedinin diriltme menzilindeki (player.gd REVIVE_RANGE) hayatta, yerde
## yatmayan her arkadaş için hız +0.8 (toplamsal: 1 arkadaş 1,8x, 2 arkadaş 2,6x). Sayaç zaten sadece hak 0'ken işler.

const PlayerScript: GDScript = preload("res://scripts/player.gd")


class FakePlayer extends Node2D:
	var peer_id: int = 0
	var is_dead: bool = false
	var is_downed: bool = false


var _saved: Dictionary = {}
var _nodes: Array[Node] = []


func _begin() -> void:
	_saved = {"active": NetworkManager.is_multiplayer_active, "host": NetworkManager.is_host, "lobby": NetworkManager.lobby_players.duplicate(true),
		"revives": GameManager.peer_revives.duplicate(), "left": GameManager._revive_regen_left.duplicate(),
		"assist": GameManager._revive_regen_assist.duplicate(), "rate": GameManager._revive_regen_rate.duplicate(),
		"sent": GameManager._revive_regen_rate_sent.duplicate(), "timer": GameManager._revive_assist_timer,
		"sync_timer": GameManager._revive_regen_sync_timer}
	GameManager._revive_regen_left = {}
	GameManager._revive_regen_assist = {}
	GameManager._revive_regen_rate = {}
	GameManager._revive_regen_rate_sent = {}
	GameManager._revive_assist_timer = 0.0
	GameManager._revive_regen_sync_timer = 1000.0 ## periyodik yayın karışmasın


func _end() -> void:
	NetworkManager.is_multiplayer_active = _saved.get("active", false)
	NetworkManager.is_host = _saved.get("host", false)
	NetworkManager.lobby_players = _saved.get("lobby", {})
	GameManager.peer_revives = _saved.get("revives", {})
	GameManager._revive_regen_left = _saved.get("left", {})
	GameManager._revive_regen_assist = _saved.get("assist", {})
	GameManager._revive_regen_rate = _saved.get("rate", {})
	GameManager._revive_regen_rate_sent = _saved.get("sent", {})
	GameManager._revive_assist_timer = float(_saved.get("timer", 0.0))
	GameManager._revive_regen_sync_timer = float(_saved.get("sync_timer", 0.0))
	for n in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


func _remote(peer: int, pos: Vector2, dead: bool = false, downed: bool = false) -> FakePlayer:
	var p := FakePlayer.new()
	p.peer_id = peer
	p.is_dead = dead
	p.is_downed = downed
	p.add_to_group("remote_players")
	add_child(p)
	p.global_position = pos
	_nodes.append(p)
	return p


func _local(pos: Vector2, dead: bool = false) -> FakePlayer:
	var p := FakePlayer.new()
	p.peer_id = 1
	p.is_dead = dead
	p.add_to_group("player")
	add_child(p)
	p.global_position = pos
	_nodes.append(p)
	return p


func _host_session(peers: Array) -> void:
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = true
	var lobby := {}
	for pid in peers:
		lobby[int(pid)] = {"name": "P%d" % int(pid)}
	NetworkManager.lobby_players = lobby


func test_rate_is_additive_eighty_percent_per_waiting_friend() -> void:
	assert(is_equal_approx(GameManager.REVIVE_REGEN_ASSIST_BONUS, 0.8), "arkadaş başına %80")
	assert(is_equal_approx(GameManager.revive_regen_rate(0), 1.0), "kimse yokken normal hız")
	assert(is_equal_approx(GameManager.revive_regen_rate(1), 1.8), "1 arkadaş: 1,8x")
	assert(is_equal_approx(GameManager.revive_regen_rate(2), 2.6), "2 arkadaş: 2,6x")
	assert(is_equal_approx(GameManager.revive_regen_rate(3), 3.4), "3 arkadaş: 3,4x")
	assert(is_equal_approx(GameManager.revive_regen_rate(-5), 1.0), "negatif sayı güvenli")


func test_assist_range_is_the_revive_channel_range() -> void:
	assert(is_equal_approx(GameManager.REVIVE_REGEN_ASSIST_RANGE, PlayerScript.REVIVE_RANGE),
		"yanında bekleme menzili diriltme kanalı menziliyle AYNI olmalı (%s vs %s)" % [GameManager.REVIVE_REGEN_ASSIST_RANGE, PlayerScript.REVIVE_RANGE])


func test_assist_count_only_counts_living_friends_near_the_corpse() -> void:
	_begin()
	_host_session([1, 2, 3, 4, 5, 6])
	var corpse := _remote(2, Vector2.ZERO, true)
	_remote(3, Vector2(50, 0)) ## menzilde, hayatta -> sayılır
	_remote(4, Vector2(500, 0)) ## uzakta -> sayılmaz
	_remote(5, Vector2(20, 0), false, true) ## yerde yatan -> kurtaramaz
	_remote(6, Vector2(10, 0), true) ## ölü -> kurtaramaz
	_local(Vector2(80, 0)) ## host'un kendi oyuncusu menzilde -> sayılır
	assert(GameManager.revive_assist_count(2) == 2, "menzildeki hayatta 2 arkadaş (uzak, yerde yatan ve ölü sayılmaz): %d" % GameManager.revive_assist_count(2))
	assert(corpse.global_position == Vector2.ZERO, "test kurulumu")
	assert(GameManager.revive_assist_count(3) == 0, "yaşayan oyuncuda (ceset değil) hız artışı yok")
	assert(GameManager.revive_assist_count(99) == 0, "bilinmeyen peer: 0")
	## Yerde yatan (hak 0 ile) oyuncu da ceset gibi sayılır
	_remote(7, Vector2(1000, 0), false, true)
	_remote(8, Vector2(1040, 0))
	assert(GameManager.revive_assist_count(7) == 1, "yerde yatanın yanındaki arkadaş sayılır: %d" % GameManager.revive_assist_count(7))
	_end()


func test_host_countdown_runs_faster_with_friends_waiting_and_slows_when_they_leave() -> void:
	_begin()
	_host_session([1, 2, 3, 4])
	GameManager.peer_revives = {1: 3, 2: 0, 3: 3, 4: 3}
	_remote(2, Vector2.ZERO, true)
	var friend_a := _remote(3, Vector2(40, 0))
	_remote(4, Vector2(-40, 0))
	GameManager._process_revive_regen(1.0)
	var left: float = float(GameManager._revive_regen_left[2])
	assert(is_equal_approx(left, GameManager.REVIVE_REGEN_INTERVAL - 2.6), "2 arkadaş yanında: 1 sn'de 2,6 sn düşer, kalan %s" % left)
	assert(is_equal_approx(float(GameManager._revive_regen_rate[2]), 2.6), "hız kaydı 2,6")
	## Bir arkadaş uzaklaşır: bir sonraki sayımda (0,25 sn) hız 1,8'e düşer
	friend_a.global_position = Vector2(900, 0)
	GameManager._process_revive_regen(0.3) ## sayım yenilenir, bu karede eski sayıyla akar
	GameManager._process_revive_regen(1.0)
	assert(is_equal_approx(float(GameManager._revive_regen_rate[2]), 1.8), "arkadaş gidince hız 1,8x: %s" % GameManager._revive_regen_rate[2])
	_end()


func test_no_boost_for_a_living_player_or_without_friends() -> void:
	_begin()
	_host_session([1, 2, 3])
	GameManager.peer_revives = {1: 3, 2: 0, 3: 3}
	var target := _remote(2, Vector2.ZERO, false) ## hakkı 0 ama HÂLÂ YAŞIYOR
	_remote(3, Vector2(30, 0))
	GameManager._process_revive_regen(1.0)
	assert(is_equal_approx(float(GameManager._revive_regen_left[2]), GameManager.REVIVE_REGEN_INTERVAL - 1.0), "yaşayan oyuncunun sayacı normal hızda akar")
	target.is_dead = true ## öldü: artık yanındaki arkadaş hızlandırır
	GameManager._revive_assist_timer = 0.0
	GameManager._process_revive_regen(1.0)
	assert(is_equal_approx(float(GameManager._revive_regen_rate[2]), 1.8), "öldükten sonra yanındaki arkadaşla 1,8x")
	## Kimse yanında değilken (ölü, yalnız) normal hız
	GameManager._revive_regen_left = {}
	GameManager.peer_revives = {1: 3, 2: 0, 3: 3}
	for n in _nodes:
		if n is FakePlayer and (n as FakePlayer).peer_id == 3:
			(n as FakePlayer).global_position = Vector2(2000, 0)
	GameManager._revive_assist_timer = 0.0
	GameManager._process_revive_regen(1.0)
	assert(is_equal_approx(float(GameManager._revive_regen_rate[2]), 1.0), "yanında kimse yokken normal hız")
	_end()


func test_a_player_with_lives_has_no_timer_and_completion_grants_one_life() -> void:
	_begin()
	_host_session([1, 2, 3, 4, 5])
	GameManager.peer_revives = {1: 3, 2: 0, 3: 3, 4: 3, 5: 3}
	_remote(2, Vector2.ZERO, true)
	_remote(3, Vector2(10, 0))
	_remote(4, Vector2(-10, 0))
	_remote(5, Vector2(0, 10))
	GameManager._revive_regen_left[2] = 1.0
	GameManager._process_revive_regen(0.3) ## 3 arkadaş: hız 3,4 -> 1,02 sn düşer -> süre bitti
	assert(GameManager.get_peer_revives(2) == 1, "süre dolunca TAM 1 can verilir: %d" % GameManager.get_peer_revives(2))
	assert(not GameManager._revive_regen_left.has(2) and not GameManager._revive_regen_rate.has(2), "sayaç ve hız kaydı temizlenir")
	## Hakkı olanın sayacı yok
	GameManager._process_revive_regen(1.0)
	assert(not GameManager._revive_regen_left.has(2), "hakkı olan oyuncuda sayaç işlemez")
	_end()


func test_client_mirror_counts_down_at_the_rate_the_host_reports() -> void:
	_begin()
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = false
	GameManager.apply_revive_regen_sync(2, 120.0, 2.6)
	GameManager._process_revive_regen(1.0)
	assert(is_equal_approx(float(GameManager._revive_regen_left[2]), 117.4), "istemci ayna hızı 2,6x ile düşer: %s" % GameManager._revive_regen_left[2])
	GameManager.apply_revive_regen_sync(2, 100.0) ## hız verilmezse 1,0
	GameManager._process_revive_regen(1.0)
	assert(is_equal_approx(float(GameManager._revive_regen_left[2]), 99.0), "hızsız eşitleme normal hız")
	GameManager.apply_revive_regen_sync(2, -1.0)
	assert(not GameManager._revive_regen_left.has(2) and not GameManager._revive_regen_rate.has(2), "iptal hepsini siler")
	_end()
