extends SceneTree

## RUH MAĞAZASI yeni tasarım PROTOTİPLERİ (2026-10-16): 4 koyu tonlu yerleşim, her birine kodla üretilmiş piksel arka plan.
## Gerçek öğe verisi (MetaProgress / MetaUpgrades), sahte bakiye + sahte açılmış öğeler. Oyuna BAĞLI DEĞİL; user://meta.cfg'ye dokunmaz.
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261016/ruh_magaza_proto.gd
##   SHOP_CAP_DIR = çıktı klasörü (zorunlu), SHOP_CAP_ONLY = "a_kar" ya da "e_kar,e_gel" gibi seçili çekimler (boşsa hepsi + özet).
## E (2026-10-16, kullanıcı: "C'nin sanat temasını A'ya ata, düzen A gibi, geliştirmeler C gibi" + "pencere değil TAM EKRAN"): A yerleşimi + C paleti/arka planı
##   + C geliştirme satırları, dış pencere yok (paneller doğrudan tahta duvarın üstünde, kenar boşluğu 32).

const SHARDS := 340
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

## Sahte geliştirme seviyeleri (free_reroll dolu: "MAKS" görünümü için).
const FAKE_LV := {"pickup": 3, "attack": 5, "atk_speed": 2, "health": 4, "lifesteal": 1, "speed": 2, "shield_regen": 1,
		"crit_chance": 3, "luck": 2, "cooldown": 1, "free_reroll": 1}

const PAL := {
	## A - Kayrak & Altın: soğuk lacivert-gri zemin, sıcak altın vurgu (klasik RPG dükkanı)
	"a": {"bg0": Color("#0c1018"), "bg1": Color("#1a2130"), "glow": Color("#33476a"), "glow2": Color("#5a4a2c"), "mote": Color("#9fe3ea"),
		"panel": Color("#1b212e"), "panel2": Color("#242c3b"), "panel3": Color("#2f3a4f"), "inset": Color("#141924"),
		"line": Color("#353f55"), "line_hi": Color("#56657f"), "text": Color("#ece6d7"), "dim": Color("#96a0b2"),
		"accent": Color("#d9b46a"), "accent_dk": Color("#6e5426"), "accent_text": Color("#21180a"),
		"good": Color("#94c97e"), "bad": Color("#dc8676"), "price": Color("#eccb7e"), "spot": Color("#6f8fc0")},
	## B - Ruh Sahnesi: gece moru zemin, ruh mavisi vurgu (büyük vitrin)
	"b": {"bg0": Color("#0d0b17"), "bg1": Color("#1f1934"), "glow": Color("#4b3f80"), "glow2": Color("#7fc8dc"), "mote": Color("#c7b8ff"),
		"panel": Color("#1a1629"), "panel2": Color("#231d38"), "panel3": Color("#30284d"), "inset": Color("#130f20"),
		"line": Color("#352c55"), "line_hi": Color("#574a86"), "text": Color("#eee8f7"), "dim": Color("#a59dc0"),
		"accent": Color("#8fd9e8"), "accent_dk": Color("#2c6878"), "accent_text": Color("#0c1a22"),
		"good": Color("#9fe0aa"), "bad": Color("#ee8c9c"), "price": Color("#a6e8f2"), "spot": Color("#8f7fd8")},
	## C - Gece Tüccarı: koyu ahşap + fener ışığı, kehribar vurgu (oyunun sıcak kitinin koyu hâli; satır listesi)
	"c": {"bg0": Color("#120e0b"), "bg1": Color("#261d16"), "glow": Color("#7a4e22"), "glow2": Color("#4a3018"), "mote": Color("#f2c070"),
		"panel": Color("#241c16"), "panel2": Color("#2e251d"), "panel3": Color("#3b2f24"), "inset": Color("#1a140f"),
		"line": Color("#45372a"), "line_hi": Color("#6a5440"), "text": Color("#efe2c6"), "dim": Color("#ad9b80"),
		"accent": Color("#e2a64e"), "accent_dk": Color("#6a4416"), "accent_text": Color("#24160a"),
		"good": Color("#a9c96e"), "bad": Color("#dc7f60"), "price": Color("#f2c674"), "spot": Color("#c0803a")},
	## D - Orman Kampı: gece ormanı yeşil-camgöbeği, nane + krem vurgu (ana sayfa + kategori sayfaları)
	"d": {"bg0": Color("#0a1312"), "bg1": Color("#15282a"), "glow": Color("#2b4f4a"), "glow2": Color("#c9d9a0"), "mote": Color("#e0f59a"),
		"panel": Color("#152220"), "panel2": Color("#1c2d2a"), "panel3": Color("#264037"), "inset": Color("#0f1918"),
		"line": Color("#2c443e"), "line_hi": Color("#46665c"), "text": Color("#e7efe3"), "dim": Color("#92aba2"),
		"accent": Color("#a3dba9"), "accent_dk": Color("#2f5f3e"), "accent_text": Color("#0e2018"),
		"good": Color("#a3dba9"), "bad": Color("#e38c7c"), "price": Color("#f0da94"), "spot": Color("#5fa08a")},
}

const NAMES := {"a": "A - Klasik Tüccar (Kayrak & Altın)", "b": "B - Ruh Sahnesi (büyük vitrin)",
		"c": "C - Gece Tüccarı Defteri (satır listesi)", "d": "D - Orman Kampı (ana sayfa + kategori)",
		"e": "E - A düzeni + C teması (geliştirmeler C satırları)", "f": "F - D ana sayfası + E teması"}

const G_CHECK := ["......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."]
const G_LOCK := ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"]
const G_HEART := [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
const G_PCT := ["##...#", "##..#.", "...#..", "..#...", ".#..##", "#...##"]
const G_REROLL := ["..####.#", ".#....##", "#....###", "#.......", ".......#", "###....#", "##....#.", "#.####.."]
const G_ARROW := ["..#..", "...#.", "#####", "...#.", "..#.."]
const G_LEFT := ["..#", ".##", "###", ".##", "..#"]
const G_RIGHT := ["#..", "##.", "###", "##.", "#.."]

var _dir: String = OS.get_environment("SHOP_CAP_DIR")
var MP: GDScript = null
var MU: GDScript = null
var SI: GDScript = null
var _src: Node = null
var P: Dictionary = {}
var _all: Array = []
var _kind_now: String = "a"
var _bg_cache: Dictionary = {}


## ---------------------------------------------------------------- çizim sınıfları
class ShardIcon extends Control:
	var dim: bool = false
	var outline: Color = Color("#0b1418")

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
		draw_polyline(PackedVector2Array([top, r, bot, l, top]), outline, maxf(2.0, roundf(s / 12.0)))


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
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), back)
		var fw: float = floorf((size.x - 6.0) * frac)
		if fw > 0.0:
			draw_rect(Rect2(3, 3, fw, size.y - 6), fill)
			draw_rect(Rect2(3, 3, fw, 3), fill.lightened(0.3))


class Pips extends Control:
	var n: int = 10
	var on: int = 0
	var fill: Color = Color.WHITE
	var back: Color = Color.BLACK

	func _init(count: int, filled: int, fc: Color, bc: Color, h: float = 10.0, w: float = 0.0) -> void:
		n = maxi(1, count)
		on = filled
		fill = fc
		back = bc
		custom_minimum_size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var gap: float = 3.0 if n > 10 else 4.0
		var seg: float = floorf((size.x - gap * (n - 1)) / n)
		var x: float = floorf((size.x - (seg * n + gap * (n - 1))) * 0.5)
		for i in n:
			var c: Color = fill if i < on else back
			draw_rect(Rect2(x, 0, seg, size.y), c)
			if i < on:
				draw_rect(Rect2(x, 0, seg, 3), fill.lightened(0.3))
			x += seg + gap


## Yumuşak basamaklı ışık havuzu + zemin elipsi (vitrin kutuları için).
class Spot extends Control:
	var col: Color = Color.WHITE
	var floor_y: float = 0.78

	func _init(c: Color, fy: float = 0.78) -> void:
		col = c
		floor_y = fy
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := (size * Vector2(0.5, 0.5)).floor()
		var r: float = minf(size.x, size.y) * 0.48
		for i in 4:
			draw_circle(c, floorf(r * (1.0 - i * 0.2)), Color(col, 0.07 + i * 0.035))
		var fc := Vector2(c.x, floorf(size.y * floor_y))
		draw_set_transform(fc, 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, floorf(r * 0.62), Color(col, 0.22))
		draw_circle(Vector2.ZERO, floorf(r * 0.44), Color(col, 0.18))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## ---------------------------------------------------------------- akış
func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await process_frame
	MP = load("res://scripts/meta_progress.gd")
	MU = load("res://scripts/meta_upgrades.gd")
	SI = load("res://scripts/stat_icon.gd")
	var tmp: String = _dir.path_join("_meta_proto.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "shards", SHARDS)
	cfg.set_value("meta", "total_earned", 1900)
	cfg.set_value("meta", "starter_granted", true)
	cfg.set_value("unlocked", "char", [3])
	cfg.set_value("unlocked", "weapon", ["pence", "boomerang"])
	cfg.set_value("unlocked", "pet", ["papagan"])
	cfg.set_value("unlocked", "spirit", [])
	for id: String in FAKE_LV:
		var lv: int = int(FAKE_LV[id])
		var d: Dictionary = MU.def(id)
		var spent: int = 0
		for k in lv:
			spent += int(d["first"]) + int(d["step"]) * k
		cfg.set_value("upgrades", id, lv)
		cfg.set_value("upgrade_spent", id, spent)
	cfg.save(tmp)
	MP.set_path_override(tmp)
	_src = (load("res://scripts/soul_shop_screen.gd") as GDScript).new()
	_all = _items()
	var pv: String = OS.get_environment("SHOP_PREVIEW")
	if pv != "":
		await _preview_run(int(pv))
		_src.free()
		DirAccess.remove_absolute(tmp)
		quit()
		return
	var shots: Array = [["a", "kar"], ["a", "gel"], ["b", "kar"], ["b", "gel"], ["c", "kar"], ["c", "gel"], ["d", "ana"], ["d", "kar"], ["d", "gel"],
			["e", "kar"], ["e", "gel"], ["f", "ana"], ["f", "kar"], ["f", "gel"]]
	var only: String = OS.get_environment("SHOP_CAP_ONLY")
	var imgs: Dictionary = {}
	for s: Array in shots:
		var tag: String = "%s_%s" % [s[0], s[1]]
		if only != "" and not tag in only.split(","):
			continue
		_kind_now = s[0]
		P = PAL["c"] if s[0] in ["e", "f"] else PAL[s[0]] ## E ve F = C'nin paleti
		var ui: Control = call("_design_" + str(s[0]), s[1])
		root.add_child(ui)
		await _frames(8)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png(_dir.path_join("ruh_%s.png" % tag))
		imgs[tag] = img
		print("SHOT %s %dx%d" % [tag, img.get_width(), img.get_height()])
		ui.queue_free()
		await process_frame
	if only == "":
		await _overview(imgs)
	_src.free()
	DirAccess.remove_absolute(tmp)
	quit()


func _overview(imgs: Dictionary) -> void:
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
	for tag: String in ["a_kar", "b_kar", "c_kar", "d_ana"]:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var l := Label.new()
		l.text = NAMES[tag.substr(0, 1)]
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
	root.add_child(r)
	await _frames(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join("ruh_ozet.png"))
	r.queue_free()
	await process_frame


## ---------------------------------------------------------------- veri
func _items() -> Array:
	var out: Array = []
	for it: Dictionary in MP.locked_items():
		var info: Dictionary = _src._info(it["kind"], it["key"])
		out.append({"kind": it["kind"], "key": it["key"], "cost": int(it["cost"]), "name": str(info.get("name", it["key"])),
				"desc": str(info.get("desc", "")), "icon": info.get("icon", null),
				"open": MP.is_unlocked(it["kind"], it["key"]), "can": MP.can_buy(it["kind"], it["key"])})
	return out


func _of(kind: String) -> Array:
	var a: Array = _all.filter(func(i: Dictionary) -> bool: return i["kind"] == kind)
	a.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var gx: int = 2 if x["open"] else (0 if x["can"] else 1)
		var gy: int = 2 if y["open"] else (0 if y["can"] else 1)
		if gx != gy:
			return gx < gy
		return int(x["cost"]) < int(y["cost"]))
	return a


func _open_n(kind: String) -> int:
	var n: int = 0
	for i: Dictionary in _all:
		if i["kind"] == kind and i["open"]:
			n += 1
	return n


func _total_n(kind: String) -> int:
	var n: int = 0
	for i: Dictionary in _all:
		if i["kind"] == kind:
			n += 1
	return n


func _state(it: Dictionary) -> String:
	return "open" if it["open"] else ("can" if it["can"] else "no")


func _first_can(kind: String) -> Dictionary:
	for i: Dictionary in _of(kind):
		if _state(i) == "can":
			return i
	return _of(kind)[0]


## Satın alınamayan en ucuz öğe (biriktirme hedefi).
func _goal() -> Dictionary:
	var best: Dictionary = {}
	for i: Dictionary in _all:
		if _state(i) == "no" and (best.is_empty() or int(i["cost"]) < int(best["cost"])):
			best = i
	return best


func _upgs() -> Array:
	var out: Array = []
	for id: String in MU.ids():
		var d: Dictionary = MU.def(id)
		var lv: int = MU.level(id)
		var mx: int = int(d["max"])
		var per: float = float(d["per"])
		var cost: int = MU.next_cost(id)
		out.append({"id": id, "name": str(d["name"]), "desc": str(d["desc"]), "lv": lv, "max": mx, "cost": cost,
				"now": MU.format_value(id, lv * per), "next": MU.format_value(id, (lv + 1) * per) if lv < mx else "",
				"icon_key": str(d.get("icon", "")), "maxed": lv >= mx, "can": lv < mx and cost <= SHARDS})
	return out


func _upg(id: String) -> Dictionary:
	for u: Dictionary in _upgs():
		if u["id"] == id:
			return u
	return {}


func _upg_levels() -> Vector2i:
	var a: int = 0
	var b: int = 0
	for u: Dictionary in _upgs():
		a += int(u["lv"])
		b += int(u["max"])
	return Vector2i(a, b)


func _char_def(it: Dictionary) -> Dictionary:
	return Characters.get_def(int(it["key"]))


func _skills(it: Dictionary) -> Array:
	var d: Dictionary = _char_def(it)
	var out: Array = []
	for pair: Array in [["Q", "skill_name"], ["E", "skill2_name"], ["R", "skill3_name"]]:
		var sn: String = str(d.get(pair[1], ""))
		if sn != "":
			out.append([pair[0], sn])
	return out


func _cats() -> Array:
	var lv: Vector2i = _upg_levels()
	return [
		{"kind": MP.CHAR, "name": "Karakterler", "short": "Karakter", "n": _open_n(MP.CHAR), "of": _total_n(MP.CHAR), "icon": _of(MP.CHAR)[0]["icon"]},
		{"kind": MP.WEAPON, "name": "Silahlar", "short": "Silah", "n": _open_n(MP.WEAPON), "of": _total_n(MP.WEAPON), "icon": _of(MP.WEAPON)[0]["icon"]},
		{"kind": MP.PET, "name": "Evcil Hayvanlar", "short": "Evcil", "n": _open_n(MP.PET), "of": _total_n(MP.PET), "icon": _of(MP.PET)[0]["icon"]},
		{"kind": MP.SPIRIT, "name": "Ruhani Yetenekler", "short": "Ruhani", "n": _open_n(MP.SPIRIT), "of": _total_n(MP.SPIRIT), "icon": _of(MP.SPIRIT)[0]["icon"]},
		{"kind": "upg", "name": "Geliştirmeler", "short": "Geliştirme", "n": lv.x, "of": lv.y, "icon": _stat_tex("damage")},
	]


func _stat_tex(key: String) -> Texture2D:
	var f: String = str(SI.ICON_PATHS.get(key, ""))
	if f != "" and ResourceLoader.exists(SI.ICON_DIR + f):
		return load(SI.ICON_DIR + f) as Texture2D
	return null


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
	var track := _sb(_c("inset"), Color(0, 0, 0, 0), 0, 3)
	track.content_margin_left = 5
	track.content_margin_right = 5
	th.set_stylebox("scroll", "VScrollBar", track)
	for st: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(st, "VScrollBar", _sb(_c("line_hi"), Color(0, 0, 0, 0), 0, 3))
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


func _expand(c: Control, x: bool = true, y: bool = false) -> Control:
	if x:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if y:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


func _shard(px: float = 24.0, dim: bool = false) -> ShardIcon:
	return ShardIcon.new(px, dim)


func _glyph(pat: Array, c: Color, px: int = 3) -> Glyph:
	return Glyph.new(pat, c, px)


## Tam katlı büyütme (piksel bozulmasın); kutudan büyükse küçültür.
func _icon(tex: Texture2D, box: float, dim: bool = false) -> Control:
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(box, box)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		return cc
	var ts: Vector2 = tex.get_size()
	var big: float = maxf(ts.x, ts.y)
	var k: float = floorf(box / big)
	if k < 1.0:
		k = box / big
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.custom_minimum_size = (ts * k).floor()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		tr.modulate = Color(0.52, 0.52, 0.58, 1.0)
	cc.add_child(tr)
	return cc


func _upg_icon(u: Dictionary, box: float) -> Control:
	var tex: Texture2D = _stat_tex(str(u["icon_key"]))
	if tex != null:
		return _icon(tex, box)
	var pat: Array = {"discount": G_PCT, "free_reroll": G_REROLL, "revive": G_HEART}.get(str(u["id"]), G_PCT)
	var cc := CenterContainer.new()
	cc.custom_minimum_size = Vector2(box, box)
	var px: int = maxi(2, int(box / 12.0))
	var col: Color = Color("#ef6f7a") if u["id"] == "revive" else _c("price")
	cc.add_child(_glyph(pat, col, px))
	return cc


## Fiyat / durum satırı: kristal + sayı, ya da onay + AÇIK.
func _price(it: Dictionary, fs: int = 32) -> HBoxContainer:
	var h := _h(8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	match _state(it):
		"open":
			h.add_child(_glyph(G_CHECK, _c("good"), 3 if fs < 32 else 4))
			h.add_child(_lbl("AÇIK", fs, _c("good")))
		"can":
			h.add_child(_shard(fs * 0.75))
			h.add_child(_lbl(str(it["cost"]), fs, _c("price")))
		_:
			h.add_child(_shard(fs * 0.75, true))
			h.add_child(_lbl(str(it["cost"]), fs, _c("bad")))
	return h


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
		var f: Color = fill.lightened(0.07) if st == "hover" else fill
		b.add_theme_stylebox_override(st, _sb(f, bd, 3, r, 10.0))
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


## Kristalli fiyat düğmesi: [ÖNEK] <kristal> 250
func _price_btn(prefix: String, cost: int, kind: String = "primary", fs: int = 32, h: float = 64.0, w: float = 0.0) -> Button:
	var b := _btn("", kind, fs, h, w)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := _h(10)
	var tc: Color = b.get_theme_color("font_color")
	if prefix != "":
		row.add_child(_lbl(prefix, fs, tc))
	row.add_child(_shard(fs * 0.75, kind == "off"))
	row.add_child(_lbl(str(cost), fs, _c("bad") if kind == "off" else tc))
	for l in row.get_children():
		if l is Label:
			(l as Label).remove_theme_color_override("font_shadow_color")
			(l as Label).add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.0 if kind == "primary" or kind == "confirm" else 0.45))
	cc.add_child(row)
	b.add_child(cc)
	return b


func _balance_chip(big: bool = false) -> Control:
	var p := _box(_c("inset"), _c("line_hi"), 12)
	var h := _h(12)
	h.add_child(_shard(40.0 if big else 32.0))
	var v := _v(-6)
	v.add_child(_lbl("Ruh Kıymığı", 24, _c("dim")))
	v.add_child(_lbl(str(SHARDS), 40 if big else 32, _c("price")))
	h.add_child(v)
	h.add_child(_sp(8))
	p.add_child(h)
	return p


func _title(fs: int = 48) -> HBoxContainer:
	var h := _h(14)
	h.add_child(_shard(fs * 0.8))
	h.add_child(_lbl("RUH MAĞAZASI", fs, _c("accent")))
	return h


func _back(t: String = "GERİ") -> Button:
	var b := _btn("", "ghost", 32, 56, 180)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := _h(12)
	row.add_child(_glyph(G_LEFT, _c("text"), 4))
	row.add_child(_lbl(t, 32))
	cc.add_child(row)
	b.add_child(cc)
	return b


## Üst şerit: [GERİ] ..... [başlık] ..... [bakiye]; iki yan eşit genişlikte (başlık tam ortada).
func _topbar(back_text: String = "GERİ", title: Control = null) -> Control:
	var h := _h(0)
	h.custom_minimum_size.y = 72
	var l := _h(0)
	l.custom_minimum_size.x = 300
	var bb := _back(back_text)
	bb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_child(bb)
	h.add_child(l)
	var mid := CenterContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(title if title != null else _title())
	h.add_child(mid)
	var r := _h(0)
	r.custom_minimum_size.x = 300
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(_balance_chip())
	h.add_child(r)
	return h


func _margin(l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


func _scroll(c: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(c)
	return s


func _key_badge(k: String, fs: int = 24) -> PanelContainer:
	var p := _box(_c("inset"), _c("line_hi"), 2, 3, 4)
	p.custom_minimum_size = Vector2(fs * 1.5, fs * 1.5)
	var l := _lbl(k, fs, _c("accent"), HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	return p


func _skill_rows(it: Dictionary, fs: int = 24) -> VBoxContainer:
	var v := _v(6)
	for s: Array in _skills(it):
		var h := _h(10)
		h.add_child(_key_badge(s[0], fs))
		h.add_child(_lbl(s[1], fs))
		v.add_child(h)
	return v


func _stat_rows(it: Dictionary, fs: int = 24, cols: int = 2) -> GridContainer:
	var bs: Dictionary = Characters.get_base_stats(int(it["key"]))
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 18)
	g.add_theme_constant_override("v_separation", 4)
	var atk: int = int(bs.get("atk", 0))
	for row: Array in [["max_health", "Can", str(int(bs.get("hp", 100)))], ["speed", "Hız", str(int(bs.get("speed", 252)))],
			["damage", "Saldırı Gücü", str(int(bs.get("ap", 10)))], ["fire_rate", "Saldırı Hızı", ("%+d%%" % atk) if atk != 0 else "0"]]:
		var h := _h(8)
		h.add_child(_icon(_stat_tex(row[0]), 32))
		h.add_child(_lbl(row[1], fs, _c("dim")))
		h.add_child(_lbl(row[2], fs))
		g.add_child(h)
	return g


func _earn_box(fs: int = 24, w: float = 0.0) -> PanelContainer:
	var p := _box(_c("inset"), _c("line"), 14)
	p.custom_minimum_size.x = w
	var v := _v(4)
	v.add_child(_lbl("NASIL KAZANILIR?", fs, _c("accent")))
	for row: Array in [["Her kademe", "5, 6, 7..."], ["Her dakika", "2"], ["Sonsuz kat", "10"], ["Zafer", "150"], ["Yeni başarım", "25"]]:
		var h := _h(8)
		h.add_child(_lbl(row[0], fs, _c("dim")))
		h.add_child(_sp(0, 0, true))
		h.add_child(_shard(fs * 0.66))
		h.add_child(_lbl(row[1], fs))
		v.add_child(h)
	p.add_child(v)
	return p


func _goal_box(fs: int = 24, w: float = 0.0, with_title: bool = true) -> PanelContainer:
	var g: Dictionary = _goal()
	var p := _box(_c("inset"), _c("line"), 14)
	p.custom_minimum_size.x = w
	var v := _v(8)
	if with_title:
		v.add_child(_lbl("SIRADAKİ HEDEF", fs, _c("accent")))
	var h := _h(12)
	var slot := _box(_c("panel2"), _c("line"), 4)
	slot.add_child(_icon(g["icon"], 72))
	h.add_child(slot)
	var tv := _v(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_lbl(str(g["name"]), 32))
	tv.add_child(_expand(Bar.new(float(SHARDS) / float(g["cost"]), _c("accent"), _c("panel3"), 14.0)))
	var hh := _h(6)
	hh.add_child(_shard(16))
	hh.add_child(_lbl("%d / %d" % [SHARDS, int(g["cost"])], fs, _c("dim")))
	hh.add_child(_sp(0, 0, true))
	hh.add_child(_lbl("%d kaldı" % (int(g["cost"]) - SHARDS), fs, _c("price")))
	tv.add_child(hh)
	h.add_child(tv)
	v.add_child(h)
	p.add_child(v)
	return p


## İçteki büyük vitrin kutusu: ışık havuzu + büyük ikon.
func _showcase(tex: Texture2D, w: float, h: float, icon_box: float, fill: Color, border: Color) -> PanelContainer:
	var p := _box(fill, border, 0)
	p.custom_minimum_size = Vector2(w, h)
	p.add_child(Spot.new(_c("spot")))
	p.add_child(_icon(tex, icon_box))
	return p


## Karakterin tam boy bekleme karesi (kırpılmış, şeffaf kenarsız).
func _char_body(it: Dictionary) -> Texture2D:
	var d: Dictionary = _char_def(it)
	var sf: SpriteFrames = load(str(d.get("frames", ""))) as SpriteFrames
	if sf == null or not sf.has_animation("idle_down"):
		return it["icon"]
	var img: Image = sf.get_frame_texture("idle_down", 0).get_image()
	var used: Rect2i = img.get_used_rect()
	return ImageTexture.create_from_image(img.get_region(used))


## ---------------------------------------------------------------- arka plan (480x270 piksel, x4)
func _q(t: float, steps: int, b: float) -> float:
	return clampf(floorf(t * steps + b + 0.5) / float(steps), 0.0, 1.0)


func _blend(img: Image, x: int, y: int, c: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, a))


func _bg_rect(kind: String) -> TextureRect:
	if not _bg_cache.has(kind):
		if kind == "e" or kind == "f":
			## E: oyunun iç mekan sanatından kurulmuş hazır görüntü (tools/gen_ruh_magaza_bg.py)
			var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/ruh_magaza/bg_ruh_magaza.png"))
			_bg_cache[kind] = ImageTexture.create_from_image(img)
		else:
			_bg_cache[kind] = ImageTexture.create_from_image(_bg_image(kind))
	var tr := TextureRect.new()
	tr.texture = _bg_cache[kind]
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _bg_image(kind: String) -> Image:
	var w: int = 480
	var h: int = 270
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var bg0: Color = _c("bg0")
	var bg1: Color = _c("bg1")
	var glow: Color = _c("glow")
	var glow2: Color = _c("glow2")
	var glows: Array = []
	match kind:
		"a":
			glows = [[Vector2(240, 40), Vector2(300, 150), glow, 0.75], [Vector2(240, 300), Vector2(260, 90), glow2, 0.45]]
		"b":
			glows = [[Vector2(150, 160), Vector2(80, 26), glow, 0.9], [Vector2(400, 20), Vector2(220, 120), glow, 0.35]]
		"c":
			glows = [[Vector2(122, 24), Vector2(150, 110), glow, 0.8], [Vector2(358, 24), Vector2(150, 110), glow, 0.8],
					[Vector2(240, 290), Vector2(300, 80), glow2, 0.5]]
		"d":
			glows = [[Vector2(330, 15), Vector2(140, 90), glow, 0.9], [Vector2(240, 270), Vector2(320, 70), glow, 0.4]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1016
	var plank_tone: Array = []
	for i in 20:
		plank_tone.append(rng.randf_range(-0.05, 0.05))
	for y in h:
		for x in w:
			var b: float = (float(BAYER[(y & 3) * 4 + (x & 3)]) + 0.5) / 16.0 - 0.5
			var col: Color = bg0.lerp(bg1, _q(float(y) / float(h - 1), 7, b))
			if kind == "c":
				var pl: int = int(y / 18.0)
				var t: float = float(plank_tone[pl % plank_tone.size()])
				col = col.lightened(t) if t > 0.0 else col.darkened(-t)
				var joint: int = (pl * 137) % 150
				if y % 18 == 0 or (x + joint) % 150 == 0:
					col = col.darkened(0.35)
				elif y % 18 == 1:
					col = col.lightened(0.04)
			for g: Array in glows:
				var dv: Vector2 = (Vector2(x, y) - (g[0] as Vector2)) / (g[1] as Vector2)
				var d: float = dv.length()
				if d < 1.0:
					var k: float = (1.0 - d)
					col = col.lerp(g[2], _q(k * k * float(g[3]), 8, b))
			if kind == "b" and y < 160:
				var hw: float = 14.0 + float(y + 10) * 0.30
				var ax: float = absf(float(x) - 150.0)
				if ax < hw:
					var k2: float = (1.0 - ax / hw) * (0.18 + 0.22 * float(y) / 160.0)
					col = col.lerp(glow2, _q(k2, 8, b))
			var vx: float = (float(x) / float(w) - 0.5) * 2.0
			var vy: float = (float(y) / float(h) - 0.5) * 2.0
			var v: float = clampf(vx * vx * 0.45 + vy * vy * 0.6 - 0.3, 0.0, 1.0) * 0.75
			col = col.lerp(bg0.darkened(0.5), _q(v, 5, b))
			img.set_pixel(x, y, col)
	match kind:
		"a":
			_bg_rune(img, Vector2(240, 140), 122.0, _c("line"), 0.35)
		"b":
			_bg_stars(img, rng, 90, 150)
			_bg_ellipse(img, Vector2(150, 160), Vector2(48, 10), _c("accent"), 0.55)
			_bg_ellipse(img, Vector2(150, 160), Vector2(36, 7), _c("glow2"), 0.35)
		"c":
			_bg_lantern(img, 122)
			_bg_lantern(img, 358)
		"d":
			_bg_stars(img, rng, 70, 120)
			_bg_moon(img, Vector2(330, 15), 9)
			_bg_pines(img, rng, 214, bg1.lerp(glow, 0.35), 34, 60, 22)
			_bg_pines(img, rng, 236, bg1.lerp(bg0, 0.3), 30, 52, 26)
			_bg_pines(img, rng, 258, bg0.darkened(0.25), 26, 46, 30)
	_bg_motes(img, rng, kind)
	return img


func _bg_rune(img: Image, c: Vector2, r: float, col: Color, a: float) -> void:
	for rr: float in [r, r - 10.0]:
		var n: int = int(TAU * rr * 1.2)
		for i in n:
			var ang: float = TAU * float(i) / float(n)
			_blend(img, int(c.x + cos(ang) * rr), int(c.y + sin(ang) * rr), col, a)
	for i in 24:
		var ang: float = TAU * float(i) / 24.0
		for k in 4:
			_blend(img, int(c.x + cos(ang) * (r - 2 - k * 2)), int(c.y + sin(ang) * (r - 2 - k * 2)), col, a)


func _bg_ellipse(img: Image, c: Vector2, rad: Vector2, col: Color, a: float) -> void:
	var n: int = int(TAU * rad.x * 1.5)
	for i in n:
		var ang: float = TAU * float(i) / float(n)
		_blend(img, int(c.x + cos(ang) * rad.x), int(c.y + sin(ang) * rad.y), col, a)


func _bg_stars(img: Image, rng: RandomNumberGenerator, count: int, max_y: int) -> void:
	for i in count:
		var x: int = rng.randi_range(0, 479)
		var y: int = rng.randi_range(0, max_y)
		_blend(img, x, y, Color("#e8ecff"), rng.randf_range(0.15, 0.5))


func _bg_moon(img: Image, c: Vector2, r: int) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			var d: float = Vector2(x, y).length()
			if d <= r:
				var shade: float = 0.42 if Vector2(x + 3, y - 2).length() > r else 0.55
				_blend(img, int(c.x) + x, int(c.y) + y, Color("#e9f1da"), shade)


func _bg_pines(img: Image, rng: RandomNumberGenerator, base_y: int, col: Color, hmin: int, hmax: int, spacing: int) -> void:
	for y in range(base_y, 270):
		for x in 480:
			img.set_pixel(x, y, col)
	var x0: int = -rng.randi_range(0, spacing)
	while x0 < 500:
		var th: int = rng.randi_range(hmin, hmax)
		var half: float = float(th) * 0.30
		var tier: int = maxi(5, th / 5)
		for yy in th:
			var t: float = float(yy) / float(th)
			var wv: int = int(half * (1.0 - t)) - int(float(yy % tier) * 0.45) + 1
			for xx in range(x0 - wv, x0 + wv + 1):
				if xx >= 0 and xx < 480 and base_y - yy >= 0:
					img.set_pixel(xx, base_y - yy, col)
		x0 += spacing + rng.randi_range(-spacing / 3, spacing / 3)


func _bg_lantern(img: Image, cx: int, top: int = 16) -> void:
	var dark := Color("#120c08")
	for y in range(0, top):
		_blend(img, cx, y, dark, 0.9)
	for y in range(top, top + 11):
		for x in range(cx - 4, cx + 5):
			var edge: bool = x == cx - 4 or x == cx + 4 or y == top or y == top + 10
			img.set_pixel(x, y, dark if edge else Color("#ffd27a").lerp(Color("#ff9a3c"), float(y - top) / 10.0))
	for x in range(cx - 5, cx + 6):
		img.set_pixel(x, top - 1, dark)
		img.set_pixel(x, top + 11, dark)


func _bg_motes(img: Image, rng: RandomNumberGenerator, kind: String) -> void:
	var mote: Color = _c("mote")
	var count: int = {"a": 40, "b": 50, "c": 34, "d": 46}[kind]
	for i in count:
		var x: int = rng.randi_range(4, 475)
		var y: int = rng.randi_range(6, 262)
		if kind == "b":
			x = int(150 + rng.randf_range(-1.0, 1.0) * (20 + y * 0.3)) if i % 2 == 0 else x
		if kind == "d":
			y = rng.randi_range(150, 262)
		var a: float = rng.randf_range(0.45, 0.95)
		_blend(img, x, y, mote, a)
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_blend(img, x + o.x, y + o.y, mote, a * 0.3)


func _root() -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.theme = _theme()
	r.add_child(_bg_rect(_kind_now))
	return r


## ================================================================ A - KLASİK TÜCCAR
## Sol: kategori menüsü (5 bölüm tek seviyede) + kazanım kutusu. Orta: kart ızgarası. Sağ: seçili öğe ayrıntısı + satın alma.
func _design_a(page: String) -> Control:
	var r := _root()
	var m := _margin(96, 52, 96, 52)
	r.add_child(m)
	var win := _box(Color(_c("panel"), 0.94), _c("line_hi"), 24, 3, 9)
	m.add_child(win)
	var col := _v(14)
	win.add_child(col)
	col.add_child(_topbar())
	col.add_child(_hline())
	var body := _h(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var kind: String = MP.CHAR if page == "kar" else "upg"
	body.add_child(_a_sidebar(kind))
	if page == "kar":
		var items: Array = _of(MP.CHAR)
		var sel: Dictionary = _first_can(MP.CHAR)
		var center := _v(10)
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hdr := _h(12)
		hdr.add_child(_lbl("KARAKTERLER", 40, _c("text")))
		hdr.add_child(_sp(0, 0, true))
		hdr.add_child(_lbl("Alınabilenler önce", 24, _c("dim")))
		center.add_child(hdr)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		for it: Dictionary in items:
			grid.add_child(_a_card(it, it == sel))
		center.add_child(_scroll(grid))
		body.add_child(center)
		body.add_child(_a_detail(sel))
	else:
		var ups: Array = _upgs()
		var center := _v(10)
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hdr := _h(12)
		hdr.add_child(_lbl("GELİŞTİRMELER", 40, _c("text")))
		hdr.add_child(_sp(0, 0, true))
		var lv: Vector2i = _upg_levels()
		hdr.add_child(_lbl("Toplam seviye %d / %d" % [lv.x, lv.y], 24, _c("dim")))
		center.add_child(hdr)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 8)
		for u: Dictionary in ups:
			grid.add_child(_a_upg_tile(u, u["id"] == "attack"))
		center.add_child(_scroll(grid))
		body.add_child(center)
		body.add_child(_a_upg_detail(_upg("attack")))
	return r


func _a_sidebar(active: String, earn: bool = true) -> Control:
	var v := _v(8)
	v.custom_minimum_size.x = 330
	for c: Dictionary in _cats():
		var on: bool = c["kind"] == active
		var p := _box(_c("panel3") if on else _c("panel2"), _c("accent") if on else _c("line"), 10)
		var h := _h(12)
		var strip := ColorRect.new()
		strip.color = _c("accent") if on else Color(0, 0, 0, 0)
		strip.custom_minimum_size = Vector2(6, 0)
		h.add_child(strip)
		h.add_child(_icon(c["icon"], 56))
		var tv := _v(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(_lbl(c["name"], 32, _c("accent") if on else _c("text")))
		var hh := _h(10)
		hh.add_child(_expand(Bar.new(float(c["n"]) / float(c["of"]), _c("accent") if on else _c("line_hi"), _c("inset"), 12.0)))
		hh.add_child(_lbl("%d/%d" % [c["n"], c["of"]], 24, _c("dim")))
		tv.add_child(hh)
		h.add_child(tv)
		p.add_child(h)
		v.add_child(p)
	v.add_child(_sp(0, 0, false, true))
	if earn:
		v.add_child(_earn_box(24))
	return v


func _a_card(it: Dictionary, sel: bool, w: float = 200.0, h: float = 236.0) -> Control:
	var st: String = _state(it)
	var border: Color = _c("accent") if sel else (_c("line_hi") if st == "can" else _c("line"))
	var fill: Color = _c("panel3") if sel else (_c("inset") if st == "open" else _c("panel2"))
	var p := _box(fill, border, 10)
	p.custom_minimum_size = Vector2(w, h)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _v(4)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var plate := _box(_c("inset") if st != "open" else _c("panel"), Color(0, 0, 0, 0), 4, 0, 4)
	plate.add_child(_icon(it["icon"], 144, st == "no"))
	v.add_child(plate)
	v.add_child(_lbl(str(it["name"]), 24, _c("text") if st != "open" else _c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_price(it, 32))
	p.add_child(v)
	if st == "no":
		var g := _glyph(G_LOCK, _c("dim"), 3)
		g.size_flags_horizontal = Control.SIZE_SHRINK_END
		g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		p.add_child(g)
	return p


func _a_detail(it: Dictionary) -> Control:
	var p := _box(_c("panel2"), _c("line_hi"), 20)
	p.custom_minimum_size.x = 440
	var v := _v(12)
	v.add_child(_lbl("KARAKTER", 24, _c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_showcase(_char_body(it), 400, 250, 220, _c("inset"), _c("line")))
	v.add_child(_lbl(str(it["name"]), 48, _c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_skill_rows(it, 24))
	v.add_child(_hline())
	v.add_child(_stat_rows(it, 24))
	v.add_child(_sp(0, 0, false, true))
	var row := _h(8)
	row.add_child(_lbl("Alınca kalan", 24, _c("dim")))
	row.add_child(_sp(0, 0, true))
	row.add_child(_shard(18))
	row.add_child(_lbl(str(SHARDS - int(it["cost"])), 24, _c("text")))
	v.add_child(row)
	v.add_child(_price_btn("AÇ", int(it["cost"]), "primary", 32, 72))
	p.add_child(v)
	return p


func _a_upg_tile(u: Dictionary, sel: bool) -> Control:
	var p := _box(_c("panel3") if sel else _c("panel2"), _c("accent") if sel else _c("line"), 8)
	p.custom_minimum_size = Vector2(0, 68)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := _h(12)
	h.add_child(_upg_icon(u, 48))
	var tv := _v(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_lbl(str(u["name"]), 24, _c("accent") if sel else _c("text")))
	tv.add_child(_expand(Pips.new(int(u["max"]), int(u["lv"]), _c("accent"), _c("inset"), 9.0)))
	h.add_child(tv)
	var lv := _lbl("MAKS" if u["maxed"] else "%d/%d" % [u["lv"], u["max"]], 24, _c("good") if u["maxed"] else _c("dim"))
	lv.custom_minimum_size.x = 62
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(lv)
	p.add_child(h)
	return p


func _now_next(u: Dictionary, fs: int = 32, center: bool = true) -> HBoxContainer:
	var h := _h(14)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if center:
		h.alignment = BoxContainer.ALIGNMENT_CENTER
	var a := _v(-4)
	a.add_child(_lbl("Şu an", 24, _c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	a.add_child(_lbl(str(u["now"]), fs, _c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	h.add_child(a)
	if not u["maxed"]:
		var av := _v(0)
		av.add_child(_sp(0, 20))
		var ac := CenterContainer.new()
		ac.custom_minimum_size = Vector2(0, 34)
		ac.add_child(_glyph(G_ARROW, _c("accent"), 4))
		av.add_child(ac)
		h.add_child(av)
		var b := _v(-4)
		b.add_child(_lbl("Sonraki", 24, _c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
		b.add_child(_lbl(str(u["next"]), fs, _c("good"), HORIZONTAL_ALIGNMENT_CENTER))
		h.add_child(b)
	return h


func _a_upg_detail(u: Dictionary) -> Control:
	var p := _box(_c("panel2"), _c("line_hi"), 20)
	p.custom_minimum_size.x = 440
	var v := _v(12)
	v.add_child(_lbl("GELİŞTİRME", 24, _c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	var sc := _box(_c("inset"), _c("line"), 0)
	sc.custom_minimum_size = Vector2(400, 200)
	sc.add_child(Spot.new(_c("spot"), 0.8))
	sc.add_child(_upg_icon(u, 128))
	v.add_child(sc)
	v.add_child(_lbl(str(u["name"]), 40, _c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_wrap(str(u["desc"]), 24, _c("dim"), 396, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lbl("Seviye %d / %d" % [u["lv"], u["max"]], 24, _c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_expand(Pips.new(int(u["max"]), int(u["lv"]), _c("accent"), _c("inset"), 16.0)))
	v.add_child(_now_next(u))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_price_btn("YÜKSELT", int(u["cost"]), "primary", 32, 72))
	var rs := _h(8)
	rs.add_child(_lbl("Hepsini sıfırla (ücretli)", 24, _c("dim")))
	rs.add_child(_sp(0, 0, true))
	rs.add_child(_btn("SIFIRLA", "ghost", 24, 44, 140))
	v.add_child(rs)
	p.add_child(v)
	return p


## ================================================================ B - RUH SAHNESİ
## Sol: büyük sahne (seçili öğe kaide üstünde, arka plandaki spot ışığı), altında ad/yetenek/satın al. Sağ: koleksiyon listesi.
func _design_b(page: String) -> Control:
	var r := _root()
	var m := _margin(64, 24, 64, 40)
	r.add_child(m)
	var col := _v(12)
	m.add_child(col)
	col.add_child(_topbar())
	var tabs := _h(10)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	var active: String = MP.CHAR if page == "kar" else "upg"
	for c: Dictionary in _cats():
		var on: bool = c["kind"] == active
		var b := _btn("", "tab_on" if on else "ghost", 32, 56, 0)
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hh := _h(10)
		hh.add_child(_icon(c["icon"], 40))
		hh.add_child(_lbl(c["name"], 32, _c("accent") if on else _c("text")))
		hh.add_child(_lbl("%d/%d" % [c["n"], c["of"]], 24, _c("dim")))
		cc.add_child(hh)
		b.add_child(cc)
		b.custom_minimum_size.x = 40.0 + 10.0 + _tw(c["name"], 32) + 10.0 + _tw("%d/%d" % [c["n"], c["of"]], 24) + 44.0
		tabs.add_child(b)
	col.add_child(tabs)
	var body := _h(32)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	var stage := Control.new()
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(stage)
	var list := _box(Color(_c("panel"), 0.93), _c("line_hi"), 16, 3, 8)
	list.custom_minimum_size.x = 680
	body.add_child(list)
	## Sahne: kaide arka planda (480x270 içinde 150,160 -> ekranda 600,640). Sahne kutusu ekranda x=64'ten başlar.
	var stage_origin := Vector2(64, 0)
	if page == "kar":
		var sel: Dictionary = _first_can(MP.CHAR)
		var tex: Texture2D = _char_body(sel)
		var ts: Vector2 = tex.get_size()
		var k: float = floorf(300.0 / ts.y)
		var spr := TextureRect.new()
		spr.texture = tex
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.stretch_mode = TextureRect.STRETCH_SCALE
		spr.size = ts * k
		spr.position = Vector2(600.0 - ts.x * k * 0.5, 648.0 - ts.y * k)
		r.add_child(spr)
		_b_info_char(r, sel)
		_b_list_items(list, _of(MP.CHAR), sel)
	else:
		var u: Dictionary = _upg("attack")
		var ic := _upg_icon(u, 224)
		ic.position = Vector2(600 - 112, 360)
		r.add_child(ic)
		_b_info_upg(r, u)
		_b_list_upgs(list, _upgs(), "attack")
	for side: Array in [[G_LEFT, 150.0], [G_RIGHT, 990.0]]:
		var ab := _btn("", "ghost", 32, 72, 72)
		ab.position = Vector2(float(side[1]) + stage_origin.x - 64.0, 470)
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		cc.add_child(_glyph(side[0], _c("text"), 5))
		ab.add_child(cc)
		r.add_child(ab)
	return r


func _b_info(r: Control) -> VBoxContainer:
	var v := _v(12)
	v.position = Vector2(80, 700)
	v.size = Vector2(1040, 360)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	r.add_child(v)
	return v


func _b_info_char(r: Control, it: Dictionary) -> void:
	var v := _b_info(r)
	var nm := _lbl(str(it["name"]), 64, _c("text"), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(nm)
	var chips := _h(12)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	for s: Array in _skills(it):
		var p := _box(Color(_c("panel2"), 0.9), _c("line"), 8)
		var h := _h(10)
		h.add_child(_key_badge(s[0], 24))
		h.add_child(_lbl(s[1], 24))
		p.add_child(h)
		chips.add_child(p)
	v.add_child(chips)
	var sr := CenterContainer.new()
	sr.add_child(_stat_rows(it, 24, 4))
	v.add_child(sr)
	var br := _h(20)
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_child(_price_btn("AÇ", int(it["cost"]), "primary", 40, 76, 380))
	var kv := _v(-4)
	kv.add_child(_lbl("Alınca kalan", 24, _c("dim")))
	var kh := _h(6)
	kh.add_child(_shard(20))
	kh.add_child(_lbl(str(SHARDS - int(it["cost"])), 32))
	kv.add_child(kh)
	br.add_child(kv)
	v.add_child(br)


func _b_info_upg(r: Control, u: Dictionary) -> void:
	var v := _b_info(r)
	v.add_child(_lbl(str(u["name"]), 64, _c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lbl(str(u["desc"]), 24, _c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	var pc := CenterContainer.new()
	var pv := _v(6)
	pv.add_child(_lbl("Seviye %d / %d" % [u["lv"], u["max"]], 24, _c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	pv.add_child(Pips.new(int(u["max"]), int(u["lv"]), _c("accent"), Color(_c("inset"), 0.9), 16.0, 620.0))
	pc.add_child(pv)
	v.add_child(pc)
	var br := _h(36)
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_child(_now_next(u, 32))
	br.add_child(_price_btn("YÜKSELT", int(u["cost"]), "primary", 40, 76, 420))
	v.add_child(br)


func _b_list_items(list: PanelContainer, items: Array, sel: Dictionary) -> void:
	var v := _v(10)
	var hdr := _h(10)
	hdr.add_child(_lbl("KOLEKSİYON", 32, _c("accent")))
	hdr.add_child(_sp(0, 0, true))
	hdr.add_child(_lbl("Alınabilenler önce", 24, _c("dim")))
	v.add_child(hdr)
	var rows := _v(8)
	for it: Dictionary in items:
		var on: bool = it == sel
		var st: String = _state(it)
		var p := _box(_c("panel3") if on else (_c("inset") if st == "open" else _c("panel2")), _c("accent") if on else _c("line"), 8)
		var h := _h(14)
		h.add_child(_icon(it["icon"], 56, st == "no"))
		var nm := _lbl(str(it["name"]), 32, _c("dim") if st == "open" else _c("text"))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(_price(it, 32))
		h.add_child(_sp(4))
		p.add_child(h)
		rows.add_child(p)
	v.add_child(_scroll(rows))
	list.add_child(v)


func _b_list_upgs(list: PanelContainer, ups: Array, sel_id: String) -> void:
	var v := _v(8)
	var hdr := _h(10)
	hdr.add_child(_lbl("TÜM GELİŞTİRMELER", 32, _c("accent")))
	hdr.add_child(_sp(0, 0, true))
	var lv: Vector2i = _upg_levels()
	hdr.add_child(_lbl("%d / %d seviye" % [lv.x, lv.y], 24, _c("dim")))
	v.add_child(hdr)
	var rows := _v(4)
	for u: Dictionary in ups:
		var on: bool = u["id"] == sel_id
		var p := _box(_c("panel3") if on else _c("panel2"), _c("accent") if on else _c("line"), 4, 3, 5)
		var h := _h(12)
		h.add_child(_upg_icon(u, 32))
		var nm := _lbl(str(u["name"]), 24, _c("accent") if on else _c("text"))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		h.add_child(Pips.new(int(u["max"]), int(u["lv"]), _c("accent"), _c("inset"), 8.0, 120.0))
		var pr := _h(6)
		pr.custom_minimum_size.x = 84
		pr.alignment = BoxContainer.ALIGNMENT_END
		if u["maxed"]:
			pr.add_child(_lbl("MAKS", 24, _c("good")))
		else:
			pr.add_child(_shard(16, not u["can"]))
			pr.add_child(_lbl(str(u["cost"]), 24, _c("price") if u["can"] else _c("bad")))
		h.add_child(pr)
		h.add_child(_sp(2))
		p.add_child(h)
		rows.add_child(p)
	v.add_child(_scroll(rows))
	var rs := _h(8)
	rs.add_child(_lbl("Hepsini sıfırla (ücretli)", 24, _c("dim")))
	rs.add_child(_sp(0, 0, true))
	rs.add_child(_btn("SIFIRLA", "ghost", 24, 44, 140))
	v.add_child(rs)
	list.add_child(v)


## ================================================================ C - GECE TÜCCARI DEFTERİ
## Üstte defter sekmeleri, ortada iki sütun satır listesi (satın alma satırın içinde, iki adımlı), sağda bakiye/kazanım/hedef sütunu.
func _design_c(page: String) -> Control:
	var r := _root()
	var m := _margin(80, 36, 80, 44)
	r.add_child(m)
	var col := _v(0)
	m.add_child(col)
	var title := _box(_c("panel2"), _c("line_hi"), 12, 3, 8)
	title.add_child(_title(48))
	col.add_child(_topbar("GERİ", title))
	col.add_child(_sp(0, 14))
	var active: String = MP.CHAR if page == "kar" else "upg"
	var tabs := _h(6)
	tabs.add_child(_sp(16))
	for c: Dictionary in _cats():
		var on: bool = c["kind"] == active
		var p := PanelContainer.new()
		var sb := _sb(_c("panel") if on else _c("inset"), _c("line_hi") if on else _c("line"), 3, 8, 12.0)
		sb.corner_radius_bottom_left = 0
		sb.corner_radius_bottom_right = 0
		if on:
			sb.border_width_bottom = 0
			sb.expand_margin_bottom = 3
		p.add_theme_stylebox_override("panel", sb)
		var h := _h(10)
		h.add_child(_icon(c["icon"], 40))
		h.add_child(_lbl(c["name"], 32, _c("accent") if on else _c("dim")))
		h.add_child(_lbl("%d/%d" % [c["n"], c["of"]], 24, _c("dim")))
		p.add_child(h)
		tabs.add_child(p)
	col.add_child(tabs)
	var ledger := _box(_c("panel"), _c("line_hi"), 20, 3, 8)
	ledger.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(ledger)
	var body := _h(20)
	ledger.add_child(body)
	var listv := _v(10)
	listv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(listv)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	if page == "kar":
		var sel: Dictionary = _first_can(MP.CHAR)
		for it: Dictionary in _of(MP.CHAR):
			grid.add_child(_c_row(it, it == sel))
		listv.add_child(_scroll(grid))
		listv.add_child(_lbl("Fiyata bas, sonra ONAYLA'ya bas: kazara alım olmaz.", 24, _c("dim")))
	else:
		for u: Dictionary in _upgs():
			grid.add_child(_c_upg_row(u))
		listv.add_child(_scroll(grid))
	var side := _v(14)
	side.custom_minimum_size.x = 360
	body.add_child(side)
	side.add_child(_earn_box(24))
	if page == "kar":
		side.add_child(_goal_box(24))
	else:
		var lv: Vector2i = _upg_levels()
		var p := _box(_c("inset"), _c("line"), 14)
		var v := _v(8)
		v.add_child(_lbl("İLERLEME", 24, _c("accent")))
		var h := _h(8)
		h.add_child(_lbl("Toplam seviye", 24, _c("dim")))
		h.add_child(_sp(0, 0, true))
		h.add_child(_lbl("%d / %d" % [lv.x, lv.y], 24))
		v.add_child(h)
		v.add_child(_expand(Bar.new(float(lv.x) / float(lv.y), _c("accent"), _c("panel3"), 14.0)))
		v.add_child(_sp(0, 6))
		v.add_child(_wrap("Sıfırlarsan harcadığın kıymıklar küçük bir ücret düşülerek geri gelir.", 24, _c("dim"), 320))
		v.add_child(_btn("HEPSİNİ SIFIRLA", "ghost", 24, 48))
		p.add_child(v)
		side.add_child(p)
	return r


func _c_row(it: Dictionary, confirm: bool) -> Control:
	var st: String = _state(it)
	var p := _box(_c("inset") if st == "open" else _c("panel2"), _c("good") if confirm else _c("line"), 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := _h(14)
	var slot := _box(_c("inset"), _c("line"), 4, 3, 4)
	slot.add_child(_icon(it["icon"], 96, st == "no"))
	h.add_child(slot)
	var tv := _v(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_lbl(str(it["name"]), 32, _c("dim") if st == "open" else _c("text")))
	for s: Array in _skills(it):
		var sh := _h(8)
		sh.add_child(_lbl(s[0], 24, _c("accent") if st != "open" else _c("dim")))
		sh.add_child(_lbl(s[1], 24, _c("dim")))
		tv.add_child(sh)
	h.add_child(tv)
	var bw: float = 190.0
	var b: Control
	match st:
		"open":
			b = _h(8)
			(b as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
			b.add_child(_glyph(G_CHECK, _c("good"), 4))
			b.add_child(_lbl("AÇIK", 32, _c("good")))
			b.custom_minimum_size.x = bw
		"can":
			b = _btn("ONAYLA?", "confirm", 32, 64, bw) if confirm else _price_btn("", int(it["cost"]), "primary", 32, 64, bw)
		_:
			b = _price_btn("", int(it["cost"]), "off", 32, 64, bw)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	p.add_child(h)
	return p


func _c_upg_row(u: Dictionary, ib: float = 44.0) -> Control:
	var p := _box(_c("panel2"), _c("line"), 6)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := _h(12)
	var slot := _box(_c("inset"), _c("line"), 2, 3, 4)
	slot.add_child(_upg_icon(u, ib))
	h.add_child(slot)
	var tv := _v(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l1 := _h(8)
	l1.add_child(_lbl(str(u["name"]), 24))
	l1.add_child(_sp(0, 0, true))
	if u["maxed"]:
		l1.add_child(_lbl(str(u["now"]), 24, _c("good")))
	else:
		l1.add_child(_lbl(str(u["now"]), 24, _c("dim")))
		l1.add_child(_glyph(G_ARROW, _c("dim"), 3))
		l1.add_child(_lbl(str(u["next"]), 24, _c("good")))
	tv.add_child(l1)
	var l2 := _h(10)
	l2.add_child(_expand(Pips.new(int(u["max"]), int(u["lv"]), _c("accent"), _c("inset"), 10.0)))
	l2.add_child(_lbl("%d/%d" % [u["lv"], u["max"]], 24, _c("dim")))
	tv.add_child(l2)
	h.add_child(tv)
	var b: Control
	if u["maxed"]:
		b = _lbl("MAKS", 32, _c("good"), HORIZONTAL_ALIGNMENT_CENTER)
		b.custom_minimum_size.x = 150
	else:
		b = _price_btn("", int(u["cost"]), "primary" if u["can"] else "off", 32, 56, 150)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	p.add_child(h)
	return p


## ================================================================ D - ORMAN KAMPI
## Ana sayfa: solda "önerilen" + sıradaki hedef, sağda 4 kategori kutusu + geniş geliştirme kutusu. Kutuya basınca kategori sayfası açılır.
func _design_d(page: String) -> Control:
	var r := _root()
	var m := _margin(64, 24, 64, 40)
	r.add_child(m)
	var col := _v(16)
	m.add_child(col)
	match page:
		"ana":
			col.add_child(_topbar())
			var body := _h(24)
			body.size_flags_vertical = Control.SIZE_EXPAND_FILL
			col.add_child(body)
			body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			body.add_child(_d_featured())
			var right := _v(20)
			right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_child(right)
			var g := GridContainer.new()
			g.columns = 2
			g.add_theme_constant_override("h_separation", 20)
			g.add_theme_constant_override("v_separation", 20)
			var cats: Array = _cats()
			for i in 4:
				g.add_child(_d_tile(cats[i]))
			right.add_child(g)
			right.add_child(_d_upg_tile(cats[4]))
		"kar":
			var t := _h(16)
			t.add_child(_shard(36))
			t.add_child(_lbl("KARAKTERLER", 48, _c("accent")))
			t.add_child(_lbl("%d/%d" % [_open_n(MP.CHAR), _total_n(MP.CHAR)], 32, _c("dim")))
			col.add_child(_topbar("ANA SAYFA", t))
			var g := GridContainer.new()
			g.columns = 5
			g.add_theme_constant_override("h_separation", 18)
			g.add_theme_constant_override("v_separation", 18)
			var sel: Dictionary = _first_can(MP.CHAR)
			for it: Dictionary in _of(MP.CHAR):
				g.add_child(_d_card(it))
			var cc := CenterContainer.new()
			cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cc.add_child(g)
			col.add_child(cc)
			_d_popup(r, sel)
		"gel":
			var t := _h(16)
			t.add_child(_upg_icon(_upg("attack"), 40))
			t.add_child(_lbl("GELİŞTİRMELER", 48, _c("accent")))
			var lv: Vector2i = _upg_levels()
			t.add_child(_lbl("%d/%d" % [lv.x, lv.y], 32, _c("dim")))
			col.add_child(_topbar("ANA SAYFA", t))
			var g := GridContainer.new()
			g.columns = 4
			g.add_theme_constant_override("h_separation", 14)
			g.add_theme_constant_override("v_separation", 12)
			for u: Dictionary in _upgs():
				g.add_child(_d_upg_card(u))
			col.add_child(_scroll(g))
			var rs := _h(12)
			rs.add_child(_sp(0, 0, true))
			rs.add_child(_lbl("Hepsini sıfırla: harcananın çoğu geri gelir", 24, _c("dim")))
			rs.add_child(_btn("SIFIRLA", "ghost", 24, 44, 150))
			col.add_child(rs)
	return r


func _d_featured() -> Control:
	var it: Dictionary = _first_can(MP.CHAR)
	var p := _box(Color(_c("panel"), 0.92), _c("line_hi"), 22, 3, 9)
	p.custom_minimum_size.x = 560
	var v := _v(12)
	var hh := _h(10)
	hh.add_child(_lbl("ŞİMDİ ALABİLİRSİN", 24, _c("glow2")))
	hh.add_child(_sp(0, 0, true))
	hh.add_child(_lbl("Karakter", 24, _c("dim")))
	v.add_child(hh)
	v.add_child(_showcase(_char_body(it), 512, 270, 240, _c("inset"), _c("line")))
	v.add_child(_lbl(str(it["name"]), 48, _c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	var sk := CenterContainer.new()
	sk.add_child(_skill_rows(it, 24))
	v.add_child(sk)
	v.add_child(_price_btn("AÇ", int(it["cost"]), "primary", 32, 68))
	v.add_child(_sp(0, 4))
	v.add_child(_goal_box(24, 0.0, true))
	p.add_child(v)
	return p


func _d_tile(c: Dictionary) -> Control:
	var p := _box(Color(_c("panel"), 0.92), _c("line_hi"), 18, 3, 9)
	p.custom_minimum_size = Vector2(574, 0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _v(12)
	var h := _h(12)
	h.add_child(_icon(c["icon"], 48))
	h.add_child(_lbl(c["name"], 40))
	h.add_child(_sp(0, 0, true))
	h.add_child(_lbl("%d/%d" % [c["n"], c["of"]], 32, _c("accent")))
	v.add_child(h)
	v.add_child(_expand(Bar.new(float(c["n"]) / float(c["of"]), _c("accent"), _c("inset"), 12.0)))
	var prev := _h(8)
	var items: Array = _of(str(c["kind"]))
	var can_n: int = 0
	for it: Dictionary in items:
		if _state(it) == "can":
			can_n += 1
	for i in mini(5, items.size()):
		var it: Dictionary = items[i]
		var st: String = _state(it)
		var s := _box(_c("inset"), _c("good") if st == "open" else _c("line"), 4, 3, 4)
		s.add_child(_icon(it["icon"], 64, st == "no"))
		prev.add_child(s)
	if items.size() > 5:
		prev.add_child(_lbl("+%d" % (items.size() - 5), 32, _c("dim")))
	v.add_child(prev)
	var f := _h(8)
	if can_n > 0:
		f.add_child(_shard(20))
		f.add_child(_lbl("%d tanesini şimdi alabilirsin" % can_n, 24, _c("good")))
	else:
		f.add_child(_lbl("Kıymık biriktir", 24, _c("dim")))
	f.add_child(_sp(0, 0, true))
	f.add_child(_lbl("AÇ", 24, _c("accent")))
	f.add_child(_glyph(G_RIGHT, _c("accent"), 3))
	v.add_child(f)
	p.add_child(v)
	return p


func _d_upg_tile(c: Dictionary) -> Control:
	var p := _box(Color(_c("panel"), 0.92), _c("line_hi"), 18, 3, 9)
	var v := _v(12)
	var h := _h(12)
	h.add_child(_icon(c["icon"], 48))
	h.add_child(_lbl(c["name"], 40))
	h.add_child(_lbl("Kalıcı güçlendirmeler, her koşuda geçerli", 24, _c("dim")))
	h.add_child(_sp(0, 0, true))
	h.add_child(_lbl("%d/%d seviye" % [c["n"], c["of"]], 32, _c("accent")))
	v.add_child(h)
	v.add_child(_expand(Bar.new(float(c["n"]) / float(c["of"]), _c("accent"), _c("inset"), 12.0)))
	var row := _h(10)
	var ups: Array = _upgs()
	var can_n: int = 0
	for u: Dictionary in ups:
		if u["can"]:
			can_n += 1
	for i in 10:
		var u: Dictionary = ups[i]
		var cv := _v(4)
		var s := _box(_c("inset"), _c("line"), 4, 3, 4)
		s.add_child(_upg_icon(u, 48))
		cv.add_child(s)
		row.add_child(cv)
	row.add_child(_lbl("+%d" % (ups.size() - 10), 32, _c("dim")))
	v.add_child(row)
	var f := _h(8)
	f.add_child(_shard(20))
	f.add_child(_lbl("%d geliştirmeyi şimdi yükseltebilirsin" % can_n, 24, _c("good")))
	f.add_child(_sp(0, 0, true))
	f.add_child(_lbl("AÇ", 24, _c("accent")))
	f.add_child(_glyph(G_RIGHT, _c("accent"), 3))
	v.add_child(f)
	p.add_child(v)
	return p


func _d_card(it: Dictionary) -> Control:
	var st: String = _state(it)
	var p := _box(Color(_c("panel") if st != "open" else _c("inset"), 0.95), _c("line_hi") if st == "can" else _c("line"), 12, 3, 8)
	p.custom_minimum_size = Vector2(320, 0)
	var v := _v(8)
	var sc := _showcase(it["icon"], 290, 190, 144, _c("inset"), Color(0, 0, 0, 0))
	if st == "no":
		(sc.get_child(1) as CenterContainer).get_child(0).modulate = Color(0.52, 0.52, 0.58, 1)
	v.add_child(sc)
	v.add_child(_lbl(str(it["name"]), 32, _c("dim") if st == "open" else _c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_price(it, 32))
	p.add_child(v)
	return p


func _d_popup(r: Control, it: Dictionary) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(cc)
	var p := _box(_c("panel"), _c("accent"), 26, 3, 10)
	p.custom_minimum_size.x = 820
	var h := _h(26)
	h.add_child(_showcase(_char_body(it), 300, 380, 280, _c("inset"), _c("line")))
	var v := _v(12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_lbl("KARAKTER", 24, _c("dim")))
	v.add_child(_lbl(str(it["name"]), 48))
	v.add_child(_skill_rows(it, 24))
	v.add_child(_hline())
	v.add_child(_stat_rows(it, 24))
	v.add_child(_sp(0, 0, false, true))
	var row := _h(8)
	row.add_child(_lbl("Alınca kalan", 24, _c("dim")))
	row.add_child(_sp(0, 0, true))
	row.add_child(_shard(18))
	row.add_child(_lbl(str(SHARDS - int(it["cost"])), 24))
	v.add_child(row)
	var br := _h(14)
	br.add_child(_btn("VAZGEÇ", "ghost", 32, 68, 180))
	br.add_child(_expand(_price_btn("AÇ", int(it["cost"]), "primary", 32, 68)))
	v.add_child(br)
	h.add_child(v)
	p.add_child(h)
	cc.add_child(p)


func _d_upg_card(u: Dictionary) -> Control:
	var p := _box(Color(_c("panel"), 0.95), _c("line_hi") if u["can"] else _c("line"), 12, 3, 8)
	p.custom_minimum_size = Vector2(430, 0)
	var v := _v(8)
	var h := _h(12)
	var slot := _box(_c("inset"), _c("line"), 2, 3, 4)
	slot.add_child(_upg_icon(u, 48))
	h.add_child(slot)
	var tv := _v(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_lbl(str(u["name"]), 24))
	tv.add_child(_lbl("Seviye %d/%d" % [u["lv"], u["max"]], 24, _c("dim")))
	h.add_child(tv)
	v.add_child(h)
	v.add_child(_expand(Pips.new(int(u["max"]), int(u["lv"]), _c("accent"), _c("inset"), 10.0)))
	var f := _h(8)
	if u["maxed"]:
		f.add_child(_lbl(str(u["now"]), 24, _c("good")))
		f.add_child(_sp(0, 0, true))
		f.add_child(_lbl("MAKS", 32, _c("good")))
	else:
		f.add_child(_lbl(str(u["now"]), 24, _c("dim")))
		f.add_child(_glyph(G_ARROW, _c("dim"), 3))
		f.add_child(_lbl(str(u["next"]), 24, _c("good")))
		f.add_child(_sp(0, 0, true))
		f.add_child(_price_btn("", int(u["cost"]), "primary" if u["can"] else "off", 24, 44, 120))
	v.add_child(f)
	p.add_child(v)
	return p


## ================================================================ E - A DÜZENİ + C TEMASI, TAM EKRAN
## Dış pencere YOK: üst şerit + sol menü doğrudan C'nin tahta duvarında (fenerler başlığın iki yanında), orta ve sağ paneller ekranı doldurur.
## Karakterler: 5 sütun kart (10 karakter 2 satır, kaydırma yok) + sağda ayrıntı. Geliştirmeler: C'nin iki sütun satırları, sağ panel yok.
func _design_e(page: String) -> Control:
	var r := _root()
	var m := _margin(32, 20, 32, 28)
	r.add_child(m)
	var col := _v(16)
	m.add_child(col)
	var title := _box(_c("panel2"), _c("line_hi"), 12, 3, 8)
	title.add_child(_title(48))
	col.add_child(_topbar("GERİ", title))
	var body := _h(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_a_sidebar(MP.CHAR if page == "kar" else "upg", false)) ## "Nasıl kazanılır?" kutusu YOK (kullanıcı isteği)
	var center := _box(Color(_c("panel"), 0.96), _c("line_hi"), 18, 3, 8)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var cv := _v(12)
	center.add_child(cv)
	var hdr := _h(14)
	cv.add_child(hdr)
	if page == "kar":
		hdr.add_child(_lbl("KARAKTERLER", 40, _c("text")))
		hdr.add_child(_sp(0, 0, true))
		hdr.add_child(_lbl("Alınabilenler önce", 24, _c("dim")))
		var sel: Dictionary = _first_can(MP.CHAR)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		for it: Dictionary in _of(MP.CHAR):
			grid.add_child(_a_card(it, it == sel, 200.0, 264.0))
		cv.add_child(_scroll(grid))
		body.add_child(_e_detail(sel))
	else:
		hdr.add_child(_lbl("GELİŞTİRMELER", 40, _c("text")))
		hdr.add_child(_lbl("Kalıcı, her koşuda geçerli", 24, _c("dim")))
		hdr.add_child(_sp(0, 0, true))
		var lv: Vector2i = _upg_levels()
		hdr.add_child(_lbl("Toplam seviye %d / %d" % [lv.x, lv.y], 24, _c("dim")))
		var bar := Bar.new(float(lv.x) / float(lv.y), _c("accent"), _c("inset"), 14.0, 220.0)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hdr.add_child(bar)
		hdr.add_child(_sp(6))
		hdr.add_child(_btn("HEPSİNİ SIFIRLA", "ghost", 24, 44, 0))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 18)
		for u: Dictionary in _upgs():
			grid.add_child(_c_upg_row(u, 48.0))
		cv.add_child(_scroll(grid))
	return r


## Tam ekran ayrıntı paneli: büyük vitrin, yetenekler kendi ikonlarıyla, pasif metni (en çok 3 satır), statlar, satın alma.
func _e_detail(it: Dictionary) -> Control:
	var d: Dictionary = _char_def(it)
	var p := _box(Color(_c("panel"), 0.96), _c("line_hi"), 20, 3, 8)
	p.custom_minimum_size.x = 480
	var v := _v(10)
	v.add_child(_showcase(_char_body(it), 436, 320, 300, _c("inset"), _c("line")))
	v.add_child(_lbl(str(it["name"]), 48, _c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_skill_icon_rows(it, 32))
	var pas := _v(2)
	pas.add_child(_lbl("PASİF", 24, _c("accent")))
	var pl := _wrap(str(d.get("passive", "")), 24, _c("dim"), 436)
	pl.max_lines_visible = 3
	pl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pas.add_child(pl)
	v.add_child(pas)
	v.add_child(_hline())
	v.add_child(_stat_rows(it, 24))
	v.add_child(_sp(0, 0, false, true))
	var row := _h(8)
	row.add_child(_lbl("Alınca kalan", 24, _c("dim")))
	row.add_child(_sp(0, 0, true))
	row.add_child(_shard(18))
	row.add_child(_lbl(str(SHARDS - int(it["cost"])), 24, _c("text")))
	v.add_child(row)
	v.add_child(_price_btn("AÇ", int(it["cost"]), "primary", 32, 72))
	p.add_child(v)
	return p


## Yetenek satırları: kendi ikonu + köşesinde tuş harfi; ikonu olmayan yetenekte (ör. Assasin R tanımında skill3_icon yok) sadece büyük harf.
func _skill_icon_rows(it: Dictionary, fs: int = 32, desc_w: float = 0.0, active: int = -1) -> VBoxContainer:
	var d: Dictionary = _char_def(it)
	var v := _v(10)
	var row_i: int = -1
	for trio: Array in [["Q", "skill_name", "skill_icon", "skill_desc"], ["E", "skill2_name", "skill2_icon", "skill2_desc"],
			["R", "skill3_name", "skill3_icon", "skill3_desc"]]:
		var h := _h(12)
		var ip: String = str(d.get(trio[2], ""))
		var slot := _box(_c("inset"), _c("line_hi"), 0, 3, 4)
		var has_icon: bool = ip != "" and ResourceLoader.exists(ip)
		if has_icon:
			slot.add_child(_icon(load(ip) as Texture2D, 48))
		var key := _lbl(trio[0], 24 if has_icon else 32, _c("accent"), HORIZONTAL_ALIGNMENT_CENTER)
		key.custom_minimum_size = Vector2(48, 48) if not has_icon else Vector2.ZERO
		if has_icon:
			key.size_flags_horizontal = Control.SIZE_SHRINK_END
			key.size_flags_vertical = Control.SIZE_SHRINK_END
			key.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			key.add_theme_constant_override("shadow_outline_size", 4)
		slot.add_child(key)
		h.add_child(slot)
		if desc_w > 0.0:
			slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var tv := _v(0)
			tv.add_child(_lbl(str(d.get(trio[1], "")), fs))
			var ds: String = str(d.get(trio[3], ""))
			for pre: String in ["YETENEK: ", "TEMEL: ", "ULTİ: ", "ULTI: "]:
				ds = ds.trim_prefix(pre)
			var dl := _wrap(ds, 24, _c("dim"), desc_w)
			dl.max_lines_visible = 2
			dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			tv.add_child(dl)
			h.add_child(tv)
		else:
			h.add_child(_lbl(str(d.get(trio[1], "")), fs))
		row_i += 1
		if row_i == active:
			## önizlemede oynayan yetenek: satır vurgulu kutuda
			var hb := _box(_c("panel3"), _c("accent"), 6, 3, 6)
			hb.add_child(h)
			v.add_child(hb)
		else:
			v.add_child(h)
	return v


## ================================================================ F - D ANA SAYFASI + E TEMASI (tam ekran)
## Kullanıcı (2026-10-16): "D düzenini (Orman Kampı) bununla bağdaştır, arka plan/renkler E'deki gibi; tıklayınca şimdiki düzene benzeyen
## sayfa: solda karakter listesi, sağda seçilen karakter büyük; geliştirmeler şimdiki (E) gibi". Arka plan = E'ninki (aynı PNG), palet C.
func _design_f(page: String) -> Control:
	var r := _root()
	var m := _margin(32, 20, 32, 28)
	r.add_child(m)
	var col := _v(16)
	m.add_child(col)
	match page:
		"ana":
			var title := _box(_c("panel2"), _c("line_hi"), 12, 3, 8)
			title.add_child(_title(48))
			col.add_child(_topbar("GERİ", title))
			var body := _h(20)
			body.size_flags_vertical = Control.SIZE_EXPAND_FILL
			col.add_child(body)
			body.add_child(_f_featured())
			var right := _v(20)
			right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_child(right)
			var g := GridContainer.new()
			g.columns = 2
			g.size_flags_vertical = Control.SIZE_EXPAND_FILL
			g.add_theme_constant_override("h_separation", 20)
			g.add_theme_constant_override("v_separation", 20)
			var cats: Array = _cats()
			for i in 4:
				g.add_child(_f_tile(cats[i]))
			right.add_child(g)
			right.add_child(_f_upg_tile(cats[4]))
		"kar":
			col.add_child(_topbar("ANA SAYFA", _f_page_title(_shard(36), "KARAKTERLER", "%d/%d" % [_open_n(MP.CHAR), _total_n(MP.CHAR)])))
			## v2 "kahraman seçimi": üstte büyük sahne + bilgi paneli, altta çerçeveli karakter kartları (eski sol liste: _f_list/_f_big_detail)
			var sel: Dictionary = _first_can(MP.CHAR)
			var body := _h(20)
			body.size_flags_vertical = Control.SIZE_EXPAND_FILL
			col.add_child(body)
			body.add_child(_f_stage(sel))
			body.add_child(_f_info(sel))
			col.add_child(_f_roster(_of(MP.CHAR), sel))
		"gel":
			var lv: Vector2i = _upg_levels()
			col.add_child(_topbar("ANA SAYFA", _f_page_title(_upg_icon(_upg("attack"), 40), "GELİŞTİRMELER", "%d/%d" % [lv.x, lv.y])))
			var center := _box(_c("panel"), _c("line_hi"), 18, 3, 8)
			center.size_flags_vertical = Control.SIZE_EXPAND_FILL
			col.add_child(center)
			var cv := _v(12)
			center.add_child(cv)
			var hdr := _h(14)
			hdr.add_child(_lbl("Kalıcı güçlendirmeler, her koşuda geçerli", 24, _c("dim")))
			hdr.add_child(_sp(0, 0, true))
			hdr.add_child(_lbl("Toplam seviye %d / %d" % [lv.x, lv.y], 24, _c("dim")))
			var bar := Bar.new(float(lv.x) / float(lv.y), _c("accent"), _c("inset"), 14.0, 260.0)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hdr.add_child(bar)
			hdr.add_child(_sp(6))
			hdr.add_child(_btn("HEPSİNİ SIFIRLA", "ghost", 24, 44, 0))
			cv.add_child(hdr)
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 16)
			grid.add_theme_constant_override("v_separation", 18)
			for u: Dictionary in _upgs():
				grid.add_child(_c_upg_row(u, 48.0))
			cv.add_child(_scroll(grid))
	return r


func _f_page_title(icon: Control, text: String, count: String) -> PanelContainer:
	var p := _box(_c("panel2"), _c("line_hi"), 12, 3, 8)
	var h := _h(14)
	h.add_child(icon)
	h.add_child(_lbl(text, 48, _c("accent")))
	h.add_child(_lbl(count, 32, _c("dim")))
	p.add_child(h)
	return p


func _f_featured() -> Control:
	var it: Dictionary = _first_can(MP.CHAR)
	var p := _box(_c("panel"), _c("line_hi"), 22, 3, 8)
	p.custom_minimum_size.x = 560
	var v := _v(12)
	var hh := _h(10)
	hh.add_child(_lbl("ŞİMDİ ALABİLİRSİN", 24, _c("accent")))
	hh.add_child(_sp(0, 0, true))
	hh.add_child(_lbl("Karakter", 24, _c("dim")))
	v.add_child(hh)
	v.add_child(_showcase(_char_body(it), 512, 300, 280, _c("inset"), _c("line")))
	v.add_child(_lbl(str(it["name"]), 48, _c("text"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_skill_icon_rows(it, 32))
	v.add_child(_hline())
	v.add_child(_stat_rows(it, 24))
	v.add_child(_sp(0, 4))
	v.add_child(_price_btn("AÇ", int(it["cost"]), "primary", 32, 68))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_goal_box(24, 0.0, true))
	p.add_child(v)
	return p


func _f_tile(c: Dictionary) -> Control:
	var p := _box(_c("panel"), _c("line_hi"), 18, 3, 8)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := _v(12)
	var h := _h(12)
	h.add_child(_icon(c["icon"], 48))
	h.add_child(_lbl(c["name"], 40))
	h.add_child(_sp(0, 0, true))
	h.add_child(_lbl("%d/%d" % [c["n"], c["of"]], 32, _c("accent")))
	v.add_child(h)
	v.add_child(_expand(Bar.new(float(c["n"]) / float(c["of"]), _c("accent"), _c("inset"), 12.0)))
	var prev := GridContainer.new()
	prev.columns = 5
	prev.add_theme_constant_override("h_separation", 8)
	prev.add_theme_constant_override("v_separation", 8)
	var items: Array = _of(str(c["kind"]))
	var can_n: int = 0
	for it: Dictionary in items:
		if _state(it) == "can":
			can_n += 1
	for i in mini(10, items.size()):
		var it: Dictionary = items[i]
		var st: String = _state(it)
		var s := _box(_c("inset"), _c("good") if st == "open" else _c("line"), 3, 3, 4)
		s.add_child(_icon(it["icon"], 96, st == "no"))
		prev.add_child(s)
	v.add_child(prev)
	v.add_child(_sp(0, 0, false, true))
	var f := _h(8)
	if can_n > 0:
		f.add_child(_shard(20))
		f.add_child(_lbl("%d tanesini şimdi alabilirsin" % can_n, 24, _c("good")))
	else:
		f.add_child(_lbl("Kıymık biriktir", 24, _c("dim")))
	f.add_child(_sp(0, 0, true))
	if items.size() > 10:
		f.add_child(_lbl("+%d daha" % (items.size() - 10), 24, _c("dim")))
		f.add_child(_sp(12))
	f.add_child(_lbl("AÇ", 24, _c("accent")))
	f.add_child(_glyph(G_RIGHT, _c("accent"), 3))
	v.add_child(f)
	p.add_child(v)
	return p


func _f_upg_tile(c: Dictionary) -> Control:
	var p := _box(_c("panel"), _c("line_hi"), 18, 3, 8)
	var v := _v(12)
	var h := _h(12)
	h.add_child(_icon(c["icon"], 48))
	h.add_child(_lbl(c["name"], 40))
	h.add_child(_lbl("Kalıcı güçlendirmeler, her koşuda geçerli", 24, _c("dim")))
	h.add_child(_sp(0, 0, true))
	h.add_child(_lbl("%d/%d seviye" % [c["n"], c["of"]], 32, _c("accent")))
	v.add_child(h)
	v.add_child(_expand(Bar.new(float(c["n"]) / float(c["of"]), _c("accent"), _c("inset"), 12.0)))
	var row := _h(10)
	var ups: Array = _upgs()
	var can_n: int = 0
	for u: Dictionary in ups:
		if u["can"]:
			can_n += 1
	for i in 12:
		var s := _box(_c("inset"), _c("line"), 4, 3, 4)
		s.add_child(_upg_icon(ups[i], 56))
		row.add_child(s)
	row.add_child(_lbl("+%d" % (ups.size() - 12), 32, _c("dim")))
	v.add_child(row)
	var f := _h(8)
	f.add_child(_shard(20))
	f.add_child(_lbl("%d geliştirmeyi şimdi yükseltebilirsin" % can_n, 24, _c("good")))
	f.add_child(_sp(0, 0, true))
	f.add_child(_lbl("AÇ", 24, _c("accent")))
	f.add_child(_glyph(G_RIGHT, _c("accent"), 3))
	v.add_child(f)
	p.add_child(v)
	return p


## Kategori sayfası sol listesi: portre + ad + fiyat/durum; seçili satır vurgulu (sol şerit + kenar).
func _f_list(items: Array, sel: Dictionary) -> Control:
	var p := _box(_c("panel"), _c("line_hi"), 16, 3, 8)
	p.custom_minimum_size.x = 540
	var v := _v(10)
	var hdr := _h(10)
	hdr.add_child(_lbl("Alınabilenler önce", 24, _c("dim")))
	v.add_child(hdr)
	var rows := _v(8)
	for it: Dictionary in items:
		var on: bool = it == sel
		var st: String = _state(it)
		var b := _box(_c("panel3") if on else (_c("inset") if st == "open" else _c("panel2")), _c("accent") if on else _c("line"), 6)
		var h := _h(12)
		var strip := ColorRect.new()
		strip.color = _c("accent") if on else Color(0, 0, 0, 0)
		strip.custom_minimum_size = Vector2(6, 0)
		h.add_child(strip)
		h.add_child(_icon(it["icon"], 56, st == "no"))
		var nm := _lbl(str(it["name"]), 32, _c("accent") if on else (_c("dim") if st == "open" else _c("text")))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		if st == "no":
			h.add_child(_glyph(G_LOCK, _c("dim"), 3))
		h.add_child(_price(it, 32))
		h.add_child(_sp(6))
		b.add_child(h)
		rows.add_child(b)
	v.add_child(_scroll(rows))
	p.add_child(v)
	return p


## Kategori sayfası sağ büyük görünüm: solda büyük vitrin, sağda bilgi sütunu + satın alma.
func _f_big_detail(it: Dictionary) -> Control:
	var d: Dictionary = _char_def(it)
	var p := _box(_c("panel"), _c("line_hi"), 22, 3, 8)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := _h(28)
	var sc := _box(_c("inset"), _c("line"), 0)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(Spot.new(_c("spot"), 0.8))
	sc.add_child(_icon(_char_body(it), 420))
	h.add_child(sc)
	var v := _v(14)
	v.custom_minimum_size.x = 600
	v.add_child(_lbl("KARAKTER", 24, _c("dim")))
	v.add_child(_lbl(str(it["name"]), 64))
	v.add_child(_hline())
	v.add_child(_lbl("YETENEKLER", 24, _c("accent")))
	v.add_child(_skill_icon_rows(it, 32, 540.0))
	var pas := _v(4)
	pas.add_child(_lbl("PASİF", 24, _c("accent")))
	var pl := _wrap(str(d.get("passive", "")), 24, _c("dim"), 596)
	pl.max_lines_visible = 4
	pl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pas.add_child(pl)
	v.add_child(pas)
	v.add_child(_hline())
	v.add_child(_stat_rows(it, 24))
	v.add_child(_sp(0, 0, false, true))
	var row := _h(8)
	row.add_child(_lbl("Alınca kalan", 24, _c("dim")))
	row.add_child(_sp(0, 0, true))
	row.add_child(_shard(18))
	row.add_child(_lbl(str(SHARDS - int(it["cost"])), 24, _c("text")))
	v.add_child(row)
	v.add_child(_price_btn("AÇ", int(it["cost"]), "primary", 40, 80))
	h.add_child(v)
	p.add_child(h)
	return p


## ---------------------------------------------------------------- F karakter sayfası v2: "kahraman seçimi"
## Kullanıcı (2026-10-16): "solda listelenmesi karakterleri değersiz ve sıradan gösterdi" -> büyük sahne + bilgi paneli + altta çerçeveli
## karakter kartları dizisi (dövüş oyunu / MOBA kahraman seçimi gibi). Seçili kart yükselir, köşe süsü + vurgu kenarı alır.

## Sahne zemini: basamaklı ışık havuzu + tepeden inen ışık konisi + zemin elipsi (halkalı) + köşe süsleri.
class StageBg extends Control:
	var col: Color = Color.WHITE
	var ring: Color = Color.WHITE
	var floor_off: float = 90.0

	func _init(c: Color, r: Color, fo: float = 90.0) -> void:
		col = c
		ring = r
		floor_off = fo
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var cx: float = floorf(w * 0.5)
		var fy: float = floorf(h - floor_off)
		## (arka ışık halkaları kaldırıldı - kullanıcı: "arkadan gelen ışığı kaldır, üstteki spotu tut")
		var tw: float = w * 0.05
		var bw: float = w * 0.24
		draw_colored_polygon(PackedVector2Array([Vector2(cx - tw, 0), Vector2(cx + tw, 0), Vector2(cx + bw, fy), Vector2(cx - bw, fy)]), Color(col, 0.06))
		draw_colored_polygon(PackedVector2Array([Vector2(cx - tw * 0.5, 0), Vector2(cx + tw * 0.5, 0), Vector2(cx + bw * 0.6, fy), Vector2(cx - bw * 0.6, fy)]), Color(col, 0.05))
		for k: Array in [[1.25, 0.16], [0.95, 0.16], [0.65, 0.14]]:
			var rx: float = bw * float(k[0])
			var pts := PackedVector2Array()
			for a in 49:
				var t: float = TAU * float(a) / 48.0
				pts.append(Vector2(cx + cos(t) * rx, fy + sin(t) * rx * 0.2))
			draw_colored_polygon(pts, Color(col, float(k[1])))
		var ring_pts := PackedVector2Array()
		for a in 65:
			var t: float = TAU * float(a) / 64.0
			ring_pts.append(Vector2(cx + cos(t) * bw * 1.25, fy + sin(t) * bw * 1.25 * 0.2).floor())
		draw_polyline(ring_pts, Color(ring, 0.55), 3.0)


## Pikselli köşe süsü (L köşeli parantezler + üst ortada küçük elmas).
class CornerFrame extends Control:
	var col: Color = Color.WHITE
	var ln: float = 22.0
	var t: float = 3.0
	var ins: float = 8.0
	var gem: bool = true

	func _init(c: Color, length: float = 22.0, inset: float = 8.0, with_gem: bool = true) -> void:
		col = c
		ln = length
		ins = inset
		gem = with_gem
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var i: float = ins
		for corner: Vector2 in [Vector2(i, i), Vector2(w - i - ln, i), Vector2(i, h - i - t), Vector2(w - i - ln, h - i - t)]:
			draw_rect(Rect2(corner, Vector2(ln, t)), col)
		for corner: Vector2 in [Vector2(i, i), Vector2(w - i - t, i), Vector2(i, h - i - ln), Vector2(w - i - t, h - i - ln)]:
			draw_rect(Rect2(corner, Vector2(t, ln)), col)
		if gem:
			var c := Vector2(floorf(w * 0.5), i + 1.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), col)


## Kart zemini: yukarıdan aşağı basamaklı koyulaşan dolgu + portre arkasında ışık lekesi.
class CardBg extends Control:
	var top: Color = Color.WHITE
	var bottom: Color = Color.BLACK
	var glow: Color = Color.WHITE
	var glow_y: float = 0.38

	func _init(t: Color, b: Color, g: Color) -> void:
		top = t
		bottom = b
		glow = g
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n: int = 6
		var bh: float = ceilf(size.y / n)
		for i in n:
			draw_rect(Rect2(0, i * bh, size.x, bh), top.lerp(bottom, float(i) / float(n - 1)))
		var c := Vector2(floorf(size.x * 0.5), floorf(size.y * glow_y))
		for i in 3:
			draw_circle(c, floorf(size.x * (0.42 - i * 0.1)), Color(glow, 0.07 + i * 0.04))


func _anchored(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> Control:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob
	return c


func _status_badge(it: Dictionary) -> PanelContainer:
	var st: String = _state(it)
	var fill: Color = _c("inset")
	var bd: Color = _c("line_hi")
	var txt: String = "KİLİTLİ"
	var tc: Color = _c("dim")
	if st == "can":
		bd = _c("good")
		txt = "ŞİMDİ ALABİLİRSİN"
		tc = _c("good")
	elif st == "open":
		bd = _c("good")
		txt = "SENDE"
		tc = _c("good")
	var p := _box(fill, bd, 8, 3, 6)
	var h := _h(8)
	if st == "no":
		h.add_child(_glyph(G_LOCK, tc, 3))
	elif st == "open":
		h.add_child(_glyph(G_CHECK, tc, 3))
	else:
		h.add_child(_shard(20))
	h.add_child(_lbl(txt, 24, tc))
	p.add_child(h)
	return p


## Büyük sahne: karakter tam boy, ışık konisinin altında halkalı zeminde; sol üstte durum rozeti, yanlarda gezinme okları.
func _f_stage(it: Dictionary, pv_idx: int = -1) -> Control:
	var p := _box(_c("inset"), _c("line_hi"), 0, 3, 8)
	_pv_stage = p
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var floor_off: float = 92.0
	p.add_child(StageBg.new(_c("spot"), _c("accent"), floor_off))
	p.add_child(CornerFrame.new(_c("accent"), 26.0, 10.0))
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hold)
	var tex: Texture2D = _char_body(it)
	var ts: Vector2 = tex.get_size()
	var k: float = floorf(430.0 / ts.y)
	var spr := TextureRect.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_SCALE
	var sw: float = ts.x * k
	var shh: float = ts.y * k
	if pv_idx < 0:
		hold.add_child(_anchored(spr, 0.5, 1.0, 0.5, 1.0, -floorf(sw * 0.5), -(floor_off - 8.0) - shh, floorf(sw * 0.5), -(floor_off - 8.0)))
	hold.add_child(_anchored(_status_badge(it), 0, 0, 0, 0, 26, 26, 26, 26))
	## yetenek önizleme göstergesi (üst orta): karaktere tıklayınca Q -> E -> R kendiliğinden oynar
	var chips := _pv_chips(it, maxi(pv_idx, 0))
	hold.add_child(_anchored(chips, 0.5, 0, 0.5, 0, -300, 26, 300, 70))
	for side: Array in [[G_LEFT, 0.0, 26.0], [G_RIGHT, 1.0, -26.0 - 72.0]]:
		var ab := _btn("", "ghost", 32, 72, 72)
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(_glyph(side[0], _c("text"), 5))
		ab.add_child(cc)
		hold.add_child(_anchored(ab, float(side[1]), 0.5, float(side[1]), 0.5, float(side[2]), -36, float(side[2]) + 72.0, 36))
	return p


## Sağ bilgi paneli: ad, yetenekler (ikon + kısa açıklama), pasif, statlar, satın alma.
func _f_info(it: Dictionary, active: int = 0) -> Control:
	var d: Dictionary = _char_def(it)
	var p := _box(_c("panel"), _c("line_hi"), 24, 3, 8)
	p.custom_minimum_size.x = 660
	var v := _v(10)
	v.add_child(_lbl(str(it["name"]), 64))
	v.add_child(_hline())
	v.add_child(_lbl("YETENEKLER", 24, _c("accent")))
	v.add_child(_skill_icon_rows(it, 32, 536.0, active))
	var pas := _v(4)
	pas.add_child(_lbl("PASİF", 24, _c("accent")))
	var pl := _wrap(str(d.get("passive", "")), 24, _c("dim"), 608)
	pl.max_lines_visible = 3
	pl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pas.add_child(pl)
	v.add_child(pas)
	v.add_child(_hline())
	v.add_child(_stat_rows(it, 24, 2))
	v.add_child(_sp(0, 0, false, true))
	var br := _h(16)
	var kv := _v(-4)
	kv.add_child(_lbl("Alınca kalan", 24, _c("dim")))
	var kh := _h(6)
	kh.add_child(_shard(20))
	kh.add_child(_lbl(str(SHARDS - int(it["cost"])), 32))
	kv.add_child(kh)
	kv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	br.add_child(kv)
	br.add_child(_expand(_price_btn("AÇ", int(it["cost"]), "primary", 40, 80)))
	v.add_child(br)
	p.add_child(v)
	return p


## Alt sıra: çerçeveli karakter kartları (portre x3, ad levhası, fiyat). Seçili kart 14 px yukarıda + köşe süsü.
func _f_roster(items: Array, sel: Dictionary) -> Control:
	var row := _h(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for it: Dictionary in items:
		var on: bool = it == sel
		var st: String = _state(it)
		var wrap := MarginContainer.new()
		wrap.add_theme_constant_override("margin_top", 0 if on else 14)
		wrap.add_theme_constant_override("margin_bottom", 14 if on else 0)
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card := _box(_c("panel"), _c("accent") if on else (_c("line_hi") if st == "can" else _c("line")), 3, 3, 6)
		card.custom_minimum_size = Vector2(170, 214)
		card.add_child(CardBg.new(_c("panel3") if on else _c("panel2"), _c("inset"), _c("spot") if st != "no" else _c("line")))
		var v := _v(2)
		v.add_child(_sp(0, 4))
		v.add_child(_icon(it["icon"], 144, st == "no"))
		var plate := _box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 2, 0, 0)
		plate.add_child(_lbl(str(it["name"]), 24, _c("accent") if on else (_c("dim") if st == "open" else _c("text")), HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(plate)
		v.add_child(_price(it, 32))
		card.add_child(v)
		if on:
			card.add_child(CornerFrame.new(_c("accent"), 16.0, 5.0))
		if st == "no":
			var g := _glyph(G_LOCK, _c("dim"), 3)
			g.size_flags_horizontal = Control.SIZE_SHRINK_END
			g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var gm := MarginContainer.new()
			gm.add_theme_constant_override("margin_right", 10)
			gm.add_theme_constant_override("margin_top", 10)
			gm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gm.add_child(g)
			gm.size_flags_horizontal = Control.SIZE_SHRINK_END
			gm.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			card.add_child(gm)
		wrap.add_child(card)
		row.add_child(wrap)
	return row


## ================================================================ YETENEK ÖNİZLEMESİ (kayıt denemesi, 2026-10-16)
## Kullanıcı: "karaktere tıklayınca otomatik olarak karakterin yeteneklerini kullandığı önizlemeler olsun her karakterde".
## Canlı önizleme menüde SORUNLU: yetenek efektleri get_tree().current_scene'e eklenir (menüde current_scene ana menüdür) ->
## önizleme oyunun GERÇEK motorunda kaydedilir, mağaza kayıtları oynatır (LoL'deki yetenek videoları gibi).
## Bu kip: SHOP_PREVIEW=<karakter id> -> 1) sahnesi boş F karakter sayfası Q/E/R vurgulu 3 kez yakalanır (pv_ui_<i>.png) + sahnenin
## piksel dikdörtgeni; 2) arayüz kalkar, kök görüntü şeffaf, current_scene = boş dünya; her yetenek için TEMİZ bir player.tscn +
## slime hedefler kurulur, yetenek tetiklenir, sahne dikdörtgeni kare kare kaydedilir (pv_<i>_<kare>.png, saydam). Birleştirme Python'da.

const PV_FPS := 15
const PV_ZOOM := 3.75
const PV_DUR := [2.6, 3.0, 4.2] ## Q, E, R kayıt süresi (sn)

var _pv_stage: Control = null


class PvDummy extends Node2D:
	## Önizleme hedefi: oyunun slime sprite'ı, yerinde kıpırdar, vurulunca beyaz parlar. Hasar almaz, ölmez.
	var is_dead: bool = false
	var is_frozen: bool = false
	var health: float = 999999.0
	var max_health: float = 999999.0
	var spr: Sprite2D = null
	var flash: float = 0.0
	var t: float = 0.0

	func _init(tex: Texture2D) -> void:
		spr = Sprite2D.new()
		spr.texture = tex
		spr.hframes = 8
		spr.vframes = 4
		spr.scale = Vector2(0.949, 0.949) * 0.85
		spr.offset = Vector2(0, -4.86)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(spr)
		add_to_group("enemies")

	func _process(dt: float) -> void:
		t += dt
		spr.frame = int(t * 9.0) % 8
		flash = maxf(0.0, flash - dt * 5.0)
		spr.modulate = Color(1, 1, 1).lerp(Color(4, 4, 4), flash)

	func take_damage(_amount: float, _crit: bool = false, _pen: float = 0.0, _is_area: bool = false) -> void:
		flash = 1.0


func _pv_char_item(key: int) -> Dictionary:
	for i: Dictionary in _all:
		if i["kind"] == MP.CHAR and int(i["key"]) == key:
			return i
	return _first_can(MP.CHAR)


func _preview_run(key: int) -> void:
	_kind_now = "f"
	P = PAL["c"]
	var it: Dictionary = _pv_char_item(key)
	var stage_px := Rect2()
	var floor_base := Vector2.ZERO
	for idx in 3:
		var ui: Control = _f_kar_page(it, idx)
		root.add_child(ui)
		await _frames(8)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_dir.path_join("pv_ui_%d.png" % idx))
		var gr: Rect2 = _pv_stage.get_global_rect()
		var xf: Transform2D = root.get_final_transform()
		stage_px = Rect2(xf * gr.position, xf.basis_xform(gr.size))
		floor_base = Vector2(gr.get_center().x, gr.end.y - 92.0)
		ui.queue_free()
		await process_frame
	print("STAGE ", stage_px, " floor ", floor_base)
	AudioServer.set_bus_mute(0, true)
	root.transparent_bg = true
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var cam := Camera2D.new()
	cam.zoom = Vector2(PV_ZOOM, PV_ZOOM)
	world.add_child(cam)
	cam.make_current()
	var origin := Vector2(500, 500)
	cam.position = origin - (floor_base - Vector2(960, 540)) / PV_ZOOM
	var slime: Texture2D = load("res://visuals/Yaratıklar/Tüm Yaratıklar/Slime 1/PNG/Slime1/With_shadow/Slime1_Walk_with_shadow.png")
	var d: Dictionary = _char_def(it)
	var gm: Node = root.get_node("GameManager") ## -s betiği autoload'lardan önce derlenir: adla erişilemez
	gm.selected_char_id = int(it["key"])
	gm.selected_character = int(d.get("skill", 1))
	for idx in 3:
		var p: CharacterBody2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
		p.scale = Vector2(0.5, 0.5)
		world.add_child(p)
		p.global_position = origin
		var pc: Camera2D = p.get_node_or_null("Camera2D")
		if pc:
			pc.enabled = false
		cam.make_current()
		## can/kalkana DOKUNULMAZ (elle 1.000.000 can yeşil iyileşme yazısı + efekt çıkarıyordu); R'nin kalkan bedeli oyuncunun
		## kendi başlangıç kalkanından ödenir. Kafa üstü çubuk/ad önizlemede gizli.
		for nn: String in ["OverheadBar", "NameLabel", "DownedTimerLabel"]:
			var hn: CanvasItem = p.get_node_or_null(nn)
			if hn:
				hn.visible = false
		p.item_shield_max = 400.0 ## yetenek bedeli mana kalkanından ödenir (yeni doğan oyuncuda 0: "MANA K. YETERSİZ")
		p.item_shield_hp = 400.0
		var dummies: Array = []
		for off: Vector2 in [Vector2(70, -6), Vector2(-68, 4), Vector2(34, -26), Vector2(-30, -24), Vector2(8, 16)]:
			var dm := PvDummy.new(slime)
			world.add_child(dm)
			dm.global_position = origin + off
			dm.set_meta((load("res://scripts/vision_fog.gd") as GDScript).VIS_META, 1.0)
			dummies.append(dm)
		p.level = 10 ## E 5., R 10. seviyede açılır
		var t0: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 600:
			await process_frame
		## Yetenek GERÇEK tuş basışıyla tetiklenir: Q dağıtımı karaktere göre tuş işleyicisinde dallanıyor (Assasin Q -> _try_assasin_dash2,
		## Cadı/Hadime aç-kapa, Korsan bomba...) - _activate_skill() doğrudan çağrılırsa Assasin'de Oakley'nin iyileştirmesi çalışıyordu.
		var action: String = ["skill", "skill2", "skill3"][idx]
		p.facing = "right"
		_pv_press(action)
		var dur: float = float(PV_DUR[idx])
		var n: int = int(dur * PV_FPS)
		var start: int = Time.get_ticks_msec()
		for f in n:
			while Time.get_ticks_msec() - start < int(1000.0 * f / PV_FPS):
				await process_frame
			if idx == 0 and f == int(PV_FPS * 1.1):
				p.facing = "left"
				_pv_press(action)
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			img.get_region(Rect2i(stage_px)).save_png(_dir.path_join("pv_%d_%03d.png" % [idx, f]))
		print("PV %d kare=%d" % [idx, n])
		for c in world.get_children():
			if c != cam:
				c.queue_free()
		await _frames(3)
	print("PV_RECT %d %d %d %d" % [int(stage_px.position.x), int(stage_px.position.y), int(stage_px.size.x), int(stage_px.size.y)])


func _pv_press(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await physics_frame
	Input.action_release(action)


## F karakter sayfasının tek başına kurulumu (önizleme kipi: pv_idx >= 0 -> sahnede figür yok, o yetenek vurgulu).
func _f_kar_page(it: Dictionary, pv_idx: int = -1) -> Control:
	var r := _root()
	var m := _margin(32, 20, 32, 28)
	r.add_child(m)
	var col := _v(16)
	m.add_child(col)
	col.add_child(_topbar("ANA SAYFA", _f_page_title(_shard(36), "KARAKTERLER", "%d/%d" % [_open_n(MP.CHAR), _total_n(MP.CHAR)])))
	var body := _h(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(body)
	body.add_child(_f_stage(it, pv_idx))
	body.add_child(_f_info(it, maxi(pv_idx, 0)))
	col.add_child(_f_roster(_of(MP.CHAR), it))
	return r


## Sahne üstündeki önizleme göstergesi: Q / E / R çipleri, oynayanın adı görünür ve vurgulu.
func _pv_chips(it: Dictionary, active: int) -> HBoxContainer:
	var d: Dictionary = _char_def(it)
	var row := _h(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var keys: Array = [["Q", "skill_name", "skill_icon"], ["E", "skill2_name", "skill2_icon"], ["R", "skill3_name", "skill3_icon"]]
	for i in 3:
		var on: bool = i == active
		var chip := _box(_c("panel3") if on else Color(_c("inset"), 0.85), _c("accent") if on else _c("line"), 4, 3, 5)
		var h := _h(8)
		var ip: String = str(d.get(keys[i][2], ""))
		if ip != "" and ResourceLoader.exists(ip):
			var ic := _icon(load(ip) as Texture2D, 32, not on)
			h.add_child(ic)
		h.add_child(_lbl(keys[i][0], 24, _c("accent") if on else _c("dim")))
		if on:
			h.add_child(_lbl(str(d.get(keys[i][1], "")), 24, _c("text")))
			h.add_child(_sp(4))
		chip.add_child(h)
		row.add_child(chip)
	return row
