extends Node

## Madde 292: Melek Q/E kendine giden pay. Bir dosta GERÇEKTEN can/kalkan gidiyorsa Melek kendi payının %50'sini alır;
## kimseye gitmiyorsa (menzilde dost yok / dostun canı ya da kalkanı dolu) %100'ünü alır. Dostun aldığı miktar değişmez.

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
	GameManager.selected_character = 1 ## Q yetenek kimliği: Can Basma (tik bunu okur)
	NetworkManager.is_multiplayer_active = false
	var player: Node2D = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.global_position = Vector2(100.0, 100.0)
	player.max_health = 200.0
	player.health = 50.0
	player.damage_bonus = 0.0 ## tik miktarı sadece max_health yüzdesi olsun
	player.crit_chance_bonus = -10.0 ## kritik zarı hiç tutmasın (sınır 0)
	return player


func _ally(peer: int, hp: float, shield: float = -1.0) -> Node2D:
	var rp: Node2D = RemotePlayerScene.instantiate()
	add_child(rp)
	_spawned.append(rp)
	rp.setup(peer, 7, "P%d" % peer)
	rp.global_position = Vector2(180.0, 100.0)
	rp.set("max_health", 100.0)
	rp.set("health", hp)
	if shield >= 0.0:
		rp.set("item_shield_max", 100.0)
		rp.set("item_shield_hp", shield)
	return rp


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func test_helper_only_halves_for_melek_with_a_receiving_ally() -> void:
	var player := _melek()
	assert(is_equal_approx(player._melek_self_amount_mult(true), 0.5), "dosta gidiyorsa Melek %50")
	assert(is_equal_approx(player._melek_self_amount_mult(false), 1.0), "kimseye gitmiyorsa Melek %100")
	GameManager.selected_char_id = 2 ## Oakley hiç etkilenmez
	assert(is_equal_approx(player._melek_self_amount_mult(true), 1.0), "Melek dışı hep %100")
	_cleanup()


func test_q_instant_alone_is_full_and_with_hurt_ally_is_half() -> void:
	var player := _melek()
	player._skill_heal() ## yakında dost yok
	assert(is_equal_approx(player.health, 50.0 + 200.0 * 0.15), "yalnız Q: kendine %100 (%15 max can)")
	player._end_skill_effects()
	player.health = 50.0
	var ally := _ally(88, 20.0)
	player._skill_heal()
	assert(is_equal_approx(player.health, 50.0 + 200.0 * 0.15 * 0.5), "canı eksik dost varken kendine %50")
	assert(is_equal_approx(float(ally.get("health")), 20.0 + 100.0 * 0.15), "dostun payı değişmez (%15 max can)")
	player._end_skill_effects()
	_cleanup()


func test_q_instant_ally_at_full_health_gives_melek_full_share() -> void:
	var player := _melek()
	var ally := _ally(88, 100.0) ## canı dolu: kimseye can gitmiyor
	player._skill_heal()
	assert(is_equal_approx(player.health, 50.0 + 200.0 * 0.15), "dostun canı doluysa Melek %100 alır")
	player._end_skill_effects()
	_cleanup()


func test_q_tick_follows_whether_the_ally_is_actually_healed() -> void:
	var player := _melek()
	## yalnız: tik = %1 max can = 2.0
	player.skill_state = "active"
	player._oakley_q_ally_target = null
	player._oakley_q_tick_timer = 0.0
	player.health = 50.0
	player._process_healer_heal_tick(1.01)
	assert(is_equal_approx(player.health, 52.0), "yalnız Q tiki: %100 (beklenen 52, gelen " + str(player.health))
	## canı eksik dost bağlı: tik yarıya iner (1.0)
	var ally := _ally(88, 20.0)
	player._oakley_q_ally_target = ally
	player._oakley_q_tick_timer = 0.0
	player.health = 50.0
	player._process_healer_heal_tick(1.01)
	assert(is_equal_approx(player.health, 51.0), "dosta can giderken Q tiki %50 (beklenen 51, gelen " + str(player.health))
	assert(float(ally.get("health")) > 20.0, "dost tikte can almalı")
	## dost iyileşip dolunca Melek tekrar %100 alır
	ally.set("health", 100.0)
	player._oakley_q_tick_timer = 0.0
	player.health = 50.0
	player._process_healer_heal_tick(1.01)
	assert(is_equal_approx(player.health, 52.0), "dost dolunca Q tiki yeniden %100 (beklenen 52, gelen " + str(player.health))
	player._end_skill_effects()
	_cleanup()


func test_e_tick_follows_whether_the_ally_is_actually_shielded() -> void:
	var player := _melek()
	player.item_shield_max = 100.0
	player.item_shield_hp = 0.0
	## yalnız: tik = %1 max kalkan = 1.0
	player._oakley_e_ally_target = null
	player._oakley_e_tick_timer = 0.0
	player._shield_regen_tick_pending = 0.0
	player._process_healer_shield_tick(0.1)
	assert(is_equal_approx(player._shield_regen_tick_pending, 1.0), "yalnız E: %100 (beklenen 1, gelen " + str(player._shield_regen_tick_pending))
	## kalkanı eksik dost: yarı (0.5)
	var ally := _ally(88, 100.0, 10.0)
	player._oakley_e_ally_target = ally
	player._oakley_e_tick_timer = 0.0
	player._shield_regen_tick_pending = 0.0
	player._process_healer_shield_tick(0.1)
	assert(is_equal_approx(player._shield_regen_tick_pending, 0.5), "dosta kalkan giderken E %50 (beklenen 0.5, gelen " + str(player._shield_regen_tick_pending))
	## dostun kalkanı dolu: Melek %100
	ally.set("item_shield_hp", 100.0)
	player._oakley_e_tick_timer = 0.0
	player._shield_regen_tick_pending = 0.0
	player._process_healer_shield_tick(0.1)
	assert(is_equal_approx(player._shield_regen_tick_pending, 1.0), "dostun kalkanı doluysa E %100 (beklenen 1, gelen " + str(player._shield_regen_tick_pending))
	_cleanup()
