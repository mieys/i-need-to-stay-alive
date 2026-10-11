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
const LAYER_NAMES: Array[String] = ["Çalılar", "Çalılar1", "Çiçekler 1"] ## Çiçekler 1: 2026-10-09 (kullanıcı: "çiçekler de çalılar gibi sallansın, y eksenine sahip olsun, dokununca sallansın")
const MAX_CHARACTERS := 8      ## shader'daki karakterler dizi boyu
## Karakter ayak noktası (dünya px, köke göre): oyuncu kökü ölçek 0.5'te, sprite'ın zemine değdiği yer ~+30 yerel.
const FEET_OFFSET := 15.0 * EntityScale.BODY_REL ## 2026-10-09: karakterler %15 küçüldü (eski ölçü 15 / 11 / 34)
const BODY_HALF_WIDTH := 11.0 * EntityScale.BODY_REL
const BODY_HEIGHT := 34.0 * EntityScale.BODY_REL
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
## Katman başına temas durumu: {"rect", "ofset", "data" (kök/boy/faz/komşu RGBA8), "bend_img" (R8), "bend_tex", "plants" (kök hücresi ->
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
		layer.use_parent_material = false ## Tiled'daki 'use_parent_material' özelliği shader'ı yok sayardı (bkz. bake_harita.gd _make_carried_material_visible)
		if layer_name == "Çiçekler 1":
			## Çiçeklerin renkleri sabit kalır: ot shader'ının renk çeşitliliği (hue/doygunluk kayması) yeşiller içindi, çiçeği başka renge çevirirdi.
			mat.set_shader_parameter("hue_shift_amount", 0.0)
			mat.set_shader_parameter("sat_shift_amount", 0.0)
			mat.set_shader_parameter("val_shift_amount", 0.0)
		if _materials.is_empty():
			var s: Variant = mat.get_shader_parameter("strength")
			if s == null and mat.shader:
				s = RenderingServer.shader_get_parameter_default(mat.shader.get_rid(), "strength")
			_base_strength = float(s) if s != null else 1.35
		var state: Dictionary = _write_cell_data(mat, layer, layer_name == "Çiçekler 1")
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


## Hücre başına kök/boy -> RGBA8 veri dokusu (R = kökün karonun üstünden uzaklığı (texel), G = boy, B = geniş ot grubunun fazı (0 = tek karo / dikey ot),
## A = grup komşu bitleri: 1 = atlasta SOLDAKİ karo da aynı grupta, 2 = atlasta SAĞDAKİ). Kök ve boy haritadaki
## GERÇEK komşuluğa göre: altındaki hücrede aynı otun devamı (atlasta hemen alttaki karo, aynı kaynak/çevirme, çizgi kesintisiz)
## varsa kök alttaki karoda; üstündekinin devamıysa boy üst yarıdan başlar; yoksa tek karoluk ot.
##
## GENİŞ ÇALILAR (2026-10-09, kullanıcı: "bazı çalılar rüzgarla hareketlenince ikiye üçe bölünüyor"): shader pikseli karonun İÇİNDE kaydırır; kayma
## komşu karoda farklı faz alınca ya da içerik karodan taşınca karo sınırında boşluk/kopma oluşuyordu. Yatay (atlasta bitişik) ya da dikey bitişik karolar
## TEK bitki sayılır: ortak kök/boy (grubun en alt satırı), ortak faz (B), ve karo sınırında kayan içerik komşu karonun GERÇEK piksellerinden doldurulur
## (A bitleri; shader). En az iki sütunlu gruplar bu yolu kullanır, tek karo/dikey ot eskisi gibi kalır.
func _write_cell_data(mat: ShaderMaterial, layer: TileMapLayer, generic_links: bool = false) -> Dictionary:
	var rect: Rect2i = layer.get_used_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return {}
	var data := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
	var ts: TileSet = layer.tile_set
	var src_for_padding: TileSetAtlasSource = null
	var infos: Dictionary = {} ## hücre -> {"root","top","sid","alt","coords","flip"} (kök/üst: hücre üstüne göre, devam dahil)
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
		var td: TileData = layer.get_cell_tile_data(cell)
		infos[cell] = {"root": root, "top": top, "sid": layer.get_cell_source_id(cell), "alt": layer.get_cell_alternative_tile(cell),
				"coords": coords, "flip": td != null and td.flip_h, "flat": td == null or not (td.flip_v or td.transpose),
				"region": region, "img": img}
	## Bitişik karolar (atlasta yatay +1 / çevrikte -1, dikey +1; aynı kaynak + alternatif) = tek bitki grubu.
	var parent: Dictionary = {}
	for cell: Vector2i in infos:
		parent[cell] = cell
	for cell: Vector2i in infos:
		var a: Dictionary = infos[cell]
		var right: Vector2i = cell + Vector2i(1, 0)
		if infos.has(right):
			var b: Dictionary = infos[right]
			if b["sid"] == a["sid"] and b["alt"] == a["alt"] and b["coords"] == a["coords"] + (Vector2i(-1, 0) if a["flip"] else Vector2i(1, 0)):
				_union(parent, cell, right)
		var down: Vector2i = cell + Vector2i(0, 1)
		if infos.has(down):
			var c: Dictionary = infos[down]
			if c["sid"] == a["sid"] and c["alt"] == a["alt"] and c["coords"] == a["coords"] + Vector2i(0, 1):
				_union(parent, cell, down)
	## ÇİÇEKLER (2026-10-11, kullanıcı: "çiçeklerin animasyonu ikiye bölünüyor"): çiçekler haritada atlas sırasına UYMADAN, sadece görsel olarak
	## birleşecek şekilde dizilmiş (ör. atlasta (1,54),(0,54) yan yana değil ama haritada yan yana duruyor) -> yukarıdaki atlas komşuluğu onları ayrı
	## bitki sayıp her biri kendi fazıyla kayıyordu. Bu katmanda haritada yan yana/alt alta olan ve karo sınırında piksel piksel devam eden
	## karolar da aynı bitkidir (shader taşan içeriği komşunun GERÇEK pikselinden alır, bkz. komsu_veri).
	if generic_links:
		for cell: Vector2i in infos:
			var a2: Dictionary = infos[cell]
			if not a2["flat"]:
				continue
			var right2: Vector2i = cell + Vector2i(1, 0)
			if infos.has(right2) and _link_ok(a2, infos[right2]) and _edge_touches(a2, infos[right2], true):
				_union(parent, cell, right2)
			var down2: Vector2i = cell + Vector2i(0, 1)
			if infos.has(down2) and _link_ok(a2, infos[down2]) and _edge_touches(a2, infos[down2], false):
				_union(parent, cell, down2)
	var groups: Dictionary = {}
	for cell: Vector2i in infos:
		var r: Vector2i = _find(parent, cell)
		if not groups.has(r):
			groups[r] = {"cells": [], "root": -1000000, "top": 1000000, "min_x": 1000000, "max_x": -1000000}
		var g: Dictionary = groups[r]
		(g["cells"] as Array).append(cell)
		g["root"] = maxi(int(g["root"]), cell.y * 16 + int(infos[cell]["root"]))
		g["top"] = mini(int(g["top"]), cell.y * 16 + int(infos[cell]["top"]))
		g["min_x"] = mini(int(g["min_x"]), cell.x)
		g["max_x"] = maxi(int(g["max_x"]), cell.x)
	var wide_group: Dictionary = {} ## hücre -> grup kökü (sadece en az iki sütunlu gruplar)
	for r: Vector2i in groups:
		var g: Dictionary = groups[r]
		if int(g["max_x"]) > int(g["min_x"]) or (generic_links and (g["cells"] as Array).size() > 1):
			for cell: Vector2i in g["cells"]:
				wide_group[cell] = r
	## Ekran-solu/sağ komşu karonun atlas koordinatı (komsu_veri: 2 piksel/hücre, R = x, G = y, B = çevirme, A = 255 komşu var) + temas grupları.
	var nb := Image.create(rect.size.x * 2, rect.size.y, false, Image.FORMAT_RGBA8)
	var members: Dictionary = {} ## grup temsilcisi (rect'e göreli hücre) -> [rect'e göreli hücreler] (sadece geniş gruplar)
	var rep_of: Dictionary = {}  ## rect'e göreli hücre -> grup temsilcisi
	for cell: Vector2i in infos:
		var inf: Dictionary = infos[cell]
		var p: Vector2i = cell - rect.position
		var root: int = int(inf["root"])
		var top: int = int(inf["top"])
		var phase: int = 0
		var flags: int = 0
		if wide_group.has(cell):
			var g: Dictionary = groups[wide_group[cell]]
			root = int(g["root"]) - cell.y * 16
			top = int(g["top"]) - cell.y * 16
			phase = 1 + (absi(int(g["min_x"]) * 73 + int(g["root"]) * 131) % 255)
			var left_cell: Vector2i = cell + Vector2i(1, 0) if inf["flip"] else cell + Vector2i(-1, 0)
			var right_cell: Vector2i = cell + Vector2i(-1, 0) if inf["flip"] else cell + Vector2i(1, 0)
			if wide_group.get(left_cell, Vector2i(-9999, -9999)) == wide_group[cell]:
				flags |= 1
			if wide_group.get(right_cell, Vector2i(-9999, -9999)) == wide_group[cell]:
				flags |= 2
			var rep: Vector2i = wide_group[cell] - rect.position
			rep_of[p] = rep
			if not members.has(rep):
				members[rep] = []
			(members[rep] as Array).append(p)
			for side in 2:
				var nc: Vector2i = cell + Vector2i(-1 if side == 0 else 1, 0)
				if wide_group.get(nc, Vector2i(-9999, -9999)) == wide_group[cell]:
					var ni: Dictionary = infos[nc]
					var nco: Vector2i = ni["coords"]
					if nco.x < 256 and nco.y < 256:
						nb.set_pixel(p.x * 2 + side, p.y, Color8(nco.x, nco.y, 255 if ni["flip"] else 0, 255))
		data.set_pixel(p.x, p.y, Color8(clampi(root, 0, 255), clampi(maxi(1, root - top), 1, 255), phase, flags))
	mat.set_shader_parameter("veri", ImageTexture.create_from_image(data))
	mat.set_shader_parameter("komsu_veri", ImageTexture.create_from_image(nb))
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
	return {"rect": rect, "ofset": ofset, "data": data, "bend_img": bend_img, "bend_tex": bend_tex, "plants": {}, "touching": {}, "rep_of": rep_of, "members": members}


func _find(parent: Dictionary, c: Vector2i) -> Vector2i:
	var r: Vector2i = c
	while parent[r] != r:
		parent[r] = parent[parent[r]]
		r = parent[r]
	return r


func _union(parent: Dictionary, a: Vector2i, b: Vector2i) -> void:
	var ra: Vector2i = _find(parent, a)
	var rb: Vector2i = _find(parent, b)
	if ra != rb:
		parent[rb] = ra


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


## İki karo aynı bitki olabilir mi: aynı kaynak (aynı doku), hiçbiri döndürülmüş/dikey çevrilmemiş.
func _link_ok(a: Dictionary, b: Dictionary) -> bool:
	return a["sid"] == b["sid"] and b["flat"] and a["img"] == b["img"]


## Karonun EKRANDAKİ sütun sx / satır y pikselinin opaklığı (yatay çevrilmiş karoda atlas sütunu aynalanır).
func _screen_alpha(inf: Dictionary, sx: int, y: int) -> float:
	var r: Rect2i = inf["region"]
	var x: int = (r.size.x - 1 - sx) if inf["flip"] else sx
	return (inf["img"] as Image).get_pixel(r.position.x + x, r.position.y + clampi(y, 0, r.size.y - 1)).a


## a ile b'nin ortak kenarında (yatay: a solda b sağda; dikey: a üstte b altta) iki yanda da opak piksel var mı (±1 satır/sütun payıyla).
func _edge_touches(a: Dictionary, b: Dictionary, horizontal: bool) -> bool:
	var size: Vector2i = (a["region"] as Rect2i).size
	if horizontal:
		for y in size.y:
			if _screen_alpha(a, size.x - 1, y) < 0.1:
				continue
			for dy in [-1, 0, 1]:
				if _screen_alpha(b, 0, y + dy) > 0.1:
					return true
	else:
		for x in size.x:
			if _screen_alpha(a, x, size.y - 1) < 0.1:
				continue
			for dx in [-1, 0, 1]:
				if _screen_alpha(b, clampi(x + dx, 0, size.x - 1), 0) > 0.1:
					return true
	return false


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
	var rep_of: Dictionary = state["rep_of"]
	var members: Dictionary = state["members"]
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
				## Geniş bitki (grup) TEK bitki gibi eğilir: tüm karolar grup temsilcisinin eğilmesini paylaşır (yoksa dokunulan karo kayar, komşusu kalır = bölünme).
				var key: Vector2i = rep_of.get(p, p)
				targets[key] = clampf(float(targets.get(key, 0.0)) + dir * amt * BEND_MAX, -BEND_MAX, BEND_MAX)
				touching[key] = true
				if not plants.has(key):
					plants[key] = [0.0, 0.0]
				if not (state["touching"] as Dictionary).has(key):
					var push: float = clampf(vel.length() * BEND_IMPULSE_RATIO, 0.0, BEND_IMPULSE_MAX)
					plants[key][1] = float(plants[key][1]) + (dir if dir != 0.0 else 1.0) * push
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
		for m: Vector2i in members.get(p, [p]):
			img.set_pixel(m.x, m.y, px)
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
