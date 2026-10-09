extends Node

## DERİNLİK ÖN KATMANLARI (y-sıralama) - kullanıcı isteği (2026-10-08): "y ekseni sorununu çöz: bir şeyin arkasındayken karakter onun altında
## (nesne karakteri örter), önündeyken üstünde görünsün". Eskiden oyuncular z_index 1'de (haritanın tamamının üstünde) çizildiği için bir ağacın,
## evin ya da madenin ARKASINA geçince bile onların üstünde görünüyordu; sadece otlarda bu mantık vardı (grass_sway.gd).
##
## Neden Godot'un Y-Sort'u değil: sallanan ot.gdshader / grass_sway.gd başındaki gerekçe aynen geçerli - y-sıralama ortak y-sıralı bir ebeveyn ister;
## Main'e Y-Sort açmak yaratık/FX/küre/telegraph halkası sırasını oyunun her yerinde değiştirirdi. Bunun yerine otlarla AYNI yerel çözüm:
##  - Nesneler haritada aynen çizilir (herkesin altında, eskisi gibi).
##  - Katmanların bir KOPYASI z_index 2'de (oyuncuların üstünde) çizilir; shader kopyada SADECE kökü (yere değdiği çizgi) bir karakterin ayağından
##    AŞAĞIDA olan (yani karakterin önünde duran) nesne piksellerini ve SADECE o karakterin gövde dikdörtgeninde bırakır (derinlik_on_katman.gdshader).
##  - Karakter nesnenin arkasındayken (ayağı kökün üstünde) kopya hiçbir şey çizmez -> oyuncu önde kalır; "önündeyken" nesne zaten oyuncunun altında.
## Karakterler = yerel oyuncu + uzak oyuncu kuklaları (grass_sway.gd ile AYNI ayak/gövde ölçüleri). Tamamen yerel/kozmetik: ağ gerekmez.
##
## YARATIKLAR (2026-10-09, kullanıcı: "yaratıklar ağaçların ve evlerin üstünde yürüyor"): AYNI kural yaratıklara da uygulanır. Yaratık sayısı yüzlerce olabilir ve
## shader'a hepsi verilemez; bu yüzden her 2 karede bir SADECE görüntüdeki, bir nesne kümesine değen (altında/yanında kökü ayağından aşağıda ya da hemen yakınında
## olan nesne hücresi var: kaba ızgara `_coarse`, 32 px) en çok MAX_CREATURES yaratığın gövde dikdörtgeni `yaratiklar` dizisine yazılır. Açık arazide dizi boştur
## (shader döngüsü hiç çalışmaz). Gövde ölçüsü sprite karesinin görünen (opak) alanından, bir kez ölçülür (`creature_body`). Kopyalar z_index 3'te: öne alınmış
## (oyuncunun önündeki, z 2) yaratıklar da ağacın arkasındaysa örtülsün (bkz. creature_depth.gd).
##
## KÖK nasıl bulunur (hepsi haritadaki GERÇEK yerleşimden, oyun başında):
##  - AĞAÇLAR ("Shader Eklenecek/Ağaç 0/1/2"): sallanan ağaç shader'ının kendi hücre verisi zaten ağaç başına kökü taşıyor (tree_sway.gd, atlasta komşu
##    karo = aynı ağaç); kopya AYNI materyali (aynı köşe kaydırması: sallanma birebir örtüşür) + on_katman ile kullanır.
##  - BİNALAR (BUILDING_GROUPS): gruptaki katmanların (duvar, çatı, kapı, ayrıntı) dolu hücreleri 8-komşu bağlı bileşenlere ayrılır, her bina TEK köke sahip
##    (en alttaki opak satır) - çatı ile duvar farklı katmanda olsa da aynı anda önde/arkada kalır (yoksa kafa çatının, gövde duvarın altında/üstünde kalırdı).
##  - MADEN / çalı katmanları (OBJECT_LAYERS): atlasta komşu karolar (aynı kaynak + aynı çevirme) bir nesne; kök o nesnenin en alt opak satırı.
## Ormanlar ("Orman parçaları", plato/uçurum duvarları) ve zemin katmanları BİLEREK dışarıda: büyük bağlı bloklar, "kök" kavramı yok (oyuncu zaten
## orman duvarından geçemiyor, bkz. GameManager.is_position_blocked_by_forest).
## Tuzak: Tiled'da bu katman adları değişirse aşağıdaki sabitler güncellenmeli; bulunamayan katman sessizce atlanır (test_depth_occluders bulunduklarını sınar).

const EnemyQueryScript := preload("res://scripts/enemy_world/enemy_query.gd")
const SHADER_PATH := "res://scenes/derinlik_on_katman.gdshader"
const TREE_SHADER_PATH := "res://scenes/sallanan ağaç.gdshader"
const TREE_PARENT := "Shader Eklenecek"
const TREE_PREFIX := "Ağaç"
const FRONT_ROOT_NAME := "DerinlikOnKatman"
const MAX_CHARACTERS := 8
const MAX_CREATURES := 32 ## shader'daki `yaratiklar` dizisi uzunluğu (derinlik_on_katman.gdshader + sallanan ağaç.gdshader ile AYNI)
const FRONT_Z := 3 ## kopya katmanların z_index'i: oyuncular 1, oyuncunun önüne alınan yaratıklar 2 (creature_depth.gd)
const COARSE := 32.0 ## kaba nesne ızgarası hücre boyu (dünya px)
## Yaratığın ayağının bu kadar altına kadar kökü olan nesneler de "ilgili" sayılır: yaratık nesnenin ÖNÜNDEYSE de aynı pikselde başka bir varlığı
## örtmesin diye shader'ın bilmesi gerekir (shader orter(): önündeki varlık hep görünür kalır).
const FRONT_SLACK := 48.0
const CREATURE_UPDATE_FRAMES := 2
const CREATURE_VIEW_PAD := 120.0 ## görüş yarıçapına eklenen pay (yaratık gövdesi ekran dışından içeri taşar)
const BODY_FALLBACK := Vector2(24.0, 44.0)
const NEAR_CELLS := 3 ## ön eleme çevresi (kaba hücre = 96 px): yaratık gövdesinin yarı genişliği + ayak payı
const BODY_MARGIN := 1.15 ## ölçülen opak alana ek pay (animasyon kareleri birbirinden biraz farklı)
## Karakter ayak noktası / gövde (dünya px) - grass_sway.gd FEET_OFFSET/BODY_* ile AYNI (oyuncu kökü ölçek 0.5'te, sprite zemine ~+15 px'te değer).
const FEET_OFFSET := 15.0 * EntityScale.BODY_REL ## 2026-10-09: karakterler %15 küçüldü (eski ölçü 15 / 11 / 34)
const BODY_HALF_WIDTH := 11.0 * EntityScale.BODY_REL
const BODY_HEIGHT := 34.0 * EntityScale.BODY_REL
const OPAQUE_ALPHA := 0.4
const CELL := 16.0

## Birlikte tek yapı sayılan katmanlar (Harita'ya göre yol). Kapı/çatı/duvar/ayrıntı farklı katmanlarda ama aynı binanın parçaları.
const BUILDING_GROUPS: Array = [
	["ev/Blacksmith", "ev/blacksmith kapı", "ev/Ev ayrıntı", "ev/Ev", "ev/ev kapı", "ev/Ev Çatı 1"],
]
## Tek tek nesne katmanları (atlas komşuluğu = aynı nesne).
const OBJECT_LAYERS: Array = [
	"Etkileşimler/Maden", "Etkileşimler/Maden 1", "Shader Eklenecek/Animasyonsuz çalılar", "Düşman Üssü/Düşman üssü", "Düşman Üssü/Özel maden",
]

## Demirci iç mekanı (scenes/silah_saticisi_baked.tscn) mobilya katmanları - yere serili/duvara asılı süslerin (Various_objects, Torches_back) hiçbiri YOK:
## yassı bir nesne "önde" sayılırsa oyuncuyu ayağının üstünde örterdi.
const SMITHY_INTERIOR_LAYERS: Array = [
	"Boxes_grindstone_barrel_rack", "Forge_pillars_boxes", "Bellows_tannery_rack_table", "Tables_shields_w_weapon", "Örs",
]

var _front_root: Node2D = null
var _front_materials: Array[ShaderMaterial] = []
## Ağaç kopyaları asıl katmanın materyalini paylaşamaz (on_katman farklı) - sallanma gücü (rüzgar) asıldan kopyaya her karede taşınır.
var _tree_pairs: Array = [] ## [asıl materyal, kopya materyal]
var _image_cache: Dictionary = {}
var _rows_cache: Dictionary = {}
var _last_chars: Array[Vector4] = []
var _main: Node = null ## harita kökünün ebeveyni (Main): yaratık ayağı için _creature_foot_y
var _coarse: Dictionary = {} ## Vector2i(kaba hücre) -> o hücreye değen nesne hücrelerinin EN BÜYÜK kök y'si (sadece setup(); iç mekanda yok)
var _near: Dictionary = {} ## Vector2i(kaba hücre) -> true: bir nesne hücresine NEAR_CELLS kaba hücre içinde olan her hücre (ucuz ön eleme: açık arazideki yaratık tek sorguda elenir)
var _creatures_on: bool = false
var _creature_entries: Array[Vector4] = [] ## son yazılan (ayak x, ayak y, yarım genişlik, boy) listesi (testler/hata ayıklama)
var _creature_frame: int = 0
static var _body_cache: Dictionary = {} ## "doku|hframes|vframes" -> opak alan boyu (px, ölçeksiz)
## Bulunan/kurulan ön katmanlar (testler ve hata ayıklama için): [{"layer": asıl, "front": kopya, "mode": "tree"|"building"|"object"}]
var fronts: Array = []


## main.gd çağırır (TreeSway.setup'tan SONRA: ağaç materyalleri hazır olmalı). Harita/katmanlar yoksa sessizce hiçbir şey yapmaz.
func setup(harita: Node) -> void:
	if harita == null:
		return
	_begin(harita)
	_setup_trees(harita)
	for group: Array in BUILDING_GROUPS:
		_setup_building_group(harita, group)
	for path: String in OBJECT_LAYERS:
		var layer := harita.get_node_or_null(path) as TileMapLayer
		if layer != null and layer.tile_set != null and not layer.get_used_cells().is_empty():
			_setup_object_layer(layer)
	_main = harita.get_parent()
	_build_coarse()
	_creatures_on = not _coarse.is_empty()


## İç mekanlar (demirci, ev içi, seyyar satıcı arabası): kökün altındaki adı verilen mobilya/nesne katmanları atlas komşuluğuyla nesne sayılır (maden/çalı
## ile aynı kural), kopyalar iç mekan kökünün altına konur (kök gizlenirse kopyalar da gizlenir). Kök KONUMLANDIKTAN SONRA çağrılmalı (kökler dünya
## koordinatıyla hesaplanır). Zemin/duvar katmanlarını vermeyin.
func setup_interior(interior_root: Node, layer_names: Array) -> void:
	if interior_root == null:
		return
	_begin(interior_root)
	for layer_name: String in layer_names:
		var layer := interior_root.get_node_or_null(layer_name) as TileMapLayer
		if layer != null and layer.tile_set != null and not layer.get_used_cells().is_empty():
			_setup_object_layer(layer)


func _begin(root: Node) -> void:
	name = "DepthOccluders"
	root.add_child(self)
	_front_root = Node2D.new()
	_front_root.name = FRONT_ROOT_NAME
	_front_root.z_index = FRONT_Z
	root.add_child(_front_root)


# ------------------------------------------------------------------ kurulum

func _setup_trees(harita: Node) -> void:
	var parent: Node = harita.get_node_or_null(TREE_PARENT)
	if parent == null:
		return
	for child in parent.get_children():
		var layer := child as TileMapLayer
		if layer == null or layer.tile_set == null or not String(layer.name).begins_with(TREE_PREFIX):
			continue
		var src_mat := layer.material as ShaderMaterial
		if src_mat == null or src_mat.shader == null or src_mat.shader.resource_path != TREE_SHADER_PATH:
			continue ## TreeSway kurulmamış (test sahnesi): hücre verisi yok, kök bilinmez
		var mat: ShaderMaterial = _copy_material(src_mat)
		mat.set_shader_parameter("on_katman", true)
		var front: TileMapLayer = _make_front(layer, mat)
		_tree_pairs.append([src_mat, mat])
		_front_materials.append(mat)
		fronts.append({"layer": layer, "front": front, "mode": "tree", "bases": object_bases(layer)})


func _setup_building_group(harita: Node, paths: Array) -> void:
	var layers: Array[TileMapLayer] = []
	for path: String in paths:
		var layer := harita.get_node_or_null(path) as TileMapLayer
		if layer != null and layer.tile_set != null and not layer.get_used_cells().is_empty():
			layers.append(layer)
	if layers.is_empty():
		return
	var per_layer: Dictionary = building_bases(layers)
	for layer in layers:
		_add_object_front(layer, per_layer.get(layer, {}), "building")


## Birlikte tek yapı sayılan katmanların hücre kökleri: layer -> {harita hücresi -> kökün dünya y'si}. Katmanların dolu hücreleri 8-komşu bağlı bileşenlere
## ayrılır, her bileşen (bina) TEK köke sahip (bileşendeki en alt opak satır). Saf hesap: sahneye dokunmaz (collision de kullanır, bkz. terrain_collision.gd).
func building_bases(layers: Array) -> Dictionary:
	## Hücre (dünya sol-üst px) -> bu hücredeki karonun alt kenarının dünya y'si (sadece opak pikseli olan hücreler).
	var bottoms: Dictionary = {}
	for layer in layers:
		var ofset: Vector2 = _cell_origin(layer)
		for cell in layer.get_used_cells():
			var rows: Vector2i = _tile_rows(layer, cell)
			if rows.y < 0:
				continue
			var key := Vector2i(roundi(ofset.x + float(cell.x) * CELL), roundi(ofset.y + float(cell.y) * CELL))
			var bottom: float = float(key.y) + float(rows.y) + 1.0
			bottoms[key] = maxf(float(bottoms.get(key, -1.0e9)), bottom)
	## 8-komşu bağlı bileşenler: her bina tek kök (bileşendeki en alt kenar).
	var comp_base: Dictionary = {} ## hücre anahtarı -> bileşen kökü
	var step := Vector2i(int(CELL), int(CELL))
	for start: Vector2i in bottoms:
		if comp_base.has(start):
			continue
		var stack: Array[Vector2i] = [start]
		var members: Array[Vector2i] = []
		var seen: Dictionary = {start: true}
		var base: float = -1.0e9
		while not stack.is_empty():
			var k: Vector2i = stack.pop_back()
			members.append(k)
			base = maxf(base, float(bottoms[k]))
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					var nk: Vector2i = k + Vector2i(dx * step.x, dy * step.y)
					if (dx != 0 or dy != 0) and bottoms.has(nk) and not seen.has(nk):
						seen[nk] = true
						stack.append(nk)
		for m in members:
			comp_base[m] = base
	var result: Dictionary = {}
	for layer in layers:
		var cell_bases: Dictionary = {} ## harita hücresi -> kök
		var ofset: Vector2 = _cell_origin(layer)
		for cell in layer.get_used_cells():
			var key := Vector2i(roundi(ofset.x + float(cell.x) * CELL), roundi(ofset.y + float(cell.y) * CELL))
			if comp_base.has(key):
				cell_bases[cell] = comp_base[key]
		result[layer] = cell_bases
	return result


func _setup_object_layer(layer: TileMapLayer) -> void:
	_add_object_front(layer, object_bases(layer), "object")


## Tek katmandaki nesnelerin hücre kökleri: harita hücresi -> kökün dünya y'si. Nesne = atlasta komşu karolar (aynı kaynak + aynı çevirme); kök = nesnenin
## en alt opak satırı. Saf hesap (sahneye dokunmaz; collision de kullanır).
func object_bases(layer: TileMapLayer) -> Dictionary:
	var cells: Array[Vector2i] = layer.get_used_cells()
	var info: Dictionary = {} ## hücre -> [kaynak, atlas koordinatı, yatay çevrik mi]
	for cell in cells:
		var sid: int = layer.get_cell_source_id(cell)
		var td: TileData = layer.get_cell_tile_data(cell)
		info[cell] = [sid, layer.get_cell_atlas_coords(cell), td != null and td.flip_h]
	var parent: Dictionary = {}
	for cell in info:
		parent[cell] = cell
	for cell: Vector2i in info:
		var a: Array = info[cell]
		var right: Vector2i = cell + Vector2i(1, 0)
		if info.has(right):
			var b: Array = info[right]
			var want: Vector2i = a[1] + (Vector2i(-1, 0) if a[2] else Vector2i(1, 0))
			if b[0] == a[0] and b[2] == a[2] and b[1] == want:
				_union(parent, cell, right)
		var down: Vector2i = cell + Vector2i(0, 1)
		if info.has(down):
			var c: Array = info[down]
			if c[0] == a[0] and c[2] == a[2] and c[1] == a[1] + Vector2i(0, 1):
				_union(parent, cell, down)
	var ofset: Vector2 = _cell_origin(layer)
	var group_base: Dictionary = {}
	for cell: Vector2i in info:
		var rows: Vector2i = _tile_rows(layer, cell)
		if rows.y < 0:
			continue
		var root: Vector2i = _find(parent, cell)
		var bottom: float = ofset.y + float(cell.y) * CELL + float(rows.y) + 1.0
		group_base[root] = maxf(float(group_base.get(root, -1.0e9)), bottom)
	var cell_bases: Dictionary = {}
	for cell: Vector2i in info:
		var root: Vector2i = _find(parent, cell)
		if group_base.has(root) and _tile_rows(layer, cell).y >= 0:
			cell_bases[cell] = group_base[root]
	return cell_bases


## cell_bases: harita hücresi -> nesne kökünün dünya y'si. Veri dokusunu yazar, kopya katmanı kurar.
func _add_object_front(layer: TileMapLayer, cell_bases: Dictionary, mode: String) -> void:
	var rect: Rect2i = layer.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0 or cell_bases.is_empty():
		return
	var data := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	for cell: Vector2i in cell_bases:
		var p: Vector2i = cell - rect.position
		var y: int = clampi(roundi(float(cell_bases[cell])), 0, 65535)
		data.set_pixel(p.x, p.y, Color8(y & 255, y >> 8, 255, 255))
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	mat.set_shader_parameter("veri", ImageTexture.create_from_image(data))
	mat.set_shader_parameter("veri_baslangic", Vector2(rect.position))
	mat.set_shader_parameter("veri_boyut", Vector2(rect.size))
	mat.set_shader_parameter("hucre_ofset", _cell_origin(layer))
	var front: TileMapLayer = _make_front(layer, mat)
	_front_materials.append(mat)
	fronts.append({"layer": layer, "front": front, "mode": mode, "bases": cell_bases})


## Asıl katmanın kopyası: aynı karolar/dönüşüm, oyuncuların üstünde (z_index 2 köklü Node2D altında).
func _make_front(layer: TileMapLayer, mat: ShaderMaterial) -> TileMapLayer:
	var front := layer.duplicate() as TileMapLayer
	front.name = String(layer.name) + " ön"
	front.use_parent_material = false
	front.material = mat
	_front_root.add_child(front)
	front.global_transform = layer.global_transform
	front.visible = layer.visible
	layer.visibility_changed.connect(func() -> void:
		if is_instance_valid(front):
			front.visible = layer.visible)
	return front


## ShaderMaterial.duplicate() script'ten set_shader_parameter ile verilen değerleri KOPYALAMIYOR (bkz. grass_sway.gd aynı not): tek tek aktarılır.
func _copy_material(src: ShaderMaterial) -> ShaderMaterial:
	var dst := ShaderMaterial.new()
	dst.shader = src.shader
	if src.shader:
		for u: Dictionary in src.shader.get_shader_uniform_list():
			var v: Variant = src.get_shader_parameter(u["name"])
			if v != null:
				dst.set_shader_parameter(u["name"], v)
	return dst


## Hücre (0,0)'ın dünyadaki sol-üstü (karolar bu noktadan 16'şar).
func _cell_origin(layer: TileMapLayer) -> Vector2:
	return layer.to_global(layer.map_to_local(Vector2i.ZERO)) - Vector2(layer.tile_set.tile_size) * 0.5


# ------------------------------------------------------------------ karo piksel analizi

## Hücre (0,0)'ın dünyadaki sol-üstü (public: terrain_collision.gd de kullanır).
func cell_origin(layer: TileMapLayer) -> Vector2:
	return _cell_origin(layer)


## Karonun GÖRÜNTÜLENEN satırları r0..r1 (dahil, 0..15) içindeki opak piksellerin karo içi (x, y) konumları. Yatay/dikey çevirme hesaba katılır; dönmüş
## (transpose) karoda aralıktaki tüm pikseller opak sayılır. Collision ayak izi (bkz. terrain_collision.gd) nesne tabanındaki bandı buradan alır.
func opaque_pixels(layer: TileMapLayer, cell: Vector2i, r0: int, r1: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var sid: int = layer.get_cell_source_id(cell)
	var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
	if src == null or src.texture == null:
		return out
	var coords: Vector2i = layer.get_cell_atlas_coords(cell)
	if not src.has_tile(coords):
		return out
	var img: Image = _image_of(src.texture)
	if img == null:
		return out
	var td: TileData = layer.get_cell_tile_data(cell)
	var flip_h: bool = td != null and td.flip_h
	var flip_v: bool = td != null and td.flip_v
	var transpose: bool = td != null and td.transpose
	var region: Rect2i = src.get_tile_texture_region(coords)
	var last: int = int(CELL) - 1
	for y in range(maxi(r0, 0), mini(r1, last) + 1):
		for x in range(int(CELL)):
			if transpose:
				out.append(Vector2i(x, y))
				continue
			var ax: int = last - x if flip_h else x
			var ay: int = last - y if flip_v else y
			if ax < region.size.x and ay < region.size.y and img.get_pixel(region.position.x + ax, region.position.y + ay).a > OPAQUE_ALPHA:
				out.append(Vector2i(x, y))
	return out

## (ilk opak satır, son opak satır) karonun kendi içinde (0..15); boşsa (-1, -1). Dikey çevirme dikkate alınır, dönmüş (transpose) karo tam hücre sayılır.
func _tile_rows(layer: TileMapLayer, cell: Vector2i) -> Vector2i:
	var sid: int = layer.get_cell_source_id(cell)
	var src := layer.tile_set.get_source(sid) as TileSetAtlasSource
	if src == null or src.texture == null:
		return Vector2i(-1, -1)
	var coords: Vector2i = layer.get_cell_atlas_coords(cell)
	if not src.has_tile(coords):
		return Vector2i(-1, -1)
	var td: TileData = layer.get_cell_tile_data(cell)
	var flip_v: bool = td != null and td.flip_v
	var transpose: bool = td != null and td.transpose
	var key := Vector4i(sid, coords.x, coords.y, (1 if flip_v else 0) + (2 if transpose else 0))
	if _rows_cache.has(key):
		return _rows_cache[key]
	var rows := Vector2i(-1, -1)
	var img: Image = _image_of(src.texture)
	if img != null:
		rows = _opaque_rows(img, src.get_tile_texture_region(coords))
		if rows.y >= 0:
			if transpose:
				rows = Vector2i(0, int(CELL) - 1)
			elif flip_v:
				rows = Vector2i(int(CELL) - 1 - rows.y, int(CELL) - 1 - rows.x)
	_rows_cache[key] = rows
	return rows


func _image_of(tex: Texture2D) -> Image:
	if not _image_cache.has(tex):
		var img: Image = tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_image_cache[tex] = img
	return _image_cache[tex]


## (ilk opak satır, son opak satır) - boşsa (-1, -1).
func _opaque_rows(img: Image, r: Rect2i) -> Vector2i:
	var first: int = -1
	var last: int = -1
	for y in range(r.size.y):
		for x in range(r.size.x):
			if img.get_pixel(r.position.x + x, r.position.y + y).a > OPAQUE_ALPHA:
				if first < 0:
					first = y
				last = y
				break
	return Vector2i(first, last)


func _find(parent: Dictionary, c: Vector2i) -> Vector2i:
	while parent[c] != c:
		parent[c] = parent[parent[c]]
		c = parent[c]
	return c


func _union(parent: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var ra: Vector2i = _find(parent, a)
	var rb: Vector2i = _find(parent, b)
	if ra != rb:
		parent[rb] = ra


# ------------------------------------------------------------------ çalışma anı

## Karakter listesi: yerel oyuncu + uzak oyuncu kuklaları (ayak x, ayak y, yarım genişlik, boy) - grass_sway.gd ile aynı kurallar.
static func collect_characters(tree: SceneTree) -> Array[Vector4]:
	var chars: Array[Vector4] = []
	for group_name in ["player", "remote_players"]:
		for n in tree.get_nodes_in_group(group_name):
			if chars.size() >= MAX_CHARACTERS:
				break
			if not (n is Node2D) or not is_instance_valid(n) or n.get("is_dead") == true or not (n as Node2D).is_visible_in_tree():
				continue
			var feet: Vector2 = (n as Node2D).global_position + Vector2(0.0, FEET_OFFSET)
			chars.append(Vector4(feet.x, feet.y, BODY_HALF_WIDTH, BODY_HEIGHT))
	return chars


func _process(_delta: float) -> void:
	if _front_materials.is_empty():
		return
	for pair: Array in _tree_pairs:
		var strength: Variant = (pair[0] as ShaderMaterial).get_shader_parameter("strength")
		if strength != null and strength != (pair[1] as ShaderMaterial).get_shader_parameter("strength"):
			(pair[1] as ShaderMaterial).set_shader_parameter("strength", strength)
	var chars: Array[Vector4] = collect_characters(get_tree())
	if chars != _last_chars:
		_last_chars = chars.duplicate()
		var count: int = chars.size()
		while chars.size() < MAX_CHARACTERS:
			chars.append(Vector4.ZERO)
		for m in _front_materials:
			m.set_shader_parameter("karakter_sayisi", count)
			m.set_shader_parameter("karakterler", chars)
	if _creatures_on:
		## CreatureDepth + main.gd çizim sırası ÇİFT karelerde çalışır: bu güncelleme TEK karelerde (aynı karede yığılmasınlar)
		_creature_frame += 1
		if _creature_frame % CREATURE_UPDATE_FRAMES == 1:
			update_creatures()


# ------------------------------------------------------------------ yaratıklar (ağaç/ev arkasında yürüyen yaratık örtülsün)

## Kaba ızgara: her kopya katmanın nesne hücresi -> o hücreye değen 32 px'lik kaba hücrelerde EN BÜYÜK kök y'si.
func _build_coarse() -> void:
	_coarse.clear()
	_near.clear()
	for f: Dictionary in fronts:
		var layer: TileMapLayer = f["layer"]
		var ofset: Vector2 = _cell_origin(layer)
		var bases: Dictionary = f["bases"]
		for cell: Vector2i in bases:
			var x0: float = ofset.x + float(cell.x) * CELL
			var y0: float = ofset.y + float(cell.y) * CELL
			var base: float = float(bases[cell])
			for cx in range(floori(x0 / COARSE), floori((x0 + CELL - 1.0) / COARSE) + 1):
				for cy in range(floori(y0 / COARSE), floori((y0 + CELL - 1.0) / COARSE) + 1):
					var key := Vector2i(cx, cy)
					if base > float(_coarse.get(key, -1.0e9)):
						_coarse[key] = base
	for key: Vector2i in _coarse:
		for dx in range(-NEAR_CELLS, NEAR_CELLS + 1):
			for dy in range(-NEAR_CELLS, NEAR_CELLS + 1):
				_near[key + Vector2i(dx, dy)] = true


## Dikdörtgene (x0..x1, y0..y1) değen kaba hücrelerdeki en büyük nesne kökü (yoksa -1e9).
func max_base_in(x0: float, y0: float, x1: float, y1: float) -> float:
	var best: float = -1.0e9
	for cx in range(floori(x0 / COARSE), floori(x1 / COARSE) + 1):
		for cy in range(floori(y0 / COARSE), floori(y1 / COARSE) + 1):
			var v: float = float(_coarse.get(Vector2i(cx, cy), -1.0e9))
			if v > best:
				best = v
	return best


## Görüntü merkezi + yarıçap (z). Kamera yoksa (testler) ilk karakterin çevresi; o da yoksa yarıçap -1.
func _view_circle() -> Vector3:
	var cam: Camera2D = get_viewport().get_camera_2d() if is_inside_tree() else null
	if cam != null:
		var size: Vector2 = get_viewport().get_visible_rect().size / cam.zoom
		var c: Vector2 = cam.get_screen_center_position()
		return Vector3(c.x, c.y, size.length() * 0.5 + CREATURE_VIEW_PAD)
	if not _last_chars.is_empty():
		return Vector3(_last_chars[0].x, _last_chars[0].y, 900.0)
	return Vector3(0.0, 0.0, -1.0)


## Yaratığın ayağının dünya y'si (main.gd'nin ölçtüğü değer; main yoksa kök noktası).
func _foot_y(n: Node2D) -> float:
	if _main != null and is_instance_valid(_main) and _main.has_method("_creature_foot_y"):
		return float(_main.call("_creature_foot_y", n))
	return n.global_position.y


## Nesne kümesine değen yaratıkların gövde dikdörtgenlerini (ayak x, ayak y, yarım genişlik, boy) bulup tüm kopya katmanlara yazar.
func update_creatures() -> void:
	var entries: Array[Vector4] = []
	var view: Vector3 = _view_circle()
	if view.z > 0.0:
		var center := Vector2(view.x, view.y)
		var found: Array = []
		var seen: Dictionary = {}
		var cand: Array = EnemyQueryScript.candidates(get_tree(), center, view.z)
		for group_name in ["player_ally", "player_allies"]:
			cand = cand + get_tree().get_nodes_in_group(group_name)
		var half: Vector2 = Vector2(view.z, view.z)
		var cam: Camera2D = get_viewport().get_camera_2d()
		if cam != null:
			half = get_viewport().get_visible_rect().size / cam.zoom * 0.5 + Vector2(CREATURE_VIEW_PAD, CREATURE_VIEW_PAD)
		for n in cand:
			var n2 := n as Node2D
			if n2 == null or not is_instance_valid(n2) or not n2.visible:
				continue
			var pos: Vector2 = n2.global_position
			var d: Vector2 = pos - center
			if absf(d.x) > half.x or absf(d.y) > half.y:
				continue
			## ucuz ön eleme: yakınında hiç nesne hücresi olmayan (açık arazi) yaratığın gövdesi/ayağı hesaplanmaz
			if not _near.has(Vector2i(floori(pos.x / COARSE), floori(pos.y / COARSE))):
				continue
			if seen.has(n2) or n2.get("is_dead") == true:
				continue
			seen[n2] = true
			var body: Vector2 = creature_body(n2)
			var foot: float = _foot_y(n2)
			if max_base_in(pos.x - body.x, foot - body.y, pos.x + body.x, foot) > foot - FRONT_SLACK:
				found.append([d.length_squared(), Vector4(pos.x, foot, body.x, body.y)])
		if found.size() > MAX_CREATURES:
			found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
			found.resize(MAX_CREATURES)
		for item: Array in found:
			entries.append(item[1])
	if entries == _creature_entries:
		return
	_creature_entries = entries.duplicate()
	var count: int = entries.size()
	while entries.size() < MAX_CREATURES:
		entries.append(Vector4.ZERO)
	for m in _front_materials:
		m.set_shader_parameter("yaratik_sayisi", count)
		m.set_shader_parameter("yaratiklar", entries)


## Yaratığın gövde yarı genişliği ve boyu (dünya px): görselin ilk karesindeki opak alandan x ölçek, BODY_MARGIN payla. Düğüm başına bir kez (meta).
func creature_body(n: Node2D) -> Vector2:
	if n.has_meta("_depth_body"):
		return n.get_meta("_depth_body")
	var vis: Node2D = null
	for child_name in ["Sprite2D", "AnimatedSprite2D"]:
		var c: Node = n.get_node_or_null(child_name)
		if c is Sprite2D or c is AnimatedSprite2D:
			vis = c as Node2D
			break
	var body: Vector2 = BODY_FALLBACK
	if vis != null:
		var used: Vector2 = _used_size(vis)
		if used.x > 0.0 and used.y > 0.0:
			var sc: Vector2 = vis.global_scale.abs()
			body = Vector2(maxf(used.x * 0.5 * sc.x * BODY_MARGIN, 10.0), maxf(used.y * sc.y * BODY_MARGIN, 16.0))
	n.set_meta("_depth_body", body)
	return body


## Sprite karesinin (hframes x vframes bölünmüş ilk kare ya da AnimatedSprite2D'nin geçerli animasyonunun ilk karesi) opak alan boyu (px, ölçeksiz); ölçülemezse (0,0).
func _used_size(vis: Node2D) -> Vector2:
	var tex: Texture2D = null
	var frame_size := Vector2.ZERO
	var key := ""
	if vis is Sprite2D:
		var s := vis as Sprite2D
		tex = s.texture
		if tex != null:
			frame_size = tex.get_size() / Vector2(maxi(s.hframes, 1), maxi(s.vframes, 1))
			key = "%d|%d|%d" % [tex.get_rid().get_id(), s.hframes, s.vframes]
	elif vis is AnimatedSprite2D:
		var a := vis as AnimatedSprite2D
		if a.sprite_frames != null and a.sprite_frames.has_animation(a.animation) and a.sprite_frames.get_frame_count(a.animation) > 0:
			tex = a.sprite_frames.get_frame_texture(a.animation, 0)
			if tex != null:
				frame_size = tex.get_size()
				key = "%d|a|%s" % [tex.get_rid().get_id(), str((tex as AtlasTexture).region) if tex is AtlasTexture else ""]
	if tex == null or frame_size.x <= 0.0 or frame_size.y <= 0.0:
		return Vector2.ZERO
	if _body_cache.has(key):
		return _body_cache[key]
	var size := Vector2.ZERO
	var img: Image = _image_of(tex)
	if img != null:
		var fr := Rect2i(Vector2i.ZERO, Vector2i(frame_size)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var used: Rect2i = img.get_region(fr).get_used_rect()
		size = Vector2(used.size)
	_body_cache[key] = size
	return size
