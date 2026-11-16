extends SceneTree

## Karakter stat çubukları 4 PROTOTİP (madde 748, kullanıcı: "bu tasarımlar çok kötü, 4 prototip hazırla, uyumlu olsun").
## Gerçek character_select.tscn; orta paneldeki ad / temel stat satırı (+ şimdiki çubuklar) gizlenir, yerine her prototipin bloğu konur.
## Oyun kodu DEĞİŞMEZ - seçilen prototip sonra lobby_select_desktop.gd'ye taşınır.
##   A Birleşik tablo  : solda ad / lakap / özel stat; sağda 4 uzun satır = ikon + ad + çubuk + ilgili sayı (Güç / Can / Hız). Ayrı stat ızgarası yok.
##   B İki kuyu        : üstte ad + lakap tek satır; altında eşit iki koyu kuyu: temel statlar listesi | 4 çubuk listesi (satırlar hizalı).
##   C Çerçeveli şerit : üst satır eskisi gibi (ad solda, temel statlar sağda); altında tam genişlik tek kuyu, 4 eşit hücre, ince ayraçlar.
##   D Dikey gösterge  : solda ad; ortada 4 dikey çubuk (alttan dolar) + altlarında ikon; sağda temel statlar 4 satır, aynı yükseklikte.
## SS_OUT klasörüne <harf>_<id>.png (orta panel kırpıntısı) yazar; "PROTO" satırları taşma ölçümü.

## Kitler _run içinde load() ile: -s betiği autoload'lardan ÖNCE derlenir, preload zinciri (weapon_catalog -> GameManager) kırılıyordu.
var _dk = null
var _ht = null
var _wsb = null
var _mk = null

const CHARS := [1, 10, 12] ## Talon (tipik), Seraphine (en uzun ad + özel stat), Ulric (en uzun lakap)
const VARIANTS := ["A", "B", "C", "D"]

var _desk: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	_dk = load("res://scripts/menu_dark_kit.gd")
	_ht = load("res://scripts/hud_theme.gd")
	_wsb = load("res://scripts/weapon_stat_bars.gd")
	_mk = load("res://scripts/menu_kit.gd")
	var dir: String = OS.get_environment("SS_OUT")
	DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	load("res://scripts/meta_progress.gd").set_unlock_all(true)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(2.5)
	_desk = current_scene.get("_desk")
	var nh: Control = (_desk.get("_stats") as Control).get_parent()
	var mv: Control = nh.get_parent()
	var mid: Control = mv.get_parent()
	nh.visible = false
	var block: Control = null
	for v: String in VARIANTS:
		for id: int in CHARS:
			_desk.call("show_character", id, false)
			if block != null:
				mv.remove_child(block)
				block.free()
			block = _build(v, id)
			mv.add_child(block)
			mv.move_child(block, nh.get_index() + 1)
			await _wait(0.3)
			print("PROTO %s %d blok=%s orta_min_h=%.0f orta_h=%.0f" % [v, id, str(block.size), mid.get_combined_minimum_size().y, mid.size.y])
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			var s: float = img.get_width() / 1920.0
			img.get_region(Rect2i(int(488 * s), int(548 * s), int(760 * s), int(504 * s))).save_png(dir.path_join("%s_%02d.png" % [v, id]))
	load("res://scripts/meta_progress.gd").set_unlock_all(false)
	quit(0)


## ------------------------------------------------------------------ ortak parçalar
func _tex(key: String) -> Texture2D:
	return _desk.call("_stat_tex", key) as Texture2D


func _base_rows(id: int) -> Array:
	var bs: Dictionary = Characters.get_base_stats(id)
	var rows: Array = [["max_health", "Can", str(int(bs.get("hp", 100)))], ["speed", "Hız", str(int(bs.get("speed", 252)))],
			["damage", "Güç", str(int(bs.get("ap", 10)))]]
	var sig: Dictionary = _mk.signature_info(id)
	if not sig.is_empty():
		rows.append([str(sig["icon"]), str(sig["name"]), str(sig["value"])])
	return rows


## Temel stat hücresi (orta panelin şimdiki görünümü): ikon 32 + sönük ad + değer.
func _base_cell(row: Array, value_right: bool = false) -> HBoxContainer:
	var hb = _dk.h(8)
	hb.add_child(_dk.icon(_tex(row[0]), 32))
	var n = _dk.lbl(str(row[1]), _dk.FS_LABEL, _dk.C_DIM)
	if value_right:
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(n)
	hb.add_child(_dk.lbl(str(row[2]), _dk.FS_LABEL))
	return hb


func _name_col(id: int, min_w: float = 0.0) -> VBoxContainer:
	var d: Dictionary = Characters.get_def(id)
	var c = _dk.v(0)
	c.custom_minimum_size.x = min_w
	c.add_child(_dk.lbl(str(d.get("name", "")), _dk.FS_TITLE, _dk.C_ACCENT))
	var t: String = str(d.get("title_name", ""))
	if t != "":
		c.add_child(_dk.lbl(t, _dk.FS_LABEL, _dk.C_DIM))
	return c


func _pips(i: int, val: int, pip_w: int) -> Control:
	var p := HPips.new(_wsb.CHAR_ROWS[i][2], val, pip_w, _ht.DOCK_MARK, _ht.OUTLINE)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _bar_label(i: int, min_w: float = 0.0) -> Label:
	var l = _dk.lbl(str(_wsb.CHAR_ROWS[i][1]), _dk.FS_LABEL, _dk.C_DIM)
	l.custom_minimum_size.x = min_w
	return l


func _bar_icon(i: int) -> Control:
	return _dk.icon(_tex(str(_wsb.CHAR_ROWS[i][0])), 32)


func _build(v: String, id: int) -> Control:
	var vals: Array = Characters.stat_bars(id)
	match v:
		"A":
			return _build_a(id, vals)
		"B":
			return _build_b(id, vals)
		"C":
			return _build_c(id, vals)
	return _build_d(id, vals)


## ------------------------------------------------------------------ A: birleşik tablo
func _build_a(id: int, vals: Array) -> Control:
	var base: Array = _base_rows(id)
	var row = _dk.h(12)
	var left := _name_col(id, 200.0)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if base.size() > 3:
		left.add_child(_dk.sp(0, 8))
		var chip = _dk.h(8)
		chip.add_child(_dk.icon(_tex(base[3][0]), 32))
		chip.add_child(_dk.wrap(tr(str(base[3][1])) + " " + str(base[3][2]), _dk.FS_LABEL, _dk.C_TEXT, 156.0, 2))
		left.add_child(chip)
	row.add_child(left)
	var tbl = _dk.v(6)
	tbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var link: Array = [2, 0, 1, -1] ## Hasar -> Güç, Savunma -> Can, Çeviklik -> Hız, Destek -> (yok)
	for i in 4:
		var r = _dk.h(9)
		r.add_child(_bar_icon(i))
		r.add_child(_bar_label(i, 104.0))
		r.add_child(_pips(i, int(vals[i]), 6))
		r.add_child(_dk.sp(0, 0, true))
		if link[i] >= 0:
			var b: Array = base[link[i]]
			var vb = _dk.h(6)
			vb.add_child(_dk.lbl(str(b[1]), _dk.FS_LABEL, _dk.C_DIM))
			vb.add_child(_dk.lbl(str(b[2]), _dk.FS_LABEL))
			r.add_child(vb)
		tbl.add_child(r)
	row.add_child(tbl)
	return row


## ------------------------------------------------------------------ B: iki kuyu
func _build_b(id: int, vals: Array) -> Control:
	var d: Dictionary = Characters.get_def(id)
	## Orta panel bütçesi ~193 px (A-D ölçümü): ad bu prototipte bir boy küçük (FS_BODY), kuyu dolgusu 6, satır aralığı 2.
	var col = _dk.v(6)
	var nrow = _dk.h(14)
	nrow.add_child(_dk.lbl(str(d.get("name", "")), _dk.FS_BODY, _dk.C_ACCENT))
	var t: String = str(d.get("title_name", ""))
	if t != "":
		var tl = _dk.lbl(t, _dk.FS_LABEL, _dk.C_DIM)
		tl.size_flags_vertical = Control.SIZE_SHRINK_END
		nrow.add_child(tl)
	col.add_child(nrow)
	var wells = _dk.h(12)
	var lw = _dk.box(_dk.C_INSET, _dk.C_LINE, 6)
	var rw = _dk.box(_dk.C_INSET, _dk.C_LINE, 6)
	for w: Control in [lw, rw]:
		w.custom_minimum_size.x = 358.0
		w.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wells.add_child(w)
	var lv = _dk.v(2)
	for row: Array in _base_rows(id):
		lv.add_child(_base_cell(row, true))
	lw.add_child(lv)
	var rv = _dk.v(2)
	for i in 4:
		var r = _dk.h(9)
		r.add_child(_bar_icon(i))
		r.add_child(_bar_label(i, 100.0))
		r.add_child(_pips(i, int(vals[i]), 5))
		rv.add_child(r)
	rw.add_child(rv)
	col.add_child(wells)
	return col


## ------------------------------------------------------------------ C: çerçeveli şerit
func _build_c(id: int, vals: Array) -> Control:
	var col = _dk.v(10)
	var top = _dk.h(0)
	var nc := _name_col(id)
	nc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(nc)
	top.add_child(_dk.sp(12, 0, true))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 6)
	for row: Array in _base_rows(id):
		g.add_child(_base_cell(row))
	top.add_child(g)
	col.add_child(top)
	var strip = _dk.box(_dk.C_INSET, _dk.C_LINE, 8)
	var sh = _dk.h(0)
	for i in 4:
		if i > 0:
			var line := ColorRect.new()
			line.color = _dk.C_LINE
			line.custom_minimum_size = Vector2(3, 36)
			line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sh.add_child(line)
		var cc := CenterContainer.new()
		cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hb = _dk.h(9)
		hb.add_child(_bar_icon(i))
		var vv = _dk.v(0)
		vv.alignment = BoxContainer.ALIGNMENT_CENTER
		vv.add_child(_bar_label(i))
		vv.add_child(_pips(i, int(vals[i]), 3))
		hb.add_child(vv)
		cc.add_child(hb)
		sh.add_child(cc)
	strip.add_child(sh)
	col.add_child(strip)
	return col


## ------------------------------------------------------------------ D: dikey göstergeler
func _build_d(id: int, vals: Array) -> Control:
	var row = _dk.h(12)
	var left := _name_col(id, 170.0)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	## Göstergeler koyu kuyuda: boş dilimler ahşap zeminde kayboluyordu (ilk çekim).
	var well = _dk.box(_dk.C_INSET, _dk.C_LINE, 8)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gauges = _dk.h(12)
	well.add_child(gauges)
	for i in 4:
		var gv = _dk.v(6)
		gv.tooltip_text = str(_wsb.CHAR_ROWS[i][1])
		var cc := CenterContainer.new()
		cc.add_child(VPips.new(_wsb.CHAR_ROWS[i][2], int(vals[i]), _ht.DOCK_MARK, _ht.OUTLINE))
		gv.add_child(cc)
		gv.add_child(_bar_icon(i))
		gauges.add_child(gv)
	row.add_child(well)
	row.add_child(_dk.sp(0, 0, true))
	var lst = _dk.v(8)
	lst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for b: Array in _base_rows(id):
		lst.add_child(_base_cell(b))
	row.add_child(lst)
	return row


## Dikey 10 dilim (alttan dolar): dilim 6x3 sanat px, arası 1 px; silah çubuğuyla aynı ton kuralı (üst açık, alt koyu).
class VPips extends Control:
	const K := 3
	const N := 10
	var value: int = 0
	var col: Color = Color.WHITE
	var mark: Color
	var outl: Color

	func _init(c: Color, v: int, m: Color, o: Color) -> void:
		col = c
		value = v
		mark = m
		outl = o
		custom_minimum_size = Vector2(6 * K, N * 3 * K + (N - 1) * K)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = 6 * K
		var h: float = 3 * K
		for i in N:
			var y: float = size.y - (i + 1) * h - i * K
			if i < value:
				draw_rect(Rect2(0, y, w, h), col)
				draw_rect(Rect2(0, y, w, K), col.lightened(0.3))
				draw_rect(Rect2(0, y + h - K, w, K), col.darkened(0.35))
			else:
				draw_rect(Rect2(0, y, w, h), mark)
				draw_rect(Rect2(0, y + h - K, w, K), outl)


## Yatay 10 dilim (weapon_stat_bars.gd Pips'in kopyası - o sınıf preload zinciri yüzünden -s betiğinde kullanılamıyor).
class HPips extends Control:
	const K := 3
	const N := 10
	var value: int = 0
	var col: Color = Color.WHITE
	var pw: int = 6
	var mark: Color
	var outl: Color

	func _init(c: Color, v: int, pip_w: int, m: Color, o: Color) -> void:
		col = c
		value = v
		pw = pip_w
		mark = m
		outl = o
		custom_minimum_size = Vector2(N * pw * K + (N - 1) * K, 4 * K)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = pw * K
		var h: float = 4 * K
		for i in N:
			var x: float = i * (w + K)
			if i < value:
				draw_rect(Rect2(x, 0, w, h), col)
				draw_rect(Rect2(x, 0, w, K), col.lightened(0.3))
				draw_rect(Rect2(x, h - K, w, K), col.darkened(0.35))
			else:
				draw_rect(Rect2(x, 0, w, h), mark)
				draw_rect(Rect2(x, h - K, w, K), outl)
