extends Node

## Kullanıcı bildirimi (2026-10-04): "joystick kullanırken seyyar satıcıdan satın alma butonlarına basamıyorum". Kök neden: kart
## odaklanabilir bir PanelContainer, içindeki AL butonu D-pad odak aramasına hiç girmiyordu (4/4 ulaşılamaz) ve karta A sadece
## "seç" yapıyordu. Artık: dükkan ilk kartta açılır, D-pad karta gelince o kart seçilir, A (ui_accept) odaktaki kartı satın alır.

const MerchantScreenScript: GDScript = preload("res://scripts/merchant_shop_screen.gd")


class FakeMerchant extends Node:
	func get_reroll_cost() -> int:
		return 0

	func try_reroll_stock() -> Variant:
		return []


class FakePlayer extends Node:
	var bought_items: Array = []

	func get_max_item_slots() -> int:
		return 3

	func get_max_owned_weapons() -> int:
		return 5

	func acquire_item(key: String, _plan: Dictionary = {}, paid: int = 0) -> bool:
		bought_items.append(key)
		GameManager.owned_items.append({"key": key, "spent": paid})
		return true

	func buy_weapon_copy(_k: String, _l: int) -> bool:
		return true

	func refresh_shield_stats() -> void:
		pass


func _press_accept() -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	get_viewport().push_input(ev)


func test_pad_navigates_to_card_and_a_buys_once() -> void:
	GameManager.gold = 100000
	GameManager.owned_weapons = []
	GameManager.owned_items = []
	var merchant := FakeMerchant.new()
	var player := FakePlayer.new()
	add_child(merchant)
	add_child(player)
	var stock: Array = [{"type": "weapon", "key": "fire_staff"}, {"type": "weapon", "key": "arcane_staff"},
		{"type": "item", "key": "kutsal_tilsim", "tier": 1}]
	var screen: CanvasLayer = MerchantScreenScript.new()
	add_child(screen)
	screen.setup(player, stock, merchant)
	for i in 8:
		await get_tree().process_frame
	GameManager.get_node("GamepadUi").set("joypad_active", true)
	for i in 30:
		await get_tree().process_frame
	var focused: Control = get_viewport().gui_get_focus_owner()
	assert(focused == screen._card_panels[0], "dükkan açılınca ilk odak ilk kartta olmalı: %s" % str(focused))
	for b in screen._buy_buttons:
		assert((b as Control).focus_mode == Control.FOCUS_NONE, "AL butonu odak almaz (odak kartta)")
	var next_card: Control = focused.find_valid_focus_neighbor(SIDE_RIGHT)
	assert(next_card != null and screen._card_panels.has(next_card), "D-pad sağ başka bir karta gitmeli: %s" % str(next_card))
	next_card.grab_focus()
	assert(screen._selected_index == screen._card_panels.find(next_card), "odaklanan kart seçilir (ayrıntılar onu gösterir)")
	var idx: int = screen._selected_index
	var gold0: int = GameManager.gold
	_press_accept()
	await get_tree().process_frame
	assert(GameManager.gold < gold0, "A odaktaki kartı satın almalı")
	assert(screen._price_labels[idx].text == "SATILDI", "satılan kart SATILDI olur")
	var gold1: int = GameManager.gold
	_press_accept()
	await get_tree().process_frame
	assert(GameManager.gold == gold1, "ikinci A aynı kartı tekrar almaz")
	GameManager.get_node("GamepadUi").set("joypad_active", false)
	screen.queue_free()
	merchant.queue_free()
	player.queue_free()
	GameManager.gold = 100000
	GameManager.owned_weapons = []
	GameManager.owned_items = []
