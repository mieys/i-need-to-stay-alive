extends SceneTree

## RUH MAĞAZASI arayüz PROTOTİPLERİ (2026-10-13): 4 yerleşim, GERÇEK MenuKit + gerçek öğe verisi (MetaProgress.COSTS), sahte bakiye.
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261013/soul_shop_proto.gd   (SHOP_CAP_DIR = çıktı klasörü)
## Oyuna hiçbir şey bağlı değil - sadece görüntü. Kayıt user://meta.cfg'ye DOKUNMAZ (geçici yol).

var _dir: String = OS.get_environment("SHOP_CAP_DIR")
var MP: GDScript = null
var _src: Node = null

const SHARDS := 340 ## sahte bakiye
const C_PRICE := Color("#8f5a10") ## C_GOLD bej zeminde silik kalıyordu; fiyatlar daha koyu amber


## Pikselli "Ruh Kıymığı" kristali (sanat dosyası yok, kodla çizilir; lock_badge.gd ile aynı yaklaşım).
class ShardIcon extends Control:
	var dim: bool = false

	func _init(px: float = 32.0, dimmed: bool = false) -> void:
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim = dimmed

	func _draw() -> void:
		var s: float = size.x
		var c: float = s * 0.5
		var top := Vector2(c, s * 0.02)
		var mid_y: float = s * 0.38
		var l := Vector2(s * 0.10, mid_y)
		var r := Vector2(s * 0.90, mid_y)
		var bot := Vector2(c, s * 0.98)
		var m := Vector2(c, mid_y)
		var k: float = 0.55 if dim else 1.0
		draw_colored_polygon(PackedVector2Array([top, m, l]), Color("#a8f0f4") * Color(k, k, k, 1))
		draw_colored_polygon(PackedVector2Array([top, r, m]), Color("#6fd0da") * Color(k, k, k, 1))
		draw_colored_polygon(PackedVector2Array([l, m, bot]), Color("#3f9fb0") * Color(k, k, k, 1))
		draw_colored_polygon(PackedVector2Array([m, r, bot]), Color("#2a7a8c") * Color(k, k, k, 1))
		var o: float = maxf(2.0, s / 12.0)
		draw_polyline(PackedVector2Array([top, r, bot, l, top]), Color("#4a2c1a"), o)


class Bar extends Control:
	var frac: float = 0.0
	var fill: Color = Color("#c9922e")

	func _init(w: float, h: float, f: float, c: Color = Color("#c9922e")) -> void:
		custom_minimum_size = Vector2(w, h)
		frac = f
		fill = c
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#4a2c1a"))
		draw_rect(Rect2(3, 3, size.x - 6, size.y - 6), Color("#e7d6ae"))
		draw_rect(Rect2(3, 3, (size.x - 6) * clampf(frac, 0.0, 1.0), size.y - 6), fill)
		draw_rect(Rect2(3, 3, (size.x - 6) * clampf(frac, 0.0, 1.0), 3), fill.lightened(0.35))


class Plank extends Control:
	func _init(w: float = 10.0) -> void:
		custom_minimum_size = Vector2(w, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(0, 0, size.x, size.y), Color("#7a5534"))
		draw_rect(Rect2(0, 0, size.x, 4), Color("#a87a48"))
		draw_rect(Rect2(0, size.y - 3, size.x, 3), Color("#4a2c1a"))


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	MP = load("res://scripts/meta_progress.gd")
	var tmp: String = _dir.path_join("_meta_proto.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", SHARDS)
	cfg.set_value("meta", "total_earned", 900)
	cfg.set_value("unlocked", "char", [3])
	cfg.set_value("unlocked", "weapon", ["pence", "boomerang"])
	cfg.set_value("unlocked", "pet", ["papagan"])
	cfg.set_value("unlocked", "spirit", [])
	cfg.save(tmp)
	MP.set_path_override(tmp)
	_src = (load("res://scripts/soul_shop_screen.gd") as GDScript).new()
	var pick: String = OS.get_environment("SHOP_CAP_ONLY")
	for v: String in ["a", "b", "c", "d"]:
		if pick != "" and pick != v:
			continue
		var ui: Control = call("_variant_" + v)
		root.add_child(ui)
		await _wait(0.8)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png(_dir.path_join("ruh_dukkani_%s.png" % v))
		print("SHOT %s %dx%d" % [v, img.get_width(), img.get_height()])
		ui.queue_free()
		await process_frame
	DirAccess.remove_absolute(tmp)
	quit()


## ---------------------------------------------------------------- ortak veri / parçalar
func _items() -> Array:
	var out: Array = []
	for it: Dictionary in MP.locked_items():
		var info: Dictionary = _src._info(it["kind"], it["key"])
		out.append({"kind": it["kind"], "key": it["key"], "cost": int(it["cost"]), "name": str(info.get("name", it["key"])),
				"desc": str(info.get("desc", "")), "icon": info.get("icon", null),
				"open": MP.is_unlocked(it["kind"], it["key"]), "can": MP.can_buy(it["kind"], it["key"])})
	return out


func _of_kind(items: Array, kind: String) -> Array:
	return items.filter(func(i: Dictionary) -> bool: return i["kind"] == kind)


func _find(items: Array, kind: String, key: Variant) -> Dictionary:
	for i: Dictionary in items:
		if i["kind"] == kind and str(i["key"]) == str(key):
			return i
	return {}


## Alınabilir -> alınamayan (ucuzdan pahalıya) -> açık olanlar.
func _sorted(items: Array) -> Array:
	var a: Array = items.duplicate()
	a.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var gx: int = 2 if x["open"] else (0 if x["can"] else 1)
		var gy: int = 2 if y["open"] else (0 if y["can"] else 1)
		if gx != gy:
			return gx < gy
		return int(x["cost"]) < int(y["cost"]))
	return a


func _open_count(items: Array) -> int:
	var n: int = 0
	for i: Dictionary in items:
		if i["open"]:
			n += 1
	return n


func _base() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = MenuKit.theme()
	MenuKit.add_background(root)
	var dim := ColorRect.new()
	dim.color = Color(0.20, 0.11, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	return root


func _price(cost: int, px: float, color: Color, font: int = MenuKit.FS_BODY, dimmed: bool = false) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := ShardIcon.new(px, dimmed)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	h.add_child(MenuKit.make_label(str(cost), font, color))
	return h


func _icon(tex: Texture2D, px: float, dim: bool = false) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if dim:
		t.modulate = Color(0.7, 0.66, 0.62)
	return t


func _balance_chip(big: bool = false) -> PanelContainer:
	var p := MenuKit.make_panel("inset")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(h)
	var px: float = 56.0 if big else 40.0
	var ic := ShardIcon.new(px)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", -4)
	h.add_child(col)
	col.add_child(MenuKit.make_label("BAKİYE", MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM))
	col.add_child(MenuKit.make_label(str(MP.shards()), MenuKit.FS_TITLE if big else MenuKit.FS_BODY, C_PRICE))
	return p


func _tag(text: String, variant: String = "tan", w: float = 0.0) -> Button:
	var b: Button = MenuKit.make_button(text, variant, MenuKit.FS_SMALL, 44)
	if w > 0.0:
		b.custom_minimum_size.x = w
	b.focus_mode = Control.FOCUS_NONE
	return b


func _spacer(expand_x: bool = true) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand_x:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Kazanım tablosu (meta_progress.gd sabitlerinden): oyuncu "nasıl kıymık kazanırım?" diye merak eder.
func _earn_box(width: float, compact: bool = false) -> PanelContainer:
	var p := MenuKit.make_panel("inset")
	p.custom_minimum_size.x = width
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	v.add_child(MenuKit.make_label("NASIL KAZANILIR?", MenuKit.FS_SMALL, MenuKit.C_ACCENT))
	for pair: Array in [["Kademe 1 (sonrakiler +%d)" % MP.SHARDS_TIER_STEP, MP.SHARDS_FIRST_TIER], ["Hayatta kalınan dakika", MP.SHARDS_PER_MINUTE],
			["Sonsuz mod katı", MP.SHARDS_PER_LAYER], ["Zafer (bir kez)", MP.SHARDS_VICTORY], ["Yeni başarım", MP.SHARDS_ACHIEVEMENT]]:
		var row := HBoxContainer.new()
		row.add_child(MenuKit.make_label(pair[0], MenuKit.FS_SMALL, MenuKit.C_TEXT))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		row.add_child(MenuKit.make_label("+%d" % pair[1], MenuKit.FS_SMALL, C_PRICE))
		v.add_child(row)
	if not compact:
		v.add_child(MenuKit.make_label("Oyundan düşsen de kazandığın kaybolmaz.", MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM))
	return p


## Bir öğe için durum: "open" / "can" / "no".
func _state(it: Dictionary) -> String:
	return "open" if it["open"] else ("can" if it["can"] else "no")


func _need(it: Dictionary) -> int:
	return maxi(0, int(it["cost"]) - MP.shards())


## Kare kart (dikey): ikon + isim + fiyat/durum. Alınabilir = altın halka, alınamaz = soluk ikon + kırmızı fiyat, açık = yeşil "AÇIK".
func _card(it: Dictionary, w: float, h: float, icon_px: float, selected: bool = false, expand: bool = true) -> Control:
	var show_name: bool = true
	var st: String = _state(it)
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(w, h)
	if expand:
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p := MenuKit.make_panel("slot_selected" if selected else "slot_normal")
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	wrap.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.add_child(_icon(it["icon"], icon_px, st == "no"))
	if show_name:
		var nm: Label = MenuKit.make_label("", MenuKit.FS_SMALL, MenuKit.C_GOOD if st == "open" else MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		nm.text = str(it["name"])
		MenuKit.fit_label_font(nm, str(it["name"]), MenuKit.FS_BODY if w > 200.0 else MenuKit.FS_SMALL, w - 40.0)
		v.add_child(nm)
	match st:
		"open":
			v.add_child(MenuKit.make_label("AÇIK", MenuKit.FS_SMALL, MenuKit.C_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
		"can":
			v.add_child(_price(it["cost"], 24, C_PRICE, MenuKit.FS_SMALL))
		_:
			v.add_child(_price(it["cost"], 24, MenuKit.C_BAD, MenuKit.FS_SMALL, true))
	if st == "can" or selected:
		var ring := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color("#4a2c1a") if selected else Color("#e0a82e")
		sb.set_border_width_all(6 if selected else 3)
		ring.add_theme_stylebox_override("panel", sb)
		ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(ring)
	return wrap


func _full_panel(root: Control, margin: Vector2, kind: String = "panel") -> PanelContainer:
	var p := MenuKit.make_panel(kind)
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = margin.x
	p.offset_right = -margin.x
	p.offset_top = margin.y
	p.offset_bottom = -margin.y
	root.add_child(p)
	return p


func _header(title: String, left: Control, right: Control) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Control.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if left:
		l.add_child(left)
	h.add_child(l)
	h.add_child(MenuKit.make_banner(title))
	var r := HBoxContainer.new()
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.alignment = BoxContainer.ALIGNMENT_END
	if right:
		r.add_child(right)
	h.add_child(r)
	return h


func _buy_button(it: Dictionary, h: float = 64.0, fs: int = MenuKit.FS_BODY) -> Button:
	match _state(it):
		"open":
			var b: Button = MenuKit.make_button("AÇIK", "sage", fs, h)
			b.disabled = true
			return b
		"can":
			return MenuKit.make_button("AÇ", "tan", fs, h)
	var d: Button = MenuKit.make_button("%d EKSİK" % _need(it), "tan", fs, h)
	d.disabled = true
	return d


## ================================================================ A: VİTRİN (sekmeler + kart ızgarası + sağda ayrıntı/satın alma)
func _variant_a() -> Control:
	var items: Array = _items()
	var root := _base()
	var panel := _full_panel(root, Vector2(70, 36))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var back: Button = _tag("< GERİ", "rose", 160)
	back.position = Vector2(0, 14)
	v.add_child(_header("Ruh Mağazası", back, _balance_chip()))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	## SOL: sekmeler + ızgara
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	left.add_child(tabs)
	var active: String = MP.CHAR
	for kind: String in MP.KINDS:
		var list: Array = _of_kind(items, kind)
		var t: Button = MenuKit.make_button("%s  %d/%d" % [MP.KIND_LABELS[kind], _open_count(list), list.size()],
				"sage" if kind == active else "tan", MenuKit.FS_SMALL, 56)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.focus_mode = Control.FOCUS_NONE
		tabs.add_child(t)
	var grid_panel := MenuKit.make_panel("inset")
	grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(grid_panel)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var sel: Dictionary = _find(items, MP.CHAR, 8)
	for it: Dictionary in _sorted(_of_kind(items, active)):
		grid.add_child(_card(it, 216, 330, 128, it == sel))
	grid_panel.add_child(grid)
	left.add_child(MenuKit.make_label("Bir karta dokun: sağda ayrıntısı çıkar.  Altın çerçeveli = şimdi alabilirsin.",
			MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))

	## SAĞ: ayrıntı
	var right := MenuKit.make_panel("panel_tight")
	right.custom_minimum_size.x = 500
	body.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	rv.add_child(MenuKit.make_label(str(MP.KIND_LABELS[sel["kind"]]).to_upper(), MenuKit.FS_SMALL, MenuKit.C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	var stage := MenuKit.make_panel("inset")
	var sc := CenterContainer.new()
	sc.add_child(_icon(sel["icon"], 160))
	stage.add_child(sc)
	rv.add_child(stage)
	rv.add_child(MenuKit.make_label(str(sel["name"]), MenuKit.FS_TITLE, MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var d: Label = MenuKit.make_label(str(sel["desc"]).replace("  ", "
"), MenuKit.FS_BODY, MenuKit.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(d)
	rv.add_child(_spacer(false))
	rv.add_child(MenuKit.make_section_header("FİYAT", MenuKit.FS_SMALL))
	for pair: Array in [["Fiyat", sel["cost"], C_PRICE], ["Bakiye", MP.shards(), MenuKit.C_TEXT],
			["Alınca kalan", MP.shards() - int(sel["cost"]), MenuKit.C_GOOD if MP.shards() >= int(sel["cost"]) else MenuKit.C_BAD]]:
		var row := HBoxContainer.new()
		row.add_child(MenuKit.make_label(pair[0], MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM))
		row.add_child(_spacer())
		var pr := _price(int(pair[1]), 24, pair[2], MenuKit.FS_BODY)
		row.add_child(pr)
		rv.add_child(row)
	rv.add_child(MenuKit.make_button("AÇ  -  %d" % int(sel["cost"]), "sage", MenuKit.FS_BODY, 68))
	return root


## ================================================================ B: REHBER (sol kategori listesi + ilerleme, sağda iki sütun satır listesi)
func _variant_b() -> Control:
	var items: Array = _items()
	var root := _base()
	var panel := _full_panel(root, Vector2(70, 36))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_header("Ruh Mağazası", _tag("< GERİ", "rose", 160), null))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	## SOL sütun
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 470
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	left.add_child(_balance_chip(true))
	var active: String = MP.WEAPON
	for kind: String in MP.KINDS:
		var list: Array = _of_kind(items, kind)
		var on: bool = kind == active
		var row := MenuKit.make_panel("slot_selected" if on else "slot_normal")
		row.custom_minimum_size.y = 128
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", 4)
		row.add_child(rv)
		var top := HBoxContainer.new()
		var nm: Label = MenuKit.make_label(MP.KIND_LABELS[kind], MenuKit.FS_BODY, MenuKit.C_ACCENT if on else MenuKit.C_TEXT)
		top.add_child(nm)
		top.add_child(_spacer())
		var afford: int = list.filter(func(i: Dictionary) -> bool: return i["can"]).size()
		if afford > 0:
			top.add_child(MenuKit.make_label("%d alınabilir" % afford, MenuKit.FS_SMALL, C_PRICE))
		rv.add_child(top)
		var pr := HBoxContainer.new()
		pr.add_theme_constant_override("separation", 10)
		pr.add_child(Bar.new(250, 22, float(_open_count(list)) / float(list.size()), MenuKit.C_GOOD))
		pr.add_child(MenuKit.make_label("%d/%d açık" % [_open_count(list), list.size()], MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM))
		rv.add_child(pr)
		left.add_child(row)
	left.add_child(_spacer(false))
	left.add_child(_earn_box(470))

	## SAĞ: iki sütun satır listesi
	var right := MenuKit.make_panel("inset")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var rv2 := VBoxContainer.new()
	rv2.add_theme_constant_override("separation", 10)
	right.add_child(rv2)
	var title_row := HBoxContainer.new()
	title_row.add_child(MenuKit.make_label(MP.KIND_LABELS[active], MenuKit.FS_TITLE, MenuKit.C_TEXT))
	title_row.add_child(_spacer())
	title_row.add_child(MenuKit.make_label("Sıra:", MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM))
	var f1: Button = _tag("Alınabilirler önce", "sage", 250)
	title_row.add_child(f1)
	title_row.add_child(_tag("Fiyat", "tan", 130))
	rv2.add_child(title_row)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rv2.add_child(grid)
	for it: Dictionary in _sorted(_of_kind(items, active)):
		grid.add_child(_row(it, 625))
	return root


func _row(it: Dictionary, w: float) -> Control:
	var st: String = _state(it)
	var p := MenuKit.make_panel("slot_normal")
	p.custom_minimum_size = Vector2(w, 112)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	h.add_child(_icon(it["icon"], 72, st == "no"))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", -2)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(col)
	col.add_child(MenuKit.make_label(str(it["name"]), MenuKit.FS_BODY, MenuKit.C_GOOD if st == "open" else MenuKit.C_TEXT))
	var d: Label = MenuKit.make_label(str(it["desc"]), MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.max_lines_visible = 2
	d.custom_minimum_size.x = w - 280
	col.add_child(d)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 2)
	side.custom_minimum_size.x = 128
	h.add_child(side)
	if st == "open":
		var b: Button = MenuKit.make_button("AÇIK", "sage", MenuKit.FS_SMALL, 44)
		b.disabled = true
		side.add_child(b)
	else:
		side.add_child(_price(it["cost"], 28, C_PRICE if st == "can" else MenuKit.C_BAD, MenuKit.FS_BODY, st == "no"))
		if st == "can":
			side.add_child(MenuKit.make_button("AÇ", "sage", MenuKit.FS_SMALL, 44))
		else:
			var d2: Button = MenuKit.make_button("%d eksik" % _need(it), "tan", MenuKit.FS_SMALL, 44)
			d2.disabled = true
			side.add_child(d2)
	return p


func _shelf(items: Array, kind: String) -> Control:
	var list: Array = _sorted(_of_kind(items, kind))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(MenuKit.make_section_header("%s   %d / %d" % [MP.KIND_LABELS[kind], _open_count(list), list.size()], MenuKit.FS_SMALL))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for it: Dictionary in list:
		row.add_child(_card(it, 150, 176, 72, str(it["key"]) == "peri", kind == MP.CHAR or kind == MP.WEAPON))
	col.add_child(row)
	col.add_child(Plank.new())
	return col


## ================================================================ C: RAFLAR (4 raf birden, hepsi tek bakışta + altta seçili öğe şeridi)
func _variant_c() -> Control:
	var items: Array = _items()
	var root := _base()
	var panel := _full_panel(root, Vector2(36, 24))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(_header("Ruh Mağazası", _tag("< GERİ", "rose", 160), _balance_chip()))
	v.add_child(_shelf(items, MP.CHAR))
	v.add_child(_shelf(items, MP.WEAPON))
	var low := HBoxContainer.new()
	low.add_theme_constant_override("separation", 28)
	low.add_child(_shelf(items, MP.PET))
	low.add_child(_shelf(items, MP.SPIRIT))
	low.add_child(_spacer())
	var eb := _earn_box(480, true)
	eb.size_flags_vertical = Control.SIZE_SHRINK_END
	low.add_child(eb)
	v.add_child(low)
	v.add_child(_spacer(false))
	## alt şerit: seçili öğe
	var sel: Dictionary = _find(items, MP.PET, "peri")
	var strip := MenuKit.make_panel("inset")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	strip.add_child(h)
	h.add_child(_icon(sel["icon"], 72))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", -2)
	h.add_child(col)
	col.add_child(MenuKit.make_label("%s   -   %s" % [sel["name"], MP.KIND_LABELS[sel["kind"]]], MenuKit.FS_BODY, MenuKit.C_TEXT))
	var d: Label = MenuKit.make_label(str(sel["desc"]), MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.max_lines_visible = 2
	d.custom_minimum_size.x = 1000
	col.add_child(d)
	h.add_child(_price(int(sel["cost"]), 32, C_PRICE, MenuKit.FS_TITLE))
	var buy: Button = MenuKit.make_button("AÇ", "sage", MenuKit.FS_BODY, 64)
	buy.custom_minimum_size.x = 200
	h.add_child(buy)
	v.add_child(strip)
	return root


## ================================================================ D: HEDEF ODAKLI (sol: sıradaki hedef + kazanım, sağ: filtre çipleri + yoğun ızgara)
func _variant_d() -> Control:
	var items: Array = _items()
	var root := _base()
	var panel := _full_panel(root, Vector2(70, 36))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(_header("Ruh Mağazası", _tag("< GERİ", "rose", 160), null))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)

	## SOL: bakiye + sıradaki hedef + kazanım
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 560
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)
	left.add_child(_balance_chip(true))
	## hedef = alınamayan en ucuz öğe (alınabilirler zaten ızgarada altın çerçeveli)
	var goal: Dictionary = {}
	for it: Dictionary in _sorted(items):
		if not it["open"] and not it["can"]:
			goal = it
			break
	var hero := MenuKit.make_panel("panel_tight")
	left.add_child(hero)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	hero.add_child(hv)
	hv.add_child(MenuKit.make_section_header("SIRADAKİ HEDEF", MenuKit.FS_SMALL))
	var stage := MenuKit.make_panel("inset")
	var sc := CenterContainer.new()
	sc.add_child(_icon(goal["icon"], 176, true))
	stage.add_child(sc)
	stage.custom_minimum_size.y = 250
	hv.add_child(stage)
	hv.add_child(MenuKit.make_label(str(goal["name"]), MenuKit.FS_TITLE, MenuKit.C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var d: Label = MenuKit.make_label(str(goal["desc"]), MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.max_lines_visible = 3
	hv.add_child(d)
	var frac: float = float(MP.shards()) / float(goal["cost"])
	var bar := Bar.new(480, 28, frac)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hv.add_child(bar)
	var avg: int = MP.shards_for_run({"time": 420.0, "tier": 5, "layer": 0})
	var runs: int = int(ceil(float(_need(goal)) / float(avg)))
	hv.add_child(MenuKit.make_label("%d / %d    -    %d kıymık eksik" % [MP.shards(), goal["cost"], _need(goal)], MenuKit.FS_SMALL, C_PRICE, HORIZONTAL_ALIGNMENT_CENTER))
	hv.add_child(MenuKit.make_label("Ortalama bir koşu ~%d kıymık: yaklaşık %d koşu sonra" % [avg, runs], MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER))
	left.add_child(_spacer(false))
	left.add_child(_earn_box(560))

	## SAĞ: filtre çipleri + ızgara
	var right := MenuKit.make_panel("inset")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 10)
	right.add_child(rv)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	var afford_n: int = items.filter(func(i: Dictionary) -> bool: return i["can"]).size()
	chips.add_child(_tag("Hepsi %d" % items.size(), "tan", 150))
	chips.add_child(_tag("Alınabilir %d" % afford_n, "sage", 210))
	for kind: String in MP.KINDS:
		chips.add_child(_tag(str(MP.KIND_LABELS[kind]).split(" ")[0], "tan", 130))
	rv.add_child(chips)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var shown: Array = _sorted(items).filter(func(i: Dictionary) -> bool: return i["can"])
	for i in shown.size():
		var it: Dictionary = shown[i]
		grid.add_child(_card(it, 152, 190, 80, str(it["key"]) == "peri"))
	rv.add_child(grid)
	return root
