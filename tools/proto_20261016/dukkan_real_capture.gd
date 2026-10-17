extends SceneTree

## Seyyar satıcı (Klasik Pazar) + demirci (Örs Vitrini) GERÇEK ekranlarının görüntüsü (madde 197): oyundaki merchant_shop_screen.gd /
## weapon_shop_screen.gd sahte oyuncu durumuyla (1480 altın, 17 parçacık, 4 eşya, 3 silah) gerçek harita / demirci iç mekanı üstünde açılır.
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261016/dukkan_real_capture.gd  (DUKKAN_CAP_DIR = çıktı)

const STOCK := ["tornavida", "kutsal_tilsim", "ceviklik_yuzugu", "bile_tasi",
		"keskin_goz_hanceri", "savascinin_kilici", "ruh_emici", "yenilenme_ozutu",
		"ilidaricin_kilici", "son_felaket_pencesi", "kan_aglayan", "kiyamet_bicagi"]
const OWNED := ["bile_tasi", "ceviklik_yuzugu", "yasam_kristali", "ruzgar_eldiveni"]
const MERCHANT_POS := Vector2(1931, 1290)
const SMITHY_POS := Vector2(24000, 0)

var _dir: String = OS.get_environment("DUKKAN_CAP_DIR")
var _world: Node2D = null
var _cam: Camera2D = null
var GM: Node = null


class FakePlayer extends Node2D:
	func get_max_item_slots() -> int:
		return 9

	func get_max_owned_weapons() -> int:
		return 3


class FakeMerchant extends Node:
	func get_reroll_cost() -> int:
		return 7

	func try_reroll_stock() -> Variant:
		return null

	func get_visit_time_left() -> float:
		return 134.0

	func get_visit_duration() -> float:
		return 180.0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_dir.path_join(name))
	print("SHOT %s" % name)


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_dir)
	GM = root.get_node("GameManager")
	var MP: GDScript = load("res://scripts/meta_progress.gd")
	MP.set("unlock_all_override", true)
	var ED: GDScript = load("res://scripts/enchant_defs.gd")
	RenderingServer.set_default_clear_color(Color.BLACK)
	_world = Node2D.new()
	_world.name = "Main"
	root.add_child(_world)
	current_scene = _world
	_world.add_child((load("res://scenes/harita_baked.tscn") as PackedScene).instantiate())
	var cart: Node2D = (load("res://scenes/seyyar_satici_baked.tscn") as PackedScene).instantiate()
	cart.position = MERCHANT_POS
	_world.add_child(cart)
	var smithy: Node2D = (load("res://scenes/silah_saticisi_baked.tscn") as PackedScene).instantiate()
	smithy.position = SMITHY_POS
	_world.add_child(smithy)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2.25, 2.25)
	_world.add_child(_cam)
	_cam.make_current()
	var player := FakePlayer.new()
	_world.add_child(player)

	GM.set("gold", 1480)
	GM.set("weapon_shards", 17)
	var items: Array = []
	for k: String in OWNED:
		items.append({"key": k, "spent": 0})
	GM.set("owned_items", items)
	var weapons: Array = []
	for w: Array in [["uzunkilic", [0, 1]], ["tabanca", [0, 1, 2, 3]], ["fire_staff", []]]:
		var e: Dictionary = ED.new_weapon_entry(str(w[0]), 1, 0)
		(e["enchant"] as Dictionary)["ups"] = w[1]
		weapons.append(e)
	GM.set("owned_weapons", weapons)
	GM.set("shield_enchant", "shield_kale")

	## ---- seyyar satıcı
	_cam.position = MERCHANT_POS + Vector2(60, 40)
	var stock: Array = []
	for k: String in STOCK:
		stock.append({"type": "item", "key": k, "sold": k == "kutsal_tilsim"})
	var fm := FakeMerchant.new()
	_world.add_child(fm)
	var ms: CanvasLayer = (load("res://scripts/merchant_shop_screen.gd") as GDScript).new()
	_world.add_child(ms)
	ms.setup(player, stock, fm)
	await _frames(4)
	var sel: int = 0
	var st: Array = ms.get("_stock")
	for i in st.size():
		if str(st[i].get("key")) == "ilidaricin_kilici":
			sel = i
	ms.call("_select_index", sel)
	await _shot("oyun_satici.png")
	ms.call("_on_bag_gui_input", _click(), 3)
	await _shot("oyun_satici_canta.png")
	ms.call("_on_close_pressed")
	await _frames(2)

	## ---- demirci
	_cam.position = SMITHY_POS + Vector2(-40, -10)
	var ws: CanvasLayer = (load("res://scripts/weapon_shop_screen.gd") as GDScript).new()
	_world.add_child(ws)
	ws.setup(player)
	ws.set("_trait_slot", 0)
	ws.call("_show_tab", 2) ## Tab.ENCHANTS
	await _frames(2)
	var rows: Array = ws.get("_rows")
	if rows.size() > 2:
		ws.call("_select", rows[2]["entry"])
	await _shot("oyun_demirci_gelistir.png")
	ws.call("_show_tab", 0) ## Tab.WEAPONS
	await _shot("oyun_demirci_silah.png")
	ws.call("_show_tab", 1) ## Tab.SHIELDS
	await _shot("oyun_demirci_kalkan.png")
	ws.call("_on_close_pressed")
	await _frames(2)
	MP.set("unlock_all_override", false)
	quit()


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e
