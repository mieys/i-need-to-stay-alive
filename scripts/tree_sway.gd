extends Node

## Sallanan ağaçlar (scenes/sallanan ağaç.gdshader) için yardımcı - kullanıcı isteği (2026-09-26): Harita > "Shader Eklenecek" >
## "Ağaç 0/1/2" katmanlarındaki ağaçlar hafifçe sallansın. Ağaçlar karo katmanında KALIR (Tiled'dan eklenen her şey çalışır).
##
## AĞAÇ AYIRMA: bir ağaç atlasta dikdörtgen bir karo bloğu. Haritada sağdaki hücre atlasta sağdaki karoysa (çevrilmiş karoda
## soldaki), alttaki hücre atlasta alttaki karoysa ikisi aynı ağaçtır (aynı kaynak + aynı çevirme). Sadece "dolu komşu" ile
## birleştirmek harita kenarlarında üst üste dizilmiş ağaçları TEK dev ağaç yapıyordu (kök en alttaki ağaçta, tepedekiler
## çok sallanırdı) - atlas komşuluğu onları ayırıyor (Harita.tmx'te ölçüldü: Ağaç 0/1/2 = 27/21/6 ağaç).
## Kök = ağacın en alt satırındaki son opak piksel satırı, boy = kökten ağacın en üst opak satırına. 2 karodan kısa parçalar
## (harita kenarında kesilmiş ağaç dipleri) sallanmaz; az yeşilli (yapraksız, kuru) ağaçlar yarım genlikle sallanır.
## Rüzgar/fırtına: atmosphere.gd get_sway_multiplier (otlarla aynı çarpan). Tamamen yerel/kozmetik, ağ gerekmez.

const SHADER_PATH := "res://scenes/sallanan ağaç.gdshader"
const LAYER_PARENT := "Shader Eklenecek"
const LAYER_PREFIX := "Ağaç"
const MIN_SWAY_ROWS := 2
const DRY_TREE_GREEN_RATIO := 0.4 ## yeşil piksel oranı bunun altındaysa kuru ağaç
const DRY_TREE_AMPLITUDE := 0.5
const WAVE_SCALE := 0.004 ## ortak esinti dalgası: kökün dünya x'i x bu = faz (radyan)

var _materials: Array[ShaderMaterial] = []
var _base_strength: float = 1.4
var _last_mult: float = -1.0
var _atmosphere: Node = null
var _image_cache: Dictionary = {}


## main.gd çağırır. Katmanlar yoksa (test sahnesi, başka harita) sessizce hiçbir şey yapmaz.
func setup(harita: Node) -> void:
	var parent: Node = harita.get_node_or_null(LAYER_PARENT)
	if parent == null:
		return
	name = "TreeSway"
	harita.add_child(self)
	var shader: Shader = load(SHADER_PATH)
	for child in parent.get_children():
		var layer := child as TileMapLayer
		if layer == null or layer.tile_set == null or not String(layer.name).begins_with(LAYER_PREFIX):
			continue
		## Her katman KENDİ materyal kopyasını alır (kendi hücre verisi). Sahnede başka bir shader varsa (açık editörün eski
		## hâli yeniden kaydetmesi gibi) çalışma anında doğrusu takılır - bkz. grass_sway.gd aynı not.
		var mat := ShaderMaterial.new()
		mat.shader = shader
		var cur := layer.material as ShaderMaterial
		if cur and cur.shader == shader:
			for u: Dictionary in shader.get_shader_uniform_list():
				var v: Variant = cur.get_shader_parameter(u["name"])
				if v != null:
					mat.set_shader_parameter(u["name"], v)
		layer.material = mat
		layer.use_parent_material = false
		if _materials.is_empty():
			var s: Variant = mat.get_shader_parameter("strength")
			if s == null:
				s = RenderingServer.shader_get_parameter_default(shader.get_rid(), "strength")
			_base_strength = float(s) if s != null else 1.4
		_write_cell_data(mat, layer)
		_materials.append(mat)


func _write_cell_data(mat: ShaderMaterial, layer: TileMapLayer) -> void:
	var rect: Rect2i = layer.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var ts: TileSet = layer.tile_set
	var cells: Array[Vector2i] = layer.get_used_cells()
	## Hücre -> [kaynak, atlas koordinatı, çevrik mi]
	var info: Dictionary = {}
	var padding_src: TileSetAtlasSource = null
	for cell in cells:
		var sid: int = layer.get_cell_source_id(cell)
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null:
			continue
		if padding_src == null:
			padding_src = src
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		var alt: int = layer.get_cell_alternative_tile(cell)
		var flip: bool = false
		if src.has_tile(coords) and src.has_alternative_tile(coords, alt):
			flip = src.get_tile_data(coords, alt).flip_h
		info[cell] = [sid, coords, flip]
	## Union-find: atlas komşuluğu olan hücreler aynı ağaç.
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
	var trees: Dictionary = {}
	for cell in info:
		var r: Vector2i = _find(parent, cell)
		if not trees.has(r):
			trees[r] = []
		(trees[r] as Array).append(cell)

	var ofset: Vector2 = layer.to_global(layer.map_to_local(Vector2i.ZERO)) - Vector2(ts.tile_size) * 0.5
	var data := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	for key in trees:
		var tree: Array = trees[key]
		var min_y: int = 1 << 30
		var max_y: int = -(1 << 30)
		var min_x: int = 1 << 30
		var max_x: int = -(1 << 30)
		for cell: Vector2i in tree:
			min_y = mini(min_y, cell.y)
			max_y = maxi(max_y, cell.y)
			min_x = mini(min_x, cell.x)
			max_x = maxi(max_x, cell.x)
		## Kök (en alt satırın son opak satırı) ve tepe (en üst satırın ilk opak satırı), texel - ağacın üst hücresinin üstüne göre.
		var root_px: int = (max_y - min_y) * 16 + 16
		var top_px: int = 0
		var last_row: int = -1
		var first_row: int = 16
		var green: int = 0
		var opaque: int = 0
		for cell: Vector2i in tree:
			var a: Array = info[cell]
			var src := ts.get_source(a[0]) as TileSetAtlasSource
			if src.texture == null or not src.has_tile(a[1]):
				continue
			var img: Image = _image_of(src.texture)
			if img == null:
				continue
			var region: Rect2i = src.get_tile_texture_region(a[1])
			for y in range(region.size.y):
				for x in range(region.size.x):
					var px: Color = img.get_pixel(region.position.x + x, region.position.y + y)
					if px.a < 0.4:
						continue
					opaque += 1
					if px.h > 0.17 and px.h < 0.48 and px.s > 0.25:
						green += 1
					if cell.y == max_y:
						last_row = maxi(last_row, y)
					if cell.y == min_y:
						first_row = mini(first_row, y)
		if last_row >= 0:
			root_px = (max_y - min_y) * 16 + last_row + 1
		if first_row < 16:
			top_px = first_row
		var height: int = root_px - top_px
		if max_y - min_y + 1 < MIN_SWAY_ROWS or opaque == 0:
			height = 0
		var amp: float = 1.0 if float(green) / float(maxi(opaque, 1)) >= DRY_TREE_GREEN_RATIO else DRY_TREE_AMPLITUDE
		var root_world_x: float = ofset.x + (float(min_x + max_x) * 0.5 + 0.5) * 16.0
		var wave: int = int(fposmod(root_world_x * WAVE_SCALE / TAU, 1.0) * 255.0)
		for cell: Vector2i in tree:
			var p: Vector2i = cell - rect.position
			var rel_root: int = root_px - (cell.y - min_y) * 16
			var amp_byte: int = (clampi(roundi(amp * 127.0), 0, 127) * 2) | (1 if info[cell][2] else 0)
			data.set_pixel(p.x, p.y, Color8(clampi(rel_root, 1, 255), clampi(height, 0, 255), wave, amp_byte))
	mat.set_shader_parameter("veri", ImageTexture.create_from_image(data))
	mat.set_shader_parameter("veri_var", true)
	mat.set_shader_parameter("veri_baslangic", Vector2(rect.position))
	mat.set_shader_parameter("veri_boyut", Vector2(rect.size))
	mat.set_shader_parameter("hucre_ofset", ofset)
	if padding_src:
		mat.set_shader_parameter("karo_hucre", float(padding_src.texture_region_size.x + (2 if padding_src.use_texture_padding else 0)))
		mat.set_shader_parameter("karo_dolgu", 1.0 if padding_src.use_texture_padding else 0.0)


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


func _image_of(tex: Texture2D) -> Image:
	if not _image_cache.has(tex):
		var img: Image = tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_image_cache[tex] = img
	return _image_cache[tex]


func _process(_delta: float) -> void:
	if _materials.is_empty():
		return
	if _atmosphere == null or not is_instance_valid(_atmosphere):
		_atmosphere = get_tree().get_first_node_in_group(&"atmosphere")
	var mult: float = float(_atmosphere.get_sway_multiplier()) if _atmosphere and _atmosphere.has_method("get_sway_multiplier") else 1.0
	if absf(mult - _last_mult) > 0.005:
		_last_mult = mult
		for m in _materials:
			m.set_shader_parameter("strength", _base_strength * mult)
