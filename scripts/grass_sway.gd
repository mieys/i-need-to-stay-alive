extends Node

## Sallanan otlar (scenes/sallanan ot.gdshader) için yardımcı - kullanıcı isteği (2026-09-26): Harita > "Shader Eklenecek" >
## "Çalılar"/"Çalılar1" otları sallansın (görünüm eskisiyle AYNI) + 2D oyunlardaki yukarı/aşağı önceliği: "yukarı yürüyünce
## otun arkasında, aşağı yürüyünce önünde görünmeli". Otlar karo katmanında KALIR (Tiled'dan eklenen her şey çalışır).
##
## Neden Godot'un Y-Sort'u değil: y-sıralama sadece AYNI z seviyesinde ve ortak y-sıralı ebeveyn altında çalışır. Oyuncular
## z_index 1'de (haritanın üstünde), yaratık/XP küresi/düşen eşya/FX ise z 0'da. Otları oyuncuyla sıralamak için z 1'e
## almak onları tüm yaratıkların ve yerdeki kürelerin ÜSTÜNE çıkarırdı (küreler çimende kaybolurdu); Main'in tamamına Y-Sort
## açmak da FX/yaratık/damla sırasını oyunun her yerinde değiştirirdi. Bunun yerine aynı sonucu veren yerel bir çözüm:
##  - Otlar haritada aynen çizilir (herkesin altında, eskisi gibi).
##  - Katmanların bir KOPYASI z_index 2'de (oyuncuların üstünde) çizilir; shader kopyada SADECE kökü bir oyuncunun ayağından
##    aşağıda (yani önünde) olan ot piksellerini ve SADECE o oyuncunun gövdesinin üstünde bırakır (on_katman).
## Yaratıklar bu önceliğe dahil değil (eskisi gibi otların üstünde).
##
## KÖK: her HÜCRE için haritadaki gerçek yerleşimden hesaplanır (veri dokusu, shader hücre başına okur). Atlas kalıbından
## tahmin ETMEYİN: (1,54) karosu normalde altındaki (1,55) ile 2 karoluk otun üst yarısı ama haritada ~30 yerde tek başına
## duruyor - kökünü 16 px aşağıda sanınca oyuncu otun hemen altındayken ot başının üstüne çiziliyordu (kullanıcı bildirimi).
## Ayrıca havaya göre salınım gücü (atmosphere.gd get_sway_multiplier - eski sallantı.gdshader ile aynı çarpan).
## Tamamen yerel/kozmetik: uzak oyuncu kuklaları da dahil, ağ gerekmez.

const SHADER_PATH := "res://scenes/sallanan ot.gdshader"
const LAYER_PARENT := "Shader Eklenecek"
const LAYER_NAMES: Array[String] = ["Çalılar", "Çalılar1"]
const MAX_CHARACTERS := 8      ## shader'daki karakterler dizi boyu
## Karakter ayak noktası (dünya px, köke göre): oyuncu kökü ölçek 0.5'te, sprite'ın zemine değdiği yer ~+30 yerel.
const FEET_OFFSET := 15.0
const BODY_HALF_WIDTH := 11.0
const BODY_HEIGHT := 34.0
## TEMAS (kullanıcı isteği 2026-09-26: "oyuncular çalıya dokunduğu zaman çalının buna göre sallanmasını istiyorum"): ayağı otun
## kökünün çevresindeki kutuda olan oyuncu otu kendinden UZAĞA eğer (tam ortasındaysa yürüdüğü yöne); değmeye başladığı an
## hızına göre bir itki verir -> yay-sönüm ile birkaç kez sallanıp durulur. Sadece hareket eden otlar güncellenir.
const TOUCH_HALF_WIDTH := 9.0     ## otun ortasından yatay (dünya px)
const TOUCH_ABOVE := 10.0         ## kökün üstünde (ayak otun içindeyken)
const TOUCH_BELOW := 5.0          ## kökün altında
const BEND_MAX := 3.5             ## temas eğilmesi: otun ucunda en fazla (texel)
const BEND_IMPULSE_RATIO := 0.08  ## değme anında: oyuncu hızı (px/sn) x bu = eğilme hızı itkisi
const BEND_IMPULSE_MAX := 18.0
const SPRING_K := 140.0
const SPRING_DAMP := 8.0
const BEND_TEX_SCALE := 16.0      ## eğilme dokusu: R8 = 128 + eğilme x 16 (±8 texel) - shader'daki egilme_veri ile AYNI

var _materials: Array[ShaderMaterial] = []
var _front_materials: Array[ShaderMaterial] = []
var _base_strength: float = 1.35
var _last_mult: float = -1.0
var _atmosphere: Node = null
var _image_cache: Dictionary = {}
## Katman başına temas durumu: {"rect", "ofset", "data" (kök/boy RG8), "bend_img" (R8), "bend_tex", "plants" (kök hücresi ->
## [eğilme, hız]), "touching" (önceki karede değilen kök hücreleri)}
var _layer_states: Array[Dictionary] = []
var _prev_feet: Dictionary = {}


## main.gd çağırır. Katmanlar/materyaller yoksa (test sahnesi, başka harita) sessizce hiçbir şey yapmaz.
func setup(harita: Node) -> void:
	var parent: Node = harita.get_node_or_null(LAYER_PARENT)
	if parent == null:
		return
	name = "GrassSway"
	harita.add_child(self)
	var front_root := Node2D.new()
	front_root.name = "OtOnKatman"
	front_root.z_index = 2
	parent.add_child(front_root)
	for layer_name in LAYER_NAMES:
		var layer := parent.get_node_or_null(layer_name) as TileMapLayer
		if layer == null or layer.tile_set == null:
			continue
		## Her katman KENDİ materyal kopyasını alır (kendi hücre verisi - iki katmanda aynı hücrede farklı ot olabilir).
		## Katmanda bu shader YOKSA çalışma anında takılır: 2026-09-26'da açık Godot editörü harita_baked.tscn'i eski
		## hâliyle yeniden kaydedip katmanı eski sallantı.gdshader'a döndürdü; ön katman kopyası da eski shader'la TÜM
		## otları oyuncunun üstüne çizdi ("aşağısındayken bitki üstümde görünüyor"). Sahne ne derse desin doğru shader.
		var mat: ShaderMaterial
		var cur := layer.material as ShaderMaterial
		if cur and cur.shader and cur.shader.resource_path == SHADER_PATH:
			mat = _copy_material(cur)
		else:
			mat = ShaderMaterial.new()
			mat.shader = load(SHADER_PATH)
		layer.material = mat
		if _materials.is_empty():
			var s: Variant = mat.get_shader_parameter("strength")
			if s == null and mat.shader:
				s = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), "strength")
			_base_strength = float(s) if s != null else 1.35
		var state: Dictionary = _write_cell_data(mat, layer)
		if not state.is_empty():
			_layer_states.append(state)
		_materials.append(mat)
		## Ön katman kopyası: aynı karolar, aynı dönüşüm, oyuncuların üstünde.
		var front := layer.duplicate() as TileMapLayer
		front.name = String(layer.name) + " ön"
		front.transform = layer.transform
		var fmat := _copy_material(mat)
		fmat.set_shader_parameter("on_katman", true)
		front.material = fmat
		front_root.add_child(front)
		_front_materials.append(fmat)


## ShaderMaterial.duplicate() script'ten set_shader_parameter ile verilen değerleri (veri dokusu, veri_var...) KOPYALAMIYOR
## (ölçüldü: kopyada veri_var null) - ön katman her ota varsayılan kökü uygulayıp 2 karoluk otun alt yarısını "hep önde"
## sanıyordu. Tüm shader parametreleri tek tek aktarılır.
func _copy_material(src: ShaderMaterial) -> ShaderMaterial:
	var dst := ShaderMaterial.new()
	dst.shader = src.shader
	if src.shader:
		for u: Dictionary in src.shader.get_shader_uniform_list():
			var v: Variant = src.get_shader_parameter(u["name"])
			if v != null:
				dst.set_shader_parameter(u["name"], v)
	return dst


## Hücre başına kök/boy -> RG8 veri dokusu (R = kökün karonun üstünden uzaklığı (texel), G = boy). Kök ve boy haritadaki
## GERÇEK komşuluğa göre: altındaki hücrede aynı otun devamı (atlasta hemen alttaki karo, aynı kaynak/çevirme, çizgi kesintisiz)
## varsa kök alttaki karoda; üstündekinin devamıysa boy üst yarıdan başlar; yoksa tek karoluk ot.
func _write_cell_data(mat: ShaderMaterial, layer: TileMapLayer) -> Dictionary:
	var rect: Rect2i = layer.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return {}
	var data := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RG8)
	var ts: TileSet = layer.tile_set
	var src_for_padding: TileSetAtlasSource = null
	for cell in layer.get_used_cells():
		var src := ts.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
		if src == null or src.texture == null:
			continue
		if src_for_padding == null:
			src_for_padding = src
		var img: Image = _image_of(src.texture)
		if img == null:
			continue
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		var region: Rect2i = src.get_tile_texture_region(coords)
		var rows: Vector2i = _opaque_rows(img, region)
		if rows.x < 0:
			continue
		var root: int = rows.y
		var top: int = rows.x
		var below: Vector2i = cell + Vector2i(0, 1)
		var above: Vector2i = cell + Vector2i(0, -1)
		if _is_continuation(layer, cell, below, img, src, coords, 1):
			var rb: Vector2i = _opaque_rows(img, src.get_tile_texture_region(coords + Vector2i(0, 1)))
			if rb.y >= 0:
				root = 16 + rb.y
		if _is_continuation(layer, cell, above, img, src, coords, -1):
			var ra: Vector2i = _opaque_rows(img, src.get_tile_texture_region(coords + Vector2i(0, -1)))
			if ra.x >= 0:
				top = ra.x - 16
		var p: Vector2i = cell - rect.position
		data.set_pixel(p.x, p.y, Color8(clampi(root, 0, 255), clampi(maxi(1, root - top), 1, 255), 0))
	mat.set_shader_parameter("veri", ImageTexture.create_from_image(data))
	## Temas eğilmesi dokusu (128 = eğilme yok) - ön katman kopyası da aynı dokuyu kullanır (_copy_material).
	var bend_img := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_R8)
	bend_img.fill(Color8(128, 0, 0))
	var bend_tex := ImageTexture.create_from_image(bend_img)
	mat.set_shader_parameter("egilme_veri", bend_tex)
	mat.set_shader_parameter("veri_var", true)
	mat.set_shader_parameter("veri_baslangic", Vector2(rect.position))
	mat.set_shader_parameter("veri_boyut", Vector2(rect.size))
	## Hücre (0,0)'ın dünyadaki sol-üstü (karolar bu noktadan 16'şar).
	var ofset: Vector2 = layer.to_global(layer.map_to_local(Vector2i.ZERO)) - Vector2(ts.tile_size) * 0.5
	mat.set_shader_parameter("hucre_ofset", ofset)
	if src_for_padding:
		## Shader dolgulu (use_texture_padding) çalışma anı dokusunu görür: karolar 18'lik hücrelerde, 1 px içeride.
		mat.set_shader_parameter("karo_hucre", float(src_for_padding.texture_region_size.x + (2 if src_for_padding.use_texture_padding else 0)))
		mat.set_shader_parameter("karo_dolgu", 1.0 if src_for_padding.use_texture_padding else 0.0)
	return {"rect": rect, "ofset": ofset, "data": data, "bend_img": bend_img, "bend_tex": bend_tex, "plants": {}, "touching": {}}


## other hücresinde bu otun devamı var mı (dir = 1 alttaki, -1 üstteki): atlasta dikey komşu karo, aynı kaynak ve aynı
## alternatif (çevirme), iki karonun birleşim satırlarında aynı sütunda (±1) opak piksel.
func _is_continuation(layer: TileMapLayer, cell: Vector2i, other: Vector2i, img: Image, src: TileSetAtlasSource, coords: Vector2i, dir: int) -> bool:
	if layer.get_cell_source_id(other) != layer.get_cell_source_id(cell):
		return false
	if layer.get_cell_alternative_tile(other) != layer.get_cell_alternative_tile(cell):
		return false
	var other_coords: Vector2i = coords + Vector2i(0, dir)
	if layer.get_cell_atlas_coords(other) != other_coords or not src.has_tile(other_coords):
		return false
	var upper: Rect2i = src.get_tile_texture_region(coords if dir == 1 else other_coords)
	var lower: Rect2i = src.get_tile_texture_region(other_coords if dir == 1 else coords)
	return _continues(img, upper, lower)


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
			if img.get_pixel(r.position.x + x, r.position.y + y).a > 0.1:
				if first < 0:
					first = y
				last = y
				break
	return Vector2i(first, last)


## Üst karonun en alt satırı ile alt karonun en üst satırında aynı sütunda (±1) opak piksel var mı.
func _continues(img: Image, upper: Rect2i, lower: Rect2i) -> bool:
	var yu: int = upper.position.y + upper.size.y - 1
	for x in range(upper.size.x):
		if img.get_pixel(upper.position.x + x, yu).a < 0.1:
			continue
		for dx in [-1, 0, 1]:
			var xx: int = clampi(x + dx, 0, lower.size.x - 1)
			if img.get_pixel(lower.position.x + xx, lower.position.y).a > 0.1:
				return true
	return false


## Değilen otları bul, yay-sönümle eğ, eğilmeyi dokuya yaz (sadece değişen/hareketli otlar).
func _update_touch(state: Dictionary, touchers: Array, delta: float) -> void:
	var rect: Rect2i = state["rect"]
	var ofset: Vector2 = state["ofset"]
	var data: Image = state["data"]
	var plants: Dictionary = state["plants"]
	var touching: Dictionary = {}
	var targets: Dictionary = {}
	for t in touchers:
		var feet: Vector2 = t[0]
		var vel: Vector2 = t[1]
		var fc := Vector2i(floori((feet.x - ofset.x) / 16.0), floori((feet.y - ofset.y) / 16.0))
		for cx in range(fc.x - 1, fc.x + 2):
			for cy in range(fc.y - 1, fc.y + 2):
				var p := Vector2i(cx, cy) - rect.position
				if p.x < 0 or p.y < 0 or p.x >= rect.size.x or p.y >= rect.size.y:
					continue
				var d: Color = data.get_pixel(p.x, p.y)
				var root: int = roundi(d.r * 255.0)
				if roundi(d.g * 255.0) <= 0 or root >= 16:
					continue ## boş hücre ya da 2 karoluk otun üst yarısı (kök alttaki hücrede)
				var root_y: float = ofset.y + float(cy) * 16.0 + float(root) + 1.0
				var center_x: float = ofset.x + float(cx) * 16.0 + 8.0
				var dx: float = center_x - feet.x
				if absf(dx) > TOUCH_HALF_WIDTH or feet.y < root_y - TOUCH_ABOVE or feet.y > root_y + TOUCH_BELOW:
					continue
				var dir: float = signf(dx) if absf(dx) > 1.5 else signf(vel.x)
				var amt: float = 1.0 - clampf(absf(dx) / TOUCH_HALF_WIDTH, 0.0, 1.0) * 0.5
				targets[p] = clampf(float(targets.get(p, 0.0)) + dir * amt * BEND_MAX, -BEND_MAX, BEND_MAX)
				touching[p] = true
				if not plants.has(p):
					plants[p] = [0.0, 0.0]
				if not (state["touching"] as Dictionary).has(p):
					var push: float = clampf(vel.length() * BEND_IMPULSE_RATIO, 0.0, BEND_IMPULSE_MAX)
					plants[p][1] = float(plants[p][1]) + (dir if dir != 0.0 else 1.0) * push
	state["touching"] = touching
	if plants.is_empty():
		return
	var img: Image = state["bend_img"]
	var dt: float = minf(delta, 0.05)
	var done: Array = []
	for p: Vector2i in plants.keys():
		var bend: float = plants[p][0]
		var v: float = plants[p][1]
		v += ((float(targets.get(p, 0.0)) - bend) * SPRING_K - v * SPRING_DAMP) * dt
		bend = clampf(bend + v * dt, -7.5, 7.5)
		if not touching.has(p) and absf(bend) < 0.03 and absf(v) < 0.03:
			bend = 0.0
			done.append(p)
		plants[p] = [bend, v]
		var px := Color8(clampi(roundi(128.0 + bend * BEND_TEX_SCALE), 0, 255), 0, 0)
		img.set_pixel(p.x, p.y, px)
		## 2 karoluk otun üst yarısı (üstteki hücre, kökü bu hücrede) da aynı eğilmeyi alır.
		if p.y > 0 and roundi(data.get_pixel(p.x, p.y - 1).r * 255.0) >= 16:
			img.set_pixel(p.x, p.y - 1, px)
	for p in done:
		plants.erase(p)
	(state["bend_tex"] as ImageTexture).update(img)


func _process(_delta: float) -> void:
	if _materials.is_empty():
		return
	## Rüzgar/fırtınada daha sert (eski sallantı.gdshader ile aynı çarpan).
	if _atmosphere == null or not is_instance_valid(_atmosphere):
		_atmosphere = get_tree().get_first_node_in_group(&"atmosphere")
	var mult: float = float(_atmosphere.get_sway_multiplier()) if _atmosphere and _atmosphere.has_method("get_sway_multiplier") else 1.0
	if absf(mult - _last_mult) > 0.005:
		_last_mult = mult
		for m in _materials + _front_materials:
			m.set_shader_parameter("strength", _base_strength * mult)
	## Ön katman: oyuncular (yerel + uzak kuklalar) - ayak noktası ve gövde. Temas için ayak + hız.
	var chars: Array[Vector4] = []
	var touchers: Array = [] ## [ayak, hız]
	var seen: Dictionary = {}
	for group_name in ["player", "remote_players"]:
		for n in get_tree().get_nodes_in_group(group_name):
			if chars.size() >= MAX_CHARACTERS:
				break
			if not (n is Node2D) or not is_instance_valid(n) or n.get("is_dead") == true or not (n as Node2D).is_visible_in_tree():
				continue
			var feet: Vector2 = (n as Node2D).global_position + Vector2(0.0, FEET_OFFSET)
			chars.append(Vector4(feet.x, feet.y, BODY_HALF_WIDTH, BODY_HEIGHT))
			var id: int = n.get_instance_id()
			seen[id] = true
			var prev: Vector2 = _prev_feet.get(id, feet)
			_prev_feet[id] = feet
			touchers.append([feet, (feet - prev) / maxf(_delta, 0.001)])
	for id in _prev_feet.keys():
		if not seen.has(id):
			_prev_feet.erase(id)
	for state in _layer_states:
		_update_touch(state, touchers, _delta)
	var count: int = chars.size()
	while chars.size() < MAX_CHARACTERS:
		chars.append(Vector4.ZERO)
	for m in _front_materials:
		m.set_shader_parameter("karakter_sayisi", count)
		m.set_shader_parameter("karakterler", chars)
