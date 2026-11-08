extends Node

## Madde 422: die() host'tan diriltme hakkı yanıtını beklerken (istemcide bir RTT) yeniden girmemeli. 4 kişilik Epic oyununda 150 ms gecikmeli
## Elara'da 0,1 sn arayla iki düşme kaydı vardı: ikinci ölümcül darbe die()'ı yeniden çağırıp ayrı bir diriltme hakkı harcıyordu.
## Gerçek ağ gecikmesi burada kurulamaz; koruma bayrağını (_die_pending) doğrudan kurup die()'ın hiçbir şey yapmadığını doğrularız.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")

var _prev: Dictionary = {}


func _setup() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev = {
		"mp": NetworkManager.is_multiplayer_active, "revives": GameManager.revives_remaining, "game_over": GameManager.is_game_over,
	}
	NetworkManager.is_multiplayer_active = false
	GameManager.is_game_over = false
	GameManager.revives_remaining = 3
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	return player


func _cleanup(player: Node) -> void:
	if is_instance_valid(player):
		player.free()
	NetworkManager.is_multiplayer_active = _prev.get("mp", false)
	GameManager.revives_remaining = _prev.get("revives", 3)
	GameManager.is_game_over = _prev.get("game_over", false)


func test_die_is_ignored_while_a_revive_answer_is_pending() -> void:
	var player: Node = _setup()
	player.set("_die_pending", true)
	player.call("die")
	player.call("die")
	assert(not bool(player.get("is_downed")), "yanıt beklenirken die() yere düşürmemeli")
	assert(not bool(player.get("is_dead")), "yanıt beklenirken die() öldürmemeli")
	assert(GameManager.revives_remaining == 3, "yanıt beklenirken die() ek diriltme hakkı harcamamalı: %d" % GameManager.revives_remaining)
	_cleanup(player)


func test_die_goes_down_once_and_clears_the_pending_flag() -> void:
	var player: Node = _setup()
	player.call("die")
	assert(bool(player.get("is_downed")), "normal die() yere düşürmeli")
	assert(not bool(player.get("_die_pending")), "die() bitince bekleme bayrağı kapanmalı")
	assert(GameManager.revives_remaining == 2, "tek düşme tek hak harcar: %d" % GameManager.revives_remaining)
	player.call("die")
	player.call("die")
	assert(GameManager.revives_remaining == 2, "zaten yerdeyken die() tekrar hak harcamamalı: %d" % GameManager.revives_remaining)
	_cleanup(player)
