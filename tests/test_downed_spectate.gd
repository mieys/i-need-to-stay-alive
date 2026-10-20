extends Node

## Kullanıcı bildirimi: "yere düşen dostlar diğer oyuncuları izleyemiyor sadece ölünce izleyebiliyorlar."
## Kural: yerde yatan (is_downed) oyuncu da arkadaşlarını izleyebilir (downed_spectate.gd): sıra Kendin -> arkadaşlar -> Kendin,
## kamera izleme sürerken top_level olur, diriltilince cesedine kayıp eski yerine döner, arkadaş yoksa şerit çıkmaz.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const DownedSpectateScript: GDScript = preload("res://scripts/downed_spectate.gd")

var _spawned: Array[Node] = []


class FakeAlly extends Node2D:
	var is_dead: bool = false
	var is_downed: bool = false
	var player_name: String = "Ali"


func _make_downed_player() -> Node:
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	NetworkManager.is_multiplayer_active = true
	player._go_down()
	return player


func _make_ally(pos: Vector2, nm: String) -> FakeAlly:
	var a := FakeAlly.new()
	a.player_name = nm
	a.add_to_group("remote_players")
	add_child(a)
	a.global_position = pos
	_spawned.append(a)
	return a


func _make_spectate() -> CanvasLayer:
	var s: CanvasLayer = DownedSpectateScript.new()
	add_child(s)
	_spawned.append(s)
	return s


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func test_next_index_cycles_self_then_allies_then_self() -> void:
	var S := DownedSpectateScript
	assert(S.next_index(-1, 0, 1) == -1, "Arkadaş yokken hep kendin")
	assert(S.next_index(-1, 2, 1) == 0, "Kendin -> ilk arkadaş")
	assert(S.next_index(0, 2, 1) == 1, "ilk -> ikinci")
	assert(S.next_index(1, 2, 1) == -1, "son arkadaştan sonra tekrar kendin")
	assert(S.next_index(-1, 2, -1) == 1, "Kendin'den geri: son arkadaş")
	assert(S.next_index(0, 2, -1) == -1, "ilk arkadaştan geri: kendin")


func test_downed_player_can_spectate_an_ally() -> void:
	var player: Node = _make_downed_player()
	var ally: FakeAlly = _make_ally(Vector2(600.0, 0.0), "Ali")
	var spec: CanvasLayer = _make_spectate()
	var cam: Camera2D = player.death_camera
	spec.step(0.1)
	assert(spec._bar.visible, "Yerdeyken ve arkadaş varken izleme şeridi görünmeli")
	assert(not spec.is_following() and not cam.top_level, "Varsayılan: kendi cesedinde kalır")
	spec.cycle(1)
	assert(spec.is_following(), "Sonraki -> arkadaş izlenir")
	assert(spec._name_label.text == "Ali", "Şeritte arkadaşın adı yazmalı, bulunan: %s" % spec._name_label.text)
	for i in range(12): ## 12 x 0,1 sn x 900 px/sn = 1080 px > 600 px
		spec.step(0.1)
	assert(cam.top_level, "İzleme sürerken kamera Player'dan bağımsız (top_level) olmalı")
	assert(cam.global_position.distance_to(ally.global_position) < 1.0,
		"Kamera arkadaşın üstüne varmalı, uzaklık: %s" % cam.global_position.distance_to(ally.global_position))
	ally.global_position = Vector2(-300.0, 200.0)
	for i in range(12):
		spec.step(0.1)
	assert(cam.global_position.distance_to(ally.global_position) < 1.0, "Kamera hareket eden arkadaşı izlemeli")
	_cleanup()


func test_camera_returns_to_the_body_when_revived() -> void:
	var player: Node = _make_downed_player()
	_make_ally(Vector2(900.0, 0.0), "Ali")
	var spec: CanvasLayer = _make_spectate()
	var cam: Camera2D = player.death_camera
	spec.cycle(1)
	for i in range(15):
		spec.step(0.1)
	assert(cam.top_level and cam.global_position.x > 800.0, "Önce arkadaşın yanında olmalı")
	player.is_downed = false ## _complete_revive'ın yaptığı
	player.is_dead = false
	for i in range(20): ## 20 x 0,1 sn x 1800 px/sn = 3600 px
		spec.step(0.1)
	assert(not cam.top_level, "Dirilince kamera tekrar Player'a bağlanmalı")
	assert(cam.position.is_zero_approx(), "Kamera eski yerel konumuna (0,0) dönmeli, bulunan: %s" % cam.position)
	assert(not spec._bar.visible, "Dirilince şerit kalkmalı")
	assert(cam.get_parent() == player, "Kamera hâlâ Player'ın çocuğu")
	_cleanup()


func test_no_bar_without_allies_and_no_bar_when_alive() -> void:
	var player: Node = _make_downed_player()
	var spec: CanvasLayer = _make_spectate()
	spec.step(0.1)
	assert(not spec._bar.visible, "Hayatta arkadaş yoksa şerit çıkmamalı")
	spec.cycle(1)
	assert(not spec.is_following(), "Arkadaş yokken izleme başlamaz")
	_make_ally(Vector2(100.0, 0.0), "Ali")
	player.is_downed = false
	player.is_dead = false
	spec.step(0.1)
	assert(not spec._bar.visible, "Ayaktayken şerit çıkmamalı")
	_cleanup()


func test_target_leaving_moves_on_to_the_next_ally_then_self() -> void:
	var player: Node = _make_downed_player()
	var a1: FakeAlly = _make_ally(Vector2(300.0, 0.0), "Ali")
	var a2: FakeAlly = _make_ally(Vector2(-300.0, 0.0), "Veli")
	var spec: CanvasLayer = _make_spectate()
	spec.cycle(1)
	assert(spec._target == a1, "İlk arkadaş seçilmeli")
	a1.is_dead = true ## kalıcı öldü
	spec.step(0.1)
	assert(spec._target == a2, "İzlenen ölünce sıradaki arkadaşa geçmeli")
	a2.is_dead = true
	spec.step(0.1)
	assert(not spec.is_following() and not spec._bar.visible, "Kimse kalmayınca kendine dönmeli, şerit kalkmalı")
	assert(player.is_downed, "Oyuncu hâlâ yerde")
	_cleanup()


func test_final_death_leaves_the_camera_alone() -> void:
	var player: Node = _make_downed_player()
	_make_ally(Vector2(700.0, 0.0), "Ali")
	var spec: CanvasLayer = _make_spectate()
	var cam: Camera2D = player.death_camera
	spec.cycle(1)
	for i in range(10):
		spec.step(0.1)
	var held_at: Vector2 = cam.global_position
	player.is_downed = false ## _finalize_death: is_downed false, is_dead true
	player.is_dead = true
	spec.step(0.1)
	assert(cam.top_level and cam.global_position.is_equal_approx(held_at),
		"Kalıcı ölümde kamera olduğu yerde bırakılmalı (player.gd _detach_death_camera devralır)")
	assert(not spec._held, "Şerit kamerayı bırakmış sayılmalı")
	_cleanup()
