extends Node

## Melek (Q Can Basma, E Kalkan Yenileme, pasif, R Kutsal Korku) ölü ya da yerde yatan dosta can/kalkan basmaz.
## Kukla yere düşünce is_dead false, is_downed true gelir (main.gd send_dead); kalıcı ölüde is_dead true.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const RemotePlayerScene: PackedScene = preload("res://scenes/remote_player.tscn")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _ensure_scene() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self


func _melek() -> Node2D:
	_ensure_scene()
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 10
	GameManager.selected_character = 1
	NetworkManager.is_multiplayer_active = false
	var player: Node2D = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(100.0, 100.0)
	player.max_health = 200.0
	player.health = 50.0
	player.item_shield_max = 100.0
	player.item_shield_hp = 0.0
	player.damage_bonus = 100.0
	player.crit_chance_bonus = -10.0
	return player


## down: "downed" (is_downed true, is_dead false - kuklada böyle gelir) ya da "dead" (kalıcı ölü, is_dead true).
func _ally(peer: int, down: String) -> Node2D:
	var rp: Node2D = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(peer, 7, "P%d" % peer)
	rp.global_position = Vector2(150.0, 100.0)
	rp.set("max_health", 100.0)
	rp.set("health", 20.0)
	rp.set("item_shield_max", 100.0)
	rp.set("item_shield_hp", 10.0)
	rp.set("is_downed", down == "downed")
	rp.set("is_dead", down == "dead")
	return rp


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _assert_untouched(ally: Node2D, what: String) -> void:
	assert(is_equal_approx(float(ally.get("health")), 20.0), what + ": ölü/yerdeki dosta CAN basıldı (" + str(ally.get("health")) + ")")
	assert(is_equal_approx(float(ally.get("item_shield_hp")), 10.0), what + ": ölü/yerdeki dosta KALKAN basıldı (" + str(ally.get("item_shield_hp")) + ")")


func test_q_never_targets_or_heals_a_down_ally() -> void:
	for state in ["downed", "dead"]:
		var player := _melek()
		var ally := _ally(88, state)
		player._skill_heal()
		assert(player._oakley_q_ally_target == null, state + ": Q ölü dostu hedef seçti")
		_assert_untouched(ally, state + " Q anlık")
		## Hedef sonradan düştü: bağ kurulmuşken dost yere düşerse tik can basmaz.
		var alive := _ally(89, "")
		alive.set("is_downed", false)
		alive.set("is_dead", false)
		player._oakley_q_ally_target = alive
		alive.set("is_downed", state == "downed")
		alive.set("is_dead", state == "dead")
		player._oakley_q_tick_timer = 0.0
		player._process_healer_heal_tick(1.01)
		_assert_untouched(alive, state + " Q tik (bağ kurulduktan sonra düştü)")
		player._end_skill_effects()
		_cleanup()


func test_e_never_targets_or_shields_a_down_ally() -> void:
	for state in ["downed", "dead"]:
		var player := _melek()
		var ally := _ally(88, state)
		player._skill_kalkan_yenileme()
		assert(player._oakley_e_ally_target == null, state + ": E ölü dostu hedef seçti")
		_assert_untouched(ally, state + " E")
		var alive := _ally(89, "")
		alive.set("is_downed", false)
		alive.set("is_dead", false)
		player._oakley_e_ally_target = alive
		alive.set("is_downed", state == "downed")
		alive.set("is_dead", state == "dead")
		player._oakley_e_tick_timer = 0.0
		player._process_healer_shield_tick(0.1)
		_assert_untouched(alive, state + " E tik (bağ kurulduktan sonra düştü)")
		player._end_skill_effects()
		_cleanup()


func test_passive_and_ult_skip_a_down_ally() -> void:
	for state in ["downed", "dead"]:
		var player := _melek()
		var ally := _ally(88, state)
		player._passive_melek(10.0)
		_assert_untouched(ally, state + " pasif")
		player._skill_melek_fear()
		_assert_untouched(ally, state + " R")
		_cleanup()


func test_puppet_ignores_direct_heal_while_downed() -> void:
	_ensure_scene()
	for state in ["downed", "dead"]:
		var ally := _ally(88, state)
		ally.heal(30.0)
		ally.heal_shield(30.0)
		ally.show_support_number(30.0, false)
		ally.show_support_number(30.0, true)
		_assert_untouched(ally, state + " kukla doğrudan heal")
	var alive := _ally(89, "")
	alive.heal(30.0)
	assert(is_equal_approx(float(alive.get("health")), 50.0), "yaşayan kukla can almalı")
	_cleanup()


func test_a_living_ally_is_still_healed() -> void:
	var player := _melek()
	var ally := _ally(88, "")
	player._skill_heal()
	assert(float(ally.get("health")) > 20.0, "yaşayan dosta Q can basmalı")
	player._end_skill_effects()
	_cleanup()
