extends Node

## Kullanıcı bildirimi (2026-10-06, Android): "marketteki kaydırma sorunu düzelmemiş". Kök neden: telefon dükkanında detay paneli (ad + açıklama +
## tarif + fiyat) ve stat paneli doğrudan PanelContainer'daydı; uzun adlı / tarifli eşyada panelin en az yüksekliği (868 birim) mevcut
## alanı (564) aşıyor, pencere EKRANDAN UZUN oluyordu: ortadaki kart ızgarasının kaydırma kutusu uzayıp kaydırma sınırı 826 -> 522'ye düşüyor,
## liste sıçrıyor, AL düğmeleri ekran dışında kalıyordu. Kart seçimi (kaydırmaya başlarken parmak karta basar) bu değişimi tetikliyordu.
## Düzeltme: yan paneller telefonda kendi kaydırma kutusunda (en az yükseklik 0). Burada her eşya seçilirken pencere boyu ve kaydırma
## sınırının sabit kaldığı doğrulanır.

const MobileUIPath := "res://scripts/mobile_ui.gd"
const W := 2400
const H := 1080


class FakeMerchant extends Node:
	func get_reroll_cost() -> int:
		return 3

	func try_reroll_stock() -> Variant:
		return null


class FakePlayer extends Node:
	func get_max_item_slots() -> int:
		return 6

	func get_max_owned_weapons() -> int:
		return 5

	func acquire_item(_key: String, _plan: Dictionary = {}, _paid: int = 0) -> bool:
		return true

	func buy_weapon_copy(_key: String, _level: int) -> bool:
		return true

	func refresh_shield_stats() -> void:
		pass


var _made: Array[Node] = []


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open_shop(phone: bool) -> Dictionary:
	(load(MobileUIPath) as GDScript).set(&"enabled", phone)
	Input.use_accumulated_input = false
	DisplayServer.window_set_size(Vector2i(W, H))
	get_tree().root.size = Vector2i(W, H)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	await _frames(2)
	GameManager.gold = 100000
	var keys: Array = (load("res://scripts/items.gd") as GDScript).get("KEYS")
	var owned: Array = []
	for i in 4:
		owned.append({"key": str(keys[i % keys.size()]), "spent": 10})
	GameManager.owned_items = owned
	GameManager.owned_weapons = [{"key": "tufek", "level": 1, "spent": 0}]
	var merchant_node: Node = (load("res://scripts/traveling_merchant.gd") as GDScript).new()
	_made.append(merchant_node)
	var stock: Array = merchant_node.call("_generate_stock")
	var screen: CanvasLayer = (load("res://scripts/merchant_shop_screen.gd") as GDScript).new()
	var fm := FakeMerchant.new()
	var fp := FakePlayer.new()
	for n: Node in [fm, fp, screen]:
		add_child(n)
		_made.append(n)
	screen.setup(fp, stock, fm)
	await _frames(40)
	return {"screen": screen, "stock": stock}


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	(load(MobileUIPath) as GDScript).set(&"enabled", false)


func _grid_scroll(screen: Node) -> ScrollContainer:
	return screen.get("_phone_scroll") as ScrollContainer


func test_phone_window_never_outgrows_the_screen_when_items_are_selected() -> void:
	var o: Dictionary = await _open_shop(true)
	var screen: CanvasLayer = o["screen"]
	var stock: Array = o["stock"]
	var window := screen.get_child(1) as Control
	var rect_h: float = (screen.call("_phone_rect") as Rect2).size.y
	var sc: ScrollContainer = _grid_scroll(screen)
	assert(sc != null, "telefon kart ızgarasının kaydırma kutusu olmalı")
	var base_page: float = sc.get_v_scroll_bar().page
	var base_max: float = sc.get_v_scroll_bar().max_value
	assert(base_page > 100.0, "test önkoşulu: kaydırma kutusu ölçülebilmeli")
	for i in stock.size():
		screen.call("_select_index", i)
		await _frames(4)
		assert(absf(window.size.y - rect_h) < 1.0, "eşya %d (%s) seçilince pencere ekran alanını (%.0f) aşmamalı: %.0f" % [i, str(stock[i].get("key")), rect_h, window.size.y])
		var bar: ScrollBar = sc.get_v_scroll_bar()
		assert(absf(bar.page - base_page) < 1.0, "eşya %d seçilince kaydırma kutusu boyu sabit kalmalı: %.0f -> %.0f" % [i, base_page, bar.page])
		assert(absf(bar.max_value - base_max) < 1.0, "eşya %d seçilince içerik boyu sabit kalmalı" % i)
	_cleanup()


func test_phone_side_panels_scroll_inside_instead_of_growing() -> void:
	var o: Dictionary = await _open_shop(true)
	var screen: CanvasLayer = o["screen"]
	var found: Array = []
	var stack: Array[Node] = [screen]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n.name == &"SidePanelScroll":
			found.append(n)
	assert(found.size() == 2, "detay + stat paneli telefonda kendi kaydırma kutusunda olmalı: %d" % found.size())
	for sp: ScrollContainer in found:
		assert(sp.get_combined_minimum_size().y < 40.0, "yan panel kaydırma kutusunun en az yüksekliği içeriğe bağlı olmamalı: %.0f" % sp.get_combined_minimum_size().y)
	_cleanup()


func test_desktop_shop_is_unchanged() -> void:
	var o: Dictionary = await _open_shop(false)
	var screen: CanvasLayer = o["screen"]
	var stack: Array[Node] = [screen]
	var side: int = 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n.name == &"SidePanelScroll":
			side += 1
	assert(side == 0, "masaüstü dükkanında yan panel kaydırma kutusu YOK (düzen aynı)")
	_cleanup()
