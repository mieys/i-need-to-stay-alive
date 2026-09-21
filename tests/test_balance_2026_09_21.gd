extends Node

## Kullanıcı isteklerinin (2026-09-21) sayısal kısımları:
##  - can emme alan hasarı vuran skill/silahlarda sadece %33 geçerli (GameManager.LIFESTEAL_EFFECTIVENESS)
##  - yemek canı: 1. kademe %8, 2. %16, 3. %24, 4. %32, 5. %40 (yiyenin MAKS canı üzerinden)
##  - şans göstergesi: puan olarak (x100 değil)

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const FoodScene: PackedScene = preload("res://scenes/food_drop.tscn")
const StatsPanel: GDScript = preload("res://scripts/stats_panel.gd")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 2 ## Oakley (Vampir DEĞİL - genel can emme yolu)
	GameManager.selected_character = 2
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	player.item_shield_hp = 0.0
	player.item_shield_max = 0.0
	return player


func _cleanup() -> void:
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


func test_lifesteal_area_hits_use_one_third_chance() -> void:
	var p: Node = _make_player()
	p.max_health = 1000000.0
	p.lifesteal_percent = 0.5
	var trials: int = 6000
	p.health = 10.0
	for i in range(trials):
		p.on_dealer_hit(50.0, false)
	var single_heals: float = p.health - 10.0
	p.health = 10.0
	for i in range(trials):
		p.on_dealer_hit(50.0, true)
	var area_heals: float = p.health - 10.0
	## beklenen: tek hedef 0.5*6000 = 3000, alan 0.5*0.33*6000 = 990 (istatistiksel, geniş aralık)
	assert(single_heals > 2700.0 and single_heals < 3300.0, "tek hedef can emme: %s" % single_heals)
	assert(area_heals > 800.0 and area_heals < 1200.0, "alan can emme %%33 olmali: %s" % area_heals)
	assert(area_heals < single_heals * 0.45, "alan, tek hedefin ~1/3'u olmali")
	_cleanup()


func test_lifesteal_default_arg_is_single_target() -> void:
	var p: Node = _make_player()
	p.max_health = 1000000.0
	p.lifesteal_percent = 1.0
	p.health = 10.0
	for i in range(200):
		p.on_damage_dealt(20.0)
	assert(p.health - 10.0 == 200.0, "%%100 can emme, tek hedef: her vurus 1 can")
	_cleanup()


func test_food_heal_percent_by_tier() -> void:
	var expected := {1: 0.08, 2: 0.16, 3: 0.24, 4: 0.32, 5: 0.40}
	for tier in expected:
		var food: Area2D = FoodScene.instantiate()
		add_child(food)
		food.tier = tier
		assert(is_equal_approx(food.get_heal_percent(), expected[tier]), "kademe %d yuzdesi" % tier)
		assert(is_equal_approx(food.get_heal_amount(200.0), expected[tier] * 200.0), "kademe %d miktari 200 can uzerinden" % tier)
		food.free()


func test_food_heals_percent_of_eater_max_health() -> void:
	var p: Node = _make_player()
	p.max_health = 250.0
	p.health = 50.0
	p.add_to_group("player")
	var food: Area2D = FoodScene.instantiate()
	add_child(food)
	food.tier = 4 ## %32 -> 80 can
	food._on_body_entered(p)
	assert(is_equal_approx(p.health, 130.0), "50 + %%32*250 = 130, bulunan: %s" % p.health)
	_cleanup()


func test_luck_display_is_points_not_times_100() -> void:
	assert(StatsPanel.format_luck(0.0) == "0")
	assert(StatsPanel.format_luck(15.0) == "15", "15 puan '15' gorunmeli (eskiden %1500)")
	assert(StatsPanel.format_luck(1.5) == "1.5")
	assert(StatsPanel.format_luck(2.0) == "2")
