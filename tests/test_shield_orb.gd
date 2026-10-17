extends Node

## Kalkan orbu (2026-10-14): yiyecek gibi yere düşen 2 toplanabilir - 1. orb azami kalkanın %15'ini, 2. orb %30'unu yeniler.

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const OrbScene: PackedScene = preload("res://scenes/shield_orb_drop.tscn")
const OrbScript: GDScript = preload("res://scripts/shield_orb_drop.gd")

var _spawned: Array[Node] = []
var _prev_char_id: int = 1
var _prev_character: int = 1


func _make_player() -> Node:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = 2
	GameManager.selected_character = 2
	NetworkManager.is_multiplayer_active = false
	var player: Node = PlayerScene.instantiate()
	add_child(player)
	_spawned.append(player)
	return player


func _cleanup() -> void:
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	for n: Node in get_tree().get_nodes_in_group("shield_orb_drops"):
		if is_instance_valid(n):
			n.free()


func _make_orb(tier: int) -> Area2D:
	var orb: Area2D = OrbScene.instantiate()
	orb.tier = tier
	add_child(orb)
	return orb


func test_percent_by_tier_and_icons() -> void:
	var expected := {1: 0.15, 2: 0.30}
	for tier in expected:
		var orb: Area2D = _make_orb(tier)
		assert(orb.is_in_group("shield_orb_drops"))
		assert(is_equal_approx(orb.get_shield_percent(), expected[tier]), "kademe %d yuzdesi" % tier)
		assert(is_equal_approx(orb.get_shield_amount(200.0), expected[tier] * 200.0))
		assert((orb.get_node("Sprite2D") as Sprite2D).texture != null, "kademe %d ikonu yuklenmeli" % tier)
		orb.free()
	var small: Area2D = _make_orb(1)
	var large: Area2D = _make_orb(2)
	assert((small.get_node("Sprite2D") as Sprite2D).texture.get_width() < (large.get_node("Sprite2D") as Sprite2D).texture.get_width(), "buyuk orb daha iri")
	_cleanup()


func test_pickup_restores_percent_of_max_shield_and_is_consumed() -> void:
	var p: Node = _make_player()
	p.item_shield_max = 200.0
	p.item_shield_hp = 20.0
	var orb: Area2D = _make_orb(1)
	orb._on_body_entered(p)
	assert(is_equal_approx(p.item_shield_hp, 50.0), "20 + %%15*200 = 50, bulunan: %s" % p.item_shield_hp)
	assert(orb.is_queued_for_deletion() and orb.get_meta("claimed", false))
	var big: Area2D = _make_orb(2)
	big._on_body_entered(p)
	assert(is_equal_approx(p.item_shield_hp, 110.0), "50 + %%30*200 = 110, bulunan: %s" % p.item_shield_hp)
	_cleanup()


func test_pickup_ignores_heal_power_and_caps_at_max() -> void:
	var p: Node = _make_player()
	p.item_shield_max = 100.0
	p.item_shield_hp = 0.0
	p.heal_shield_power = 1.0 ## +%100 İyileştirme ve Kalkan Gücü: orb yine tam %30 verir
	assert(p.heal_power_mult() > 1.0, "guc carpani bu alandan gelmeli")
	_make_orb(2)._on_body_entered(p)
	assert(is_equal_approx(p.item_shield_hp, 30.0), "guc carpani orbu buyutmemeli, bulunan: %s" % p.item_shield_hp)
	p.item_shield_hp = 90.0
	_make_orb(2)._on_body_entered(p)
	assert(is_equal_approx(p.item_shield_hp, 100.0), "azami kalkani asmamali")
	_cleanup()


func test_claimed_orb_does_not_pay_twice() -> void:
	var p: Node = _make_player()
	p.item_shield_max = 100.0
	p.item_shield_hp = 0.0
	var orb: Area2D = _make_orb(1)
	orb._on_body_entered(p)
	orb._on_body_entered(p)
	assert(is_equal_approx(p.item_shield_hp, 15.0), "ayni orb iki kez odemez, bulunan: %s" % p.item_shield_hp)
	_cleanup()


func test_roll_tier_is_mostly_small() -> void:
	var large: int = 0
	for i in range(4000):
		var t: int = OrbScript.roll_tier()
		assert(t == 1 or t == 2)
		if t == 2:
			large += 1
	assert(large > 4000 * 0.22 and large < 4000 * 0.38, "buyuk orb ~%%30 olmali, bulunan: %d/4000" % large)


func test_catchup_and_visual_copy_carry_the_tier() -> void:
	var orb: Area2D = _make_orb(2)
	orb.set_meta("drop_network_id", 987001)
	var found: bool = false
	for e in NetworkManager.collect_drop_catchup():
		if int(e[3]) == 987001:
			found = true
			assert(str(e[0]) == "shield_orb" and int(e[2]) == 2, "yakalama: tur + kademe")
	assert(found, "geri katilana yerdeki orb yollanmali")
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	NetworkManager._spawn_visual_drop("shield_orb", Vector2(40, 40), 2, 987002)
	var copy: Node = NetworkManager._visual_drops.get(987002)
	assert(copy != null and is_instance_valid(copy) and int(copy.tier) == 2 and copy.get_meta("network_spawned", false))
	NetworkManager._visual_drops.erase(987002)
	copy.free()
	_cleanup()
