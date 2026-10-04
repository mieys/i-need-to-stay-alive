extends Node

## GRAFİK AYARI "Çözünürlük ölçeği" (UISound.gfx_render_scale: %100 / %75 / %50; Düşük seviyede %75) - kullanıcı isteği
## (2026-10-03, grafik ayarları): dünya daha az pikselle çizilip ekrana büyütülür, ARAYÜZ ve ekran katmanları (sis, gün-gece
## rengi, güneş, HUD - hepsi CanvasLayer) her zaman TAM çözünürlükte kalır.
##
## Nasıl (düğümler yerinde kalır, hiçbir oyun kodu değişmez):
##  - Bir SubViewport ana ekranın World2D'sini paylaşır ve dünyayı ekran boyutu x ölçek boyutunda, kameranın canvas
##    dönüşümünü aynı oranda küçülterek çizer. Bir CanvasLayer (layer -1, tüm diğer katmanların altında) bu dokuyu tam
##    ekrana "nearest" ile gerer.
##  - Ana ekranın dünyayı İKİNCİ kez çizmemesi için visibility_layer: Main'e WORLD_BIT verilir ve 1 biti alınır; ana ekranın
##    canvas_cull_mask'inden WORLD_BIT ve zemin geçişinin biti (ground_texel_pass.gd LAYER_BIT - Main onu da taşır) çıkarılır.
##    Godot kuralı: öğe ancak KENDİSİ VE TÜM ATALARI maskeyle bit paylaşırsa çizilir -> Main elenince bütün dünya elenir.
##    CanvasLayer altındaki arayüz öğelerinin CanvasItem atası yoktur (CanvasLayer CanvasItem değil) -> etkilenmez.
##  - Alt görünümün maskesi 1 | WORLD_BIT: Main (WORLD_BIT) ve dünyadaki her şey (1) çizilir; zemin geçişi açıksa zemin
##    katmanları sadece kendi bitini taşıdığı için burada çizilmez (onları zemin geçişinin sprite'ı getirir).
##  - Fare/dokunma -> dünya dönüşümleri ana ekranın (değişmeyen) canvas dönüşümünü kullanmaya devam eder.
## %100'de hiçbir şey kurulmaz (eski yol birebir). Main sahneden çıkınca ana ekran maskesi geri verilir (menüler etkilenmesin).

const WORLD_BIT := 1 << 20
const GroundTexelPassScript := preload("res://scripts/ground_texel_pass.gd")
const NODE_NAME := "WorldRenderScale"

var _main: CanvasItem = null
var _sub: SubViewport = null
var _layer: CanvasLayer = null
var _active: bool = false


## main.gd çağırır.
static func attach(main: Node) -> Node:
	if main == null or not (main is CanvasItem) or main.get_node_or_null(NODE_NAME) != null:
		return null
	var n: Node = load("res://scripts/world_render_scale.gd").new()
	n.name = NODE_NAME
	main.add_child(n)
	return n


func _ready() -> void:
	process_priority = 1001 ## kameradan ve zemin geçişinden (997) sonra
	_main = get_parent() as CanvasItem
	UISound.graphics_changed.connect(_refresh)
	_refresh()


func _exit_tree() -> void:
	if UISound.graphics_changed.is_connected(_refresh):
		UISound.graphics_changed.disconnect(_refresh)
	_deactivate()


func is_active() -> bool:
	return _active


func _refresh() -> void:
	var want: bool = UISound.gfx_render_scale < 0.999
	if want and not _active:
		_activate()
	elif not want and _active:
		_deactivate()


func _activate() -> void:
	var root: Viewport = get_viewport()
	_sub = SubViewport.new()
	_sub.name = "DunyaGorunumu"
	_sub.world_2d = root.world_2d
	_sub.disable_3d = true
	_sub.canvas_cull_mask = 1 | WORLD_BIT
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	_layer = CanvasLayer.new()
	_layer.name = "DunyaGoruntusu"
	_layer.layer = -1
	add_child(_layer)
	var rect := TextureRect.new()
	rect.texture = _sub.get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(rect)
	_main.visibility_layer = (_main.visibility_layer | WORLD_BIT) & ~1
	_active = true
	_process(0.0)


func _deactivate() -> void:
	if not _active:
		return
	_active = false
	if is_instance_valid(_main):
		_main.visibility_layer = (_main.visibility_layer | 1) & ~WORLD_BIT
	var root: Viewport = get_viewport()
	if root:
		root.canvas_cull_mask |= WORLD_BIT
		var ground: Node = get_tree().get_first_node_in_group(GroundTexelPassScript.GROUP) if is_inside_tree() else null
		if ground == null or not bool(ground.call("is_on")):
			root.canvas_cull_mask |= GroundTexelPassScript.LAYER_BIT
	if is_instance_valid(_layer):
		_layer.queue_free()
	if is_instance_valid(_sub):
		_sub.queue_free()
	_layer = null
	_sub = null


func _process(_delta: float) -> void:
	if not _active:
		return
	var root: Viewport = get_viewport()
	## Zemin geçişi kapanırken kendi bitini ana maskeye geri ekler - dünya ana ekranda ikinci kez çizilmesin diye her kare.
	root.canvas_cull_mask &= ~(WORLD_BIT | GroundTexelPassScript.LAYER_BIT)
	var vis: Vector2 = root.get_visible_rect().size
	if vis.x <= 0.0 or vis.y <= 0.0:
		return
	var phys: Vector2 = Vector2((root as Window).size) if root is Window else vis
	var s: float = UISound.gfx_render_scale
	var want := Vector2i(maxi(1, roundi(phys.x * s)), maxi(1, roundi(phys.y * s)))
	if _sub.size != want:
		_sub.size = want
	var k: Vector2 = Vector2(want) / vis
	_sub.canvas_transform = Transform2D(0.0, k, 0.0, Vector2.ZERO) * root.get_canvas_transform()
