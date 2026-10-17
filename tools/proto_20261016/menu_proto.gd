extends SceneTree

## KARAKTER SEÇİMİ + ANA MENÜ yeni tasarım PROTOTİPLERİ (2026-10-16). Oyuna BAĞLI DEĞİL; user://meta.cfg'ye dokunmaz.
## Kullanıcı: "oda kurulduktan sonra direk karakter seçim ekranına geçilsin ve o esnada oyuncular bağlansın, şu anki 2 aşamalı
##   halden hoşlanmıyorum" + "ana menü için 4 prototip, yapay zeka kullanma, hafif koyu tonlar".
## -> Seçim ekranı = oda lobisi + karakter seçimi TEK ekranda: oyuncu listesi (bağlanan oyuncu satırı dahil), sohbet, oda bilgisi,
##    karakter/silah/evcil/ruhani seçimi, host "OYUNU BAŞLAT" (herkes hazır olunca).
## Arka planlar: oyunun GERÇEK haritası (scenes/harita_baked.tscn) kamera + akşam tonu (CanvasModulate) + gerçek karakter/evcil
##   sprite'ları (idle_/sit_/walk_ klipleri). Kodla çizilmiş manzara / üretilmiş görüntü YOK; tek ek: kenar karartma.
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261016/menu_proto.gd
##   MENU_CAP_DIR = çıktı klasörü (zorunlu), MENU_CAP_ONLY = "sec_a,ana_b" gibi seçili çekimler (boşsa hepsi + 2 özet).

const W := 1920.0
const H := 1080.0
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## Ruh Mağazası prototipiyle (ruh_magaza_proto.gd) aynı 4 koyu palet - ekranlar birbirine uysun.
const PAL := {
	## A - Kayrak & Altın
	"a": {"panel": Color("#1b212e"), "panel2": Color("#242c3b"), "panel3": Color("#2f3a4f"), "inset": Color("#141924"),
		"line": Color("#353f55"), "line_hi": Color("#56657f"), "text": Color("#ece6d7"), "dim": Color("#96a0b2"),
		"accent": Color("#d9b46a"), "accent_dk": Color("#6e5426"), "accent_text": Color("#21180a"),
		"good": Color("#94c97e"), "bad": Color("#dc8676"), "price": Color("#eccb7e"), "spot": Color("#6f8fc0"),
		"tint": Color(0.60, 0.64, 0.80)},
	## B - Gece Moru, ruh mavisi vurgu
	"b": {"panel": Color("#1a1629"), "panel2": Color("#231d38"), "panel3": Color("#30284d"), "inset": Color("#130f20"),
		"line": Color("#352c55"), "line_hi": Color("#574a86"), "text": Color("#eee8f7"), "dim": Color("#a59dc0"),
		"accent": Color("#8fd9e8"), "accent_dk": Color("#2c6878"), "accent_text": Color("#0c1a22"),
		"good": Color("#9fe0aa"), "bad": Color("#ee8c9c"), "price": Color("#a6e8f2"), "spot": Color("#8f7fd8"),
		"tint": Color(0.60, 0.55, 0.78)},
	## C - Koyu Ahşap + Kehribar (kabul edilen Ruh Mağazası F'nin teması)
	"c": {"panel": Color("#241c16"), "panel2": Color("#2e251d"), "panel3": Color("#3b2f24"), "inset": Color("#1a140f"),
		"line": Color("#45372a"), "line_hi": Color("#6a5440"), "text": Color("#efe2c6"), "dim": Color("#ad9b80"),
		"accent": Color("#e2a64e"), "accent_dk": Color("#6a4416"), "accent_text": Color("#24160a"),
		"good": Color("#a9c96e"), "bad": Color("#dc7f60"), "price": Color("#f2c674"), "spot": Color("#c0803a"),
		"tint": Color(0.78, 0.66, 0.56)},
	## D - Gece Ormanı, nane vurgu
	"d": {"panel": Color("#152220"), "panel2": Color("#1c2d2a"), "panel3": Color("#264037"), "inset": Color("#0f1918"),
		"line": Color("#2c443e"), "line_hi": Color("#46665c"), "text": Color("#e7efe3"), "dim": Color("#92aba2"),
		"accent": Color("#a3dba9"), "accent_dk": Color("#2f5f3e"), "accent_text": Color("#0e2018"),
		"good": Color("#a3dba9"), "bad": Color("#e38c7c"), "price": Color("#f0da94"), "spot": Color("#5fa08a"),
		"tint": Color(0.52, 0.68, 0.64)},
}

const NAMES := {
	"sec_a": "SEÇİM A - Üç Sütun (oyuncular | vitrin | karakterler)",
	"sec_b": "SEÇİM B - Takım Sırası (herkesin seçimi üstte büyük)",
	"sec_c": "SEÇİM C - Kamp Sahnesi (seçilenler haritada duruyor)",
	"sec_d": "SEÇİM D - Oyuncu Kartları + yerinde silah/evcil/ruhani",
	"ana_a": "ANA MENÜ A - Köy Akşamı (sol panel)",
	"ana_b": "ANA MENÜ B - Köprü Başı (orta tabela)",
	"ana_c": "ANA MENÜ C - Mod Kartları (Tek / Çok oyunculu büyük)",
	"ana_d": "ANA MENÜ D - Sinematik (alt şerit)",
	"bg_a": "SADE ARKA PLAN A - Tek Ağaç (gece çayırı, koru + devrik kütük)",
	"bg_b": "SADE ARKA PLAN B - Kütük Kulübe (yanan pencereler)",
	"bg_c": "SADE ARKA PLAN C - Ocak Başı (iç mekan, şömine + lamba)",
	"bg_d": "SADE ARKA PLAN D - Orman Kıyısı (ağaç şeridi)",
	"sol_a": "SOL MENÜ A - Asılı Tahtalar (tabela + ip + koyu ahşap)",
	"sol_b": "SOL MENÜ B - Ahşap Kart Listesi (duvar paneli, ikon + alt yazı)",
	"sol_c": "SOL MENÜ C - Defter (parşömen sayfa, kırmızı ayraç)",
	"sol_d": "SOL MENÜ D - Panelsiz Ateş Işığı (büyük yazı, yanan mum)",
}

## Oyuncu renkleri (satır şeridi, kart üstü seçim işareti, sohbet adı).
const PCOL := [Color("#e8c26a"), Color("#7fd0d8"), Color("#e58f9e"), Color("#a99be6")]

## Sahte oda: host + 1 hazır + 1 seçiyor + 1 BAĞLANIYOR (bağlanma seçim ekranında olur).
const ROOM := {"name": "perva'nın odası", "net": "İnternet", "max": 4}
const PLAYERS := [
	{"name": "perva", "host": true, "me": true, "char": 4, "weapon": "fire_staff", "pet": "peri", "spirit": "can", "state": "ready"},
	{"name": "Baykuş", "char": 1, "weapon": "uzunkilic", "pet": "kopek", "spirit": "tank", "state": "ready"},
	{"name": "Gölge", "char": 8, "weapon": "yay", "pet": "kelebek", "spirit": "adc", "state": "picking"},
	{"name": "Kirpi_07", "state": "connecting"},
]
const CHAT := [
	["sys", -1, "Oda kuruldu. Arkadaşların bağlanırken karakterini seç."],
	["msg", 1, "ben öne geçerim, Talon aldım"],
	["msg", 2, "elara mı alsam yay mı bilemedim"],
	["sys", -1, "Kirpi_07 bağlanıyor..."],
	["msg", 0, "herkes hazır olunca başlatıyorum"],
]
const SEL := 4 ## yerel oyuncunun (host) seçili karakteri

const SHORT := {4: "Büyücü", 5: "Assasin", 7: "Şovalye", 13: "Vampir", 14: "Hadime"}

const G_CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."]
const G_LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]
const G_LEFT := ["..#", ".##", "###", ".##", "..#"]
const G_RIGHT := ["#..", "##.", "###", "##.", "#.."]
const G_DOWN := ["#####", ".###.", "..#.."]
const G_PERSON := ["..###..", "..###..", "..###..", ".......", ".#####.", "#######", "#######"]
const G_GLOBE := [".#####.", "#..#..#", "#######", "#..#..#", "#######", "#..#..#", ".#####."]
const G_CROWN := ["#..#..#", "##.#.##", "#######", "#######", ".#####."]
const G_DOTS := ["##..##..##", "##..##..##"]
const G_X := ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"]
const G_QMARK := [".####.", "##..##", "....##", "...##.", "..##..", "......", "..##.."]

var _dir: String = OS.get_environment("MENU_CAP_DIR")
var P: Dictionary = {}
var MP: GDScript = null
var SI: GDScript = null
var WC: GDScript = null
var PC: GDScript = null
var SS: GDScript = null
var LU: GDScript = null
var ES: GDScript = null
var CH: Array = []
var _world: Node2D = null
var _cam: Camera2D = null
var _cm: CanvasModulate = null
var _actors: Node2D = null
var _ui: CanvasLayer = null
var _vig_cache: Dictionary = {}
var _body_cache: Dictionary = {}


## ---------------------------------------------------------------- çizim sınıfları
class ShardIcon extends Control:
	var dim: bool = false

	func _init(px: float = 24.0, dimmed: bool = false) -> void:
		custom_minimum_size = Vector2(px, px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim = dimmed

	func _draw() -> void:
		var s: float = size.x
		var c: float = s * 0.5
		var top := Vector2(c, s * 0.04)
		var mid_y: float = s * 0.38
		var l := Vector2(s * 0.12, mid_y)
		var r := Vector2(s * 0.88, mid_y)
		var bot := Vector2(c, s * 0.96)
		var m := Vector2(c, mid_y)
		var k: float = 0.5 if dim else 1.0
		var t := Color(k, k, k, 1)
		draw_colored_polygon(PackedVector2Array([top, m, l]), Color("#b4f1f5") * t)
		draw_colored_polygon(PackedVector2Array([top, r, m]), Color("#73d2dc") * t)
		draw_colored_polygon(PackedVector2Array([l, m, bot]), Color("#3f9fb0") * t)
		draw_colored_polygon(PackedVector2Array([m, r, bot]), Color("#27707f") * t)
		draw_polyline(PackedVector2Array([top, r, bot, l, top]), Color("#0b1418"), maxf(2.0, roundf(s / 12.0)))


class Glyph extends Control:
	var rows: Array = []
	var col: Color = Color.WHITE
	var px: int = 3

	func _init(pattern: Array, c: Color, pixel: int = 3) -> void:
		rows = pattern
		col = c
		px = pixel
		custom_minimum_size = Vector2(str(rows[0]).length() * px, rows.size() * px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var off := ((size - custom_minimum_size) * 0.5).floor()
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				if row[x] == "#":
					draw_rect(Rect2(off + Vector2(x * px, y * px), Vector2(px, px)), col)


## Basamaklı ışık havuzu + zemin elipsi (vitrin kutuları).
class Spot extends Control:
	var col: Color = Color.WHITE
	var floor_y: float = 0.8

	func _init(c: Color, fy: float = 0.8) -> void:
		col = c
		floor_y = fy
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := (size * Vector2(0.5, 0.5)).floor()
		var r: float = minf(size.x, size.y) * 0.48
		for i in 4:
			draw_circle(c, floorf(r * (1.0 - i * 0.2)), Color(col, 0.06 + i * 0.03))
		var fc := Vector2(c.x, floorf(size.y * floor_y))
		draw_set_transform(fc, 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, floorf(r * 0.62), Color(col, 0.2))
		draw_circle(Vector2.ZERO, floorf(r * 0.42), Color(col, 0.16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Dünyadaki karakterin piksel elips ayak gölgesi.
class FootShadow extends Node2D:
	var rad: Vector2 = Vector2(19, 7)

	func _draw() -> void:
		for y in range(-int(rad.y), int(rad.y) + 1):
			var t: float = float(y) / rad.y
			var hw: float = floorf(rad.x * sqrt(maxf(0.0, 1.0 - t * t)))
			draw_rect(Rect2(-hw, y, hw * 2.0, 1), Color(0, 0, 0, 0.3))


## Seçim ekranı sahnesi: oyuncu yuvasının yerdeki piksel halkası (oyuncu renginde).
class FootRing extends Node2D:
	var rad: Vector2 = Vector2(17, 6)
	var col: Color = Color.WHITE

	func _inside(x: int, y: int) -> bool:
		return pow(x / rad.x, 2.0) + pow(y / rad.y, 2.0) <= 1.0

	func _draw() -> void:
		for y in range(-int(rad.y), int(rad.y) + 1):
			for x in range(-int(rad.x), int(rad.x) + 1):
				if _inside(x, y) and (not _inside(x - 1, y) or not _inside(x + 1, y) or not _inside(x, y - 1) or not _inside(x, y + 1)):
					draw_rect(Rect2(x, y, 1, 1), col)


## İnce ilerleme çizgisi (bağlanan oyuncu).
class Bar extends Control:
	var frac: float = 0.0
	var fill: Color = Color.WHITE
	var back: Color = Color.BLACK

	func _init(f: float, fc: Color, bc: Color, h: float = 8.0) -> void:
		frac = f
		fill = fc
		back = bc
		custom_minimum_size = Vector2(0, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), back)
		draw_rect(Rect2(0, 0, floorf(size.x * frac), size.y), fill)


## ---------------------------------------------------------------- akış
func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await process_frame
	MP = load("res://scripts/meta_progress.gd")
	SI = load("res://scripts/stat_icon.gd")
	WC = load("res://scripts/weapon_catalog.gd")
	PC = load("res://scripts/pet_catalog.gd")
	SS = load("res://scripts/spiritual_skills.gd")
	LU = load("res://scripts/menu_lobby_ui.gd")
	ES = load("res://scripts/entity_scale.gd")
	var tmp: String = _dir.path_join("_meta_menu_proto.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", 1340)
	cfg.set_value("meta", "total_earned", 2600)
	cfg.set_value("meta", "starter_granted", true)
	cfg.set_value("unlocked", "char", [3, 8])
	cfg.set_value("unlocked", "weapon", ["yay", "uzunkilic", "fire_staff", "pence", "boomerang"])
	cfg.set_value("unlocked", "pet", ["peri", "kelebek", "papagan"])
	cfg.set_value("unlocked", "spirit", ["tank", "adc"])
	cfg.save(tmp)
	MP.set_path_override(tmp)
	for k in Characters.DEFS.keys():
		CH.append(int(k))
	CH.sort()
	_setup_world()
	var shots: Array = ["sec_a", "sec_b", "sec_c", "sec_d", "ana_a", "ana_b", "ana_c", "ana_d", "bg_a", "bg_b", "bg_c", "bg_d", "sol_a", "sol_b", "sol_c", "sol_d"]
	var only: String = OS.get_environment("MENU_CAP_ONLY")
	var imgs: Dictionary = {}
	for tag: String in shots:
		if only != "" and not tag in only.split(","):
			continue
		var ui: Control = call("_design_" + tag) ## _root() kendini _ui'ye ekler
		await _frames(10)
		await RenderingServer.frame_post_draw
		if OS.get_environment("MENU_DEBUG") != "":
			_debug_sizes(ui, 0)
		var img: Image = root.get_texture().get_image()
		img.save_png(_dir.path_join("%s.png" % tag))
		imgs[tag] = img
		print("SHOT %s %dx%d" % [tag, img.get_width(), img.get_height()])
		ui.queue_free()
		await process_frame
	if only == "":
		await _overview(imgs, ["sec_a", "sec_b", "sec_c", "sec_d"], "sec_ozet.png")
		await _overview(imgs, ["ana_a", "ana_b", "ana_c", "ana_d"], "ana_ozet.png")
	if only == "" or only.begins_with("bg_"):
		await _overview(imgs, ["bg_a", "bg_b", "bg_c", "bg_d"], "ana_sade_ozet.png")
	if only == "" or only.begins_with("sol_"):
		await _overview(imgs, ["sol_a", "sol_b", "sol_c", "sol_d"], "ana_sol_ozet.png")
	DirAccess.remove_absolute(tmp)
	quit()


## Yerleşim taşması ayıklama: beklenenden geniş Control'leri yazar (MENU_DEBUG=1).
func _debug_sizes(n: Node, depth: int) -> void:
	if depth > 9:
		return
	for c in n.get_children():
		if c is Control:
			var cc := c as Control
			if depth <= 1 or cc.get_combined_minimum_size().x > 560:
				print("%s%s %s pos=%s size=%s min=%s" % ["  ".repeat(depth), cc.get_class(), cc.name, cc.position, cc.size, cc.get_combined_minimum_size()])
			_debug_sizes(cc, depth + 1)


func _overview(imgs: Dictionary, tags: Array, out: String) -> void:
	_view(Vector2(-4000, -4000), 1.0, Color.BLACK)
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = MenuKit.font()
	r.theme = th
	_ui.add_child(r)
	var bg := ColorRect.new()
	bg.color = Color("#0b0b0d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(bg)
	var g := GridContainer.new()
	g.columns = 2
	g.position = Vector2(12, 4)
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 2)
	r.add_child(g)
	for tag: String in tags:
		if not imgs.has(tag):
			continue
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var l := Label.new()
		l.text = NAMES[tag]
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Color("#e8e4da"))
		v.add_child(l)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(imgs[tag])
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.custom_minimum_size = Vector2(936, 506)
		v.add_child(tr)
		g.add_child(v)
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join(out))
	r.queue_free()
	await process_frame


## ---------------------------------------------------------------- dünya (gerçek harita)
func _setup_world() -> void:
	_world = Node2D.new()
	_world.name = "Main"
	root.add_child(_world)
	current_scene = _world
	var map: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	map.name = "Harita"
	_world.add_child(map)
	_actors = Node2D.new()
	_actors.z_index = 20
	_world.add_child(_actors)
	_cm = CanvasModulate.new()
	_world.add_child(_cm)
	_cam = Camera2D.new()
	_world.add_child(_cam)
	_cam.make_current()
	_ui = CanvasLayer.new()
	_ui.layer = 5
	root.add_child(_ui)


func _view(center: Vector2, zoom: float, tint: Color) -> void:
	_cam.position = center
	_cam.zoom = Vector2(zoom, zoom)
	_cm.color = tint
	for c in _actors.get_children():
		c.queue_free()


func _w2s(wpos: Vector2) -> Vector2:
	return (wpos - _cam.position) * _cam.zoom + Vector2(W, H) * 0.5


## Gerçek karakter sprite'ı: oyuncu kökü 0.5 ölçekli, sprite ölçeği = tanım ölçeği x EntityScale.SIZE (player.gd ile aynı).
func _actor(id: int, anim: String, wpos: Vector2, frame: int = 0, flip: bool = false, ghost: bool = false) -> Node2D:
	var d: Dictionary = Characters.get_def(id)
	var holder := Node2D.new()
	holder.position = wpos
	holder.scale = Vector2(0.5, 0.5)
	var sh := FootShadow.new()
	sh.position = Vector2(0, float(d.get("ground_shadow_y", 32.5)))
	holder.add_child(sh)
	var sf: SpriteFrames = load(str(d.get("frames", ""))) as SpriteFrames
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.animation = StringName(anim) if sf.has_animation(anim) else &"idle_down"
	spr.frame = mini(frame, sf.get_frame_count(spr.animation) - 1)
	spr.stop()
	spr.scale = (d.get("scale", Vector2(1.27575, 1.27575)) as Vector2) * float(ES.SIZE)
	spr.offset = d.get("offset", Vector2(0, -5)) as Vector2
	spr.flip_h = flip
	if ghost:
		spr.modulate = Color(0.22, 0.22, 0.28, 0.7)
		sh.modulate = Color(1, 1, 1, 0.5)
	holder.add_child(spr)
	_actors.add_child(holder)
	return holder


func _pet(key: String, wpos: Vector2, flip: bool = false) -> Node2D:
	var spec: Array = PC.FRAMES.get(key, [])
	var holder := Node2D.new()
	holder.position = wpos
	var sh := FootShadow.new()
	sh.rad = Vector2(9, 3)
	sh.position = Vector2(0, 7)
	holder.add_child(sh)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = load(str(spec[0])) as SpriteFrames
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.animation = spec[1]
	spr.stop()
	spr.flip_h = flip ## player_pet.tscn: sprite ölçeği 1
	holder.add_child(spr)
	_actors.add_child(holder)
	return holder


## Kenar karartma: 480x270 basamaklı (Bayer) maske, x4 en yakın komşu. Işık değil - sadece kenarları koyulaştırır.
func _vignette(strength: float, bottom: float = 0.0) -> TextureRect:
	var key: String = "%.2f_%.2f" % [strength, bottom]
	if not _vig_cache.has(key):
		var img := Image.create(480, 270, false, Image.FORMAT_RGBA8)
		for y in 270:
			for x in 480:
				var b: float = (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0 - 0.5
				var vx: float = (x / 480.0 - 0.5) * 2.0
				var vy: float = (y / 270.0 - 0.5) * 2.0
				var v: float = maxf(0.0, vx * vx * 0.4 + vy * vy * 0.5 - 0.12)
				if bottom > 0.0:
					v += maxf(0.0, (y / 270.0 - 0.62) / 0.38) * bottom
				var a: float = clampf(floorf(v * strength * 6.0 + b + 0.5) / 6.0, 0.0, 0.9)
				img.set_pixel(x, y, Color(0.02, 0.02, 0.04, a))
		_vig_cache[key] = ImageTexture.create_from_image(img)
	var tr := TextureRect.new()
	tr.texture = _vig_cache[key]
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## ---------------------------------------------------------------- veri
func _def(id: int) -> Dictionary:
	return Characters.get_def(id)


func _short(id: int) -> String:
	return str(SHORT.get(id, _def(id).get("name", "?")))


func _tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _face_tex(id: int) -> Texture2D:
	return LU.face_texture(str(_def(id).get("portrait", "")))


## Tam boy bekleme karesi (kırpılmış).
func _body_tex(id: int, anim: String = "idle_down") -> Texture2D:
	var key: String = "%d_%s" % [id, anim]
	if _body_cache.has(key):
		return _body_cache[key]
	var sf: SpriteFrames = load(str(_def(id).get("frames", ""))) as SpriteFrames
	var a: String = anim if sf.has_animation(anim) else "idle_down"
	var img: Image = sf.get_frame_texture(a, 0).get_image()
	if img.is_compressed():
		img.decompress()
	var t := ImageTexture.create_from_image(img.get_region(img.get_used_rect()))
	_body_cache[key] = t
	return t


func _locked(id: int) -> bool:
	return not MP.is_unlocked(MP.CHAR, id)


func _cost(id: int) -> int:
	return int(MP.cost(MP.CHAR, id))


func _skill_tex(id: int, slot: String) -> Texture2D:
	return _tex(str(_def(id).get(slot + "_icon", "")))


## Yetenek açıklamasının ilk cümlesi ("ULTİ:" gibi önekler atılır).
func _first(t: String, n: int = 150) -> String:
	var s: String = t.strip_edges()
	var colon: int = s.find(":")
	if colon > 0 and colon < 22 and s.substr(0, colon).to_upper() == s.substr(0, colon):
		s = s.substr(colon + 1).strip_edges()
	var dot: int = s.find(". ")
	if dot > 0:
		s = s.substr(0, dot + 1)
	if s.length() > n:
		s = s.substr(0, n - 3).strip_edges() + "..."
	return s


func _skill_list(id: int) -> Array:
	var d: Dictionary = _def(id)
	var out: Array = []
	for pair: Array in [["Q", "skill"], ["E", "skill2"], ["R", "skill3"]]:
		var nm: String = str(d.get(pair[1] + "_name", ""))
		if nm != "":
			out.append({"key": pair[0], "name": nm, "desc": _first(str(d.get(pair[1] + "_desc", ""))), "tex": _skill_tex(id, pair[1])})
	out.append({"key": "P", "name": "Pasif", "desc": _first(str(d.get("passive", ""))), "tex": _skill_tex(id, "passive")})
	return out


func _stat_tex(key: String) -> Texture2D:
	var f: String = str(SI.ICON_PATHS.get(key, ""))
	if f != "" and ResourceLoader.exists(SI.ICON_DIR + f):
		return load(SI.ICON_DIR + f) as Texture2D
	return null


func _spirit_tex(id: String) -> Texture2D:
	return _tex(str(SS.get_def(id).get("icon", "")))


func _ready_count() -> Vector2i:
	var r: int = 0
	var n: int = 0
	for p: Dictionary in PLAYERS:
		if p["state"] == "connecting":
			continue
		n += 1
		if p["state"] == "ready":
			r += 1
	return Vector2i(r, n)


func _pickers(id: int) -> Array:
	var out: Array = []
	for i in PLAYERS.size():
		var p: Dictionary = PLAYERS[i]
		if p["state"] != "connecting" and int(p.get("char", -1)) == id:
			out.append(i)
	return out


## ---------------------------------------------------------------- UI yardımcıları
func _c(k: String) -> Color:
	return P[k]


func _sb(fill: Color, border: Color = Color(0, 0, 0, 0), bw: int = 3, r: int = 6, pad: float = -1.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	if border.a > 0.0 and bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	s.set_corner_radius_all(r)
	s.corner_detail = 1 ## 45 derece pah: pikselli köşe
	s.anti_aliasing = false
	if pad >= 0.0:
		s.set_content_margin_all(pad)
	return s


func _theme() -> Theme:
	var th := Theme.new()
	th.default_font = MenuKit.font()
	th.default_font_size = 32
	th.set_color("font_color", "Label", _c("text"))
	th.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	th.set_constant("shadow_offset_x", "Label", 0)
	th.set_constant("shadow_offset_y", "Label", 3)
	return th


func _tw(t: String, fs: int) -> float:
	return MenuKit.font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _lbl(t: String, fs: int = 32, c: Color = Color(0, 0, 0, 0), align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c if c.a > 0.0 else _c("text"))
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap(t: String, fs: int, c: Color, w: float, lines: int = 0) -> Label:
	var l := _lbl(t, fs, c)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if lines > 0:
		l.max_lines_visible = lines
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


func _big_title(t: String, fs: int, c: Color) -> Label:
	var l := _lbl(t, fs, c)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03, 1))
	l.add_theme_constant_override("outline_size", int(fs / 6.0))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", int(fs / 12.0))
	l.add_theme_constant_override("shadow_outline_size", int(fs / 6.0))
	return l


func _box(fill: Color, border: Color = Color(0, 0, 0, 0), pad: float = 16.0, bw: int = 3, r: int = 6) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(fill, border, bw, r, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _h(sep: int = 12) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _v(sep: int = 12) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _sp(w: float = 0.0, h: float = 0.0, ex: bool = false, ey: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ex:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ey:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _hline(h: float = 3.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = _c("line")
	r.custom_minimum_size = Vector2(0, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _expand(c: Control, x: bool = true, y: bool = false) -> Control:
	if x:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if y:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _glyph(pat: Array, c: Color, px: int = 3) -> Glyph:
	return Glyph.new(pat, c, px)


## Tam katlı büyütme (piksel bozulmasın); kutudan büyükse küçültür.
func _icon(tex: Texture2D, box: float, dim: bool = false, boxh: float = -1.0) -> Control:
	var bh: float = box if boxh < 0.0 else boxh
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(box, bh)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		return cc
	var ts: Vector2 = tex.get_size()
	var k: float = floorf(minf(box / ts.x, bh / ts.y))
	if k < 1.0:
		k = minf(box / ts.x, bh / ts.y)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.custom_minimum_size = (ts * k).floor()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		tr.modulate = Color(0.45, 0.45, 0.5, 1.0)
	cc.add_child(tr)
	return cc


## Çerçeveli ikon kutusu (silah / evcil / ruhani / yetenek).
func _slot(tex: Texture2D, box: float, fill: Color = Color(0, 0, 0, 0), border: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p := _box(fill if fill.a > 0.0 else _c("inset"), border if border.a > 0.0 else _c("line"), 2, 3, 4)
	p.add_child(_icon(tex, box))
	return p


func _face(id: int, px: float, dim: bool = false) -> Control:
	return _icon(_face_tex(id), px, dim)


func _btn_style(b: Button, kind: String, r: int = 6) -> void:
	var fill: Color = _c("accent")
	var bd: Color = _c("accent_dk")
	var tc: Color = _c("accent_text")
	match kind:
		"ghost":
			fill = _c("panel2")
			bd = _c("line_hi")
			tc = _c("text")
		"off":
			fill = _c("inset")
			bd = _c("line")
			tc = _c("dim")
		"danger":
			fill = _c("panel2")
			bd = _c("bad").darkened(0.35)
			tc = _c("bad")
		"flat":
			fill = Color(0, 0, 0, 0)
			bd = Color(0, 0, 0, 0)
			tc = _c("text")
		"flat_on":
			fill = Color(_c("accent"), 0.14)
			bd = Color(0, 0, 0, 0)
			tc = _c("accent")
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, _sb(fill, bd, 3, r, 10.0))
	for fc: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(fc, tc)


func _btn(t: String, kind: String = "primary", fs: int = 32, h: float = 60.0, w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", fs)
	_btn_style(b, kind)
	return b


## Düğmenin içine ortalı satır (ikon + yazı). Button'a çocuk eklenen HBox genişliği büyütmez -> w verilmeli.
func _btn_row(b: Button, row: Control, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Button:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 24)
	m.add_theme_constant_override("margin_right", 24)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if row is HBoxContainer:
		(row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER if align == HORIZONTAL_ALIGNMENT_CENTER else BoxContainer.ALIGNMENT_BEGIN
	m.add_child(row)
	b.add_child(m)
	return b


func _chip(pat: Array, t: String, col: Color, fs: int = 24) -> PanelContainer:
	var p := _box(_c("inset"), _c("line"), 8, 2, 4)
	p.get_theme_stylebox("panel").content_margin_left = 12
	p.get_theme_stylebox("panel").content_margin_right = 14
	var h := _h(10)
	if not pat.is_empty():
		h.add_child(_glyph(pat, col, 3))
	h.add_child(_lbl(t, fs, col))
	p.add_child(h)
	return p


func _key_badge(k: String, fs: int = 24, col: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p := _box(_c("inset"), _c("line_hi"), 2, 2, 3)
	p.custom_minimum_size = Vector2(fs * 1.4, fs * 1.4)
	p.add_child(_lbl(k, fs, col if col.a > 0.0 else _c("accent"), HORIZONTAL_ALIGNMENT_CENTER))
	return p


func _shard(px: float = 24.0, dim: bool = false) -> ShardIcon:
	return ShardIcon.new(px, dim)


func _balance_chip() -> PanelContainer:
	var p := _box(_c("inset"), _c("line_hi"), 10)
	var h := _h(12)
	h.add_child(_shard(32.0))
	h.add_child(_lbl("1340", 32, _c("price")))
	p.add_child(h)
	return p


func _place(parent: Control, c: Control, pos: Vector2, sz: Vector2 = Vector2.ZERO) -> Control:
	parent.add_child(c)
	c.position = pos
	if sz != Vector2.ZERO:
		c.custom_minimum_size = sz
		c.size = sz
	return c


func _root(tint_k: float = 1.0, vig: float = 1.0, vig_bottom: float = 0.0) -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.theme = _theme()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(r) ## ÖNCE ağaca: dışarıda kurulan Control proje temasının (88 px) fontuyla ölçülür, boyut kalıcı büyür
	if vig > 0.0:
		r.add_child(_vignette(vig, vig_bottom))
	_cm.color = Color(_c("tint") * tint_k, 1.0)
	return r


## ---------------------------------------------------------------- ortak seçim ekranı parçaları
func _room_title(fs: int = 48) -> HBoxContainer:
	var h := _h(14)
	h.add_child(_lbl(str(ROOM["name"]), fs, _c("accent")))
	return h


func _room_chips(fs: int = 24) -> HBoxContainer:
	var h := _h(8)
	h.add_child(_chip(G_LOCK, "Şifreli", _c("dim"), fs))
	h.add_child(_chip(G_GLOBE, str(ROOM["net"]), _c("dim"), fs))
	var n: int = 0
	for p: Dictionary in PLAYERS:
		if p["state"] != "connecting":
			n += 1
	h.add_child(_chip(G_PERSON, "%d/%d" % [n, int(ROOM["max"])], _c("text"), fs))
	return h


func _state_badge(state: String, fs: int = 24) -> Control:
	var h := _h(8)
	match state:
		"ready":
			h.add_child(_glyph(G_CHECK, _c("good"), 3))
			h.add_child(_lbl("HAZIR", fs, _c("good")))
		"picking":
			h.add_child(_lbl("SEÇİYOR", fs, _c("price")))
		_:
			h.add_child(_glyph(G_DOTS, _c("dim"), 3))
			h.add_child(_lbl("BAĞLANIYOR", fs, _c("dim")))
	return h


func _host_tag() -> PanelContainer:
	var p := _box(Color(_c("accent"), 0.16), Color(0, 0, 0, 0), 4, 0, 3)
	var h := _h(6)
	h.add_child(_glyph(G_CROWN, _c("accent"), 3))
	h.add_child(_lbl("HOST", 24, _c("accent")))
	p.add_child(h)
	return p


func _me_tag() -> PanelContainer:
	var p := _box(_c("accent"), Color(0, 0, 0, 0), 4, 0, 3)
	p.get_theme_stylebox("panel").content_margin_left = 8
	p.get_theme_stylebox("panel").content_margin_right = 8
	var l := _lbl("SEN", 24, _c("accent_text"))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	p.add_child(l)
	return p


## Küçük oyuncu işareti (karakter kartının köşesi): oyuncu renginde kare + baş harf.
func _pmark(i: int, px: float = 28.0) -> PanelContainer:
	var p := _box(PCOL[i], PCOL[i].darkened(0.5), 0, 2, 3)
	p.custom_minimum_size = Vector2(px, px)
	var l := _lbl(str(PLAYERS[i]["name"]).substr(0, 1).to_upper(), 24, Color("#16120c"), HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	p.add_child(l)
	return p


func _loadout_icons(p: Dictionary, px: float = 32.0) -> HBoxContainer:
	var h := _h(4)
	h.add_child(_slot(WC.icon(str(p["weapon"])), px))
	h.add_child(_slot(PC.icon(str(p["pet"])), px))
	h.add_child(_slot(_spirit_tex(str(p["spirit"])), px))
	return h


## Oyuncu satırı: renk şeridi + yüz + ad (HOST/SEN) + karakter adı + yükleme ikonları + durum (+ host'ta "at").
func _prow(i: int, w: float, face_px: float = 72.0, host_view: bool = true) -> PanelContainer:
	var p: Dictionary = PLAYERS[i]
	var me: bool = bool(p.get("me", false))
	var conn: bool = p["state"] == "connecting"
	var row := _box(_c("panel3") if me else (_c("inset") if conn else _c("panel2")), _c("accent") if me else _c("line"), 8)
	row.custom_minimum_size.x = w
	var h := _h(12)
	var stripe := ColorRect.new()
	stripe.color = PCOL[i] if not conn else _c("line_hi")
	stripe.custom_minimum_size = Vector2(6, 0)
	h.add_child(stripe)
	var fb := _box(_c("inset"), _c("line"), 2, 2, 3)
	if conn:
		var cc := CenterContainer.new()
		cc.custom_minimum_size = Vector2(face_px, face_px)
		cc.add_child(_glyph(G_QMARK, _c("line_hi"), 5))
		fb.add_child(cc)
	else:
		fb.add_child(_face(int(p["char"]), face_px))
	h.add_child(fb)
	var v := _v(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := _h(10)
	top.add_child(_lbl(str(p["name"]), 32, _c("dim") if conn else _c("text")))
	if bool(p.get("host", false)):
		top.add_child(_host_tag())
	if me:
		top.add_child(_me_tag())
	top.add_child(_sp(0, 0, true))
	top.add_child(_state_badge(str(p["state"])))
	v.add_child(top)
	if conn:
		var bv := _v(6)
		bv.add_child(_lbl("odaya giriyor...", 24, _c("dim")))
		bv.add_child(_expand(Bar.new(0.62, _c("line_hi"), _c("panel2"), 6)))
		v.add_child(bv)
	else:
		var bot := _h(10)
		bot.add_child(_lbl(str(_def(int(p["char"]))["name"]), 24, PCOL[i]))
		bot.add_child(_sp(0, 0, true))
		bot.add_child(_loadout_icons(p, 32))
		if host_view and not bool(p.get("host", false)):
			bot.add_child(_kick_btn())
		v.add_child(bot)
	h.add_child(v)
	row.add_child(h)
	return row


## Host'ta oyuncuyu atma: küçük kırmızı X (ipucu "Odadan at").
func _kick_btn() -> Button:
	var kick := _btn("", "danger", 24, 40, 40)
	kick.tooltip_text = "Odadan at"
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.add_child(_glyph(G_X, _c("bad"), 3))
	kick.add_child(cc)
	return kick


func _hrow(items: Array, sep: int = 10) -> HBoxContainer:
	var h := _h(sep)
	for it: Control in items:
		h.add_child(it)
	return h


## Sohbet kutusu: son mesajlar (ad oyuncu renginde) + yazma satırı.
func _chat(w: float, h: float, fs: int = 24, title: bool = true, fill: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p := _box(fill if fill.a > 0.0 else _c("panel"), _c("line"), 14)
	p.custom_minimum_size = Vector2(w, h)
	var v := _v(8)
	if title:
		v.add_child(_lbl("SOHBET", 24, _c("accent")))
	var msgs := _v(6)
	msgs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	msgs.alignment = BoxContainer.ALIGNMENT_END
	for m: Array in CHAT:
		if m[0] == "sys":
			msgs.add_child(_wrap("- " + str(m[2]), fs, _c("dim"), w - 40))
		else:
			var i: int = int(m[1])
			var rl := RichTextLabel.new()
			rl.bbcode_enabled = true
			rl.fit_content = true
			rl.scroll_active = false
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rl.custom_minimum_size.x = w - 40
			rl.add_theme_font_override("normal_font", MenuKit.font())
			rl.add_theme_font_size_override("normal_font_size", fs)
			rl.add_theme_color_override("default_color", _c("text"))
			rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rl.text = "[color=#%s]%s:[/color] %s" % [PCOL[i].to_html(false), str(PLAYERS[i]["name"]), str(m[2])]
			msgs.add_child(rl)
	v.add_child(msgs)
	var inp := _box(_c("inset"), _c("line_hi"), 10, 2, 4)
	var ih := _h(10)
	ih.add_child(_expand(_lbl("Mesaj yaz...", fs, _c("dim"))))
	ih.add_child(_lbl("ENTER", 24, _c("line_hi")))
	inp.add_child(ih)
	v.add_child(inp)
	p.add_child(v)
	return p


## Karakter kartı: yüz + kısa ad; kilitliyse sönük + kilit + fiyat; seçenlerin işareti köşede.
func _rcard(id: int, w: float, h: float, face_px: float = 72.0, name_fs: int = 24) -> Control:
	var sel: bool = id == SEL
	var lk: bool = _locked(id)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, h)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := _box(_c("inset") if lk else (_c("panel3") if sel else _c("panel2")), _c("accent") if sel else _c("line"), 6, 3 if sel else 2, 4)
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := _v(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_face(id, face_px, lk))
	if lk:
		var ph := _h(6)
		ph.alignment = BoxContainer.ALIGNMENT_CENTER
		ph.add_child(_shard(18, true))
		ph.add_child(_lbl(str(_cost(id)), name_fs, _c("bad")))
		v.add_child(ph)
	else:
		var nm: String = _short(id)
		var fs: int = name_fs if _tw(nm, name_fs) <= w - 12 else 16
		v.add_child(_lbl(nm, fs, _c("accent") if sel else _c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	card.add_child(v)
	holder.add_child(card)
	if lk:
		var lg := _glyph(G_LOCK, _c("dim"), 3)
		lg.position = Vector2(w - 30, 8)
		holder.add_child(lg)
	var pk: Array = _pickers(id)
	for k in pk.size():
		var mk := _pmark(int(pk[k]), 26)
		mk.position = Vector2(6 + k * 30, 6)
		holder.add_child(mk)
	return holder


func _roster_grid(cols: int, w: float, h: float, face_px: float = 72.0, sep: int = 10, name_fs: int = 24) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	for id: int in CH:
		g.add_child(_rcard(id, w, h, face_px, name_fs))
	return g


## Yetenek satırı: ikon (köşede tuş harfi) + ad + ilk cümle.
func _skill_row(s: Dictionary, w: float, icon_px: float = 48.0, desc_lines: int = 2, desc: bool = true) -> HBoxContainer:
	var h := _h(14)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(icon_px + 8, icon_px + 8)
	var sl := _slot(s["tex"], icon_px)
	sl.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(sl)
	var kb := _key_badge(str(s["key"]), 16)
	kb.custom_minimum_size = Vector2(24, 24)
	kb.position = Vector2(icon_px - 14, icon_px - 14)
	holder.add_child(kb)
	h.add_child(holder)
	var v := _v(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_lbl(str(s["name"]), 32))
	if desc and str(s["desc"]) != "":
		v.add_child(_wrap(str(s["desc"]), 24, _c("dim"), w - icon_px - 30, desc_lines))
	h.add_child(v)
	return h


func _stat_grid(id: int, cols: int = 4, fs: int = 24) -> GridContainer:
	var bs: Dictionary = Characters.get_base_stats(id)
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 6)
	var atk: int = int(bs.get("atk", 0))
	for row: Array in [["max_health", "Can", str(int(bs.get("hp", 100)))], ["speed", "Hız", str(int(bs.get("speed", 252)))],
			["damage", "Güç", str(int(bs.get("ap", 10)))], ["fire_rate", "Saldırı Hızı", ("%+d%%" % atk) if atk != 0 else "0"]]:
		var h := _h(8)
		h.add_child(_icon(_stat_tex(row[0]), 32))
		h.add_child(_lbl(row[1], fs, _c("dim")))
		h.add_child(_lbl(row[2], fs))
		g.add_child(h)
	return g


## Yükleme yuvası (Silah / Evcil / Ruhani): ikon + tür + ad + aşağı ok.
func _lslot(kind: String, tex: Texture2D, nm: String, w: float, icon_px: float = 48.0, sub: String = "") -> PanelContainer:
	var p := _box(_c("panel2"), _c("line_hi"), 10)
	p.custom_minimum_size.x = w
	var h := _h(12)
	h.add_child(_slot(tex, icon_px))
	var v := _v(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_lbl(kind, 24, _c("dim")))
	v.add_child(_lbl(nm, 32))
	if sub != "":
		v.add_child(_wrap(sub, 24, _c("dim"), w - icon_px - 70, 2))
	h.add_child(v)
	h.add_child(_glyph(G_DOWN, _c("accent"), 4))
	p.add_child(h)
	return p


func _me() -> Dictionary:
	return PLAYERS[0]


func _loadout_slots(w_each: float, vertical: bool = false, icon_px: float = 48.0) -> BoxContainer:
	var me: Dictionary = _me()
	var b: BoxContainer = _v(10) if vertical else _h(12)
	b.add_child(_lslot("Silah", WC.icon(str(me["weapon"])), WC.display_name(str(me["weapon"])), w_each, icon_px))
	b.add_child(_lslot("Evcil", PC.icon(str(me["pet"])), PC.display_name(str(me["pet"])), w_each, icon_px))
	b.add_child(_lslot("Ruhani", _spirit_tex(str(me["spirit"])), SS.skill_name(str(me["spirit"])), w_each, icon_px))
	return b


## Host'un başlat düğmesi: herkes hazır değilken kilitli + neden yazısı.
func _start_block(w: float, h: float = 80.0, fs: int = 48) -> VBoxContainer:
	var rc: Vector2i = _ready_count()
	var v := _v(6)
	var b := _btn("OYUNU BAŞLAT", "off", fs, h, w)
	v.add_child(b)
	var info := _h(8)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(_lbl("%d/%d hazır" % [rc.x, rc.y], 24, _c("price")))
	info.add_child(_lbl("·  1 oyuncu bağlanıyor", 24, _c("dim")))
	v.add_child(info)
	return v


## Vitrin: ışık havuzu + karakterin tam boy karesi (tam kat).
func _showcase(id: int, w: float, h: float, body_h: float, anim: String = "idle_down", fill: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p := _box(fill if fill.a > 0.0 else _c("inset"), _c("line"), 0)
	p.custom_minimum_size = Vector2(w, h)
	p.add_child(Spot.new(_c("spot"), 0.84))
	var tex: Texture2D = _body_tex(id, anim)
	var k: float = floorf(body_h / tex.get_size().y)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_bottom", int(h * 0.12))
	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_SHRINK_END
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = tex.get_size() * k
	cc.add_child(tr)
	m.add_child(cc)
	p.add_child(m)
	return p


func _title_bar(text: String, fs: int = 24, right: Control = null) -> HBoxContainer:
	var h := _h(10)
	h.add_child(_lbl(text, fs, _c("accent")))
	h.add_child(_sp(0, 0, true))
	if right != null:
		h.add_child(right)
	return h


func _back_btn(t: String = "ODADAN ÇIK", w: float = 280.0, h: float = 56.0) -> Button:
	var b := _btn("", "ghost", 32, h, w)
	return _btn_row(b, _hrow([_glyph(G_LEFT, _c("text"), 4), _lbl(t, 32)], 12))


## ================================================================ SEÇİM A - Üç Sütun
func _design_sec_a() -> Control:
	P = PAL["a"]
	_view(Vector2(1400, 2230), 2.0, Color.WHITE)
	var r := _root(0.42, 1.0)
	## üst şerit
	_place(r, _back_btn(), Vector2(32, 32))
	var top := _h(18)
	top.add_child(_room_title(48))
	top.add_child(_room_chips())
	_place(r, top, Vector2(340, 34))
	_place(r, _lbl("Arkadaşların bağlanırken karakterini seç", 24, _c("dim")), Vector2(1330, 46))
	## sol: oyuncular + sohbet
	var left := _box(_c("panel"), _c("line"), 16)
	var lv := _v(10)
	lv.add_child(_title_bar("OYUNCULAR", 24, _lbl("3/4", 24, _c("dim"))))
	for i in PLAYERS.size():
		lv.add_child(_prow(i, 408, 72))
	left.add_child(lv)
	_place(r, left, Vector2(32, 112), Vector2(456, 0))
	_place(r, _chat(456, 461), Vector2(32, 587))
	## orta: vitrin + yetenekler + yükleme
	var mid := _box(_c("panel"), _c("line"), 20)
	var mv := _v(14)
	var sc := _showcase(SEL, 776, 300, 260)
	mv.add_child(sc)
	var nh := _h(16)
	nh.add_child(_lbl(str(_def(SEL)["name"]), 48, _c("accent")))
	nh.add_child(_sp(0, 0, true))
	nh.add_child(_stat_grid(SEL, 4))
	mv.add_child(nh)
	mv.add_child(_hline())
	for s: Dictionary in _skill_list(SEL):
		mv.add_child(_skill_row(s, 776, 48, 2))
	mv.add_child(_sp(0, 0, false, true))
	mv.add_child(_loadout_slots(250))
	mid.add_child(mv)
	_place(r, mid, Vector2(504, 112), Vector2(816, 936))
	## sağ: karakterler + başlat
	var right := _box(_c("panel"), _c("line"), 16)
	var rv := _v(12)
	rv.add_child(_title_bar("KARAKTERLER", 24, _lbl("6/14 açık", 24, _c("dim"))))
	rv.add_child(_roster_grid(4, 124, 136, 72, 10))
	right.add_child(rv)
	_place(r, right, Vector2(1336, 112), Vector2(552, 0))
	_place(r, _start_block(552, 84), Vector2(1336, 948))
	return r


## ================================================================ SEÇİM B - Takım Sırası
func _design_sec_b() -> Control:
	P = PAL["b"]
	_view(Vector2(3600, 520), 2.0, Color.WHITE)
	var r := _root(0.40, 1.0)
	var top := _h(18)
	top.add_child(_room_title(48))
	top.add_child(_room_chips())
	_place(r, top, Vector2(32, 26))
	var bb := _back_btn("ODADAN ÇIK", 260, 56)
	_place(r, bb, Vector2(W - 32 - 260, 24))
	## takım şeridi: 4 büyük oyuncu kartı
	var cw: float = (W - 64 - 3 * 16) / 4.0
	for i in PLAYERS.size():
		_place(r, _team_card(i, cw, 380), Vector2(32 + i * (cw + 16), 100))
	## karakter şeridi (14 kart tek satır)
	var strip := _box(_c("panel"), _c("line"), 12)
	var sh := _h(8)
	for id: int in CH:
		sh.add_child(_rcard(id, 123, 124, 72))
	strip.add_child(sh)
	_place(r, strip, Vector2(35, 496))
	## alt: ayrıntı + yükleme | sohbet + başlat
	var det := _box(_c("panel"), _c("line"), 18)
	var dv := _v(12)
	var dh := _h(16)
	dh.add_child(_lbl(str(_def(SEL)["name"]), 48, _c("accent")))
	dh.add_child(_sp(0, 0, true))
	dh.add_child(_stat_grid(SEL, 4))
	dv.add_child(dh)
	var sg := GridContainer.new()
	sg.columns = 2
	sg.add_theme_constant_override("h_separation", 24)
	sg.add_theme_constant_override("v_separation", 10)
	for s: Dictionary in _skill_list(SEL):
		sg.add_child(_skill_row(s, 520, 48, 2))
	dv.add_child(sg)
	dv.add_child(_sp(0, 0, false, true))
	dv.add_child(_loadout_slots(344))
	det.add_child(dv)
	_place(r, det, Vector2(32, 652), Vector2(1100, 396))
	_place(r, _chat(740, 290, 24, true), Vector2(1148, 652))
	_place(r, _start_block(740, 72), Vector2(1148, 958))
	return r


func _team_card(i: int, w: float, h: float) -> Control:
	var p: Dictionary = PLAYERS[i]
	var me: bool = bool(p.get("me", false))
	var conn: bool = p["state"] == "connecting"
	var card := _box(_c("panel") if not conn else Color(_c("inset"), 0.85), _c("accent") if me else _c("line"), 12, 3, 6)
	card.custom_minimum_size = Vector2(w, h)
	var v := _v(8)
	var top := _h(10)
	var stripe := ColorRect.new()
	stripe.color = PCOL[i] if not conn else _c("line_hi")
	stripe.custom_minimum_size = Vector2(6, 32)
	top.add_child(stripe)
	top.add_child(_lbl(str(p["name"]), 32, _c("dim") if conn else _c("text")))
	if bool(p.get("host", false)):
		top.add_child(_host_tag())
	if me:
		top.add_child(_me_tag())
	top.add_child(_sp(0, 0, true))
	v.add_child(top)
	if conn:
		var sc := _box(Color(0, 0, 0, 0.25), _c("line"), 0)
		sc.custom_minimum_size = Vector2(w - 24, 216)
		var cc := CenterContainer.new()
		var cv := _v(14)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		var gc := CenterContainer.new()
		gc.add_child(_glyph(G_QMARK, _c("line_hi"), 10))
		cv.add_child(gc)
		cv.add_child(_lbl("odaya giriyor...", 24, _c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
		var bar := Bar.new(0.62, _c("line_hi"), _c("panel2"), 6)
		bar.custom_minimum_size.x = 220
		cv.add_child(bar)
		cc.add_child(cv)
		sc.add_child(cc)
		v.add_child(sc)
		v.add_child(_lbl("Karakter seçecek", 32, _c("dim")))
		v.add_child(_sp(0, 0, false, true))
		v.add_child(_ribbon("connecting"))
	else:
		v.add_child(_showcase(int(p["char"]), w - 24, 216, 180))
		var nm := _h(10)
		nm.add_child(_lbl(str(_def(int(p["char"]))["name"]), 32, PCOL[i]))
		nm.add_child(_sp(0, 0, true))
		nm.add_child(_loadout_icons(p, 32))
		v.add_child(nm)
		v.add_child(_sp(0, 0, false, true))
		v.add_child(_ribbon(str(p["state"])))
	card.add_child(v)
	return card


## Kartın altındaki durum şeridi (HAZIR yeşil / SEÇİYOR sarı / BAĞLANIYOR gri).
func _ribbon(state: String) -> PanelContainer:
	var col: Color = _c("good") if state == "ready" else (_c("price") if state == "picking" else _c("dim"))
	var p := _box(Color(col, 0.14), Color(col, 0.45), 8, 2, 3)
	var cc := CenterContainer.new()
	cc.add_child(_state_badge(state, 32))
	p.add_child(cc)
	return p


## ================================================================ SEÇİM C - Kamp Sahnesi
func _design_sec_c() -> Control:
	P = PAL["c"]
	## Ev önündeki çimen: 4 yuva dünyada yan yana, seçilen karakterler orada duruyor (bağlanan = siluet).
	_view(Vector2(1340, 2370), 3.0, Color.WHITE)
	var r := _root(0.86, 1.0)
	var feet: Array = []
	for i in PLAYERS.size():
		var wp := Vector2(1234 + i * 64, 2414)
		feet.append(wp)
		var p: Dictionary = PLAYERS[i]
		var ring := FootRing.new()
		ring.position = wp + Vector2(0, 16)
		ring.col = Color(PCOL[i], 0.9) if p["state"] != "connecting" else Color(_c("dim"), 0.7)
		_actors.add_child(ring)
		if p["state"] == "connecting":
			_actor(10, "idle_down", wp, 0, false, true)
		else:
			_actor(int(p["char"]), "idle_down", wp)
	## sol: karakter listesi
	var left := _box(Color(_c("panel"), 0.94), _c("line"), 14)
	var lv := _v(6)
	lv.add_child(_title_bar("KARAKTERLER", 24, _lbl("6/14", 24, _c("dim"))))
	for id: int in CH:
		lv.add_child(_list_row(id, 372))
	left.add_child(lv)
	_place(r, left, Vector2(32, 32), Vector2(400, 0))
	## üst orta: oda başlığı
	var banner := _box(Color(_c("panel"), 0.9), _c("line"), 12)
	var bv := _v(6)
	var t1 := _h(12)
	t1.alignment = BoxContainer.ALIGNMENT_CENTER
	t1.add_child(_room_title(48))
	bv.add_child(t1)
	var t2 := _room_chips()
	t2.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_child(t2)
	banner.add_child(bv)
	_place(r, banner, Vector2(560, 32), Vector2(752, 0))
	## sahnedeki adlar + durumlar
	for i in PLAYERS.size():
		var p: Dictionary = PLAYERS[i]
		var s: Vector2 = _w2s(feet[i])
		var tag := _v(4)
		var nb := _box(Color(_c("panel"), 0.9), PCOL[i] if p["state"] != "connecting" else _c("line"), 6, 2, 4)
		var nh := _h(8)
		if bool(p.get("host", false)):
			nh.add_child(_glyph(G_CROWN, _c("accent"), 3))
		nh.add_child(_lbl(str(p["name"]), 24, _c("dim") if p["state"] == "connecting" else _c("text")))
		nb.add_child(nh)
		var cc := CenterContainer.new()
		cc.add_child(nb)
		tag.add_child(cc)
		var sc := CenterContainer.new()
		sc.add_child(_state_badge(str(p["state"])))
		tag.add_child(sc)
		tag.custom_minimum_size.x = 180
		_place(r, tag, Vector2(s.x - 90, s.y - 136))
		if bool(p.get("me", false)):
			var mk := CenterContainer.new()
			mk.custom_minimum_size.x = 180
			mk.add_child(_me_tag())
			_place(r, mk, Vector2(s.x - 90, s.y + 76))
	## sağ: ayrıntı + yükleme + başlat
	var right := _box(Color(_c("panel"), 0.94), _c("line"), 18)
	var rv := _v(12)
	rv.add_child(_lbl(str(_def(SEL)["name"]), 48, _c("accent")))
	rv.add_child(_stat_grid(SEL, 2))
	rv.add_child(_hline())
	for s2: Dictionary in _skill_list(SEL):
		rv.add_child(_skill_row(s2, 420, 48, 2))
	rv.add_child(_hline())
	rv.add_child(_loadout_slots(420, true))
	right.add_child(rv)
	_place(r, right, Vector2(W - 32 - 460, 32), Vector2(460, 0))
	_place(r, _start_block(460, 80), Vector2(W - 32 - 460, 948))
	## alt orta: sohbet
	_place(r, _chat(752, 200, 24, false, Color(_c("panel"), 0.9)), Vector2(560, 848))
	return r


func _list_row(id: int, w: float) -> PanelContainer:
	var sel: bool = id == SEL
	var lk: bool = _locked(id)
	var p := _box(_c("panel3") if sel else (Color(0, 0, 0, 0) if lk else _c("panel2")), _c("accent") if sel else (_c("line") if not lk else Color(0, 0, 0, 0)), 2, 2, 4)
	p.custom_minimum_size = Vector2(w, 0)
	var h := _h(10)
	h.add_child(_face(id, 48, lk))
	h.add_child(_lbl(str(_def(id)["name"]), 24, _c("dim") if lk else (_c("accent") if sel else _c("text"))))
	h.add_child(_sp(0, 0, true))
	for k in _pickers(id):
		h.add_child(_pmark(int(k), 24))
	if lk:
		h.add_child(_glyph(G_LOCK, _c("dim"), 2))
		h.add_child(_shard(16, true))
		h.add_child(_lbl(str(_cost(id)), 24, _c("bad")))
	h.add_child(_sp(6))
	p.add_child(h)
	return p


## ================================================================ SEÇİM D - Oyuncu Kartları + yerinde yükleme
func _design_sec_d() -> Control:
	P = PAL["d"]
	_view(Vector2(1931, 1290), 2.0, Color.WHITE)
	var r := _root(0.42, 1.0)
	## sol sütun: oda + oyuncular + sohbet
	var room := _box(_c("panel"), _c("line"), 14)
	var rv := _v(8)
	var rh := _h(10)
	rh.add_child(_room_title(48))
	rv.add_child(rh)
	rv.add_child(_room_chips())
	room.add_child(rv)
	_place(r, room, Vector2(32, 24), Vector2(440, 0))
	for i in PLAYERS.size():
		_place(r, _pcard_d(i, 440), Vector2(32, 168 + i * 132))
	_place(r, _chat(440, 336, 24, true), Vector2(32, 712))
	## orta: karakter ızgarası + yetenekler
	var mid := _box(_c("panel"), _c("line"), 16)
	var mv := _v(12)
	mv.add_child(_title_bar("KARAKTERİNİ SEÇ", 24, _lbl("6/14 açık", 24, _c("dim"))))
	mv.add_child(_roster_grid(5, 134, 150, 96, 10))
	mv.add_child(_hline())
	var nh := _h(12)
	nh.add_child(_lbl(str(_def(SEL)["name"]), 48, _c("accent")))
	nh.add_child(_sp(0, 0, true))
	nh.add_child(_stat_grid(SEL, 2))
	mv.add_child(nh)
	for s: Dictionary in _skill_list(SEL):
		mv.add_child(_skill_row(s, 720, 48, 1))
	mid.add_child(mv)
	_place(r, mid, Vector2(488, 24), Vector2(760, 1024))
	## sağ: vitrin + sekmeli yükleme (silah sekmesi açık) + başlat
	var right := _box(_c("panel"), _c("line"), 16)
	var xv := _v(12)
	var hv := _h(16)
	hv.add_child(_showcase(SEL, 200, 200, 160))
	var hb := _v(6)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(_lbl("YÜKLEMEN", 24, _c("accent")))
	hb.add_child(_lbl(str(_def(SEL)["name"]), 48))
	hb.add_child(_loadout_icons(_me(), 48))
	hv.add_child(hb)
	xv.add_child(hv)
	var tabs := _h(8)
	tabs.add_child(_tab_btn("SİLAH", true))
	tabs.add_child(_tab_btn("EVCİL", false))
	tabs.add_child(_tab_btn("RUHANİ", false))
	xv.add_child(tabs)
	var wg := GridContainer.new()
	wg.columns = 5
	wg.add_theme_constant_override("h_separation", 10)
	wg.add_theme_constant_override("v_separation", 10)
	var cur: String = str(_me()["weapon"])
	for key: String in WC.KEYS:
		var lk: bool = not MP.is_unlocked(MP.WEAPON, key)
		var on: bool = key == cur
		var t := Control.new()
		t.custom_minimum_size = Vector2(108, 132)
		var b := _box(_c("panel3") if on else (_c("inset") if lk else _c("panel2")), _c("accent") if on else _c("line"), 4, 3 if on else 2, 4)
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		var tv := _v(2)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_child(_icon(WC.icon(key), 64, lk))
		tv.add_child(_lbl(WC.display_name(key), 16, _c("accent") if on else (_c("dim") if lk else _c("text")), HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(tv)
		t.add_child(b)
		if lk:
			var lg := _glyph(G_LOCK, _c("dim"), 2)
			lg.position = Vector2(86, 8)
			t.add_child(lg)
		wg.add_child(t)
	xv.add_child(wg)
	xv.add_child(_sp(0, 0, false, true))
	var wd := _box(_c("inset"), _c("line"), 14)
	var wdv := _v(4)
	var wh := _h(10)
	wh.add_child(_lbl(WC.display_name(cur), 32, _c("accent")))
	wh.add_child(_lbl(WC.category_label(cur), 24, WC.category_color(cur)))
	wdv.add_child(wh)
	wdv.add_child(_wrap(_first(WC.trait_text(cur), 120), 24, _c("dim"), 560, 3))
	wd.add_child(wdv)
	xv.add_child(wd)
	right.add_child(xv)
	_place(r, right, Vector2(1264, 24), Vector2(624, 908))
	_place(r, _start_block(624, 80), Vector2(1264, 948))
	return r


func _tab_btn(t: String, on: bool) -> Button:
	var b := _btn(t, "primary" if on else "ghost", 32, 52, 0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _pcard_d(i: int, w: float) -> PanelContainer:
	var p: Dictionary = PLAYERS[i]
	var me: bool = bool(p.get("me", false))
	var conn: bool = p["state"] == "connecting"
	var card := _box(_c("panel3") if me else (_c("inset") if conn else _c("panel")), _c("accent") if me else _c("line"), 10)
	card.custom_minimum_size = Vector2(w, 120)
	var h := _h(12)
	var stripe := ColorRect.new()
	stripe.color = PCOL[i] if not conn else _c("line_hi")
	stripe.custom_minimum_size = Vector2(6, 0)
	h.add_child(stripe)
	if conn:
		var gb := _box(_c("panel2"), _c("line"), 0)
		var cc := CenterContainer.new()
		cc.custom_minimum_size = Vector2(96, 96)
		cc.add_child(_glyph(G_QMARK, _c("line_hi"), 6))
		gb.add_child(cc)
		h.add_child(gb)
	else:
		var fb := _box(_c("inset"), _c("line"), 2, 2, 3)
		fb.add_child(_face(int(p["char"]), 96))
		h.add_child(fb)
	var v := _v(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var top := _h(8)
	top.add_child(_lbl(str(p["name"]), 32, _c("dim") if conn else _c("text")))
	if bool(p.get("host", false)):
		top.add_child(_glyph(G_CROWN, _c("accent"), 3))
	if me:
		top.add_child(_me_tag())
	top.add_child(_sp(0, 0, true))
	top.add_child(_state_badge(str(p["state"])))
	v.add_child(top)
	if conn:
		v.add_child(_lbl("odaya giriyor...", 24, _c("dim")))
		v.add_child(_expand(Bar.new(0.62, _c("line_hi"), _c("panel2"), 6)))
	else:
		v.add_child(_lbl(str(_def(int(p["char"]))["name"]), 24, PCOL[i]))
		var bot := _h(8)
		bot.add_child(_loadout_icons(p, 32))
		bot.add_child(_sp(0, 0, true))
		if not bool(p.get("host", false)):
			bot.add_child(_kick_btn())
		v.add_child(bot)
	h.add_child(v)
	card.add_child(h)
	return card


## ================================================================ ANA MENÜ ortak
func _logo(fs: int, c: Color, sub: bool = true, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> VBoxContainer:
	var v := _v(0)
	var h := _h(18)
	h.alignment = BoxContainer.ALIGNMENT_CENTER if align == HORIZONTAL_ALIGNMENT_CENTER else BoxContainer.ALIGNMENT_BEGIN
	var ic: float = 96.0 if fs >= 96 else 64.0
	var left_ic := _icon(WC.icon("dagger"), ic)
	(left_ic.get_child(0) as TextureRect).flip_h = true
	h.add_child(left_ic)
	h.add_child(_big_title("LIL'SLAYERS", fs, c))
	h.add_child(_icon(WC.icon("fire_staff"), ic))
	v.add_child(h)
	if sub:
		v.add_child(_lbl("Hayatta kal. Birlikte.", 32, _c("dim"), align))
	return v


const MENU := [["TEK OYUNCULU", "primary"], ["ÇOK OYUNCULU", "ghost"], ["RUH MAĞAZASI", "ghost"], ["REKORLAR", "ghost"], ["AYARLAR", "ghost"], ["ÇIKIŞ", "danger"]]


## Ana menü düğmesi: [ikon] YAZI ...... [ek] (Ruh Mağazası'nda bakiye).
func _mbtn(t: String, kind: String, w: float, h: float, fs: int = 32, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Button:
	var b := _btn("", kind, fs, h, w)
	var tc: Color = b.get_theme_color("font_color")
	var items: Array = []
	if kind == "primary":
		items.append(_glyph(G_RIGHT, tc, 4))
	var l := _lbl(t, fs, tc)
	if kind == "primary":
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	items.append(l)
	if t == "RUH MAĞAZASI":
		if align == HORIZONTAL_ALIGNMENT_LEFT:
			items.append(_sp(0, 0, true))
		items.append(_shard(24))
		items.append(_lbl("1340", 24, _c("price")))
	return _btn_row(b, _hrow(items, 12), align)


func _menu_list(w: float, h: float, sep: int, fs: int = 32, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> VBoxContainer:
	var v := _v(sep)
	for m: Array in MENU:
		v.add_child(_mbtn(m[0], m[1], w, h, fs, align))
	return v


func _record_line(fs: int = 24) -> HBoxContainer:
	var h := _h(10)
	h.add_child(_lbl("En iyi koşu:", fs, _c("dim")))
	h.add_child(_lbl("Kademe 12  ·  24:10  ·  Elara", fs, _c("text")))
	return h


## ================================================================ ANA MENÜ A - Köy Akşamı (sol panel)
func _design_ana_a() -> Control:
	P = PAL["c"]
	## Ev + nehir + köprü; parti evin önünde oturuyor (sit_ klipleri, sahnenin sağ yarısında).
	_view(Vector2(1196, 2300), 3.0, Color.WHITE)
	_actor(1, "idle_down", Vector2(1262, 2392))
	_actor(4, "sit_down", Vector2(1294, 2402), 1)
	_actor(8, "sit_left", Vector2(1334, 2394), 2)
	_actor(7, "sit_right", Vector2(1238, 2410), 0)
	_pet("kopek", Vector2(1210, 2418), true)
	var r := _root(1.0, 0.9)
	var panel := _box(Color(_c("panel"), 0.92), _c("line"), 0, 0, 0)
	panel.add_theme_stylebox_override("panel", _panel_side())
	_place(r, panel, Vector2(0, 0), Vector2(600, H))
	var v := _v(0)
	v.add_child(_sp(0, 96))
	v.add_child(_logo(80, _c("accent"), false))
	v.add_child(_sp(0, 6))
	v.add_child(_lbl("Hayatta kal. Birlikte.", 32, _c("dim")))
	v.add_child(_sp(0, 80))
	v.add_child(_menu_list(472, 72, 14))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_record_line())
	v.add_child(_sp(0, 40))
	_place(r, v, Vector2(64, 0), Vector2(472, H))
	return r


func _panel_side() -> StyleBoxFlat:
	var s := _sb(Color(_c("panel"), 0.9), Color(0, 0, 0, 0), 0, 0)
	s.border_color = _c("line_hi")
	s.border_width_right = 3
	return s


## ================================================================ ANA MENÜ sade arka planları (2026-10-16, 2. tur)
## Kullanıcı: "arka planı hiç beğenmedim, haritanın bir parçası yerine yeni sade bir arka plan; yapay zeka yok, oyunun asset'leri".
## Arka plan = tools/proto_20261016/gen_ana_menu_bg.py'nin 480x270 PNG'si (x4), sol panel A yerleşimi; parti = gerçek sprite kareleri x4,
## sahnenin ışığına uyması için tonla çarpılır. Konumlar tuval pikselinde (ayak ortası).
const BG_PARTY := {
	"a": {"tint": Color(0.66, 0.70, 0.86), "party": [[1, "idle_down", 0, 300, 214, false], [4, "sit_down", 1, 330, 220, false],
			[8, "sit_down", 2, 372, 202, false], [7, "idle_left", 0, 418, 214, false]], "pet": ["kopek", 276, 224, true]},
	"b": {"tint": Color(0.70, 0.66, 0.70), "party": [[1, "idle_down", 0, 318, 214, false], [4, "idle_down", 1, 346, 220, false],
			[8, "idle_down", 2, 374, 214, false], [7, "idle_down", 0, 402, 220, false]], "pet": ["kopek", 292, 224, true]},
	"c": {"tint": Color(0.98, 0.78, 0.62), "party": [[1, "sit_up", 0, 300, 180, false], [4, "sit_up", 1, 324, 192, false],
			[8, "sit_up", 2, 348, 180, false], [7, "sit_left", 0, 374, 164, false]], "pet": ["kopek", 236, 200, false]},
	"d": {"tint": Color(0.70, 0.64, 0.84), "party": [[7, "walk_right", 1, 250, 206, false], [4, "walk_right", 3, 280, 210, false],
			[8, "walk_right", 5, 310, 206, false], [1, "walk_right", 2, 340, 210, false]], "pet": []},
}


func _design_bg_a() -> Control:
	return _bg_menu("a")


func _design_bg_b() -> Control:
	return _bg_menu("b")


func _design_bg_c() -> Control:
	return _bg_menu("c")


func _design_bg_d() -> Control:
	return _bg_menu("d")


func _bg_menu(kind: String) -> Control:
	P = PAL["c"]
	_view(Vector2(-4000, -4000), 1.0, Color.BLACK) ## harita kapalı: arka plan tamamen PNG
	var r := _root(1.0, 0.0)
	_cm.color = Color.BLACK
	var img := Image.load_from_file(_dir.path_join("bg").path_join("bg_%s.png" % kind))
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(img)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(bg)
	var spec: Dictionary = BG_PARTY[kind]
	var items: Array = []
	for p: Array in spec["party"]:
		items.append([int(p[4]), p])
	items.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	if not (spec["pet"] as Array).is_empty():
		var pt: Array = spec["pet"]
		_ui_sprite(r, (load(str(PC.FRAMES[pt[0]][0])) as SpriteFrames), str(PC.FRAMES[pt[0]][1]), 0, Vector2(pt[1], pt[2]), bool(pt[3]), spec["tint"])
	for it: Array in items:
		var p: Array = it[1]
		var d: Dictionary = _def(int(p[0]))
		_ui_sprite(r, load(str(d["frames"])) as SpriteFrames, str(p[1]), int(p[2]), Vector2(p[3], p[4]), bool(p[5]), spec["tint"])
	var panel := _box(Color(_c("panel"), 0.92), _c("line"), 0, 0, 0)
	panel.add_theme_stylebox_override("panel", _panel_side())
	_place(r, panel, Vector2(0, 0), Vector2(600, H))
	var v := _v(0)
	v.add_child(_sp(0, 96))
	v.add_child(_logo(80, _c("accent"), false))
	v.add_child(_sp(0, 6))
	v.add_child(_lbl("Hayatta kal. Birlikte.", 32, _c("dim")))
	v.add_child(_sp(0, 80))
	v.add_child(_menu_list(472, 72, 14))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_record_line())
	v.add_child(_sp(0, 40))
	_place(r, v, Vector2(64, 0), Vector2(472, H))
	return r


## Arka plan tuvaline (x4) gerçek sprite karesi: ayak ortası = foot (tuval px); altında piksel gölge elipsi.
func _ui_sprite(r: Control, sf: SpriteFrames, anim: String, frame: int, foot: Vector2, flip: bool, tint: Color) -> void:
	var a: String = anim if sf.has_animation(anim) else "idle_down"
	var tex: Texture2D = sf.get_frame_texture(a, mini(frame, sf.get_frame_count(a) - 1))
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	var used: Rect2i = img.get_used_rect()
	var k: float = 4.0
	var sh := ColorRect.new()
	var sw: float = maxf(12.0, used.size.x * 0.7) * k
	sh.color = Color(0, 0, 0, 0.32)
	sh.size = Vector2(sw, 2.0 * k)
	sh.position = Vector2(foot.x * k - sw * 0.5, foot.y * k - k)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(sh)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.flip_h = flip
	tr.size = Vector2(img.get_width(), img.get_height()) * k
	var cx: float = (used.position.x + used.size.x * 0.5) if not flip else (img.get_width() - used.position.x - used.size.x * 0.5)
	tr.position = Vector2(foot.x * k - cx * k, foot.y * k - used.end.y * k)
	tr.modulate = tint
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(tr)


## ================================================================ ANA MENÜ B - Köprü Başı (orta tabela)
func _design_ana_b() -> Control:
	P = PAL["a"]
	## Sağdaki köprü: parti köprüden geçiyor (walk_right), menü ortada; köprü sağda açık kalır.
	_view(Vector2(3440, 470), 2.5, Color.WHITE)
	_actor(1, "walk_right", Vector2(3730, 510), 2)
	_actor(8, "walk_right", Vector2(3700, 512), 4)
	_actor(4, "walk_right", Vector2(3670, 508), 0)
	_actor(7, "walk_right", Vector2(3640, 512), 3)
	var r := _root(1.0, 1.1)
	var v := _v(0)
	var lc := CenterContainer.new()
	lc.add_child(_logo(112, _c("accent"), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(lc)
	_place(r, v, Vector2(0, 96), Vector2(W, 0))
	var box := _box(Color(_c("panel"), 0.9), _c("line_hi"), 24)
	box.add_child(_menu_list(440, 64, 12, 32, HORIZONTAL_ALIGNMENT_CENTER))
	_place(r, box, Vector2((W - 488) * 0.5, 380))
	_place(r, _balance_chip(), Vector2(W - 32 - 170, 32))
	var rec := _box(Color(_c("panel"), 0.85), _c("line"), 10)
	rec.add_child(_record_line())
	_place(r, rec, Vector2(32, H - 32 - 52))
	return r


## ================================================================ ANA MENÜ C - Mod Kartları
func _design_ana_c() -> Control:
	P = PAL["d"]
	_view(Vector2(1723, 880), 2.0, Color.WHITE)
	var r := _root(0.55, 1.0)
	_place(r, _logo(80, _c("accent"), true), Vector2(56, 40))
	_place(r, _balance_chip(), Vector2(W - 32 - 170, 48))
	var cw: float = 660.0
	var ch: float = 540.0
	var x0: float = (W - (cw * 2 + 40)) * 0.5
	_place(r, _mode_card(false, cw, ch), Vector2(x0, 236))
	_place(r, _mode_card(true, cw, ch), Vector2(x0 + cw + 40, 236))
	var row := _h(20)
	for m: Array in MENU.slice(2):
		row.add_child(_mbtn(m[0], m[1] if m[1] != "ghost" else "ghost", 320 if m[0] != "RUH MAĞAZASI" else 400, 72, 32, HORIZONTAL_ALIGNMENT_CENTER))
	var rc := CenterContainer.new()
	rc.add_child(row)
	_place(r, rc, Vector2(0, 820), Vector2(W, 0))
	var rec := CenterContainer.new()
	rec.add_child(_record_line())
	_place(r, rec, Vector2(0, 940), Vector2(W, 0))
	return r


func _mode_card(multi: bool, w: float, h: float) -> PanelContainer:
	var card := _box(_c("panel"), _c("accent") if not multi else _c("line_hi"), 18, 3, 8)
	card.custom_minimum_size = Vector2(w, h)
	var v := _v(14)
	var stage := _box(_c("inset"), _c("line"), 0)
	stage.custom_minimum_size = Vector2(w - 36, 330)
	stage.add_child(Spot.new(_c("spot"), 0.84))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_bottom", 40)
	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_SHRINK_END
	var bh := _h(26)
	var ids: Array = [1, 4, 8, 7] if multi else [8]
	for id: int in ids:
		var tex: Texture2D = _body_tex(id)
		var k: float = floorf((200.0 if multi else 250.0) / tex.get_size().y)
		var tr := TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = tex.get_size() * k
		tr.size_flags_vertical = Control.SIZE_SHRINK_END
		bh.add_child(tr)
	cc.add_child(bh)
	m.add_child(cc)
	stage.add_child(m)
	v.add_child(stage)
	var th := _h(14)
	th.add_child(_lbl("ÇOK OYUNCULU" if multi else "TEK OYUNCULU", 64, _c("accent") if not multi else _c("text")))
	v.add_child(th)
	v.add_child(_lbl("Oda kur ya da katıl  ·  LAN / İnternet  ·  2-8 kişi" if multi else "Son koşu: Kademe 9  ·  18:42  ·  Elara", 24, _c("dim")))
	v.add_child(_sp(0, 0, false, true))
	var bt := _h(10)
	if multi:
		bt.add_child(_chip(G_GLOBE, "3 açık oda", _c("dim")))
		bt.add_child(_sp(0, 0, true))
		bt.add_child(_lbl("ODALARA GİT", 32, _c("text")))
		bt.add_child(_glyph(G_RIGHT, _c("text"), 4))
	else:
		bt.add_child(_sp(0, 0, true))
		bt.add_child(_lbl("BAŞLA", 32, _c("accent")))
		bt.add_child(_glyph(G_RIGHT, _c("accent"), 4))
	v.add_child(bt)
	card.add_child(v)
	return card


## ================================================================ ANA MENÜ D - Sinematik (alt şerit)
func _design_ana_d() -> Control:
	P = PAL["b"]
	## Sağ alt yaratık kampı (totem + kristaller + ölü ağaçlar); parti soldan kampa bakıyor.
	_view(Vector2(3790, 3190), 3.0, Color.WHITE)
	_actor(8, "idle_right", Vector2(3540, 3214))
	_actor(4, "idle_right", Vector2(3556, 3246))
	_actor(1, "idle_right", Vector2(3570, 3196))
	_actor(7, "idle_right", Vector2(3592, 3226))
	var r := _root(1.0, 0.9, 1.4)
	var lv := _v(4)
	lv.add_child(_big_title("LIL'SLAYERS", 128, _c("accent")))
	lv.add_child(_lbl("Hayatta kal. Birlikte.", 32, _c("text")))
	_place(r, lv, Vector2(72, 64))
	_place(r, _balance_chip(), Vector2(W - 32 - 170, 40))
	var bar := _box(Color(_c("panel"), 0.92), Color(0, 0, 0, 0), 0, 0, 0)
	var bs := _sb(Color(_c("panel"), 0.92), Color(0, 0, 0, 0), 0, 0)
	bs.border_color = _c("line_hi")
	bs.border_width_top = 3
	bar.add_theme_stylebox_override("panel", bs)
	_place(r, bar, Vector2(0, H - 128), Vector2(W, 128))
	var row := _h(8)
	for i in MENU.size():
		var m: Array = MENU[i]
		var on: bool = i == 0
		var b := _btn("", "flat_on" if on else "flat", 32, 72, 0)
		var items: Array = []
		if on:
			items.append(_glyph(G_RIGHT, _c("accent"), 4))
		items.append(_lbl(m[0], 32, _c("accent") if on else (_c("bad") if m[1] == "danger" else _c("text"))))
		if m[0] == "RUH MAĞAZASI":
			items.append(_shard(24))
			items.append(_lbl("1340", 24, _c("price")))
		b.custom_minimum_size.x = _tw(m[0], 32) + (110 if m[0] == "RUH MAĞAZASI" else 56) + (28 if on else 0)
		_btn_row(b, _hrow(items, 10))
		row.add_child(b)
	var rc := CenterContainer.new()
	rc.add_child(row)
	_place(r, rc, Vector2(0, H - 128 + 28), Vector2(W, 0))
	return r



## ================================================================ ANA MENÜ SOL PANEL varyantları (2026-10-16, 3. tur)
## Kullanıcı (Ocak Başı oyuna girince): "soldaki menüyü düzeltmeni istemiştim, çok ruhsuz ve sıradan duruyor". Düz koyu kutu + düz düğme
## yerine oyunun KENDİ sanatıyla 4 karakterli yön (hepsi aynı Ocak Başı sahnesinde): A Asılı Tahtalar (kit tabelası + ip + koyu ahşap
## "bark" düğmeleri), B Ahşap Kart Listesi (oda duvarının ahşap paneli + kiriş süsü, ikon + alt yazılı kartlar), C Defter (koyu çerçeveli
## parşömen sayfa, mürekkep yazı, kırmızı ayraç), D Panelsiz Ateş Işığı (sol karartma, büyük yazı, seçilide yanan mum).
## İkonlar: yüz portreleri, Ruh Kıymığı, eşya ikonları (kadeh = rekor, tornavida = ayar, rüzgar çizmesi = çıkış).
const SOL_ITEMS := [
	["TEK OYUNCULU", "Tek başına hayatta kal", "face1"],
	["ÇOK OYUNCULU", "Oda kur ya da arkadaşına katıl", "faces"],
	["RUH MAĞAZASI", "1340 kıymık · kilit aç", "shard"],
	["REKORLAR", "En iyi: Kademe 16 · 48:09", "res://assets/items/kralin_kadehi.png"],
	["AYARLAR", "Ses, görüntü, tuşlar", "res://assets/items/tornavida.png"],
	["ÇIKIŞ", "Masaüstüne dön", "res://assets/items/ruzgar_yuruyen_cizmeleri.png"],
]
const INK := Color("#3a2414")
const INK_DIM := Color("#553a22")
const CREAM := Color("#efe2c6")


func _design_sol_a() -> Control:
	return _sol("a")


func _design_sol_b() -> Control:
	return _sol("b")


func _design_sol_c() -> Control:
	return _sol("c")


func _design_sol_d() -> Control:
	return _sol("d")


func _sol(kind: String) -> Control:
	P = PAL["c"]
	_view(Vector2(-4000, -4000), 1.0, Color.BLACK)
	var r := _root(1.0, 0.0)
	_cm.color = Color.BLACK
	var img := Image.load_from_file(_dir.path_join("bg").path_join("bg_c.png"))
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(img)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(bg)
	var tint := Color(0.98, 0.78, 0.62)
	var dog: Array = PC.FRAMES["kopek"]
	_ui_sprite(r, load(str(dog[0])) as SpriteFrames, "sleep_down", 0, Vector2(262, 214), false, tint)
	for p: Array in [[7, "sit_left", 374, 164], [1, "sit_up", 300, 180], [8, "sit_up", 348, 180], [4, "sit_up", 324, 192]]:
		_ui_sprite(r, load(str(_def(int(p[0]))["frames"])) as SpriteFrames, str(p[1]), 3, Vector2(p[2], p[3]), false, tint)
	call("_sol_" + kind, r)
	return r


## Sol tarafı basamaklı (Bayer) karartma: x < extent (tuval px) koyulaşır. Işık değil, okunurluk için.
func _left_shade(r: Control, extent: float, strength: float) -> void:
	var img := Image.create(480, 270, false, Image.FORMAT_RGBA8)
	for y in 270:
		for x in 480:
			var b: float = (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0 - 0.5
			var t: float = clampf(1.0 - x / extent, 0.0, 1.0)
			var a: float = clampf(floorf(t * strength * 6.0 + b + 0.5) / 6.0, 0.0, 0.92)
			img.set_pixel(x, y, Color(0.06, 0.04, 0.03, a))
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(tr)


## Menü kiti 9-dilim dokusu (sanat pikseli x3 önceden ölçekli); mod = renk çarpanı (koyu/sıcak ton).
func _kit_sb(path: String, m: Array, content: Array, mod: Color = Color.WHITE, tile: bool = true) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path) as Texture2D
	sb.texture_margin_left = m[0] * 3
	sb.texture_margin_top = m[1] * 3
	sb.texture_margin_right = m[2] * 3
	sb.texture_margin_bottom = m[3] * 3
	sb.content_margin_left = content[0]
	sb.content_margin_top = content[1]
	sb.content_margin_right = content[2]
	sb.content_margin_bottom = content[3]
	sb.modulate_color = mod
	if tile:
		sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return sb


func _kit_panel(sb: StyleBox) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _rope(r: Control, x: float, y0: float, y1: float) -> void:
	var rope := TextureRect.new()
	rope.texture = load("res://assets/ui/menu/rope.png") as Texture2D
	rope.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rope.stretch_mode = TextureRect.STRETCH_TILE
	rope.modulate = Color(0.78, 0.68, 0.58)
	_place(r, rope, Vector2(roundf(x / 3.0) * 3.0 - 6.0, y0), Vector2(12, y1 - y0))


## Öğe ikonu: yüz / üç yüz / kıymık / eşya ikonu (tam kat); hepsi aynı genişlikte kutuda (yazılar hizalı kalsın).
func _sol_icon(spec: String, px: float) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(px * 1.6, px)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_sol_icon_raw(spec, px))
	return box


func _sol_icon_raw(spec: String, px: float) -> Control:
	match spec:
		"face1":
			return _face(1, px)
		"faces":
			var c := Control.new()
			c.custom_minimum_size = Vector2(px * 1.6, px)
			for i in 3:
				var f := _face([4, 8, 1][i], px * 0.75)
				f.position = Vector2(i * px * 0.42, px * 0.25 if i == 1 else 0.0)
				c.add_child(f)
			return c
		"shard":
			var cc := CenterContainer.new()
			cc.custom_minimum_size = Vector2(px, px)
			cc.add_child(_shard(px * 0.66))
			return cc
	return _icon(_tex(spec), px)


func _ttl(fs: int, c: Color, outline: bool = true) -> Label:
	var l := _lbl("LIL'SLAYERS", fs, c)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 1))
		l.add_theme_constant_override("outline_size", int(fs / 6.0))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		l.add_theme_constant_override("shadow_offset_y", int(fs / 12.0))
		l.add_theme_constant_override("shadow_outline_size", int(fs / 6.0))
	return l


## ---------------------------------------------------------------- A: Asılı Tahtalar
func _sol_a(r: Control) -> void:
	_left_shade(r, 230.0, 0.9)
	var sign_w: float = 456.0
	var sx: float = 52.0
	_rope(r, sx + sign_w * 0.2, 0, 96)
	_rope(r, sx + sign_w * 0.8, 0, 96)
	var sgn := _kit_panel(_kit_sb("res://assets/ui/menu/sign.png", [14, 25, 14, 25], [40, 0, 40, 6], Color(0.66, 0.55, 0.47)))
	var sv := _v(0)
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	var st := _ttl(80, Color("#f4d58e"))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sv.add_child(st)
	sgn.add_child(sv)
	_place(r, sgn, Vector2(sx, 84), Vector2(sign_w, 150))
	var ban := _kit_panel(_kit_sb("res://assets/ui/game/banner.png", [14, 8, 14, 11], [54, 3, 54, 21], Color(0.9, 0.82, 0.74), false))
	var bl := _lbl("Hayatta kal. Birlikte.", 24, Color("#2a1a10"), HORIZONTAL_ALIGNMENT_CENTER)
	bl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	ban.add_child(bl)
	_place(r, ban, Vector2(sx + 58, 222), Vector2(sign_w - 116, 72))
	var y: float = 330.0
	var pw: float = sign_w
	var px: float = sx
	for i in SOL_ITEMS.size():
		var it: Array = SOL_ITEMS[i]
		var sel: bool = i == 0
		_rope(r, px + pw * 0.16, y - 26, y + 6)
		_rope(r, px + pw * 0.84, y - 26, y + 6)
		var var_name: String = "tan" if sel else ("rose" if it[0] == "ÇIKIŞ" else "bark")
		var plank := _kit_panel(_kit_sb("res://assets/ui/game/btn_%s_normal.png" % var_name, [8, 5, 8, 5], [18, 6, 18, 6],
				Color(1.05, 0.95, 0.85) if sel else Color(0.9, 0.84, 0.8)))
		var h := _h(14)
		h.add_child(_sol_icon(str(it[2]), 48))
		var tc: Color = Color("#2a1a10") if sel else (Color("#ffd9c8") if it[0] == "ÇIKIŞ" else CREAM)
		var l := _lbl(str(it[0]), 32, tc)
		if sel:
			l.add_theme_color_override("font_shadow_color", Color(1, 0.9, 0.6, 0.35))
		h.add_child(l)
		h.add_child(_sp(0, 0, true))
		if it[0] == "RUH MAĞAZASI":
			h.add_child(_lbl("1340", 24, _c("price")))
		if sel:
			h.add_child(_glyph(G_LEFT, Color("#2a1a10"), 4))
		plank.add_child(h)
		_place(r, plank, Vector2(px, y), Vector2(pw, 72))
		y += 100.0
	var plq := _kit_panel(_kit_sb("res://assets/ui/game/hud_plaque_clean.png", [5, 5, 5, 5], [18, 8, 18, 8], Color(0.85, 0.78, 0.72)))
	var ph := _h(10)
	ph.add_child(_icon(_tex("res://assets/items/kralin_kadehi.png"), 32))
	ph.add_child(_lbl("En iyi: Kademe 16 · 48:09", 24, CREAM))
	plq.add_child(ph)
	_place(r, plq, Vector2(px, 960))


## ---------------------------------------------------------------- B: Ahşap Kart Listesi
func _wall_tex(rect: Rect2i, k: int, mod: float) -> ImageTexture:
	var src: Image = (load("res://harita/Ev içi/Interior_walls_floor.png") as Texture2D).get_image()
	if src.is_compressed():
		src.decompress()
	var reg: Image = src.get_region(rect)
	reg.convert(Image.FORMAT_RGBA8)
	for yy in reg.get_height():
		for xx in reg.get_width():
			var c: Color = reg.get_pixel(xx, yy)
			reg.set_pixel(xx, yy, Color(c.r * mod, c.g * mod, c.b * mod, c.a))
	reg.resize(reg.get_width() * k, reg.get_height() * k, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(reg)


func _sol_b(r: Control) -> void:
	var pw: float = 620.0
	var wood := TextureRect.new()
	wood.texture = _wall_tex(Rect2i(0, 216, 64, 32), 4, 0.5)
	wood.stretch_mode = TextureRect.STRETCH_TILE
	wood.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_place(r, wood, Vector2(0, 0), Vector2(pw, H))
	var trim := TextureRect.new()
	trim.texture = _wall_tex(Rect2i(0, 80, 64, 16), 4, 0.75)
	trim.stretch_mode = TextureRect.STRETCH_TILE
	trim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_place(r, trim, Vector2(0, 0), Vector2(pw, 64))
	var post := ColorRect.new()
	post.color = Color("#1a120c")
	_place(r, post, Vector2(pw - 8, 0), Vector2(8, H))
	var post2 := ColorRect.new()
	post2.color = Color("#6a4a30")
	_place(r, post2, Vector2(pw - 12, 0), Vector2(4, H))
	var tv := _v(4)
	var th := _h(14)
	var li := _icon(WC.icon("dagger"), 64)
	(li.get_child(0) as TextureRect).flip_h = true
	th.add_child(li)
	th.add_child(_ttl(80, _c("accent")))
	th.add_child(_icon(WC.icon("fire_staff"), 64))
	tv.add_child(th)
	tv.add_child(_lbl("Hayatta kal. Birlikte.", 32, _c("dim")))
	_place(r, tv, Vector2(44, 96))
	var y: float = 290.0
	for i in SOL_ITEMS.size():
		var it: Array = SOL_ITEMS[i]
		var sel: bool = i == 0
		var card := _box(Color("#1a120c", 0.86) if not sel else Color("#3b2a1c", 0.95), _c("accent") if sel else Color("#5a4230"), 10, 3, 4)
		var h := _h(16)
		var slot := _kit_panel(_kit_sb("res://assets/ui/game/slot_normal.png", [4, 4, 4, 4], [6, 6, 6, 6], Color(0.85, 0.78, 0.72), false))
		slot.add_child(_sol_icon(str(it[2]), 56))
		h.add_child(slot)
		var v := _v(0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(_lbl(str(it[0]), 32, _c("accent") if sel else (_c("bad") if it[0] == "ÇIKIŞ" else CREAM)))
		v.add_child(_lbl(str(it[1]), 24, _c("dim")))
		h.add_child(v)
		if sel:
			h.add_child(_icon(_candle_tex(), 64))
		card.add_child(h)
		_place(r, card, Vector2(44, y), Vector2(532, 0))
		y += 112.0


func _candle_tex() -> Texture2D:
	var at := AtlasTexture.new()
	at.atlas = load("res://harita/Ev içi/Candles.png") as Texture2D
	at.region = Rect2(96, 0, 32, 32)
	return at


## ---------------------------------------------------------------- C: Defter
func _sol_c(r: Control) -> void:
	_left_shade(r, 200.0, 0.7)
	var page := _kit_panel(_kit_sb("res://assets/ui/game/panel.png", [10, 10, 10, 10], [44, 40, 44, 40], Color(0.8, 0.7, 0.58)))
	var v := _v(10)
	var tl := _ttl(80, INK, false)
	tl.add_theme_color_override("font_shadow_color", Color(1, 0.95, 0.8, 0.35))
	tl.add_theme_constant_override("shadow_offset_y", 3)
	v.add_child(tl)
	var tag := _lbl("Hayatta kal. Birlikte.", 32, INK_DIM)
	tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	v.add_child(tag)
	v.add_child(_ink_rule())
	v.add_child(_sp(0, 18))
	for i in SOL_ITEMS.size():
		var it: Array = SOL_ITEMS[i]
		var sel: bool = i == 0
		var row := _h(14)
		row.custom_minimum_size.y = 84
		row.add_child(_sol_icon(str(it[2]), 48))
		var tv := _v(0)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		var t := _lbl(str(it[0]), 32, CREAM if sel else (Color("#8a2e1c") if it[0] == "ÇIKIŞ" else INK))
		t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4) if sel else Color(0, 0, 0, 0))
		tv.add_child(t)
		var s := _lbl(str(it[1]), 24, Color("#f6dcc0") if sel else INK_DIM)
		s.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		tv.add_child(s)
		row.add_child(tv)
		if sel:
			var mark := _kit_panel(_kit_sb("res://assets/ui/game/btn_rose_normal.png", [8, 5, 8, 5], [18, 0, 26, 0], Color(0.95, 0.8, 0.72)))
			mark.add_child(row)
			v.add_child(mark)
		else:
			var m := MarginContainer.new()
			m.add_theme_constant_override("margin_left", 18)
			m.add_child(row)
			v.add_child(m)
		if i < SOL_ITEMS.size() - 1 and not sel:
			v.add_child(_ink_rule(true))
	v.add_child(_sp(0, 0, false, true))
	var bot := _h(10)
	for id: int in [1, 4, 8, 7]:
		bot.add_child(_face(id, 48))
	bot.add_child(_sp(8))
	var bl := _lbl("Kademe 16 · 48:09", 24, INK_DIM)
	bl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	bot.add_child(bl)
	v.add_child(bot)
	page.add_child(v)
	_place(r, page, Vector2(36, 36), Vector2(560, H - 72))


func _ink_rule(dotted: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 6)
	var line := ColorRect.new()
	line.color = Color(INK, 0.35 if dotted else 0.6)
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.offset_top = 2
	line.offset_bottom = -1 if dotted else 0
	c.add_child(line)
	return c


## ---------------------------------------------------------------- D: Panelsiz Ateş Işığı
func _sol_d(r: Control) -> void:
	_left_shade(r, 250.0, 1.05)
	var v := _v(0)
	var th := _h(14)
	var li := _icon(WC.icon("dagger"), 64)
	(li.get_child(0) as TextureRect).flip_h = true
	th.add_child(li)
	th.add_child(_ttl(96, Color("#f4c56e")))
	th.add_child(_icon(WC.icon("fire_staff"), 64))
	v.add_child(th)
	v.add_child(_lbl("Hayatta kal. Birlikte.", 32, Color("#c8b28e")))
	v.add_child(_sp(0, 14))
	var trim := TextureRect.new()
	trim.texture = _wall_tex(Rect2i(0, 80, 64, 16), 3, 0.55)
	trim.stretch_mode = TextureRect.STRETCH_TILE
	trim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trim.custom_minimum_size = Vector2(480, 48)
	v.add_child(trim)
	v.add_child(_sp(0, 40))
	for i in SOL_ITEMS.size():
		var it: Array = SOL_ITEMS[i]
		var sel: bool = i == 0
		var h := _h(14)
		h.custom_minimum_size.y = 92
		var mk := CenterContainer.new()
		mk.custom_minimum_size = Vector2(64, 64)
		if sel:
			mk.add_child(_icon(_candle_tex(), 64))
		h.add_child(mk)
		h.add_child(_sol_icon(str(it[2]), 48))
		var tv := _v(-2)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		var t := _lbl(str(it[0]), 48, Color("#f4c56e") if sel else (_c("bad") if it[0] == "ÇIKIŞ" else CREAM))
		if sel:
			t.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.04, 1))
			t.add_theme_constant_override("outline_size", 6)
		tv.add_child(t)
		tv.add_child(_lbl(str(it[1]), 24, Color("#b09878") if not sel else Color("#e2c08a")))
		h.add_child(tv)
		v.add_child(h)
	_place(r, v, Vector2(40, 80))
	var bot := _h(10)
	for id: int in [1, 4, 8, 7]:
		bot.add_child(_face(id, 48))
	bot.add_child(_sp(6))
	bot.add_child(_lbl("En iyi: Kademe 16 · 48:09", 24, Color("#c8b28e")))
	_place(r, bot, Vector2(104, H - 92))
