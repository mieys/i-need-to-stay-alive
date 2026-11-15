extends Node

## İyileştirme ve Kalkan Gücü (heal_shield_power) "her türlü can/kalkan yenilenmesini" büyütür (stats_panel.gd açıklaması). Üç yol çarpanı
## atlıyordu (2026-11-11 denetimi): Melek'in Q/E KENDİ payı, Şovalye Q kalkan yenilenmesi, Oakley çiçeği (dosta giden kısım zaten çarpılıyordu).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const FlowerScript: GDScript = preload("res://scripts/oakley_flower.gd")

const POWER := 0.5 ## +%50 -> çarpan 1,5
const MELEK_ID := 10
const OTHER_ID := 1 ## Talon: Q/E "healer" yoluna (2/10) girmeyen herhangi bir karakter

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player(char_id: int) -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = char_id
	GameManager.selected_character = int(Characters.DEFS[char_id]["skill"])
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.global_position = Vector2(1000.0, 1000.0)
	player.crit_chance_bonus = -1.0 ## yetenek kritiği kapalı (ölçüm sabit kalsın)
	_spawned.append(player)
	return player


func _cleanup() -> void:
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func _ratio(boosted: float, base: float) -> float:
	return boosted / maxf(base, 0.0001)


func test_melek_q_self_heal_scales_with_heal_power() -> void:
	var p: Node = _make_player(MELEK_ID)
	p.max_health = 1000.0
	p.heal_shield_power = 0.0
	p.health = 1.0
	p._skill_heal()
	var base: float = p.health - 1.0
	p.heal_shield_power = POWER
	p.health = 1.0
	p._skill_heal()
	var boosted: float = p.health - 1.0
	assert(base > 1.0, "Melek Q kendine can basmalı (taban: %s)" % base)
	assert(is_equal_approx(_ratio(boosted, base), 1.0 + POWER), "Melek Q kendi canı x1,5 olmalı: %s / %s" % [boosted, base])
	_cleanup()


func test_melek_q_self_tick_scales_with_heal_power() -> void:
	var p: Node = _make_player(MELEK_ID)
	p.max_health = 1000.0
	assert(p.get_skill_character_id() == 1, "Melek Q 'heal' yolu (skill id 1) olmalı: %s" % p.get_skill_character_id())
	p.skill_state = "active"
	p.heal_shield_power = 0.0
	p.health = 1.0
	p._oakley_q_tick_timer = 0.0
	p._process_healer_heal_tick(0.0)
	var base: float = p.health - 1.0
	p.heal_shield_power = POWER
	p.health = 1.0
	p._oakley_q_tick_timer = 0.0
	p._process_healer_heal_tick(0.0)
	var boosted: float = p.health - 1.0
	assert(base > 0.0, "Melek Q tiki kendine can basmalı (taban: %s)" % base)
	assert(is_equal_approx(_ratio(boosted, base), 1.0 + POWER), "Melek Q tik canı x1,5 olmalı: %s / %s" % [boosted, base])
	_cleanup()


func test_melek_e_self_shield_tick_scales_with_heal_power() -> void:
	var p: Node = _make_player(MELEK_ID)
	p.item_shield_max = 1000.0
	p.item_shield_hp = 0.0
	p._oakley_e_ally_target = null
	p.heal_shield_power = 0.0
	p._shield_regen_tick_pending = 0.0
	p._oakley_e_tick_timer = 0.0
	p._process_healer_shield_tick(0.0)
	var base: float = p._shield_regen_tick_pending
	p.heal_shield_power = POWER
	p._shield_regen_tick_pending = 0.0
	p._oakley_e_tick_timer = 0.0
	p._process_healer_shield_tick(0.0)
	var boosted: float = p._shield_regen_tick_pending
	assert(base > 0.0, "Melek E tiki kendine kalkan basmalı (taban: %s)" % base)
	assert(is_equal_approx(_ratio(boosted, base), 1.0 + POWER), "Melek E kendi kalkanı x1,5 olmalı: %s / %s" % [boosted, base])
	_cleanup()


func test_sovalye_q_shield_regen_scales_with_heal_power() -> void:
	var p: Node = _make_player(OTHER_ID)
	p.item_shield_max = 1000.0
	p.item_shield_hp = 0.0
	p.is_kalkan_yenileme_active = true
	p.item_shield_ability_slow_timer = 0.0
	p.heal_shield_power = 0.0
	p._shield_regen_tick_pending = 0.0
	p._process_kalkan_yenileme(1.0)
	var base: float = p._shield_regen_tick_pending
	p.heal_shield_power = POWER
	p._shield_regen_tick_pending = 0.0
	p.item_shield_hp = 0.0
	p._process_kalkan_yenileme(1.0)
	var boosted: float = p._shield_regen_tick_pending
	assert(base > 0.0, "Şovalye Q kalkan yenilemeli (taban: %s)" % base)
	assert(is_equal_approx(_ratio(boosted, base), 1.0 + POWER), "Şovalye Q kalkan yenilenmesi x1,5 olmalı: %s / %s" % [boosted, base])
	_cleanup()


func test_oakley_flower_uses_caster_heal_mult() -> void:
	var p: Node = _make_player(2)
	p.item_shield_max = 1000.0
	var plain: Node2D = Node2D.new()
	plain.set_script(FlowerScript)
	plain.call("setup", 100.0, "t_1")
	var boosted: Node2D = Node2D.new()
	boosted.set_script(FlowerScript)
	boosted.call("setup", 100.0, "t_2", 1.0 + POWER)
	var heal_plain: float = float(plain.call("_current_heal_amount"))
	var heal_boosted: float = float(boosted.call("_current_heal_amount"))
	assert(heal_plain > 0.0, "çiçek can basmalı")
	assert(is_equal_approx(_ratio(heal_boosted, heal_plain), 1.0 + POWER), "çiçek canı x1,5 olmalı: %s / %s" % [heal_boosted, heal_plain])
	var shield_plain: float = float(plain.call("_current_shield_amount", p))
	var shield_boosted: float = float(boosted.call("_current_shield_amount", p))
	assert(shield_plain > 0.0, "çiçek kalkan basmalı")
	assert(is_equal_approx(_ratio(shield_boosted, shield_plain), 1.0 + POWER), "çiçek kalkanı x1,5 olmalı: %s / %s" % [shield_boosted, shield_plain])
	plain.free()
	boosted.free()
	_cleanup()


## Çiçek çarpanı ağdan da gitmeli (her istemcide ayrı kopya var, alan kim olursa olsun veren gücüyle aynı).
func test_flower_spawn_broadcast_carries_heal_mult() -> void:
	var player_src: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	assert(player_src.contains("\"caster_heal_mult\": heal_power_mult()"), "player.gd çiçek yayınına caster_heal_mult koymalı")
	var net_src: String = FileAccess.get_file_as_string("res://scripts/network_manager.gd")
	assert(net_src.contains("extra_data.get(\"caster_heal_mult\", 1.0)"), "network_manager.gd çiçek kopyasına caster_heal_mult vermeli")
