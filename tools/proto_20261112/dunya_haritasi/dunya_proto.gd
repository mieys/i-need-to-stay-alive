extends SceneTree

## DÜNYA HARİTASI seçim ekranı prototipleri A-D (2026-11-12, oyuna bağlı DEĞİL).
## Dünya = compose.py'nin kıtası (haritaların gerçek çizici görüntüsü, 1 piksel = 1 hücre); vurgu/yol = overlay.py.
## Arayüz gerçek kit: shop_dark_kit (Kısık Ahşap, m5x7, pixel_box), pixel_signpost (DEVAM ET tabelası), skull_icon, karakter sayfaları.
##   A Açık Atlas      : dünya tam ekran 2x, seçili bölge altın kenar + diğerleri kararır, altta bilgi tepsisi
##   B Atlas Defteri   : pazar B3 dili - solda harita listesi, sağda haritanın büyük gerçek görüntüsü + bilgi
##   C Yakın Bakış     : seçili bölgeye 4x yakınlaşmış dünya, sağda bilgi sütunu, solda küçük dünya + görüş çerçevesi
##   D Sefer Yolu      : bölgeleri bağlayan toprak yol, her bölgede ad levhası, parti seçili bölgede bekler
## Kullanım: dunya_run.ps1 -Script dunya_proto.gd ; python -I ozet.py

const DarkKit := preload("res://scripts/shop_dark_kit.gd")
const HT := preload("res://scripts/hud_theme.gd")
const Signpost := preload("res://scripts/pixel_signpost.gd")
const Skull := preload("res://scripts/skull_icon.gd")
const MapProfiles := preload("res://scripts/map_profiles.gd")
const Chars := preload("res://scripts/characters.gd")

const SCREEN := Vector2(1920, 1080)
const SEA := Color("#49678a")
var _k = null
var _meta: Dictionary = {}
var _texs: Dictionary = {}
var _ui: Control = null


func _initialize() -> void:
	_run.call_deferred()


func _out() -> String:
	var d: String = OS.get_environment("DUNYA_OUT")
	if d == "":
		d = ProjectSettings.globalize_path("res://tools/proto_20261112/dunya_haritasi/out")
	return d


func _tex(name: String) -> Texture2D:
	if _texs.has(name):
		return _texs[name]
	var img := Image.load_from_file(_out().path_join(name))
	var t := ImageTexture.create_from_image(img)
	_texs[name] = t
	return t


func _region(id: String) -> Dictionary:
	for r: Dictionary in _meta["regions"]:
		if r["id"] == id:
			return r
	return {}


func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	img.save_png(_out().path_join(name))
	print("SHOT %s" % name)


func _run() -> void:
	await process_frame
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.get_node("UISound").set("show_fps", false)
	AudioServer.set_bus_mute(0, true)
	_meta = JSON.parse_string(FileAccess.get_file_as_string(_out().path_join("bolgeler.json")))
	_k = DarkKit.new(DarkKit.PAL_NIGHT)
	var only: String = OS.get_environment("DUNYA_ONLY")
	for v: String in ["A", "B", "C", "D"]:
		if only != "" and not only.contains(v):
			continue
		if _ui:
			_ui.queue_free()
			await process_frame
		_ui = Control.new()
		_ui.size = SCREEN
		_ui.theme = _k.theme()
		root.add_child(_ui)
		var bg := ColorRect.new()
		bg.color = SEA
		bg.size = SCREEN
		_ui.add_child(bg)
		call("_build_" + v)
		await _wait_frames(6)
		await _shot("dunya_%s.png" % v)
	quit()


# ---------------------------------------------------------------- ortak parçalar

func _img(parent: Control, t: Texture2D, pos: Vector2, scale: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.position = pos
	r.size = Vector2(t.get_size()) * scale
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


## Dünya + seçili bölgenin karartması ve altın kenarı; S ölçek, off ekran kayması (dünya pikseli -> ekran).
func _world(parent: Control, sel: String, s: float, off: Vector2, file: String = "dunya.png", dim: bool = true) -> void:
	_img(parent, _tex(file), off, s)
	if sel != "":
		if dim:
			_img(parent, _tex("karart_%s.png" % sel), off, s)
		_img(parent, _tex("cerceve_%s.png" % sel), off, s)


func _w2s(p: Vector2, s: float, off: Vector2) -> Vector2:
	return p * s + off


func _outlined(t: String, fs: int, col: Color) -> Label:
	var l: Label = _k.lbl(t, fs, col)
	l.add_theme_color_override("font_outline_color", HT.OUTLINE)
	l.add_theme_constant_override("outline_size", 9 if fs >= 40 else 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Bölge adı haritanın üstünde, oyun alanının üst kenarına ortalı.
func _map_name(parent: Control, id: String, s: float, off: Vector2, sel: bool) -> void:
	var r: Array = _region(id)["rect"]
	var l: Label = _outlined(_name(id).to_upper(), 32, HT.ACCENT if sel else HT.TEXT)
	parent.add_child(l)
	var w: float = _k.tw(l.text, 32)
	var top: Vector2 = _w2s(Vector2(r[0] + r[2] * 0.5, r[1]), s, off)
	l.position = Vector2(roundf(top.x - w * 0.5), top.y - 40)


func _name(id: String) -> String:
	return str(MapProfiles.get_profile(id).get("ad", id))


func _kind(id: String) -> String:
	return "YERALTI" if str(MapProfiles.get_profile(id).get("tur", "")) == MapProfiles.KIND_ZINDAN else "YÜZEY"


func _desc(id: String) -> String:
	return str(MapProfiles.get_profile(id).get("aciklama", ""))


func _go(caption: String = "YOLA ÇIK") -> Button:
	var gw: float = 300.0
	var gh: float = 57.0
	var w: int = int(gw) / Signpost.PX
	var h: int = int(gh) / Signpost.PX
	var b := Button.new()
	b.custom_minimum_size = Vector2(gw, gh)
	b.add_theme_stylebox_override("normal", Signpost.box(w, h, HT.RIM, HT.OUTLINE))
	b.add_theme_stylebox_override("hover", Signpost.box(w, h, HT.RIM_HI, HT.OUTLINE))
	b.add_theme_stylebox_override("focus", Signpost.box(w, h, HT.RIM, HT.ACCENT, true))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_right = -float(Signpost.tip_px(h))
	cc.offset_bottom = -float(Signpost.PX)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(_k.lbl(caption, 40, HT.TEXT))
	b.add_child(cc)
	return b


## Kademe/boss satırı: kafatası + yazı.
func _facts() -> VBoxContainer:
	var v: VBoxContainer = _k.v(6)
	var r1: HBoxContainer = _k.h(12)
	var sk := TextureRect.new()
	sk.texture = Skull.tex()
	sk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sk.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	sk.custom_minimum_size = Vector2(30, 32)
	r1.add_child(sk)
	r1.add_child(_k.lbl("BOSS: KADEME 5 VE 10", 32, HT.TEXT))
	v.add_child(r1)
	v.add_child(_k.lbl("10 kademe, son boss ölünce zafer", 32, HT.DIM))
	return v


func _place(parent: Control, n: Control, pos: Vector2, sz: Vector2 = Vector2.ZERO) -> Control:
	parent.add_child(n)
	n.position = pos
	if sz != Vector2.ZERO:
		n.size = sz
		n.custom_minimum_size = sz
	return n


## Çift ahşap çerçeve (envanter / pazar dili): dış RIM + OUTLINE, iç panel + RIM_LO.
func _window(parent: Control, rect: Rect2) -> PanelContainer:
	var rb: PanelContainer = _k.box(HT.RIM, HT.OUTLINE, 8.0, 4, 6)
	_place(parent, rb, rect.position, rect.size)
	var win: PanelContainer = _k.box(_k.c("panel"), HT.RIM_LO, 16.0, 3, 4)
	rb.add_child(win)
	return win


func _back(parent: Control, pos: Vector2) -> void:
	var b: Button = _k.btn("GERİ", "ghost", 32, 57.0, 160.0)
	_place(parent, b, pos)


# ---------------------------------------------------------------- A: Açık Atlas

func _build_A() -> void:
	var sel := "ana"
	var s := 2.0
	var off := Vector2(0, -4)
	_world(_ui, sel, s, off)
	for r: Dictionary in _meta["regions"]:
		_map_name(_ui, str(r["id"]), s, off, r["id"] == sel)
	_back(_ui, Vector2(24, 20))
	## alt bilgi tepsisi
	var tray: PanelContainer = _k.box(HT.RIM, HT.OUTLINE, 8.0, 4, 6)
	_place(_ui, tray, Vector2(330, 870), Vector2(1260, 186))
	var win: PanelContainer = _k.box(_k.c("panel"), HT.RIM_LO, 16.0, 3, 4)
	tray.add_child(win)
	var row: HBoxContainer = _k.h(28)
	win.add_child(row)
	var left: VBoxContainer = _k.v(4)
	left.custom_minimum_size.x = 300
	left.add_child(_k.lbl(_name(sel).to_upper(), 48, HT.ACCENT))
	left.add_child(_k.lbl(_kind(sel), 32, HT.DIM))
	row.add_child(left)
	var mid: VBoxContainer = _k.v(8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(_k.wrap(_desc(sel), 32, HT.TEXT, 560))
	mid.add_child(_facts())
	row.add_child(mid)
	var rc: VBoxContainer = _k.v(0)
	rc.alignment = BoxContainer.ALIGNMENT_END
	rc.add_child(_go())
	row.add_child(rc)


# ---------------------------------------------------------------- B: Atlas Defteri

func _build_B() -> void:
	var sel := "bataklik"
	_world(_ui, "", 2.0, Vector2(0, -4))
	var shade := ColorRect.new()
	shade.color = Color(HT.DEEP, 0.72)
	shade.size = SCREEN
	_ui.add_child(shade)
	var win: PanelContainer = _window(_ui, Rect2(150, 70, 1620, 900))
	var body: HBoxContainer = _k.h(18)
	win.add_child(body)
	## liste
	var lb: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 12.0, 3, 6)
	lb.custom_minimum_size.x = 470
	body.add_child(lb)
	var lv: VBoxContainer = _k.v(10)
	lb.add_child(lv)
	lv.add_child(_k.lbl("HARİTALAR", 32, HT.ACCENT_SOFT))
	for id: String in MapProfiles.selectable_ids():
		var on: bool = id == sel
		var row: HBoxContainer = _k.h(14)
		var thumb: Texture2D = _thumb(id)
		var tr := TextureRect.new()
		tr.texture = thumb
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.custom_minimum_size = Vector2(96, 96)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(tr)
		var tv: VBoxContainer = _k.v(0)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_child(_k.lbl(_name(id).to_upper(), 32, HT.ACCENT if on else HT.TEXT))
		tv.add_child(_k.lbl(_kind(id), 24, HT.DIM))
		row.add_child(tv)
		var b: Button = _k.row_btn(row, "ghost", 116.0, 444.0)
		b.add_theme_stylebox_override("normal", _k.sb(HT.PLATE_ON if on else _k.c("panel3"), HT.ACCENT if on else _k.c("line"), 3, 6))
		lv.add_child(b)
	## önizleme
	var dbox: PanelContainer = _k.box(_k.c("panel2"), _k.c("line_hi"), 18.0, 3, 6)
	dbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(dbox)
	var dv: VBoxContainer = _k.v(12)
	dbox.add_child(dv)
	var pic: PanelContainer = _k.box(HT.DEEP, HT.OUTLINE, 0.0, 3, 0)
	pic.custom_minimum_size = Vector2(1056, 500)
	pic.clip_contents = true
	dv.add_child(pic)
	var view := Control.new()
	view.clip_contents = true
	view.custom_minimum_size = Vector2(1050, 494)
	pic.add_child(view)
	var big: Texture2D = _tex("render4_%s.png" % sel)
	var bs: Vector2 = Vector2(big.get_size())
	_img(view, big, Vector2(roundf((1050 - bs.x) * 0.5), roundf((494 - bs.y) * 0.5)), 1.0)
	var hr: HBoxContainer = _k.h(20)
	var hv: VBoxContainer = _k.v(0)
	hv.add_child(_k.lbl(_name(sel).to_upper(), 48, HT.ACCENT))
	hv.add_child(_k.lbl(_kind(sel), 32, HT.DIM))
	hr.add_child(hv)
	hr.add_child(_k.sp(0, 0, true))
	var gv: VBoxContainer = _k.v(0)
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gv.add_child(_go())
	hr.add_child(gv)
	dv.add_child(hr)
	dv.add_child(_k.wrap(_desc(sel), 32, HT.TEXT, 1040))
	dv.add_child(_facts())


func _thumb(id: String) -> Texture2D:
	var key := "thumb_" + id
	if _texs.has(key):
		return _texs[key]
	var img := Image.load_from_file(_out().path_join("render4_%s.png" % id))
	var r: Array = _region(id)["rect"]
	## oyun alanı kesiti, 96 px kareye kutu filtresiyle (ara adım yarıya küçültme)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_out().path_join("render4_%s.json" % id)))
	var play := {"ana": Rect2i(28, 20, 256, 256), "bataklik": Rect2i(32, 20, 214, 214), "col": Rect2i(32, 20, 243, 243)}
	var pr: Rect2i = play.get(id, Rect2i(0, 0, int(meta["cells_w"]), int(meta["cells_h"])))
	var crop: Image = img.get_region(Rect2i(pr.position * 4, pr.size * 4))
	while crop.get_width() > 192:
		crop.shrink_x2()
	crop.resize(96, 96, Image.INTERPOLATE_BILINEAR)
	var t := ImageTexture.create_from_image(crop)
	_texs[key] = t
	return t


# ---------------------------------------------------------------- C: Yakın Bakış

func _build_C() -> void:
	var sel := "col"
	var s := 4.0
	var c: Array = _region(sel)["center"]
	var view_w: float = 1400.0
	var off := Vector2(roundf(view_w * 0.5 - c[0] * s), roundf(540 - c[1] * s))
	_world(_ui, sel, s, off, "dunya.png", false)
	for r: Dictionary in _meta["regions"]:
		if r["id"] != sel:
			_map_name(_ui, str(r["id"]), s, off, false)
	## üstte ad levhası
	var plaque: PanelContainer = _k.box(HT.RIM, HT.OUTLINE, 6.0, 4, 6)
	var pin: PanelContainer = _k.box(_k.c("panel"), HT.RIM_LO, 14.0, 3, 4)
	plaque.add_child(pin)
	var pl: Label = _k.lbl(_name(sel).to_upper(), 48, HT.ACCENT)
	pin.add_child(pl)
	_ui.add_child(plaque)
	await process_frame
	plaque.position = Vector2(roundf(view_w * 0.5 - plaque.size.x * 0.5), 24)
	_back(_ui, Vector2(24, 24))
	## sağ bilgi sütunu
	var win: PanelContainer = _window(_ui, Rect2(1404, 0, 516, 1080))
	var v: VBoxContainer = _k.v(16)
	win.add_child(v)
	v.add_child(_k.lbl(_kind(sel), 32, HT.DIM))
	v.add_child(_k.lbl(_name(sel).to_upper(), 48, HT.ACCENT))
	v.add_child(_k.hline(HT.RIM_LO, 3.0))
	v.add_child(_k.wrap(_desc(sel), 32, HT.TEXT, 460))
	v.add_child(_facts())
	v.add_child(_k.sp(0, 0, false, true))
	## küçük dünya + görüş çerçevesi
	var mini_box: PanelContainer = _k.box(HT.DEEP, HT.OUTLINE, 0.0, 3, 0)
	mini_box.custom_minimum_size = Vector2(480, 272)
	v.add_child(mini_box)
	var mini := Control.new()
	mini.custom_minimum_size = Vector2(480, 272)
	mini_box.add_child(mini)
	var mt: Texture2D = _half_world()
	_img(mini, mt, Vector2.ZERO, 1.0)
	var vr := Rect2(-off / s * 0.5, Vector2(view_w, 1080) / s * 0.5)
	var frame := ReferenceRect.new()
	frame.border_color = HT.ACCENT
	frame.border_width = 2.0
	frame.editor_only = false
	frame.position = vr.position.round()
	frame.size = vr.size.round()
	mini.add_child(frame)
	var gc: HBoxContainer = _k.h(0)
	gc.alignment = BoxContainer.ALIGNMENT_END
	gc.add_child(_go())
	v.add_child(gc)


func _half_world() -> Texture2D:
	if _texs.has("half"):
		return _texs["half"]
	var img := Image.load_from_file(_out().path_join("dunya.png"))
	img.shrink_x2()
	var t := ImageTexture.create_from_image(img)
	_texs["half"] = t
	return t


# ---------------------------------------------------------------- D: Sefer Yolu

func _build_D() -> void:
	var sel := "batik_nekropol"
	var s := 2.0
	var off := Vector2(0, -4)
	_world(_ui, sel, s, off, "dunya_yol.png", false)
	for r: Dictionary in _meta["regions"]:
		var id: String = str(r["id"])
		var on: bool = id == sel
		var rect: Array = r["rect"]
		var pl: PanelContainer = _k.box(HT.RIM if not on else HT.ACCENT, HT.OUTLINE, 6.0, 3, 4)
		var l: Label = _k.lbl(_name(id).to_upper(), 32, HT.TEXT if not on else HT.ACCENT_TEXT)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		pl.add_child(l)
		_ui.add_child(pl)
		await process_frame
		var top: Vector2 = _w2s(Vector2(rect[0] + rect[2] * 0.5, rect[1]), s, off)
		pl.position = Vector2(roundf(top.x - pl.size.x * 0.5), maxf(8.0, top.y - pl.size.y * 0.5))
	## parti: seçili bölgenin ortasında (Büyücü Kız önde, Şovalye + Talon arkada), sanat pikseli = dünya pikseli (2 ekran px)
	var c: Vector2 = _w2s(Vector2(_region(sel)["center"][0], _region(sel)["center"][1]), s, off)
	var ids := [7, 4, 1]
	for i in ids.size():
		_party(_ui, int(ids[i]), c + Vector2((i - 1) * 64.0, (0 if i == 1 else -18)), s)
	_back(_ui, Vector2(24, 20))
	var tray: PanelContainer = _k.box(HT.RIM, HT.OUTLINE, 8.0, 4, 6)
	_place(_ui, tray, Vector2(380, 902), Vector2(1160, 160))
	var win: PanelContainer = _k.box(_k.c("panel"), HT.RIM_LO, 14.0, 3, 4)
	tray.add_child(win)
	var row: HBoxContainer = _k.h(24)
	win.add_child(row)
	var tv: VBoxContainer = _k.v(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hr: HBoxContainer = _k.h(16)
	hr.add_child(_k.lbl(_name(sel).to_upper(), 48, HT.ACCENT))
	var kl: Label = _k.lbl(_kind(sel), 32, HT.DIM)
	kl.size_flags_vertical = Control.SIZE_SHRINK_END
	hr.add_child(kl)
	tv.add_child(hr)
	tv.add_child(_k.wrap(_desc(sel), 32, HT.TEXT, 760))
	row.add_child(tv)
	var gv: VBoxContainer = _k.v(0)
	gv.alignment = BoxContainer.ALIGNMENT_CENTER
	gv.add_child(_go())
	row.add_child(gv)


func _party(parent: Control, char_id: int, foot: Vector2, s: float) -> void:
	var def: Dictionary = Chars.get_def(char_id)
	var frames: SpriteFrames = load(str(def.get("frames", ""))) as SpriteFrames
	if frames == null:
		return
	var anim := ""
	for a: String in ["idle_down", "idle", "idle_right"]:
		if frames.has_animation(a):
			anim = a
			break
	if anim == "":
		anim = str(frames.get_animation_names()[0])
	var t: Texture2D = frames.get_frame_texture(anim, 0)
	var sz: Vector2 = Vector2(t.get_size()) * s
	var r: TextureRect = _img(parent, t, Vector2(roundf(foot.x - sz.x * 0.5), roundf(foot.y - sz.y * 0.8)), s)
	r.size = sz
