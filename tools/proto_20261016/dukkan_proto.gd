extends SceneTree

## SEYYAR SATICI + DEMİRCİ GELİŞTİRME arayüz PROTOTİPLERİ (2026-10-16). Kullanıcı: "demirci geliştirme arayüzü ve seyyar satıcı
## arayüzünü komple sıfırdan tasarladığın 4 prototip; seyyar satıcı biraz League of Legends dükkan düzeninde, demirci RPG oyunlarındaki
## gelişim ekranlarına benzer, kullanıcı dostu".
## Oyuna BAĞLI DEĞİL: gerçek eşya / tarif / silah / efsun verisi (items.gd, enchant_defs.gd, weapon_catalog.gd, weapon_shop_logic.gd
## fiyat sabitleri) + sahte oyuncu durumu (altın, parçacık, sahip olunan eşyalar, silah geliştirmeleri). Arka plan: gerçek harita +
## seyyar satıcı arabası (satıcı) / gerçek demirci iç mekanı (demirci), karartılmış - ekranlar oyun içinde açılan modal pencerelerdir.
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261016/dukkan_proto.gd
##   DUKKAN_CAP_DIR = çıktı klasörü (zorunlu), DUKKAN_CAP_ONLY = "sa,db" gibi seçili çekimler (boşsa 8 çekim + 2 özet).

## ---------------------------------------------------------------- sahte oyuncu durumu
const GOLD := 1480
const SHARDS := 17
const VISIT_LEFT := 134.0 ## satıcının ayrılmasına kalan (traveling_merchant.gd VISIT_DURATION 180)
const VISIT_TOTAL := 180.0
const PART_SLOTS := 9 ## parça yuvası = seviye başına 1
const REROLL := 7 ## merchant_shop_screen.reroll_cost(0) ~9. dakikada
## Ziyaretin 12'lik stoku (traveling_merchant.gd: 4 parça -> 4 epik -> 4 efsanevi).
const STOCK := ["tornavida", "kutsal_tilsim", "ceviklik_yuzugu", "bile_tasi",
		"keskin_goz_hanceri", "savascinin_kilici", "ruh_emici", "yenilenme_ozutu",
		"ilidaricin_kilici", "son_felaket_pencesi", "kan_aglayan", "kiyamet_bicagi"]
const SOLD := ["kutsal_tilsim"]
const OWNED := ["bile_tasi", "ceviklik_yuzugu", "yasam_kristali", "ruzgar_eldiveni"]
const SEL_ITEM := "ilidaricin_kilici"
const GOAL_ITEM := "kan_aglayan"
const FAKE_STATS := {"damage_bonus": 46.0, "item_fire_rate_percent": 0.35, "max_health": 420.0, "item_shield_power_flat": 180.0,
		"crit_chance_bonus": 0.12, "lifesteal_percent": 0.03, "cooldown_reduction_percent": 0.05, "item_speed_percent": 0.04}
## Sahip olunan silah kopyaları + alınmış geliştirmeler (owned_weapons[i].enchant.ups / final).
const WEAPONS := [{"key": "uzunkilic", "ups": [0, 1], "final": false}, {"key": "tabanca", "ups": [0, 1, 2, 3], "final": false},
		{"key": "fire_staff", "ups": [], "final": false}]
const SEL_W := 0
const SEL_UP := 2

const MERCHANT_POS := Vector2(1931, 1290)
const SMITHY_POS := Vector2(24000, 0) ## weapon_shop.gd INTERIOR_OFFSET
const ZOOM := 2.25 ## player.gd masaüstü kamera yakınlaştırması

## Kademe çerçeve renkleri (oyundaki gibi: parça kahve, epik mavi, efsanevi mor) - koyu zeminde okunsun diye açılmış tonlar.
const TIER_COL := [Color("#c39a64"), Color("#6f9df2"), Color("#b98af2")]
const TIER_NAME := ["PARÇA", "EPİK", "EFSANEVİ"]
## Efsun kontür renkleri (enchant_weapon_glow.gd TIER_COLORS), dizin = kademe (1 kontürsüz).
const ENCH_COL := [Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.47, 0.91, 0.35), Color(0.31, 0.63, 1.0), Color(0.73, 0.49, 1.0), Color(1.0, 0.33, 0.28)]
const ROMAN := ["I", "II", "III", "IV", "V"]

const STAT_DIR := "res://assets/ui/stat_mini/"
const STAT_META := {
	"damage_bonus": ["Saldırı Gücü", "damage.png"], "item_fire_rate_percent": ["Saldırı Hızı", "fire_rate.png"],
	"crit_chance_bonus": ["Kritik Şansı", "crit_chance.png"], "max_health": ["Can", "@res://assets/ui/level_up_icons/stat_max_health.png"],
	"item_health_regen": ["Can Yenilenmesi", "health_regen.png"], "lifesteal_percent": ["Can Çalma", "lifesteal.png"],
	"item_shield_power_flat": ["Mana Kalkanı", "shield_amount.png"], "item_shield_regen_flat": ["Kalkan Yenilenmesi", "shield_regen.png"],
	"item_shield_regen_percent": ["Kalkan Yenilenme Hızı", "shield_regen.png"], "shield_pen_percent": ["Kalkan Delme", "shield_pen_percent.png"],
	"cooldown_reduction_percent": ["Bekleme Azaltma", "cooldown_reduction.png"], "item_speed_percent": ["Hareket Hızı", "speed.png"],
	"dodge_chance": ["Sıvışma", "dodge.png"], "heal_shield_power": ["İyileştirme Gücü", "heal_power.png"], "luck": ["Şans", "luck.png"],
	"exp_gain_percent": ["EXP Kazanımı", "@res://assets/ui/level_up_icons/stat_exp_gain.png"],
	"shield_protection_bonus": ["Kalkan Soğurma", "shield_protection.png"],
}
const FILTERS := ["damage_bonus", "item_fire_rate_percent", "crit_chance_bonus", "max_health", "item_health_regen", "lifesteal_percent",
		"item_shield_power_flat", "shield_pen_percent", "cooldown_reduction_percent", "item_speed_percent", "heal_shield_power", "luck"]
## Prototipte seçili silahın (Uzunkılıç - Wind Sword) özellik değerleri için etiketler (enchant_defs.gd wind_sword "set"/"add" anahtarları).
const TRAIT_STAT := {"wave_chance": "Dalga şansı", "wave_ap": "Dalga hasarı", "wave_push": "İtme mesafesi", "wave_slow": "Yavaşlatma",
		"wave_range": "Dalga menzili", "wave_width": "Dalga genişliği"}

const PAL := {
	## Kayrak & Altın (LoL'un lacivert-altın dükkanını andırır, oyunun koyu kitine yakın)
	"a": {"panel": Color("#1b212e"), "panel2": Color("#242c3b"), "panel3": Color("#2f3a4f"), "inset": Color("#121722"),
		"line": Color("#353f55"), "line_hi": Color("#56657f"), "text": Color("#ece6d7"), "dim": Color("#96a0b2"),
		"accent": Color("#d9b46a"), "accent_dk": Color("#6e5426"), "accent_text": Color("#21180a"),
		"good": Color("#94c97e"), "bad": Color("#dc8676"), "price": Color("#eccb7e"), "spot": Color("#6f8fc0")},
	## Gece moru + ruh mavisi (yan çanta)
	"b": {"panel": Color("#1a1629"), "panel2": Color("#231d38"), "panel3": Color("#30284d"), "inset": Color("#120e1f"),
		"line": Color("#352c55"), "line_hi": Color("#574a86"), "text": Color("#eee8f7"), "dim": Color("#a59dc0"),
		"accent": Color("#8fd9e8"), "accent_dk": Color("#2c6878"), "accent_text": Color("#0c1a22"),
		"good": Color("#9fe0aa"), "bad": Color("#ee8c9c"), "price": Color("#f2d48a"), "spot": Color("#8f7fd8")},
	## Koyu ahşap + fener, kehribar vurgu (Ruh Mağazası E/F'nin teması)
	"c": {"panel": Color("#241c16"), "panel2": Color("#2e251d"), "panel3": Color("#3b2f24"), "inset": Color("#1a140f"),
		"line": Color("#45372a"), "line_hi": Color("#6a5440"), "text": Color("#efe2c6"), "dim": Color("#ad9b80"),
		"accent": Color("#e2a64e"), "accent_dk": Color("#6a4416"), "accent_text": Color("#24160a"),
		"good": Color("#a9c96e"), "bad": Color("#dc7f60"), "price": Color("#f2c674"), "spot": Color("#c0803a")},
	## Gece ormanı yeşil-camgöbeği, nane vurgu
	"d": {"panel": Color("#152220"), "panel2": Color("#1c2d2a"), "panel3": Color("#264037"), "inset": Color("#0f1918"),
		"line": Color("#2c443e"), "line_hi": Color("#46665c"), "text": Color("#e7efe3"), "dim": Color("#92aba2"),
		"accent": Color("#a3dba9"), "accent_dk": Color("#2f5f3e"), "accent_text": Color("#0e2018"),
		"good": Color("#a3dba9"), "bad": Color("#e38c7c"), "price": Color("#f0da94"), "spot": Color("#5fa08a")},
	## Ocak: kömür siyahı + kor turuncusu (demirci ateşi)
	"f": {"panel": Color("#1c1714"), "panel2": Color("#251e19"), "panel3": Color("#33281f"), "inset": Color("#120e0c"),
		"line": Color("#3d3027"), "line_hi": Color("#5e4a3a"), "text": Color("#f0e4d4"), "dim": Color("#a8968a"),
		"accent": Color("#f08a3c"), "accent_dk": Color("#6e3410"), "accent_text": Color("#2a1206"),
		"good": Color("#a9d07a"), "bad": Color("#e07a64"), "price": Color("#f5c66e"), "spot": Color("#e0702a")},
	## Taş + erimiş altın (dövme kartları)
	"s": {"panel": Color("#1d1d21"), "panel2": Color("#26262b"), "panel3": Color("#313138"), "inset": Color("#141417"),
		"line": Color("#3a3a42"), "line_hi": Color("#5a5a64"), "text": Color("#ecebe6"), "dim": Color("#a3a2a8"),
		"accent": Color("#ffb347"), "accent_dk": Color("#7a4a10"), "accent_text": Color("#241405"),
		"good": Color("#9fd18a"), "bad": Color("#e38070"), "price": Color("#ffd27a"), "spot": Color("#ff9a3c")},
}
const PAL_OF := {"sa": "a", "sb": "c", "sc": "d", "sd": "b", "da": "c", "db": "f", "dc": "a", "dd": "s"}
const NAMES := {
	"sa": "A - Klasik Pazar (LoL: filtre | stok | tarif ağacı)", "sb": "B - Tarif Atölyesi (raf + büyük tarif ağacı)",
	"sc": "C - Öneri Rafı (parçalarınla tamamla + stat önizlemesi)", "sd": "D - Yan Çanta (sola yaslı, oyun görünür kalır)",
	"da": "A - Örs Vitrini (silah listesi + vitrin + malzeme)", "db": "B - Ustalık Ağacı (yetenek ağacı)",
	"dc": "C - Usta ile Karşılaştır (önce / sonra)", "dd": "D - Dövme Kartları (hepsi tek bakışta)",
}

const G_CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."]
const G_LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]
const G_X := ["##...##", ".##.##.", "..###..", ".##.##.", "##...##"]
const G_REROLL := ["..####.#", ".#....##", "#....###", "#.......", ".......#", "###....#", "##....#.", "#.####.."]
const G_SEARCH := [".###...", "#...#..", "#...#..", "#...#..", ".###...", "....##.", ".....##"]
const G_ARROW := ["...#...", "....#..", "#######", "....#..", "...#..."]
const G_UP := ["..#..", ".###.", "#####"]
const G_CROWN := ["#..#..#", "##.#.##", "#######", "#######", ".#####."]
const G_HAMMER := ["#######", "#######", "#######", "..###..", "...#...", "...#...", "...#...", "...#..."]
const G_LEFT := ["..#", ".##", "###", ".##", "..#"]
const G_DIAMOND := ["..#..", ".###.", "#####", ".###.", "..#.."]
const G_PLUS := ["..#..", "..#..", "#####", "..#..", "..#.."]
const G_MINUS := ["#####"]
const G_EQ := ["#####", ".....", "#####"]

const SIL_SHADER := """shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb, step(0.35, a) * tint.a);
}
"""

var _dir: String = OS.get_environment("DUKKAN_CAP_DIR")
var IT: GDScript = null ## items.gd
var ED: GDScript = null ## enchant_defs.gd
var WC: GDScript = null ## weapon_catalog.gd
var LG: GDScript = null ## weapon_shop_logic.gd
var P: Dictionary = {}
var _world: Node2D = null
var _cam: Camera2D = null
var _ui: CanvasLayer = null
var _merchant_c := Vector2.ZERO
var _smithy_c := Vector2.ZERO
var _tex_cache: Dictionary = {}
var _sil_shader: Shader = null
var _sil_mats: Dictionary = {}


## ---------------------------------------------------------------- çizim sınıfları
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


class Bar extends Control:
	var frac: float = 0.0
	var fill: Color = Color.WHITE
	var back: Color = Color.BLACK

	func _init(f: float, fc: Color, bc: Color, h: float = 10.0, w: float = 0.0) -> void:
		frac = clampf(f, 0.0, 1.0)
		fill = fc
		back = bc
		custom_minimum_size = Vector2(w, h)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), back)
		var fw: float = floorf((size.x - 6.0) * frac)
		if fw > 0.0:
			draw_rect(Rect2(3, 3, fw, size.y - 6), fill)
			draw_rect(Rect2(3, 3, fw, 2), fill.lightened(0.3))


## Kademe başına renkli ustalık çubuğu (4 geliştirme + final).
class TierPips extends Control:
	var cols: Array = []
	var on: int = 0
	var back: Color = Color.BLACK

	func _init(colors: Array, filled: int, bc: Color, w: float, h: float) -> void:
		cols = colors
		on = filled
		back = bc
		custom_minimum_size = Vector2(w, h)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n: int = cols.size()
		var gap: float = 4.0
		var seg: float = floorf((size.x - gap * (n - 1)) / n)
		for i in n:
			var x: float = i * (seg + gap)
			var c: Color = cols[i] if i < on else back
			draw_rect(Rect2(x, 0, seg, size.y), c)
			if i < on:
				draw_rect(Rect2(x, 0, seg, 2), c.lightened(0.35))


## Yumuşak basamaklı ışık havuzu + zemin elipsi (vitrin kutuları için).
class Spot extends Control:
	var col: Color = Color.WHITE
	var floor_y: float = 0.78

	func _init(c: Color, fy: float = 0.78) -> void:
		col = c
		floor_y = fy
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := (size * Vector2(0.5, 0.48)).floor()
		var r: float = minf(size.x, size.y) * 0.46
		for i in 4:
			draw_circle(c, floorf(r * (1.0 - i * 0.2)), Color(col, 0.06 + i * 0.03))
		var fc := Vector2(c.x, floorf(size.y * floor_y))
		draw_set_transform(fc, 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, floorf(r * 0.62), Color(col, 0.20))
		draw_circle(Vector2.ZERO, floorf(r * 0.44), Color(col, 0.16))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Bağlantı çizgileri (tarif ağacı, ustalık ağacı): [PackedVector2Array, Color, kalınlık].
class Lines extends Control:
	var segs: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for s: Array in segs:
			draw_polyline(s[0] as PackedVector2Array, s[1] as Color, float(s[2]))


## Üstü çizili eski fiyat.
class StrikeLabel extends Label:
	var strike: Color = Color.WHITE

	func _draw() -> void:
		var y: float = floorf(size.y * 0.5)
		draw_rect(Rect2(0, y, size.x, 2), strike)


## ---------------------------------------------------------------- akış
func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await process_frame
	if _dir == "":
		push_error("DUKKAN_CAP_DIR yok")
		quit()
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	IT = load("res://scripts/items.gd")
	ED = load("res://scripts/enchant_defs.gd")
	WC = load("res://scripts/weapon_catalog.gd")
	LG = load("res://scripts/weapon_shop_logic.gd")
	_sil_shader = Shader.new()
	_sil_shader.code = SIL_SHADER
	_setup_world()
	await _frames(6)
	var only: String = OS.get_environment("DUKKAN_CAP_ONLY")
	var imgs: Dictionary = {}
	for tag: String in ["sa", "sb", "sc", "sd", "da", "db", "dc", "dd"]:
		if only != "" and not tag in only.split(","):
			continue
		P = PAL[PAL_OF[tag]]
		var smithy: bool = tag.begins_with("d")
		_cam.position = (_smithy_c if smithy else _merchant_c) + (Vector2(-150, 0) if tag == "sd" else Vector2.ZERO)
		var ui: Control = call("_design_" + tag)
		_ui.add_child(ui)
		await _frames(8)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png(_dir.path_join(_file_of(tag) + ".png"))
		imgs[tag] = img
		print("SHOT %s %dx%d" % [tag, img.get_width(), img.get_height()])
		ui.queue_free()
		await process_frame
	if only == "":
		await _overview(imgs, ["sa", "sb", "sc", "sd"], "satici_ozet.png", "SEYYAR SATICI")
		await _overview(imgs, ["da", "db", "dc", "dd"], "demirci_ozet.png", "DEMİRCİ")
	quit()


func _file_of(tag: String) -> String:
	return ("satici_" if tag.begins_with("s") else "demirci_") + tag.substr(1, 1)


func _overview(imgs: Dictionary, tags: Array, file: String, title: String) -> void:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font = MenuKit.font()
	r.theme = th
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
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var l := Label.new()
		l.text = "%s  %s" % [title, NAMES[tag]]
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Color("#e8e4da"))
		v.add_child(l)
		var tr := TextureRect.new()
		if imgs.has(tag):
			tr.texture = ImageTexture.create_from_image(imgs[tag])
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.custom_minimum_size = Vector2(936, 506)
		v.add_child(tr)
		g.add_child(v)
	_ui.add_child(r)
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join(file))
	r.queue_free()
	await process_frame


## ---------------------------------------------------------------- dünya (gerçek harita + satıcı arabası + demirci iç mekanı)
func _setup_world() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	_world = Node2D.new()
	_world.name = "Main"
	root.add_child(_world)
	current_scene = _world
	var map: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	map.name = "Harita"
	_world.add_child(map)
	var cart: Node2D = (load("res://scenes/seyyar_satici_baked.tscn") as PackedScene).instantiate()
	cart.position = MERCHANT_POS
	_world.add_child(cart)
	_merchant_c = MERCHANT_POS + _used_rect(cart).get_center()
	_npc_sprite("res://assets/npc/seyyar_satici/seyyar_satici_frames.tres", _merchant_c + Vector2(-34, 40))
	var smithy: Node2D = (load("res://scenes/silah_saticisi_baked.tscn") as PackedScene).instantiate()
	smithy.position = SMITHY_POS
	_world.add_child(smithy)
	_smithy_c = SMITHY_POS + _used_rect(smithy).get_center()
	var anvil: TileMapLayer = smithy.get_node_or_null("Eleman pozisyon") as TileMapLayer
	if anvil != null:
		anvil.visible = false
		var cells: Array = anvil.get_used_cells()
		if not cells.is_empty():
			_npc_sprite("res://assets/npc/demirci/demirci_frames.tres", SMITHY_POS + anvil.position + anvil.map_to_local(cells[0]) + Vector2(0, 8))
	_cam = Camera2D.new()
	_cam.zoom = Vector2(ZOOM, ZOOM)
	_world.add_child(_cam)
	_cam.make_current()
	_ui = CanvasLayer.new()
	_ui.layer = 5
	root.add_child(_ui)


func _used_rect(n: Node) -> Rect2:
	var r := Rect2()
	var first := true
	for c in n.get_children():
		if not c is TileMapLayer:
			continue
		var l := c as TileMapLayer
		var ur: Rect2i = l.get_used_rect()
		if ur.size == Vector2i.ZERO:
			continue
		var ts := Vector2(l.tile_set.tile_size) if l.tile_set != null else Vector2(16, 16)
		var rr := Rect2(l.position + Vector2(ur.position) * ts, Vector2(ur.size) * ts)
		r = rr if first else r.merge(rr)
		first = false
	return r


func _npc_sprite(frames: String, pos: Vector2) -> void:
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = load(frames) as SpriteFrames
	spr.animation = &"idle_down"
	spr.stop()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.scale = Vector2(0.54, 0.54)
	spr.z_index = 30
	_world.add_child(spr)


## ---------------------------------------------------------------- veri
func _owned_d() -> Array:
	var out: Array = []
	for k: String in OWNED:
		out.append({"key": k})
	return out


func _plan(key: String) -> Dictionary:
	return IT.plan_purchase(key, _owned_d())


func _state(key: String) -> String:
	if SOLD.has(key):
		return "sold"
	var pl: Dictionary = _plan(key)
	if str(IT.purchase_block_reason(key, _owned_d(), PART_SLOTS, pl)) != "":
		return "blocked"
	return "can" if int(pl["cost"]) <= GOLD else "poor"


func _consumed(key: String) -> Array:
	var out: Array = []
	for idx in _plan(key).get("consume", []):
		out.append(OWNED[int(idx)])
	return out


func _istats(key: String) -> Dictionary:
	return (IT.get_def(key) as Dictionary).get("stats", {})


func _has_stat(key: String, s: String) -> bool:
	return _istats(key).has(s)


## Satın alınca statların NET değişimi: eşyanın statları - tüketilecek parçaların statları.
func _net_delta(key: String) -> Dictionary:
	var d: Dictionary = {}
	for s: String in _istats(key):
		d[s] = float(d.get(s, 0.0)) + float(_istats(key)[s])
	for c: String in _consumed(key):
		for s: String in _istats(c):
			d[s] = float(d.get(s, 0.0)) - float(_istats(c)[s])
	return d


func _num(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else ("%.1f" % v).replace(".", ",")


func _is_pct(s: String) -> bool:
	var lab: Array = IT.STAT_LABELS.get(s, ["", false])
	return bool(lab[1])


func _sname(s: String) -> String:
	if STAT_META.has(s):
		return str(STAT_META[s][0])
	return str((IT.STAT_LABELS.get(s, [s, false]) as Array)[0])


func _fmt_stat(s: String, v: float, signed: bool = true) -> String:
	var sign: String = ("+" if v >= 0.0 else "-") if signed else ""
	if _is_pct(s):
		return "%s%%%s" % [sign, _num(absf(v) * 100.0)]
	return "%s%s" % [sign, _num(absf(v))]


func _stat_tex(s: String) -> Texture2D:
	if not STAT_META.has(s):
		return null
	var f: String = str(STAT_META[s][1])
	return _tex(f.substr(1) if f.begins_with("@") else STAT_DIR + f)


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _tex_cache[path]


func _npc_tex(which: String) -> Texture2D:
	var path: String = "res://assets/npc/demirci/demirci_frames.tres" if which == "demirci" else "res://assets/npc/seyyar_satici/seyyar_satici_frames.tres"
	var sf: SpriteFrames = load(path) as SpriteFrames
	return sf.get_frame_texture(&"idle_down", 0)


func _passive(key: String) -> String:
	return str((IT.get_def(key) as Dictionary).get("passive", ""))


## ---- silah verisi
func _wkey(i: int) -> String:
	return str(WEAPONS[i]["key"])


func _wname(i: int) -> String:
	return str(WC.NAMES.get(_wkey(i), _wkey(i)))


func _wdef(i: int) -> Dictionary:
	return ED.get_def(str(ED.trait_of(_wkey(i))))


func _wrows(i: int) -> Array:
	return ED.upgrade_rows(str(ED.trait_of(_wkey(i))))


func _wups(i: int) -> Array:
	return WEAPONS[i]["ups"]


func _wtier(i: int) -> int:
	if bool(WEAPONS[i]["final"]):
		return 5
	return mini(4, 1 + _wups(i).size())


func _row_state(i: int, idx: int) -> String:
	var rows: Array = _wrows(i)
	if bool((rows[idx] as Dictionary)["final"]):
		if bool(WEAPONS[i]["final"]):
			return "taken"
		return "avail" if _wups(i).size() >= rows.size() - 1 else "locked"
	return "taken" if _wups(i).has(idx) else "avail"


## Vector2i(altın, parçacık) - weapon_shop_logic.gd wupgrade_price / wupgrade_shard_cost ile aynı formül.
func _up_cost(i: int, idx: int) -> Vector2i:
	var rows: Array = _wrows(i)
	if bool((rows[idx] as Dictionary)["final"]):
		return Vector2i(int(LG.WFINAL_PRICE), int(LG.SHARD_COST_WFINAL))
	return Vector2i(int(LG.WUPGRADE_BASE_PRICE) + int(LG.WUPGRADE_PRICE_STEP) * _wups(i).size(), int(LG.SHARD_COST_WUPGRADE))


func _pip_cols() -> Array:
	return [ENCH_COL[2], ENCH_COL[3], ENCH_COL[4], ENCH_COL[4], ENCH_COL[5]]


func _wpips(i: int, w: float, h: float = 10.0) -> TierPips:
	return TierPips.new(_pip_cols(), _wups(i).size() + (1 if bool(WEAPONS[i]["final"]) else 0), _c("inset"), w, h)


func _tier_color(t: int) -> Color:
	return ENCH_COL[t] if t >= 2 else _c("dim")


## Özellik değerleri: temel "set" + alınan geliştirmelerin "add"/"set"leri (+ istenirse bir geliştirme daha).
func _trait_vals(i: int, extra: int) -> Dictionary:
	var d: Dictionary = _wdef(i)
	var vals: Dictionary = ((d["base"] as Dictionary)["set"] as Dictionary).duplicate()
	var ups: Array = d["upgrades"]
	var take: Array = _wups(i).duplicate()
	if extra >= 0:
		take.append(extra)
	for u in take:
		var up: Dictionary = ups[int(u)]
		for k: String in up.get("add", {}):
			vals[k] = float(vals.get(k, 0.0)) + float(up["add"][k])
		for k: String in up.get("set", {}):
			vals[k] = up["set"][k]
	return vals


func _trait_fmt(k: String, v: float) -> String:
	match k:
		"wave_chance":
			return "%%%s" % _num(v * 100.0)
		"wave_ap":
			return "SG'nin %%%s'i" % _num(v * 100.0)
		"wave_slow":
			return "yok" if v <= 0.0 else "%%%s · 1,5 sn" % _num(v * 100.0)
	return "%s birim" % _num(v)


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


func _wrap(t: String, fs: int, c: Color, w: float, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := _lbl(t, fs, c, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	return l


func _clip(t: String, fs: int, c: Color, w: float, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := _lbl(t, fs, c, align)
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = w
	return l


func _strike(t: String, fs: int, c: Color) -> StrikeLabel:
	var l := StrikeLabel.new()
	l.text = t
	l.strike = c
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _hline(c: Color = Color(0, 0, 0, 0), h: float = 3.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = c if c.a > 0.0 else _c("line")
	r.custom_minimum_size = Vector2(0, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _vline(c: Color = Color(0, 0, 0, 0), w: float = 3.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = c if c.a > 0.0 else _c("line")
	r.custom_minimum_size = Vector2(w, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _expand(c: Control, x: bool = true, y: bool = false) -> Control:
	if x:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if y:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


func _glyph(pat: Array, c: Color, px: int = 3) -> Glyph:
	return Glyph.new(pat, c, px)


## Kutuya sığan en büyük TAM katlı büyütme (piksel bozulmasın); kutudan büyük doku (silah ikonları 250 px) yumuşak küçültülür.
func _icon_tr(tex: Texture2D, box: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		tr.custom_minimum_size = Vector2(box, box)
		tr.size = tr.custom_minimum_size
		return tr
	var ts: Vector2 = tex.get_size()
	var big: float = maxf(ts.x, ts.y)
	var k: float = floorf(box / big)
	if k >= 1.0:
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.custom_minimum_size = (ts * k).floor()
	else:
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.custom_minimum_size = (ts * box / big).floor()
	tr.size = tr.custom_minimum_size
	return tr


func _icon(tex: Texture2D, box: float, dim: bool = false) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(box, box)
	cc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		return cc
	var tr := _icon_tr(tex, box)
	if dim:
		tr.modulate = Color(0.5, 0.5, 0.56, 1.0)
	cc.add_child(tr)
	return cc


func _coin(box: float = 24.0) -> CenterContainer:
	return _icon(_tex("res://assets/ui/newui/icon_gold_coin.png"), box)


func _shard_ic(box: float = 24.0, dim: bool = false) -> CenterContainer:
	return _icon(_tex("res://assets/pickups/weapon_shard/shard_icon.png"), box, dim)


## [ikon] sayı - kind "gold" | "shard"
func _amt(n: int, fs: int, col: Color, kind: String = "gold") -> HBoxContainer:
	var h := _h(6)
	var box: float = 32.0 if fs >= 32 else 24.0
	h.add_child(_coin(box) if kind == "gold" else _shard_ic(box))
	h.add_child(_lbl(str(n), fs, col))
	return h


func _amt_w(n: int, fs: int) -> float:
	return (32.0 if fs >= 32 else 24.0) + 6.0 + _tw(str(n), fs)


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
		"confirm":
			fill = _c("good")
			bd = _c("good").darkened(0.55)
			tc = Color("#10200c")
		"tab":
			fill = Color(0, 0, 0, 0)
			bd = Color(0, 0, 0, 0)
			tc = _c("dim")
		"tab_on":
			fill = _c("panel3")
			bd = _c("accent")
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
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_style(b, kind)
	return b


func _btn_tc(kind: String) -> Color:
	match kind:
		"ghost":
			return _c("text")
		"off", "tab":
			return _c("dim")
		"confirm":
			return Color("#10200c")
		"tab_on":
			return _c("accent")
	return _c("accent_text")


## İçine ortalanmış satır koyulan düğme (ikon + yazı + fiyat).
func _row_btn(row: HBoxContainer, kind: String = "primary", h: float = 64.0, w: float = 0.0) -> Button:
	var b := _btn("", kind, 32, h, w)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l in row.get_children():
		if l is Label and kind in ["primary", "confirm"]:
			(l as Label).add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	cc.add_child(row)
	b.add_child(cc)
	if w <= 0.0:
		b.custom_minimum_size.x = _est_w(row) + 48.0
	return b


## Ağaca eklenmeden önce genişlik tahmini (Label'ın en küçük boyutu ağaç dışında yedek fontla ölçülür - yanlış çıkar).
func _est_w(n: Node) -> float:
	if n is Label:
		return _tw((n as Label).text, (n as Label).get_theme_font_size("font_size"))
	if n is HBoxContainer:
		var w: float = 0.0
		var k: int = 0
		for c in n.get_children():
			w += _est_w(c)
			k += 1
		return w + maxi(0, k - 1) * (n as HBoxContainer).get_theme_constant("separation")
	if n is Control:
		return (n as Control).custom_minimum_size.x
	return 0.0


## [YAZI   (altın) N   (parçacık) M]
func _cost_btn(t: String, gold: int, shards: int, kind: String = "primary", fs: int = 32, h: float = 64.0, w: float = 0.0, glyph: Array = []) -> Button:
	var tc: Color = _btn_tc(kind)
	var row := _h(10)
	if not glyph.is_empty():
		row.add_child(_glyph(glyph, tc, 4))
	if t != "":
		row.add_child(_lbl(t, fs, tc))
	if gold >= 0:
		row.add_child(_sp(10))
		row.add_child(_amt(gold, fs, tc))
	if shards >= 0:
		row.add_child(_sp(4))
		row.add_child(_amt(shards, fs, tc, "shard"))
	return _row_btn(row, kind, h, w)


func _close_btn() -> Button:
	var row := _h(0)
	row.add_child(_glyph(G_X, _c("text"), 4))
	return _row_btn(row, "ghost", 56, 56)


func _reroll_btn(fs: int = 32) -> Button:
	var row := _h(10)
	row.add_child(_glyph(G_REROLL, _c("text"), 3))
	row.add_child(_lbl("YENİLE", fs, _c("text")))
	row.add_child(_amt(REROLL, fs, _c("price")))
	return _row_btn(row, "ghost", 56)


func _chip(kind: String, n: int, caption: String) -> PanelContainer:
	var p := _box(_c("inset"), _c("line_hi"), 8.0)
	var h := _h(10)
	h.add_child(_sp(2))
	h.add_child(_coin(32) if kind == "gold" else _shard_ic(32))
	var v := _v(-8)
	v.add_child(_lbl(caption, 24, _c("dim")))
	v.add_child(_lbl(str(n), 32, _c("price") if kind == "gold" else Color("#a8d8f0")))
	h.add_child(v)
	h.add_child(_sp(6))
	p.add_child(h)
	return p


func _tabs(names: Array, active: int, fs: int = 32, h: float = 56.0) -> HBoxContainer:
	var row := _h(6)
	for i in names.size():
		row.add_child(_btn(str(names[i]), "tab_on" if i == active else "tab", fs, h, _tw(str(names[i]), fs) + 44.0))
	return row


func _root(dim: float) -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.theme = _theme()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var d := ColorRect.new()
	d.color = Color(0.02, 0.02, 0.03, dim)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(d)
	return r


## Ortalanmış pencere; döner [pencere, içerik VBox].
func _window(r: Control, pos: Vector2, sz: Vector2, pad: Vector4 = Vector4(24, 18, 24, 20)) -> VBoxContainer:
	var win := PanelContainer.new()
	var st := _sb(_c("panel"), _c("line_hi"), 3, 8, 0.0)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 14
	st.shadow_offset = Vector2(0, 8)
	win.add_theme_stylebox_override("panel", st)
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.position = pos
	win.custom_minimum_size = sz
	r.add_child(win)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(pad.x))
	m.add_theme_constant_override("margin_top", int(pad.y))
	m.add_theme_constant_override("margin_right", int(pad.z))
	m.add_theme_constant_override("margin_bottom", int(pad.w))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.add_child(m)
	var col := _v(14)
	m.add_child(col)
	return col


func _sil_mat(col: Color) -> ShaderMaterial:
	var k: String = col.to_html()
	if not _sil_mats.has(k):
		var m := ShaderMaterial.new()
		m.shader = _sil_shader
		m.set_shader_parameter("tint", col)
		_sil_mats[k] = m
	return _sil_mats[k]


## Silah ikonu + efsun kademesi kontürü (oyundaki gibi; kademe 1 kontürsüz).
func _wicon(key: String, box: float, tier: int, dim: bool = false) -> Control:
	var tex: Texture2D = WC.icon(key)
	var c := Control.new()
	c.custom_minimum_size = Vector2(box, box)
	c.size = c.custom_minimum_size
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = ENCH_COL[clampi(tier, 0, 5)]
	var px: float = clampf(roundf(box / 56.0), 2.0, 4.0)
	var inner: float = box - px * 4.0
	if col.a > 0.0 and not dim:
		for off: Vector2 in [Vector2(-px, 0), Vector2(px, 0), Vector2(0, -px), Vector2(0, px), Vector2(-px, -px), Vector2(px, -px), Vector2(-px, px), Vector2(px, px)]:
			var s := _icon_tr(tex, inner)
			s.material = _sil_mat(col)
			s.position = ((c.size - s.size) * 0.5).floor() + off
			c.add_child(s)
	var ic := _icon_tr(tex, inner)
	ic.position = ((c.size - ic.size) * 0.5).floor()
	if dim:
		ic.modulate = Color(0.45, 0.45, 0.5, 1.0)
	c.add_child(ic)
	return c


## Eşya yuvası: koyu iç + kademe renginde kenar + tam katlı ikon. o: sel / dim / sold / owned / stock / fill
func _tile(tex: Texture2D, s: float, border: Color, o: Dictionary = {}) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(s, s)
	c.size = c.custom_minimum_size
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim: bool = bool(o.get("dim", false))
	var bw: int = 3 if s >= 48.0 else 2
	if bool(o.get("sel", false)):
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0), _c("accent"), 3, 8))
		ring.position = Vector2(-6, -6)
		ring.size = Vector2(s + 12, s + 12)
		c.add_child(ring)
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: Color = o.get("fill", _c("inset"))
	var bc: Color = border.darkened(0.55) if dim else border
	bg.add_theme_stylebox_override("panel", _sb(fill, bc, bw, 4))
	bg.size = c.size
	c.add_child(bg)
	if not dim:
		var glow := ColorRect.new()
		glow.color = Color(border, 0.10)
		glow.position = Vector2(bw, bw)
		glow.size = Vector2(s - bw * 2, floorf((s - bw * 2) * 0.5))
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(glow)
	if tex != null:
		var ic := _icon_tr(tex, s - bw * 2 - 2)
		ic.position = ((c.size - ic.size) * 0.5).floor()
		if dim or bool(o.get("sold", false)):
			ic.modulate = Color(0.42, 0.42, 0.48, 1.0)
		c.add_child(ic)
	if bool(o.get("sold", false)):
		var sh := ColorRect.new()
		sh.color = Color(0, 0, 0, 0.45)
		sh.position = Vector2(bw, bw)
		sh.size = c.size - Vector2(bw * 2, bw * 2)
		sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(sh)
	if bool(o.get("owned", false)):
		var bs: float = 22.0 if s >= 64.0 else 18.0
		var badge := Panel.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_stylebox_override("panel", _sb(_c("good"), _c("good").darkened(0.6), 2, 3))
		badge.position = Vector2(s - bs + 4, s - bs + 4)
		badge.size = Vector2(bs, bs)
		c.add_child(badge)
		var g := _glyph(G_CHECK, Color("#10200c"), 2)
		g.position = badge.position + ((Vector2(bs, bs) - g.custom_minimum_size) * 0.5).floor()
		c.add_child(g)
	if bool(o.get("stock", false)):
		var g2 := _glyph(G_DIAMOND, _c("price"), 2)
		g2.position = Vector2(bw + 3, bw + 3)
		c.add_child(g2)
	return c


func _itile(key: String, s: float, o: Dictionary = {}) -> Control:
	return _tile(IT.icon(key), s, TIER_COL[int(IT.kademe(key)) - 1], o)


func _empty_slot(s: float) -> Control:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0.25), _c("line"), 2, 4))
	p.custom_minimum_size = Vector2(s, s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## Stoktaki eşyanın fiyat satırı: sendeki parçalar düşülmüşse yeşil yeni fiyat + üstü çizili tam fiyat.
func _price_cell(key: String, fs: int = 24, center: bool = true) -> HBoxContainer:
	var st: String = _state(key)
	var pl: Dictionary = _plan(key)
	var cost: int = int(pl["cost"])
	var full: int = int(pl["full"])
	var h := _h(6)
	if center:
		h.alignment = BoxContainer.ALIGNMENT_CENTER
	match st:
		"sold":
			h.add_child(_lbl("SATILDI", fs, _c("dim")))
		"blocked":
			h.add_child(_lbl("SENDE VAR", fs, _c("dim")))
		_:
			var col: Color = _c("price")
			if st == "poor":
				col = _c("bad")
			elif cost < full:
				col = _c("good")
			h.add_child(_amt(cost, fs, col))
			if cost < full:
				h.add_child(_strike(str(full), fs, _c("dim")))
	return h


func _stat_line(s: String, v: float, fs: int = 24, col: Color = Color(0, 0, 0, 0)) -> HBoxContainer:
	var h := _h(8)
	h.add_child(_icon(_stat_tex(s), 24))
	h.add_child(_lbl("%s %s" % [_fmt_stat(s, v), _sname(s)], fs, col if col.a > 0.0 else _c("text")))
	return h


func _stat_grid(key: String, cols: int = 2, fs: int = 24) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 4)
	for s: String in _istats(key):
		if (IT.PASSIVE_ONLY_STATS as Array).has(s) or not IT.STAT_LABELS.has(s):
			continue
		g.add_child(_stat_line(s, float(_istats(key)[s]), fs))
	return g


func _passive_box(key: String, w: float, fs: int = 24) -> Control:
	var t: String = _passive(key)
	var v := _v(2)
	if t == "":
		return v
	v.add_child(_lbl("PASİF", fs, _c("accent")))
	v.add_child(_wrap(t, fs, _c("text"), w))
	return v


func _section(t: String, sub: String = "", fs: int = 32) -> HBoxContainer:
	var h := _h(12)
	h.add_child(_lbl(t, fs, _c("accent")))
	if sub != "":
		h.add_child(_lbl(sub, 24, _c("dim")))
	return h


## ---------------------------------------------------------------- tarif ağacı (LoL'daki gibi kök üstte, parçalar altta)
func _tree_data(key: String, pool: Array, covered: bool, is_root: bool) -> Dictionary:
	var st: String = "need"
	if covered:
		st = "covered"
	elif not is_root and pool.has(key):
		pool.erase(key)
		st = "owned"
	var n: Dictionary = {"key": key, "state": st, "kids": []}
	for comp in IT.recipe(key):
		(n["kids"] as Array).append(_tree_data(str(comp), pool, st == "owned" or st == "covered", false))
	return n


var _tree_fs: int = 24


## Düğüm genişliği = yuva ya da altındaki fiyat/SENDE yazısı (hangisi genişse) - küçük ağaçta yazılar üst üste binmesin.
func _tree_w(n: Dictionary, s: float, gx: float) -> float:
	var own: float = s
	match str(n["state"]):
		"owned":
			own = maxf(s, _tw("SENDE", _tree_fs))
		"need":
			own = maxf(s, _amt_w(int(IT.cost(str(n["key"]))), _tree_fs))
	var kids: Array = n["kids"]
	if kids.is_empty():
		return own
	var w: float = 0.0
	for k: Dictionary in kids:
		w += _tree_w(k, s, gx)
	w += gx * (kids.size() - 1)
	return maxf(own, w)


func _tree_depth(n: Dictionary) -> int:
	var d: int = 0
	for k: Dictionary in n["kids"]:
		d = maxi(d, _tree_depth(k))
	return d + 1


func _tree_view(key: String, s: float, gx: float, gy: float, fs: int = 24) -> Control:
	var pool: Array = OWNED.duplicate()
	var data: Dictionary = _tree_data(key, pool, false, true)
	_tree_fs = fs
	var lh: float = fs + 8.0
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ln := Lines.new()
	host.add_child(ln)
	var w: float = _tree_w(data, s, gx)
	var depth: int = _tree_depth(data)
	host.custom_minimum_size = Vector2(w + 12.0, depth * (s + lh) + (depth - 1) * gy + 6.0)
	ln.size = host.custom_minimum_size
	_tree_place(data, 6.0, 0, host, ln, Vector2.INF, s, gx, gy, lh, fs)
	return host


func _tree_place(n: Dictionary, x0: float, d: int, host: Control, ln: Lines, anchor: Vector2, s: float, gx: float, gy: float, lh: float, fs: int) -> void:
	var w: float = _tree_w(n, s, gx)
	var cx: float = floorf(x0 + w * 0.5)
	var y: float = 6.0 + d * (s + lh + gy)
	var key: String = n["key"]
	var st: String = n["state"]
	var tile := _itile(key, s, {"dim": st == "covered", "owned": st == "owned", "stock": STOCK.has(key) and st == "need" and d > 0})
	tile.position = Vector2(cx - s * 0.5, y)
	host.add_child(tile)
	var pl: Control
	var pw: float = 0.0
	if st == "owned":
		pl = _lbl("SENDE", fs, _c("good"))
		pw = _tw("SENDE", fs)
	elif st == "covered":
		pl = _sp()
	else:
		pl = _amt(int(IT.cost(key)), fs, _c("price"))
		pw = _amt_w(int(IT.cost(key)), fs)
	pl.position = Vector2(floorf(cx - pw * 0.5), y + s + 2.0)
	host.add_child(pl)
	if anchor != Vector2.INF:
		var midy: float = floorf((anchor.y + y) * 0.5)
		var col: Color = _c("good") if st == "owned" else (_c("line") if st == "covered" else _c("line_hi"))
		ln.segs.append([PackedVector2Array([anchor, Vector2(anchor.x, midy), Vector2(cx, midy), Vector2(cx, y)]), col, 3.0])
	var kids: Array = n["kids"]
	var kw: float = 0.0
	for k: Dictionary in kids:
		kw += _tree_w(k, s, gx)
	kw += gx * maxi(0, kids.size() - 1)
	var xs: float = x0 + (w - kw) * 0.5
	for k: Dictionary in kids:
		_tree_place(k, xs, d + 1, host, ln, Vector2(cx, y + s + lh - 2.0), s, gx, gy, lh, fs)
		xs += _tree_w(k, s, gx) + gx


## ---------------------------------------------------------------- ortak satıcı parçaları
func _m_header(fs_title: int = 48, por_box: float = 96.0, reroll: bool = true, close: bool = true) -> HBoxContainer:
	var h := _h(16)
	var por := _box(_c("inset"), _c("line_hi"), 2.0)
	por.add_child(_icon(_npc_tex("seyyar"), por_box))
	h.add_child(por)
	var v := _v(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_lbl("SEYYAR SATICI", fs_title, _c("accent")))
	var t := _h(10)
	t.add_child(_lbl("Ayrılmasına", 24, _c("dim")))
	t.add_child(_lbl("2:14", 24, _c("text")))
	t.add_child(Bar.new(VISIT_LEFT / VISIT_TOTAL, _c("accent"), _c("inset"), 10, 150))
	v.add_child(t)
	h.add_child(v)
	h.add_child(_sp(0, 0, true))
	if reroll:
		var rb := _reroll_btn()
		rb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(rb)
	var gc := _chip("gold", GOLD, "Altın")
	gc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(gc)
	if close:
		var cb := _close_btn()
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cb)
	return h


## Alt envanter şeridi (LoL'un alt çubuğu): kademe başına sahip olunan eşyalar + boş yuvalar + SAT.
func _inv_bar(s: float = 56.0, show_sell: bool = true) -> PanelContainer:
	var p := _box(_c("inset"), _c("line"), 12.0)
	var h := _h(22)
	p.add_child(h)
	var cap := _v(0)
	cap.alignment = BoxContainer.ALIGNMENT_CENTER
	cap.add_child(_lbl("ÇANTAN", 32, _c("text")))
	cap.add_child(_lbl("tıkla: sat", 24, _c("dim")))
	h.add_child(cap)
	for grp: Array in [[1, PART_SLOTS, 4], [2, 10, 2], [3, 5, 5]]:
		var k: int = grp[0]
		var mine: Array = OWNED.filter(func(x: String) -> bool: return int(IT.kademe(x)) == k)
		var v := _v(4)
		v.add_child(_lbl("%s %d/%d" % [TIER_NAME[k - 1], mine.size(), int(grp[1])], 24, TIER_COL[k - 1]))
		var row := _h(6)
		for key: String in mine:
			row.add_child(_itile(key, s))
		for e in range(maxi(0, int(grp[2]) - mine.size())):
			row.add_child(_empty_slot(s))
		v.add_child(row)
		h.add_child(v)
	h.add_child(_sp(0, 0, true))
	if show_sell:
		var sv := _v(4)
		sv.alignment = BoxContainer.ALIGNMENT_CENTER
		sv.add_child(_btn("SAT", "off", 32, 56, 150))
		sv.add_child(_lbl("fiyatın %50'si", 24, _c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
		h.add_child(sv)
	return p


## Stok hücresi: yuva + (ad) + fiyat.
func _stock_cell(key: String, s: float, w: float, o: Dictionary = {}, with_name: bool = true) -> VBoxContainer:
	var v := _v(4)
	v.custom_minimum_size.x = w
	var st: String = _state(key)
	var opts: Dictionary = o.duplicate()
	opts["sold"] = st == "sold"
	opts["sel"] = key == SEL_ITEM
	v.add_child(_center(_itile(key, s, opts)))
	if with_name:
		v.add_child(_clip(str(IT.item_name(key)), 24, _c("text") if st != "sold" else _c("dim"), w, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_price_cell(key, 24))
	return v


func _stock_of(k: int) -> Array:
	return STOCK.filter(func(x: String) -> bool: return int(IT.kademe(x)) == k)


## Seçili eşyanın başlığı: yuva + ad + kademe ............ ödenecek / tam fiyat
func _item_head(key: String, s: float = 72.0, fs: int = 40) -> HBoxContainer:
	var h := _h(16)
	var k: int = int(IT.kademe(key))
	h.add_child(_itile(key, s))
	var v := _v(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_lbl(str(IT.item_name(key)), fs, TIER_COL[k - 1].lightened(0.25)))
	v.add_child(_lbl(TIER_NAME[k - 1], 24, TIER_COL[k - 1]))
	h.add_child(v)
	h.add_child(_sp(0, 0, true))
	var pv := _v(0)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	var pl: Dictionary = _plan(key)
	var pr := _h(8)
	pr.alignment = BoxContainer.ALIGNMENT_END
	pr.add_child(_amt(int(pl["cost"]), 40, _c("good") if int(pl["cost"]) < int(pl["full"]) else _c("price")))
	pv.add_child(pr)
	if int(pl["cost"]) < int(pl["full"]):
		var fr := _h(6)
		fr.alignment = BoxContainer.ALIGNMENT_END
		fr.add_child(_lbl("tam fiyat", 24, _c("dim")))
		fr.add_child(_strike(str(pl["full"]), 24, _c("dim")))
		pv.add_child(fr)
	h.add_child(pv)
	return h


func _consume_note(key: String, w: float) -> Label:
	var names: Array = []
	for c: String in _consumed(key):
		names.append(str(IT.item_name(c)))
	return _wrap("Tüketilir: " + ", ".join(names), 24, _c("dim"), w)


## ================================================================ SATICI A - Klasik Pazar (LoL)
## Solda stat filtre sütunu, ortada kademe kademe stok (4+4+4), sağda seçilenin tarif ağacı + statlar + SATIN AL, altta çanta.
func _design_sa() -> Control:
	var r := _root(0.62)
	var col := _window(r, Vector2(150, 44), Vector2(1620, 992))
	col.add_child(_m_header())
	col.add_child(_hline())
	var body := _h(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	## filtreler
	var fb := _box(_c("inset"), _c("line"), 8.0)
	var fv := _v(6)
	fb.add_child(fv)
	var all := _btn("TÜMÜ", "tab_on", 24, 40, 64)
	fv.add_child(all)
	for s: String in FILTERS:
		var b := _box(_c("panel2"), _c("line"), 0.0, 2, 4)
		b.custom_minimum_size = Vector2(64, 44)
		b.add_child(_center(_icon(_stat_tex(s), 24)))
		fv.add_child(b)
	body.add_child(fb)
	## stok
	var sv := _v(10)
	for k in [1, 2, 3]:
		var sh := _h(10)
		var bar := ColorRect.new()
		bar.color = TIER_COL[k - 1]
		bar.custom_minimum_size = Vector2(6, 26)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sh.add_child(bar)
		sh.add_child(_lbl(["PARÇALAR", "EPİK EŞYALAR", "EFSANEVİ EŞYALAR"][k - 1], 32, TIER_COL[k - 1].lightened(0.2)))
		sv.add_child(sh)
		var row := _h(14)
		for key: String in _stock_of(k):
			row.add_child(_stock_cell(key, 96.0, 160.0))
		sv.add_child(row)
	sv.add_child(_sp(0, 0, false, true))
	var hint := _h(8)
	hint.add_child(_glyph(G_DIAMOND, _c("price"), 2))
	hint.add_child(_lbl("Her eşyadan ziyaret başına 1 tane · yeşil fiyat = sendeki parçalar düşüldü", 24, _c("dim")))
	sv.add_child(hint)
	body.add_child(sv)
	## ayrıntı
	var db := _box(_c("panel2"), _c("line"), 18.0)
	db.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dv := _v(10)
	db.add_child(dv)
	dv.add_child(_item_head(SEL_ITEM))
	dv.add_child(_hline())
	dv.add_child(_lbl("TARİF", 24, _c("dim")))
	dv.add_child(_center(_tree_view(SEL_ITEM, 72.0, 12.0, 10.0)))
	dv.add_child(_hline())
	dv.add_child(_stat_grid(SEL_ITEM))
	dv.add_child(_passive_box(SEL_ITEM, 560.0))
	dv.add_child(_sp(0, 0, false, true))
	var br := _h(14)
	br.add_child(_expand(_consume_note(SEL_ITEM, 250.0)))
	br.add_child(_cost_btn("SATIN AL", int(_plan(SEL_ITEM)["cost"]), -1, "primary", 32, 64, 300))
	dv.add_child(br)
	body.add_child(db)
	col.add_child(_inv_bar())
	return r


## ================================================================ SATICI B - Tarif Atölyesi
## Üstte tek sıra stok rafı (kademe aralıklı), ortada BÜYÜK tarif ağacı + fiyat hesabı, sağda eşya kartı, altta çanta.
func _design_sb() -> Control:
	var r := _root(0.62)
	var col := _window(r, Vector2(150, 40), Vector2(1620, 1000))
	col.add_child(_m_header())
	## raf
	var shelf := _box(_c("inset"), _c("line"), 12.0)
	var sh := _h(14)
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	shelf.add_child(sh)
	for k in [1, 2, 3]:
		if k > 1:
			sh.add_child(_vline(_c("line_hi")))
		var gv := _v(6)
		gv.add_child(_lbl(TIER_NAME[k - 1], 24, TIER_COL[k - 1]))
		var gr := _h(12)
		for key: String in _stock_of(k):
			gr.add_child(_stock_cell(key, 72.0, 104.0, {}, false))
		gv.add_child(gr)
		sh.add_child(gv)
	col.add_child(shelf)
	var body := _h(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	## ağaç
	var tb := _box(_c("panel2"), _c("line"), 18.0)
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tv := _v(12)
	tb.add_child(tv)
	var th := _h(18)
	th.add_child(_lbl("TARİF AĞACI", 32, _c("accent")))
	th.add_child(_sp(0, 0, true))
	for lg: Array in [["owned", "sende"], ["stock", "bugün stokta"], ["need", "tarifle birlikte alınır"]]:
		var lh := _h(8)
		if lg[0] == "owned":
			var b := _box(_c("good"), _c("good").darkened(0.6), 2.0, 2, 3)
			b.add_child(_glyph(G_CHECK, Color("#10200c"), 2))
			lh.add_child(b)
		elif lg[0] == "stock":
			lh.add_child(_glyph(G_DIAMOND, _c("price"), 3))
		else:
			lh.add_child(_empty_slot(18))
		lh.add_child(_lbl(str(lg[1]), 24, _c("dim")))
		th.add_child(lh)
	tv.add_child(th)
	tv.add_child(_sp(0, 0, false, true))
	tv.add_child(_center(_tree_view(SEL_ITEM, 96.0, 22.0, 18.0, 24)))
	tv.add_child(_sp(0, 0, false, true))
	## fiyat hesabı: tam - sendekiler = ödeyeceğin
	var pl: Dictionary = _plan(SEL_ITEM)
	var mb := _box(_c("inset"), _c("line"), 12.0)
	var mh := _h(20)
	mh.alignment = BoxContainer.ALIGNMENT_CENTER
	mb.add_child(mh)
	var parts: Array = [["Tam fiyat", int(pl["full"]), _c("text")], ["-"], ["Sendeki parçalar", int(pl["full"]) - int(pl["cost"]), _c("good")], ["="], ["Ödeyeceğin", int(pl["cost"]), _c("price")]]
	for p: Array in parts:
		if p.size() == 1:
			mh.add_child(_glyph(G_MINUS if p[0] == "-" else G_EQ, _c("dim"), 4))
			continue
		var pv := _v(0)
		pv.add_child(_lbl(str(p[0]), 24, _c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
		var a := _amt(int(p[1]), 40, p[2])
		a.alignment = BoxContainer.ALIGNMENT_CENTER
		pv.add_child(a)
		mh.add_child(pv)
	tv.add_child(mb)
	body.add_child(tb)
	## kart
	var cb := _box(_c("panel2"), _c("line"), 18.0)
	cb.custom_minimum_size.x = 520
	var cv := _v(12)
	cb.add_child(cv)
	cv.add_child(_item_head(SEL_ITEM, 72.0, 32))
	cv.add_child(_hline())
	cv.add_child(_stat_grid(SEL_ITEM, 1, 32))
	cv.add_child(_passive_box(SEL_ITEM, 470.0, 24))
	cv.add_child(_sp(0, 0, false, true))
	cv.add_child(_lbl("TÜKETİLECEK PARÇALAR", 24, _c("dim")))
	var cr := _h(10)
	for c: String in _consumed(SEL_ITEM):
		cr.add_child(_itile(c, 56.0, {"owned": true}))
	cv.add_child(cr)
	cv.add_child(_cost_btn("SATIN AL", int(pl["cost"]), -1, "primary", 32, 68, 0))
	body.add_child(cb)
	col.add_child(_inv_bar(48.0))
	return r


## ================================================================ SATICI C - Öneri Rafı
## LoL'un "Önerilen" sekmesi gibi: parçalarınla tamamlayabileceklerin (en çok indirim), sıradaki hedef, bütçene uyanlar;
## sağda DURUMUN: seçili eşyayı alırsan statlarının NET değişimi (tüketilen parçalar düşülerek).
func _design_sc() -> Control:
	var r := _root(0.62)
	var col := _window(r, Vector2(150, 44), Vector2(1620, 992))
	col.add_child(_m_header())
	col.add_child(_tabs(["ÖNERİLEN", "TÜM STOK", "ÇANTAM"], 0))
	var body := _h(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var left := _v(16)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	## parçalarınla tamamla
	left.add_child(_section("PARÇALARINLA TAMAMLA", "sendeki parçalar fiyattan düşer"))
	var combos: Array = []
	for key: String in STOCK:
		var pl: Dictionary = _plan(key)
		if _state(key) == "can" and int(pl["cost"]) < int(pl["full"]):
			combos.append([key, int(pl["full"]) - int(pl["cost"])])
	combos.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var cr := _h(14)
	for c: Array in combos.slice(0, 4):
		cr.add_child(_rec_card(str(c[0]), 246.0, int(c[1])))
	left.add_child(cr)
	## sıradaki hedef
	left.add_child(_section("SIRADAKİ HEDEF", "biraz daha altınla alabileceğin"))
	var gb := _box(_c("panel2"), _c("line"), 14.0)
	var gh := _h(18)
	gb.add_child(gh)
	gh.add_child(_itile(GOAL_ITEM, 88.0))
	var gv := _v(6)
	gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gcost: int = int(_plan(GOAL_ITEM)["cost"])
	var gt := _h(14)
	gt.add_child(_lbl(str(IT.item_name(GOAL_ITEM)), 32, TIER_COL[2].lightened(0.25)))
	gt.add_child(_lbl("%d altın eksik" % (gcost - GOLD), 24, _c("bad")))
	gv.add_child(gt)
	var bh := _h(12)
	bh.add_child(_expand(Bar.new(float(GOLD) / float(gcost), _c("price"), _c("inset"), 16)))
	bh.add_child(_lbl("%d / %d" % [GOLD, gcost], 24, _c("dim")))
	gv.add_child(bh)
	var ph := _h(8)
	ph.add_child(_lbl("Parçaları:", 24, _c("dim")))
	var pool: Array = OWNED.duplicate()
	for comp in IT.recipe(GOAL_ITEM):
		var have: bool = pool.has(str(comp))
		if have:
			pool.erase(str(comp))
		ph.add_child(_itile(str(comp), 40.0, {"owned": have}))
	gv.add_child(ph)
	gh.add_child(gv)
	left.add_child(gb)
	## bütçene uygun
	left.add_child(_section("BÜTÇENE UYGUN", "şu an alabileceklerin"))
	var br := _h(14)
	for key: String in STOCK:
		if _state(key) == "can" and int(_plan(key)["cost"]) >= int(_plan(key)["full"]):
			br.add_child(_stock_cell(key, 72.0, 118.0, {}, false))
	left.add_child(br)
	left.add_child(_sp(0, 0, false, true))
	## durumun
	var sb := _box(_c("panel2"), _c("line"), 18.0)
	sb.custom_minimum_size.x = 500
	var sv := _v(10)
	sb.add_child(sv)
	sv.add_child(_item_head(SEL_ITEM, 64.0, 32))
	sv.add_child(_hline())
	var dh := _h(10)
	dh.add_child(_lbl("DURUMUN", 32, _c("accent")))
	dh.add_child(_lbl("alırsan (parçalar düşülerek)", 24, _c("dim")))
	sv.add_child(dh)
	var delta: Dictionary = _net_delta(SEL_ITEM)
	for s: String in FAKE_STATS:
		var cur: float = float(FAKE_STATS[s])
		var dv: float = float(delta.get(s, 0.0))
		var row := _h(10)
		row.add_child(_icon(_stat_tex(s), 24))
		row.add_child(_expand(_lbl(_sname(s), 24, _c("text") if absf(dv) > 0.0001 else _c("dim"))))
		row.add_child(_lbl(_fmt_stat(s, cur, false), 24, _c("dim")))
		if absf(dv) > 0.0001:
			row.add_child(_glyph(G_ARROW, _c("dim"), 2))
			row.add_child(_lbl(_fmt_stat(s, cur + dv, false), 24, _c("good") if dv > 0 else _c("bad")))
			row.add_child(_lbl("(%s)" % _fmt_stat(s, dv), 24, _c("good") if dv > 0 else _c("bad")))
		sv.add_child(row)
	sv.add_child(_hline())
	sv.add_child(_passive_box(SEL_ITEM, 450.0))
	sv.add_child(_sp(0, 0, false, true))
	sv.add_child(_consume_note(SEL_ITEM, 450.0))
	sv.add_child(_cost_btn("SATIN AL", int(_plan(SEL_ITEM)["cost"]), -1, "primary", 32, 68, 0))
	body.add_child(sb)
	return r


func _rec_card(key: String, w: float, save: int) -> PanelContainer:
	var sel: bool = key == SEL_ITEM
	var p := _box(_c("panel3") if sel else _c("panel2"), _c("accent") if sel else _c("line"), 12.0)
	p.custom_minimum_size.x = w
	var v := _v(6)
	p.add_child(v)
	var top := _h(8)
	top.add_child(_itile(key, 72.0))
	var tv := _v(0)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	var badge := _box(_c("good").darkened(0.55), _c("good"), 4.0, 2, 3)
	badge.add_child(_lbl("-%d" % save, 24, _c("good")))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tv.add_child(badge)
	tv.add_child(_lbl(TIER_NAME[int(IT.kademe(key)) - 1], 24, TIER_COL[int(IT.kademe(key)) - 1]))
	top.add_child(tv)
	v.add_child(top)
	v.add_child(_clip(str(IT.item_name(key)), 32, _c("text"), w - 24.0))
	var cost: int = int(_plan(key)["cost"])
	if cost == 0:
		var fh := _h(8)
		fh.add_child(_lbl("BEDAVA BİRLEŞTİR", 24, _c("good")))
		v.add_child(fh)
	else:
		v.add_child(_price_cell(key, 24, false))
	return p


## ================================================================ SATICI D - Yan Çanta
## Ekranın soluna yaslı dar panel (oyun sağda görünür kalır - dükkan oyunu durdurmuyor): stat filtre çipleri, kademe satırları,
## altta seçilenin küçük tarif ağacı + statları + SATIN AL, en altta çanta.
func _design_sd() -> Control:
	var r := _root(0.12)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, 0.5)
	shade.position = Vector2.ZERO
	shade.size = Vector2(720, 1080)
	r.add_child(shade)
	var col := _window(r, Vector2(24, 16), Vector2(668, 1048), Vector4(20, 14, 20, 14))
	col.add_theme_constant_override("separation", 10)
	col.add_child(_m_header(40, 64.0, false, true))
	var fr := _h(8)
	for i in 8:
		var s: String = FILTERS[i]
		var on: bool = i == 0
		var b := _box(_c("panel3") if on else _c("inset"), _c("accent") if on else _c("line"), 0.0, 3 if on else 2, 4)
		b.custom_minimum_size = Vector2(52, 48)
		b.add_child(_center(_icon(_stat_tex(s), 24)))
		fr.add_child(b)
	fr.add_child(_sp(0, 0, true))
	var rb := _reroll_btn(24)
	rb.custom_minimum_size.y = 48
	fr.add_child(rb)
	col.add_child(fr)
	var fl := _h(8)
	fl.add_child(_lbl("Filtre:", 24, _c("dim")))
	fl.add_child(_lbl("Saldırı Gücü", 24, _c("accent")))
	fl.add_child(_lbl("· filtreye uymayanlar soluk", 24, _c("dim")))
	col.add_child(fl)
	var grid := _box(_c("inset"), _c("line"), 10.0)
	var gv := _v(10)
	grid.add_child(gv)
	for k in [1, 2, 3]:
		var row := _h(10)
		var tag := _box(TIER_COL[k - 1].darkened(0.6), TIER_COL[k - 1], 0.0, 2, 3)
		tag.custom_minimum_size = Vector2(30, 108)
		var tl := _lbl(["P", "E", "F"][k - 1], 32, TIER_COL[k - 1].lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
		tag.add_child(tl)
		row.add_child(tag)
		for key: String in _stock_of(k):
			row.add_child(_stock_cell(key, 80.0, 132.0, {"dim": not _has_stat(key, FILTERS[0])}, false))
		gv.add_child(row)
	col.add_child(grid)
	## ayrıntı
	var db := _box(_c("panel2"), _c("line"), 14.0)
	db.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dv := _v(8)
	db.add_child(dv)
	dv.add_child(_item_head(SEL_ITEM, 64.0, 32))
	var dh := _h(14)
	dh.add_child(_tree_view(SEL_ITEM, 40.0, 8.0, 2.0, 24))
	var st := _v(4)
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(_stat_grid(SEL_ITEM, 1))
	st.add_child(_passive_box(SEL_ITEM, 250.0))
	dh.add_child(st)
	dv.add_child(dh)
	dv.add_child(_sp(0, 0, false, true))
	dv.add_child(_cost_btn("SATIN AL", int(_plan(SEL_ITEM)["cost"]), -1, "primary", 32, 56, 0))
	col.add_child(db)
	## çanta (kompakt)
	var ib := _box(_c("inset"), _c("line"), 8.0)
	var ih := _h(6)
	ib.add_child(ih)
	ih.add_child(_lbl("ÇANTA", 24, _c("dim")))
	for key: String in OWNED:
		ih.add_child(_itile(key, 44.0))
	for e in 4:
		ih.add_child(_empty_slot(44))
	ih.add_child(_sp(0, 0, true))
	ih.add_child(_btn("SAT", "off", 24, 44, 90))
	col.add_child(ib)
	return r


## ================================================================ ortak demirci parçaları
func _d_header(active: int = 1, close: bool = true) -> HBoxContainer:
	var h := _h(16)
	var plq := _box(_c("inset"), _c("line_hi"), 10.0)
	var ph := _h(12)
	ph.add_child(_glyph(G_HAMMER, _c("accent"), 4))
	ph.add_child(_lbl("DEMİRCİ", 48, _c("accent")))
	plq.add_child(ph)
	h.add_child(plq)
	var tabs := _tabs(["SİLAH AL", "GELİŞTİR", "MANA KALKANI"], active)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tabs)
	h.add_child(_sp(0, 0, true))
	var c1 := _chip("shard", SHARDS, "Parçacık")
	c1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(c1)
	var c2 := _chip("gold", GOLD, "Altın")
	c2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(c2)
	if close:
		var cb := _close_btn()
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(cb)
	return h


## Silah kartı: kontürlü ikon + ad + özellik adı + ustalık çubuğu.
func _w_card(i: int, w: float, sel: bool, icon_box: float = 80.0) -> PanelContainer:
	var p := _box(_c("panel3") if sel else _c("panel2"), _c("accent") if sel else _c("line"), 12.0)
	p.custom_minimum_size.x = w
	var h := _h(14)
	p.add_child(h)
	h.add_child(_wicon(_wkey(i), icon_box, _wtier(i)))
	var v := _v(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nh := _h(10)
	nh.add_child(_lbl(_wname(i), 32, _c("text")))
	nh.add_child(_lbl(ROMAN[_wtier(i) - 1], 24, _tier_color(_wtier(i))))
	v.add_child(nh)
	v.add_child(_lbl(str(_wdef(i).get("name", "")), 24, _c("dim")))
	var ph := _h(8)
	ph.add_child(_wpips(i, 120.0))
	var n_up: int = _wups(i).size()
	ph.add_child(_lbl("FİNAL HAZIR" if n_up >= 4 and not bool(WEAPONS[i]["final"]) else "%d/4" % n_up, 24, _c("accent") if n_up >= 4 else _c("dim")))
	v.add_child(ph)
	h.add_child(v)
	return p


## Geliştirme rozeti: Roma rakamı (final = taç), duruma göre renk.
func _up_badge(i: int, idx: int, s: float, sel: bool = false) -> PanelContainer:
	var st: String = _row_state(i, idx)
	var final_up: bool = bool((_wrows(i)[idx] as Dictionary)["final"])
	var fill: Color = _c("panel2")
	var bd: Color = _c("line_hi")
	var tc: Color = _c("text")
	match st:
		"taken":
			fill = _c("good").darkened(0.62)
			bd = _c("good")
			tc = _c("good")
		"locked":
			fill = _c("inset")
			bd = _c("line")
			tc = _c("dim")
	if sel:
		fill = _c("accent")
		bd = _c("accent").lightened(0.3)
		tc = _c("accent_text")
	if final_up and st != "locked" and not sel:
		bd = ENCH_COL[5]
	var p := _box(fill, bd, 0.0, 3, 6)
	p.custom_minimum_size = Vector2(s, s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var px: int = maxi(2, int(s / 18.0))
	if final_up:
		p.add_child(_center(_glyph(G_LOCK if st == "locked" else G_CROWN, tc, px)))
	elif st == "taken" and not sel:
		p.add_child(_center(_glyph(G_CHECK, tc, px)))
	else:
		var l := _lbl(ROMAN[idx], int(clampf(roundf(s * 0.5 / 8.0) * 8.0, 24.0, 48.0)), tc, HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		p.add_child(l)
	return p


## Durum etiketi / fiyat (satırların sağı).
func _up_state(i: int, idx: int, fs: int = 24) -> HBoxContainer:
	var h := _h(10)
	h.alignment = BoxContainer.ALIGNMENT_END
	match _row_state(i, idx):
		"taken":
			h.add_child(_glyph(G_CHECK, _c("good"), 3))
			h.add_child(_lbl("ALINDI", fs, _c("good")))
		"locked":
			h.add_child(_glyph(G_LOCK, _c("dim"), 3))
			h.add_child(_lbl("%d/4 gerekli" % _wups(i).size(), fs, _c("dim")))
		_:
			var cost: Vector2i = _up_cost(i, idx)
			h.add_child(_amt(cost.x, fs, _c("price")))
			h.add_child(_amt(cost.y, fs, Color("#a8d8f0"), "shard"))
	return h


func _mat_row(kind: String, cap: String, need: int, have: int, fs: int = 32) -> PanelContainer:
	var p := _box(_c("inset"), _c("line"), 10.0)
	var h := _h(12)
	p.add_child(h)
	h.add_child(_coin(32) if kind == "gold" else _shard_ic(32))
	h.add_child(_expand(_lbl(cap, fs, _c("text"))))
	var ok: bool = have >= need
	h.add_child(_lbl(str(need), fs, _c("price") if ok else _c("bad")))
	h.add_child(_lbl("/ %d" % have, 24, _c("dim")))
	h.add_child(_glyph(G_CHECK if ok else G_X, _c("good") if ok else _c("bad"), 3))
	return p


## Kademe değişimi: [III mavi] -> [IV mor]
func _tier_change(i: int, fs: int = 24) -> HBoxContainer:
	var h := _h(10)
	var t0: int = _wtier(i)
	var t1: int = mini(4, t0 + 1)
	h.add_child(_lbl("Kademe", fs, _c("dim")))
	for t in [t0, t1]:
		var b := _box(Color(_tier_color(t), 0.18), _tier_color(t), 4.0, 2, 3)
		b.add_child(_lbl(" %s " % ROMAN[t - 1], fs, _tier_color(t)))
		h.add_child(b)
		if t == t0:
			h.add_child(_glyph(G_ARROW, _c("dim"), 3))
	h.add_child(_lbl("kontür %s" % ["", "", "yeşil", "mavi", "mor", "kırmızı"][t1], fs, _c("dim")))
	return h


## ================================================================ DEMİRCİ A - Örs Vitrini
## Solda silahların (kart + ustalık çubuğu), ortada seçili silahın vitrini + ustalık yolu, sağda geliştirme listesi
## (seçili satır açık) + GEREKENLER (sende / gereken) + büyük GELİŞTİR.
func _design_da() -> Control:
	var r := _root(0.62)
	var col := _window(r, Vector2(150, 70), Vector2(1620, 940))
	col.add_child(_d_header())
	col.add_child(_hline())
	var body := _h(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	## silahlar
	var lv := _v(10)
	lv.custom_minimum_size.x = 380
	lv.add_child(_section("SİLAHLARIN", "3/3"))
	for i in WEAPONS.size():
		lv.add_child(_w_card(i, 380.0, i == SEL_W))
	lv.add_child(_sp(0, 0, false, true))
	var tip := _box(_c("inset"), _c("line"), 12.0)
	tip.add_child(_wrap("Her silah kendi özelliğiyle gelir. 4 geliştirmeyi istediğin sırayla al, hepsi bitince FİNAL açılır.", 24, _c("dim"), 350.0))
	lv.add_child(tip)
	body.add_child(lv)
	## vitrin
	var cv := _v(12)
	cv.custom_minimum_size.x = 520
	var vit := _box(_c("inset"), _c("line"), 0.0)
	vit.custom_minimum_size = Vector2(520, 400)
	var spot := Spot.new(_c("spot"), 0.82)
	vit.add_child(spot)
	var wc := _center(_wicon(_wkey(SEL_W), 260.0, _wtier(SEL_W)))
	vit.add_child(wc)
	var corner := MarginContainer.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top"]:
		corner.add_theme_constant_override("margin_" + side, 14)
	var tb := _box(Color(_tier_color(_wtier(SEL_W)), 0.18), _tier_color(_wtier(SEL_W)), 6.0, 2, 3)
	tb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tb.add_child(_lbl("KADEME %s" % ROMAN[_wtier(SEL_W) - 1], 24, _tier_color(_wtier(SEL_W))))
	corner.add_child(tb)
	vit.add_child(corner)
	cv.add_child(vit)
	var nh := _h(14)
	nh.add_child(_lbl(_wname(SEL_W).to_upper(), 48, _c("text")))
	nh.add_child(_lbl(str(_wdef(SEL_W).get("name", "")), 32, _c("accent")))
	cv.add_child(nh)
	cv.add_child(_wrap(str((_wdef(SEL_W)["base"] as Dictionary)["text"]), 24, _c("dim"), 520.0))
	cv.add_child(_sp(0, 0, false, true))
	cv.add_child(_lbl("USTALIK YOLU", 24, _c("dim")))
	var track := _h(0)
	track.alignment = BoxContainer.ALIGNMENT_CENTER
	var base := _box(_c("panel3"), _c("line_hi"), 0.0, 3, 6)
	base.custom_minimum_size = Vector2(52, 52)
	base.add_child(_center(_glyph(G_DIAMOND, _c("text"), 4)))
	track.add_child(base)
	var rows: Array = _wrows(SEL_W)
	for idx in rows.size():
		var bar := ColorRect.new()
		var done: bool = _row_state(SEL_W, idx) == "taken"
		bar.color = _c("good") if done else _c("line")
		bar.custom_minimum_size = Vector2(36, 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		track.add_child(bar)
		track.add_child(_up_badge(SEL_W, idx, 64.0 if bool((rows[idx] as Dictionary)["final"]) else 52.0, idx == SEL_UP))
	cv.add_child(track)
	body.add_child(cv)
	## geliştirmeler + malzeme
	var rv := _v(8)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv.add_child(_section("GELİŞTİRMELER", "%d/4 · sıra serbest" % _wups(SEL_W).size()))
	for idx in rows.size():
		var rd: Dictionary = rows[idx]
		var sel: bool = idx == SEL_UP
		var rp := _box(_c("panel3") if sel else _c("panel2"), _c("accent") if sel else _c("line"), 10.0)
		var rh := _h(14)
		rp.add_child(rh)
		rh.add_child(_up_badge(SEL_W, idx, 48.0, sel))
		var tv := _v(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := _h(10)
		nm.add_child(_lbl(str(rd["name"]), 32, _c("text") if _row_state(SEL_W, idx) != "locked" else _c("dim")))
		if bool(rd["final"]):
			nm.add_child(_lbl("FİNAL", 24, ENCH_COL[5]))
		tv.add_child(nm)
		if sel:
			tv.add_child(_wrap(str(rd["text"]), 24, _c("text"), 360.0))
		rh.add_child(tv)
		rh.add_child(_up_state(SEL_W, idx))
		rv.add_child(rp)
	rv.add_child(_sp(0, 0, false, true))
	rv.add_child(_lbl("GEREKENLER", 24, _c("dim")))
	var cost: Vector2i = _up_cost(SEL_W, SEL_UP)
	rv.add_child(_mat_row("shard", "Silah Parçacığı", cost.y, SHARDS))
	rv.add_child(_mat_row("gold", "Altın", cost.x, GOLD))
	rv.add_child(_tier_change(SEL_W))
	rv.add_child(_cost_btn("GELİŞTİR", -1, -1, "primary", 40, 76, 0, G_HAMMER))
	body.add_child(rv)
	return r


## ================================================================ DEMİRCİ B - Ustalık Ağacı
## Tam ekran: üstte silah sekmeleri, ortada yetenek ağacı (kök = silahın temel özelliği -> 4 geliştirme -> FİNAL),
## sağda seçili düğümün ayrıntısı + malzeme + GELİŞTİR.
func _design_db() -> Control:
	var r := _root(0.72)
	## üst şerit
	var top := _h(16)
	top.position = Vector2(40, 28)
	top.custom_minimum_size = Vector2(1840, 72)
	var hdr := _d_header(1, true)
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hdr)
	r.add_child(top)
	## silah sekmeleri
	var wt := _h(14)
	wt.position = Vector2(40, 124)
	for i in WEAPONS.size():
		wt.add_child(_w_card(i, 380.0, i == SEL_W, 64.0))
	var add := _box(_c("inset"), _c("line"), 12.0)
	add.custom_minimum_size = Vector2(160, 0)
	var av := _v(0)
	av.alignment = BoxContainer.ALIGNMENT_CENTER
	av.add_child(_center(_glyph(G_PLUS, _c("dim"), 4)))
	av.add_child(_lbl("yuva dolu", 24, _c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	add.add_child(av)
	wt.add_child(add)
	r.add_child(wt)
	## ağaç tuvali
	var cv := _box(Color(_c("panel"), 0.94), _c("line"), 0.0)
	cv.position = Vector2(40, 262)
	cv.custom_minimum_size = Vector2(1300, 790)
	r.add_child(cv)
	var canvas := Control.new()
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(canvas)
	var ln := Lines.new()
	ln.size = Vector2(1300, 790)
	canvas.add_child(ln)
	var rows: Array = _wrows(SEL_W)
	var root_c := Vector2(250, 360)
	var fin_c := Vector2(1080, 360)
	var ys: Array = [110.0, 280.0, 450.0, 620.0]
	## çizgiler
	for idx in 4:
		var nc := Vector2(665, float(ys[idx]))
		var done: bool = _row_state(SEL_W, idx) == "taken"
		var lc: Color = _c("accent") if done else _c("line_hi")
		var lw: float = 6.0 if done else 3.0
		ln.segs.append([_bez(root_c + Vector2(90, 0), nc - Vector2(56, 0)), lc, lw])
		ln.segs.append([_bez(nc + Vector2(56, 0), fin_c - Vector2(82, 0)), _c("line_hi") if done else _c("line"), 3.0])
	## kök
	var rn := _wicon(_wkey(SEL_W), 160.0, _wtier(SEL_W))
	var rbg := _box(_c("inset"), _tier_color(_wtier(SEL_W)), 0.0, 3, 10)
	rbg.custom_minimum_size = Vector2(180, 180)
	rbg.position = root_c - Vector2(90, 90)
	rbg.add_child(_center(rn))
	canvas.add_child(rbg)
	_place_label(canvas, "TEMEL ÖZELLİK", 24, _c("dim"), root_c + Vector2(0, -126), 340.0)
	_place_label(canvas, str(_wdef(SEL_W).get("name", "")).to_upper(), 32, _c("accent"), root_c + Vector2(0, 112), 340.0)
	var bt := _wrap(str((_wdef(SEL_W)["base"] as Dictionary)["text"]), 24, _c("dim"), 360.0, HORIZONTAL_ALIGNMENT_CENTER)
	bt.position = root_c + Vector2(-180, 146)
	canvas.add_child(bt)
	## geliştirme düğümleri
	for idx in 4:
		var nc := Vector2(665, float(ys[idx]))
		var b := _up_badge(SEL_W, idx, 104.0, idx == SEL_UP)
		b.position = nc - Vector2(52, 52)
		canvas.add_child(b)
		if idx == SEL_UP:
			var ring := Panel.new()
			ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ring.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0), _c("accent"), 3, 10))
			ring.position = nc - Vector2(62, 62)
			ring.size = Vector2(124, 124)
			canvas.add_child(ring)
		var st: String = _row_state(SEL_W, idx)
		_place_label(canvas, str((rows[idx] as Dictionary)["name"]), 24, _c("text") if st != "taken" else _c("good"), nc + Vector2(0, 66), 300.0)
	## final
	var fb := _up_badge(SEL_W, 4, 150.0)
	fb.position = fin_c - Vector2(75, 75)
	canvas.add_child(fb)
	_place_label(canvas, "FİNAL", 24, ENCH_COL[5], fin_c + Vector2(0, -102), 300.0)
	_place_label(canvas, str((rows[4] as Dictionary)["name"]).to_upper(), 32, _c("text"), fin_c + Vector2(0, 94), 300.0)
	_place_label(canvas, "4 geliştirmenin hepsi gerekli (%d/4)" % _wups(SEL_W).size(), 24, _c("dim"), fin_c + Vector2(0, 130), 300.0)
	## sağ ayrıntı
	var dp := _box(_c("panel"), _c("line_hi"), 22.0)
	dp.position = Vector2(1364, 262)
	dp.custom_minimum_size = Vector2(516, 790)
	r.add_child(dp)
	var dv := _v(14)
	dp.add_child(dv)
	var rd: Dictionary = rows[SEL_UP]
	var hh := _h(14)
	hh.add_child(_up_badge(SEL_W, SEL_UP, 72.0, true))
	var hv := _v(0)
	hv.add_child(_lbl("GELİŞTİRME %s" % ROMAN[SEL_UP], 24, _c("dim")))
	hv.add_child(_lbl(str(rd["name"]), 40, _c("text")))
	hh.add_child(hv)
	dv.add_child(hh)
	var stc := _box(_c("good").darkened(0.6), _c("good"), 6.0, 2, 3)
	stc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stc.add_child(_lbl("ALINABİLİR", 24, _c("good")))
	dv.add_child(stc)
	dv.add_child(_hline())
	dv.add_child(_wrap(str(rd["text"]), 32, _c("text"), 460.0))
	dv.add_child(_sp(0, 0, false, true))
	dv.add_child(_tier_change(SEL_W))
	dv.add_child(_lbl("GEREKENLER", 24, _c("dim")))
	var cost: Vector2i = _up_cost(SEL_W, SEL_UP)
	dv.add_child(_mat_row("shard", "Silah Parçacığı", cost.y, SHARDS))
	dv.add_child(_mat_row("gold", "Altın", cost.x, GOLD))
	dv.add_child(_cost_btn("GELİŞTİR", -1, -1, "primary", 40, 80, 0, G_HAMMER))
	dv.add_child(_wrap("Sonraki geliştirme %d altın (her alımda +%d)." % [cost.x + int(LG.WUPGRADE_PRICE_STEP), int(LG.WUPGRADE_PRICE_STEP)], 24, _c("dim"), 460.0))
	return r


func _bez(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c1 := Vector2(lerpf(a.x, b.x, 0.5), a.y)
	var c2 := Vector2(lerpf(a.x, b.x, 0.5), b.y)
	for i in 25:
		var t: float = i / 24.0
		var u: float = 1.0 - t
		pts.append((a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t).floor())
	return pts


func _place_label(host: Control, t: String, fs: int, c: Color, center_top: Vector2, w: float) -> void:
	var l := _wrap(t, fs, c, w, HORIZONTAL_ALIGNMENT_CENTER)
	l.position = Vector2(floorf(center_top.x - w * 0.5), center_top.y)
	host.add_child(l)


## ================================================================ DEMİRCİ C - Usta ile Karşılaştır
## Solda demirci portresi + konuşma balonu (RPG tüccar diyaloğu), sağda silah seçici, geliştirme kontrol listesi ve
## ŞİMDİ / GELİŞTİRİNCE karşılaştırma kartları (değişen değerler yeşil).
func _design_dc() -> Control:
	var r := _root(0.62)
	var col := _window(r, Vector2(150, 60), Vector2(1620, 960))
	var body := _h(22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	## usta
	var np := _box(_c("inset"), _c("line"), 18.0)
	np.custom_minimum_size.x = 400
	var nv := _v(14)
	np.add_child(nv)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(364, 330)
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sp := Spot.new(_c("spot"), 0.86)
	sp.size = Vector2(364, 330)
	stage.add_child(sp)
	var por := _icon_tr(_npc_tex("demirci"), 288.0)
	por.position = Vector2(floorf((364 - por.size.x) * 0.5), 0)
	stage.add_child(por)
	nv.add_child(stage)
	var plate := _box(_c("panel3"), _c("accent_dk"), 8.0)
	plate.add_child(_lbl("USTA DEMİRCİ", 32, _c("accent"), HORIZONTAL_ALIGNMENT_CENTER))
	nv.add_child(plate)
	var bub := _box(_c("panel2"), _c("line_hi"), 14.0)
	bub.add_child(_wrap("\"Bu kılıç rüzgârı iyi taşıyor. Bir kat daha dövelim, savurduğu düşmanlar bir de yavaşlasın!\"", 24, _c("text"), 330.0))
	nv.add_child(bub)
	nv.add_child(_sp(0, 0, false, true))
	nv.add_child(_chip("shard", SHARDS, "Silah Parçacığı"))
	nv.add_child(_chip("gold", GOLD, "Altın"))
	body.add_child(np)
	## sağ
	var mv := _v(14)
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(mv)
	var hh := _h(16)
	hh.add_child(_tabs(["SİLAH AL", "GELİŞTİR", "MANA KALKANI"], 1))
	hh.add_child(_sp(0, 0, true))
	hh.add_child(_close_btn())
	mv.add_child(hh)
	var wr := _h(12)
	for i in WEAPONS.size():
		wr.add_child(_expand(_w_card(i, 0.0, i == SEL_W, 64.0)))
	mv.add_child(wr)
	mv.add_child(_section("GELİŞTİRMELER", "istediğin sırayla"))
	var rows: Array = _wrows(SEL_W)
	for idx in rows.size():
		var rd: Dictionary = rows[idx]
		var sel: bool = idx == SEL_UP
		var rp := _box(_c("panel3") if sel else _c("panel2"), _c("accent") if sel else _c("line"), 8.0)
		var rh := _h(14)
		rp.add_child(rh)
		rh.add_child(_up_badge(SEL_W, idx, 40.0, sel))
		var nm := _lbl(str(rd["name"]), 32, _c("text") if _row_state(SEL_W, idx) != "locked" else _c("dim"))
		nm.custom_minimum_size.x = 250
		rh.add_child(nm)
		rh.add_child(_expand(_clip(str(rd["text"]), 24, _c("dim"), 300.0)))
		var us := _up_state(SEL_W, idx)
		us.custom_minimum_size.x = 170
		rh.add_child(us)
		mv.add_child(rp)
	## karşılaştırma
	var cmp := _h(12)
	cmp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var now: Dictionary = _trait_vals(SEL_W, -1)
	var nxt: Dictionary = _trait_vals(SEL_W, SEL_UP)
	cmp.add_child(_expand(_cmp_card("ŞİMDİ", now, now, false), true, true))
	cmp.add_child(_center(_glyph(G_ARROW, _c("accent"), 5)))
	cmp.add_child(_expand(_cmp_card("%s İLE" % str((rows[SEL_UP] as Dictionary)["name"]).to_upper(), nxt, now, true), true, true))
	mv.add_child(cmp)
	var cost: Vector2i = _up_cost(SEL_W, SEL_UP)
	var bh := _h(14)
	bh.add_child(_tier_change(SEL_W))
	bh.add_child(_sp(0, 0, true))
	bh.add_child(_cost_btn("GELİŞTİR", cost.x, cost.y, "primary", 32, 68, 0, G_HAMMER))
	mv.add_child(bh)
	return r


func _cmp_card(title: String, vals: Dictionary, base: Dictionary, hi: bool) -> PanelContainer:
	var p := _box(_c("panel3") if hi else _c("panel2"), _c("accent") if hi else _c("line"), 14.0)
	var v := _v(6)
	p.add_child(v)
	v.add_child(_lbl(title, 24, _c("accent") if hi else _c("dim")))
	v.add_child(_hline())
	for k: String in TRAIT_STAT:
		if not vals.has(k):
			continue
		var changed: bool = not is_equal_approx(float(vals[k]), float(base.get(k, 0.0)))
		var row := _h(8)
		row.add_child(_expand(_lbl(str(TRAIT_STAT[k]), 24, _c("text") if changed or not hi else _c("dim"))))
		row.add_child(_lbl(_trait_fmt(k, float(vals[k])), 24, _c("good") if changed else (_c("text") if not hi else _c("dim"))))
		if changed:
			row.add_child(_glyph(G_UP, _c("good"), 3))
		v.add_child(row)
	return p


## ================================================================ DEMİRCİ D - Dövme Kartları
## Tam ekran: silah sekmeleri, seçili silahın ustalık özeti, 4 geliştirme + final YAN YANA tam metinli kartlar (her kartın kendi
## fiyatı ve DÖV düğmesi; alınanlar damgalı) - seçim/ayrıntı paneli gerekmez, her şey tek bakışta.
func _design_dd() -> Control:
	var r := _root(0.7)
	var top := _h(16)
	top.position = Vector2(40, 28)
	top.custom_minimum_size = Vector2(1840, 72)
	var hdr := _d_header(1, true)
	hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hdr)
	r.add_child(top)
	var wt := _h(14)
	wt.position = Vector2(40, 124)
	wt.custom_minimum_size.x = 1840
	wt.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in WEAPONS.size():
		wt.add_child(_w_card(i, 420.0, i == SEL_W, 64.0))
	r.add_child(wt)
	## özet şeridi
	var sm := _box(Color(_c("panel"), 0.95), _c("line"), 16.0)
	sm.position = Vector2(40, 268)
	sm.custom_minimum_size = Vector2(1840, 0)
	var sh := _h(22)
	sm.add_child(sh)
	sh.add_child(_wicon(_wkey(SEL_W), 96.0, _wtier(SEL_W)))
	var sv := _v(2)
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	var sn := _h(14)
	sn.add_child(_lbl(_wname(SEL_W).to_upper(), 48, _c("text")))
	sn.add_child(_lbl(str(_wdef(SEL_W).get("name", "")), 32, _c("accent")))
	sv.add_child(sn)
	sv.add_child(_clip(str((_wdef(SEL_W)["base"] as Dictionary)["text"]), 24, _c("dim"), 900.0))
	sh.add_child(_expand(sv))
	var pv := _v(6)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	var pl := _h(10)
	pl.add_child(_lbl("USTALIK", 24, _c("dim")))
	pl.add_child(_lbl("%d/4" % _wups(SEL_W).size(), 24, _c("text")))
	pl.add_child(_lbl("· Kademe %s" % ROMAN[_wtier(SEL_W) - 1], 24, _tier_color(_wtier(SEL_W))))
	pv.add_child(pl)
	pv.add_child(_wpips(SEL_W, 420.0, 16.0))
	sh.add_child(pv)
	r.add_child(sm)
	## kartlar
	var cards := _h(22)
	cards.position = Vector2(40, 420)
	cards.custom_minimum_size = Vector2(1840, 560)
	var rows: Array = _wrows(SEL_W)
	for idx in rows.size():
		var cc := _v(0)
		if idx != SEL_UP:
			cc.add_child(_sp(0, 18))
		var card := _forge_card(idx, rows[idx], 345.0 if idx < 4 else 380.0)
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cc.add_child(card)
		if idx == SEL_UP:
			cc.add_child(_sp(0, 18))
		cards.add_child(cc)
	r.add_child(cards)
	var hint := _lbl("Geliştirmeleri istediğin sırayla dövebilirsin · fiyat her geliştirmede +%d altın artar · 4'ü bitince FİNAL açılır" % int(LG.WUPGRADE_PRICE_STEP), 24, _c("dim"), HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(40, 1012)
	hint.custom_minimum_size = Vector2(1840, 32)
	r.add_child(hint)
	return r


func _forge_card(idx: int, rd: Dictionary, w: float) -> PanelContainer:
	var st: String = _row_state(SEL_W, idx)
	var sel: bool = idx == SEL_UP
	var final_up: bool = bool(rd["final"])
	var fill: Color = _c("panel3") if sel else _c("panel2")
	var bd: Color = _c("accent") if sel else (ENCH_COL[5].darkened(0.3) if final_up else _c("line_hi"))
	if st == "taken":
		bd = _c("good").darkened(0.2)
	if st == "locked":
		fill = _c("panel")
		bd = _c("line")
	var p := _box(fill, bd, 18.0, 3, 8)
	p.custom_minimum_size.x = w
	var v := _v(12)
	p.add_child(v)
	var th := _h(12)
	th.add_child(_up_badge(SEL_W, idx, 64.0, sel))
	var tv := _v(0)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_child(_lbl("FİNAL" if final_up else "GELİŞTİRME %s" % ROMAN[idx], 24, ENCH_COL[5] if final_up else _c("dim")))
	th.add_child(tv)
	v.add_child(th)
	v.add_child(_wrap(str(rd["name"]), 40, _c("text") if st != "locked" else _c("dim"), w - 40.0))
	v.add_child(_hline())
	v.add_child(_wrap(str(rd["text"]), 24, _c("text") if st == "avail" else _c("dim"), w - 40.0))
	v.add_child(_sp(0, 0, false, true))
	match st:
		"taken":
			var stamp := _box(_c("good").darkened(0.62), _c("good"), 10.0, 3, 6)
			var sh := _h(10)
			sh.alignment = BoxContainer.ALIGNMENT_CENTER
			sh.add_child(_glyph(G_CHECK, _c("good"), 4))
			sh.add_child(_lbl("DÖVÜLDÜ", 32, _c("good")))
			stamp.add_child(sh)
			v.add_child(stamp)
		"locked":
			v.add_child(_lbl("Önce 4 geliştirmeyi bitir (%d/4)" % _wups(SEL_W).size(), 24, _c("dim")))
			var cost0: Vector2i = _up_cost(SEL_W, idx)
			v.add_child(_cost_btn("", cost0.x, cost0.y, "off", 32, 64, 0, G_LOCK))
		_:
			var cost: Vector2i = _up_cost(SEL_W, idx)
			v.add_child(_cost_btn("DÖV", cost.x, cost.y, "primary" if sel else "ghost", 32, 64, 0, G_HAMMER))
	return p
