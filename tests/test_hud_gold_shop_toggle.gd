extends Node

## Kullanıcı isteği doğrulaması: "dükkan butonunu silip altın göstergesine
## tıklandığında dükkan açılsın" + "envanter ve dükkan (altın göstergesi)
## aynı renkte olsun".
##
## NOT: Bu test ortamında instantiate edilen node'lar canlı SceneTree'ye
## girmediği için Godot _ready()'yi OTOMATİK çağırmıyor (bkz. hata ayıklama:
## $ShopPanel get_node ile buluyor ama @onready var'lar hep null kalıyordu).
## Bu yüzden add_child()'dan sonra hud._ready() burada ELLE çağrılıyor -
## chest_menu.gd testlerindeki menu.setup() paterniyle aynı fikir.

const PAL_WINDOW_BG := Color(0.47, 0.39, 0.23, 1.0)


## Bu test ortamında instantiate edilen hud gerçek (canlı) bir SceneTree'ye
## girmiyor, bu yüzden motor _ready()'yi otomatik çağırmıyor - burada elle
## tetikleniyor. hud.gd artık tüm sinyal bağlantılarını _connect_once() ile
## yaptığı için (bkz. hud.gd) bu birden fazla kez çağrılsa bile güvenli.
func _make_hud() -> Node:
	var scene: PackedScene = load("res://scenes/hud.tscn")
	var hud: Node = scene.instantiate()
	add_child(hud)
	hud._ready()
	return hud


func test_gold_indicator_children_pass_clicks_through() -> void:
	var hud: Node = _make_hud()
	var gold_indicator: PanelContainer = hud.get_node("GoldIndicator")
	for child in gold_indicator.get_children():
		_assert_all_ignore(child)
	hud.queue_free()


func _assert_all_ignore(node: Node) -> void:
	if node is Control:
		assert((node as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"%s mouse_filter IGNORE olmali (yoksa tiklama GoldIndicator'a ulasmaz)" % node.name)
	for child in node.get_children():
		_assert_all_ignore(child)


func test_shop_toggle_button_is_hidden() -> void:
	var hud: Node = _make_hud()
	var shop_btn: Button = hud.get_node("ShopToggleButton")
	assert(shop_btn.visible == false, "ShopToggleButton hala görünür olmamalı")
	hud.queue_free()


func test_gold_indicator_click_opens_shop() -> void:
	var hud: Node = _make_hud()
	var shop_panel: Control = hud.get_node("ShopPanel")
	assert(shop_panel.visible == false, "Dükkan başta kapalı olmalı")
	hud._on_gold_indicator_gui_input(
		InputEventMouseButton.new()
	)
	## Sahte event pressed=false olduğu için henüz açılmamalı.
	assert(shop_panel.visible == false, "pressed=false event dükkanı açmamalı")

	var press_event := InputEventMouseButton.new()
	press_event.pressed = true
	press_event.button_index = MOUSE_BUTTON_LEFT
	hud._on_gold_indicator_gui_input(press_event)
	assert(shop_panel.visible == true, "Sol tık dükkanı açmalı")

	hud._on_gold_indicator_gui_input(press_event)
	assert(shop_panel.visible == false, "İkinci sol tık dükkanı kapatmalı")
	hud.queue_free()


func test_envanter_button_matches_gold_indicator_palette() -> void:
	## Kullanıcı isteği (2026-09-21): ENVANTER butonu ve altın göstergesi artık aynı piksel UI kitinden (assets/ui/kit) geliyor -
	## buton ahşap plaka dokusu, gösterge başlık tahtası (plaque) dokusu; ikisi de StyleBoxTexture ve kit klasöründen.
	var hud: Node = _make_hud()
	var envanter_btn: Button = hud.get_node("EnvanterToggleButton")
	var gold_indicator: PanelContainer = hud.get_node("GoldIndicator")

	var envanter_style: StyleBoxTexture = envanter_btn.get_theme_stylebox("normal") as StyleBoxTexture
	var gold_style: StyleBoxTexture = gold_indicator.get_theme_stylebox("panel") as StyleBoxTexture

	assert(envanter_style != null, "ENVANTER butonu icin normal stil (StyleBoxTexture) bekleniyordu")
	assert(gold_style != null, "Altin gostergesi icin panel stili (StyleBoxTexture) bekleniyordu")
	assert(envanter_style.texture.resource_path.begins_with("res://assets/ui/kit/"),
		"ENVANTER butonu kit dokusunu kullanmiyor: %s" % envanter_style.texture.resource_path)
	assert(gold_style.texture.resource_path.begins_with("res://assets/ui/kit/"),
		"Altin gostergesi kit dokusunu kullanmiyor: %s" % gold_style.texture.resource_path)
	hud.queue_free()


func test_battle_mode_slots_always_visible_and_fully_opaque() -> void:
	var hud: Node = _make_hud()
	
	# Verify slots list
	assert(hud.shield_mode_slots != null, "shield_mode_slots array must exist")
	assert(hud.shield_mode_slots.size() == 4, "Should have 4 slots")
	
	for i in range(hud.shield_mode_slots.size()):
		var slot: Button = hud.shield_mode_slots[i] as Button
		assert(slot.visible == true, "Slot %d must be visible even if not owned" % i)
		assert(is_equal_approx(slot.modulate.a, 1.0), "Slot %d must be fully opaque" % i)
		
		var bg_node: TextureRect = slot.get_node_or_null("BG") as TextureRect
		if bg_node:
			assert(bg_node.visible == true, "BG of slot %d must be visible" % i)
			assert(is_equal_approx(bg_node.modulate.a, 1.0), "BG of slot %d must be fully opaque" % i)
			
	hud.queue_free()
