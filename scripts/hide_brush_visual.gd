extends Node

## SAKLANMA ÇALILIĞI GÖRÜNÜMÜ (2026-10-10, kullanıcı: "çalıların içine girince bedenimizin yarısı görünmüyor, sadece hafif saydam olalım ... içindeyken çalılar
## sallansın ve bedenimiz çalıların içinde yürüyormuş gibi görünsün").
##  - 2026-10-10 LoL TARZI ÇALILIK (kullanıcı: "league of legends tarzı" + "içine girip saklanabilmemiz ve vücudumuzun uyum sağlaması için kare kare eklenmiş çalılar"):
##    çalılık, yan yana dikişsiz birleşen 16x16 uzun ot karolarından boyanır (tools/hide_bush_proto/gen_lol_brush.py; kenar karoları dış hattı doğal yapar). HER HÜCRE
##    kendi parçası: kendi kökü (derinlik: içerideki karakterin bacakları altındaki sıraların otlarının arkasında kalır), kendi hışırtısı, saklanma da o hücrede
##    (hide_brush.gd contains). Eğilen yaprak karo kenarından taşınca KOMŞU karonun pikseli okunur (komsu_veri, grup sınırı aranmaz) -> hışırtıda dikiş açılmaz.
##  - İçinden bir karakter yürüyünce SADECE bulunduğu noktanın çevresi (`RUSTLE_RADIUS`) hışırdar: hücre başına yay-sönümlü sallantı, girişte itki, uzaklaştıkça
##    zayıflayan ağırlık; shader hücreler arasını doğrusal süzer (yumuşak dalga). Çalının geri kalanı DURUR (`AMBIENT_STRENGTH` 0 = rüzgar sallanması yok;
##    kullanıcı: "içindeyken sadece bulunduğum konumun sallanmasını istedim"). Ağ gerekmez: uzak kuklalar da aynı yerel konumdan okunur.
##  - Ön kopya (derinlik): karakter çalının içindeyken yapraklar onu SİLMEZ, `INSIDE_FOLIAGE_ALPHA` opaklıkla üstüne çizilir (gövde yaprakların arkasında görünür).
## Kurulum depth_occluders.gd'den (`install`): ön kopya orada yaratılır, böylece yaratık/karakter listesi aynı yoldan beslenir.

const HideBrushScript := preload("res://scripts/hide_brush.gd")
const SHADER_PATH := "res://scenes/saklanma_calilik.gdshader"

const CELL := 16
## İçindeki karakterin BACAK kısmının üstüne çizilen yaprak opaklığı (0 = hiç örtmez, 1 = eski tam örtü; kullanıcı "gövdenin yarısı görünmüyor" /
## "içinde gözükmüyoruz" demişti: sadece alt yarı, yarı saydam; üst yarı açıkta. Alt/üst oranı shader'da ICERDE_ORTU_ORANI).
const INSIDE_FOLIAGE_ALPHA := 0.65 ## 2026-10-10: 0,5 -> 0,65 + shader ICERDE_ORTU_ORANI 0,75 (karakter içeride daha gömülü görünsün)
## Çalının kendiliğinden (rüzgarla) sallanması: 0 = kapalı, sadece içinden geçen karakterin çevresi sallanır.
const AMBIENT_STRENGTH := 0.0
## LoL çalılığı: karakterin çevresindeki otlar hışırdar (komşu karo pikseli okunduğu için kenarda kesilme yok).
const RUSTLE_BEND := 3.0
const LEAN_BEND := 1.4
## Hışırtının karakter çevresindeki yarıçapı (dünya px) ve merkezin ayaktan yukarı kayması (gövde ortası).
const RUSTLE_RADIUS := 26.0 ## sadece karakterin içinde durduğu yerin çevresi (yaklaşık bir hücre çevresi) hışırdar
const RUSTLE_CENTER_UP := 10.0
const SPRING_K := 140.0
const SPRING_DAMP := 8.0
const BEND_TEX_SCALE := 16.0
const BEND_LIMIT := 5.0
const MOVE_MIN := 14.0
const MOVE_FULL := 90.0
const ENTER_IMPULSE_RATIO := 0.12
const ENTER_IMPULSE_MAX := 26.0
const MAX_CHARACTERS := 8

var layer: TileMapLayer = null
var _rect: Rect2i
var _origin: Vector2
var _cell_gid: Dictionary = {}   ## hücre -> küme numarası
var _groups: Dictionary = {}     ## küme -> {"cells": Array[Vector2i], "phase": float}
var _bend_img: Image
var _bend_tex: ImageTexture
var _state: Dictionary = {}      ## hücre -> [eğilme, hız] (sadece etkin/durulan hücreler)
var _prev_feet: Dictionary = {}
var _clock: float = 0.0


## Tek katmanın çözümlemesi (saf; sahneye dokunmaz; testler çağırır): {"rows": hücre -> (ilk opak satır, son opak satır) (karo içi),
## "gid": hücre -> küme, "groups": küme -> {"cells", "bottom" (kök satırı, hücre ızgarasına göre mutlak px), "top"}}. Hiç opak pikseli olmayan karo yok sayılır.
static func analyze(l: TileMapLayer) -> Dictionary:
	var rows: Dictionary = {}
	var ts: TileSet = l.tile_set
	var cache: Dictionary = {}
	var images: Dictionary = {}
	for cell: Vector2i in l.get_used_cells():
		var sid: int = l.get_cell_source_id(cell)
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null or src.texture == null:
			continue
		var coords: Vector2i = l.get_cell_atlas_coords(cell)
		var key := Vector3i(sid, coords.x, coords.y)
		if not cache.has(key):
			if not images.has(sid):
				var im: Image = src.texture.get_image()
				if im != null and im.is_compressed():
					im.decompress()
				images[sid] = im
			cache[key] = _opaque_rows(images[sid], src.get_tile_texture_region(coords))
		var r: Vector2i = cache[key]
		if r.x >= 0:
			rows[cell] = r
	## Her hücre kendi grubu (eskiden 8-bağlı komşular tek küme olurdu: tek parça sallanan "toplu" çalı).
	var gid: Dictionary = {}
	var groups: Dictionary = {}
	var ids: Dictionary = {}
	for cell: Vector2i in rows:
		ids[cell] = ids.size() + 1
		var g: int = ids[cell]
		gid[cell] = g
		if not groups.has(g):
			groups[g] = {"cells": [], "bottom": -1000000, "top": 1000000}
		var info: Dictionary = groups[g]
		(info["cells"] as Array).append(cell)
		info["bottom"] = maxi(int(info["bottom"]), cell.y * CELL + (rows[cell] as Vector2i).y)
		info["top"] = mini(int(info["top"]), cell.y * CELL + (rows[cell] as Vector2i).x)
	return {"rows": rows, "gid": gid, "groups": groups}


static func _opaque_rows(img: Image, r: Rect2i) -> Vector2i:
	if img == null:
		return Vector2i(-1, -1)
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


static func cell_origin(l: TileMapLayer) -> Vector2:
	return l.to_global(l.map_to_local(Vector2i.ZERO)) - Vector2(l.tile_set.tile_size) * 0.5


## Her hücre için ÇALININ kökünün dünya y'si (derinlik örtüsü: kök karakterin ayağından aşağıdaysa çalı onu örter).
static func root_bases(l: TileMapLayer, a: Dictionary) -> Dictionary:
	var origin: Vector2 = cell_origin(l)
	var out: Dictionary = {}
	var groups: Dictionary = a["groups"]
	for cell: Vector2i in a["gid"]:
		var g: Dictionary = groups[a["gid"][cell]]
		out[cell] = origin.y + float(g["bottom"]) + 1.0
	return out


## depth_occluders.gd'den: katmanı sallanan materyale çevirir, ön kopyayı (depth.add_brush_front) kurar, güncelleyici düğümü ekler. Kurulamazsa null.
static func install(depth: Node, l: TileMapLayer) -> Node:
	var a: Dictionary = analyze(l)
	if (a["rows"] as Dictionary).is_empty():
		return null
	var v: Node = (load("res://scripts/hide_brush_visual.gd") as GDScript).new()
	depth.add_child(v)
	var mat: ShaderMaterial = v.call("_setup", l, a)
	l.material = mat
	l.use_parent_material = false
	depth.call("add_brush_front", l, root_bases(l, a), mat)
	return v


func _setup(l: TileMapLayer, a: Dictionary) -> ShaderMaterial:
	name = "HideBrushVisual"
	layer = l
	_cell_gid = a["gid"]
	_groups = a["groups"]
	_origin = cell_origin(l)
	_rect = l.get_used_rect()
	var rows: Dictionary = a["rows"]
	var data := Image.create(_rect.size.x, _rect.size.y, false, Image.FORMAT_RGBA8)
	var nb := Image.create(_rect.size.x, _rect.size.y, false, Image.FORMAT_RGBA8)
	for cell: Vector2i in rows:
		var g: Dictionary = _groups[_cell_gid[cell]]
		var p: Vector2i = cell - _rect.position
		var root: int = int(g["bottom"]) - cell.y * CELL
		var height: int = int(g["bottom"]) - int(g["top"])
		var phase: int = 1 + (int(_cell_gid[cell]) * 53) % 254
		data.set_pixel(p.x, p.y, Color8(clampi(root, 0, 255), clampi(maxi(height, 1), 1, 255), phase, 255))
		var left: Vector2i = cell + Vector2i(-1, 0)
		var right: Vector2i = cell + Vector2i(1, 0)
		var c := Color8(0, 0, 0, 0)
		var cr: int = 0
		var cg: int = 0
		var cb: int = 0
		var ca: int = 0
		if rows.has(left):
			var lc: Vector2i = l.get_cell_atlas_coords(left)
			cr = lc.x + 1
			cg = lc.y + 1
		if rows.has(right):
			var rc: Vector2i = l.get_cell_atlas_coords(right)
			cb = rc.x + 1
			ca = rc.y + 1
		c = Color8(cr, cg, cb, ca)
		nb.set_pixel(p.x, p.y, c)
	_bend_img = Image.create(_rect.size.x, _rect.size.y, false, Image.FORMAT_R8)
	_bend_img.fill(Color8(128, 0, 0))
	_bend_tex = ImageTexture.create_from_image(_bend_img)
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	mat.set_shader_parameter("veri_sway", ImageTexture.create_from_image(data))
	mat.set_shader_parameter("komsu_veri", ImageTexture.create_from_image(nb))
	mat.set_shader_parameter("egilme_veri", _bend_tex)
	mat.set_shader_parameter("sway_var", true)
	mat.set_shader_parameter("sway_baslangic", Vector2(_rect.position))
	mat.set_shader_parameter("sway_boyut", Vector2(_rect.size))
	mat.set_shader_parameter("sway_ofset", _origin)
	mat.set_shader_parameter("strength", AMBIENT_STRENGTH)
	mat.set_shader_parameter("egri_ussu", 1.0)
	var ts: TileSet = l.tile_set
	for cell: Vector2i in rows:
		var src := ts.get_source(l.get_cell_source_id(cell)) as TileSetAtlasSource
		if src != null:
			mat.set_shader_parameter("karo_hucre", float(src.texture_region_size.x + (2 if src.use_texture_padding else 0)))
			mat.set_shader_parameter("karo_dolgu", 1.0 if src.use_texture_padding else 0.0)
			break
	return mat


## Dünya noktasının çalılık kümesi (0 = yok); boş (tamamen saydam) bir hücredeyse yanındaki dolu hücrenin kümesi.
func group_at(world: Vector2) -> int:
	if layer == null:
		return 0
	var c: Vector2i = layer.local_to_map(layer.to_local(world))
	if _cell_gid.has(c):
		return int(_cell_gid[c])
	if layer.get_cell_source_id(c) == -1:
		return 0
	for d: Vector2i in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		if _cell_gid.has(c + d):
			return int(_cell_gid[c + d])
	return 0


func _process(delta: float) -> void:
	if layer == null or not is_instance_valid(layer):
		return
	_clock += delta
	var occupants: Array = [] ## [ayak, hız (px/sn), yön işareti]
	var seen: Dictionary = {}
	var count: int = 0
	for group_name in ["player", "remote_players"]:
		for n in get_tree().get_nodes_in_group(group_name):
			if count >= MAX_CHARACTERS:
				break
			if not (n is Node2D) or not is_instance_valid(n) or n.get("is_dead") == true or not (n as Node2D).is_visible_in_tree():
				continue
			count += 1
			var feet: Vector2 = (n as Node2D).global_position + Vector2(0.0, HideBrushScript.FEET_OFFSET)
			var id: int = n.get_instance_id()
			seen[id] = true
			var vel: Vector2 = (feet - Vector2(_prev_feet.get(id, feet))) / maxf(delta, 0.001)
			_prev_feet[id] = feet
			if group_at(feet) != 0:
				occupants.append([feet, vel.length(), signf(vel.x) if absf(vel.x) > 1.0 else 1.0])
	for id in _prev_feet.keys():
		if not seen.has(id):
			_prev_feet.erase(id)
	step(delta, occupants)


## Hışırtı: occupants = [[ayak (dünya), hız (px/sn), yön işareti], ...] (içerideki karakterler). Karakterin çevresindeki HÜCRELER yay-sönümle sallanır,
## hücre başına eğilme dokusuna yazılır (testler doğrudan çağırır).
func step(delta: float, occupants: Array) -> void:
	var dt: float = minf(delta, 0.05)
	var targets: Dictionary = {} ## hücre -> hedef eğilme
	var pushes: Dictionary = {}  ## hücre -> giriş itkisi (sadece bu karede yeni etkinleşenler)
	for o: Array in occupants:
		var feet: Vector2 = o[0]
		var speed: float = o[1]
		var dir: float = o[2]
		var mv: float = clampf((speed - MOVE_MIN) / (MOVE_FULL - MOVE_MIN), 0.0, 1.0)
		var center: Vector2 = feet - Vector2(0.0, RUSTLE_CENTER_UP)
		var cc: Vector2i = layer.local_to_map(layer.to_local(center))
		var reach: int = ceili(RUSTLE_RADIUS / float(CELL)) + 1
		for dx in range(-reach, reach + 1):
			for dy in range(-reach, reach + 1):
				var cell := cc + Vector2i(dx, dy)
				if not _cell_gid.has(cell):
					continue
				var cell_center: Vector2 = layer.to_global(layer.map_to_local(cell))
				var w: float = 1.0 - clampf(cell_center.distance_to(center) / RUSTLE_RADIUS, 0.0, 1.0)
				if w <= 0.0:
					continue
				var phase: float = float(cell.x * 7 + cell.y * 13) * 0.45
				var t: float = w * mv * (RUSTLE_BEND * sin(_clock * 12.0 + phase) + LEAN_BEND * dir)
				if absf(t) >= absf(float(targets.get(cell, 0.0))):
					targets[cell] = t
				if not _state.has(cell) and mv > 0.0:
					pushes[cell] = float(pushes.get(cell, 0.0)) + dir * clampf(speed * ENTER_IMPULSE_RATIO, 0.0, ENTER_IMPULSE_MAX) * w
	for cell: Vector2i in targets:
		if not _state.has(cell):
			_state[cell] = [0.0, float(pushes.get(cell, 0.0))]
	if _state.is_empty():
		return
	var done: Array = []
	for cell: Vector2i in _state.keys():
		var bend: float = _state[cell][0]
		var v: float = _state[cell][1]
		var target: float = float(targets.get(cell, 0.0))
		v += ((target - bend) * SPRING_K - v * SPRING_DAMP) * dt
		bend = clampf(bend + v * dt, -BEND_LIMIT, BEND_LIMIT)
		if not targets.has(cell) and absf(bend) < 0.03 and absf(v) < 0.03:
			bend = 0.0
			v = 0.0
			done.append(cell)
		_state[cell] = [bend, v]
		var p: Vector2i = cell - _rect.position
		_bend_img.set_pixel(p.x, p.y, Color8(clampi(roundi(128.0 + bend * BEND_TEX_SCALE), 0, 255), 0, 0))
	for cell in done:
		_state.erase(cell)
	_bend_tex.update(_bend_img)


## Bir hücrenin şimdiki eğilmesi (texel; testler).
func bend_at(cell: Vector2i) -> float:
	return float((_state.get(cell, [0.0, 0.0]) as Array)[0])
