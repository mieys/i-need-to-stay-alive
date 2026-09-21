extends Node

## Kullanıcı bildirimi: "Oyuncular öldükten sonra diğerleri onu diriltmediğinde 1 dakika sonra falan
## kalıcı olarak ölüyor ve diriltilemeyip izleyiciye atılıyor, böyle olmaması lazım."
## Kural: yerde yatan oyuncu SÜRE SINIRI olmadan diriltilmeyi bekler; kalıcı ölüm sadece
## diriltebilecek hayatta (yerde olmayan) hiçbir müttefik kalmadığında olur (yoksa herkes yerdeyken
## oyun hiç bitmezdi). Tek oyunculuda 3sn'lik otomatik dirilme aynen kalır.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _spawned: Array[Node] = []
var _died_count: int = 0


func _on_died() -> void:
	_died_count += 1


## enemy.gd/player.gd'nin "remote_players" grubundan okuduğu alanlar.
class FakeTeammate extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false


func _make_downed_player() -> Node:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	_died_count = 0
	player.died.connect(_on_died)
	player._go_down()
	return player


func _make_teammate(dead: bool, downed: bool) -> FakeTeammate:
	var t := FakeTeammate.new()
	t.is_dead = dead
	t.is_downed = downed
	t.add_to_group("remote_players")
	add_child(t)
	t.global_position = Vector2(5000.0, 5000.0) ## kurtarma menzilinin çok dışında
	_spawned.append(t)
	return t


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func test_downed_player_waits_forever_while_a_teammate_is_alive() -> void:
	var player: Node = _make_downed_player()
	_make_teammate(false, false) ## hayatta ama yakında değil (diriltmiyor)
	NetworkManager.is_multiplayer_active = true
	for i in range(150): ## 150sn - eski 30sn'lik kanama süresinin 5 katı
		player._process_downed(1.0)
	assert(player.is_downed, "Hayatta müttefik varken yerdeki oyuncu süre dolunca kalıcı ölmemeli")
	assert(player.is_dead and _died_count == 0, "died (kalıcı ölüm) sinyali hiç yayılmamalı, sayı: %d" % _died_count)
	assert(is_equal_approx(player.get_downed_remaining_seconds(), 0.0), "Süre sınırı olmadığı için geri sayım görünmemeli")
	_cleanup()


func test_downed_player_is_finalized_when_no_living_teammate_remains() -> void:
	var player: Node = _make_downed_player()
	_make_teammate(false, true) ## diğer oyuncu da yerde -> diriltebilecek kimse yok
	NetworkManager.is_multiplayer_active = true
	for i in range(5):
		player._process_downed(1.0)
	assert(player.is_downed and _died_count == 0, "Pay süresi dolmadan kalıcı ölüm olmamalı")
	assert(absf(player.get_downed_remaining_seconds() - (player.DOWNED_NO_RESCUER_GRACE - 5.0)) < 0.01,
		"Pay süresince kalan saniye gösterilmeli, bulunan: %s" % player.get_downed_remaining_seconds())
	for i in range(6):
		player._process_downed(1.0)
	assert(not player.is_downed and player.is_dead and _died_count == 1,
		"Herkes yerdeyse pay süresi sonunda kalıcı ölüm (oyun sonu) olmalı, died sayısı: %d" % _died_count)
	_cleanup()


func test_grace_resets_when_a_living_teammate_shows_up() -> void:
	var player: Node = _make_downed_player()
	var mate: FakeTeammate = _make_teammate(false, true)
	NetworkManager.is_multiplayer_active = true
	for i in range(8):
		player._process_downed(1.0)
	mate.is_downed = false ## müttefik diriltildi/döndü
	player._process_downed(1.0)
	assert(is_equal_approx(player.get_downed_remaining_seconds(), 0.0), "Müttefik dönünce geri sayım kaybolmalı")
	mate.is_downed = true
	for i in range(8):
		player._process_downed(1.0)
	assert(player.is_downed and _died_count == 0, "Pay süresi baştan sayılmalı (8sn < 10sn), kalıcı ölüm olmamalı")
	_cleanup()


func test_permanently_dead_teammate_does_not_count_as_a_rescuer() -> void:
	var player: Node = _make_downed_player()
	_make_teammate(true, false) ## izleyici modunda (kalıcı ölü)
	NetworkManager.is_multiplayer_active = true
	for i in range(12):
		player._process_downed(1.0)
	assert(not player.is_downed and _died_count == 1, "Sadece kalıcı ölü müttefik kaldıysa oyuncu da kalıcı ölmeli")
	_cleanup()


func test_singleplayer_still_auto_revives_after_three_seconds() -> void:
	var player: Node = _make_downed_player()
	NetworkManager.is_multiplayer_active = false
	for i in range(40):
		player._process_downed(0.1)
	assert(not player.is_downed and not player.is_dead, "Tek oyunculuda 3sn sonra otomatik dirilmeli (eski davranış)")
	assert(_died_count == 0, "Dirilen oyuncu için died yayılmamalı")
	_cleanup()
