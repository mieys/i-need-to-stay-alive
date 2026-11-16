extends SceneTree

## SEÇİM İŞARETİ 4 prototip (2026-11-16, madde 759 tek kutu kartlarının devamı; kullanıcı: "seçildiğini gösteren şey için yeni 4 prototip
## hazırlar mısın"). Gerçek character_select.tscn (tek kutu oyunda); kartların seçim görseli BELLEKTE değiştirilir (oyun kodu değişmez).
## Daha önce denenenler (madde 538: büyüme / halka yanar / köşebent / ad levhası / yükselen kart) tekrarlanmaz. Hepsinde seçili ad altın.
##   A Spot Işığı  : seçili + üstündeki tam parlak, diğer kartlar kararır (%60)
##   B İşaretçi    : çerçevenin üst kenarına oturan aşağı bakan piksel ok (seçili altın, oyunda 1 sanat px yavaş zıplar; üstündeki açık ahşap, sabit)
##   C Altın Hale  : çerçevenin dışında 3 kademe DÜZ saydam altın hale (dither yok, köşeler yuvarlak basamak; oyunda yavaş nefes);
##                   üstündeki: 2 kademe açık ahşap
##   D Altın Çerçeve: çerçevenin kendisi (açık kenar + ahşap + koyu ahşap) altına döner, dış hat koyu kalır; üstündeki: açık ahşap tonlar
## Durumlar: Oakley SEÇİLİ, Matthew ÜSTÜNDE; sağda seçili evcil + bir sonraki ÜSTÜNDE. Önce oyundaki şimdiki hal (SIMDI) yakalanır.
## Çıktı SS_OUT/<harf>_kar.png (ilk 2 satır), <harf>_karo.png (evcil ilk satır), SIMDI_tam.png; birleştirme ozet.py.

var _dk = null
var _ht = null
var _tf = null
var _desk: Node = null

const SEL := 2 ## Oakley
const HOV := 3 ## Matthew
const VARIANTS := ["A", "B", "C", "D"]
const DIM := Color(0.6, 0.58, 0.62, 1.0)


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
	_tf = load("res://scripts/hud_tray_frame.gd")
	var dir: String = OS.get_environment("SS_OUT")
	DirAccess.make_dir_recursive_absolute(dir)
	AudioServer.set_bus_mute(0, true)
	load("res://scripts/meta_progress.gd").set_unlock_all(true)
	change_scene_to_file("res://scenes/character_select.tscn")
	await _wait(2.5)
	_desk = current_scene.get("_desk")
	_desk.call("show_character", SEL, false)
	_desk.call("_set_tab", "pet")
	await _wait(0.5)
	var cards: Dictionary = _desk.get("_cards")
	var grid: Control = (cards[SEL]["btn"] as Control).get_parent()
	var tg: Control = _desk.get("_tab_grid")
	await RenderingServer.frame_post_draw
	var img0: Image = root.get_texture().get_image()
	var s0: float = img0.get_width() / 1920.0
	img0.get_region(Rect2i(int(488 * s0), int(24 * s0), int(1400 * s0), int(1024 * s0))).save_png(dir.path_join("SIMDI_tam.png"))
	_crops(img0, s0, grid, tg, dir, "SIMDI")
	for v: String in VARIANTS:
		_apply(v)
		await _wait(0.3)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		_crops(img, img.get_width() / 1920.0, grid, tg, dir, v)
	load("res://scripts/meta_progress.gd").set_unlock_all(false)
	print("BITTI")
	quit(0)


func _crops(img: Image, s: float, grid: Control, tg: Control, dir: String, tag: String) -> void:
	var gr: Rect2 = grid.get_global_rect()
	var r1 := Rect2(gr.position.x - 14.0, gr.position.y - 16.0, gr.size.x + 28.0, 138.0 * 2.0 + 16.0 + 26.0)
	var tr: Rect2 = tg.get_global_rect()
	var r2 := Rect2(tr.position.x - 12.0, tr.position.y - 16.0, 604.0, 124.0 + 22.0)
	for pair: Array in [[r1, "kar"], [r2, "karo"]]:
		var r: Rect2 = pair[0]
		img.get_region(Rect2i(int(r.position.x * s), int(r.position.y * s), int(r.size.x * s), int(r.size.y * s))).save_png(
				dir.path_join("%s_%s.png" % [tag, pair[1]]))


func _clear(holder: Node) -> void:
	for c in holder.get_children():
		if c.has_meta("proto"):
			holder.remove_child(c)
			c.free()


## Tüm kartlar / karolar: önce oyundaki seçim görseli (köşebent + orta halka) sıfırlanır, sonra prototip uygulanır.
func _apply(v: String) -> void:
	var cards: Dictionary = _desk.get("_cards")
	for id in cards:
		var c: Dictionary = cards[id]
		var b: Button = c["btn"]
		var holder: Control = c["face"]
		(c["brk"] as Object).call("set_color", Color(0, 0, 0, 0))
		holder.call("set_accent", Color(0, 0, 0, 0))
		_clear(holder)
		b.modulate = Color.WHITE
		var st: String = "sel" if int(id) == SEL else ("hov" if int(id) == HOV else "")
		(c["name"] as Label).add_theme_color_override("font_color", _dk.C_ACCENT if st == "sel" else _dk.C_TEXT)
		_decorate(v, st, holder, b, 3.0)
	var tg: Control = _desk.get("_tab_grid")
	var hov_done: bool = false
	for b: Button in tg.get_children():
		var vb: Control = b.get_child(0)
		var holder: Control = (vb.get_child(0) as Control).get_child(0)
		var lab: Label = vb.get_child(1)
		for ch in holder.get_children():
			if ch.has_method("set_color"):
				ch.call("set_color", Color(0, 0, 0, 0))
		holder.call("set_accent", Color(0, 0, 0, 0))
		_clear(holder)
		b.modulate = Color.WHITE
		var on: bool = bool(b.get_meta("tile_on", false))
		var st: String = "sel" if on else ""
		if not on and not hov_done:
			st = "hov"
			hov_done = true
		lab.add_theme_color_override("font_color", _dk.C_ACCENT if st == "sel" else _dk.C_TEXT)
		_decorate(v, st, holder, b, 2.0)


func _overlay(holder: Control) -> Control:
	var o := Control.new()
	o.set_meta("proto", true)
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(o)
	return o


func _decorate(v: String, st: String, holder: Control, b: Button, t: float) -> void:
	match v:
		"A":
			if st == "":
				b.modulate = DIM
		"B":
			if st != "":
				var o := _overlay(holder)
				var base: Color = _dk.C_ACCENT if st == "sel" else _ht.PICK_HOVER
				o.draw.connect(func() -> void: _draw_arrow(o, t, base))
		"C":
			if st != "":
				var o := _overlay(holder)
				var col: Color = _dk.C_ACCENT if st == "sel" else _ht.PICK_HOVER
				var alphas: Array = [0.62, 0.36, 0.16] if st == "sel" else [0.42, 0.18]
				o.draw.connect(func() -> void: _draw_halo(o, t, col, alphas))
		"D":
			if st != "":
				var o := _overlay(holder)
				var ft: float = float((holder.get("frame") as Object).get("t"))
				var cmap: Dictionary
				if st == "sel":
					cmap = {"H": _dk.C_ACCENT.lightened(0.4), "A": _dk.C_ACCENT, "L": Color("#b07a32")}
				else:
					cmap = {"H": _ht.PICK_HOVER.lightened(0.3), "A": _ht.PICK_HOVER, "L": _ht.RIM}
				o.draw.connect(func() -> void: _draw_tray(o, ft, cmap))


## Aşağı bakan ok (9x6 sanat px): ucu çerçevenin üst kenarının 2 sanat px içinde, gövdesi çerçevenin üstünde.
func _draw_arrow(ci: Control, t: float, base: Color) -> void:
	var rows: Array[String] = ["ooooooooo", "oHHHHHHHo", ".oAAAAAo.", "..oAAAo..", "...oAo...", "....o...."]
	var x0: float = floorf((ci.size.x - 9.0 * t) * 0.5)
	var y0: float = 2.0 * t - 6.0 * t
	var hi: Color = base.lightened(0.35)
	for y in rows.size():
		for x in rows[y].length():
			var ch: String = rows[y][x]
			if ch == ".":
				continue
			var c: Color = _ht.OUTLINE if ch == "o" else (hi if ch == "H" else base)
			ci.draw_rect(Rect2(x0 + x * t, y0 + y * t, t, t), c)


## Hale: çerçeve dikdörtgeninin dışındaki her sanat pikseli, dikdörtgene uzaklığına göre kademe alır (köşede öklid -> yuvarlak basamak).
func _draw_halo(ci: Control, t: float, col: Color, alphas: Array) -> void:
	var n: int = alphas.size()
	var w: float = ci.size.x
	var h: float = ci.size.y
	var nx: int = int(ceilf(w / t)) + 2 * n
	var ny: int = int(ceilf(h / t)) + 2 * n
	for iy in ny:
		for ix in nx:
			var px: float = -n * t + ix * t
			var py: float = -n * t + iy * t
			var cx: float = px + t * 0.5
			var cy: float = py + t * 0.5
			var dx: float = maxf(0.0, maxf(-cx, cx - w))
			var dy: float = maxf(0.0, maxf(-cy, cy - h))
			if dx <= 0.0 and dy <= 0.0:
				continue
			var band: int = int(floorf(sqrt(dx * dx + dy * dy) / t))
			if band >= n:
				continue
			ci.draw_rect(Rect2(px, py, t, t), Color(col.r, col.g, col.b, float(alphas[band])))


## Gömme Tepsi çerçevesi (hud_tray_frame.gd _draw_px) kendi renk eşlemesiyle; o (dış hat / iç koyu çizgi) değişmez.
func _draw_tray(ci: Control, t: float, cmap: Dictionary) -> void:
	var aw: int = int(floorf(ci.size.x / t))
	var ah: int = int(floorf(ci.size.y / t))
	var o: Vector2 = ((ci.size - Vector2(aw, ah) * t) * 0.5).floor()
	_tile(ci, _tf.TL, o, t, cmap)
	_tile(ci, _tf.TR, o + Vector2((aw - 6) * t, 0.0), t, cmap)
	_tile(ci, _tf.BL, o + Vector2(0.0, (ah - 6) * t), t, cmap)
	_tile(ci, _tf.BR, o + Vector2((aw - 6) * t, (ah - 6) * t), t, cmap)
	var run_w: float = (aw - 12) * t
	var run_h: float = (ah - 12) * t
	for k in 4:
		var c_tl: Color = _cm(str(_tf.EDGE_TL[k]), cmap)
		var c_br: Color = _cm(str(_tf.EDGE_BR[k]), cmap)
		ci.draw_rect(Rect2(o.x + 6.0 * t, o.y + k * t, run_w, t), c_tl)
		ci.draw_rect(Rect2(o.x + 6.0 * t, o.y + (ah - 1 - k) * t, run_w, t), c_br)
		ci.draw_rect(Rect2(o.x + k * t, o.y + 6.0 * t, t, run_h), c_tl)
		ci.draw_rect(Rect2(o.x + (aw - 1 - k) * t, o.y + 6.0 * t, t, run_h), c_br)


func _tile(ci: Control, rows: Array, p: Vector2, t: float, cmap: Dictionary) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == ".":
				continue
			ci.draw_rect(Rect2(p.x + x * t, p.y + y * t, t, t), _cm(row[x], cmap))


func _cm(ch: String, cmap: Dictionary) -> Color:
	if ch == "o":
		return _ht.OUTLINE
	return cmap.get(ch, _ht.RIM)
