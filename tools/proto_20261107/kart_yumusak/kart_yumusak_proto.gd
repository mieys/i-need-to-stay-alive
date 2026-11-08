extends SceneTree

## YUMUŞAK KART prototipleri (2026-11-07, kullanıcı: "level atlama kartları ve 5 levelde bir gelen skill seçim kartları için daha soft
## ve oyunun temasıyla uyumlu yeni 4 prototip hazırlar mısın"). OYUNA BAĞLI DEĞİL.
## GERÇEK SP main.tscn'de OYUNDAKİ evrim ekranı (main.gd debug_open_evolution_screen; Matthew, sahip olunan OWNED, sunulan OFFER sabit)
## ve level ekranı (main.gd _show_level_up_screen(21); kartlar LEVEL_CARDS sabit) açılır. Ekranın kendi kart düğümleri (EvoCards / Rows)
## gizlenip yerine prototip kurulur; başlık, karartma, Karıştır düğmesi, arka plan oyunun kendisi.
## İçerik DEĞİŞMEZ: level kartı = simge + renkli tek cümle (madde 433 ek 6, ekranın card_sentence'ı), evrim kartı = simge + tuş kapağı +
## EVRİM n/N + yetenek adı + pipler + ad + açıklama (madde 428). Renkler hud_theme.gd rolleri (yeni hex yok); anlamlı renkler (kademe
## gri/mavi/mor/kırmızı = ekranın ROW_TIER_TEXT'i, evrim mor / final kırmızı) zemine doğru KISILIR; yazı m5x7 16/32/48; 3 px ızgara;
## ışıltı süpürmesi / hale / kıvılcım / ölçek yok. Bugünkü sorunlar: level satırı LACİVERT gövde (stil rehberinde yasak zemin) + doygun
## kademe kenarı + çapraz ışıltı şeridi + x0,85 ölçek (bulanık yazı); evrim kartında 3 px doygun mor/kırmızı çerçeve.
##   A Sıcak Kapsül  - bugünkü Yüzen Kapsül'ün AHŞAP hâli: düz dolgu + altında yumuşak gölge, kısık kademe kenarı, üstündeyken 1 sanat px kalkar
##   B Tek Pencere   - seçenekler oyunun diğer pencereleri gibi TEK ahşap pencerede gömme satır / sütun; kademe yalnız simge madalyonunun halkasında
##   C Dikişli Kumaş - kumaş yama: koyu dış hat + kabarık ışık/gölge + kademe renginde kesik dikiş; evrim pipleri çarpı işi
##   D Ocak Işığı    - kutusuz: ortak yumuşak koyu zemin, simge sıcak ışık havuzunda durur, kademe ayaklık halkasında, aralarda ince ahşap çizgi
## Hepsinde 2. seçenek "üstünde" hâlinde çekilir.
## Çıktı (out/): 0_evrim.png / 0_level.png (bugünkü), X_evrim.png / X_level.png, ozet.png (ozet.py, çalıştırıcı sonunda).
## Kullanım: tools/proto_20261107/kart_yumusak/kart_yumusak_run.ps1 [-Only "A,C"]
## NOT: bu dosyayı PowerShell Get-Content/Set-Content ile DÜZENLEME (BOM'suz UTF-8'i ANSI okuyup Türkçe harfleri bozuyor).

const P := preload("res://tools/proto_20261107/kart_yumusak/px_draw.gd")
const HT := preload("res://scripts/hud_theme.gd")
const CHAR_ID := 3
const EVO_LEVEL := 20
const OWNED := ["matthew_q1", "matthew_q3", "matthew_e2", "matthew_r1", "matthew_r2"]
const OFFER := ["matthew_q4", "matthew_e3", "matthew_rf"]
## [kart id, kademe]: Efsanevi takas kartı + Sıradan + Nadir (gri / mavi / kırmızı aynı ekranda).
const LEVEL_CARDS := [["trade_trigger", 4], ["crit_chance", 1], ["cooldown_reduction", 2]]
const HOVER := 1
const KEYS := {"skill": "Q", "skill2": "E", "skill3": "R"}
const LEVEL_MID_Y := 463.0 ## bugünkü satır sütununun (x0,85) dikey ortası: 253 + 420 / 2
const EVO_TOP := 150.0 ## bugünkü EVO_BOX_TOP
const ROW_W := 690.0 ## bugünkü görünen satır 683x127 (804x150 x0,85) -> ölçeksiz, 3 px ızgarada
const ROW_H := 120.0
const TRAY_BOTTOM := 894.0 ## G: tepsinin altı = HUD paneli üstünün 20 px yukarısı

var GM: Node = null
var main: Node = null
var screen: Node = null
var host: Control = null
var UIK: GDScript = null
var SE: GDScript = null
var Chars: GDScript = null
var LSC: GDScript = null
var tier_hi: Array = []
var lvl_data: Array = []
var evo_data: Array = []
var shots: Array = []


## ---------------------------------------------------------------- çizim düğümleri
## A: kapsül - kenar + düz dolgu, altında 2 sanat px yarı saydam gölge (kalkınca gölge yerinde kalır = 3 sanat px).
class Capsule extends MarginContainer:
	const P := preload("res://tools/proto_20261107/kart_yumusak/px_draw.gd")
	var fill := Color.BLACK
	var edge := Color.BLACK
	var shadow := Color(0, 0, 0, 0)
	var r: int = 4
	var lifted: bool = false

	func _draw() -> void:
		var rc := Rect2(Vector2.ZERO, size)
		P.rrect(self, Rect2(0, 9.0 if lifted else 6.0, size.x, size.y), r, shadow)
		P.rrect(self, rc, r, edge)
		P.rrect(self, rc.grow(-3.0), r - 1, fill)


## C: kumaş yama - koyu dış hat, üstte 1 sanat px kabarık ışık / altta gölge, kumaş, içeride kesik dikiş.
class Patch extends MarginContainer:
	const P := preload("res://tools/proto_20261107/kart_yumusak/px_draw.gd")
	var cloth := Color.BLACK
	var thread := Color(0, 0, 0, 0)
	var outline := Color.BLACK
	var hi := Color.BLACK
	var lo := Color.BLACK
	var shadow := Color(0, 0, 0, 0)
	var r: int = 4
	var stitch_inset: float = 9.0
	var lifted: bool = false

	func _draw() -> void:
		var rc := Rect2(Vector2.ZERO, size)
		if shadow.a > 0.0:
			P.rrect(self, Rect2(0, 9.0 if lifted else 6.0, size.x, size.y), r, shadow)
		P.rrect(self, rc, r, outline)
		P.rrect(self, rc.grow(-3.0), r - 1, lo)
		P.rrect(self, Rect2(3, 3, size.x - 6, size.y - 9), r - 1, hi)
		P.rrect(self, Rect2(3, 6, size.x - 6, size.y - 12), r - 1, cloth)
		P.stitches(self, rc.grow(-stitch_inset), maxi(r - 1, 1), thread)


## D: kutusuz bölge - iç içe yarı saydam kutularla basamaklı yumuşak zemin (ortası koyu, kenara doğru söner).
class Band extends MarginContainer:
	const P := preload("res://tools/proto_20261107/kart_yumusak/px_draw.gd")
	var col := Color(0, 0, 0, 0)
	var steps: int = 3
	var step_px: float = 9.0
	var r: int = 6

	func _draw() -> void:
		if col.a <= 0.0:
			return
		for i in steps:
			var g: float = i * step_px
			P.rrect(self, Rect2(Vector2.ZERO, size).grow(-g), maxi(r - int(g / 3.0), 1), col)


## D: simge sıcak ışık havuzunda - basamaklı elips (aynı renk üst üste = ortası parlak) + anlamlı renkte ayaklık halkası.
class Pool extends Control:
	const P := preload("res://tools/proto_20261107/kart_yumusak/px_draw.gd")
	var light := Color(0, 0, 0, 0)
	var ring := Color(0, 0, 0, 0)
	var rx: float = 54.0
	var ry: float = 15.0
	var base_y: float = 72.0
	var bands: int = 3

	func _draw() -> void:
		var c := Vector2(roundf(size.x * 0.5 / 3.0) * 3.0, base_y)
		for i in bands:
			var f: float = 1.0 - 0.27 * i
			P.ellipse(self, c, rx * f, ry * f, light)
		P.ellipse_ring(self, c, rx * 0.74, ry * 0.74, ring)


## D: ince ahşap çizgi, uçları 3 basamakta söner.
class Rule extends Control:
	var col := Color.BLACK
	var vertical: bool = false

	func _draw() -> void:
		var length: float = size.y if vertical else size.x
		var seg: float = 24.0
		var fades: Array = [0.25, 0.5, 0.75]
		for i in fades.size():
			var c2 := Color(col, col.a * float(fades[i]))
			if vertical:
				draw_rect(Rect2(0, i * seg, 3, seg), c2)
				draw_rect(Rect2(0, length - (i + 1) * seg, 3, seg), c2)
			else:
				draw_rect(Rect2(i * seg, 0, seg, 3), c2)
				draw_rect(Rect2(length - (i + 1) * seg, 0, seg, 3), c2)
		var m: float = fades.size() * seg
		if vertical:
			draw_rect(Rect2(0, m, 3, length - 2.0 * m), col)
		else:
			draw_rect(Rect2(m, 0, length - 2.0 * m, 3), col)


## Tuş kapağı: oyunun kendisi (level_up_screen.gd EvoKeyCap: HUD mini düğme levhası + m5x7 32 harf).
class KeyCap extends Control:
	const HTK := preload("res://scripts/hud_theme.gd")
	var key: String = "Q"
	var box: StyleBox = null

	func _draw() -> void:
		if box:
			draw_style_box(box, Rect2(Vector2.ZERO, size))
		var font: Font = get_theme_default_font()
		if font == null:
			return
		var base: float = roundf((size.y + 28.0) * 0.5) - 7.0
		draw_string(font, Vector2(0, base + 4.0), key, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color(HTK.DEEP, 0.6))
		draw_string(font, Vector2(0, base), key, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, HTK.TEXT)


## İlerleme pipleri (bugünkü ölçü: kare 5 sanat px, ara 3, final elmas 7). cross = çarpı işi (C).
class Pips extends Control:
	const P := preload("res://tools/proto_20261107/kart_yumusak/px_draw.gd")
	const SQ := ["#####", "#####", "#####", "#####", "#####"]
	const SQ_O := ["#####", "#...#", "#...#", "#...#", "#####"]
	const X5 := ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"]
	const DIA := ["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."]
	const DIA_O := ["...#...", "..#.#..", ".#...#.", "#.....#", ".#...#.", "..#.#..", "...#..."]
	var total: int = 5
	var owned: int = 0
	var done := Color.WHITE
	var cur := Color.WHITE
	var empty_edge := Color.WHITE
	var empty_fill := Color.BLACK
	var cross: bool = false

	func setup(t: int, o: int, done_col: Color, cur_col: Color, e_edge: Color, e_fill: Color, is_cross: bool) -> void:
		total = t
		owned = o
		done = done_col
		cur = cur_col
		empty_edge = e_edge
		empty_fill = e_fill
		cross = is_cross
		custom_minimum_size = Vector2((total - 1) * 24 + 21, 21)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		var x: float = 0.0
		for i in total:
			var fin: bool = i == total - 1
			var reached: bool = i <= owned
			var col: Color = done if i < owned else (cur if i == owned else empty_edge)
			var pos := Vector2(x, 0.0 if fin else 3.0)
			if cross:
				if fin:
					P.pattern(self, pos, DIA if reached else DIA_O, col)
				else:
					P.pattern(self, pos, X5, col)
			elif reached:
				P.pattern(self, pos, DIA if fin else SQ, col)
			else:
				P.pattern(self, pos, DIA if fin else SQ, empty_fill)
				P.pattern(self, pos, DIA_O if fin else SQ_O, empty_edge)
			x += 24.0


## E: uzun kart - dış çizgisiz yuvarlak gövde (köşe 8 sanat px), üstte anlamlı renkte başlık bandı, altında gölge; üstündeyken altın çizgi.
class TallCard extends MarginContainer:
	const P := preload("res://tools/proto_20261107/kart_yumusak/px_draw.gd")
	var fill := Color.BLACK
	var band := Color.BLACK
	var band_h: float = 15.0
	var shadow := Color(0, 0, 0, 0)
	var focus := Color(0, 0, 0, 0)
	var r: int = 8
	var lifted: bool = false

	func _draw() -> void:
		var rc := Rect2(Vector2.ZERO, size)
		P.rrect(self, Rect2(0, 9.0 if lifted else 6.0, size.x, size.y), r, shadow)
		if focus.a > 0.0:
			P.rrect(self, rc.grow(3.0), r + 1, focus)
		P.rrect(self, rc, r, band)
		P.rrect(self, Rect2(0, band_h, size.x, size.y - band_h), r, fill)
		draw_rect(Rect2(0, band_h, size.x, r * 3.0), fill)


## F (ve E'nin simge kuyusu): piksel daire katmanları - gölge, dış hat, halka, iç disk; simge çocuk olarak ortada.
class Medal extends Control:
	const P := preload("res://tools/proto_20261107/kart_yumusak/px_draw.gd")
	var rad: float = 90.0
	var outline := Color(0, 0, 0, 0)
	var ring := Color(0, 0, 0, 0)
	var ring_w: float = 9.0
	var disc := Color.BLACK
	var shadow := Color(0, 0, 0, 0)

	func _draw() -> void:
		var c := Vector2(rad, rad)
		P.ellipse(self, c + Vector2(0, 6), rad, rad, shadow)
		var rr: float = rad
		if outline.a > 0.0:
			P.ellipse(self, c, rr, rr, outline)
			rr -= 3.0
		if ring.a > 0.0:
			P.ellipse(self, c, rr, rr, ring)
			rr -= ring_w
		P.ellipse(self, c, rr, rr, disc)


## v3 OVAL DİKEY KART gövdesi: köşe r sanat px (oval) ya da kemer (üst = yarım daire); top = gövdenin başladığı y (taşan madalyon için);
## band = üstte anlamlı renkte başlık bandı; edge = 1 sanat px kenar; focus = üstündeyken dışta altın çizgi; altında gölge.
class SoftCard extends MarginContainer:
	const P := preload("res://tools/proto_20261107/kart_yumusak/px_draw.gd")
	var fill := Color.BLACK
	var edge := Color(0, 0, 0, 0)
	var band := Color(0, 0, 0, 0)
	var band_h: float = 54.0
	var shadow := Color(0, 0, 0, 0)
	var focus := Color(0, 0, 0, 0)
	var r: int = 10
	var arch: bool = false
	var top: float = 0.0
	var lifted: bool = false

	func _shape(rc: Rect2, rr: int, col: Color) -> void:
		if col.a <= 0.0:
			return
		if arch:
			var rad: float = rc.size.x * 0.5
			P.ellipse(self, Vector2(rc.position.x + rad, rc.position.y + rad), rad, rad, col)
			_bottom(Rect2(rc.position.x, rc.position.y + rad, rc.size.x, rc.size.y - rad), rr, col)
		else:
			P.rrect(self, rc, rr, col)

	## Yalnız alt köşeleri yuvarlak dikdörtgen (kemerin altı / bandın altı).
	func _bottom(rc: Rect2, rr: int, col: Color) -> void:
		P.rrect(self, rc, rr, col)
		draw_rect(Rect2(rc.position.x, rc.position.y, rc.size.x, minf(rr * 3.0, rc.size.y * 0.5)), col)

	func _draw() -> void:
		var body := Rect2(0, top, size.x, size.y - top)
		_shape(Rect2(body.position + Vector2(0, 9.0 if lifted else 6.0), body.size), r, shadow)
		if focus.a > 0.0:
			_shape(body.grow(3.0), r + 1, focus)
		var inner := body
		var ir: int = r
		if edge.a > 0.0:
			_shape(body, r, edge)
			inner = body.grow(-3.0)
			ir = r - 1
		if band.a > 0.0 and not arch:
			_shape(inner, ir, band)
			_bottom(Rect2(inner.position.x, inner.position.y + band_h, inner.size.x, inner.size.y - band_h), ir, fill)
		else:
			_shape(inner, ir, fill)


## ---------------------------------------------------------------- kurulum
func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _out() -> String:
	var d: String = OS.get_environment("KART_YUMUSAK_DIR")
	if d == "":
		d = ProjectSettings.globalize_path("res://tools/proto_20261107/kart_yumusak/out")
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	img.save_png(_out().path_join(file))
	shots.append(file)
	print("SHOT %s" % file)


func _run() -> void:
	await process_frame
	GM = root.get_node("GameManager")
	UIK = load("res://scripts/ui_kit.gd")
	SE = load("res://scripts/skill_evolutions.gd")
	Chars = load("res://scripts/characters.gd")
	LSC = load("res://scripts/level_special_cards.gd")
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
	p.set("level", EVO_LEVEL)
	var owned := {}
	for id: String in OWNED:
		owned[id] = true
	p.set("skill_evolutions", owned)
	await _wait(1.0)
	var only: String = OS.get_environment("KART_YUMUSAK_ONLY")
	var keys: Array = []
	## v1 (A-D) "hepsi neredeyse aynı" diye reddedildi, v2 (E-H) sonrası kullanıcı: "oval kenarlı dikey kart, level kartında başlık"
	## -> varsayılan v3 (I-L); eskiler -Only ile yine çekilebilir.
	## M = kullanıcı 2026-11-08 madde 394 "C - Artı / Eksi"yi seçti, "envanter gibi kahverengimsi" -> level'da OYUNUN kapalı C sütunu
	## (level_market_view.gd "cards" kipi, PAL_WOOD) gerçek kodla, evrimde aynı dilde sütun; yalnız -Only "M" ile.
	## N = kullanıcı 2026-11-08: "eski efsun kartını hafif oval kenarlı ve envanterdeki pencereye benzer şekilde tasarlar mısın" (yalnız evrim).
	for key: String in ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N"]:
		if (only == "" and key >= "I" and key < "M") or only.contains(key):
			keys.append(key)

	## ---- 1) YETENEK EVRİMİ ekranı
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
		evo_data.append(_evo_entry(e, owned))
	screen.set("_evo_offers", evo_offers)
	screen.call("_populate_evolution_rows")
	await _wait(1.0)
	await _shot("0_evrim.png")
	var evo_row: Control = screen.get_node_or_null("EvoCards") as Control
	if evo_row:
		print("VERI bugün EvoCards %s" % str(evo_row.get_global_rect()))
		evo_row.visible = false
	_make_host()
	for key: String in keys:
		_prep_screen(key)
		var proto: Control = call("_evo_" + key)
		await _place(proto, EVO_TOP, false, key == "G")
		if key == "N":
			await _n_hover_anim()
		print("VERI %s evrim %s" % [key, str(proto.get_rect())])
		await _shot("%s_evrim.png" % key)
		proto.queue_free()
		await process_frame
	screen.queue_free()
	main.set("_active_level_up_screen", null)
	paused = false
	await _wait(0.8)

	## ---- 2) LEVEL ATLAMA ekranı (21. seviye: evrim seviyesi değil)
	seed(20261107)
	main.call("_show_level_up_screen", 21)
	await _wait(1.6)
	screen = main.get_node_or_null("LevelUpScreen")
	if screen == null:
		print("!! level ekranı açılmadı")
		quit()
		return
	var consts: Dictionary = (screen.get_script() as GDScript).get_script_constant_map()
	tier_hi = consts["ROW_TIER_TEXT"]
	_level_entries(consts)
	await _wait(0.8)
	await _shot("0_level.png")
	var rows: Control = screen.get_node_or_null("Rows") as Control
	if rows:
		print("VERI bugün Rows %s x%.2f" % [str(rows.get_global_rect()), rows.scale.x])
		rows.visible = false
	_make_host()
	for key: String in keys:
		_prep_screen(key)
		if key == "N":
			continue ## yalnız evrim kartı
		if key == "M":
			await _level_M_real()
			continue
		var proto: Control = call("_level_" + key)
		await _place(proto, 0.0, true, key == "G")
		print("VERI %s level %s" % [key, str(proto.get_rect())])
		await _shot("%s_level.png" % key)
		proto.queue_free()
		await process_frame
	print("VERI bitti %s" % str(shots))
	quit()


var _dim_alpha: float = -1.0


## G (HUD tepsisi) oyunun büyük başlığını + Karıştır'ı kendi tepsisine alır ve karartmayı açar; diğerlerinde ekran olduğu gibi.
func _prep_screen(key: String) -> void:
	var g: bool = key == "G"
	var title: CanvasItem = screen.get_node_or_null("Title") as CanvasItem
	if title:
		title.visible = not g and key != "M"
	var rb: CanvasItem = screen.get("reroll_button") as CanvasItem
	if rb and not bool(screen.get("_evo_mode")):
		rb.visible = not g
	var dim: ColorRect = screen.get_node_or_null("Dim") as ColorRect
	if dim:
		if _dim_alpha < 0.0:
			_dim_alpha = dim.color.a
		dim.color.a = 0.22 if g else _dim_alpha


func _make_host() -> void:
	_dim_alpha = -1.0
	host = Control.new()
	host.name = "YumusakProto"
	host.theme = UIK.call("theme")
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(host)


## Prototipi yerleştirir: yatay ortalı (3 px ızgarada); level'da bugünkü sütunun dikey ortasına, evrimde bugünkü üst çizgiye.
func _place(proto: Control, top: float, center_y: bool, bottom: bool = false) -> void:
	host.add_child(proto)
	await process_frame
	await process_frame
	await process_frame
	var sz: Vector2 = proto.get_combined_minimum_size()
	proto.size = sz
	var y: float = top
	if bottom:
		y = roundf((TRAY_BOTTOM - sz.y) / 3.0) * 3.0
	elif proto.name == "EvoColumnM":
		y = roundf((1080.0 - sz.y) * 0.5 / 3.0) * 3.0 ## oyunun C sütunu gibi ekranın ortasında
	elif center_y:
		y = roundf((LEVEL_MID_Y - sz.y * 0.5) / 3.0) * 3.0
	proto.position = Vector2(roundf((1920.0 - sz.x) * 0.5 / 3.0) * 3.0, y)
	await _wait(0.35)


## ---------------------------------------------------------------- veri
func _evo_entry(e: Dictionary, owned: Dictionary) -> Dictionary:
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


## Sabit 3 kart: hem ekranın kendi satırlarına (ŞU AN çekimi aynı içerikle) hem prototip verisine.
func _level_entries(consts: Dictionary) -> void:
	var ups: Array = consts["UPGRADES"]
	var cards: Array = screen.get("cards")
	for i in LEVEL_CARDS.size():
		var id: String = LEVEL_CARDS[i][0]
		var tier: int = LEVEL_CARDS[i][1]
		var u: Dictionary = {}
		if id.begins_with("trade_") or id.begins_with("class_"):
			u = LSC.call("as_card", id)
			u["color"] = consts["CAT_ATTACK"] if str(u["kind"]) == "class" else consts["CAT_UTILITY"]
		else:
			for x: Dictionary in ups:
				if str(x["id"]) == id:
					u = x.duplicate()
		var d := {"u": u, "tier": tier, "icon": str(u.get("icon", u["id"])), "color": u["color"], "title": str(u["title"]),
			"bb": str(screen.call("card_sentence", u, tier)), "tcol": tier_hi[tier - 1]}
		lvl_data.append(d)
		var card: Button = cards[i]
		(card.get_node("Content/Icon") as Control).call("setup", d["icon"], d["color"])
		screen.call("_apply_card_tier_frame", card, tier)
		screen.call("_fill_row", card, u, tier, 0)


func _tier_text(d: Dictionary) -> String:
	return "FİNAL EVRİM" if d["final"] else "EVRİM %d/%d" % [int(d["owned"]) + 1, int(d["total"])]


func _evo_col(d: Dictionary) -> Color:
	return HT.EVO_FINAL_EDGE if d["final"] else HT.EVO_EDGE


## Anlamlı rengi (kademe / evrim) zemine doğru kısar.
func _mute(c: Color, t: float, toward: Color = HT.WIN_PANEL2) -> Color:
	return c.lerp(toward, t)


## ---------------------------------------------------------------- ortak parçalar
func _lbl(text: String, fs: int, col: Color, w: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if w > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = w
	return l


func _rtl(bb: String, fs: int, col: Color, w: float, center: bool = false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size.x = w
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
		r.add_theme_font_size_override(key, fs)
	r.add_theme_color_override("default_color", col)
	r.add_theme_constant_override("line_separation", 4)
	r.text = ("[center]%s[/center]" if center else "%s") % bb
	return r


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _margins(m: MarginContainer, l: float, t: float, r: float, b: float) -> void:
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", int(l))
	m.add_theme_constant_override("margin_top", int(t))
	m.add_theme_constant_override("margin_right", int(r))
	m.add_theme_constant_override("margin_bottom", int(b))


## Üstündeki seçenek 1 sanat px kalkar (ölçek yok): sarmalayıcı payı üstten alta geçer.
func _lift(c: Control, hov: bool) -> MarginContainer:
	var m := MarginContainer.new()
	_margins(m, 0, 0 if hov else 3, 0, 3 if hov else 0)
	m.add_child(c)
	return m


## Oyunun kademe kutusu (piksel kutu, madde 417): StyleBoxFlat adlı özellikler + içerik payı.
func _sb(fill: Color, border: Color, bw: int, r: int, pad: float) -> StyleBox:
	var sbx: StyleBox = (load("res://scripts/pixel_box.gd") as GDScript).new()
	sbx.set("bg_color", fill)
	sbx.set("border_color", border)
	for side: String in ["left", "top", "right", "bottom"]:
		sbx.set("border_width_" + side, bw)
	for c: String in ["top_left", "top_right", "bottom_right", "bottom_left"]:
		sbx.set("corner_radius_" + c, r)
	sbx.content_margin_left = pad
	sbx.content_margin_top = pad
	sbx.content_margin_right = pad
	sbx.content_margin_bottom = pad
	return sbx


func _stat_icon(d: Dictionary, s: float) -> Control:
	var ic: Control = (load("res://scripts/stat_icon.gd") as GDScript).new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.custom_minimum_size = Vector2(s, s)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.call("setup", str(d["icon"]), d["color"])
	return ic


## Level satırının içi: simge tutucu + dikeyde ortalı renkli tek cümle (m5x7 32, en çok 2 satır).
func _row_hbox(holder: Control, bb: String, text_w: float) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 24)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(holder)
	var t := _rtl(bb, 32, HT.TEXT, text_w)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(t)
	return hb


## Evrim simge yuvası: kind "none" (bugünkü gibi çerçevesiz) / "box" (gömme kuyu) / "patch" (kumaş yama) / "pool" (ışık havuzu).
## Tuş kapağı simgenin sağ alt köşesinden 12 px taşar (bugünkü gibi).
func _evo_slot(d: Dictionary, kind: String, edge: Color, hov: bool) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var well: float = 174.0 if kind == "box" or kind == "patch" else 144.0
	var out: float = 12.0
	var wx: float = out
	var hsize := Vector2(well + 2.0 * out, well + out)
	if kind == "pool":
		hsize = Vector2(270.0, 174.0)
		wx = (270.0 - 144.0) * 0.5
		var pool := Pool.new()
		pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pool.light = Color(HT.ACCENT, 0.16 if hov else 0.1)
		pool.ring = edge
		pool.rx = 126.0
		pool.ry = 27.0
		pool.base_y = 141.0
		holder.add_child(pool)
		pool.position = Vector2.ZERO
		pool.size = hsize
	elif kind == "box":
		var pnl := Panel.new()
		pnl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pnl.add_theme_stylebox_override("panel", _sb(HT.WIN_INSET, edge, 3, 9, 0.0))
		holder.add_child(pnl)
		pnl.position = Vector2(wx, 0)
		pnl.size = Vector2.ONE * well
	elif kind == "patch":
		var pt := Patch.new()
		pt.cloth = HT.WIN_PANEL2
		pt.lo = HT.WIN_INSET
		pt.hi = HT.WIN_PANEL2.lerp(HT.RIM_LO, 0.5)
		pt.outline = HT.OUTLINE
		pt.thread = edge
		pt.r = 5
		pt.stitch_inset = 9.0
		holder.add_child(pt)
		pt.position = Vector2(wx, 0)
		pt.size = Vector2.ONE * well
	holder.custom_minimum_size = hsize
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = d["icon"]
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(icon)
	var inset: float = (well - 144.0) * 0.5 if kind != "pool" else 0.0
	icon.position = Vector2(wx + inset, inset)
	icon.size = Vector2.ONE * 144.0
	var cap := KeyCap.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.key = str(d["key"])
	cap.box = UIK.call("button_style", "hud", "normal", true)
	holder.add_child(cap)
	## Kuyunun (yoksa simgenin) sağ alt köşesinden taşar.
	cap.position = Vector2(wx + well - 48.0 + out, well - 48.0 + out)
	cap.size = Vector2.ONE * 48.0
	return holder


## Evrim kartının içeriği (bugünkü sıra ve boylar): yuva, EVRİM n/N, yetenek adı, pipler, ad 48, açıklama 32.
func _evo_body(d: Dictionary, slot: Control, inner_w: float, done_col: Color, cross: bool) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_theme_constant_override("separation", 0)
	b.add_child(slot)
	b.add_child(_gap(12))
	b.add_child(_lbl(_tier_text(d), 32, HT.ACCENT_SOFT))
	b.add_child(_lbl(str(d["skill"]), 32, HT.DIM))
	b.add_child(_gap(12))
	var pips := Pips.new()
	pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var have: int = int(d["total"]) - 1 if d["final"] else int(d["owned"])
	pips.setup(int(d["total"]), have, done_col, HT.ACCENT_SOFT, HT.WIN_LINE_HI if cross else HT.WIN_LINE, HT.WIN_INSET, cross)
	b.add_child(pips)
	b.add_child(_gap(18))
	b.add_child(_lbl(str(d["name"]), 48, HT.TEXT, inner_w))
	b.add_child(_gap(12))
	var desc_bb: String = str(screen.call("_evo_desc_bbcode", str(d["desc"]), HT.ACCENT_SOFT))
	b.add_child(_rtl(desc_bb, 32, HT.DIM, inner_w, true))
	return b


## ================================================================ A - Sıcak Kapsül
func _capsule(hov: bool, edge: Color) -> Capsule:
	var c := Capsule.new()
	c.fill = HT.WIN_PANEL3 if hov else HT.WIN_PANEL2
	c.edge = HT.ACCENT if hov else edge
	c.shadow = Color(HT.DEEP, 0.5)
	c.r = 4
	c.lifted = hov
	return c


func _level_A() -> Control:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 21)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var hov: bool = i == HOVER
		var c := _capsule(hov, _mute(d["tcol"], 0.35))
		c.custom_minimum_size = Vector2(ROW_W, ROW_H)
		_margins(c, 24, 0, 24, 0)
		c.add_child(_row_hbox(_stat_icon(d, 72.0), d["bb"], ROW_W - 48.0 - 72.0 - 24.0))
		col.add_child(_lift(c, hov))
	return col


func _evo_A() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 36)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		var edge: Color = _mute(_evo_col(d), 0.3)
		var c := _capsule(hov, edge)
		c.custom_minimum_size = Vector2(480, 0)
		_margins(c, 30, 30, 30, 30)
		c.add_child(_evo_body(d, _evo_slot(d, "none", edge, hov), 420.0, edge, false))
		row.add_child(_lift(c, hov))
	return row


## ================================================================ B - Tek Pencere
func _window(pad: float) -> PanelContainer:
	var win := PanelContainer.new()
	win.mouse_filter = Control.MOUSE_FILTER_IGNORE
	win.add_theme_stylebox_override("panel", _sb(Color(HT.WIN_PANEL, 0.96), HT.WIN_LINE, 3, 9, pad))
	return win


func _level_B() -> Control:
	var win := _window(18.0)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 12)
	win.add_child(col)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var hov: bool = i == HOVER
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sbr: StyleBox = _sb(HT.WIN_PANEL3 if hov else HT.WIN_INSET, HT.ACCENT if hov else HT.WIN_LINE, 3, 6, 0.0)
		sbr.content_margin_left = 15.0
		sbr.content_margin_right = 15.0
		sbr.content_margin_top = 9.0
		sbr.content_margin_bottom = 9.0
		row.add_theme_stylebox_override("panel", sbr)
		row.custom_minimum_size = Vector2(708, 108)
		var medal := PanelContainer.new()
		medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		medal.add_theme_stylebox_override("panel", _sb(HT.WIN_PANEL2, _mute(d["tcol"], 0.25), 3, 18, 9.0))
		medal.add_child(_stat_icon(d, 72.0))
		row.add_child(_row_hbox(medal, d["bb"], 708.0 - 30.0 - 90.0 - 24.0))
		col.add_child(row)
	return win


func _evo_B() -> Control:
	var win := _window(18.0)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	win.add_child(row)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		if i > 0:
			var dm := MarginContainer.new()
			_margins(dm, 18, 12, 18, 12)
			var line := ColorRect.new()
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			line.color = HT.WIN_LINE
			line.custom_minimum_size = Vector2(3, 0)
			dm.add_child(line)
			row.add_child(dm)
		var colw := PanelContainer.new()
		colw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if hov:
			colw.add_theme_stylebox_override("panel", _sb(HT.WIN_PANEL3, HT.ACCENT, 3, 9, 18.0))
		else:
			var e := StyleBoxEmpty.new()
			e.set_content_margin_all(18.0)
			colw.add_theme_stylebox_override("panel", e)
		var edge: Color = _mute(_evo_col(d), 0.25)
		colw.add_child(_evo_body(d, _evo_slot(d, "box", edge, hov), 420.0, edge, false))
		row.add_child(colw)
	return win


## ================================================================ C - Dikişli Kumaş
func _patch(hov: bool, thread: Color) -> Patch:
	var p := Patch.new()
	var cloth: Color = HT.WIN_PANEL3.lerp(HT.PANEL, 0.3) if hov else HT.WIN_PANEL3
	p.cloth = cloth
	p.hi = cloth.lerp(HT.RIM, 0.45)
	p.lo = HT.WIN_PANEL2
	p.outline = HT.OUTLINE
	p.thread = HT.ACCENT if hov else thread
	p.shadow = Color(HT.DEEP, 0.4)
	p.lifted = hov
	p.r = 4
	p.stitch_inset = 9.0
	return p


func _level_C() -> Control:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 21)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var hov: bool = i == HOVER
		var p := _patch(hov, _mute(d["tcol"], 0.2, HT.WIN_PANEL3))
		p.custom_minimum_size = Vector2(ROW_W, ROW_H)
		_margins(p, 24, 0, 27, 0)
		## Simge: dikişsiz koyu aplike yama (iç içe ikinci dikiş kalabalık).
		var ap := Patch.new()
		ap.cloth = HT.WIN_PANEL2
		ap.lo = HT.WIN_INSET
		ap.hi = HT.WIN_PANEL2.lerp(HT.RIM_LO, 0.5)
		ap.outline = HT.OUTLINE
		ap.r = 4
		ap.custom_minimum_size = Vector2(90, 90)
		_margins(ap, 9, 9, 9, 9)
		ap.add_child(_stat_icon(d, 72.0))
		p.add_child(_row_hbox(ap, d["bb"], ROW_W - 51.0 - 90.0 - 24.0))
		col.add_child(_lift(p, hov))
	return col


func _evo_C() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 30)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		var thread: Color = _mute(_evo_col(d), 0.2, HT.WIN_PANEL3)
		var p := _patch(hov, thread)
		p.r = 5
		p.custom_minimum_size = Vector2(480, 0)
		_margins(p, 36, 36, 36, 36)
		p.add_child(_evo_body(d, _evo_slot(d, "patch", thread, hov), 408.0, thread, true))
		row.add_child(_lift(p, hov))
	return row


## ================================================================ D - Ocak Işığı
func _band(col: Color, steps: int, step_px: float, r: int) -> Band:
	var b := Band.new()
	b.col = col
	b.steps = steps
	b.step_px = step_px
	b.r = r
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _level_D() -> Control:
	var back := _band(Color(HT.DEEP, 0.17), 4, 9.0, 10)
	_margins(back, 36, 30, 36, 30)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	back.add_child(col)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var hov: bool = i == HOVER
		if i > 0:
			var rm := MarginContainer.new()
			_margins(rm, 48, 9, 48, 9)
			var rule := Rule.new()
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rule.col = HT.WIN_LINE
			rule.custom_minimum_size = Vector2(0, 3)
			rm.add_child(rule)
			col.add_child(rm)
		var g := _band(Color(HT.WIN_PANEL3, 0.5) if hov else Color(0, 0, 0, 0), 3, 6.0, 6)
		g.custom_minimum_size = Vector2(ROW_W, 114)
		_margins(g, 21, 0, 24, 0)
		var pool := Pool.new()
		pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pool.custom_minimum_size = Vector2(108, 93)
		## Işık = sıcak altın, 3 basamak üst üste (SPOT'un kısığı kahverengi toprak lekesi gibi okundu). Stat simgelerinin altında
		## boşluk var -> havuz simge kutusunun altına değil, çiziminin ayağına (63).
		pool.light = Color(HT.ACCENT, 0.16 if hov else 0.1)
		pool.ring = _mute(d["tcol"], 0.25)
		pool.rx = 54.0
		pool.ry = 15.0
		pool.base_y = 63.0
		var ic := _stat_icon(d, 72.0)
		pool.add_child(ic)
		ic.position = Vector2(18, 0)
		ic.size = Vector2(72, 72)
		g.add_child(_row_hbox(pool, d["bb"], ROW_W - 45.0 - 108.0 - 24.0))
		col.add_child(g)
	return back


func _evo_D() -> Control:
	var back := _band(Color(HT.DEEP, 0.17), 4, 9.0, 10)
	_margins(back, 30, 30, 30, 30)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 0)
	back.add_child(row)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		if i > 0:
			var rm := MarginContainer.new()
			_margins(rm, 12, 36, 12, 36)
			var rule := Rule.new()
			rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rule.col = HT.WIN_LINE
			rule.vertical = true
			rule.custom_minimum_size = Vector2(3, 0)
			rm.add_child(rule)
			row.add_child(rm)
		var g := _band(Color(HT.WIN_PANEL3, 0.5) if hov else Color(0, 0, 0, 0), 3, 6.0, 8)
		g.custom_minimum_size = Vector2(462, 0)
		_margins(g, 21, 24, 21, 30)
		var edge: Color = _mute(_evo_col(d), 0.25)
		g.add_child(_evo_body(d, _evo_slot(d, "pool", edge, hov), 420.0, edge, false))
		row.add_child(g)
	return back


## ================================================================ v2 (kullanıcı v1 için: "bunların hepsi aynı neredeyse beğenmedim")
## v1'in dördü de aynı yerleşimdeydi (alt alta 3 satır / yan yana 3 dikey kart), yalnız çerçeve değişiyordu. v2'de ŞEKİL ve YERLEŞİM farklı:
##   E Uzun Kart   - level kartları da evrim gibi yan yana DİKEY kart: çizgisiz yuvarlak gövde + üstte kademe/evrim renginde başlık bandı
##   F Madalyon    - YUVARLAK: simge piksel daire madalyonda (halka = kademe/evrim rengi), yazı altında kutusuz (Stardew gibi yazı gölgesi)
##   G HUD Tepsisi - ekranın ALTINDA, HUD panelinin üstünde HUD'un kendi dokularıyla (hud_plaque / hud_inset) tek tepsi; başlık + Karıştır
##                   tepsinin içinde, karartma hafif -> oyun görünür kalır
##   H Odak        - ortada BÜYÜK seçili kart (simge 144, cümle 48), yanlarda küçük ve sönük kartlar; evrimde açıklama yalnız odakta

func _shadow_text(n: Node) -> void:
	for c in n.find_children("*", "", true, false):
		if c is Label or c is RichTextLabel:
			(c as Control).add_theme_color_override("font_shadow_color", Color(HT.DEEP, 0.9))
			(c as Control).add_theme_constant_override("shadow_offset_x", 2)
			(c as Control).add_theme_constant_override("shadow_offset_y", 2)


func _medal(rad: float, ring: Color, outline: Color, disc: Color, shadow: Color) -> Medal:
	var m := Medal.new()
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.rad = rad
	m.ring = ring
	m.outline = outline
	m.disc = disc
	m.shadow = shadow
	m.custom_minimum_size = Vector2(2.0 * rad, 2.0 * rad + (6.0 if shadow.a > 0.0 else 0.0))
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return m


func _icon_medal(d: Dictionary, rad: float, icon: float, ring: Color, outline: Color, disc: Color, shadow: Color) -> Medal:
	var m := _medal(rad, ring, outline, disc, shadow)
	var ic := _stat_icon(d, icon)
	m.add_child(ic)
	ic.position = Vector2.ONE * (rad - icon * 0.5)
	ic.size = Vector2.ONE * icon
	return m


## Evrim simgesi + tuş kapağı (küçük: simge 96 = 48 sanat px x2).
func _evo_icon_small(d: Dictionary, s: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.custom_minimum_size = Vector2(s + 12.0, s + 12.0)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = d["icon"]
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	holder.add_child(icon)
	icon.position = Vector2.ZERO
	icon.size = Vector2.ONE * s
	var cap := KeyCap.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.key = str(d["key"])
	cap.box = UIK.call("button_style", "hud", "normal", true)
	holder.add_child(cap)
	cap.position = Vector2.ONE * (s - 36.0)
	cap.size = Vector2.ONE * 48.0
	return holder


## ---------------------------------------------------------------- E - Uzun Kart
func _tall(hov: bool, band: Color) -> TallCard:
	var c := TallCard.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.fill = HT.WIN_PANEL3 if hov else HT.WIN_PANEL2
	c.band = band
	c.shadow = Color(HT.DEEP, 0.5)
	c.focus = HT.ACCENT if hov else Color(0, 0, 0, 0)
	c.lifted = hov
	return c


func _level_E() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 30)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var hov: bool = i == HOVER
		var c := _tall(hov, _mute(d["tcol"], 0.3))
		c.custom_minimum_size = Vector2(300, 0)
		_margins(c, 24, 39, 24, 27)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		v.add_child(_icon_medal(d, 66.0, 96.0, Color(0, 0, 0, 0), Color(0, 0, 0, 0), HT.WIN_INSET, Color(0, 0, 0, 0)))
		v.add_child(_gap(18))
		v.add_child(_rtl(d["bb"], 32, HT.TEXT, 252.0, true))
		c.add_child(v)
		row.add_child(_lift(c, hov))
	return row


func _evo_E() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 36)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		var edge: Color = _mute(_evo_col(d), 0.25)
		var c := _tall(hov, edge)
		c.band_h = 18.0
		c.custom_minimum_size = Vector2(480, 0)
		_margins(c, 30, 42, 30, 30)
		c.add_child(_evo_body(d, _evo_slot(d, "none", edge, hov), 420.0, edge, false))
		row.add_child(_lift(c, hov))
	return row


## ---------------------------------------------------------------- F - Madalyon
func _level_F() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 42)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var hov: bool = i == HOVER
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		v.add_child(_icon_medal(d, 90.0, 96.0, _mute(d["tcol"], 0.3), HT.ACCENT if hov else HT.OUTLINE,
			HT.WIN_PANEL3 if hov else HT.WIN_PANEL2, Color(HT.DEEP, 0.5)))
		v.add_child(_gap(15))
		v.add_child(_rtl(d["bb"], 32, HT.TEXT, 330.0, true))
		_shadow_text(v)
		row.add_child(_lift(v, hov))
	return row


func _evo_F() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 48)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		var ring: Color = _mute(_evo_col(d), 0.25)
		var m := _medal(114.0, ring, HT.ACCENT if hov else HT.OUTLINE, HT.WIN_PANEL3 if hov else HT.WIN_PANEL2, Color(HT.DEEP, 0.5))
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = d["icon"]
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		m.add_child(icon)
		icon.position = Vector2.ONE * (114.0 - 72.0)
		icon.size = Vector2.ONE * 144.0
		var cap := KeyCap.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.key = str(d["key"])
		cap.box = UIK.call("button_style", "hud", "normal", true)
		m.add_child(cap)
		cap.position = Vector2.ONE * (228.0 - 60.0)
		cap.size = Vector2.ONE * 48.0
		var body := _evo_body(d, m, 420.0, ring, false)
		body.custom_minimum_size.x = 420.0
		_shadow_text(body)
		row.add_child(_lift(body, hov))
	return row


## ---------------------------------------------------------------- G - HUD Tepsisi
func _hud_box(kind: String, pad: float) -> StyleBox:
	var s: StyleBox = (UIK.call("panel_style", kind) as StyleBox).duplicate()
	s.content_margin_left = pad
	s.content_margin_top = pad
	s.content_margin_right = pad
	s.content_margin_bottom = pad
	return s


func _tray(title: String, reroll: bool) -> Array:
	var tray := PanelContainer.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_theme_stylebox_override("panel", _hud_box("hud_plaque", 18.0))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 12)
	tray.add_child(v)
	var hb := HBoxContainer.new()
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_theme_constant_override("separation", 18)
	var t := _lbl(title, 32, HT.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(t)
	var sp := Control.new()
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	if reroll:
		var b := PanelContainer.new()
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bs: StyleBox = (UIK.call("button_style", "hud", "normal", false) as StyleBox).duplicate()
		bs.content_margin_left = 18.0
		bs.content_margin_right = 18.0
		bs.content_margin_top = 6.0
		bs.content_margin_bottom = 9.0
		b.add_theme_stylebox_override("panel", bs)
		b.add_child(_lbl("Karıştır (ÜCRETSİZ)", 32, HT.TEXT))
		hb.add_child(b)
	v.add_child(hb)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	return [tray, row]


func _tray_slot(hov: bool, w: float, pad: float) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _sb(HT.PLATE_ON, HT.ACCENT, 3, 6, pad) if hov else _hud_box("hud_inset_tight", pad))
	slot.custom_minimum_size = Vector2(w, 0)
	return slot


func _level_G() -> Control:
	var tr: Array = _tray("SEVİYE ATLADIN!", true)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var hov: bool = i == HOVER
		var slot := _tray_slot(hov, 420.0, 12.0)
		var medal := _icon_medal(d, 45.0, 72.0, _mute(d["tcol"], 0.3), HT.OUTLINE, HT.INSET, Color(0, 0, 0, 0))
		slot.add_child(_row_hbox(medal, d["bb"], 420.0 - 24.0 - 90.0 - 24.0))
		(tr[1] as Control).add_child(slot)
	return tr[0]


func _evo_G() -> Control:
	var tr: Array = _tray("YETENEK EVRİMİ!", false)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		var edge: Color = _mute(_evo_col(d), 0.25)
		var slot := _tray_slot(hov, 456.0, 18.0)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_theme_constant_override("separation", 0)
		var top := HBoxContainer.new()
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_theme_constant_override("separation", 18)
		top.add_child(_evo_icon_small(d, 96.0))
		var info := VBoxContainer.new()
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		info.add_theme_constant_override("separation", 3)
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for spec: Array in [[_tier_text(d), HT.ACCENT_SOFT], [str(d["skill"]), HT.DIM]]:
			var l := _lbl(spec[0], 32, spec[1])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			info.add_child(l)
		var pips := Pips.new()
		pips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pips.setup(int(d["total"]), int(d["total"]) - 1 if d["final"] else int(d["owned"]), edge, HT.ACCENT_SOFT, HT.WIN_LINE, HT.WIN_INSET, false)
		info.add_child(_gap(6))
		info.add_child(pips)
		top.add_child(info)
		col.add_child(top)
		col.add_child(_gap(12))
		var nm := _lbl(str(d["name"]), 48, HT.TEXT, 420.0)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(nm)
		col.add_child(_gap(6))
		col.add_child(_rtl(str(screen.call("_evo_desc_bbcode", str(d["desc"]), HT.ACCENT_SOFT)), 32, HT.DIM, 420.0))
		slot.add_child(col)
		(tr[1] as Control).add_child(slot)
	return tr[0]


## ---------------------------------------------------------------- H - Odak
func _focus_card(big: bool, edge: Color, w: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _sb(HT.WIN_PANEL3, edge, 3, 12, 30.0) if big else _sb(HT.WIN_PANEL2, edge, 3, 9, 18.0))
	card.custom_minimum_size = Vector2(w, 0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not big:
		card.modulate = Color(1, 1, 1, 0.55)
	return card


func _level_H() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 24)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var big: bool = i == HOVER
		var card := _focus_card(big, _mute(d["tcol"], 0.2 if big else 0.35), 540.0 if big else 300.0)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		v.add_child(_stat_icon(d, 144.0 if big else 72.0))
		v.add_child(_gap(18.0 if big else 12.0))
		v.add_child(_rtl(d["bb"], 48 if big else 32, HT.TEXT, 480.0 if big else 264.0, true))
		card.add_child(v)
		row.add_child(card)
	return row


func _evo_H() -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 24)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var big: bool = i == HOVER
		var edge: Color = _mute(_evo_col(d), 0.2 if big else 0.35)
		var card := _focus_card(big, edge, 540.0 if big else 330.0)
		if big:
			card.add_child(_evo_body(d, _evo_slot(d, "none", edge, true), 480.0, edge, false))
		else:
			var v := VBoxContainer.new()
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_theme_constant_override("separation", 0)
			v.add_child(_evo_icon_small(d, 96.0))
			v.add_child(_gap(12))
			v.add_child(_lbl(_tier_text(d), 32, HT.ACCENT_SOFT))
			v.add_child(_lbl(str(d["skill"]), 32, HT.DIM))
			v.add_child(_gap(9))
			var pips := Pips.new()
			pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			pips.setup(int(d["total"]), int(d["total"]) - 1 if d["final"] else int(d["owned"]), edge, HT.ACCENT_SOFT, HT.WIN_LINE, HT.WIN_INSET, false)
			v.add_child(pips)
			v.add_child(_gap(12))
			v.add_child(_lbl(str(d["name"]), 32, HT.TEXT, 294.0))
			card.add_child(v)
		row.add_child(card)
	return row


## ================================================================ v3 OVAL DİKEY KART (kullanıcı v2 sonrası: "oval kenarlı dikey kart şeklinde
## olmasını istiyorum ikisinin de ... level atlama kartı geliştirmelerinin bir başlığı olsun"). Hepsi yan yana dikey, köşeler oval; level kartında
## BAŞLIK (UPGRADES "title" / özel kartın adı) + simge + renkli tek cümle. Dördü kartın ÜST kısmında ayrışır:
##   I Bantlı Kart     - üstte kısık kademe/evrim renginde bant, başlık bandın içinde
##   J Kemer Kart      - üstü yarım daire kemer (ev penceresi gibi), simge kemerin içinde yuvarlak kuyuda
##   K Madalyonlu Kart - yuvarlak madalyon kartın üst kenarından taşar (halka = kademe/evrim rengi), başlık altında
##   L Resimli Kart    - üstte kademe/evrim tonunda resim alanı + büyük simge; başlık levhası resim alanının alt kenarına biner
const V3_W := 330.0 ## level kartı: en uzun başlık "Bekleme Süresi Azaltma" 32'de 244 px, 48'de iki satır
const V3_INNER := 270.0
const NONE := Color(0, 0, 0, 0)


func _soft(hov: bool, edge: Color) -> SoftCard:
	var c := SoftCard.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.fill = HT.WIN_PANEL3 if hov else HT.WIN_PANEL2
	c.edge = edge
	c.shadow = Color(HT.DEEP, 0.5)
	c.focus = HT.ACCENT if hov else NONE
	c.lifted = hov
	return c


func _vbox() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	return v


func _cards_row(sep: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", sep)
	return row


## Evrim kartının orta bilgisi: EVRİM n/N + yetenek adı + pipler.
func _evo_info(d: Dictionary, edge: Color, v: VBoxContainer) -> void:
	v.add_child(_lbl(_tier_text(d), 32, HT.ACCENT_SOFT))
	v.add_child(_lbl(str(d["skill"]), 32, HT.DIM))
	v.add_child(_gap(12))
	var pips := Pips.new()
	pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pips.setup(int(d["total"]), int(d["total"]) - 1 if d["final"] else int(d["owned"]), edge, HT.ACCENT_SOFT, HT.WIN_LINE, HT.WIN_INSET, false)
	v.add_child(pips)


func _evo_desc(d: Dictionary, w: float) -> RichTextLabel:
	return _rtl(str(screen.call("_evo_desc_bbcode", str(d["desc"]), HT.ACCENT_SOFT)), 32, HT.DIM, w, true)


## Evrim simgesi (144) yuvarlak diskte + tuş kapağı; rad >= 102 (simgenin köşeleri diske sığar).
func _evo_disc(d: Dictionary, rad: float, ring: Color, outline: Color, disc: Color) -> Medal:
	var m := _medal(rad, ring, outline, disc, NONE)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = d["icon"]
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	m.add_child(icon)
	icon.position = Vector2.ONE * (rad - 72.0)
	icon.size = Vector2.ONE * 144.0
	var cap := KeyCap.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.key = str(d["key"])
	cap.box = UIK.call("button_style", "hud", "normal", true)
	m.add_child(cap)
	cap.position = Vector2.ONE * (2.0 * rad - 60.0)
	cap.size = Vector2.ONE * 48.0
	return m


## L: resim alanı (anlamlı rengin çok koyu tonu, kenarsız) + alt kenarına binen başlık levhası.
func _picture(tint: Color, w: float, h: float, child: Control) -> PanelContainer:
	var pic := PanelContainer.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.add_theme_stylebox_override("panel", _sb(tint.lerp(HT.WIN_INSET, 0.8), NONE, 0, 21, 0.0))
	pic.custom_minimum_size = Vector2(w, h)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(child)
	pic.add_child(cc)
	return pic


func _plaque(text: String, fs: int, overlap: float) -> MarginContainer:
	var pm := MarginContainer.new()
	_margins(pm, 0, -overlap, 0, 0)
	var plaque := PanelContainer.new()
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ps: StyleBox = _sb(HT.PANEL, HT.OUTLINE, 3, 15, 0.0)
	ps.content_margin_left = 24.0
	ps.content_margin_right = 24.0
	ps.content_margin_top = 3.0
	ps.content_margin_bottom = 6.0
	plaque.add_theme_stylebox_override("panel", ps)
	plaque.add_child(_lbl(text, fs, HT.TEXT))
	pm.add_child(plaque)
	return pm


## ---------------------------------------------------------------- I - Bantlı Kart
func _level_I() -> Control:
	var row := _cards_row(30)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var hov: bool = i == HOVER
		var c := _soft(hov, NONE)
		c.band = _mute(d["tcol"], 0.6)
		c.band_h = 54.0
		c.custom_minimum_size = Vector2(V3_W, 0)
		_margins(c, 30, 0, 30, 30)
		var v := _vbox()
		var t := _lbl(str(d["title"]), 32, HT.TEXT, V3_INNER)
		t.custom_minimum_size.y = 54.0
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(t)
		v.add_child(_gap(24))
		v.add_child(_icon_medal(d, 66.0, 96.0, NONE, NONE, HT.WIN_INSET, NONE))
		v.add_child(_gap(18))
		v.add_child(_rtl(d["bb"], 32, HT.TEXT, V3_INNER, true))
		c.add_child(v)
		row.add_child(_lift(c, hov))
	return row


func _evo_I() -> Control:
	var row := _cards_row(36)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		var edge: Color = _mute(_evo_col(d), 0.25)
		var c := _soft(hov, NONE)
		c.band = _mute(_evo_col(d), 0.55)
		c.band_h = 72.0
		c.custom_minimum_size = Vector2(480, 0)
		_margins(c, 30, 0, 30, 30)
		var v := _vbox()
		var t := _lbl(str(d["name"]), 48, HT.TEXT, 420.0)
		t.custom_minimum_size.y = 72.0
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(t)
		v.add_child(_gap(24))
		v.add_child(_evo_slot(d, "none", edge, hov))
		v.add_child(_gap(12))
		_evo_info(d, edge, v)
		v.add_child(_gap(18))
		v.add_child(_evo_desc(d, 420.0))
		c.add_child(v)
		row.add_child(_lift(c, hov))
	return row


## ---------------------------------------------------------------- J - Kemer Kart
func _level_J() -> Control:
	var row := _cards_row(30)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var hov: bool = i == HOVER
		var c := _soft(hov, _mute(d["tcol"], 0.35))
		c.arch = true
		c.r = 8
		c.custom_minimum_size = Vector2(V3_W, 0)
		_margins(c, 30, 36, 30, 30)
		var v := _vbox()
		v.add_child(_icon_medal(d, 66.0, 96.0, NONE, NONE, HT.WIN_INSET, NONE))
		v.add_child(_gap(24))
		v.add_child(_lbl(str(d["title"]), 48, HT.TEXT, V3_INNER))
		v.add_child(_gap(9))
		v.add_child(_rtl(d["bb"], 32, HT.TEXT, V3_INNER, true))
		c.add_child(v)
		row.add_child(_lift(c, hov))
	return row


func _evo_J() -> Control:
	var row := _cards_row(36)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		var edge: Color = _mute(_evo_col(d), 0.25)
		var c := _soft(hov, edge)
		c.arch = true
		c.r = 8
		c.custom_minimum_size = Vector2(480, 0)
		_margins(c, 30, 36, 30, 30)
		var v := _vbox()
		v.add_child(_evo_disc(d, 105.0, NONE, NONE, HT.WIN_INSET))
		v.add_child(_gap(18))
		_evo_info(d, edge, v)
		v.add_child(_gap(18))
		v.add_child(_lbl(str(d["name"]), 48, HT.TEXT, 420.0))
		v.add_child(_gap(12))
		v.add_child(_evo_desc(d, 420.0))
		c.add_child(v)
		row.add_child(_lift(c, hov))
	return row


## ---------------------------------------------------------------- K - Madalyonlu Kart
func _level_K() -> Control:
	var row := _cards_row(30)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var hov: bool = i == HOVER
		var c := _soft(hov, _mute(d["tcol"], 0.35))
		c.top = 72.0
		c.custom_minimum_size = Vector2(V3_W, 0)
		_margins(c, 30, 0, 30, 30)
		var v := _vbox()
		v.add_child(_icon_medal(d, 72.0, 96.0, _mute(d["tcol"], 0.3), HT.ACCENT if hov else HT.OUTLINE,
			HT.WIN_PANEL3 if hov else HT.WIN_PANEL2, NONE))
		v.add_child(_gap(12))
		v.add_child(_lbl(str(d["title"]), 48, HT.TEXT, V3_INNER))
		v.add_child(_gap(9))
		v.add_child(_rtl(d["bb"], 32, HT.TEXT, V3_INNER, true))
		c.add_child(v)
		row.add_child(_lift(c, hov))
	return row


func _evo_K() -> Control:
	var row := _cards_row(36)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		var edge: Color = _mute(_evo_col(d), 0.25)
		var c := _soft(hov, edge)
		c.top = 114.0
		c.custom_minimum_size = Vector2(480, 0)
		_margins(c, 30, 0, 30, 30)
		var v := _vbox()
		v.add_child(_evo_disc(d, 114.0, edge, HT.ACCENT if hov else HT.OUTLINE, HT.WIN_PANEL3 if hov else HT.WIN_PANEL2))
		v.add_child(_gap(12))
		_evo_info(d, edge, v)
		v.add_child(_gap(18))
		v.add_child(_lbl(str(d["name"]), 48, HT.TEXT, 420.0))
		v.add_child(_gap(12))
		v.add_child(_evo_desc(d, 420.0))
		c.add_child(v)
		row.add_child(_lift(c, hov))
	return row


## ---------------------------------------------------------------- L - Resimli Kart
func _level_L() -> Control:
	var row := _cards_row(30)
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var hov: bool = i == HOVER
		var c := _soft(hov, _mute(d["tcol"], 0.35))
		c.custom_minimum_size = Vector2(V3_W, 0)
		_margins(c, 18, 18, 18, 30)
		var v := _vbox()
		v.add_child(_picture(d["tcol"], V3_W - 36.0, 186.0, _stat_icon(d, 120.0)))
		v.add_child(_plaque(str(d["title"]), 32, 24.0))
		v.add_child(_gap(15))
		v.add_child(_rtl(d["bb"], 32, HT.TEXT, V3_INNER, true))
		c.add_child(v)
		row.add_child(_lift(c, hov))
	return row


func _evo_L() -> Control:
	var row := _cards_row(36)
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		var edge: Color = _mute(_evo_col(d), 0.25)
		var c := _soft(hov, edge)
		c.custom_minimum_size = Vector2(480, 0)
		_margins(c, 18, 18, 18, 30)
		var v := _vbox()
		v.add_child(_picture(_evo_col(d), 444.0, 216.0, _evo_slot(d, "none", edge, hov)))
		v.add_child(_plaque(str(d["name"]), 48, 30.0))
		v.add_child(_gap(15))
		_evo_info(d, edge, v)
		v.add_child(_gap(18))
		v.add_child(_evo_desc(d, 420.0))
		c.add_child(v)
		row.add_child(_lift(c, hov))
	return row


## ================================================================ M - C "Artı / Eksi" AHŞAP (kullanıcı 2026-11-08: madde 394 C prototipini
## gösterip "bu tasarımı beğendim fakat kahverengimsi olmasını istiyorum envanter panelinde olduğu gibi")
## Level: OYUNUN kendi kapalı C sütunu (level_up_screen.gd _build_market -> level_market_view.gd setup_cards "cards" kipi; COMPACT_CARD_COLUMN
## false olduğu için oyunda kapalı). Kit PAL_NIGHT = PAL_WOOD (madde 403) -> envanterle AYNI ahşap rolleri; ekranın mavimsi karartması
## (`_build_market` 0.02/0.02/0.04) sıcak karartmaya döner. Karşılaştırma için aynı çekimde envanter (M_envanter.png).
func _level_M_real() -> void:
	host.visible = false
	screen.call("_build_market")
	var mv: Control = screen.get("_market_view") as Control
	var cards: Array = screen.get("cards")
	for i in lvl_data.size():
		var d: Dictionary = lvl_data[i]
		var data: Dictionary = screen.call("_market_card_data", d["u"], d["tier"], 0)
		mv.call("fill_card", cards[i], data)
		## Madde 398'den beri düz kartlar bedelsiz -> 2. satır yalnız sönük "artar"/"azalır" kalıyordu; bedelsiz kartta gizli.
		if not bool(data["cost_red"]):
			var cost: CanvasItem = (cards[i] as Node).find_child("Cost", true, false) as CanvasItem
			if cost:
				cost.visible = false
	mv.call("_style_card", cards[HOVER], true) ## evrimdeki gibi 2. kart "üstünde"
	## Kullanıcı 2026-11-08: "simgelerin dışında çerçeve olmasını istemiyorum" -> sekizgen madalyon kutusu boş (simge çerçevesiz, yuva 48);
	## kademe rengi artık SATIRIN kenarında (%55, 1 sanat px), üstündeki satır yine altın. Renkler bugünkü level kartlarının ROW_TIER_TEXT'i
	## (gri/mavi/mor/kırmızımsı): C'nin TIER_RIM'inde Efsanevi ALTIN, satır kenarında "üstünde" altınıyla karışıyordu.
	var rim: Array = tier_hi
	## Kullanıcı 2026-11-08: "biraz daha büyük yapar mısın çerçeveleri yazılar çok sınıra yakın" -> satır iç payı 12/10 -> 21/15, satır 88 -> 108,
	## kartlar arası 8 -> 12, panel 380 -> 456 (en uzun başlık "Bekleme Süresi Azaltma" 244 px; yazı alanı artık 318).
	for i in lvl_data.size():
		var card: Control = cards[i] as Control
		card.custom_minimum_size.y = 108.0
		var med: Control = card.find_child("Medal", true, false) as Control
		if med:
			med.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			med.custom_minimum_size = Vector2(48, 48)
		var face: Control = card.find_child("MarketFace", true, false) as Control
		if face == null:
			continue
		var fsb: StyleBox = face.get_theme_stylebox("panel")
		fsb.content_margin_left = 21.0
		fsb.content_margin_right = 21.0
		fsb.content_margin_top = 15.0
		fsb.content_margin_bottom = 15.0
		if i == HOVER:
			continue
		fsb.set("border_color", Color(rim[int(lvl_data[i]["tier"]) - 1], 0.55))
		for side: String in ["left", "top", "right", "bottom"]:
			fsb.set("border_width_" + side, 3)
	## Kullanıcı 2026-11-08: "bir kart seç yazısı olmasın" -> başlıkta yalnız "SEVİYE N" (evrimde de "Bir evrim seç" yok).
	var mtitle: Node = mv.find_child("MarketTitle", true, false)
	if mtitle:
		for c in mtitle.get_parent().get_children():
			if c != mtitle:
				(c as CanvasItem).visible = false
	var cbox: Control = mv.get("_cards_box") as Control
	if cbox:
		cbox.add_theme_constant_override("separation", 12)
	var lcards: Control = mv.find_child("LevelCards", true, false) as Control
	if lcards:
		lcards.custom_minimum_size.x = 456.0
	## Kullanıcı 2026-11-08: "level kartında level kartı yazmasın" -> panelin "★ LEVEL KARTI" başlık satırı + altındaki boşluk gizli.
	var lcol: Node = mv.find_child("LevelCards", true, false)
	if lcol and lcol.get_child_count() > 0:
		var lvb: Node = lcol.get_child(0)
		for idx in [0, 1]:
			(lvb.get_child(idx) as CanvasItem).visible = false
	var dim: ColorRect = screen.get_node_or_null("Dim") as ColorRect
	if dim:
		dim.color = Color(0.12, 0.07, 0.03, 0.55) ## level ekranının kendi sıcak karartması (_apply_kit_style)
	await _wait(0.8)
	var lc: Control = mv.find_child("LevelCards", true, false) as Control
	if lc:
		print("VERI M level sütun %s" % str(lc.get_global_rect()))
	await _shot("M_level.png")
	var hud: Node = main.get("hud")
	if hud and hud.has_method("_on_envanter_toggle"):
		screen.visible = false
		hud.call("_on_envanter_toggle")
		await _wait(1.0)
		await _shot("M_envanter.png")
		hud.call("_on_envanter_toggle")
		screen.visible = true


## Evrim: aynı kit + aynı ölçüler (panel PAL_WOOD + line_hi kenar, "★ başlık", satır = yarı saydam kuyu, 64'lük sekizgen madalyon + 48 simge,
## başlık 32 + 24'lük satırlar); halka = evrim moru / final kırmızısı, üstündeki satır PANEL3 + altın kenar + altın halka. Satırlar daha uzun
## (açıklama) -> sütun 600 genişlik. Ortada "SEVİYE N  Bir evrim seç" başlığı (oyunun C kart kipi gibi).
func _evo_M() -> Control:
	var DK: GDScript = load("res://scripts/shop_dark_kit.gd")
	var kk = DK.new(DK.get_script_constant_map()["PAL_NIGHT"])
	var col: VBoxContainer = kk.v(12)
	col.name = "EvoColumnM"
	col.theme = kk.theme()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head: HBoxContainer = kk.h(20)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(kk.lbl("SEVİYE %d" % EVO_LEVEL, 56, kk.c("accent")))
	col.add_child(head)
	var lb: PanelContainer = kk.box(kk.c("panel"), kk.c("line_hi"), 16, 3, 8)
	## "yazılar çok sınıra yakın" (2026-11-08): panel 600 -> 680, satır iç payı 21/15, satırlar arası 12.
	lb.custom_minimum_size = Vector2(680, 0)
	lb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lv: VBoxContainer = kk.v(12)
	lb.add_child(lv)
	var sh: HBoxContainer = kk.h(12)
	sh.add_child(kk.glyph(DK.get_script_constant_map()["G_STAR"], kk.c("accent"), 4))
	sh.add_child(kk.lbl("YETENEK EVRİMİ", 32, kk.c("accent")))
	lv.add_child(sh)
	lv.add_child(kk.sp(0, 2))
	var text_w: float = 680.0 - 32.0 - 42.0 - 48.0 - 16.0
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var on: bool = i == HOVER
		var face := PanelContainer.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		## Simge çerçevesiz (kullanıcı 2026-11-08); evrim moru / final kırmızısı satırın kenarında, üstündeki satır altın.
		var fs = kk.sb(kk.c("panel3") if on else Color(kk.c("inset"), 0.6), kk.c("accent") if on else Color(_evo_col(d), 0.55), 3, 8)
		fs.content_margin_left = 21.0
		fs.content_margin_right = 21.0
		fs.content_margin_top = 15.0
		fs.content_margin_bottom = 15.0
		face.add_theme_stylebox_override("panel", fs)
		var r: HBoxContainer = kk.h(16)
		var med := PanelContainer.new()
		med.mouse_filter = Control.MOUSE_FILTER_IGNORE
		med.custom_minimum_size = Vector2(48, 48)
		med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		med.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var mc := CenterContainer.new()
		mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = d["icon"]
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(48, 48)
		mc.add_child(icon)
		med.add_child(mc)
		r.add_child(med)
		var v: VBoxContainer = kk.v(2)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(kk.lbl(str(d["name"]), 32, kk.c("text")))
		var tl: HBoxContainer = kk.h(12)
		var tier_l: Label = kk.lbl(_tier_text(d), 24, HT.ACCENT_SOFT)
		tier_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tl.add_child(tier_l)
		var pips := Pips.new()
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.setup(int(d["total"]), int(d["total"]) - 1 if d["final"] else int(d["owned"]), Color(_evo_col(d), 0.85), HT.ACCENT_SOFT,
			HT.WIN_LINE_HI, HT.WIN_INSET, false)
		tl.add_child(pips)
		var sk: Label = kk.lbl("%s (%s)" % [str(d["skill"]), str(d["key"])], 24, kk.c("dim"))
		sk.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tl.add_child(sk)
		v.add_child(tl)
		v.add_child(_rtl(str(screen.call("_evo_desc_bbcode", str(d["desc"]), HT.ACCENT_SOFT)), 24, kk.c("dim"), text_w))
		r.add_child(v)
		face.add_child(r)
		lv.add_child(face)
	col.add_child(lb)
	return col


## ================================================================ N - Ahşap Efsun Kartı (kullanıcı 2026-11-08: "eski efsun kartını hafif oval
## kenarlı ve envanterdeki pencereye benzer şekilde tasarlar mısın")
## Eski efsun kartının (madde 428 öncesi, `out 0_eski.png`) İSKELETİ: dikey kart, üstte simge + "EVRİM n/N" + yetenek, altında koyu iç kutuda ad +
## açıklama. GÖRÜNÜŞÜ envanterin seçim kartı (`inventory_panel.gd _ch_detail`: kit `box(panel2, kenar, 16, 3, 6)`, başlık 32, gövde 24):
## ahşap dolgu, köşe 15 (hafif oval; envanter 6), kenar = kısık evrim moru / final kırmızısı (envanterde kenar = eşyanın kademe rengi),
## iç kutu envanterin kuyusu (inset, köşe 12). Simge ÇERÇEVESİZ (kullanıcı level kartında "simgelerin dışında çerçeve olmasın"), tuş kapağı
## HUD'unki. "Q · Yetenek" yerine yetenek adı + tuş kapağı ("·" yok). Eski kartın çapraz ışıltı şeridi / mor doku yok. Üstündeki kart:
## PANEL3 + altın kenar + 1 sanat px kalkma.
## N ek 2 (kullanıcı: "iç yazısı çok solgun dikkat çekici değil ve boş kısımlar gereksiz fazla"): açıklama DIM 24 -> TEXT 32, sayılar
## PRICE (ACCENT_SOFT yerine). N ek 3 (kullanıcı: "boyutunu kısalt veya küçült demedim sadece içi fazla boş durmucak şekilde yazıların
## boyutunu biraz arttır"): kart yine 390x480 (ek 2'deki kısaltma / 420 genişlik geri alındı), ad 32 -> 48, açıklama 32 + satır arası 8.
const N_W := 390.0
const N_H := 480.0
## N ek (kullanıcı 2026-11-08, üst alanı oklarla işaretleyip: "kaplayan tüm rengin eski efsun kartındaki gibi renk ile uyumlu olmasını
## istiyorum"): kart GÖVDESİ (iç kutu dışı) eski efsun kartının gövde rengi - çekimden ölçüldü (`0_eski.png`: mor kart #2c233a, final
## #332123; efsun kartı dokusunun = ANLAMLI renk). Oyuna alınırsa hud_theme.gd'ye rol (EVO_FILL / EVO_FINAL_FILL). Üstünde = biraz açık.
const N_FILL := Color("#2c233a")
const N_FINAL_FILL := Color("#332123")
## N ek 4 (kullanıcı: "farenin üstünde olduğu kartın etrafı sarı olmak yerine hafif büyüsün ease ease şeklinde"): üstündeki kartta altın
## kenar / açık dolgu / kalkma YOK; kart ortasından %5 büyür, sinüs ease-in-out 0,22 sn (girişte ve çıkışta aynı). Çekim: N_evrim.png =
## büyümüş hâl, out/n_gif/ kareleri -> N_hover.gif (Tween.interpolate_value ile kare kare, oyundaki tween'le aynı eğri).
const N_HOVER_SCALE := 1.05
const N_HOVER_TIME := 0.22
var n_hover_card: Control = null


func _evo_N() -> Control:
	var DK: GDScript = load("res://scripts/shop_dark_kit.gd")
	var kk = DK.new(DK.get_script_constant_map()["PAL_NIGHT"])
	var row := _cards_row(36)
	row.theme = kk.theme()
	var inner: float = N_W - 42.0
	for i in evo_data.size():
		var d: Dictionary = evo_data[i]
		var hov: bool = i == HOVER
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var body: Color = N_FINAL_FILL if d["final"] else N_FILL
		card.add_theme_stylebox_override("panel", kk.sb(body, Color(_evo_col(d), 0.8), 3, 15, 21.0))
		if hov:
			n_hover_card = card
		card.custom_minimum_size = Vector2(N_W, N_H)
		var v: VBoxContainer = kk.v(15)
		card.add_child(v)
		## Üst: simge (96 = 48 sanat px x2, çerçevesiz) + tuş kapağı | EVRİM n/N, yetenek adı, pipler
		var top: HBoxContainer = kk.h(18)
		top.add_child(_evo_icon_small(d, 96.0))
		var tv: VBoxContainer = kk.v(3)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tl: Label = kk.lbl(_tier_text(d), 32, kk.c("accent"))
		tv.add_child(tl)
		tv.add_child(kk.lbl(str(d["skill"]), 24, kk.c("dim")))
		tv.add_child(_gap(6))
		var pips := Pips.new()
		pips.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pips.setup(int(d["total"]), int(d["total"]) - 1 if d["final"] else int(d["owned"]), Color(_evo_col(d), 0.85), HT.ACCENT_SOFT,
			HT.WIN_LINE_HI, HT.WIN_INSET, false)
		tv.add_child(pips)
		top.add_child(tv)
		v.add_child(top)
		## Alt: envanter kuyusu - evrimin adı (32) + açıklama (24, envanter gövdesi gibi), boşluk burada
		var well: PanelContainer = kk.box(kk.c("inset"), Color(0, 0, 0, 0), 18.0, 0, 12)
		well.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var wv: VBoxContainer = kk.v(12)
		var nm: Label = kk.lbl(str(d["name"]), 48, kk.c("accent"))
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size.x = inner - 36.0
		wv.add_child(nm)
		var desc: RichTextLabel = _rtl(str(screen.call("_evo_desc_bbcode", str(d["desc"]), HT.PRICE)), 32, kk.c("text"), inner - 36.0)
		desc.add_theme_constant_override("line_separation", 8)
		wv.add_child(desc)
		well.add_child(wv)
		v.add_child(well)
		row.add_child(card) ## kalkma yok (ek 4): üstündeki kart büyür
	return row


## Üstündeki kartın büyüme geçişi kare kare (oyundaki tween'le aynı eğri: TRANS_SINE + EASE_IN_OUT): bekle -> büyü -> bekle -> küçül -> bekle;
## her kare out/n_gif/'e (kartların bölgesi). Sonunda büyümüş hâlde bırakır (N_evrim.png).
func _n_hover_anim() -> void:
	var c: Control = n_hover_card
	if c == null:
		return
	c.pivot_offset = (c.size * 0.5).round()
	var dir: String = _out().path_join("n_gif")
	DirAccess.make_dir_recursive_absolute(dir)
	var steps: int = 8
	var seq: Array = []
	for i in 8:
		seq.append(1.0)
	for i in steps + 1:
		seq.append(Tween.interpolate_value(1.0, N_HOVER_SCALE - 1.0, N_HOVER_TIME * i / steps, N_HOVER_TIME, Tween.TRANS_SINE, Tween.EASE_IN_OUT))
	for i in 14:
		seq.append(N_HOVER_SCALE)
	for i in steps + 1:
		seq.append(Tween.interpolate_value(N_HOVER_SCALE, 1.0 - N_HOVER_SCALE, N_HOVER_TIME * i / steps, N_HOVER_TIME, Tween.TRANS_SINE, Tween.EASE_IN_OUT))
	for i in 6:
		seq.append(1.0)
	for idx in seq.size():
		c.scale = Vector2.ONE * float(seq[idx])
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.get_region(Rect2i(300, 110, 1320, 560)).save_png(dir.path_join("f_%03d.png" % idx))
	c.scale = Vector2.ONE * N_HOVER_SCALE
	print("VERI N hover %d kare" % seq.size())
