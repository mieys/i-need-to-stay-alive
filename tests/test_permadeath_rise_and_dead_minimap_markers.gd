extends Node

## 2026-10-07 kullanıcı bildirimleri:
##  1) "Revive hakkı biten oyuncunun revive hakkı yenileniyor fakat yenilendikten sonra ölen oyuncuyu kaldıramıyoruz" - kalıcı ölü
##     (is_dead, is_downed değil) oyuncu müttefik kurtarma kanalına giremiyordu. Artık diriltme hakkı varsa VE hayatta bir kurtarıcı
##     varsa hak harcanıp oyuncu "yerde yatan" (kurtarılabilir) duruma geçer (player.gd _rise_from_permadeath_to_downed).
##  2) "Ölen oyuncu haritada konumu gözüksün" - minimap ölü/yerde yatan oyuncuları artık atlamıyor, "dead" işaretiyle çiziyor.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _spawned: Array[Node] = []
var _prev: Dictionary = {}
var _rose_count: int = 0


## remote_player.gd'nin minimap/kurtarıcı aramasının okuduğu alanlar.
class FakeRemote extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var char_id: int = 1
	var peer_id: int = 2


func _setup() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev = {
		"mp": NetworkManager.is_multiplayer_active, "host": NetworkManager.is_host, "revives": GameManager.revives_remaining,
		"peer_revives": GameManager.peer_revives.duplicate(), "game_over": GameManager.is_game_over,
		"peer": get_tree().get_multiplayer().multiplayer_peer,
	}
	NetworkManager.is_multiplayer_active = false
	GameManager.is_game_over = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	return player


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	NetworkManager.is_multiplayer_active = _prev.get("mp", false)
	NetworkManager.is_host = _prev.get("host", false)
	GameManager.revives_remaining = _prev.get("revives", 3)
	GameManager.peer_revives = _prev.get("peer_revives", {})
	GameManager.is_game_over = _prev.get("game_over", false)
	get_tree().get_multiplayer().multiplayer_peer = _prev.get("peer", null)


func _remote(pos: Vector2, dead: bool, downed: bool) -> FakeRemote:
	var r := FakeRemote.new()
	r.add_to_group("remote_players")
	r.is_dead = dead
	r.is_downed = downed
	add_child(r)
	r.global_position = pos
	_spawned.append(r)
	return r


func _on_rose() -> void:
	_rose_count += 1


# ------------------------------------------------------------------ 1) kalıcı ölümden yerde yatan duruma dönüş

func test_permanently_dead_player_with_a_revive_becomes_rescuable() -> void:
	var player: Node = _setup()
	player._finalize_death()
	assert(player.is_dead and not player.is_downed, "test önkoşulu: kalıcı ölü")
	var col: CollisionShape2D = player.get_node_or_null("CollisionShape2D")
	GameManager.revives_remaining = 1 ## tek oyunculu yol: try_use_revive revives_remaining'i harcar (host/ağ yolu aynı fonksiyon)
	_rose_count = 0
	player.rose_from_permadeath.connect(_on_rose)
	await player._rise_from_permadeath_to_downed()
	assert(player.is_downed and player.is_dead, "hak varken yerde yatan (kurtarılabilir) duruma geçmeli")
	assert(GameManager.revives_remaining == 0, "diriltme hakkı harcanmalı: %d" % GameManager.revives_remaining)
	assert(_rose_count == 1, "rose_from_permadeath sinyali bir kez yayınlanmalı: %d" % _rose_count)
	if col:
		await get_tree().process_frame
		assert(not col.disabled, "ceset çarpışması geri açılmalı")
	_cleanup()


func test_without_a_revive_the_dead_player_stays_dead() -> void:
	var player: Node = _setup()
	player._finalize_death()
	GameManager.revives_remaining = 0
	_rose_count = 0
	player.rose_from_permadeath.connect(_on_rose)
	await player._rise_from_permadeath_to_downed()
	assert(player.is_dead and not player.is_downed, "hak yoksa kalıcı ölü kalmalı")
	assert(_rose_count == 0, "sinyal yayınlanmamalı")
	_cleanup()


## Poll yolu (gerçek oyundaki tetik): çok oyunculu + hak var + hayatta kurtarıcı var -> kalkar; kurtarıcı yoksa hak boşa gitmez.
func test_poll_requires_a_revive_and_a_living_rescuer() -> void:
	var player: Node = _setup()
	get_tree().get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = true
	var my_id: int = multiplayer.get_unique_id()
	player._finalize_death()
	GameManager.peer_revives = {my_id: 1}
	## Kurtarıcı yok (diğer oyuncu yok) -> hak harcanmaz.
	player._permadeath_rise_timer = 0.0
	player._process_permadeath_rise(1.0)
	await get_tree().process_frame
	assert(player.is_dead and not player.is_downed and GameManager.get_peer_revives(my_id) == 1, "kurtarıcı yokken hak harcanmamalı")
	## Yerde yatan ya da ölü bir müttefik kurtarıcı sayılmaz.
	var downed_ally: FakeRemote = _remote(Vector2(50, 0), false, true)
	var dead_ally: FakeRemote = _remote(Vector2(60, 0), true, false)
	player._permadeath_rise_timer = 0.0
	player._process_permadeath_rise(1.0)
	await get_tree().process_frame
	assert(player.is_dead and not player.is_downed, "yerdeki/ölü müttefik kurtarıcı değil")
	## Hayatta bir müttefik -> kalkar.
	downed_ally.is_downed = false
	player._permadeath_rise_timer = 0.0
	player._process_permadeath_rise(1.0)
	for _i in range(3):
		await get_tree().process_frame
	assert(player.is_downed, "hayatta müttefik + hak -> yerde yatan duruma geçmeli")
	assert(GameManager.get_peer_revives(my_id) == 0, "hak harcanmalı: %d" % GameManager.get_peer_revives(my_id))
	assert(dead_ally != null)
	_cleanup()


func test_poll_does_nothing_after_game_over_or_in_single_player() -> void:
	var player: Node = _setup()
	player._finalize_death()
	GameManager.revives_remaining = 1
	_remote(Vector2(40, 0), false, false)
	player._permadeath_rise_timer = 0.0
	player._process_permadeath_rise(1.0) ## tek oyunculu: çalışmaz
	await get_tree().process_frame
	assert(not player.is_downed and GameManager.revives_remaining == 1, "tek oyunculuda poll kalkış yapmamalı")
	get_tree().get_multiplayer().multiplayer_peer = OfflineMultiplayerPeer.new()
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = true
	GameManager.peer_revives = {multiplayer.get_unique_id(): 1}
	GameManager.is_game_over = true
	player._permadeath_rise_timer = 0.0
	player._process_permadeath_rise(1.0)
	await get_tree().process_frame
	assert(not player.is_downed, "oyun bittiyse kalkmamalı")
	_cleanup()


# ------------------------------------------------------------------ 2) minimapte ölü işareti

func test_minimap_marks_dead_and_downed_players_instead_of_hiding_them() -> void:
	var player: Node = _setup()
	var mm: Minimap = Minimap.new()
	add_child(mm)
	_spawned.append(mm)
	var alive: FakeRemote = _remote(Vector2(100, 0), false, false)
	var dead: FakeRemote = _remote(Vector2(200, 0), true, false)
	var downed: FakeRemote = _remote(Vector2(300, 0), false, true)
	NetworkManager.is_multiplayer_active = false
	mm._process(0.016)
	var dots: Array = mm._player_dots
	var dead_flags: Array = []
	for d in dots:
		dead_flags.append(bool(d.get("dead", false)))
	assert(dots.size() == 4, "yerel + 3 uzak oyuncu da çizilmeli (ölüler atlanmamalı): %d" % dots.size())
	assert(dead_flags.count(true) == 2 and dead_flags.count(false) == 2, "ölü + yerde yatan işaretli, 2 canlı normal: %s" % str(dead_flags))
	assert(dead_flags[0] and dead_flags[1] and not dead_flags[2] and not dead_flags[3], "ölüler önce (canlılar üstte çizilsin): %s" % str(dead_flags))
	## Yerel oyuncu ölünce kendi konumu da işaretlenir.
	player.is_dead = true
	mm._process(0.016)
	var local_dead: bool = false
	for d in mm._player_dots:
		if bool(d.get("is_local", false)):
			local_dead = bool(d.get("dead", false))
	assert(local_dead, "ölen yerel oyuncunun konumu da haritada ölü işaretiyle görünmeli")
	assert(alive != null and dead != null and downed != null)
	## Çizim hatasız çalışır (gerçek çizim aşamasında; script hatası runner'ın stderr taramasında yakalanır).
	mm.queue_redraw()
	for _i in range(3):
		await get_tree().process_frame
	_cleanup()
