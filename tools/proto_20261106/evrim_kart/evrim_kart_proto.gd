extends SceneTree

## YETENEK EVRİMİ kartı görünüş prototipleri (2026-11-06, kullanıcı: "5 levelde bir çıkan skill geliştirme kartlarının görünüşü için
## 4 prototip hazırla"). OYUNA BAĞLI DEĞİL.
## GERÇEK SP main.tscn'de OYUNDAKİ evrim ekranı açılır (main.gd debug_open_evolution_screen; Matthew, 20. seviye, sahip olunan
## evrimler OWNED, sunulan 3 evrim OFFER sabit: Q 3/5 + E 2/5 + R FİNAL). Ekranın kendi EvoCards satırı gizlenip yerine
## prototip kurulur; başlık / karartma / arka plan oyunun kendisi.
## Ortak dil (kullanıcının 2026-10-02 isteği korunur): normal evrim MOR, FİNAL KIRMIZI. Hepsi bugünkü 360x540 (x0,85) kartlardan
## küçük, m5x7 24/32 (tam kat), simge 144 -> 96 / 48 (tam kat), çerçeve oyunun tier_slot_3/4 + yetenek ipucunun tuş kapağı, "·" yok.
##   A Mühür Kartı   - sade dikey kart: kademe yuvasında simge + tuş kapağı, EVRİM n/N + ilerleme pipleri, ad + açıklama
##   B Evrim Tahtası - Q/E/R sütunlarında yuvanın BÜTÜN evrimleri (alınan tik, sunulan açık kart, kalan sönük, final kilitli)
##   C Yetenek Satırı- level kartı C gibi yatay satırlar: yuva solda, ad + açıklama ortada, n/N + pipler sağda
##   D Sancak        - ahşap çubuktan sarkan kumaş sancaklar (kırlangıç kuyruk), final kırmızı ve kuyruğu derin
## Çıktı (out/): 0_simdi.png (bugünkü), A.png..D.png (2. kartın üstündeyken = altın kenar), ozet.png (4'ü bir arada).
## Kullanım: tools/proto_20261106/evrim_kart/evrim_kart_run.ps1 [-Only "A,C"]
## NOT: bu dosyayı PowerShell Get-Content/Set-Content ile DÜZENLEME (BOM'suz UTF-8'i ANSI okuyup Türkçe harfleri bozuyor).

const CHAR_ID := 3
const LEVEL := 20
const OWNED := ["matthew_q1", "matthew_q3", "matthew_e2", "matthew_r1", "matthew_r2"]
const OFFER := ["matthew_q4", "matthew_e3", "matthew_rf"]
const HOVER := 1
const SLOTS := ["skill", "skill2", "skill3"]
const KEYS := {"skill": "Q", "skill2": "E", "skill3": "R"}
const DarkKit := preload("res://scripts/shop_dark_kit.gd")
const SLOT_EVO: Texture2D = preload("res://assets/ui/game/tier_slot_3.png")
const SLOT_FIN: Texture2D = preload("res://assets/ui/game/tier_slot_4.png")
const NAMES := {"0": "ŞU AN", "A": "A - Mühür Kartı", "B": "B - Evrim Tahtası", "C": "C - Yetenek Satırı", "D": "D - Sancak"}

const EVO := {"fill": Color("#221a31"), "fill_hi": Color("#2d2242"), "edge": Color("#8a5fd0"), "edge_dk": Color("#4a3470"),
	"light": Color("#d8aef4"), "well": Color("#16111f"),
	"cloth": Color("#34254f"), "shade": Color("#281c3d"), "outline": Color("#120c1c")}
const FIN := {"fill": Color("#2b1717"), "fill_hi": Color("#3a1e1c"), "edge": Color("#d0523e"), "edge_dk": Color("#6e2a22"),
	"light": Color("#f8a890"), "well": Color("#1d0f0f"),
	"cloth": Color("#4a1d1b"), "shade": Color("#371412"), "outline": Color("#170807")}
const GOLD := Color("#f4c56e")
const CREAM := Color("#efe6d6")
const DIM := Color("#c6bccf")
const NUM := Color("#e6cf92")
const FAINT := Color("#77718f")
const GOOD := Color("#a8d69a")
const G_SQUARE := ["####", "#..#", "#..#", "####"]

var GM: Node = null
var main: Node = null
var screen: Node = null
var host: Control = null
var k = null
var SE: GDScript = null
var Chars: GDScript = null
var offers: Array = []
var shots: Dictionary = {}


## ---------------------------------------------------------------- küçük çizim düğümleri
## İlerleme pipleri: alınan = mor/kırmızı dolu, şimdiki = altın, kalan = kuyu; son pip (final) elmas.
class Pips extends Control:
	const PX := 3
	var total: int = 5
	var owned: int = 0
	var pal: Dictionary = {}
	var gold: Color = Color.WHITE

	func _init(t: int, o: int, p: Dictionary, g: Color) -> void:
		total = t
		owned = o
		pal = p
		gold = g
		custom_minimum_size = Vector2(total * 15 + (total - 1) * 6, 15)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x: float = 0.0
		for i in total:
			var col: Color = pal["light"] if i < owned else (gold if i == owned else pal["edge_dk"])
			var filled: bool = i <= owned
			if i == total - 1:
				## Elmas 7 satır x 2 px (5x3 px'lik küçük elmas "artı / parıltı" gibi okunuyordu).
				var rows := [1, 3, 5, 7, 5, 3, 1]
				for r in 7:
					var w: int = rows[r]
					draw_rect(Rect2(x + 0.5 + (7 - w) * 1.0, 0.5 + r * 2.0, w * 2.0, 2.0), col)
				if not filled:
					for r in 3:
						var w2: int = [1, 3, 1][r]
						draw_rect(Rect2(x + 0.5 + (7 - w2) * 1.0, 0.5 + (r + 2) * 2.0, w2 * 2.0, 2.0), pal["well"])
			else:
				draw_rect(Rect2(x + 1.5, 1.5, 12, 12), col)
				if not filled:
					draw_rect(Rect2(x + 4.5, 4.5, 6, 6), pal["well"])
			x += 15 + 6


## Tuş kapağı: HUD mini düğme levhası + m5x7 24 harf (büyük harf 7 font pikseli x 3 = 21 px, taban çizgisi ortalanır).
class KeyCap extends Control:
	var sb: StyleBox = null
	var font: Font = null
	var key: String = "Q"

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if sb:
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if font:
			var base: float = roundf((size.y + 21.0) * 0.5) - 1.0
			draw_string(font, Vector2(1, base + 3), key, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0, 0, 0, 0.45))
			draw_string(font, Vector2(1, base), key, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color("#f3e6cc"))


## D: kumaş sancak - üstte iki ip, 4 px basamaklı kırlangıç kuyruk, dış hat > kenar şeridi > kumaş; üstte çubuğun gölgesi.
class Banner extends PanelContainer:
	const PX := 4
	const CORD := 16.0
	var pal: Dictionary = {}
	var trim: Color = Color.WHITE
	var tail: float = 28.0

	func _bottom(x: float) -> float:
		var half: float = size.x * 0.5
		var t: float = absf(x + PX * 0.5 - half) / half
		return size.y - tail + floorf(tail * t / PX) * PX

	func _draw() -> void:
		var w: float = size.x
		var rope := Color("#8a6a3a")
		for cx in [w * 0.22, w * 0.78]:
			var x0: float = floorf(cx / PX) * PX
			draw_rect(Rect2(x0, 0, PX, CORD + PX), rope)
			draw_rect(Rect2(x0 - PX, CORD - PX, PX * 3, PX), rope.darkened(0.3))
		var x: float = 0.0
		while x < w - 0.5:
			var b: float = _bottom(x)
			draw_rect(Rect2(x, CORD, PX, b - CORD), pal["outline"])
			if x >= PX and x < w - PX:
				draw_rect(Rect2(x, CORD + PX, PX, b - CORD - 2 * PX), trim)
			if x >= 2 * PX and x < w - 2 * PX:
				var col: Color = pal["shade"] if x >= w - 4 * PX else pal["cloth"]
				draw_rect(Rect2(x, CORD + 2 * PX, PX, b - CORD - 4 * PX), col)
				draw_rect(Rect2(x, CORD + 2 * PX, PX, PX * 2), pal["shade"])
			x += PX


## D: ahşap çubuk (HUD Kısık Ahşap renkleri) + iki uçta pirinç topuz.
class Rod extends Control:
	const PX := 4

	func _draw() -> void:
		var w: float = size.x
		var y0: float = 4.0
		draw_rect(Rect2(PX * 4, y0, w - PX * 8, 16), Color("#20150d"))
		draw_rect(Rect2(PX * 4, y0 + PX, w - PX * 8, 8), Color("#6a4a30"))
		draw_rect(Rect2(PX * 4, y0 + PX, w - PX * 8, PX), Color("#86623f"))
		for x0 in [0.0, w - PX * 6]:
			draw_rect(Rect2(x0, 0, PX * 6, PX * 6), Color("#20150d"))
			draw_rect(Rect2(x0 + PX, PX, PX * 4, PX * 4), Color("#c99a4a"))
			draw_rect(Rect2(x0 + PX, PX, PX * 4, PX), Color("#f0c878"))
			draw_rect(Rect2(x0 + PX, PX * 4, PX * 4, PX), Color("#8a6428"))


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _out() -> String:
	var d: String = OS.get_environment("EVRIM_KART_DIR")
	if d == "":
		d = ProjectSettings.globalize_path("res://tools/proto_20261106/evrim_kart/out")
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	img.save_png(_out().path_join(name))
	shots[name] = img
	print("SHOT %s" % name)


## ---------------------------------------------------------------- oyun kurulumu
func _run() -> void:
	await process_frame
	GM = root.get_node("GameManager")
	SE = load("res://scripts/skill_evolutions.gd")
	Chars = load("res://scripts/characters.gd")
	AudioServer.set_bus_mute(0, true)
	root.get_node("NetworkManager").call("disconnect_from_room")
	root.get_node("UISound").set("show_fps", false)
	GM.call("reset")
	GM.set("selected_char_id", CHAR_ID)
	GM.set("selected_character", Chars.call("get_def", CHAR_ID).get("skill", 1))
	GM.set("selected_start_weapon", "uzunkilic")
	GM.set("selected_pet", "kirpi")
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
	main = current_scene
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	for n in main.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s and s.resource_path.ends_with("house_intro.gd"):
			n.set_process(false)
	await _wait(2.0)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var p: Node2D = main.get_node_or_null("Player") as Node2D
	p.global_position += Vector2(40, 170)
	(load("res://scripts/meta_progress.gd") as GDScript).call("set_unlock_all", true)
	GM.set("game_time", 1350.0)
	p.set("level", LEVEL)
	var owned := {}
	for id: String in OWNED:
		owned[id] = true
	p.set("skill_evolutions", owned)
	await _wait(1.0)

	if not bool(main.call("debug_open_evolution_screen")):
		print("!! evrim ekranı açılmadı")
		quit()
		return
	await _wait(1.4)
	screen = main.get_node_or_null("LevelUpScreen")
	var evo_offers: Array = []
	for id: String in OFFER:
		var e: Dictionary = SE.call("find", id)
		evo_offers.append(e)
		offers.append(_data(e, owned))
	screen.set("_evo_offers", evo_offers)
	screen.call("_populate_evolution_rows")
	await _wait(1.0)
	await _shot("0_simdi.png")
	var row: Control = screen.get_node_or_null("EvoCards") as Control
	if row:
		print("VERI bugün EvoCards %dx%d (x%.2f) global %s" % [int(row.size.x), int(row.size.y), row.scale.x, str(row.get_global_rect())])
		row.visible = false

	k = DarkKit.new(DarkKit.PAL_NIGHT)
	host = Control.new()
	host.name = "EvoProto"
	host.theme = k.theme()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(host)
	await _worst_case()

	var only: String = OS.get_environment("EVRIM_KART_ONLY")
	var done: Array = []
	for key: String in ["A", "B", "C", "D"]:
		if only != "" and not only.contains(key):
			continue
		var proto: Control = call("_build_" + key)
		host.add_child(proto)
		await process_frame
		await process_frame
		var sz: Vector2 = proto.get_combined_minimum_size()
		proto.size = sz
		proto.position = Vector2(roundf((1920.0 - sz.x) * 0.5), roundf(140.0 + maxf(0.0, (920.0 - sz.y) * 0.5)))
		await _wait(0.3)
		print("VERI %s %dx%d @ %s" % [key, int(sz.x), int(sz.y), str(proto.position)])
		await _shot("%s.png" % key)
		proto.queue_free()
		await process_frame
		done.append(key)
	if done.size() > 1:
		await _summary(done)
	quit()


## ---------------------------------------------------------------- veri
func _data(e: Dictionary, owned: Dictionary) -> Dictionary:
	var slot: String = str(e["slot"])
	var def: Dictionary = Chars.call("get_def", CHAR_ID)
	var list: Array = SE.call("slot_list", CHAR_ID, slot)
	var have: int = int(SE.call("owned_count", CHAR_ID, slot, owned))
	return {
		"id": str(e["id"]), "slot": slot, "key": KEYS[slot],
		"skill": str(def.get(slot + "_evo_name", def.get(slot + "_name", ""))),
		"icon": load(str(def.get(slot + "_icon", ""))) as Texture2D,
		"name": str(e["name"]), "desc": str(e["desc"]), "final": bool(e.get("final", false)),
		"owned": have, "total": list.size(),
	}


func _tier_text(d: Dictionary) -> String:
	return "FİNAL EVRİM" if d["final"] else "EVRİM %d/%d" % [int(d["owned"]) + 1, int(d["total"])]


func _pal(d: Dictionary) -> Dictionary:
	return FIN if d["final"] else EVO


func _bb(text: String) -> String:
	var rx := RegEx.new()
	rx.compile("%?\\d+(?:[.,]\\d+)?(?:\\s*saniye)?")
	var out: String = ""
	var last: int = 0
	for m in rx.search_all(text):
		out += text.substr(last, m.get_start() - last)
		out += "[color=#%s]%s[/color]" % [NUM.to_html(false), m.get_string()]
		last = m.get_end()
	return out + text.substr(last)


## ---------------------------------------------------------------- ortak parçalar
func _rtl(text: String, fs: int, col: Color, w: float, center: bool = false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size.x = w
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_color_override("default_color", col)
	r.add_theme_constant_override("line_separation", 2)
	r.text = ("[center]%s[/center]" if center else "%s") % _bb(text)
	return r


## Kademe yuvası (tier_slot_3 mor / tier_slot_4 kırmızı) + simge + tuş kapağı. big: 128 (4x) + simge 96 (2x) + kapak 40 (4x);
## küçük: 64 (2x) + simge 48 (1x) + kapak 20 (2x).
func _slot_icon(d: Dictionary, big: bool) -> Control:
	var s: float = 128.0 if big else 64.0
	var ic_s: float = 96.0 if big else 48.0
	var kc: float = 39.0
	var c := Control.new()
	c.custom_minimum_size = Vector2(s, s)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for spec in [[SLOT_FIN if d["final"] else SLOT_EVO, Vector2.ZERO, s], [d["icon"], Vector2.ONE * (s - ic_s) * 0.5, ic_s]]:
		var tr := TextureRect.new()
		tr.texture = spec[0]
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(tr)
		tr.position = spec[1]
		tr.size = Vector2.ONE * float(spec[2])
	if big:
		## Oyunun kendi tuş kapağı (yetenek ipucundaki HudTooltip.make_keycap: HUD mini düğme levhası + harf, 39 px).
		## PanelContainer'ın kendisi doku kenar paylarıyla 49x86'ya şişiyor -> levhası alınıp 39x39 elle çizilir.
		var src: Control = (load("res://scripts/hud_tooltip.gd") as GDScript).call("make_keycap", str(d["key"]))
		var cap := KeyCap.new()
		cap.sb = src.get_theme_stylebox("panel")
		cap.font = k.theme().default_font
		cap.key = str(d["key"])
		src.free()
		c.add_child(cap)
		cap.position = Vector2(s - kc + 8.0, s - kc + 8.0)
		cap.size = Vector2(kc, kc)
	return c


func _card_box(d: Dictionary, hov: bool, l: float, t: float, r: float, b: float) -> PanelContainer:
	var pal: Dictionary = _pal(d)
	var sbx: StyleBox = k.sb(pal["fill_hi"] if hov else pal["fill"], GOLD if hov else pal["edge"], 3, 6)
	sbx.content_margin_left = l
	sbx.content_margin_top = t
	sbx.content_margin_right = r
	sbx.content_margin_bottom = b
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sbx)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _center(n: Control) -> Control:
	n.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return n


## ---------------------------------------------------------------- A Mühür Kartı
const A_W := 296.0


func _build_A() -> Control:
	var row: HBoxContainer = k.h(24)
	for i in offers.size():
		row.add_child(_card_A(offers[i], i == HOVER))
	return row


func _card_A(d: Dictionary, hov: bool) -> Control:
	var pal: Dictionary = _pal(d)
	var p: PanelContainer = _card_box(d, hov, 24, 24, 24, 28)
	p.custom_minimum_size.x = A_W
	var v: VBoxContainer = k.v(0)
	p.add_child(v)
	var inner: float = A_W - 48.0
	v.add_child(_slot_icon(d, true))
	v.add_child(k.sp(0, 16))
	v.add_child(k.lbl(_tier_text(d), 24, pal["light"], HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.lbl(str(d["skill"]), 24, FAINT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.sp(0, 10))
	v.add_child(_center(Pips.new(int(d["total"]), int(d["owned"]), pal, GOLD)))
	v.add_child(k.sp(0, 18))
	v.add_child(k.wrap(str(d["name"]), 32, CREAM, inner, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.sp(0, 8))
	v.add_child(_rtl(str(d["desc"]), 24, DIM, inner, true))
	return p


## ---------------------------------------------------------------- B Evrim Tahtası
const B_COL := 400.0


func _build_B() -> Control:
	var panel: PanelContainer = k.box(k.c("panel"), k.c("line"), 24.0, 3, 8)
	var cols: HBoxContainer = k.h(24)
	panel.add_child(cols)
	var owned := {}
	for id: String in OWNED:
		owned[id] = true
	var offered := {}
	for i in offers.size():
		offered[str(offers[i]["id"])] = i
	for slot: String in SLOTS:
		cols.add_child(_col_B(slot, owned, offered))
	return panel


func _col_B(slot: String, owned: Dictionary, offered: Dictionary) -> Control:
	var def: Dictionary = Chars.call("get_def", CHAR_ID)
	var list: Array = SE.call("slot_list", CHAR_ID, slot)
	var have: int = int(SE.call("owned_count", CHAR_ID, slot, owned))
	var v: VBoxContainer = k.v(8)
	v.custom_minimum_size.x = B_COL
	var head: HBoxContainer = k.h(14)
	var hd := {"final": false, "icon": load(str(def.get(slot + "_icon", ""))), "key": KEYS[slot]}
	head.add_child(_slot_icon(hd, false))
	var hv: VBoxContainer = k.v(0)
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title: HBoxContainer = k.h(10)
	title.add_child(k.lbl(str(KEYS[slot]), 32, GOLD))
	title.add_child(k.lbl(str(def.get(slot + "_evo_name", def.get(slot + "_name", ""))), 32, CREAM))
	hv.add_child(title)
	hv.add_child(k.lbl("%d/%d evrim" % [have, list.size()], 24, FAINT))
	head.add_child(hv)
	v.add_child(head)
	v.add_child(k.hline(k.c("line"), 3.0))
	var regular_missing: bool = false
	for e: Dictionary in list:
		if not bool(e.get("final", false)) and not owned.has(str(e["id"])):
			regular_missing = true
	for e: Dictionary in list:
		var id: String = str(e["id"])
		var fin: bool = bool(e.get("final", false))
		if offered.has(id):
			var idx: int = int(offered[id])
			var d: Dictionary = offers[idx]
			var p: PanelContainer = _card_box(d, idx == HOVER, 14, 10, 14, 14)
			var cv: VBoxContainer = k.v(4)
			p.add_child(cv)
			var line: HBoxContainer = k.h(10)
			if fin:
				line.add_child(k.glyph(DarkKit.G_CROWN, FIN["light"], 3))
			line.add_child(k.lbl(str(d["name"]), 32, CREAM))
			if fin:
				line.add_child(k.sp(0, 0, true))
				line.add_child(k.lbl("FİNAL", 24, FIN["light"]))
			cv.add_child(line)
			cv.add_child(_rtl(str(d["desc"]), 24, DIM, B_COL - 34.0))
			v.add_child(p)
			continue
		var row: HBoxContainer = k.h(10)
		var mark: CenterContainer = CenterContainer.new()
		mark.custom_minimum_size = Vector2(24, 24)
		var txt_col: Color = FAINT
		if owned.has(id):
			mark.add_child(k.glyph(DarkKit.G_CHECK, GOOD, 3))
			txt_col = GOOD.darkened(0.15)
		elif fin:
			mark.add_child(k.glyph(DarkKit.G_LOCK if regular_missing else DarkKit.G_CROWN, FAINT, 2 if regular_missing else 3))
		else:
			mark.add_child(k.glyph(G_SQUARE, FAINT, 3))
		row.add_child(mark)
		row.add_child(k.lbl(str(e["name"]), 24, txt_col))
		v.add_child(row)
	return v


## ---------------------------------------------------------------- C Yetenek Satırı
const C_W := 800.0
const C_RIGHT := 112.0


func _build_C() -> Control:
	var v: VBoxContainer = k.v(16)
	for i in offers.size():
		v.add_child(_row_C(offers[i], i == HOVER))
	return v


func _row_C(d: Dictionary, hov: bool) -> Control:
	var pal: Dictionary = _pal(d)
	var p: PanelContainer = _card_box(d, hov, 16, 16, 24, 16)
	p.custom_minimum_size.x = C_W
	var h: HBoxContainer = k.h(20)
	p.add_child(h)
	h.add_child(_slot_icon(d, true))
	var mid_w: float = C_W - 16.0 - 24.0 - 128.0 - 20.0 * 2.0 - C_RIGHT
	var mid: VBoxContainer = k.v(2)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(k.lbl(str(d["skill"]), 24, pal["light"]))
	mid.add_child(k.lbl(str(d["name"]), 32, CREAM))
	mid.add_child(k.sp(0, 4))
	mid.add_child(_rtl(str(d["desc"]), 24, DIM, mid_w))
	h.add_child(mid)
	var right: VBoxContainer = k.v(4)
	right.custom_minimum_size.x = C_RIGHT
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(k.lbl("FİNAL" if d["final"] else "EVRİM", 24, pal["light"], HORIZONTAL_ALIGNMENT_RIGHT))
	right.add_child(k.lbl("%d/%d" % [int(d["owned"]) + 1, int(d["total"])], 40, CREAM, HORIZONTAL_ALIGNMENT_RIGHT))
	var pips := Pips.new(int(d["total"]), int(d["owned"]), pal, GOLD)
	pips.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(pips)
	h.add_child(right)
	return p


## ---------------------------------------------------------------- D Sancak
const D_W := 300.0
const D_GAP := 40


func _build_D() -> Control:
	var v: VBoxContainer = k.v(0)
	var rod := Rod.new()
	rod.custom_minimum_size = Vector2(D_W * offers.size() + D_GAP * (offers.size() - 1) + 96.0, 24)
	rod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rod)
	var row: HBoxContainer = k.h(D_GAP)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for i in offers.size():
		row.add_child(_banner_D(offers[i], i == HOVER))
	v.add_child(row)
	return v


func _banner_D(d: Dictionary, hov: bool) -> Control:
	var pal: Dictionary = _pal(d)
	var b := Banner.new()
	b.pal = pal
	b.trim = GOLD if hov else pal["edge"]
	b.tail = 44.0 if d["final"] else 28.0
	var sbx := StyleBoxEmpty.new()
	sbx.content_margin_left = 28
	sbx.content_margin_right = 28
	sbx.content_margin_top = Banner.CORD + 28.0
	sbx.content_margin_bottom = b.tail + 28.0
	b.add_theme_stylebox_override("panel", sbx)
	b.custom_minimum_size.x = D_W
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner: float = D_W - 56.0
	var v: VBoxContainer = k.v(0)
	b.add_child(v)
	v.add_child(_slot_icon(d, true))
	v.add_child(k.sp(0, 14))
	v.add_child(k.lbl(_tier_text(d), 24, pal["light"], HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.sp(0, 8))
	v.add_child(_center(Pips.new(int(d["total"]), int(d["owned"]), pal, GOLD)))
	v.add_child(k.sp(0, 16))
	v.add_child(k.wrap(str(d["name"]), 32, CREAM, inner, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.lbl(str(d["skill"]), 24, FAINT.lightened(0.15), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(k.sp(0, 10))
	v.add_child(_rtl(str(d["desc"]), 24, DIM, inner, true))
	return b


## ---------------------------------------------------------------- en kötü durum ölçüsü (bütün karakterlerin en uzun açıklaması)
func _worst_case() -> void:
	var defs: Dictionary = SE.get_script_constant_map()["DEFS"]
	var worst := {"desc": "", "name": ""}
	var who := {}
	for cid in defs:
		for slot: String in SLOTS:
			for e: Dictionary in SE.call("slot_list", int(cid), slot):
				if str(e["desc"]).length() > str(worst["desc"]).length():
					worst["desc"] = str(e["desc"])
					who["desc"] = str(e["id"])
				if k.tw(str(e["name"]), 32) > k.tw(str(worst["name"]), 32):
					worst["name"] = str(e["name"])
					who["name"] = str(e["id"])
	print("VERI en uzun açıklama %s (%d harf) | en geniş ad %s '%s' (32 = %d px)" % [who["desc"], str(worst["desc"]).length(),
		who["name"], worst["name"], int(k.tw(str(worst["name"]), 32))])
	var d: Dictionary = offers[0].duplicate()
	d["desc"] = worst["desc"]
	d["name"] = worst["name"]
	await process_frame
	for key: String in ["A", "C", "D"]:
		var n: Control = call("_card_A", d, false) if key == "A" else (call("_row_C", d, false) if key == "C" else call("_banner_D", d, false))
		n.position = Vector2(-4000, 0)
		host.add_child(n)
		await process_frame
		await process_frame
		var sz: Vector2 = n.get_combined_minimum_size()
		print("VERI en kötü %s kart %dx%d" % [key, int(sz.x), int(sz.y)])
		n.queue_free()


## ---------------------------------------------------------------- özet
func _summary(done: Array) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("#0c0c14")
	bg.size = Vector2(1920, 1080)
	layer.add_child(bg)
	var sh := Control.new()
	sh.theme = k.theme()
	sh.size = Vector2(1920, 1080)
	layer.add_child(sh)
	for idx in done.size():
		var key: String = done[idx]
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(shots["%s.png" % key])
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.position = Vector2(8 + (idx % 2) * 960, 8 + floori(idx / 2.0) * 540)
		tr.size = Vector2(944, 531)
		sh.add_child(tr)
		var pc: PanelContainer = k.box(Color(0.05, 0.05, 0.09, 0.88), k.c("line_hi"), 8, 2, 4)
		pc.add_child(k.lbl(NAMES[key], 32, k.c("accent")))
		sh.add_child(pc)
		pc.position = tr.position + Vector2(10, 10)
	await _wait(0.2)
	await _shot("ozet.png")
