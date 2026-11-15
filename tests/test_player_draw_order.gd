extends Node

## Oyuncular arası çizim sırası (2026-11-14, kullanıcı: "ana oyuncu üstteyken normal ama diğer oyuncu üstteyken onun üstünde görünüyor"): uzak oyuncu kuklası remote_player.tscn'de "player_ally"
## grubunda; main.gd yaratık geçişi (C++ draw_order / eski move_child yolu) kuklayı yaratıklarla birlikte sıralayıp çizim indeksini yaratık indekslerine atıyordu, yerel Player gruplarda
## olmadığı için kukla Y'den bağımsız HEP yerel oyuncunun üstüne çiziliyordu. Oyuncular yalnız _update_character_draw_order ile (ayak hizasına göre) sıralanmalı.

const MainScript: GDScript = preload("res://scripts/main.gd")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")

var _m: Node2D


func _new_main() -> Node2D:
	_m = MainScript.new() as Node2D
	return _m


func _local_stub() -> Node2D:
	## Yerel Player'ın görsel yapısı (kök + "AnimatedSprite2D" çocuğu); sahnenin kendisi bu testte gereksiz ağır.
	var p := Node2D.new()
	p.add_child(AnimatedSprite2D.new())
	return p


func _free_main() -> void:
	if _m != null:
		_m.free()
		_m = null


func test_remote_puppet_is_in_a_creature_group_but_excluded_from_the_creature_pass() -> void:
	var m := _new_main()
	var rp: Node2D = RemotePlayerScene.instantiate() as Node2D
	assert(rp.is_in_group("player_ally"), "kukla hâlâ player_ally grubunda (destek yetenekleri tarıyor) - bu yüzden yaratık geçişi onu süzmeli")
	assert(m._is_player_puppet(rp), "kukla yaratık geçişinden çıkarılır")
	var enemy := Node2D.new()
	enemy.add_to_group("enemies")
	assert(not m._is_player_puppet(enemy), "yaratık yaratık geçişinde kalır")
	var pet := Node2D.new()
	pet.add_to_group("player_ally")
	assert(not m._is_player_puppet(pet), "evcil/müttefik yaratık geçişinde kalır")
	enemy.free()
	pet.free()
	rp.free()
	_free_main()


## Taze bir Main (ağaçta DEĞİL - _ready ağır) + yerel + kukla kurar, sırayı bir kez uygular; kukla yerelin ÖNÜNDE (ağaçta sonra) mi döner.
## Ağaç dışında global dönüşüm önbelleği konum değişince tazelenmez, bu yüzden her senaryo sıfırdan kurulur.
func _remote_in_front(local_y: float, remote_y: float, remote_added_first: bool) -> bool:
	var m := _new_main()
	var local := _local_stub()
	var rp: Node2D = RemotePlayerScene.instantiate() as Node2D
	local.position = Vector2(0, local_y)
	rp.position = Vector2(0, remote_y)
	if remote_added_first:
		m.add_child(rp)
		m.add_child(local)
	else:
		m.add_child(local)
		m.add_child(rp)
	m.player = local
	m._remote_players[7] = rp
	m._update_character_draw_order()
	var front: bool = rp.get_index() > local.get_index()
	_free_main()
	return front


func test_player_below_the_remote_is_drawn_after_it_and_vice_versa() -> void:
	## Kukla YUKARIDA (küçük y): yerel oyuncunun ARKASINDA; AŞAĞIDA: ÖNÜNDE - başlangıç ağaç sırası ne olursa olsun (ana hata: kukla hep önde).
	for rp_first in [false, true]:
		assert(not _remote_in_front(100.0, 0.0, rp_first), "kukla üstteyken yerelin arkasında (kukla önce eklendi=%s)" % rp_first)
		assert(_remote_in_front(0.0, 100.0, rp_first), "kukla altta iken yerelin önünde (kukla önce eklendi=%s)" % rp_first)
		assert(not _remote_in_front(100.0, -50.0, rp_first), "kukla çok üstteyken yine arkada (kukla önce eklendi=%s)" % rp_first)
