extends Node

## Kullanıcı bildirimi (2026-10-06): "markette donma devam ediyor ve bu sefer donduktan sonra kapandı". Çökme dökümü (WER minidump) +
## yeniden üretim: detay panelindeki açıklama kutusunun (ScrollContainer, dikey çubuk OTOMATİK) en az genişliği çubuk görününce 320 -> 338'e
## sıçrıyor, panel genişliği eşya adının satır sayısını (1 <-> 2) değiştiriyor, o da açıklamaya kalan yüksekliği ve çubuğun gerekliliğini
## yeniden değiştiriyordu -> sınırdaki metinlerde yerleşim döngüsü HİÇ bitmiyor, Godot'un ertelenmiş çağrı kuyruğu (32 MB) doluyor, oyun
## donup çöküyordu (ölçüm: eşya seçimi sırasında 10 denemenin ~3'ü; düzeltmeyle 30/30 temiz). Düzeltme: çubuk payı baştan ayrılır
## (merchant_shop_screen.gd DESC_SCROLLBAR_RESERVE) - açıklama kutusunun en az genişliği çubuk görünsün ya da görünmesin sabit.
## Burada: (1) en az genişlik her eşyada sabit, (2) uzun açıklamalı eşya ile kısa olan art arda seçilirken yerleşim geçişi sayısı sınırlı.

const MobileUIPath := "res://scripts/mobile_ui.gd"
## Uzun açıklamalı (çok yükseltmeli) ve kısa açıklamalı eşyalar, sınırdaki adlar dahil.
const KEYS := ["savascinin_kilici", "tecrube_kitabi", "savascinin_kilici", "ruzgar_eldiveni", "kanli_yakut", "savascinin_kilici", "zirh_soken_hancer", "olum_esigi"]


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
var _sorts: int = 0


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _open_shop() -> CanvasLayer:
	(load(MobileUIPath) as GDScript).set(&"enabled", false)
	GameManager.gold = 100000
	GameManager.owned_items = []
	GameManager.owned_weapons = [{"key": "tufek", "level": 1, "spent": 0}]
	var merchant_node: Node = (load("res://scripts/traveling_merchant.gd") as GDScript).new()
	_made.append(merchant_node)
	var stock: Array = merchant_node.call("_generate_stock")
	## Kartların ilk sekizini sabit eşyalarla değiştir (sıra: yukarıdaki KEYS).
	var slot: int = 0
	for e: Dictionary in stock:
		if str(e.get("type")) == "item" and slot < KEYS.size():
			e["key"] = KEYS[slot]
			slot += 1
	var screen: CanvasLayer = (load("res://scripts/merchant_shop_screen.gd") as GDScript).new()
	var fm := FakeMerchant.new()
	var fp := FakePlayer.new()
	for n: Node in [fm, fp, screen]:
		add_child(n)
		_made.append(n)
	screen.setup(fp, stock, fm)
	await _frames(30)
	return screen


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()


func _find_desc_scroll(screen: Node) -> ScrollContainer:
	var d: Label = screen.get("_details_desc") as Label
	return d.get_parent() as ScrollContainer


func test_description_box_min_width_does_not_depend_on_its_scrollbar() -> void:
	var screen: CanvasLayer = await _open_shop()
	var sc: ScrollContainer = _find_desc_scroll(screen)
	var desc: Label = screen.get("_details_desc") as Label
	var stock: Array = screen.get("_stock")
	var first_item: int = 0
	for i in stock.size():
		if str(stock[i].get("type")) == "item":
			first_item = i
			break
	screen.call("_select_index", first_item)
	await _frames(6)
	## Kısa metin: çubuk yok. Uzun metin: çubuk görünür. İkisinde de en az genişlik AYNI olmalı (eskiden 320 <-> 338).
	desc.text = "kısa"
	await _frames(6)
	var short_w: float = sc.get_combined_minimum_size().x
	var short_bar: bool = sc.get_v_scroll_bar().visible
	desc.text = "Çok uzun açıklama satırı. ".repeat(40)
	await _frames(6)
	var long_w: float = sc.get_combined_minimum_size().x
	var long_bar: bool = sc.get_v_scroll_bar().visible
	assert(not short_bar and long_bar, "test önkoşulu: kısa metinde çubuk yok, uzunda var olmalı (kısa=%s uzun=%s)" % [str(short_bar), str(long_bar)])
	assert(is_equal_approx(short_w, long_w), "açıklama kutusunun en az genişliği çubuk görünürlüğüne göre değişmemeli: kısa %.1f, uzun %.1f" % [short_w, long_w])
	_cleanup()


func test_selecting_items_back_and_forth_never_runs_away_in_layout() -> void:
	var screen: CanvasLayer = await _open_shop()
	var stock: Array = screen.get("_stock")
	var center: Container = screen.get_child(1) as Container
	_sorts = 0
	var details_panel: Node = (screen.get("_details_name") as Node).get_parent().get_parent().get_parent()
	var watch: Array = []
	var stack: Array[Node] = [details_panel]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Container:
			watch.append(n)
	for n: Node in watch:
		(n as Container).sort_children.connect(func() -> void: _sorts += 1)
	center.sort_children.connect(func() -> void: _sorts += 1)
	var worst_per_select: int = 0
	for round in 3:
		for i in stock.size():
			if str(stock[i].get("type")) != "item":
				continue
			_sorts = 0
			screen.call("_select_index", i)
			await _frames(8)
			worst_per_select = maxi(worst_per_select, _sorts)
			assert(_sorts < 120, "eşya %d seçilince yerleşim geçişi sınırlı kalmalı (kaçak döngü): %d" % [i, _sorts])
	assert(worst_per_select < 120, "en kötü seçimde yerleşim geçişi: %d" % worst_per_select)
	_cleanup()
