extends SceneTree

## LEVEL KARTI küçültme prototipleri (2026-11-06, kullanıcı: "level atlayınca çıkan arayüzde soldaki 3 level atlama kartı çok gereksiz
## büyük görünüyor ve tasarımını göz yorucu buluyorum. boyutunu küçültüp 4 yeni prototip üretir misin"). OYUNA BAĞLI DEĞİL.
## GERÇEK SP main.tscn'de OYUNDAKİ level + pazar ekranı açılır (level_pazar_oyun.gd durumu: Oakley, Uzunkılıç III + Ateş Asası,
## 1480 altın / 17 parçacık), kart verisi ekranın kendi _market_card_data'sından; sadece SOL SÜTUN (level_market_view.gd LevelCards)
## gizlenip yerine prototipin sütunu kurulur, pazar penceresi + bakiye sekmesi + başlık yeni genişliğe göre ortalanır. Pazar AYNI.
##   A Sade Liste   - kutusuz satırlar, ince kademe şeridi, 48 px simge, bedel yazı (hap yok), değer sağ sütunda
##   B Mini Yuvalar - pazardaki yuvalar gibi yan yana 3 küçük dikey kart
##   C Artı / Eksi  - sekizgen madalyon + "▲ kazanç / ▼ bedel" iki satır (LoL eşya farkı gibi)
##   D Düz Glif     - mini stat panelinin dili: pürüzsüz Nunito + düz LoL simgeleri (stat_mini_lol), ince satırlar
## Genişlikler bütün kartların (düz + özel, 4 kademe) en uzun yazısından hesaplanır (VERI satırları).
## Çıktı (out/): 0_simdi.png (bugünkü), X_ilk.png / X_secili.png, ozet.png (4'ü bir arada), ozet_kartlar.png (sol sütunlar 1:1).
## Kullanım: tools/proto_20261106/level_kart/level_kart_run.ps1 [-Only "A,C"]
## NOT: bu dosyayı PowerShell Get-Content/Set-Content ile DÜZENLEME (BOM'suz UTF-8'i ANSI okuyup Türkçe harfleri bozuyor).

const CHAR_ID := 2
const LEVEL := 13
const SEED := 20261106
const DarkKit := preload("res://scripts/shop_dark_kit.gd")
const StatIcon := preload("res://scripts/stat_icon.gd")
const LSC := preload("res://scripts/level_special_cards.gd")
const NUNITO: Font = preload("res://assets/fonts/Nunito-SemiBold.ttf")
const LOL_DIR := "res://assets/ui/stat_mini_lol/"
const DIE := preload("res://assets/ui/game/levelup_die.png")
const G_UP := ["..#..", ".###.", "#.#.#", "..#..", "..#.."]
const G_DOWN := ["..#..", "..#..", "#.#.#", ".###.", "..#.."]
## Göz yormasın: bugünkü parlak altın (#ffd66e) + kırmızı kenarlı hap yerine kısık tonlar.
const VAL_SOFT := Color("#e6cf92")
const COST_SOFT := Color("#d99386")
const UP_SOFT := Color("#a9cf9b")
const NAMES := {"0": "ŞU AN", "A": "A - Sade Liste", "B": "B - Mini Yuvalar", "C": "C - Artı / Eksi", "D": "D - Düz Glif"}
const B_W := 150.0

var GM: Node = null
var main: Node = null
var screen: Node = null
var view: Control = null
var k = null
var vc: Dictionary = {}
var cards: Array = []
var all_cards: Array = []
var shots: Dictionary = {}
var rects: Dictionary = {}
var orig: Dictionary = {}
var market: Control = null
var purse: Control = null
var header: Control = null
var _m: Dictionary = {}
var _nf: FontVariation = null
var _nfb: FontVariation = null


class Tri extends Control:
	var col: Color = Color.WHITE
	var up: bool = false

	func _init(c: Color, u: bool, s: float) -> void:
		col = c
		up = u
		custom_minimum_size = Vector2(s, s)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y * 0.75
		var y0: float = (size.y - h) * 0.5
		var pts := PackedVector2Array([Vector2(0, y0), Vector2(w, y0), Vector2(w * 0.5, y0 + h)])
		if up:
			pts = PackedVector2Array([Vector2(0, y0 + h), Vector2(w, y0 + h), Vector2(w * 0.5, y0)])
		draw_colored_polygon(pts, col)


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _out() -> String:
	var d: String = OS.get_environment("LEVEL_KART_DIR")
	if d == "":
		d = ProjectSettings.globalize_path("res://tools/proto_20261106/level_kart/out")
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


## ---------------------------------------------------------------- oyun kurulumu (level_pazar_oyun.gd ile aynı durum)
func _run() -> void:
	await process_frame
	GM = root.get_node("GameManager")
	AudioServer.set_bus_mute(0, true)
	root.get_node("NetworkManager").call("disconnect_from_room")
	root.get_node("UISound").set("show_fps", false)
	GM.call("reset")
	GM.set("selected_char_id", CHAR_ID)
	GM.set("selected_character", (load("res://scripts/characters.gd") as GDScript).call("get_def", CHAR_ID).get("skill", 1))
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
	var Logic: GDScript = load("res://scripts/weapon_shop_logic.gd")
	(load("res://scripts/meta_progress.gd") as GDScript).call("set_unlock_all", true)
	GM.gold = 99999
	GM.call("add_weapon_shards", 999 - int(GM.weapon_shards))
	Logic.call("buy_weapon", p, "fire_staff")
	for e: Dictionary in GM.owned_weapons:
		EnchantDefs.ensure_trait(e)
		if str(e.get("key", "")) == "uzunkilic":
			(e["enchant"] as Dictionary)["ups"] = [0, 1]
	p.set("max_item_slots", 9)
	for key: String in ["kanli_yakut", "ceviklik_yuzugu"]:
		p.call("buy_item", key)
	GM.set("game_time", 1350.0)
	GM.set("free_rerolls_per_card", 1)
	GM.gold = 1480
	GM.call("add_weapon_shards", 17 - int(GM.weapon_shards))
	p.set("level", LEVEL)
	await _wait(1.0)

	seed(SEED)
	main.call("_show_level_up_screen", LEVEL)
	await _wait(1.4)
	screen = main.get_node_or_null("LevelUpScreen")
	view = screen.get("_market_view") if screen else null
	if view == null:
		print("!! pazar görünümü yok")
		quit()
		return
	k = view.get("_k")
	vc = view.get_script().get_script_constant_map()
	_collect_cards()
	view.set("_hover", 1)
	view.call("_refresh_detail")
	await _wait(0.3)
	await _shot("0_simdi.png")
	var lc: Control = view.get_node("LevelCards")
	rects["0"] = Rect2(lc.global_position, Vector2(lc.size.x, 16.0 + 48.0 + 12.0 + 3.0 * 172.0 + 8.0))

	market = view.get_node("Market")
	purse = view.get_node("Purse")
	header = view.find_child("MarketTitle", true, false).get_parent() as Control
	orig = {"market_x": market.position.x, "purse_l": purse.offset_left, "purse_r": purse.offset_right}
	lc.visible = false
	_measure()

	var only: String = OS.get_environment("LEVEL_KART_ONLY")
	var done: Array = []
	for key: String in ["A", "B", "C", "D"]:
		if only != "" and not only.contains(key):
			continue
		for chosen: int in [-1, 1]:
			var left: PanelContainer = call("_build_" + key, chosen)
			var lw: float = float(left.get_meta("lw"))
			view.add_child(left)
			_place(left, lw)
			var go: Button = view.get("go_button")
			go.disabled = chosen < 0
			go.text = "ÖNCE KART SEÇ" if chosen < 0 else "DEVAM ET"
			await _wait(0.35)
			## gerçek en küçük boy (başlık satırı hesaplanandan geniş olabilir) -> pazar penceresiyle çakışmasın
			var real: Vector2 = left.get_combined_minimum_size()
			_place(left, maxf(lw, real.x))
			left.size = Vector2(maxf(lw, real.x), real.y)
			await _wait(0.15)
			await _shot("%s_%s.png" % [key, "ilk" if chosen < 0 else "secili"])
			if chosen < 0:
				rects[key] = left.get_global_rect()
				print("VERI %s sol sütun %dx%d (bugün 580x720, kart 160 yükseklik)" % [key, int(left.size.x), int(left.size.y)])
			left.queue_free()
			await process_frame
		done.append(key)
	if done.size() > 0:
		await _summaries(done)
	quit()


func _collect_cards() -> void:
	var ups: Array = screen.get_script().get_script_constant_map()["UPGRADES"]
	var ids: Array = screen.get("_card_ids")
	var tiers: Array = screen.get("_card_tiers")
	for i in 3:
		cards.append(screen.call("_market_card_data", _upgrade(ups, str(ids[i])), int(tiers[i]), 0))
	for u in ups:
		for t in 4:
			all_cards.append(screen.call("_market_card_data", u, t + 1, 0))
	for id: String in LSC.ORDER:
		for t in 4:
			all_cards.append(screen.call("_market_card_data", LSC.as_card(id), t + 1, 0))
	for d: Dictionary in cards:
		print("VERI kart ", d["title"], " | ", d["value"], " | ", d["cost"], " | kademe ", d["tier"], " | ", d["icon"])


func _upgrade(ups: Array, id: String) -> Dictionary:
	for u: Dictionary in ups:
		if str(u["id"]) == id:
			return u
	return LSC.as_card(id)


## ---------------------------------------------------------------- ölçü (bütün kartlar x 4 kademe: en uzun yazılar)
func _nfont(bold: bool) -> FontVariation:
	if _nf == null:
		_nf = FontVariation.new()
		_nf.base_font = NUNITO
		_nfb = FontVariation.new()
		_nfb.base_font = NUNITO
		_nfb.variation_embolden = 0.6
	return _nfb if bold else _nf


func _nw(t: String, fs: int, bold: bool = false) -> float:
	return _nfont(bold).get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


func _gain_label(d: Dictionary) -> String:
	return str(d.get("label", "")) if str(d.get("cat", "")) == LSC.CAT_TRADE else ""


func _measure() -> void:
	var m := {"title24": 0.0, "title32": 0.0, "val32": 0.0, "cost24": 0.0, "up24": 0.0, "n_title": 0.0, "n_cost": 0.0, "n_val": 0.0}
	var who := {}
	for d: Dictionary in all_cards:
		var title: String = str(d["title"])
		var value: String = str(d["value"])
		var cost: String = str(d["cost"])
		var gl: String = _gain_label(d)
		var cand := {"title24": k.tw(title, 24), "title32": k.tw(title, 32), "val32": k.tw(value, 32), "cost24": k.tw(cost, 24),
			"up24": k.tw(value + (" " + gl if gl != "" else ""), 24), "n_title": _nw(title, 22), "n_cost": _nw(cost, 17),
			"n_val": _nw(value, 24, true)}
		for key: String in cand:
			if float(cand[key]) > float(m[key]):
				m[key] = float(cand[key])
				who[key] = title + " " + value + " " + cost
	_m = m
	for key: String in m:
		print("VERI en geniş %s = %d (%s)" % [key, int(ceil(float(m[key]))), who.get(key, "")])


## ---------------------------------------------------------------- ortak parçalar
## Sol sütun lw genişliğinde; sütun + ara + pazar ekranın ortasında, pazar/bakiye sekmesi/başlık kayar.
func _place(left: PanelContainer, lw: float) -> void:
	var lr: Rect2 = vc["LEFT_RECT"]
	var comp_w: float = lw + float(vc["COL_GAP"]) + float(vc["RIGHT_W"])
	var cx: float = roundf((1920.0 - comp_w) * 0.5)
	left.position = Vector2(cx, lr.position.y)
	left.custom_minimum_size = Vector2(lw, 0)
	var nx: float = cx + lw + float(vc["COL_GAP"])
	var dx: float = nx - float(orig["market_x"])
	market.position.x = nx
	purse.offset_left = float(orig["purse_l"]) + dx
	purse.offset_right = float(orig["purse_r"]) + dx
	header.position.x = cx + 4.0


func _panel(lw: float) -> PanelContainer:
	var p: PanelContainer = k.box(k.c("panel"), k.c("line_hi"), 16, 3, 8)
	p.name = "ProtoLeft"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_meta("lw", ceilf(lw / 4.0) * 4.0)
	return p


func _head(chosen: int) -> HBoxContainer:
	var r: HBoxContainer = k.h(12)
	r.add_child(k.glyph(DarkKit.G_STAR, k.c("accent"), 4))
	r.add_child(k.lbl("LEVEL KARTI", 32, k.c("accent")))
	r.add_child(k.sp(0, 0, true))
	var used: bool = chosen >= 0
	var f: HBoxContainer = k.h(6)
	var g: Control = k.glyph(DarkKit.G_CHECK if used else DarkKit.G_STAR, k.c("dim") if used else k.c("good"), 2)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	f.add_child(g)
	f.add_child(k.lbl("KULLANILDI" if used else "1 ÜCRETSİZ", 24, k.c("dim") if used else k.c("good")))
	r.add_child(f)
	return r


func _reroll(chosen: int) -> Button:
	var b := Button.new()
	b.text = "KARIŞTIR · ÜCRETSİZ"
	b.icon = DIE
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 24)
	k.btn_style(b, "ghost")
	b.disabled = chosen >= 0
	b.focus_mode = Control.FOCUS_NONE
	return b


func _sb(fill: Color, border: Color, bw: int, r: int, mx: float, my: float) -> StyleBoxFlat:
	var s: StyleBoxFlat = k.sb(fill, border, bw, r)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	return s


func _tier_col(d: Dictionary) -> Color:
	return (vc["TIER_RIM"] as Array)[clampi(int(d["tier"]), 1, 4) - 1]


func _stat_tex(id: String) -> Texture2D:
	var f: String = str(StatIcon.ICON_PATHS.get(id, ""))
	return load(StatIcon.ICON_DIR + f) as Texture2D if f != "" else null


## Level simgeleri 288 px (48'in 6 katı): 48 / 96'da NEAREST tam örnekler (keskin), başka boyda doğrusal.
func _ico(t: Texture2D, px: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if t:
		var ts: Vector2 = t.get_size()
		var exact: bool = int(ts.x) % int(px) == 0 and int(ts.y) % int(px) == 0
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if exact else CanvasItem.TEXTURE_FILTER_LINEAR
	return tr


func _cost_line(d: Dictionary, fs: int, gpx: int) -> HBoxContainer:
	var r: HBoxContainer = k.h(6)
	if bool(d.get("cost_red", true)):
		var g: Control = k.glyph(G_DOWN, COST_SOFT, gpx)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(g)
		r.add_child(k.lbl(str(d["cost"]), fs, COST_SOFT))
	else:
		r.add_child(k.lbl(str(d["cost"]), fs, k.c("dim")))
	return r


func _dim_others(n: Control, i: int, chosen: int) -> void:
	if chosen >= 0 and i != chosen:
		n.modulate = Color(1, 1, 1, 0.42)


## ---------------------------------------------------------------- A - Sade Liste
## Kart kutusu yok: satırlar ince çizgiyle ayrılır, kademe = 4 px sol şerit. Başlık 32, değer 32 sağ sütunda (tablo gibi hizalı),
## bedel başlığın altında kısık kırmızı 24 (hap/kenar yok). Satır ~76 px (bugün 160).
func _build_A(chosen: int) -> PanelContainer:
	var val_w: float = ceilf(float(_m["val32"]))
	var text_w: float = ceilf(maxf(float(_m["title32"]), float(_m["cost24"]) + 16.0))
	var p := _panel(32.0 + 20.0 + 4.0 + 14.0 + 48.0 + 14.0 + text_w + 14.0 + val_w)
	var v: VBoxContainer = k.v(0)
	p.add_child(v)
	v.add_child(_head(chosen))
	v.add_child(k.sp(0, 10))
	for i in 3:
		if i > 0:
			v.add_child(k.hline(Color(k.c("line"), 0.7), 2))
		var d: Dictionary = cards[i]
		var on: bool = i == chosen
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", _sb(k.c("panel3") if on else Color(0, 0, 0, 0),
			k.c("accent") if on else Color(0, 0, 0, 0), 2, 6, 10, 10))
		var r: HBoxContainer = k.h(14)
		row.add_child(r)
		var stripe := ColorRect.new()
		stripe.color = Color(_tier_col(d), 0.85)
		stripe.custom_minimum_size = Vector2(4, 0)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(stripe)
		r.add_child(_ico(_stat_tex(str(d["icon"])), 48))
		var tv: VBoxContainer = k.v(2)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.custom_minimum_size.x = text_w
		tv.add_child(k.lbl(str(d["title"]), 32, k.c("text")))
		tv.add_child(_cost_line(d, 24, 2))
		r.add_child(tv)
		var vl: Label = k.lbl(str(d["value"]), 32, VAL_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
		vl.custom_minimum_size.x = val_w
		r.add_child(vl)
		_dim_others(row, i, chosen)
		v.add_child(row)
	v.add_child(k.sp(0, 12))
	v.add_child(_reroll(chosen))
	return p


## ---------------------------------------------------------------- B - Mini Yuvalar
## Pazarın yuvalarıyla aynı dil: yan yana 3 dikey kart (150 genişlik), 64'lük kademe çerçeveli kuyu + 48 simge, başlık 24 (gerekirse
## iki satır), değer 32 kısık altın, bedel 24 kısık kırmızı. Değerler kart altında hizalı.
func _build_B(chosen: int) -> PanelContainer:
	var p := _panel(32.0 + 3.0 * B_W + 2.0 * 10.0)
	var v: VBoxContainer = k.v(0)
	p.add_child(v)
	v.add_child(_head(chosen))
	v.add_child(k.sp(0, 12))
	var hb: HBoxContainer = k.h(10)
	v.add_child(hb)
	for i in 3:
		var d: Dictionary = cards[i]
		var tc: Color = _tier_col(d)
		var on: bool = i == chosen
		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.custom_minimum_size = Vector2(B_W, 200)
		card.add_theme_stylebox_override("panel", _sb(k.c("panel3") if on else k.c("panel2"),
			k.c("accent") if on else Color(tc, 0.45), 2, 6, 8, 10))
		var cv: VBoxContainer = k.v(6)
		card.add_child(cv)
		var well := PanelContainer.new()
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.custom_minimum_size = Vector2(64, 64)
		well.add_theme_stylebox_override("panel", _sb(k.c("inset"), Color(tc, 0.7), 2, 4, 0, 0))
		var wc := CenterContainer.new()
		wc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wc.add_child(_ico(_stat_tex(str(d["icon"])), 48))
		well.add_child(wc)
		cv.add_child(k.center(well))
		cv.add_child(k.wrap(str(d["title"]), 24, k.c("text"), B_W - 16.0, HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(k.sp(0, 0, false, true))
		cv.add_child(k.lbl(str(d["value"]), 32, VAL_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
		var cl: Label = k.wrap(str(d["cost"]), 24, COST_SOFT if bool(d.get("cost_red", true)) else k.c("dim"), B_W - 16.0,
			HORIZONTAL_ALIGNMENT_CENTER)
		cv.add_child(cl)
		_dim_others(card, i, chosen)
		hb.add_child(card)
	v.add_child(k.sp(0, 12))
	v.add_child(_reroll(chosen))
	return p


## ---------------------------------------------------------------- C - Artı / Eksi
## LoL eşya farkı gibi: sekizgen madalyon (kademe halkası) + başlık 32 + "▲ kazanç" yeşil + "▼ bedel" kırmızı (ikisi de 24, aynı
## hizada) - büyük sayı/hap yok, göz satırı soldan okur. Satırlar koyu kuyuda, araları boşluk.
func _build_C(chosen: int) -> PanelContainer:
	var text_w: float = ceilf(maxf(float(_m["title32"]), maxf(float(_m["up24"]), float(_m["cost24"])) + 16.0))
	var p := _panel(32.0 + 24.0 + 64.0 + 16.0 + text_w)
	var v: VBoxContainer = k.v(8)
	p.add_child(v)
	v.add_child(_head(chosen))
	v.add_child(k.sp(0, 2))
	for i in 3:
		var d: Dictionary = cards[i]
		var tc: Color = _tier_col(d)
		var on: bool = i == chosen
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_stylebox_override("panel", _sb(k.c("panel3") if on else Color(k.c("inset"), 0.6),
			k.c("accent") if on else Color(0, 0, 0, 0), 2, 8, 12, 10))
		var r: HBoxContainer = k.h(16)
		row.add_child(r)
		var med := PanelContainer.new()
		med.mouse_filter = Control.MOUSE_FILTER_IGNORE
		med.custom_minimum_size = Vector2(64, 64)
		med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		med.add_theme_stylebox_override("panel", _sb(k.c("panel2"), k.c("accent") if on else Color(tc, 0.85), 3, 18, 0, 0))
		var mc := CenterContainer.new()
		mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mc.add_child(_ico(_stat_tex(str(d["icon"])), 48))
		med.add_child(mc)
		r.add_child(med)
		var tv: VBoxContainer = k.v(2)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(k.lbl(str(d["title"]), 32, k.c("text")))
		var up: HBoxContainer = k.h(6)
		var ug: Control = k.glyph(G_UP, UP_SOFT, 2)
		ug.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		up.add_child(ug)
		var gl: String = _gain_label(d)
		up.add_child(k.lbl(str(d["value"]) + (" " + gl if gl != "" else ""), 24, UP_SOFT))
		tv.add_child(up)
		tv.add_child(_cost_line(d, 24, 2))
		r.add_child(tv)
		_dim_others(row, i, chosen)
		v.add_child(row)
	v.add_child(k.sp(0, 4))
	v.add_child(_reroll(chosen))
	return p


## ---------------------------------------------------------------- D - Düz Glif
## Mini stat panelinin (madde 262) dili: pürüzsüz Nunito (başlık 22, bedel 17, değer 24 kalın) + düz renkli LoL simgeleri
## (stat_mini_lol 48 -> 36 doğrusal; olmayan stat'ta oyunun simgesi), ince satırlar. Piksel yazı yalnız bölüm başlığında.
func _nl(t: String, fs: int, col: Color, bold: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", _nfont(bold))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _lol_tex(id: String) -> Texture2D:
	var path: String = LOL_DIR + id + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else _stat_tex(id)


func _build_D(chosen: int) -> PanelContainer:
	var val_w: float = ceilf(float(_m["n_val"]))
	var text_w: float = ceilf(maxf(float(_m["n_title"]), float(_m["n_cost"]) + 16.0))
	var p := _panel(32.0 + 20.0 + 48.0 + 14.0 + text_w + 14.0 + val_w)
	var v: VBoxContainer = k.v(4)
	p.add_child(v)
	v.add_child(_head(chosen))
	v.add_child(k.sp(0, 6))
	for i in 3:
		var d: Dictionary = cards[i]
		var tc: Color = _tier_col(d)
		var on: bool = i == chosen
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		row.add_theme_stylebox_override("panel", _sb(k.c("panel3") if on else Color(k.c("panel2"), 0.55),
			k.c("accent") if on else Color(0, 0, 0, 0), 2, 6, 10, 8))
		var r: HBoxContainer = k.h(14)
		row.add_child(r)
		var ib := PanelContainer.new()
		ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ib.custom_minimum_size = Vector2(48, 48)
		ib.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ib.add_theme_stylebox_override("panel", _sb(k.c("inset"), Color(tc, 0.65), 2, 6, 0, 0))
		var icc := CenterContainer.new()
		icc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var it: TextureRect = _ico(_lol_tex(str(d["icon"])), 36)
		it.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		icc.add_child(it)
		ib.add_child(icc)
		r.add_child(ib)
		var tv: VBoxContainer = k.v(0)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.custom_minimum_size.x = text_w
		tv.add_child(_nl(str(d["title"]), 22, k.c("text")))
		var cr: HBoxContainer = k.h(6)
		var red: bool = bool(d.get("cost_red", true))
		if red:
			cr.add_child(Tri.new(COST_SOFT, false, 10))
		cr.add_child(_nl(str(d["cost"]), 17, COST_SOFT if red else k.c("dim")))
		tv.add_child(cr)
		r.add_child(tv)
		var vl: Label = _nl(str(d["value"]), 24, VAL_SOFT, true, HORIZONTAL_ALIGNMENT_RIGHT)
		vl.custom_minimum_size.x = val_w
		r.add_child(vl)
		_dim_others(row, i, chosen)
		v.add_child(row)
	v.add_child(k.sp(0, 8))
	v.add_child(_reroll(chosen))
	return p


## ---------------------------------------------------------------- özetler
func _plate(parent: Control, t: String, pos: Vector2, fs: int = 32) -> void:
	var pc: PanelContainer = k.box(Color(0.05, 0.05, 0.09, 0.88), k.c("line_hi"), 8, 2, 4)
	pc.add_child(k.lbl(t, fs, k.c("accent")))
	parent.add_child(pc)
	pc.position = pos


func _crop(key: String) -> Image:
	var src: Image = shots["0_simdi.png" if key == "0" else "%s_ilk.png" % key]
	var rc: Rect2 = rects[key]
	var ri := Rect2i(Vector2i(rc.position.floor()) - Vector2i(4, 4), Vector2i(rc.size.ceil()) + Vector2i(8, 8))
	return src.get_region(ri.intersection(Rect2i(0, 0, 1920, 1080)))


func _put(host: Control, img: Image, key: String, pos: Vector2) -> void:
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.position = pos + Vector2(0, 48)
	tr.size = Vector2(img.get_size())
	host.add_child(tr)
	_plate(host, NAMES[key], pos, 24)


func _summaries(done: Array) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	root.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color("#0c0c14")
	bg.size = Vector2(1920, 1080)
	layer.add_child(bg)
	var host := Control.new()
	host.theme = k.theme()
	host.size = Vector2(1920, 1080)
	layer.add_child(host)
	## 1) dört ekran bir arada
	for idx in done.size():
		var key: String = done[idx]
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(shots["%s_ilk.png" % key])
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.position = Vector2(8 + (idx % 2) * 960, 8 + floori(idx / 2.0) * 540)
		tr.size = Vector2(944, 531)
		host.add_child(tr)
		_plate(host, NAMES[key], tr.position + Vector2(10, 10))
	await _wait(0.2)
	await _shot("ozet.png")
	for c in host.get_children():
		c.queue_free()
	await process_frame
	## 2) sol sütunlar 1:1 - solda bugünkü, sağında prototipler 2 sütunlu ızgarada
	var now: Image = _crop("0")
	_put(host, now, "0", Vector2(16, 8))
	var x0: float = 16.0 + now.get_width() + 40.0
	var imgs: Array = []
	for key: String in done:
		imgs.append(_crop(key))
	var col_w := [0.0, 0.0]
	var row_h: Array = []
	for idx in imgs.size():
		var im: Image = imgs[idx]
		var r: int = floori(idx / 2.0)
		while row_h.size() <= r:
			row_h.append(0.0)
		col_w[idx % 2] = maxf(col_w[idx % 2], im.get_width())
		row_h[r] = maxf(row_h[r], 48.0 + im.get_height())
	for idx in imgs.size():
		var r: int = floori(idx / 2.0)
		var y: float = 8.0
		for j in r:
			y += row_h[j] + 16.0
		var x: float = x0 + (0.0 if idx % 2 == 0 else col_w[0] + 32.0)
		_put(host, imgs[idx], done[idx], Vector2(x, y))
	var total_h: float = 8.0
	for h in row_h:
		total_h += h + 16.0
	if total_h > 1080.0 or x0 + col_w[0] + 32.0 + col_w[1] > 1920.0:
		print("!! ozet_kartlar taşıyor: %dx%d" % [int(x0 + col_w[0] + 32.0 + col_w[1]), int(total_h)])
	await _wait(0.2)
	await _shot("ozet_kartlar.png")
