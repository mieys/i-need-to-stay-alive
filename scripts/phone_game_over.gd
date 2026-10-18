extends Control

## TELEFON ÖLÜM / OYUN BİTTİ (2026-10-19; kullanıcı seçimi prototip S = B "Yan Ray + Detay", tools/proto_20261018/mobil_proto.gd
## B_oyun_bitti). Oyun bitince: solda dar ray (ÖZET / HASAR / ÖDÜL), ortada levha (ÖZET: başlık + stat karoları; HASAR: oyuncu
## tablosu + silah / yetenek hasarın; ÖDÜL: Ruh Kıymığı + rekorlar + başarımlar), sağda HASAR SIRASI + TEKRAR OYNA / ANA MENÜ.
## İzleyiciyken (takımda yaşayan var): üstte başlık + açıklama, altta büyük önceki / sonraki düğmeleri ve ANA MENÜ.
## main.gd masaüstü penceresini (Window) gizli olarak kurmaya ve güncellemeye devam eder: veriler onun GameOverBoard'undan okunur,
## düğmeler onun düğmelerine basar (yeniden başlatma oylaması, izleyici kamerası, çıkış temizliği aynı yol), başlık / izlenen
## müttefik / düğme hâlleri her karede oradan aynalanır.

const DK := preload("res://scripts/menu_dark_kit.gd")
const PK := preload("res://scripts/phone_menu_kit.gd")
const TierDisplay := preload("res://scripts/tier_display.gd")
const RunSummaryUI := preload("res://scripts/run_summary_ui.gd")

## Yatay ölçüler simetrik: ray 272 (sekme 176 ortada, iki yanda 48), orta levha raydan ve sağ sütundan 24 açık, sağ sütun içeriği
## levhanın iki iç kenarından 48 (ekran kenarından da 48 - rayın sekmeleriyle aynı).
const RAIL_W := 272.0
const TAB_W := 176.0
const EDGE := 48.0
const DET_W := 860.0 ## sağ sütun içerik genişliği
const DET_PANEL := DET_W + 2.0 * EDGE ## görünür levha genişliği (ekranın sağ kenarına kadar)
const MID_X := RAIL_W + 24.0
const COIN_PATH := "res://assets/ui/newui/icon_gold_coin.png"
const DMG_COL := Color("#e8885a") ## game_over_board.gd DMG / TANK ile aynı
const TANK_COL := Color("#8cc0e6")
const G_SOUL := ["...O...", "..OLO..", ".OLLMO.", ".OLMMO.", "OLLMMDO", "OLMMMDO", "OLMMDDO", ".OMMDO.", ".OMDDO.", "..ODO..", "...O..."]
const SOUL_COLS := {"O": Color("#0b0e15"), "L": Color("#e6dcff"), "M": Color("#b49cf0"), "D": Color("#6f52bc")}
enum Tab { OZET, HASAR, ODUL }

## main.gd'nin masaüstü ölüm penceresi (gizli): VBox/{Title, Subtitle, SpectateRow, StatsBox/Board, DeathButtonRow}.
var pc_window: Control = null

var _final: bool = false
var _tab: int = Tab.OZET
var _sig: String = ""
var _poll: float = 0.0
var _final_root: Control = null
var _spec_root: Control = null
var _rail_btns: Array[Button] = []
var _mid_box: Control = null
var _rank_box: VBoxContainer = null
var _restart: Button = null
var _menu: Button = null
var _spec_title: Label = null
var _spec_sub: Label = null
var _spec_name: Label = null


## Çok renkli piksel sprite (ör. Ruh Kıymığı): desen + harf -> renk.
class ColorSprite extends Control:
	var rows: Array = []
	var cols: Dictionary = {}
	var px: float = 6.0

	func _init(r: Array, c: Dictionary, p: float) -> void:
		rows = r
		cols = c
		px = p
		custom_minimum_size = Vector2(str(rows[0]).length(), rows.size()) * px
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var off := ((size - custom_minimum_size) * 0.5).floor()
		for j in rows.size():
			var row: String = rows[j]
			for i in row.length():
				if cols.has(row[i]):
					draw_rect(Rect2(off + Vector2(i, j) * px, Vector2(px, px)), cols[row[i]])


## Düz çubuk (koyu kuyu + dolgu).
class Bar extends Control:
	var frac: float = 0.0
	var fill: Color = Color.WHITE

	func _init(f: float, c: Color, h: float) -> void:
		frac = clampf(f, 0.0, 1.0)
		fill = c
		custom_minimum_size = Vector2(0, h)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), DK.C_INSET)
		draw_rect(Rect2(Vector2(3, 3), size - Vector2(6, 6)), Color(0.04, 0.04, 0.08))
		var w: float = roundf((size.x - 6.0) * frac)
		if w > 0.0:
			draw_rect(Rect2(3, 3, w, size.y - 6.0), fill)
			draw_rect(Rect2(3, 3, w, 4), fill.lightened(0.3))


func _ready() -> void:
	name = "PhoneGameOver"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = DK.theme()
	_build_spectate()
	_build_final()
	PK.fit(self)
	_apply_mode()


## main.gd her _show_death_overlay'de çağırır (izleyici -> oyun bitti geçişi dahil).
func set_final(on: bool) -> void:
	_final = on
	if is_node_ready():
		_apply_mode()


func _apply_mode() -> void:
	_spec_root.visible = not _final
	_final_root.visible = _final
	mouse_filter = Control.MOUSE_FILTER_STOP if _final else Control.MOUSE_FILTER_IGNORE ## izlerken dünya görünsün
	_sig = ""
	_refresh()


func _pc(path: String) -> Node:
	return pc_window.get_node_or_null(path) if is_instance_valid(pc_window) else null


func _board() -> Control:
	return _pc("VBox/StatsBox/Board") as Control


## ------------------------------------------------------------------ izleyici
func _build_spectate() -> void:
	_spec_root = Control.new()
	_spec_root.name = "Spectate"
	_spec_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_spec_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_spec_root)
	_spec_root.add_child(PK.fade(SIDE_TOP, 300.0, 0.8))
	_spec_root.add_child(PK.fade(SIDE_BOTTOM, 360.0, 0.85))
	var top := DK.v(4)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 32.0
	top.offset_left = PK.SIDE
	top.offset_right = -PK.SIDE
	_spec_title = PK.lbl("SEN ÖLDÜN", PK.FS_HERO, DK.C_BAD, HORIZONTAL_ALIGNMENT_CENTER)
	top.add_child(_spec_title)
	_spec_sub = PK.lbl("", PK.FS_SMALL, DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_spec_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(_spec_sub)
	_spec_root.add_child(top)
	## Altta ortalı iki sıra: önceki / izlenen / sonraki, altında ANA MENÜ (aynı eksende - yana yığılmasın).
	var row := DK.h(24)
	row.name = "SpectateRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -(PK.BOTTOM + 112.0 + 20.0 + PK.BTN_H)
	row.offset_bottom = -(PK.BOTTOM + 112.0 + 20.0)
	var prev := PK.button("", "secondary", PK.FS_BODY, PK.G_CHEV_L, 200.0)
	prev.name = "PrevButton"
	prev.pressed.connect(func() -> void: _press_pc("VBox/SpectateRow/PrevButton"))
	row.add_child(prev)
	var name_box := PK.panel(0.9, 0.0)
	name_box.custom_minimum_size = Vector2(620, PK.BTN_H)
	_spec_name = PK.lbl("", PK.FS_BODY, DK.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
	name_box.add_child(_spec_name)
	row.add_child(name_box)
	var next := PK.button("", "secondary", PK.FS_BODY, PK.G_CHEV_R, 200.0)
	next.name = "NextButton"
	next.pressed.connect(func() -> void: _press_pc("VBox/SpectateRow/NextButton"))
	row.add_child(next)
	_spec_root.add_child(row)
	var menu := PK.button("ANA MENÜ", "ghost", PK.FS_BODY, PK.G_HOME, 420.0, 112.0)
	menu.name = "SpectateMenu"
	menu.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	menu.offset_left = -210.0
	menu.offset_right = 210.0
	menu.offset_top = -(PK.BOTTOM + 112.0)
	menu.offset_bottom = -PK.BOTTOM
	menu.pressed.connect(func() -> void: _press_pc("VBox/DeathButtonRow/BackToMenuButton"))
	_spec_root.add_child(menu)


func _press_pc(path: String) -> void:
	var b := _pc(path) as BaseButton
	if b and not b.disabled:
		b.pressed.emit()


## ------------------------------------------------------------------ oyun bitti
func _build_final() -> void:
	_final_root = Control.new()
	_final_root.name = "Final"
	_final_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_final_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_final_root)
	_final_root.add_child(PK.dim(0.74))
	## Ray: ekranın sol kenarına yaslı koyu şerit + sekmeler.
	var rail := Panel.new()
	rail.name = "Rail"
	rail.add_theme_stylebox_override("panel", PK.sb(Color(PK.C_PANEL, 0.97), DK.C_LINE, 3, 0))
	rail.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	rail.offset_left = -20.0
	rail.offset_right = RAIL_W
	rail.offset_top = -20.0
	rail.offset_bottom = 20.0
	rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final_root.add_child(rail)
	var tabs := DK.v(12)
	tabs.position = Vector2((RAIL_W - TAB_W) * 0.5, PK.TOP)
	var specs: Array = [["ÖZET", PK.G_GRID], ["HASAR", PK.G_SWORD], ["ÖDÜL", []]]
	for i in specs.size():
		var b := _rail_tab(str(specs[i][0]), specs[i][1])
		var ti: int = i
		b.pressed.connect(func() -> void:
			if ti != _tab:
				_tab = ti
				UISound.play_click()
				_sig = ""
				_refresh())
		tabs.add_child(b)
		_rail_btns.append(b)
	_final_root.add_child(tabs)
	## Orta levha.
	var mid := PK.panel(0.9, 32.0)
	mid.name = "Mid"
	mid.add_theme_stylebox_override("panel", PK.sb(Color(PK.C_PANEL, 0.9), DK.C_LINE, 3, 18, 32.0))
	mid.set_anchors_preset(Control.PRESET_FULL_RECT)
	mid.offset_left = MID_X
	mid.offset_top = PK.TOP
	mid.offset_bottom = -PK.TOP
	mid.offset_right = -(DET_PANEL + 24.0)
	_mid_box = Control.new()
	_mid_box.name = "Content"
	_mid_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_mid_box)
	_final_root.add_child(mid)
	## Sağ sütun: tam boy koyu levha + HASAR SIRASI + düğmeler.
	var det := Panel.new()
	det.name = "DetailBack"
	det.add_theme_stylebox_override("panel", PK.sb(Color(DK.C_PANEL2, 0.98), DK.C_LINE_HI, 3, 0))
	det.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	det.offset_left = -DET_PANEL
	det.offset_right = 40.0
	det.offset_top = -20.0
	det.offset_bottom = 20.0
	det.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_final_root.add_child(det)
	var col := DK.v(0)
	col.name = "Detail"
	col.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	col.offset_left = -(DET_PANEL - EDGE)
	col.offset_right = -EDGE
	col.offset_top = PK.TOP + 12.0
	col.offset_bottom = -(PK.TOP + 12.0)
	col.add_child(PK.lbl("HASAR SIRASI", PK.FS_TITLE, DK.C_ACCENT))
	col.add_child(DK.sp(0, 16))
	_rank_box = DK.v(0)
	_rank_box.name = "Ranking"
	_rank_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_rank_box)
	_restart = PK.button("TEKRAR OYNA", "secondary", PK.FS_BODY, PK.G_REROLL, 0.0, 112.0)
	_restart.name = "PhoneRestart"
	_restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restart.pressed.connect(func() -> void: _press_pc("VBox/DeathButtonRow/RestartButton"))
	col.add_child(_restart)
	col.add_child(DK.sp(0, 24))
	_menu = PK.button("ANA MENÜ", "primary", PK.FS_TITLE, PK.G_HOME, 0.0, 144.0)
	_menu.name = "PhoneMenu"
	_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu.pressed.connect(func() -> void: _press_pc("VBox/DeathButtonRow/BackToMenuButton"))
	col.add_child(_menu)
	_final_root.add_child(col)


## Ray sekmesi: 176x156, simge + küçük yazı; seçili = koyu levha + altın kenar + sol altın şerit.
func _rail_tab(caption: String, pat: Array) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(TAB_W, 156)
	var box := DK.v(10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ic: Control = PK.glyph(pat, DK.C_TEXT, 7) if not pat.is_empty() else ColorSprite.new(G_SOUL, SOUL_COLS, 6.0)
	ic.name = "Icon"
	var icw := CenterContainer.new()
	icw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icw.add_child(ic)
	box.add_child(icw)
	var l := PK.lbl(caption, PK.FS_SMALL, DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	l.name = "Caption"
	box.add_child(l)
	b.add_child(box)
	var strip := ColorRect.new()
	strip.name = "Strip"
	strip.color = DK.C_ACCENT
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.position = Vector2(-(RAIL_W - TAB_W) * 0.5, 12)
	strip.size = Vector2(10, 132)
	b.add_child(strip)
	return b


func _style_rail() -> void:
	for i in _rail_btns.size():
		var b: Button = _rail_btns[i]
		var on: bool = i == _tab
		var st: StyleBox = PK.sb(DK.C_PANEL3, DK.C_ACCENT, 3, 16) if on else StyleBoxEmpty.new()
		for s: String in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(s, st)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		(b.get_node("Strip") as Control).visible = on
		var c: Color = DK.C_ACCENT if on else DK.C_TEXT
		var ic: Node = b.find_child("Icon", true, false)
		if ic is PK.PGlyph:
			(ic as PK.PGlyph).set_color(c)
		(b.find_child("Caption", true, false) as Label).add_theme_color_override("font_color", DK.C_ACCENT if on else DK.C_DIM)


## ------------------------------------------------------------------ güncelleme
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_mirror()
	_poll -= delta
	if _poll <= 0.0:
		_poll = 0.5
		_refresh()


## Masaüstü penceresindeki hâlleri her karede kopyalar (yeniden başlatma oylaması, izlenen müttefik, alt yazı).
func _mirror() -> void:
	var pr := _pc("VBox/DeathButtonRow/RestartButton") as Button
	if pr and is_instance_valid(_restart):
		_restart.visible = pr.visible
		_restart.disabled = pr.disabled
		PK.set_text(_restart, "ONAY BEKLENİYOR" if pr.disabled else "TEKRAR OYNA")
	if not _final:
		var t := _pc("VBox/Title") as Label
		if t:
			_spec_title.text = t.text
		var s := _pc("VBox/Subtitle") as Label
		if s:
			_spec_sub.text = s.text
		var n := _pc("VBox/SpectateRow/SpectateLabel") as Label
		if n:
			_spec_name.text = n.text


func _refresh() -> void:
	if not _final or not is_node_ready():
		return
	var b := _board()
	var team: Array = b.get("_team") if b else []
	var summary: Dictionary = b.get("_summary") if b else {}
	var results: Dictionary = b.get("_results") if b else {}
	var sig: String = "%d|%s|%s|%d|%d" % [_tab, str(summary), str(results), team.size(), hash(str(team))]
	if sig == _sig:
		return
	_sig = sig
	_style_rail()
	for c in _mid_box.get_children():
		c.queue_free()
	var page: Control
	match _tab:
		Tab.HASAR:
			page = _page_damage(team, b)
		Tab.ODUL:
			page = _page_rewards(b)
		_:
			page = _page_summary(summary, b)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mid_box.add_child(page)
	_mid_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fill_ranking(team)


static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## ÖZET: büyük başlık + alt yazı (masaüstüyle aynı metin) + 2 sütun stat karosu.
func _page_summary(summary: Dictionary, b: Control) -> Control:
	var v := DK.v(0)
	v.add_child(PK.lbl("OYUN BİTTİ", PK.FS_HERO, DK.C_BAD))
	var sub := _pc("VBox/Subtitle") as Label
	var st := PK.lbl(sub.text if sub else "", PK.FS_BODY, DK.C_DIM)
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(st)
	v.add_child(DK.sp(0, 28))
	var kills: int = int(summary.get("kills", 0))
	var team: Array = b.get("_team") if b else []
	if team.size() > 1: ## çok oyunculuda takım toplamı (game_over_board.gd _tiles ile aynı kural)
		kills = 0
		for p: Dictionary in team:
			kills += int(p["kills"])
	var tiles: Array = [[RunSummaryUI.format_time(float(summary.get("time", 0.0))), "SÜRE", PK.G_CLOCK, null],
			[TierDisplay.to_roman(int(summary.get("tier", 1))), "KADEME", PK.G_SKULL, null]]
	if int(summary.get("layer", 0)) > 0:
		tiles.append([str(int(summary["layer"])), "SONSUZ KAT", PK.G_STAR, null])
	tiles.append([fmt(kills), "ÖLDÜRME", PK.G_SWORD, null])
	tiles.append([str(int(summary.get("level", 1))), "SEVİYE", PK.G_STAR, null])
	if tiles.size() < 5:
		tiles.append([fmt(int(GameManager.gold)), "ALTIN", [], load(COIN_PATH)])
	var shards: int = int(b.call("_shards")) if b and b.has_method("_shards") else 0
	tiles.append(["+%d" % shards, "RUH KIYMIĞI", [], null])
	## Değer yazısı karoya sığan en büyük boy (80 / 64 / 48): dar ekranda (orta levha daralınca) taşmasın.
	var inner_w: float = maxf(200.0, _mid_box.get_parent().get("size").x - 64.0) if _mid_box.get_parent() else 1060.0
	var tile_w: float = (inner_w - 24.0) * 0.5 - 48.0 - 80.0
	var vfs: int = 48
	for fs: int in [80, 64]:
		var widest: float = 0.0
		for t: Array in tiles:
			widest = maxf(widest, DK.font().get_string_size(str(t[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		if widest <= tile_w:
			vfs = fs
			break
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t: Array in tiles:
		var soul: bool = str(t[1]) == "RUH KIYMIĞI"
		var tile := PK.stat_tile(str(t[0]), str(t[1]), t[2], PK.C_SOUL if soul else DK.C_TEXT, t[3], vfs, PK.FS_SMALL)
		tile.custom_minimum_size = Vector2(0, 200)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if soul: ## Ruh Kıymığı simgesi (game_over_board.gd SOUL deseni)
			var row: HBoxContainer = tile.get_child(0).get_child(0)
			row.add_child(ColorSprite.new(G_SOUL, SOUL_COLS, 6.0))
			row.move_child(row.get_child(row.get_child_count() - 1), 0)
		grid.add_child(tile)
	v.add_child(grid)
	return v


## HASAR: oyuncu tablosu (verilen / alınan / öldürme) + bu koşudaki silah ve yetenek hasarın.
func _page_damage(team: Array, b: Control) -> Control:
	var v := DK.v(0)
	var head := DK.h(16)
	head.custom_minimum_size.y = 56
	var hn := PK.lbl("OYUNCU", PK.FS_SMALL, DK.C_DIM)
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hn)
	for h: Array in [["VERİLEN", 230.0], ["ALINAN", 200.0], ["ÖLDÜRME", 170.0]]:
		var l := PK.lbl(str(h[0]), PK.FS_SMALL, DK.C_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		l.custom_minimum_size.x = float(h[1])
		head.add_child(l)
	v.add_child(head)
	var rh: float = 96.0 if team.size() <= 4 else 64.0
	for p: Dictionary in team:
		var row := DK.h(16)
		row.custom_minimum_size.y = rh + 8.0
		row.add_child(PK.portrait(p.get("tex") as Texture2D, rh - 8.0))
		var nm := PK.lbl(str(p["name"]), PK.FS_BODY, DK.C_ACCENT if bool(p.get("me", false)) else DK.C_TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		row.add_child(nm)
		for c: Array in [[fmt(int(p["dealt"])), DMG_COL, 230.0], [fmt(int(p["taken"])), TANK_COL, 200.0], [fmt(int(p["kills"])), DK.C_TEXT, 170.0]]:
			var l := PK.lbl(str(c[0]), PK.FS_BODY, c[1], HORIZONTAL_ALIGNMENT_RIGHT)
			l.custom_minimum_size.x = float(c[2])
			row.add_child(l)
		v.add_child(row)
	var weapons: Array = b.get("_own_weapons") if b else []
	var skills: Array = b.get("_own_skills") if b else []
	if weapons.is_empty() and skills.is_empty():
		return v
	v.add_child(DK.sp(0, 20))
	var cols := DK.h(32)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for part: Array in [["SİLAH HASARIN", weapons], ["YETENEK HASARIN", skills]]:
		var c := DK.v(4)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(PK.lbl(str(part[0]), PK.FS_SMALL, DK.C_ACCENT))
		var rows: Array = part[1]
		for i in mini(rows.size(), 4):
			var r: Dictionary = rows[i]
			var h := DK.h(12)
			h.custom_minimum_size.y = 64
			h.add_child(DK.icon(r.get("tex") as Texture2D, 56))
			var nm := PK.lbl(str(r.get("name", "")), PK.FS_SMALL, DK.C_TEXT)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.clip_text = true
			h.add_child(nm)
			var amount: float = float(r.get("dmg", 0.0))
			if amount <= 0.0:
				amount = float(r.get("heal", 0.0)) + float(r.get("shield", 0.0))
			h.add_child(PK.lbl(fmt(int(amount)), PK.FS_SMALL, DK.C_PRICE, HORIZONTAL_ALIGNMENT_RIGHT))
			c.add_child(h)
		cols.add_child(c)
	v.add_child(cols)
	return v


## ÖDÜL: kazanılan Ruh Kıymığı + bu koşuda kırılan rekorlar ve açılan başarımlar.
func _page_rewards(b: Control) -> Control:
	var v := DK.v(12)
	var shards: int = int(b.call("_shards")) if b and b.has_method("_shards") else 0
	var top := DK.h(24)
	top.add_child(ColorSprite.new(G_SOUL, SOUL_COLS, 12.0))
	var tv := DK.v(0)
	tv.add_child(PK.lbl("+%d" % shards, PK.FS_HERO, PK.C_SOUL))
	tv.add_child(PK.lbl("Ruh Kıymığı - Ruh Mağazası'nda kilit açar, kalıcı geliştirir", PK.FS_SMALL, DK.C_DIM))
	top.add_child(tv)
	v.add_child(top)
	v.add_child(DK.sp(0, 12))
	var lines: Array = b.call("_reward_lines") if b and b.has_method("_reward_lines") else []
	if lines.is_empty():
		v.add_child(PK.lbl("Bu koşuda yeni rekor ya da başarım yok", PK.FS_SMALL, DK.C_DIM))
		return v
	for ln: Array in lines:
		var h := DK.h(16)
		h.add_child(PK.glyph(PK.G_STAR if str(ln[0]) == "star" else PK.G_CHECK, DK.C_PRICE if str(ln[0]) == "star" else DK.C_GOOD, 5))
		var t := PK.lbl(str(ln[1]).replace(" · ", ": "), PK.FS_SMALL, DK.C_PRICE if str(ln[0]) == "star" else DK.C_GOOD)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(t)
		v.add_child(h)
	return v


## Sağ sütun: hasar sırası (sıra no, portre, ad, çubuk, değer). 4 kişiye kadar iri satır, fazlası sıkışır.
func _fill_ranking(team: Array) -> void:
	for c in _rank_box.get_children():
		c.queue_free()
	var top: float = 1.0
	for p: Dictionary in team:
		top = maxf(top, float(p["dealt"]))
	var n: int = team.size()
	var face: float = 112.0 if n <= 4 else (80.0 if n <= 6 else 60.0)
	for i in n:
		var p: Dictionary = team[i]
		var row := DK.h(20)
		row.custom_minimum_size.y = face + (32.0 if n <= 4 else 12.0)
		var num := PK.lbl(str(i + 1), PK.FS_TITLE if n <= 4 else PK.FS_BODY, DK.C_ACCENT if i == 0 else DK.C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		num.custom_minimum_size.x = 56
		row.add_child(num)
		row.add_child(PK.portrait(p.get("tex") as Texture2D, face))
		var col := DK.v(6)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var top_row := DK.h(12)
		var nm := PK.lbl(str(p["name"]), PK.FS_BODY if n <= 4 else PK.FS_SMALL, DK.C_ACCENT if bool(p.get("me", false)) else DK.C_TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		top_row.add_child(nm)
		top_row.add_child(PK.lbl(fmt(int(p["dealt"])), PK.FS_BODY if n <= 4 else PK.FS_SMALL, DK.C_PRICE, HORIZONTAL_ALIGNMENT_RIGHT))
		col.add_child(top_row)
		col.add_child(Bar.new(float(p["dealt"]) / top, DK.C_ACCENT, 28.0 if n <= 4 else 18.0))
		row.add_child(col)
		_rank_box.add_child(row)
