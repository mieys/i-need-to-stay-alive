extends Node

## DERİN ORMAN - Kuzey "Kadim Kara Orman" / Batı "Kızıl Bataklık" / Doğu "Işıyan Kayalıklar" / Güney "Sisli Sazlık" (madde 359/360/361): GERÇEK
## baked haritada yeni katmanlar dolu, set parçaları engel (TerrainCollision "deep_forest") ve sadece dört bölgede, bölge maskesi doğru kanalda
## (evde boş), harita shader'larının HEPSİ bölge renk ayarını (harita_renk_d / harita_renk_bitki_d) çağırıyor, bölge zemini globali var,
## bölge ışıkları sadece bölgede ve doğru türde doğuyor; zindan girişleri haritada (animasyonlu, engel) ve duyurular bir kez çıkıyor.
## Madde 385: Batı ve Doğu KALDIRILDI (maske G/B kanalı boş, o alanlarda derin orman karosu yok; zindan girişleri Et Kuyusu + Boynuzlu Kapı
## yerinde, bölge numaraları aynı), Kuzey kuzeybatıya uzadı (aynı derinlik).
## Madde 387: Güney batısındaki çayıra uzadı (kanal A); çayırın toprak yolu/açıklığı ve soldaki maden toprağı bölge zemini almaz.

const HaritaScene: PackedScene = preload("res://scenes/harita_baked.tscn")
const TerrainCollisionScript := preload("res://scripts/terrain_collision.gd")
const DeepForestFxScript := preload("res://scripts/deep_forest_fx.gd")
const DeepForestLoreScript := preload("res://scripts/deep_forest_lore.gd")
const PlacesScript := preload("res://scripts/deep_forest_places.gd")
const MAP_SHADERS: Array[String] = [
	"res://scenes/derinlik_on_katman.gdshader", "res://scenes/mini çim renk.gdshader", "res://scenes/orman_parcalari_doku.gdshader",
	"res://scenes/saklanma_calilik.gdshader", "res://scenes/sallanan ağaç.gdshader", "res://scenes/sallanan ot.gdshader", "res://scenes/su.gdshader",
	"res://scenes/toprak kir.gdshader", "res://scenes/çimen yaprak.gdshader", "res://shaders/harita_renk_duz.gdshader", "res://shaders/oakley_agac.gdshader",
]
## Bölge zemini artık Harita.tmx'te gerçek karolar (madde 363): bu shader'lar onu YENİDEN hesaplamamalı (iki kez uygulanırdı).
const GROUND_SHADERS: Array[String] = [
	"res://scenes/toprak kir.gdshader", "res://scenes/çimen yaprak.gdshader", "res://scenes/orman_parcalari_doku.gdshader", "res://shaders/harita_renk_duz.gdshader",
	"res://scenes/mini çim renk.gdshader",
]
const GROUND_LAYER := "Yer/Derin orman zemini"
const GROUND_TSX := "res://harita/Derin orman zemin 01.tsx" ## madde 372: zemin atlası ~1000 karoluk parçalara bölünmüş (01..NN)
const MAX_TILES_PER_SOURCE := 2500 ## TileSetAtlasSource.create_tile karesel yavaşlar (14.000 karo = +4,5 sn harita yüklemesi)
const OBJ_LAYER := "Shader Eklenecek/Derin orman nesneleri"
const PIT_LAYER := "Shader Eklenecek/Derin orman çukurları"
const THRONE_FOOT := Vector2i(120, 17) ## place_derin_orman.py KUZEY fixed "taht_b"
const NORTH_CELL := Vector2i(150, 15)
const WEST_CELL := Vector2i(30, 30) ## madde 385: eski Batı'nın kuzeyi = artık Kuzey'in kuzeybatı uzantısı
const OLD_WEST_CELL := Vector2i(30, 100) ## eski Batı'nın güneyi (madde 385: bölge değil)
const EAST_CELL := Vector2i(232, 113) ## eski Doğu (madde 385: bölge değil); görüş alanında Kuzey yok
const REMOVED_PIECES: Array[String] = ["dev_goz", "et_halka", "heykel", "yilan_iskelet", "kule_yikik"] ## kaldırılan bölgelerin set parçaları
const SOUTH_CELL := Vector2i(140, 215)
const SOUTH_WEST_CELL := Vector2i(60, 225) ## madde 387: Güney'in batı çayırı uzantısı
const MEADOW_ROAD_CELL := Vector2i(42, 192) ## çayırın üstündeki toprak açıklık (madde 387: bölge değil, toprak olduğu gibi)
const MINE_DIRT_CELL := Vector2i(10, 220) ## sol alt maden toprağı (uçurumun ardı, bölge değil)
const HOUSE_CELL := Vector2i(120, 80)
const KOKU := Vector2(-2.0, 21.0)

var _main: Node2D = null
var _harita: Node2D = null


func _load_map() -> void:
	_main = Node2D.new()
	_main.name = "TestMain"
	_harita = HaritaScene.instantiate()
	_harita.name = "Harita"
	_harita.position = KOKU ## gerçek oyundaki konum (main.tscn)
	_main.add_child(_harita)
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	GameManager._terrain_layers_searched = false
	GameManager._map_world_rect_searched = false
	TerrainCollisionScript.reset()


func _unload_map() -> void:
	if is_instance_valid(_main):
		_main.free()
	_main = null
	_harita = null
	get_tree().current_scene = null
	GameManager._terrain_su_layer = null
	GameManager._terrain_ev_layer = null
	GameManager._terrain_forest_layer = null
	GameManager._terrain_layers_searched = false
	GameManager._map_world_rect_searched = false
	TerrainCollisionScript.reset()


func _cell_center(c: Vector2i) -> Vector2:
	return KOKU + (Vector2(c) + Vector2(0.5, 0.5)) * 16.0


## Kuzey + kuzeybatı uzantısı (y <= 59, tüm genişlik; Boynuzlu Kapı grubu da bu şeritte) / Güney + batı çayırı (25 <= x <= 210, y >= 176)
## kutuları - kutu kenarları 7 hücre dalgalı (madde 361 2. tur) + parça taşmaları için pay. Madde 385: Batı / Doğu kutuları kalktı.
func _in_zones(c: Vector2i) -> bool:
	return (c.y >= -2 and c.y <= 59) or (c.x >= 25 and c.x <= 210 and c.y >= 176)


func test_new_layers_present_and_blocking() -> void:
	_load_map()
	var min_cells: Dictionary = {"Shader Eklenecek/Ağaç ölü": 100, OBJ_LAYER: 100, "Shader Eklenecek/Derin orman süsleri": 100, PIT_LAYER: 6}
	for path: String in min_cells:
		var l: TileMapLayer = _harita.get_node_or_null(path) as TileMapLayer
		assert(l != null, "katman yok: " + path)
		assert(l.get_used_cells().size() > int(min_cells[path]), "katman boş: %s (%d)" % [path, l.get_used_cells().size()])
		## hepsi tepe arkası bölgelerinde (oyun alanının üst/batı/doğu/güney kenarı)
		for c: Vector2i in l.get_used_cells():
			assert(_in_zones(c), "katman bölge dışına taşıyor: %s %s" % [path, str(c)])
	var forest: TileMapLayer = _harita.get_node("Orman parçaları/Orman parçaları")
	var cells: Dictionary = TerrainCollisionScript.ensure(forest)
	assert(int(TerrainCollisionScript.stats.get("deep_forest", 0)) > 10, "set parçaları engel değil: %s" % str(TerrainCollisionScript.stats))
	## kemik tahtın tabanı engel (ayak izi 15 px yukarı kaydırılır -> taban hücresi ya da bir üstü)
	var blocked: bool = false
	for dx in range(-2, 3):
		for dy in range(-2, 1):
			if cells.has(THRONE_FOOT + Vector2i(dx, dy)):
				blocked = true
	assert(blocked, "kemik taht tabanı engel değil")
	for c: Vector2i in TerrainCollisionScript.by_category["deep_forest"]:
		assert(_in_zones(c), "derin orman engeli bölge dışında: %s" % str(c))
	_unload_map()


## Madde 361: üç tehlikeli bölgenin her birinde TEK zindan girişi; karoları doğru katmanda, Kemik Mahzeni + Boynuzlu Kapı animasyonlu,
## Et Kuyusu (zemine gömülü çukur) ayak izinin ortası da engel (üstünden yürünmez). Madde 385: Batı/Doğu kalktı ama kapıları AYNI hücrede,
## aynı sırada (zindan eşlemesi = GATES dizini) ve eski bölge numarasıyla (kapı halesi rengi / yükselen ışık türü) kaldı.
func test_dungeon_gates_on_map() -> void:
	var zones: Array[int] = []
	for g: Dictionary in PlacesScript.GATES:
		zones.append(int(g["zone"]))
	assert(zones == [0, 1, 2], "zindan kapıları sırası/bölge numarası değişti (güney yok): %s" % str(zones))
	var gate_cells: Array[Vector2i] = []
	for g: Dictionary in PlacesScript.GATES:
		gate_cells.append(g["cell"])
	assert(gate_cells == [Vector2i(207, 17), Vector2i(39, 32), Vector2i(241, 53)], "zindan kapısı yer değiştirdi: %s" % str(gate_cells))
	_load_map()
	var forest: TileMapLayer = _harita.get_node("Orman parçaları/Orman parçaları")
	var cells: Dictionary = TerrainCollisionScript.ensure(forest)
	for g: Dictionary in PlacesScript.GATES:
		var foot: Vector2i = g["cell"]
		var path: String = PIT_LAYER if String(g["name"]) == "Et Kuyusu" else OBJ_LAYER
		var l: TileMapLayer = _harita.get_node(path) as TileMapLayer
		assert(l.get_cell_source_id(foot) != -1 or l.get_cell_source_id(foot + Vector2i(0, -1)) != -1, "kapı karosu yok: %s %s" % [g["name"], str(foot)])
		if String(g["name"]) != "Et Kuyusu":
			## kapının gövdesindeki bir karo animasyonlu (YATI -> animation_frames_count)
			var animated: bool = false
			for dy in range(0, 5):
				for dx in range(-2, 3):
					var c: Vector2i = foot + Vector2i(dx, -dy)
					var sid: int = l.get_cell_source_id(c)
					if sid == -1:
						continue
					var src := l.tile_set.get_source(sid) as TileSetAtlasSource
					if src != null and src.get_tile_animation_frames_count(l.get_cell_atlas_coords(c)) > 1:
						animated = true
			assert(animated, "kapı animasyonsuz: " + String(g["name"]))
		else:
			var hit: int = 0
			for dy in range(-4, 1):
				for dx in range(-1, 2):
					if cells.has(foot + Vector2i(dx, dy)):
						hit += 1
			assert(hit >= 6, "Et Kuyusu çukuru engel değil (%d)" % hit)
	_unload_map()


func test_zone_mask_channels() -> void:
	var fx: Node2D = DeepForestFxScript.new()
	add_child(fx)
	var north: float = fx.zone_at(_cell_center(NORTH_CELL))
	var house: float = fx.zone_at(_cell_center(HOUSE_CELL))
	assert(north > 0.9, "kuzey bölge değil: %f" % north)
	assert(fx.zone_kind(_cell_center(NORTH_CELL)) == 0, "kuzey türü")
	assert(fx.zone_kind(_cell_center(WEST_CELL)) == 0, "kuzeybatı Kadim Kara Orman değil (madde 385)")
	assert(fx.zone_at(_cell_center(OLD_WEST_CELL)) < 0.01 and fx.zone_at(_cell_center(EAST_CELL)) < 0.01, "kaldırılan Batı/Doğu hâlâ bölge")
	assert(fx.zone_kind(_cell_center(SOUTH_CELL)) == 3, "güney türü (maske alfa kanalı - .import fix_alpha_border kapalı mı?)")
	assert(fx.zone_at(_cell_center(SOUTH_WEST_CELL)) > 0.9 and fx.zone_kind(_cell_center(SOUTH_WEST_CELL)) == 3, "batı çayırı Sisli Sazlık değil (madde 387)")
	assert(fx.zone_at(_cell_center(MINE_DIRT_CELL)) < 0.01, "maden toprağı bölgede (madde 387)")
	assert(house < 0.01, "ev bölgede: %f" % house)
	## maske alfası RGB'yi bozmamış: güneyde kuzey/batı/doğu kanalı yok, kuzeyde güney yok
	var zs: Color = fx.zone_rgb(_cell_center(SOUTH_CELL))
	var zn: Color = fx.zone_rgb(_cell_center(NORTH_CELL))
	assert(zs.r + zs.g + zs.b < 0.05 and zn.a < 0.05, "maske kanalları karışmış: güney %s kuzey %s" % [str(zs), str(zn)])
	## dış çerçeve (oyun alanının hemen dışı) kenar değerini alır, daha uzağı (iç mekanlar 20000+ px) bölge değil
	assert(fx.zone_kind(Vector2(-200.0, 600.0)) == 0, "kuzeybatı kenarındaki dış çerçeve Kuzey bölgesi olmalı")
	assert(fx.zone_at(Vector2(-2000.0, -2000.0)) == 0.0 and fx.zone_at(Vector2(20400.0, 300.0)) == 0.0, "harita/çerçeve dışı bölge sayıldı")
	fx.free()


## Madde 385 ("ışıyan kayalıklar ve kızıl bataklığı sil ... silinecek biyomların zindan girişlerine v.b dokunma"): maskenin Batı (G) / Doğu (B)
## kanalı her yerde boş; eski Batı'nın güneyinde ve eski Doğu'nun Kuzey şeridi altındaki kısmında derin orman karosu (zemin dahil) yok,
## kaldırılan bölgelerin set parçaları yok. Kapıları test_dungeon_gates_on_map denetler.
func test_removed_zones_are_gone() -> void:
	var img: Image = (load(DeepForestFxScript.MASK_PATH) as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var gb: float = 0.0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var px: Color = img.get_pixel(x, y)
			gb = maxf(gb, maxf(px.g, px.b))
	assert(gb == 0.0, "maskede Batı/Doğu kanalı dolu: %f" % gb)
	for s: Dictionary in PlacesScript.SETS:
		assert(not REMOVED_PIECES.has(String(s["piece"])), "kaldırılan bölgenin set parçası duruyor: %s" % str(s))
	_load_map()
	for path: String in ["Shader Eklenecek/Ağaç ölü", OBJ_LAYER, "Shader Eklenecek/Derin orman süsleri", PIT_LAYER, GROUND_LAYER]:
		var l := _harita.get_node(path) as TileMapLayer
		for c: Vector2i in l.get_used_cells():
			var old_west: bool = c.x <= 80 and c.y >= 80 and c.y <= 148
			var old_east: bool = c.x >= 203 and c.y >= 80 and c.y <= 149
			assert(not (old_west or old_east), "kaldırılan bölgede derin orman karosu: %s %s" % [path, str(c)])
	_unload_map()


func test_all_map_shaders_use_zone_grade() -> void:
	var inc: String = FileAccess.get_file_as_string("res://shaders/harita_renk.gdshaderinc")
	assert(inc.find("global uniform sampler2D derin_orman_maske") >= 0 and inc.find("vec3 harita_renk_d(") >= 0)
	assert(inc.find("do_zemin_uygula") < 0 and inc.find("derin_orman_zemin ") < 0, "bölge zemini hâlâ shader'da (madde 363: karolarda)")
	assert(ProjectSettings.has_setting("shader_globals/derin_orman_maske"), "project.godot [shader_globals] derin_orman_maske yok")
	assert(not ProjectSettings.has_setting("shader_globals/derin_orman_zemin"), "kullanılmayan derin_orman_zemin globali kaldı")
	for p in MAP_SHADERS:
		var src: String = FileAccess.get_file_as_string(p)
		assert(src.find("harita_renk_d(COLOR.rgb") >= 0 or src.find("harita_renk_bitki_d(COLOR.rgb") >= 0 or src.find("harita_renk_agac_d(COLOR.rgb") >= 0,
			"bölge ayarı çağrılmıyor: " + p)
		assert(src.find("harita_renk(COLOR.rgb)") < 0, "eski çağrı kaldı: " + p)
		var sh: Shader = load(p) as Shader
		assert(sh != null and sh.code.find("harita_renk_") >= 0, "shader yüklenmedi: " + p)
	for p in GROUND_SHADERS:
		assert(FileAccess.get_file_as_string(p).find("do_zemin_uygula(") < 0, "zemin shader'ı bölge zeminini yeniden hesaplıyor: " + p)


## Madde 363: bölge zemini GERÇEK KAROLAR - pişmiş haritada "Yer/Derin orman zemini" Zemin Çimen'in hemen üstünde, dört bölgenin içi dolu (merkez
## hücreleri), evin önü boş; kıyı karolarının animasyonu korunmuş (pişmiş tileset'te animasyonlu karo var); TSX Tiled için diskte.
func test_zone_ground_is_real_tiles() -> void:
	assert(FileAccess.file_exists(GROUND_TSX), "Derin orman zemin 01.tsx yok")
	assert(not FileAccess.file_exists("res://harita/Derin orman zemin.tsx"), "eski tek parça zemin tileset'i kalmış")
	assert(FileAccess.get_file_as_string("res://harita/Harita.tmx").find('source="Derin orman zemin 01.tsx"') >= 0, "Harita.tmx zemin tileset'ini kullanmıyor")
	_load_map()
	var l: TileMapLayer = _harita.get_node_or_null(GROUND_LAYER) as TileMapLayer
	assert(l != null, "katman yok: " + GROUND_LAYER)
	var yer: Node = _harita.get_node("Yer")
	assert(l.get_index() == yer.get_node("Zemin Çimen").get_index() + 1, "zemin katmanı Zemin Çimen'in hemen üstünde değil")
	## hiçbir tileset kaynağı çok karolu olmamalı (yükleme süresi tuzağı), zemin birden çok kaynağa bölünmüş
	var big: int = 0
	var ground_sources: int = 0
	for i in range(l.tile_set.get_source_count()):
		var asrc := l.tile_set.get_source(l.tile_set.get_source_id(i)) as TileSetAtlasSource
		if asrc != null:
			big = maxi(big, asrc.get_tiles_count())
			if asrc.texture != null and asrc.texture.resource_path.contains("derin_orman_zemin_"):
				ground_sources += 1
	assert(big <= MAX_TILES_PER_SOURCE, "bir tileset kaynağında %d karo var (en çok %d): create_tile karesel yavaşlar" % [big, MAX_TILES_PER_SOURCE])
	assert(ground_sources >= 10, "zemin atlası parçalanmamış: %d kaynak" % ground_sources)
	assert(l.get_used_cells().size() > 20000, "zemin katmanı neredeyse boş: %d" % l.get_used_cells().size())
	for c: Vector2i in [NORTH_CELL, WEST_CELL, SOUTH_CELL, SOUTH_WEST_CELL]:
		assert(l.get_cell_source_id(c) != -1, "bölge merkezinde zemin karosu yok: %s" % str(c))
	for c: Vector2i in [HOUSE_CELL, OLD_WEST_CELL, EAST_CELL, MEADOW_ROAD_CELL, MINE_DIRT_CELL]:
		assert(l.get_cell_source_id(c) == -1, "bölge dışında bölge zemini var: %s" % str(c))
	var animated: int = 0
	var shore: TileMapLayer = _harita.get_node("Su/Su ayrıntılar 2") as TileMapLayer
	for c: Vector2i in shore.get_used_cells():
		## zemin atlası parçalara bölünmüş (madde 372): kıyı karosu hangi parçadaysa (derin_orman_zemin_NN) animasyonu o kaynakta
		var src := shore.tile_set.get_source(shore.get_cell_source_id(c)) as TileSetAtlasSource
		if src != null and src.texture != null and src.texture.resource_path.contains("derin_orman_zemin_"):
			if src.get_tile_animation_frames_count(shore.get_cell_atlas_coords(c)) > 1:
				animated += 1
	assert(animated > 100, "bölgedeki kıyı karoları animasyonunu kaybetmiş: %d" % animated)
	_unload_map()


func test_wisps_spawn_only_in_zone() -> void:
	var fx: Node2D = DeepForestFxScript.new()
	add_child(fx)
	## görüş alanını el ile ver: kuzeyin ortası / kuzeybatı (Kuzey türü) / güney -> o türün ışıkları; evin önü + kaldırılan Batı/Doğu -> hiç
	var cam := Camera2D.new()
	add_child(cam)
	cam.make_current()
	var spots: Array[Vector2i] = [NORTH_CELL, WEST_CELL, SOUTH_CELL, SOUTH_WEST_CELL, HOUSE_CELL, OLD_WEST_CELL, EAST_CELL]
	var kinds: Array[int] = [0, 0, 3, 3, -1, -1, -1]
	for k in range(spots.size()):
		cam.global_position = _cell_center(spots[k])
		fx.call("clear_motes")
		await get_tree().process_frame
		await get_tree().process_frame
		for _i in range(80):
			fx._process(0.1)
		var st: Dictionary = fx.debug_state()
		if kinds[k] >= 0:
			assert(int(st["motes"]) > 4, "bölgede ışık doğmadı (%s): %s" % [str(spots[k]), str(st)])
			assert(int((st["by_kind"] as Array)[kinds[k]]) * 2 > int(st["motes"]), "baskın tür yanlış (%s): %s" % [str(spots[k]), str(st)])
		else:
			assert(int(st["motes"]) == 0, "bölge dışında ışık doğdu (%s): %s" % [str(spots[k]), str(st)])
	cam.free()
	fx.free()


## Madde 361: yerel oyuncu bölgeye ilk girişte bölge duyurusu (bir kez), zindan kapısına yaklaşınca kapı duyurusu + hale güçlenir.
func test_zone_and_gate_notices_once() -> void:
	var fx: Node2D = DeepForestFxScript.new()
	add_child(fx)
	var lore: Node = DeepForestLoreScript.new()
	lore.set("fx", fx)
	add_child(lore)
	var p := Node2D.new()
	p.add_to_group("player")
	add_child(p)
	p.global_position = _cell_center(SOUTH_CELL)
	for _i in range(8):
		lore._process(0.25)
	var st: Dictionary = lore.debug_state()
	assert((st["zones"] as Array)[3] == true, "güney bölge duyurusu çıkmadı: %s" % str(st))
	assert((st["zones"] as Array)[0] == false, "girilmeyen bölge duyuruldu: %s" % str(st))
	var g0: Vector2 = DeepForestFxScript.gate_mouth(0)
	p.global_position = g0 + Vector2(0, 30)
	for _i in range(4):
		lore._process(0.25)
	st = lore.debug_state()
	assert((st["gates"] as Array)[0] == true, "kapıya yaklaşınca duyuru yok: %s" % str(st))
	assert(float((fx.get("_gate_boost") as Array)[0]) > 0.5, "kapı halesi güçlenmedi")
	p.global_position = _cell_center(HOUSE_CELL)
	for _i in range(4):
		lore._process(0.25)
	assert(float((fx.get("_gate_boost") as Array)[0]) < 0.01, "uzaklaşınca hale sönmedi")
	p.free()
	lore.free()
	fx.free()


## Madde 365 ("bazı bölgelerde ağaçlar bölgeleriyle uyumsuz görünüyor"): bölge içinde haritanın kendi ağaçlarından uymayan türler kalmadı
## (Kuzey/Doğu'da yuvarlak yapraklı + karnabahar taçlı, hiçbir bölgede palmiye/yonca/çiçekli ağaç), ağaç shader'ı bölgenin ağaç paletini
## uyguluyor ve paketten gelen bölge ağaçları ("Ağaç ölü") boyanmıyor. Türler atlas karosunun İÇ dikdörtgeniyle tanınır (x0, y0, x1, y1 dahil;
## tools/derin_orman/derin_orman_core.py AGAC_TURU); sadece_agac/gölgeli tileset'i pişmiş sahnede gömülü doku -> 800x192 boyundan tanınır.
const TREE_LAYERS: Array[String] = ["Shader Eklenecek/Ağaç 0", "Shader Eklenecek/Ağaç 1", "Shader Eklenecek/Ağaç 2"]
const BROADLEAF_RECTS: Dictionary = {
	"res://harita/Objects.png": [Rect2i(9, 5, 2, 4), Rect2i(10, 1, 2, 3), Rect2i(24, 1, 2, 3), Rect2i(23, 5, 3, 3), Rect2i(16, 5, 2, 3), Rect2i(18, 1, 4, 4)],
	"res://harita/köy insalar/Tiled_files/sade ağaç ve taş.png": [Rect2i(6, 1, 2, 4), Rect2i(12, 6, 2, 2), Rect2i(5, 5, 2, 4), Rect2i(14, 1, 2, 3)],
}
const TROPICAL_SIZE := Vector2i(800, 192)
const TROPICAL_RECTS: Array[Rect2i] = [Rect2i(43, 1, 3, 3), Rect2i(34, 6, 2, 2), Rect2i(39, 1, 2, 3), Rect2i(35, 1, 2, 3), Rect2i(27, 6, 2, 3)]


func _tree_kind(l: TileMapLayer, c: Vector2i) -> String:
	var src := l.tile_set.get_source(l.get_cell_source_id(c)) as TileSetAtlasSource
	if src == null or src.texture == null:
		return ""
	var at: Vector2i = l.get_cell_atlas_coords(c)
	if Vector2i(src.texture.get_size()) == TROPICAL_SIZE:
		for r: Rect2i in TROPICAL_RECTS:
			if r.has_point(at):
				return "tropik"
	for r: Rect2i in BROADLEAF_RECTS.get(src.texture.resource_path, []):
		if r.has_point(at):
			return "yaprak"
	return ""


func test_zone_trees_match_zone() -> void:
	var tree_src: String = FileAccess.get_file_as_string("res://scenes/sallanan ağaç.gdshader")
	assert(tree_src.find("harita_renk_agac_d(COLOR.rgb, world_orijin, bolge_boya)") >= 0, "ağaç shader'ı bölge ağaç paletini uygulamıyor")
	assert(FileAccess.get_file_as_string("res://shaders/harita_renk_duz.gdshader").find("do_agac_guc(") >= 0, "dış çerçeve ormanı ağaç paletinde değil")
	_load_map()
	var fx: Node2D = DeepForestFxScript.new()
	add_child(fx)
	var bad: Array[String] = []
	var seen: Array[int] = [0, 0, 0, 0]
	var outside: Dictionary = {"yaprak": 0, "tropik": 0}
	for path: String in TREE_LAYERS:
		var l := _harita.get_node(path) as TileMapLayer
		for c: Vector2i in l.get_used_cells():
			var p: Vector2 = _cell_center(c)
			if fx.zone_at(p) < 0.97:
				var k: String = _tree_kind(l, c)
				if k != "" and fx.zone_at(p) < 0.01:
					outside[k] += 1
				continue
			var z: int = fx.zone_kind(p)
			seen[z] += 1
			var kind: String = _tree_kind(l, c)
			if kind == "tropik" or (kind == "yaprak" and (z == 0 or z == 2)):
				bad.append("%s %s bölge %d %s" % [path.get_file(), str(c), z, kind])
	assert(bad.is_empty(), "bölgeye uymayan ağaç kaldı (%d): %s" % [bad.size(), str(bad.slice(0, 8))])
	assert(seen[0] > 300 and seen[1] == 0 and seen[2] == 0, "bölge ağaçları sayılmadı / kaldırılan bölgede ağaç sayıldı: %s" % str(seen))
	## tanıyıcı gerçekten çalışıyor: orta bölgede (dokunulmadı) yapraklı ve çiçekli/tropik ağaçlar tanınıyor
	assert(int(outside["yaprak"]) > 100 and int(outside["tropik"]) > 10, "ağaç türü tanınmıyor (atlas konumu değişti mi?): %s" % str(outside))
	## Ağaç 0/1/2 boyanır, paketin bölge ağaçları ("Ağaç ölü") boyanmaz; derinlik ön kopyası aynı değeri taşır
	load("res://scripts/tree_sway.gd").new().setup(_harita)
	var dead := _harita.get_node("Shader Eklenecek/Ağaç ölü") as TileMapLayer
	var a0 := _harita.get_node("Shader Eklenecek/Ağaç 0") as TileMapLayer
	assert(float((a0.material as ShaderMaterial).get_shader_parameter("bolge_boya")) == 1.0, "Ağaç 0 bölge boyası kapalı")
	assert(float((dead.material as ShaderMaterial).get_shader_parameter("bolge_boya")) == 0.0, "Ağaç ölü boyanıyor")
	fx.free()
	_unload_map()


## Madde 364 ("engeller var kaya obje v.b ama engel oluşturmuyorlar"): sahne nesnesi katmanlarındaki katı nesneler (kaya, kütük...) engel; ayak
## izinin ortasına (kökten 15 px yukarı kaydırılmış sorgu) yürünemez. Mantar/ot gibi küçük yumuşak nesneler engel DEĞİL. Derin orman nesnelerinin
## bandı boyla orantılı (büyük nesnede 12 px'ten kalın).
func test_props_are_solid_but_soft_plants_are_not() -> void:
	_load_map()
	var forest: TileMapLayer = _harita.get_node("Orman parçaları/Orman parçaları")
	TerrainCollisionScript.ensure(forest)
	assert(int(TerrainCollisionScript.stats.get("props", 0)) > 100, "sahne nesneleri engel değil: %s" % str(TerrainCollisionScript.stats))
	var helper: Node = load("res://scripts/depth_occluders.gd").new()
	var checked: int = 0
	var soft: int = 0
	for path: String in TerrainCollisionScript.PROP_LAYERS:
		var l := _harita.get_node_or_null(path) as TileMapLayer
		assert(l != null, "katman yok: " + path)
		for grp: Dictionary in TerrainCollisionScript.object_groups(helper, l):
			var bases: Dictionary = grp["bases"]
			var base_y: float = float(bases.values()[0])
			var xs: Array = []
			for c: Vector2i in bases:
				xs.append(c.x)
			var org: Vector2 = helper.cell_origin(l) ## object_bases kökleri de bu dünya kökünden
			var cx: float = org.x + (float(xs.min()) + float(xs.max()) + 1.0) * 0.5 * 16.0
			## ayak nesnenin tabanından 3 px yukarıda -> kök (gövde ortası) sorgusu FEET_SHIFT daha yukarıda
			var q := Vector2(cx, base_y - 3.0 - TerrainCollisionScript.FEET_SHIFT)
			if TerrainCollisionScript.is_solid_prop(grp):
				if float(grp["w"]) >= 24.0 and checked < 40:
					assert(GameManager.is_position_blocked_by_terrain(q), "katı nesnenin ortasına yürünüyor: %s %s" % [path, str(bases.keys()[0])])
					checked += 1
			elif float(grp["w"]) * float(grp["h"]) <= TerrainCollisionScript.PROP_SMALL_AREA and float(grp["red"]) + float(grp["green"]) > 0.3:
				soft += 1
	assert(checked >= 10, "denetlenen katı nesne az: %d" % checked)
	helper.free()
	_unload_map()
