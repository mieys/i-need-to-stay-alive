extends Control

## REKORLAR + BAŞARIMLAR ekranı - "A - Ateş Işığı" (2026-10-17, madde 250; prototip tools/proto_20261017/rekor_proto.gd, madde 249).
## Ayarlar ekranının (settings_screen.gd, madde 234) dili: kutu yok, solda büyük başlık + kategori sütunu (EN İYİLER / BAŞARIMLAR /
## [BALANS VERİSİ] / GERİ, seçilide yanan mum), sağda panelsiz satırlar (altın bölüm başlığı + ince ayraç), uzun liste kayar.
## Ana menü açar (main_menu.gd _on_records_pressed, ayarlarla AYNI desen): menünün tabelası/öğeleri gizlenir, bu ekran tasarım boyutunda
## (1920x1080) sola-üste yaslı - telefonda RootFitter ana menüyü ölçekler (eskiden CanvasLayer'dı, mobile_ui FIT_LAYER_SCRIPTS'teydi).
## Veri tek yerde: run_records.gd (rekorlar, açılmış başarımlar + tarihleri, son koşuda kırılan rekorlar), katalog achievements.gd. Sadece okur.
## Kilitli başarımların ilerlemesi bugünkü kayıttan (en iyi kademe/öldürme/süre/kat, toplam öldürme, koşu, zafer karakter sayısı).
## Gezinme: W/S (ok/D-pad) satır, Q/E (LB/RB, Tab) bölüm, ESC/B geri. Fare: satır üstü = seçili, tekerlek kaydırır, kategoriye tıkla.

signal closed

const FM := preload("res://scripts/fire_menu_kit.gd")
const DK := preload("res://scripts/menu_dark_kit.gd")
const UiAnim := preload("res://scripts/ui_anim.gd")
const LobbyUI := preload("res://scripts/menu_lobby_ui.gd")
const RunRecordsScript: GDScript = preload("res://scripts/run_records.gd")
const AchievementsScript: GDScript = preload("res://scripts/achievements.gd")
const TierDisplayScript: GDScript = preload("res://scripts/tier_display.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const PK := preload("res://scripts/phone_menu_kit.gd")

const COL_X := 660.0 ## settings_screen.gd ile aynı satır sütunu
const COL_Y := 150.0
const COL_W := 840.0
const LIST_H := 890.0 ## liste penceresi (altında ekran kenarı)
const ROW_H := 64.0
const ROW_H_SUB := 72.0 ## alt yazılı satır
const MAX_VICTORY_FACES := 6

enum Cat { REKOR, BASARIM }

const G_BACK := ["...#...", "..#....", "#######", "..#....", "...#..."]
const G_FOLDER := ["###......", "#########", "#.......#", "#.......#", "#.......#", "#########"]
const G_CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."]

## Piksel desenler: # ana, h parlak, k koyu (madalyada oyuk).
const P_SKULL := ["..#####..", ".#######.", "#########", "#kk###kk#", "#kk###kk#", ".###k###.", "..#####..", "..#k#k#.."]
const P_HORNS := ["#.......#", "##.....##", ".#######.", "#########", "#kk###kk#", "#kk###kk#", ".###k###.", "..#k#k#.."]
const P_CROWN := ["#...#...#", "##.###.##", "#########", "#h##h##h#", "#########", ".#######."]
const P_MOON := ["..####...", ".###.....", "###....h.", "###...hhh", "###....h.", "###......", ".###.....", "..####..."]
const P_SWORD := [".......hh", "......h#h", ".....h#h.", "....h#h..", "k..h#h...", ".k##h....", "..kk.....", ".k..k....", "k........"]
const P_SWORDS := ["h.......h", "#h.....h#", ".#h...h#.", "..#h.h#..", "...#h#...", "..k#.#k..", ".k.....k.", "k.......k"]
const P_HOURGLASS := ["#########", ".#hhhhh#.", "..#hhh#..", "...#h#...", "...#.#...", "..#.h.#..", ".#.hhh.#.", "#########"]
const P_FLAG := ["##.......", "#######..", "#hhhhhh#.", "#hhhhh#..", "#######..", "#........", "#........", "##......."]
const P_LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]

## Başarım madalyasının metali (kolaydan zora bronz -> gümüş -> altın; Final/çok kahraman kızıl). Tabloda olmayan yeni başarım bronz.
const METAL := {
	"bronz": [Color("#f0b47a"), Color("#b8743e"), Color("#5c3418")],
	"gumus": [Color("#eef3f7"), Color("#a9b7c6"), Color("#4e5a6c")],
	"altin": [Color("#ffe28c"), Color("#e0a83a"), Color("#6e4510")],
	"kizil": [Color("#ffb48e"), Color("#d6553c"), Color("#5e1a14")],
}
const ACH_METAL := {
	"tier_5": "bronz", "tier_10": "gumus", "tier_15": "altin", "final": "kizil", "victory": "altin", "victory_solo": "gumus",
	"victory_coop": "gumus", "victory_heroes_3": "kizil", "layer_3": "bronz", "layer_10": "gumus", "layer_25": "altin",
	"kills_500": "bronz", "kills_3000": "gumus", "time_15": "bronz", "time_30": "gumus", "total_kills_10000": "altin", "runs_10": "bronz",
}


## Piksel desenli küçük simge (cols: karakter -> renk; desende olup cols'ta olmayan karakter boş kalır).
class Pic extends Control:
	var rows: Array = []
	var cols: Dictionary = {}
	var px: float = 3.0

	func _init(r: Array, c: Dictionary, s: float = 3.0) -> void:
		rows = r
		cols = c
		px = s
		custom_minimum_size = Vector2(str(r[0]).length() * s, r.size() * s)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var off := ((size - custom_minimum_size) * 0.5).floor()
		for j in rows.size():
			var row: String = rows[j]
			for i in row.length():
				var ch: String = row[i]
				if cols.has(ch):
					draw_rect(Rect2(off + Vector2(i * px, j * px), Vector2(px, px)), cols[ch])


## Yuvarlak başarım madalyası (3 px hücreli disk + desen); kilitli = koyu silüet + kilit rozeti.
class Medal extends Control:
	const CELL := 3.0
	const OUTLINE := Color("#0d0906")
	const DARK_FILL := Color("#1a140f")
	const DARK_RIM := Color("#45372a")
	const LOCK_COL := Color("#ad9b80")
	var rows: Array = []
	var metal: Array = []
	var locked := false
	var pat_px: float = 0.0 ## desen pikseli (0 = CELL); telefonun iri madalyaları büyütür

	func _init(r: Array, m: Array, is_locked: bool, s: float) -> void:
		rows = r
		metal = m
		locked = is_locked
		custom_minimum_size = Vector2(s, s)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	func _disk(c: Vector2, rad: float, col: Color) -> void:
		var n := int(ceil(rad / CELL)) + 1
		for j in range(-n, n):
			for i in range(-n, n):
				var cx := (i + 0.5) * CELL
				var cy := (j + 0.5) * CELL
				if cx * cx + cy * cy <= rad * rad:
					draw_rect(Rect2(c.x + i * CELL, c.y + j * CELL, CELL, CELL), col)

	func _pat(rows_: Array, o: Vector2, px: float, cols: Dictionary) -> void:
		for j in rows_.size():
			var row: String = rows_[j]
			for i in row.length():
				var ch: String = row[i]
				if cols.has(ch):
					draw_rect(Rect2(o.x + i * px, o.y + j * px, px, px), cols[ch])

	func _draw() -> void:
		var hi: Color = DARK_RIM.lightened(0.06) if locked else metal[0]
		var mid: Color = DARK_RIM if locked else metal[1]
		var dk: Color = DARK_FILL if locked else metal[2]
		var rad: float = floorf(minf(size.x, size.y) * 0.5) - 1.0
		var c := (size * 0.5).floor()
		_disk(c, rad, OUTLINE)
		_disk(c, rad - 3.0, hi)
		_disk(c, rad - 6.0, mid)
		_disk(c, rad - 9.0, dk)
		var cols: Dictionary = {"#": metal[0], "h": Color("#fff6dc"), "k": (metal[2] as Color).darkened(0.45)}
		if locked:
			var g: Color = DARK_RIM.lightened(0.14)
			cols = {"#": g, "h": g, "k": DARK_FILL.darkened(0.35)}
		var px: float = pat_px if pat_px > 0.0 else CELL
		var gw: float = str(rows[0]).length() * px
		var gh: float = rows.size() * px
		_pat(rows, (c - Vector2(gw, gh) * 0.5).round(), px, cols)
		if locked:
			var lp := (c + Vector2(rad, rad) * 0.66).floor()
			_disk(lp, 11.0, OUTLINE)
			_disk(lp, 8.0, DARK_RIM)
			_pat(P_LOCK, lp - Vector2(7, 7), 2.0, {"#": LOCK_COL})


## İlerleme çubuğu (koyu yuva + altın dolgu + üst parıltı).
class Bar extends Control:
	var frac := 0.0

	func _init(f: float, w: float) -> void:
		frac = clampf(f, 0.0, 1.0)
		custom_minimum_size = Vector2(w, 18)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), FM.C_LINE)
		draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), FM.C_DARK)
		var fw: float = floorf((size.x - 4) * frac)
		if fw > 0.0:
			draw_rect(Rect2(2, 2, fw, size.y - 4), FM.C_GOLD)
			draw_rect(Rect2(2, 2, fw, 2), FM.C_GOLD.lightened(0.35))


## Listenin altında, aşağıda daha satır varken görünen basamaklı karartma.
class Fade extends Control:
	var col := Color.BLACK
	const STEPS := 6

	func _draw() -> void:
		var sh: float = ceilf(size.y / STEPS)
		for i in STEPS:
			draw_rect(Rect2(0, i * sh, size.x, sh), Color(col, col.a * float(i + 1) / STEPS))


var back_sub: String = "Ana menüye dön"
var band_alpha: float = 0.74

var _data: Dictionary = {}
var _cat: int = Cat.REKOR
var _cat_btns: Array[Button] = []
var _scroll: ScrollContainer = null
var _col: VBoxContainer = null
var _fade: Fade = null
var _rows: Array[Dictionary] = []
var _focus: int = 0


func _init(sub_for_back: String = "Ana menüye dön", shade_alpha: float = 0.74) -> void:
	back_sub = sub_for_back
	band_alpha = shade_alpha


func _ready() -> void:
	name = "RecordsScreen"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = DK.theme()
	_data = RunRecordsScript.load_all()
	_phone = MobileUIScript.enabled
	FM.use_phone_palette(_phone)
	if _phone:
		_build_phone()
		return
	var band := FM.StepShade.new()
	band.col = Color(0.05, 0.035, 0.025, band_alpha)
	add_child(band)
	var runs: int = int(_data["runs"])
	var sub: String = "Henüz koşu yok" if runs <= 0 else "%d koşu  ·  %s oyun" % [runs, _hours(float(_data["total_time"]))]
	var logo := FM.title_block("REKORLAR", FM.lbl(sub, DK.FS_BODY, FM.C_TAG))
	add_child(logo)
	logo.position = FM.TITLE_POS
	var v := DK.v(0)
	v.name = "CategoryPanel"
	var unlocked: int = (_data["achievements"] as Dictionary).size()
	var specs: Array = [
		["EN İYİLER", "Tek koşu rekorları ve toplamlar", FM.tex_icon(load("res://assets/items/kralin_kadehi.png"))],
		["BAŞARIMLAR", "%d / %d açıldı" % [unlocked, AchievementsScript.DEFS.size()], FM.tex_icon(load("res://assets/items/lutuf_madalyonu.png"))],
	]
	for i in specs.size():
		var sp: Array = specs[i]
		var b := FM.item(sp[0], sp[1], sp[2], false, false)
		b.focus_mode = Control.FOCUS_NONE
		var ci: int = i
		b.pressed.connect(func() -> void: _set_category(ci, true))
		b.mouse_entered.connect(func() -> void: FM.set_selected(b, true))
		b.mouse_exited.connect(func() -> void: FM.set_selected(b, ci == _cat))
		v.add_child(b)
		_cat_btns.append(b)
	v.add_child(DK.sp(0, 24))
	## Balans telemetrisi (balance_log.gd): koşu verisi klasörünü aç - arkadaşın kosular.jsonl dosyasını sana yollayabilsin.
	if OS.has_feature("pc"):
		var bal := FM.item("BALANS VERİSİ", "Koşu kayıtları klasörünü aç", DK.glyph(G_FOLDER, FM.C_SUB, 5), false, false)
		bal.name = "BalanceButton"
		bal.focus_mode = Control.FOCUS_NONE
		bal.pressed.connect(_on_open_balance_folder)
		bal.mouse_entered.connect(func() -> void: FM.set_selected(bal, true))
		bal.mouse_exited.connect(func() -> void: FM.set_selected(bal, false))
		v.add_child(bal)
	var back := FM.item("GERİ", back_sub, DK.glyph(G_BACK, FM.C_SUB, 5), false, false)
	back.name = "BackButton"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close)
	back.mouse_entered.connect(func() -> void: FM.set_selected(back, true))
	back.mouse_exited.connect(func() -> void: FM.set_selected(back, false))
	v.add_child(back)
	add_child(v)
	v.position = FM.COL_POS
	v.custom_minimum_size.x = FM.COL_W
	_scroll = ScrollContainer.new()
	_scroll.name = "List"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)
	_scroll.position = Vector2(COL_X, COL_Y)
	_scroll.size = Vector2(COL_W, LIST_H)
	_col = DK.v(0)
	_col.name = "Rows"
	_col.custom_minimum_size.x = COL_W
	_scroll.add_child(_col)
	_fade = Fade.new()
	_fade.col = Color(0.05, 0.035, 0.025, 0.96)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	_fade.position = Vector2(COL_X - 20, COL_Y + LIST_H - 110)
	_fade.size = Vector2(COL_W + 40, 1080 - (COL_Y + LIST_H - 110))
	var sbar: VScrollBar = _scroll.get_v_scroll_bar()
	sbar.value_changed.connect(func(_v: float) -> void: _update_fade())
	sbar.changed.connect(_update_fade)
	var hv := DK.v(10)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.add_child(FM.hint([["W/S", "kaydır"], ["Q/E", "bölüm"]]))
	hv.add_child(FM.hint([["ESC", "geri"]]))
	add_child(hv)
	hv.position = Vector2(64, 952) ## sol altta iki satır (ayarlar ekranıyla aynı yer)
	_set_category(Cat.REKOR, false)
	UiAnim.cascade(v, 0.04)


## ------------------------------------------------------------------ veri yardımcıları
static func _num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


static func _tm(sec: float) -> String:
	if sec <= 0.0:
		return "-"
	var t: int = int(sec)
	@warning_ignore("integer_division")
	var h: int = t / 3600
	@warning_ignore("integer_division")
	var m: int = (t % 3600) / 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, t % 60]
	return "%02d:%02d" % [m, t % 60]


static func _hours(sec: float) -> String:
	var t: int = int(sec)
	@warning_ignore("integer_division")
	var h: int = t / 3600
	@warning_ignore("integer_division")
	var m: int = (t % 3600) / 60
	return "%d sa %02d dk" % [h, m] if h > 0 else "%d dk" % m


static func _tier_txt(n: int) -> String:
	if n <= 0:
		return "-"
	return "FİNAL" if n >= TierDisplayScript.FINAL_TIER else TierDisplayScript.to_roman(n)


static func _date(unix: int) -> String:
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) ## dakika; kayıt UTC
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%02d.%02d.%d" % [int(d["day"]), int(d["month"]), int(d["year"])]


## Başarımın ölçtüğü değerin bugünkü kayıttaki karşılığı (achievements.gd ctx anahtarları; "bu koşu" anahtarları için en iyi değer).
func _ach_val(key: String) -> float:
	match key:
		"tier":
			return float(_data["best_tier"])
		"time":
			return float(_data["best_time"])
		"kills":
			return float(_data["best_kills"])
		"layer":
			return float(_data["best_layer"])
		"victory":
			return 1.0 if int(_data["victories"]) > 0 else 0.0
		"victory_chars":
			return float((_data["victory_chars"] as Array).size())
		"runs_total":
			return float(_data["runs"])
		"total_kills":
			return float(_data["total_kills"])
	return 0.0 ## victory_solo / victory_coop: kayıtta ayrı sayaç yok, kilitliyse 0


func _ach_frac(d: Dictionary) -> float:
	return clampf(_ach_val(str(d["key"])) / maxf(float(d["min"]), 1.0), 0.0, 1.0)


func _ach_count(d: Dictionary) -> String:
	var key: String = d["key"]
	var cur: float = minf(_ach_val(key), float(d["min"]))
	match key:
		"tier":
			return "%s / %s" % [_tier_txt(int(cur)), _tier_txt(int(d["min"]))]
		"time":
			return "%d / %d dk" % [int(cur / 60.0), int(float(d["min"]) / 60.0)]
	return "%s / %s" % [_num(int(cur)), _num(int(d["min"]))]


static func _ach_pattern(d: Dictionary) -> Array:
	match str(d["key"]):
		"tier":
			return P_HORNS if int(d["min"]) >= TierDisplayScript.FINAL_TIER else P_SKULL
		"victory", "victory_solo", "victory_coop", "victory_chars":
			return P_CROWN
		"layer":
			return P_MOON
		"kills":
			return P_SWORD
		"total_kills":
			return P_SWORDS
		"time":
			return P_HOURGLASS
	return P_FLAG


func _medal(d: Dictionary, s: float = 48.0) -> Medal:
	var id: String = d["id"]
	var m := Medal.new(_ach_pattern(d), METAL[ACH_METAL.get(id, "bronz")], not (_data["achievements"] as Dictionary).has(id), s)
	m.pat_px = maxf(Medal.CELL, floorf(s / 26.0)) if _phone else 0.0
	return m


## ------------------------------------------------------------------ kategoriler
func _set_category(c: int, with_sound: bool) -> void:
	_cat = clampi(c, 0, Cat.size() - 1)
	for i in _cat_btns.size():
		FM.set_selected(_cat_btns[i], i == _cat)
	for ch in _col.get_children():
		_col.remove_child(ch)
		ch.queue_free()
	_rows.clear()
	_focus = 0
	match _cat:
		Cat.REKOR:
			_build_records()
		Cat.BASARIM:
			_build_achievements()
	_update_focus()
	_scroll.scroll_vertical = 0
	_update_fade.call_deferred()
	UiAnim.cascade(_col, 0.025)
	if with_sound:
		UISound.play_click()


func _section(title: String, extra: String = "") -> void:
	var h := DK.h(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.custom_minimum_size.y = 48
	h.add_child(DK.glyph(FM.G_DIAMOND, FM.C_GOLD, 3))
	var t := DK.lbl(title, DK.FS_BODY, FM.C_GOLD)
	t.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.03, 1))
	t.add_theme_constant_override("outline_size", 6)
	h.add_child(t)
	if extra != "":
		h.add_child(DK.lbl(extra, DK.FS_LABEL, FM.C_SUB))
	var ln := ColorRect.new()
	ln.color = Color(FM.C_GOLD_DIM, 0.28)
	ln.custom_minimum_size = Vector2(0, 2)
	ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ln.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ln)
	if _col.get_child_count() > 0:
		_col.add_child(DK.sp(0, 18))
	_col.add_child(h)


## Satır: simge + yazı (+ alt yazı) solda, değer sağda; seçiliyken altın zemin + sol altın şerit (ayarlar ekranıyla aynı).
func _add_row(id: String, icon: Control, label: String, sub: String, right: Control) -> void:
	var pc := PanelContainer.new()
	pc.name = "Row_" + id
	pc.custom_minimum_size.y = ROW_H if sub == "" else ROW_H_SUB
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var hb := DK.h(16)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if icon:
		var ib := CenterContainer.new()
		ib.custom_minimum_size = Vector2(56, 0)
		ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ib.add_child(icon)
		hb.add_child(ib)
	var lv := DK.v(-4)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := DK.lbl(label, DK.FS_BODY, FM.C_CREAM)
	lv.add_child(lab)
	if sub != "":
		lv.add_child(DK.lbl(sub, DK.FS_LABEL, FM.C_SUB))
	hb.add_child(lv)
	if right:
		right.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(right)
	pc.add_child(hb)
	var wrap := DK.v(0)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(pc)
	var ln := ColorRect.new()
	ln.color = Color(FM.C_GOLD_DIM, 0.16)
	ln.custom_minimum_size = Vector2(0, 2)
	ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(ln)
	_col.add_child(wrap)
	_rows.append({"panel": pc, "lab": lab})


func _value(t: String, gold: bool = false) -> Label:
	return DK.lbl(t, DK.FS_BODY, FM.C_GOLD if gold else FM.C_GOLD_DIM, HORIZONTAL_ALIGNMENT_RIGHT)


func _new_chip() -> Control:
	var p := PanelContainer.new()
	var s := DK.sb(FM.C_GOLD, Color("#6a4416"), 2, 4)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(DK.lbl("YENİ", DK.FS_LABEL, Color("#24160a"), HORIZONTAL_ALIGNMENT_CENTER))
	return p


func _progress(d: Dictionary, bar_w: float) -> HBoxContainer:
	var h := DK.h(12)
	h.add_child(Bar.new(_ach_frac(d), bar_w))
	var cl := DK.lbl(_ach_count(d), DK.FS_LABEL, FM.C_TAG, HORIZONTAL_ALIGNMENT_RIGHT)
	cl.custom_minimum_size.x = 150
	h.add_child(cl)
	return h


func _build_records() -> void:
	var gl := {"#": FM.C_TAG, "h": FM.C_TAG}
	var fresh: Array = RunRecordsScript.last_run_records(_data)
	_section("EN İYİ KOŞU")
	var recs: Array = [
		["time", P_HOURGLASS, _tm(float(_data["best_time"]))],
		["tier", P_SKULL, _tier_txt(int(_data["best_tier"]))],
		["kills", P_SWORD, _num(int(_data["best_kills"])) if int(_data["best_kills"]) > 0 else "-"],
		["layer", P_MOON, str(int(_data["best_layer"])) if int(_data["best_layer"]) > 0 else "-"],
		["victory_time", P_CROWN, _tm(float(_data["best_victory_time"]))],
	]
	var first_fresh: int = -1
	for r: Array in recs:
		var key: String = r[0]
		var is_new: bool = fresh.has(key)
		var right := DK.h(14)
		if is_new:
			right.add_child(_new_chip())
			if first_fresh < 0:
				first_fresh = _rows.size()
		right.add_child(_value(r[2], is_new))
		_add_row(key, Pic.new(r[1], gl, 3), str(RunRecordsScript.RECORD_LABELS[key]), "", right)
	_section("TOPLAM")
	_add_row("runs", Pic.new(P_FLAG, gl, 3), "Toplam koşu", "", _value(str(int(_data["runs"]))))
	var chars: Array = _data["victory_chars"]
	var vic := DK.h(10)
	for i in mini(chars.size(), MAX_VICTORY_FACES):
		vic.add_child(DK.icon(LobbyUI.face_texture(str(Characters.get_def(int(chars[i])).get("portrait", ""))), 48))
	vic.add_child(_value(str(int(_data["victories"]))))
	_add_row("victories", Pic.new(P_CROWN, gl, 3), "Zafer", "Kazanan kahramanlar" if not chars.is_empty() else "", vic)
	_add_row("total_kills", Pic.new(P_SWORDS, gl, 3), "Toplam öldürme", "", _value(_num(int(_data["total_kills"]))))
	_add_row("total_time", Pic.new(P_HOURGLASS, gl, 3), "Toplam oyun süresi", "", _value(_hours(float(_data["total_time"]))))
	var next: Dictionary = _next_achievement()
	if not next.is_empty():
		_section("SIRADAKİ BAŞARIM")
		_add_row("next_" + str(next["id"]), _medal(next), str(next["name"]), str(next["desc"]), _progress(next, 220))
	_focus = maxi(first_fresh, 0)


## En yakın kilitli başarım (ilerleme oranı en yüksek; eşitlikte tablo sırası). Hepsi açıksa boş.
func _next_achievement() -> Dictionary:
	var best: Dictionary = {}
	var best_f: float = -1.0
	var unlocked: Dictionary = _data["achievements"]
	for d: Dictionary in AchievementsScript.DEFS:
		if unlocked.has(str(d["id"])):
			continue
		var f: float = _ach_frac(d)
		if f > best_f:
			best_f = f
			best = d
	return best


func _build_achievements() -> void:
	var unlocked: Dictionary = _data["achievements"]
	var locked: Array = []
	var done: Array = []
	for d: Dictionary in AchievementsScript.DEFS:
		if unlocked.has(str(d["id"])):
			done.append(d)
		else:
			locked.append(d)
	## sort_custom kararlı değil: eşitlikte tablo sırası korunsun diye sıra no'su ikinci anahtar
	var order: Dictionary = {}
	for i in AchievementsScript.DEFS.size():
		order[str(AchievementsScript.DEFS[i]["id"])] = i
	locked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var fa: float = _ach_frac(a)
		var fb: float = _ach_frac(b)
		return fa > fb if fa != fb else int(order[a["id"]]) < int(order[b["id"]]))
	done.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: int = int(unlocked[a["id"]])
		var tb: int = int(unlocked[b["id"]])
		return ta > tb if ta != tb else int(order[a["id"]]) < int(order[b["id"]]))
	if not locked.is_empty():
		_section("YAKINDA", "%d kilitli" % locked.size())
		for d: Dictionary in locked:
			_add_row(str(d["id"]), _medal(d), str(d["name"]), str(d["desc"]), _progress(d, 200))
	if not done.is_empty():
		_section("AÇILANLAR", "%d" % done.size())
		for d: Dictionary in done:
			var right := DK.h(10)
			right.add_child(DK.glyph(G_CHECK, FM.C_GOLD, 3))
			right.add_child(DK.lbl(_date(int(unlocked[d["id"]])), DK.FS_LABEL, FM.C_SUB))
			_add_row(str(d["id"]), _medal(d), str(d["name"]), str(d["desc"]), right)


## ------------------------------------------------------------------ odak + kaydırma
func _update_focus() -> void:
	for i in _rows.size():
		var r: Dictionary = _rows[i]
		var on: bool = i == _focus
		var s := StyleBoxFlat.new()
		s.bg_color = Color(FM.C_GOLD, 0.09) if on else Color(0, 0, 0, 0)
		if on:
			s.border_width_left = 6
			s.border_color = FM.C_GOLD
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		(r["panel"] as PanelContainer).add_theme_stylebox_override("panel", s)
		(r["lab"] as Label).add_theme_color_override("font_color", FM.C_GOLD if on else FM.C_CREAM)


func _move_focus(d: int) -> void:
	if _rows.is_empty():
		return
	var n: int = clampi(_focus + d, 0, _rows.size() - 1)
	if n == _focus:
		return
	_focus = n
	_update_focus()
	## seçili satır listenin görünen kısmında kalsın (alttaki solma payıyla); ilk satırda bölüm başlığı da görünsün
	if _focus == 0:
		_scroll.scroll_vertical = 0
	else:
		_scroll.ensure_control_visible(_rows[_focus]["panel"])


func _update_fade() -> void:
	if not is_instance_valid(_scroll) or not is_instance_valid(_fade):
		return
	var sbar: VScrollBar = _scroll.get_v_scroll_bar()
	_fade.visible = sbar.max_value - sbar.page > 1.0 and sbar.value < sbar.max_value - sbar.page - 1.0


func _act(event: InputEvent, names: Array) -> bool:
	for n: String in names:
		if InputMap.has_action(n) and event.is_action_pressed(n, true):
			return true
	return false


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if _phone: ## telefonda dokunmatik: sadece geri (sistem geri tuşu = ui_cancel)
		if _act(event, ["ui_cancel", "pause_game"]) and not event.is_echo():
			close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		if not Rect2(Vector2.ZERO, _scroll.size).has_point(_scroll.get_local_mouse_position()):
			return ## liste penceresi dışında (kaymış, görünmeyen satırlar seçilmesin)
		for i in _rows.size():
			var pc: Control = _rows[i]["panel"]
			if Rect2(Vector2.ZERO, pc.size).has_point(pc.get_local_mouse_position()): ## telefonda ölçekli - yerel konum
				if i != _focus:
					_focus = i
					_update_focus()
				break
		return
	var handled := true
	if _act(event, ["ui_cancel", "pause_game"]) and not event.is_echo():
		close()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_Q \
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_LEFT_SHOULDER:
		_set_category(wrapi(_cat - 1, 0, Cat.size()), true)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_E, KEY_TAB] \
			or event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
		_set_category(wrapi(_cat + 1, 0, Cat.size()), true)
	elif _act(event, ["ui_up", "move_up"]):
		_move_focus(-1)
	elif _act(event, ["ui_down", "move_down"]):
		_move_focus(1)
	elif _act(event, ["ui_left", "move_left"]):
		_set_category(wrapi(_cat - 1, 0, Cat.size()), true)
	elif _act(event, ["ui_right", "move_right"]):
		_set_category(wrapi(_cat + 1, 0, Cat.size()), true)
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


func _on_open_balance_folder() -> void:
	var dir: String = ProjectSettings.globalize_path("user://balans")
	DirAccess.make_dir_recursive_absolute(dir)
	OS.shell_open(dir)


## ------------------------------------------------------------------ telefon
## TELEFON (2026-10-19; kullanıcı seçimi prototip S = B "Yan Ray + Detay", mobil_proto.gd B_rekor): ray EN İYİ / BAŞARIM, ortada
## rekor satırları (madalya + ad + iri değer, son koşuda kırılana YENİ) ya da başarım listesi (kilitliler ilerlemeyle, açılanlar
## tarihle), sağda SIRADAKİ başarım (iri madalya + ilerleme) + SON AÇILANLAR. Veri / sıralama masaüstüyle aynı yardımcılardan.
var _phone: bool = false
var _ph: Dictionary = {}
var _ph_tab: int = 0


func _build_phone() -> void:
	var root := Control.new()
	root.name = "PhoneRecords"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	PK.fit(root)
	_ph = PK.b_frame(root, [["EN İYİ", PK.G_TROPHY], ["BAŞARIM", PK.G_STAR]], close, 820.0, 0.6)
	var tabs: Array = _ph["tabs"]
	for i in tabs.size():
		var ti: int = i
		(tabs[i] as Button).pressed.connect(func() -> void:
			if ti != _ph_tab:
				UISound.play_click()
				_ph_set_tab(ti))
	_ph_fill_detail()
	_ph_set_tab(0)


func _ph_set_tab(i: int) -> void:
	_ph_tab = i
	PK.set_rail(_ph["tabs"], i)
	PK.set_page(_ph["mid"], _ph_records_page() if i == 0 else _ph_achievements_page())


func _ph_records_page() -> Control:
	var v := DK.v(16)
	v.add_child(PK.lbl("EN İYİLER", PK.FS_TITLE, DK.C_ACCENT))
	var fresh: Array = RunRecordsScript.last_run_records(_data)
	var recs: Array = [
		["time", P_HOURGLASS, _tm(float(_data["best_time"]))],
		["tier", P_SKULL, _tier_txt(int(_data["best_tier"]))],
		["kills", P_SWORD, _num(int(_data["best_kills"])) if int(_data["best_kills"]) > 0 else "-"],
		["layer", P_MOON, str(int(_data["best_layer"])) if int(_data["best_layer"]) > 0 else "-"],
		["victory_time", P_CROWN, _tm(float(_data["best_victory_time"]))],
	]
	for r: Array in recs:
		var is_new: bool = fresh.has(str(r[0]))
		var row := PanelContainer.new()
		row.name = "Rec_" + str(r[0])
		row.custom_minimum_size.y = 120
		row.add_theme_stylebox_override("panel", PK.sb(Color(DK.C_INSET, 0.7), DK.C_ACCENT if is_new else DK.C_LINE, 4 if is_new else 3, 16))
		var h := DK.h(24)
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 24)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var md := Medal.new(r[1], METAL["altin"], false, 88.0)
		md.pat_px = 3.0
		m.add_child(md)
		h.add_child(m)
		var lab := PK.lbl(str(RunRecordsScript.RECORD_LABELS[str(r[0])]), PK.FS_BODY, DK.C_TEXT)
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lab.clip_text = true
		lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(lab)
		if is_new:
			var chip := PK.button("YENİ", "danger", PK.FS_SMALL, [], 0.0, 52.0)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(chip)
		var val := PK.lbl(str(r[2]), 80, DK.C_PRICE, HORIZONTAL_ALIGNMENT_RIGHT)
		val.custom_minimum_size.x = 320
		h.add_child(val)
		h.add_child(DK.sp(16))
		row.add_child(h)
		v.add_child(row)
	v.add_child(DK.sp(0, 0, false, true))
	var runs: int = int(_data["runs"])
	var foot: String = "Henüz koşu yok" if runs <= 0 else "Toplam %d koşu, %d zafer, %s öldürme, %s oyun" % [runs, int(_data["victories"]),
			_num(int(_data["total_kills"])), _hours(float(_data["total_time"]))]
	v.add_child(PK.lbl(foot, PK.FS_SMALL, DK.C_DIM))
	return v


func _ph_achievements_page() -> Control:
	var v := DK.v(12)
	var unlocked: Dictionary = _data["achievements"]
	var head := DK.h(16)
	var t := PK.lbl("BAŞARIMLAR", PK.FS_TITLE, DK.C_ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(PK.lbl("%d / %d açıldı" % [unlocked.size(), AchievementsScript.DEFS.size()], PK.FS_SMALL, DK.C_DIM))
	v.add_child(head)
	var lst: Array = PK.scroll_list(12)
	v.add_child(lst[0])
	var box: VBoxContainer = lst[1]
	for d: Dictionary in _ph_sorted_achievements():
		var done: bool = unlocked.has(str(d["id"]))
		var row := PanelContainer.new()
		row.custom_minimum_size.y = 112
		row.add_theme_stylebox_override("panel", PK.sb(Color(DK.C_INSET, 0.7), DK.C_LINE, 3, 16, 12.0))
		var h := DK.h(20)
		h.add_child(_medal(d, 80.0))
		var tv := DK.v(-4)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(PK.lbl(str(d["name"]), PK.FS_BODY, DK.C_TEXT if done else DK.C_TEXT))
		var desc := PK.lbl(str(d["desc"]), PK.FS_SMALL, DK.C_DIM)
		desc.clip_text = true
		desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tv.add_child(desc)
		h.add_child(tv)
		var right := DK.h(12)
		right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if done:
			right.add_child(PK.glyph(PK.G_CHECK, DK.C_ACCENT, 5))
			right.add_child(PK.lbl(_date(int(unlocked[d["id"]])), PK.FS_SMALL, DK.C_DIM))
		else:
			var bar := Bar.new(_ach_frac(d), 220.0)
			bar.custom_minimum_size.y = 24
			right.add_child(bar)
			var cl := PK.lbl(_ach_count(d), PK.FS_SMALL, DK.C_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
			cl.custom_minimum_size.x = 170
			right.add_child(cl)
		h.add_child(right)
		h.add_child(DK.sp(12))
		row.add_child(h)
		box.add_child(row)
	return v


## Masaüstüyle aynı sıra: kilitliler ilerleme oranına göre (eşitlikte tablo sırası), sonra açılanlar en yeniden.
func _ph_sorted_achievements() -> Array:
	var unlocked: Dictionary = _data["achievements"]
	var order: Dictionary = {}
	var locked: Array = []
	var done: Array = []
	for i in AchievementsScript.DEFS.size():
		var d: Dictionary = AchievementsScript.DEFS[i]
		order[str(d["id"])] = i
		(done if unlocked.has(str(d["id"])) else locked).append(d)
	locked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var fa: float = _ach_frac(a)
		var fb: float = _ach_frac(b)
		return fa > fb if fa != fb else int(order[a["id"]]) < int(order[b["id"]]))
	done.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: int = int(unlocked[a["id"]])
		var tb: int = int(unlocked[b["id"]])
		return ta > tb if ta != tb else int(order[a["id"]]) < int(order[b["id"]]))
	return locked + done


## Sağ sütun: sıradaki başarım + son açılanlar.
func _ph_fill_detail() -> void:
	var det: VBoxContainer = _ph["det"]
	det.add_child(PK.lbl("SIRADAKİ", PK.FS_TITLE, DK.C_ACCENT))
	var nx: Dictionary = _next_achievement()
	if nx.is_empty():
		det.add_child(DK.sp(0, 24))
		det.add_child(PK.lbl("Bütün başarımlar açıldı", PK.FS_BODY, DK.C_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		det.add_child(DK.sp(0, 24))
		var mc := CenterContainer.new()
		mc.add_child(_medal(nx, 224.0))
		det.add_child(mc)
		det.add_child(DK.sp(0, 16))
		det.add_child(PK.lbl(str(nx["name"]), PK.FS_TITLE, DK.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var desc := PK.lbl(str(nx["desc"]), PK.FS_SMALL, DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		det.add_child(desc)
		det.add_child(DK.sp(0, 20))
		var bar := Bar.new(_ach_frac(nx), 0.0)
		bar.custom_minimum_size.y = 32
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		det.add_child(bar)
		det.add_child(PK.lbl(_ach_count(nx), PK.FS_SMALL, DK.C_DIM, HORIZONTAL_ALIGNMENT_RIGHT))
	det.add_child(DK.sp(0, 0, false, true))
	var unlocked: Dictionary = _data["achievements"]
	var recent: Array = []
	for d: Dictionary in _ph_sorted_achievements():
		if unlocked.has(str(d["id"])):
			recent.append(d)
	det.add_child(PK.lbl("SON AÇILANLAR", PK.FS_BODY, DK.C_DIM))
	det.add_child(DK.sp(0, 12))
	var row := DK.h(28)
	if recent.is_empty():
		row.add_child(PK.lbl("Henüz yok", PK.FS_SMALL, DK.C_DIM))
	for i in mini(recent.size(), 5):
		row.add_child(_medal(recent[i], 128.0))
	det.add_child(row)
	det.add_child(DK.sp(0, 24))


## Ekranı kapatır: ESC/B ya da GERİ (ayarlar ekranıyla aynı: aynı basış menüde başka bir şeyi tetiklemesin).
func close() -> void:
	GameManager.mark_ui_cancel_consumed()
	UISound.play_click()
	closed.emit()
	queue_free()
