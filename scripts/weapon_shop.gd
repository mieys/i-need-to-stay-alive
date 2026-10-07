extends Node2D

## SİLAH SATICISI (demirci) DÜKKANI - kullanıcı isteği (2026-10-07): "harita tmx'ine eklediğim yeni blacksmith yapısının
## kapısından içeri girince açılacak yeni bir dükkan. bu dükkanda örse yaklaşınca etkileşime girip artık silahları buradan satın
## alacağız. bundan sonra silahlar ve kalkanlar burada satılacak". house_interior.gd ile AYNI desen (ona bakılarak yazıldı):
##   - DIŞ GİRİŞ: haritadaki "ev/blacksmith kapı" katmanının (Tiled'da 2x2 kapı) alt kenarı; yakınında etkileşim tuşu
##     (varsayılan Space) iç mekana ışınlar (kısa kararma geçişiyle).
##   - İÇ MEKAN: res://scenes/silah_saticisi_baked.tscn ("harita/silah satıcısı.tmx"nin tools/bake_silah_saticisi.gd ile pişirilmiş
##     hali) haritadan çok uzağa (INTERIOR_OFFSET, ev içinden 4000 birim yanda) konur; oyuncu is_indoors olur (yaratıklar
##     saldırmaz/doğmaz, silahlar gizlenir - ev içiyle aynı bayrak, bkz. player.gd is_indoors). Çarpışma ÇALIŞMA ANINDA katmanlardan
##     üretilir (house_interior.gd _add_interior_collisions mantığı): çarpışmasız katmanlar NO_COLLISION_LAYERS'ta, kapı hücreleri
##     her zaman açık. Tiled'da katman eklenip yeniden bake edilince kod değişikliği gerekmez.
##   - ÇIKIŞ: iç haritadaki "blacksmith kapı iç" katmanının (güney duvardaki 2 hücre) üstüne basınca dışarı (kullanıcı ekledi).
##   - ÖRS: "Eleman pozisyon" katmanındaki tek karo örsün etkileşim noktasıdır (kullanıcı: "örse yaklaşınca etkileşime girip");
##     yakınında etkileşim tuşu weapon_shop_screen.gd'yi açar. O katman işaretleyicidir, görünmez yapılır.
## Haritadaki bina ÇARPIŞMASIZ (oyuncu/yaratık engeli sadece orman katmanında, bkz. player.gd _block_movement_into_terrain) - bina
## duvarları için kural değiştirilmedi.

const InteriorScene: PackedScene = preload("res://scenes/silah_saticisi_baked.tscn")
const ShopScreenScript := preload("res://scripts/weapon_shop_screen.gd")
const HouseScript := preload("res://scripts/house_interior.gd")
const DepthOccludersScript := preload("res://scripts/depth_occluders.gd")

## Ev içi (20000,0) ile çakışmasın diye 4000 birim yanda; harita 0..4096 (camera_map_limits.gd: haritadan 2048'den uzaktaki kamera
## limitsiz sayılır).
const INTERIOR_OFFSET := Vector2(24000.0, 0.0)
const INTERIOR_COLLISION_LAYER := 8 ## bkz. house_interior.gd INTERIOR_COLLISION_LAYER (oyuncunun maskesine sadece içerideyken eklenir)
const BACKDROP_SIZE := 3000.0
## Oda dışının görünümü. Kullanıcı 2026-10-07 üç hali görüp SEÇTİ: "dükkanın dışının siyah olmasını istiyorum tıpkı evinki gibi" = &"clean"
## (ev içiyle aynı: dış her yer düz siyah, gri kenar yok). Diğer iki hal karşılaştırma için kodda duruyor:
##   &"black" : dış boşluk siyah, duvar paketinin arduvaz dolgusu odanın çevresinde gri bir kenar bırakır
##   &"match" : dış boşluk da AYNI arduvaz renginde (gri kenar ile boşluk birleşir)
##   &"clean" : gri kenar yok - arduvaz dolgu rengi duvar katmanlarında siyaha çevrilir (renk anahtarı gölgelendirici)
const OUTSIDE_STYLE := &"clean"
const WALL_SLATE := Color8(39, 38, 46) ## Walls_interior.png dolgu karosu (tile 33) ve duvar karolarının baskın rengi
const SLATE_KEY_SHADER := """shader_type canvas_item;
uniform vec3 key_color = vec3(0.15294, 0.14902, 0.18039);
uniform float tolerance = 0.012;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.5 && distance(c.rgb, key_color) < tolerance) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		COLOR = c;
	}
}
"""

## Dış kapı katmanı (main.tscn'de Harita sahnesi kardeş) ve yedek konum (kapı alt kenarı, harita kaymasıyla dünya koordinatı).
const EXTERIOR_DOOR_LAYER_PATH := "../Harita/ev/blacksmith kapı"
const FALLBACK_EXTERIOR_DOOR_POS := Vector2(1294.0, 2389.0)
const EXTERIOR_TRIGGER_RADIUS := 56.0
const EXTERIOR_RETURN_OFFSET := Vector2(0.0, 40.0) ## çıkınca kapının önüne (güneye) çıkılır

## İç mekan katman adları (küçük harfle karşılaştırılır; Tiled'daki adlar, bkz. tools/bake_silah_saticisi.gd).
const EXIT_DOOR_LAYER := "blacksmith kapı iç"
const ANVIL_MARKER_LAYER := "eleman pozisyon"
## Duvar katmanları TAM kaplanır; diğer (eşya) katmanlarında yalnızca her sütunun EN ALT karosu ("ayak izi") çarpışır: paketin
## eşya katmanları nesnelerin tüm yüksekliğini (üst yarıları dahil) taşıyor, hepsini kaplamak oda içini kapatıyor ve kapı cebini
## örsten ayırıyordu (ölçüm: kapıdan sadece 11 hücre erişilebiliyordu; ayak izi kuralıyla ~70). Oyuncu katmanların üstünde çizilir.
const FULL_COLLISION_LAYERS: Array[String] = ["walls", "walls_top"]
const NO_COLLISION_LAYERS: Array[String] = ["floor", "floor_light", "torches_back", "torches_pillar_n_front", EXIT_DOOR_LAYER, ANVIL_MARKER_LAYER]
## Oyuncunun üstünde çizilen "ön" katmanlar (oyuncu z_index = 1, bkz. main.tscn Player; ön katmanlar 2).
const FRONT_LAYERS: Array[String] = ["torches_pillar_n_front", "walls_top"]
const FRONT_Z := 2
## Yedek (katman bulunamazsa): iç mekanın yerel koordinatında doğma noktası ve çıkış alanı.
const FALLBACK_SPAWN_POS := Vector2(-80.0, 8.0)
const FALLBACK_EXIT_POS := Vector2(-80.0, 40.0)
## Kapı önü boşluğu: kapı hücrelerinin yanlarında LOBBY_SIDE, kuzeyinde LOBBY_DEPTH hücre içindeki EŞYA çarpışmaları kaldırılır
## (duvarlar kalır). Paketin eşyaları kapı cebini tek hücrelik (16 px) geçitlerle odadan ayırıyordu; oyuncunun gövdesi 16 px olduğu
## için fiziksel olarak sığmıyordu (testle ölçüldü: doğma noktasından odaya çıkılamıyor).
const LOBBY_SIDE := 2
const LOBBY_DEPTH := 3
const SPAWN_ABOVE_DOOR := 48.0 ## sol kapı hücresinin ortasından bu kadar yukarıda (iç mekan yerelinde) doğulur (3 hücre: boş bant)
const ANVIL_INTERACT_RADIUS := 84.0
const FADE_DURATION := 0.22

var _player: CharacterBody2D = null
var _interior: Node2D = null
var _entrance_area: Area2D = null
var _exit_area: Area2D = null
var _prompt_label: Label = null
var _fade_layer: CanvasLayer = null
var _fade_overlay: ColorRect = null
var _shop_screen: CanvasLayer = null

var _exterior_door_pos: Vector2 = FALLBACK_EXTERIOR_DOOR_POS
var _exterior_return_pos: Vector2 = FALLBACK_EXTERIOR_DOOR_POS + EXTERIOR_RETURN_OFFSET
var _interior_spawn_local: Vector2 = FALLBACK_SPAWN_POS
var _anvil_local: Vector2 = Vector2.INF
var _near_entrance: bool = false
var _transitioning: bool = false
var _inside: bool = false
var _door_cells: Array[Vector2i] = []
var _backdrop: ColorRect = null
var _outside_style: StringName = OUTSIDE_STYLE


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_locate_exterior_door()
	_spawn_interior()
	_create_entrance_trigger()
	_create_exit_trigger()
	_create_prompt_ui()


# ------------------------------------------------------------------ dış kapı

func _locate_exterior_door() -> void:
	_exterior_door_pos = FALLBACK_EXTERIOR_DOOR_POS
	var layer: TileMapLayer = get_node_or_null(EXTERIOR_DOOR_LAYER_PATH) as TileMapLayer
	if layer != null:
		var cells: Array[Vector2i] = layer.get_used_cells()
		if not cells.is_empty():
			var min_x: int = cells[0].x
			var max_x: int = cells[0].x
			var max_y: int = cells[0].y
			for c: Vector2i in cells:
				min_x = mini(min_x, c.x)
				max_x = maxi(max_x, c.x)
				max_y = maxi(max_y, c.y)
			var tile: Vector2 = Vector2(layer.tile_set.tile_size) if layer.tile_set != null else Vector2(16.0, 16.0)
			var left: Vector2 = layer.to_global(layer.map_to_local(Vector2i(min_x, max_y)))
			var right: Vector2 = layer.to_global(layer.map_to_local(Vector2i(max_x, max_y)))
			_exterior_door_pos = Vector2((left.x + right.x) * 0.5, left.y + tile.y * 0.5) ## kapının alt kenarının ortası
	_exterior_return_pos = _exterior_door_pos + EXTERIOR_RETURN_OFFSET


func _create_entrance_trigger() -> void:
	_entrance_area = Area2D.new()
	_entrance_area.name = "WeaponShopEntranceTrigger"
	_entrance_area.collision_layer = 0
	_entrance_area.collision_mask = 2 ## bkz. main.tscn Player collision_layer = 2
	_entrance_area.position = _exterior_door_pos + Vector2(0.0, 8.0)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = EXTERIOR_TRIGGER_RADIUS
	shape.shape = circle
	_entrance_area.add_child(shape)
	add_child(_entrance_area)
	_entrance_area.body_entered.connect(_on_entrance_body_entered)
	_entrance_area.body_exited.connect(_on_entrance_body_exited)


func _on_entrance_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_near_entrance = true


func _on_entrance_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_near_entrance = false


# ------------------------------------------------------------------ iç mekan

func _spawn_interior() -> void:
	_interior = InteriorScene.instantiate()
	_interior.position = INTERIOR_OFFSET
	_interior.visible = false
	add_child(_interior)
	## Derinlik (y-sıralama, bkz. depth_occluders.gd): oyuncu bir masanın/ocağın/rafın ARKASINA geçince onun altında kalır.
	DepthOccludersScript.new().setup_interior(_interior, DepthOccludersScript.SMITHY_INTERIOR_LAYERS)

	var door_layer: TileMapLayer = _find_layer(EXIT_DOOR_LAYER)
	if door_layer != null:
		_door_cells = door_layer.get_used_cells()
	var marker: TileMapLayer = _find_layer(ANVIL_MARKER_LAYER)
	if marker != null:
		marker.visible = false ## işaretleyici katman: örsün üstüne çizilmesin
		var mc: Array[Vector2i] = marker.get_used_cells()
		if not mc.is_empty():
			_anvil_local = marker.position + marker.map_to_local(mc[0])
	for child: Node in _interior.get_children():
		if child is TileMapLayer and FRONT_LAYERS.has(String(child.name).to_lower()):
			(child as TileMapLayer).z_index = FRONT_Z
	_interior_spawn_local = _compute_spawn(door_layer)

	var floor_layer: TileMapLayer = _find_layer("floor")
	if floor_layer != null:
		_add_bounds(floor_layer)
	_add_collisions()
	_hide_wall_filler()
	_add_backdrop()
	set_outside_style(_outside_style)


func _find_layer(layer_name_lower: String) -> TileMapLayer:
	if _interior == null:
		return null
	for child: Node in _interior.get_children():
		if child is TileMapLayer and String(child.name).to_lower() == layer_name_lower:
			return child as TileMapLayer
	return null


## Doğma noktası: SOL kapı hücresinin ortasının yukarısı (iç mekan yerelinde). İki hücrenin ortası bir hücre sınırına denk gelip
## yandaki duvar karosuna değiyordu (oyuncu yarıçapı 8 px) - hücrenin kendi ortası komşusuyla pay bırakır.
func _compute_spawn(door_layer: TileMapLayer) -> Vector2:
	if door_layer == null or _door_cells.is_empty():
		return FALLBACK_SPAWN_POS
	var left: Vector2 = door_layer.position + door_layer.map_to_local(_door_cells[0])
	for c: Vector2i in _door_cells:
		var p: Vector2 = door_layer.position + door_layer.map_to_local(c)
		if p.x < left.x:
			left = p
	return left + Vector2(0.0, -SPAWN_ABOVE_DOOR)


## Zemin dikdörtgeninin dışına görünmez sınır (katman hücreleri duvarı her kenarda kapsamıyor - ör. sol kenar).
func _add_bounds(floor_layer: TileMapLayer) -> void:
	var used: Rect2i = floor_layer.get_used_rect()
	if used.size == Vector2i.ZERO:
		return
	var tile: Vector2 = Vector2(floor_layer.tile_set.tile_size) if floor_layer.tile_set != null else Vector2(16.0, 16.0)
	var half: Vector2 = tile * 0.5
	var tl: Vector2 = floor_layer.position + floor_layer.map_to_local(used.position) - half
	var br: Vector2 = floor_layer.position + floor_layer.map_to_local(used.position + used.size - Vector2i.ONE) + half
	var size: Vector2 = br - tl
	var center: Vector2 = (tl + br) * 0.5
	var t: float = 16.0
	var body := StaticBody2D.new()
	body.name = "WeaponShopBounds"
	body.collision_layer = INTERIOR_COLLISION_LAYER
	body.collision_mask = 0
	body.position = INTERIOR_OFFSET
	add_child(body)
	for seg: Array in [
			[Vector2(center.x, tl.y - t * 0.5), Vector2(size.x + t * 2.0, t)],
			[Vector2(center.x, br.y + t * 0.5), Vector2(size.x + t * 2.0, t)],
			[Vector2(tl.x - t * 0.5, center.y), Vector2(t, size.y + t * 2.0)],
			[Vector2(br.x + t * 0.5, center.y), Vector2(t, size.y + t * 2.0)]]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = seg[1]
		shape.shape = rect
		shape.position = seg[0]
		body.add_child(shape)


## Çarpışması olan katmanların hücrelerini (bkz. FULL_COLLISION_LAYERS: duvarlar tam, eşyalar ayak izi) tek ızgarada birleştirip
## dikdörtgenlere böler (house_interior.gd ile aynı yöntem); kapı hücreleri her zaman açık bırakılır (duvar katmanı aynı hücreyi
## doldurmuş olsa bile çıkış erişilebilir olsun).
func _add_collisions() -> void:
	var wall_cells: Dictionary = {}
	var object_cells: Dictionary = {}
	var tile_size := Vector2i(16, 16)
	var origin := Vector2.ZERO
	for child: Node in _interior.get_children():
		var layer := child as TileMapLayer
		if layer == null or NO_COLLISION_LAYERS.has(String(layer.name).to_lower()):
			continue
		if layer.tile_set != null:
			tile_size = layer.tile_set.tile_size
		origin = layer.position
		var used: Array[Vector2i] = layer.get_used_cells()
		var used_set: Dictionary = {}
		for cell: Vector2i in used:
			used_set[cell] = true
		var full: bool = FULL_COLLISION_LAYERS.has(String(layer.name).to_lower())
		for cell: Vector2i in used:
			## Eşya katmanı: sütunun en alt karosu (altında aynı katmandan karo yok) = nesnenin ayağı.
			if full:
				wall_cells[cell] = true
			elif not used_set.has(Vector2i(cell.x, cell.y + 1)):
				object_cells[cell] = true
	if not _door_cells.is_empty():
		var lo: Vector2i = _door_cells[0]
		var hi: Vector2i = _door_cells[0]
		for c: Vector2i in _door_cells:
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
		for y in range(lo.y - LOBBY_DEPTH, hi.y + 1):
			for x in range(lo.x - LOBBY_SIDE, hi.x + LOBBY_SIDE + 1):
				object_cells.erase(Vector2i(x, y))
	var cells: Dictionary = wall_cells.duplicate()
	cells.merge(object_cells)
	for c: Vector2i in _door_cells:
		cells.erase(c)
	if cells.is_empty():
		return
	var body := StaticBody2D.new()
	body.name = "WeaponShopCollision"
	body.collision_layer = INTERIOR_COLLISION_LAYER
	body.collision_mask = 0
	body.position = INTERIOR_OFFSET
	add_child(body)
	for rect: Rect2i in HouseScript._merge_cells_into_rects(cells):
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(rect.size.x * tile_size.x, rect.size.y * tile_size.y)
		shape.shape = box
		shape.position = origin + Vector2(rect.position.x * tile_size.x, rect.position.y * tile_size.y) + box.size * 0.5
		body.add_child(shape)


## Duvar katmanlarındaki "dolgu" karosu (paketin koyu arduvaz kütlesi: en sık tekrar eden karo), ZEMİN DİKDÖRTGENİNİN DIŞINDA görsel
## olarak silinir - oda dışı ev içindeki gibi düz siyah olsun (aksi halde odanın çevresinde açık renkli bir dikdörtgen görünüyordu).
## Zemin dikdörtgeninin İÇİNDEKİ dolgu kalır: odanın girintili köşelerindeki zemin karolarını örtüyor (silinince zemin sızıyordu).
## Çarpışma bundan ÖNCE hücrelerden üretildiği için duvar kütlesi katı kalır (bkz. _add_collisions, çağrı sırası).
func _hide_wall_filler() -> void:
	var floor_layer: TileMapLayer = _find_layer("floor")
	if floor_layer == null:
		return
	var floor_rect: Rect2i = floor_layer.get_used_rect()
	for layer_name: String in FULL_COLLISION_LAYERS:
		var layer: TileMapLayer = _find_layer(layer_name)
		if layer == null:
			continue
		var counts: Dictionary = {}
		for cell: Vector2i in layer.get_used_cells():
			var key: String = "%d|%s|%d" % [layer.get_cell_source_id(cell), str(layer.get_cell_atlas_coords(cell)), layer.get_cell_alternative_tile(cell)]
			counts[key] = int(counts.get(key, 0)) + 1
		var filler: String = ""
		var best: int = 0
		for k: String in counts:
			if int(counts[k]) > best:
				best = int(counts[k])
				filler = k
		if filler == "" or best < 20: ## gerçek bir dolgu karosu değil (küçük/özel harita) - dokunma
			continue
		for cell: Vector2i in layer.get_used_cells():
			var key2: String = "%d|%s|%d" % [layer.get_cell_source_id(cell), str(layer.get_cell_atlas_coords(cell)), layer.get_cell_alternative_tile(cell)]
			if key2 == filler and not floor_rect.has_point(cell):
				layer.erase_cell(cell)


## Odanın dışı düz siyah (house_interior.gd _add_black_backdrop); katmanların ARKASINDA çizilir.
func _add_backdrop() -> void:
	var rect := ColorRect.new()
	rect.name = "IndoorBackdrop"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.0, 0.0, 0.0, 1.0)
	rect.position = Vector2(-BACKDROP_SIZE, -BACKDROP_SIZE)
	rect.size = Vector2(BACKDROP_SIZE * 2.0, BACKDROP_SIZE * 2.0)
	_interior.add_child(rect)
	_interior.move_child(rect, 0)
	_backdrop = rect


## Oda dışının görünümünü ayarlar (bkz. OUTSIDE_STYLE) - çalışma anında değiştirilebilir (karşılaştırma görüntüleri için).
func set_outside_style(style: StringName) -> void:
	_outside_style = style
	if _backdrop != null:
		_backdrop.color = WALL_SLATE if style == &"match" else Color(0.0, 0.0, 0.0, 1.0)
	var mat: ShaderMaterial = null
	if style == &"clean":
		var sh := Shader.new()
		sh.code = SLATE_KEY_SHADER
		mat = ShaderMaterial.new()
		mat.shader = sh
	for layer_name: String in FULL_COLLISION_LAYERS:
		var layer: TileMapLayer = _find_layer(layer_name)
		if layer != null:
			layer.material = mat


## Çıkış: "blacksmith kapı iç" katmanının her hücresi için bir alan (oyuncunun gövdesi karoya değince tetiklenir).
func _create_exit_trigger() -> void:
	_exit_area = Area2D.new()
	_exit_area.name = "WeaponShopExitTrigger"
	_exit_area.collision_layer = 0
	_exit_area.collision_mask = 2
	_exit_area.position = INTERIOR_OFFSET
	var door_layer: TileMapLayer = _find_layer(EXIT_DOOR_LAYER)
	if door_layer == null or _door_cells.is_empty():
		push_warning("WeaponShop: iç sahnede '%s' katmanı yok/boş - yedek çıkış alanı kullanılıyor" % EXIT_DOOR_LAYER)
		var fallback := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 24.0
		fallback.shape = circle
		fallback.position = FALLBACK_EXIT_POS
		_exit_area.add_child(fallback)
	else:
		var tile: Vector2 = Vector2(door_layer.tile_set.tile_size) if door_layer.tile_set != null else Vector2(16.0, 16.0)
		for cell: Vector2i in _door_cells:
			var shape := CollisionShape2D.new()
			var box := RectangleShape2D.new()
			box.size = tile
			shape.shape = box
			shape.position = door_layer.position + door_layer.map_to_local(cell)
			_exit_area.add_child(shape)
	add_child(_exit_area)
	_exit_area.body_entered.connect(_on_exit_body_entered)


func _on_exit_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or _transitioning or not _inside:
		return
	_exit()


# ------------------------------------------------------------------ arayüz ipucu

func _create_prompt_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WeaponShopPromptLayer"
	layer.layer = 50
	add_child(layer)
	_prompt_label = Label.new()
	_prompt_label.name = "InteractPrompt"
	_prompt_label.add_theme_font_size_override("font_size", 24)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.offset_left = -240.0
	_prompt_label.offset_right = 240.0
	## house_interior.gd ile aynı: alttaki oyuncu paneli (hud.gd dock) ~-211'e kadar çıkıyor - ipucu onun üstünde.
	_prompt_label.offset_top = -262.0
	_prompt_label.offset_bottom = -222.0
	_prompt_label.visible = false
	layer.add_child(_prompt_label)


func _show_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.add_to_group(&"interact_prompt") ## telefonda ETKİLEŞİM düğmesi bu uyarı görünürken çıkar (touch_controls.gd)
	_prompt_label.visible = true


func _hide_prompt() -> void:
	if _prompt_label != null and _prompt_label.visible:
		_prompt_label.visible = false


# ------------------------------------------------------------------ her kare

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if not is_instance_valid(_player):
			return
	if _transitioning:
		return
	## Oyuncu ölürse/yere düşerse ekran kapanır (ölüm ekranı üstüne binmesin).
	if is_instance_valid(_shop_screen) and (_player.get("is_dead") == true or _player.get("is_downed") == true):
		_shop_screen.call("_on_close_pressed")
	var interact: bool = Input.is_action_just_pressed("interact") and not bool(_player.get("is_chat_typing"))
	var key_label: String = GameManager.get_action_key_label("interact")
	if _inside:
		if is_instance_valid(_shop_screen):
			_hide_prompt()
		elif _near_anvil() and _player.get("is_dead") != true:
			_show_prompt("Silah ve kalkan almak için %s tuşuna bas" % key_label)
			if interact:
				_open_shop()
		else:
			_hide_prompt()
		return
	## Dışarıda: kapının yanında giriş ipucu. Ev içindeyken (HouseInterior) buraya hiç gelinmez - o oyuncu is_indoors.
	if _near_entrance and not bool(_player.get("is_indoors")) and _player.get("is_dead") != true and _player.get("is_downed") != true:
		_show_prompt("Demirciye girmek için %s tuşuna bas" % key_label)
		if interact:
			_enter()
	else:
		_hide_prompt()


func _near_anvil() -> bool:
	if not _anvil_local.is_finite():
		return false
	return _player.global_position.distance_to(INTERIOR_OFFSET + _anvil_local) <= ANVIL_INTERACT_RADIUS


## true: bu dünya konumu demirci iç mekanının içinde (traveling_merchant.gd uzak oyuncunun HARİTADAKİ konumunu bulurken kullanır).
func is_interior_position(pos: Vector2) -> bool:
	return pos.distance_to(INTERIOR_OFFSET) < 3000.0


## Bu iç mekandaki bir oyuncunun HARİTADAKİ karşılığı (dükkanın kapısının önü).
func get_exterior_anchor_pos() -> Vector2:
	return _exterior_return_pos


func is_inside() -> bool:
	return _inside


# ------------------------------------------------------------------ giriş / çıkış

func _open_shop() -> void:
	if is_instance_valid(_shop_screen):
		return
	if _player.has_method("clear_input_state"):
		_player.call("clear_input_state")
	_shop_screen = ShopScreenScript.new()
	_shop_screen.name = "WeaponShopScreen"
	var host: Node = get_tree().current_scene if get_tree().current_scene != null else self
	host.add_child(_shop_screen)
	_shop_screen.call("setup", _player)
	_hide_prompt()


func _enter() -> void:
	_near_entrance = false
	_transitioning = true
	await _fade_transition(_do_enter)
	_transitioning = false


func _exit() -> void:
	_transitioning = true
	if is_instance_valid(_shop_screen):
		_shop_screen.call("_on_close_pressed")
	await _fade_transition(_do_exit)
	_transitioning = false


## Gerçek ışınlama/durum değişimi (fade yok - testler ve geçiş ortasında çağrılır). house_interior.gd _do_enter_house ile aynı bayraklar.
func _do_enter() -> void:
	_player.global_position = INTERIOR_OFFSET + _interior_spawn_local
	_player.reset_physics_interpolation() ## ışınlama: kamera eski yerden kaymasın (bkz. physics_interp.gd)
	_player.is_indoors = true
	_player.collision_mask = int(_player.collision_mask) | INTERIOR_COLLISION_LAYER
	_interior.visible = true
	_inside = true
	_near_entrance = false
	_set_combat_visuals_hidden(true)
	_set_outdoor_atmosphere_enabled(false)
	_hide_prompt()


func _do_exit() -> void:
	_player.global_position = _exterior_return_pos
	_player.reset_physics_interpolation()
	_player.is_indoors = false
	_player.collision_mask = int(_player.collision_mask) & ~INTERIOR_COLLISION_LAYER
	_interior.visible = false
	_inside = false
	_set_combat_visuals_hidden(false)
	_set_outdoor_atmosphere_enabled(true)
	_hide_prompt()


func _set_combat_visuals_hidden(hidden: bool) -> void:
	if is_instance_valid(_player) and _player.has_method("set_combat_active"):
		_player.set_combat_active(not hidden)


## Rüzgar katmanı + ortam müziği (ev içiyle aynı): mantık HouseInterior'da, burada tekrar yazılmaz.
func _set_outdoor_atmosphere_enabled(enabled: bool) -> void:
	var house: Node = get_node_or_null("../HouseInterior")
	if house != null and house.has_method("_set_outdoor_atmosphere_enabled"):
		house.call("_set_outdoor_atmosphere_enabled", enabled)


func _ensure_fade_overlay() -> void:
	if _fade_layer and is_instance_valid(_fade_layer):
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.name = "WeaponShopFadeLayer"
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_fade_layer.layer = 95
	add_child(_fade_layer)
	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_overlay)


func _fade_transition(apply_change: Callable) -> void:
	_ensure_fade_overlay()
	var tw_in := create_tween()
	tw_in.tween_property(_fade_overlay, "color:a", 1.0, FADE_DURATION)
	await tw_in.finished
	apply_change.call()
	var tw_out := create_tween()
	tw_out.tween_property(_fade_overlay, "color:a", 0.0, FADE_DURATION)
	await tw_out.finished
