extends Sprite2D

## Zemin katmanlarını DÜNYA PİKSELİ çözünürlüğünde çizip ekrana büyüten geçiş - kullanıcı bildirimi (2026-10-03): "oyunumun
## mobil versiyonunda fps sorunları yaşıyorum orta segment bir telefon kullanmama rağmen" + "dışarı çıkınca 20 yaratık varken
## bile 30fps, evin içinde 60fps".
##
## Kök neden (ölçüldü, telefon modu, gündüz dışarıda; GPU 3.27 ms'nin): çimen yaprak shader'ı ~1.06 ms, toprak kir shader'ı
## ~0.89 ms - ikisi GPU'nun ~%58'i. İkisi de her ekran pikselinde 3 kez kıvrımlı fbm gürültüsü (~100+ hash) hesaplıyor ama
## desen `floor(world_pos)` ile DÜNYA pikseline oturuyor: telefonda kamera 3.25x yakın, yani bir dünya pikselinin ~10 ekran
## pikseli AYNI sonucu ~10 kez yeniden hesaplıyordu (masaüstünde 2x -> 4 kez).
##
## Çözüm (görüntü birebir aynı): ZEMIN_KATMANLARI bir SubViewport'a 1 alt-piksel = 1 dünya pikseli ölçeğinde çizilir (aynı
## World2D paylaşılır, katmanlar sadece visibility_layer biti ile ana ekrandan bu görünüme taşınır - düğümler yerinde kalır,
## çarpışma/yol bulma/sis engelleri/harita pişirme araçları hiçbir şey fark etmez), sonra bu Sprite2D o dokuyu dünyada aynı
## yere "nearest" süzgeçle koyar. Shader'lar artık ekran pikseli başına değil dünya pikseli başına çalışır (~zoom² kat ucuz).
##  - Sprite, "Yer"in İLK çocuğu: katmanların eski çizim sırası (Yer > Çimler, Su, gölgeler, objeler) aynen korunur.
##  - Katmanlar şeffaf zemine "mix" ile çizilince doku premultiplied olur -> sprite PREMULT_ALPHA karışımıyla çizilir (yarı
##    saydam karo kenarları kararmaz).
##  - Doku ızgarası haritanın texel ızgarasına hizalı (Yer'in global konumunun kesirli kısmı korunur).
##  - Kamera çok uzaklaşırsa (dünya görünümü ekrandan büyük) geçiş kendini kapatır, katmanlar eskisi gibi doğrudan çizilir.
##  - Godot kuralı: SubViewport bir öğeyi ancak öğe VE TÜM ATALARI cull mask bitini taşıyorsa çizer -> atalara (Yer, Harita,
##    Main) bit EKLENİR (1 de kalır): ana ekran onları eskisi gibi çizer, alt görünüm ise atalardan sadece zemin katmanlarına iner.
## Yeni bir zemin katmanı eklersen ZEMIN_KATMANLARI'na eklemek yeter (alt görünüm her kare çizilir, TIME'lı shader de çalışır);
## tek şart 1 dünya pikselinden küçük ayrıntı çizmemesi. Bkz. sun_clouds.gd (güneş/bulut için aynı fikir).

## Ana ekrandan taşınan katmanların visibility_layer biti (başka hiçbir yerde kullanılmıyor).
const LAYER_BIT := 1 << 19
const NODE_NAME := "ZeminDunyaPikseli"
const PARENT_NAME := "Yer"
## "Yer" altındaki, ÇİZİM SIRASIYLA ardışık katmanlar. "Çimler" (sallanan mini çim) bilerek dışarıda: onların üstünde kalır.
const ZEMIN_KATMANLARI: Array[String] = ["Zemin Toprak", "Çimen gölge", "Zemin Çimen"]
## Kamera bu karede kıpırdarsa kenarda boşluk kalmasın diye görünümün her yanına eklenen pay (dünya px).
const MARGIN := 8
## Dünya görünümü (alt-piksel sayısı) ekran pikselinin bu oranından büyükse geçiş kapanır (kazanç yok).
const MAX_PIXEL_RATIO := 0.6
const GROUP := &"ground_texel_pass"
## GRAFİK AYARI "Zemin ayrıntısı" (UISound.gfx_ground_detail, Düşük'te kapalı): kapalıyken bu katmanların desen shader'ı
## kaldırılır (düz karo rengi), açılınca aynı materyal geri takılır. Harita köküne göre yollar ("Su ayrıntılar 2" çimen
## materyalini paylaşır).
const DETAIL_LAYER_PATHS: Array[String] = ["Yer/Zemin Toprak", "Yer/Zemin Çimen", "Su/Su ayrıntılar 2"]

## false = geçiş kapalı, katmanlar eskisi gibi doğrudan çizilir (A/B karşılaştırma).
var enabled: bool = true
var _sub: SubViewport = null
var _layers: Array[CanvasItem] = []
var _on: bool = false
var _detail_materials: Dictionary = {} ## CanvasItem -> özgün Material


## main.gd çağırır. Katmanlar bulunamazsa (harita yeniden bake edildi, adlar değişti) hiçbir şey yapmaz - eski yol çalışır.
static func attach(harita: Node) -> Node:
	var yer: Node = harita.get_node_or_null(PARENT_NAME) if harita else null
	if yer == null or yer.get_node_or_null(NODE_NAME) != null:
		return null
	var layers: Array[CanvasItem] = []
	for n: String in ZEMIN_KATMANLARI:
		var ci := yer.get_node_or_null(n) as CanvasItem
		if ci:
			layers.append(ci)
	if layers.is_empty():
		return null
	var pass_node: Sprite2D = load("res://scripts/ground_texel_pass.gd").new()
	pass_node.name = NODE_NAME
	pass_node._layers = layers
	yer.add_child(pass_node)
	yer.move_child(pass_node, layers[0].get_index())
	return pass_node


func _ready() -> void:
	process_priority = 997 ## kameradan sonra (bkz. sun_clouds.gd 998)
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	material = m
	_sub = SubViewport.new()
	_sub.name = "ZeminGorunumu"
	_sub.world_2d = get_viewport().world_2d
	_sub.transparent_bg = true
	_sub.disable_3d = true
	_sub.canvas_cull_mask = LAYER_BIT
	_sub.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_sub)
	texture = _sub.get_texture()
	visible = false
	var anc := get_parent() as CanvasItem
	while anc:
		anc.visibility_layer |= LAYER_BIT
		anc = anc.get_parent() as CanvasItem
	add_to_group(GROUP)
	var harita: Node = get_parent().get_parent()
	for path: String in DETAIL_LAYER_PATHS:
		var ci := harita.get_node_or_null(path) as CanvasItem
		if ci and ci.material:
			_detail_materials[ci] = ci.material
	UISound.graphics_changed.connect(_apply_detail)
	_apply_detail()


func is_on() -> bool:
	return _on


func _apply_detail() -> void:
	for ci: CanvasItem in _detail_materials:
		if is_instance_valid(ci):
			ci.material = _detail_materials[ci] if UISound.gfx_ground_detail else null


func _exit_tree() -> void:
	_set_on(false)
	if UISound.graphics_changed.is_connected(_apply_detail):
		UISound.graphics_changed.disconnect(_apply_detail)


func _set_on(on: bool) -> void:
	if on == _on:
		return
	_on = on
	for ci: CanvasItem in _layers:
		if is_instance_valid(ci):
			ci.visibility_layer = LAYER_BIT if on else 1
	var vp: Viewport = get_viewport()
	if vp:
		vp.canvas_cull_mask = (vp.canvas_cull_mask & ~LAYER_BIT) if on else (vp.canvas_cull_mask | LAYER_BIT)
	visible = on
	if _sub:
		_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


func _process(_delta: float) -> void:
	var vp: Viewport = get_viewport()
	var screen: Vector2 = vp.get_visible_rect().size
	var inv: Transform2D = vp.get_canvas_transform().affine_inverse()
	var a: Vector2 = inv * Vector2.ZERO
	var b: Vector2 = inv * screen
	var tl := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var world: Vector2 = (a - b).abs()
	var want := Vector2i(ceili(world.x) + MARGIN * 2 + 1, ceili(world.y) + MARGIN * 2 + 1)
	var ok: bool = enabled and screen.x > 0.0 and float(want.x * want.y) <= screen.x * screen.y * MAX_PIXEL_RATIO
	_set_on(ok)
	if not ok:
		return
	if _sub.size != want:
		_sub.size = want
	## Haritanın texel ızgarasına hizalı tam sayı adım (Yer'in global konumunun kesiri korunur).
	var grid: Vector2 = get_parent().global_position if get_parent() is Node2D else Vector2.ZERO
	var frac := grid - grid.floor()
	var origin: Vector2 = (tl - frac).floor() + frac - Vector2(MARGIN, MARGIN)
	_sub.canvas_transform = Transform2D(0.0, -origin)
	global_transform = Transform2D(0.0, origin)
