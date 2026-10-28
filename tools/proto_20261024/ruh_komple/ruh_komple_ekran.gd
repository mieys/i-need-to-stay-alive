extends "res://scripts/soul_shop_screen.gd"

## Ruh Mağazası KOMPLE yeniden tasarım prototipleri (2026-10-24, oyuna bağlı DEĞİL; madde 382). Kullanıcı: "komple 4 yeni prototip üret,
## her şeyi değiştir; şu anki hali karmaşık hissettiriyor". Gerçek soul_shop_screen.gd'den türer (veri, satın alma, iki adımlı onay, animasyon
## kancaları, sayfa geçişi aynı), ama ana sayfa + kategori sayfaları + geliştirmeler BAŞTAN kurulur. Ortak ilke: ANA SAYFA YOK, açılınca doğrudan
## Karakterler; her bölüm (geliştirmeler dahil) aynı kalıbı kullanır; ekranda tek ana eylem.
##   "a" Sekmeli Tezgâh   - bugünkü oda + koyu ahşap; üstte 5 sekme, solda çerçevesiz öğe ızgarası, sağda tek ayrıntı paneli
##   "b" Vitrin Odası     - panel YOK: öğe odanın zemininde spot altında tek başına, yanında yüzen yazı, altta küçük resim şeridi
##   "c" Ocak Başı Defteri - ana menü/ayarlar dili (Ateş Işığı, Ocak Başı sahnesi): solda bölümler (mum), ortada yazı listesi, sağda ayrıntı
##   "d" Kart Masası      - oda/karakter seçimi dili (Gece Sıvası): sayfa başına 5 büyük kart, karta basınca ayrıntı penceresi

const FM := preload("res://scripts/fire_menu_kit.gd")
const HearthBg := preload("res://scripts/menu_hearth_bg.gd")

var variant: String = ""
var modal_open: bool = false ## D: ayrıntı penceresi açık (seçili öğe)
var _sel_upg: String = ""
var _d_pages: Dictionary = {} ## D: bölüm -> sayfa
var _pal: Dictionary = {}
var _bg_done: bool = false
var _overlay: Control = null
var _crop_cache: Dictionary = {}

const SECTIONS := ["char", "weapon", "pet", "spirit", "upgrades"]
const KIND_LOWER := {"char": "Karakter", "weapon": "Başlangıç silahı", "pet": "Evcil hayvan", "spirit": "Ruhani yetenek"}
const D_PER_PAGE := 5


## ================================================================ yönlendirme (ana sayfa yok)
func _build_home() -> void:
	if variant == "":
		super._build_home()
		return
	_page = MetaProgressScript.CHAR
	_route(_page)


func _build_kind_page(kind: String) -> void:
	if variant == "":
		super._build_kind_page(kind)
		return
	_route(kind)


func _build_upgrades() -> void:
	if variant == "":
		super._build_upgrades()
		return
	_route(PAGE_UPGRADES)


func _route(page: String) -> void:
	_pal = _palette()
	_setup_bg()
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	match variant:
		"a":
			_a_build(page)
		"b":
			_b_build(page)
		"c":
			_c_build(page)
		"d":
			_d_build(page)


## C/D: ana menünün Ocak Başı sahnesi (oda arka planı gizlenir). C sola yumuşak karartma, D düz Gece Sıvası örtüsü (oda listesi gibi).
func _setup_bg() -> void:
	if _bg_done or not (variant in ["c", "d"]):
		return
	_bg_done = true
	var root := _page_box.get_parent().get_parent() as Control
	(root.get_child(0) as CanvasItem).visible = false
	var layer: Control = HearthBg.add_to(root, 0.0)
	root.move_child(layer, 1)
	if variant == "c":
		var sh := FM.StepShade.new()
		sh.col = Color(0.05, 0.035, 0.025, 0.88)
		sh.x0 = 1220.0
		sh.step_w = 40.0
		sh.steps = 6
		root.add_child(sh)
		root.move_child(sh, 2)
	else:
		var dim := ColorRect.new()
		dim.color = Color(HearthBg.DIM_COLOR, 0.5)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(dim)
		root.move_child(dim, 2)


func _palette() -> Dictionary:
	match variant:
		"c":
			return {"panel": Color(0.06, 0.04, 0.03, 0.82), "panel2": Color("#2a1d12"), "panel3": Color("#3a2a1a"), "inset": Color("#140e09"),
					"line": Color("#3b2a1a"), "line_hi": Color("#5a4128"), "text": Color("#efe2c6"), "dim": Color("#b09878"),
					"accent": Color("#f4c56e"), "accent_dk": Color("#6a4416"), "accent_text": Color("#24160a"), "good": Color("#a9c96e"),
					"bad": Color("#dc7f60"), "price": Color("#f2c674"), "spot": Color("#c0803a")}
		"d":
			return {"panel": Color(DK.C_PANEL, 0.94), "panel2": DK.C_PANEL2, "panel3": DK.C_PANEL3, "inset": DK.C_INSET, "line": DK.C_LINE,
					"line_hi": DK.C_LINE_HI, "text": DK.C_TEXT, "dim": DK.C_DIM, "accent": DK.C_ACCENT, "accent_dk": DK.C_ACCENT_DK,
					"accent_text": DK.C_ACCENT_TEXT, "good": DK.C_GOOD, "bad": DK.C_BAD, "price": DK.C_PRICE, "spot": DK.C_SPOT}
	return {"panel": C_PANEL, "panel2": C_PANEL2, "panel3": C_PANEL3, "inset": C_INSET, "line": C_LINE, "line_hi": C_LINE_HI, "text": C_TEXT,
			"dim": C_DIM, "accent": C_ACCENT, "accent_dk": C_ACCENT_DK, "accent_text": C_ACCENT_TEXT, "good": C_GOOD, "bad": C_BAD,
			"price": C_PRICE, "spot": C_SPOT}


func P(k: String) -> Color:
	return _pal[k]


## ================================================================ veri yardımcıları
func _sec_name(kind: String) -> String:
	return "Geliştirmeler" if kind == PAGE_UPGRADES else str(KIND_TILE.get(kind, kind))


func _sec_title(kind: String) -> String:
	return "GELİŞTİRMELER" if kind == PAGE_UPGRADES else str(KIND_NAMES.get(kind, kind))


func _by_cost(items: Array, kind: String) -> Array:
	var a: Array = items.filter(func(i: Dictionary) -> bool: return i["kind"] == kind)
	a.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["cost"]) < int(y["cost"]))
	return a


func _counts(items: Array, kind: String) -> Vector2i:
	if kind == PAGE_UPGRADES:
		return _upg_levels()
	var list: Array = _of_kind(items, kind)
	return Vector2i(_open_count(list), list.size())


func _can_n(items: Array, kind: String) -> int:
	var n: int = 0
	if kind == PAGE_UPGRADES:
		for d: Dictionary in MetaUpgradesScript.LIST:
			if MetaUpgradesScript.can_buy(str(d["id"])):
				n += 1
		return n
	for it: Dictionary in _of_kind(items, kind):
		if _state(it) == "can":
			n += 1
	return n


## Alınabilir en ucuz geliştirme (yoksa ilk).
func _rep_upgrade() -> Dictionary:
	var best: Dictionary = {}
	for d: Dictionary in MetaUpgradesScript.LIST:
		var id: String = str(d["id"])
		if MetaUpgradesScript.can_buy(id) and (best.is_empty() or MetaUpgradesScript.next_cost(id) < MetaUpgradesScript.next_cost(str(best["id"]))):
			best = d
	return best if not best.is_empty() else MetaUpgradesScript.LIST[0]


func _upg_selected() -> Dictionary:
	if _sel_upg != "":
		return MetaUpgradesScript.def(_sel_upg)
	return _rep_upgrade()


func _select_upg(id: String) -> void:
	_sel_upg = id
	_confirm_id = ""
	_rebuild_list()


## Öğenin büyük görseli: karakterde tam boy kare, silahta boş kenarı kırpılmış ikon, diğerlerinde ikon.
func _tex_of(it: Dictionary) -> Texture2D:
	if it["kind"] == MetaProgressScript.CHAR:
		return _char_body(it)
	var tex: Texture2D = it.get("icon", null)
	if tex == null or it["kind"] != MetaProgressScript.WEAPON:
		return tex
	if _crop_cache.has(tex):
		return _crop_cache[tex]
	var out: Texture2D = tex
	var img: Image = tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var used: Rect2i = img.get_used_rect()
		if used.size.x > 0:
			out = ImageTexture.create_from_image(img.get_region(used))
	_crop_cache[tex] = out
	return out


## Küçük ikon: karakterde yüz portresi, silahta kırpılmış ikon.
func _small_tex(it: Dictionary) -> Texture2D:
	return _tex_of(it) if it["kind"] == MetaProgressScript.WEAPON else it.get("icon", null)


func _with_tex(it: Dictionary) -> Dictionary:
	var d: Dictionary = it.duplicate()
	d["icon"] = _tex_of(it)
	return d


func _fit_k(tex: Texture2D, box: float) -> float:
	var big: float = maxf(tex.get_size().x, tex.get_size().y)
	var k: float = floorf(box / big)
	return k if k >= 1.0 else box / big


## Karakterler için ORTAK tam kat ölçek (göreli boylar doğru kalsın).
func _char_k(list: Array, max_h: float, max_w: float) -> float:
	var k: float = 64.0
	for it: Dictionary in list:
		var tex: Texture2D = _tex_of(it)
		if tex != null:
			k = minf(k, minf(floorf(max_h / tex.get_size().y), floorf(max_w / tex.get_size().x)))
	return maxf(1.0, k)


func _fig_sprite(tex: Texture2D, k: float, lift: float, dim: bool = false) -> TextureRect:
	var spr := TextureRect.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_SCALE
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts: Vector2 = (tex.get_size() * k).floor()
	spr.anchor_left = 0.5
	spr.anchor_right = 0.5
	spr.anchor_top = 1.0
	spr.anchor_bottom = 1.0
	spr.offset_left = -floorf(ts.x * 0.5)
	spr.offset_right = spr.offset_left + ts.x
	spr.offset_top = -lift - ts.y
	spr.offset_bottom = -lift
	if dim:
		spr.modulate = Color(0.52, 0.52, 0.58, 1.0)
	return spr


## Kutunun ortasında ikon (tam kat; kutudan büyükse küçülür).
func _center_tex(tex: Texture2D, box: float, dim: bool = false) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		return cc
	var tr := TextureRect.new()
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.custom_minimum_size = (tex.get_size() * _fit_k(tex, box)).floor()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		tr.modulate = Color(0.52, 0.52, 0.58, 1.0)
	cc.add_child(tr)
	return cc


func _tab_icon(items: Array, kind: String, box: float) -> Control:
	if kind == PAGE_UPGRADES:
		return _icon(_stat_tex("damage"), box)
	var list: Array = _by_cost(items, kind)
	return _icon(_small_tex(list[0]) if not list.is_empty() else null, box)


## ================================================================ paletli parçalar
func _pbtn_style(b: BaseButton, kind: String) -> void:
	var fill: Color = P("accent")
	var bd: Color = P("accent_dk")
	var tc: Color = P("accent_text")
	match kind:
		"ghost":
			fill = P("panel2")
			bd = P("line_hi")
			tc = P("text")
		"off":
			fill = P("inset")
			bd = P("line")
			tc = P("dim")
		"confirm":
			fill = P("good")
			bd = P("good").darkened(0.55)
			tc = Color("#10200c")
		"danger":
			fill = P("panel2")
			bd = P("bad").darkened(0.3)
			tc = P("bad")
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var f: Color = fill.lightened(0.08) if st == "hover" else fill
		var sb := _sb(f, bd, 3, 6, 10.0)
		if st == "focus":
			sb = _sb(Color(0, 0, 0, 0), P("text"), 3, 6, 10.0)
		b.add_theme_stylebox_override(st, sb)
	for fc: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(fc, tc)


func _pbtn(t: String, kind: String = "primary", fs: int = 32, h: float = 60.0, w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", fs)
	_pbtn_style(b, kind)
	return b


func _btn_center(b: Button, row: Control) -> Button:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(row)
	b.add_child(cc)
	return b


func _pprice_btn(prefix: String, cost: int, kind: String = "primary", fs: int = 32, h: float = 64.0, w: float = 0.0) -> Button:
	var b := _pbtn("", kind, fs, h, w)
	var row := _h(10)
	var off: bool = kind == "off"
	if prefix != "":
		var pl := _lbl(prefix, fs, P("dim") if off else P("accent_text"))
		pl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45 if off else 0.0))
		row.add_child(pl)
	row.add_child(DK.ShardIcon.new(fs * 0.75, off))
	var cl := _lbl(str(cost), fs, P("bad") if off else P("accent_text"))
	cl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45 if off else 0.0))
	row.add_child(cl)
	return _btn_center(b, row)


## Satın alma: açık = SENDE, alınabilir = AÇ <fiyat> (ikinci basışta ONAYLA?), yetmiyor = pasif kırmızı fiyat.
func _pbuy(it: Dictionary, fs: int = 40, h: float = 80.0, w: float = 0.0) -> Button:
	var b: Button
	match _state(it):
		"open":
			b = _pbtn("SENDE", "off", fs, h, w)
			b.disabled = true
		"can":
			if _confirm_id == _id(it):
				b = _pbtn("ONAYLA?", "confirm", fs, h, w)
			else:
				b = _pprice_btn("AÇ", int(it["cost"]), "primary", fs, h, w)
			b.pressed.connect(_on_buy_pressed.bind(str(it["kind"]), it["key"]))
		_:
			b = _pprice_btn("AÇ", int(it["cost"]), "off", fs, h, w)
			b.disabled = true
	_tag_sid(b, "buy")
	return b


func _pupg_btn(id: String, fs: int = 40, h: float = 80.0, w: float = 0.0) -> Button:
	var b: Button
	if MetaUpgradesScript.level(id) >= MetaUpgradesScript.max_level(id):
		b = _pbtn("EN ÜST SEVİYE", "off", fs, h, w)
		b.disabled = true
	elif MetaUpgradesScript.can_buy(id):
		b = _pprice_btn("YÜKSELT", MetaUpgradesScript.next_cost(id), "primary", fs, h, w)
		b.pressed.connect(_on_upgrade_pressed.bind(id))
	else:
		b = _pprice_btn("YÜKSELT", MetaUpgradesScript.next_cost(id), "off", fs, h, w)
		b.disabled = true
	_tag_sid(b, "upg_buy")
	return b


func _pprice(it: Dictionary, fs: int = 32, center: bool = true) -> HBoxContainer:
	var h := _h(8)
	if center:
		h.alignment = BoxContainer.ALIGNMENT_CENTER
	match _state(it):
		"open":
			h.add_child(Glyph.new(G_CHECK, P("good"), 3 if fs < 32 else 4))
			h.add_child(_lbl("SENDE", fs, P("good")))
		"can":
			h.add_child(DK.ShardIcon.new(fs * 0.75))
			h.add_child(_lbl(str(it["cost"]), fs, P("price")))
		_:
			h.add_child(DK.ShardIcon.new(fs * 0.75, true))
			h.add_child(_lbl(str(it["cost"]), fs, P("bad")))
	return h


func _pback(t: String = "GERİ") -> Button:
	var b := _pbtn("", "ghost", 32, 56, 200)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := _h(12)
	row.add_child(Glyph.new(G_LEFT, P("text"), 4))
	row.add_child(_lbl(t, 32, P("text")))
	_btn_center(b, row)
	b.pressed.connect(_on_close_pressed)
	_tag_sid(b, "back")
	_close_btn = b
	return b


func _pbalance(boxed: bool = true) -> Control:
	var h := _h(12)
	h.add_child(DK.ShardIcon.new(32))
	var v := _v(-6)
	v.add_child(_lbl("Ruh Kıymığı", 24, P("dim")))
	_balance_label = _lbl(str(MetaProgressScript.shards()), 32, P("price"))
	v.add_child(_balance_label)
	h.add_child(v)
	h.add_child(_sp(8))
	_anim_nodes["chip"] = h
	if not boxed:
		return h
	var p := _box(P("inset"), P("line_hi"), 12)
	p.add_child(h)
	return p


func _pchip(it: Dictionary) -> PanelContainer:
	var st: String = _state(it)
	var bd: Color = P("line_hi")
	var txt: String = "%d KIYMIK EKSİK" % _need(it)
	var tc: Color = P("dim")
	if st == "can":
		bd = P("good")
		txt = "ŞİMDİ ALABİLİRSİN"
		tc = P("good")
	elif st == "open":
		bd = P("good")
		txt = "SENDE"
		tc = P("good")
	var p := _box(P("inset"), bd, 8, 3, 6)
	var h := _h(8)
	if st == "no":
		h.add_child(Glyph.new(G_LOCK, tc, 3))
	elif st == "open":
		h.add_child(Glyph.new(G_CHECK, tc, 3))
	else:
		h.add_child(DK.ShardIcon.new(20))
	h.add_child(_lbl(txt, 24, tc))
	p.add_child(h)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return p


## Yetenek satırları (kendi ikonu + köşede tuş harfi), desc_w > 0 ise altında açıklama (desc_lines satır).
func _pskills(it: Dictionary, fs: int = 32, desc_w: float = 0.0, box: float = 48.0, desc_lines: int = 2) -> VBoxContainer:
	var d: Dictionary = _char_def(it)
	var v := _v(10)
	for trio: Array in [["Q", "skill_name", "skill_icon", "skill_desc"], ["E", "skill2_name", "skill2_icon", "skill2_desc"],
			["R", "skill3_name", "skill3_icon", "skill3_desc"]]:
		var h := _h(14)
		var ip: String = str(d.get(trio[2], ""))
		var slot := _box(P("inset"), P("line_hi"), 0, 3, 4)
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if ip != "" and ResourceLoader.exists(ip):
			slot.add_child(_icon(load(ip) as Texture2D, box))
			var key := _lbl(trio[0], 24, P("accent"), HORIZONTAL_ALIGNMENT_CENTER)
			key.size_flags_horizontal = Control.SIZE_SHRINK_END
			key.size_flags_vertical = Control.SIZE_SHRINK_END
			key.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
			slot.add_child(key)
		else:
			var key2 := _lbl(trio[0], 32, P("accent"), HORIZONTAL_ALIGNMENT_CENTER)
			key2.custom_minimum_size = Vector2(box, box)
			slot.add_child(key2)
		h.add_child(slot)
		var tv := _v(0)
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		tv.add_child(_lbl(str(d.get(trio[1], "")), fs, P("text")))
		if desc_w > 0.0:
			var ds: String = str(d.get(trio[3], ""))
			for pre: String in ["YETENEK: ", "TEMEL: ", "ULTİ: ", "ULTI: "]:
				ds = ds.trim_prefix(pre)
			tv.add_child(_wrap(ds, 24, P("dim"), desc_w, desc_lines))
		h.add_child(tv)
		v.add_child(h)
	return v


func _pstats(it: Dictionary, fs: int = 24, cols: int = 2) -> GridContainer:
	var bs: Dictionary = Characters.get_base_stats(int(it["key"]))
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 6)
	var atk: int = int(bs.get("atk", 0))
	for row: Array in [["max_health", "Can", str(int(bs.get("hp", 100)))], ["speed", "Hız", str(int(bs.get("speed", 252)))],
			["damage", "Saldırı Gücü", str(int(bs.get("ap", 10)))], ["fire_rate", "Saldırı Hızı", ("%+d%%" % atk) if atk != 0 else "0"]]:
		var h := _h(8)
		h.add_child(_icon(_stat_tex(row[0]), 32))
		h.add_child(_lbl(row[1], fs, P("dim")))
		h.add_child(_lbl(row[2], fs, P("text")))
		g.add_child(h)
	return g


## Öğenin açıklama bloğu: karakterde yetenekler (+ statlar), diğerlerinde metin.
func _pdesc(it: Dictionary, fs: int, desc_w: float, skill_desc: bool, max_lines: int = 4) -> Control:
	if it["kind"] == MetaProgressScript.CHAR:
		var v := _v(16)
		v.add_child(_pskills(it, fs, desc_w if skill_desc else 0.0))
		v.add_child(_pstats(it, 24, 2))
		return v
	return _wrap(str(it["desc"]), fs, P("dim"), desc_w, max_lines)


func _upg_values(d: Dictionary) -> HBoxContainer:
	var id: String = str(d["id"])
	var lv: int = MetaUpgradesScript.level(id)
	var mx: int = MetaUpgradesScript.max_level(id)
	var per: float = float(d.get("per", 0.0))
	var h := _h(12)
	h.add_child(_lbl("Şu an", 24, P("dim")))
	h.add_child(_lbl(MetaUpgradesScript.format_value(id, per * lv) if lv > 0 else "-", 32, P("text")))
	if lv < mx:
		h.add_child(_sp(10))
		h.add_child(Glyph.new(G_RIGHT, P("accent"), 4))
		h.add_child(_sp(10))
		h.add_child(_lbl("Sonraki", 24, P("dim")))
		h.add_child(_lbl(MetaUpgradesScript.format_value(id, per * (lv + 1)), 32, P("good")))
	return h


func _stage_box(it: Dictionary, h: float, max_fig: float, floor_off: float, fill: Color) -> PanelContainer:
	var st := _box(fill, Color(0, 0, 0, 0), 0, 0, 8)
	st.custom_minimum_size.y = h
	st.clip_contents = true
	st.add_child(StageBg.new(P("spot"), P("accent"), floor_off))
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(hold)
	_anim_nodes["stage"] = st
	if it.has("max"): ## geliştirme tanımı
		_stage_upgrade(hold, it, max_fig, floor_off)
	else:
		var spr: TextureRect = _stage_figure(hold, _with_tex(it), max_fig if it["kind"] == MetaProgressScript.CHAR else max_fig * 0.55, floor_off)
		if spr != null:
			_anim_nodes["figure"] = spr
	return st


func _stage_upgrade(hold: Control, d: Dictionary, box: float, floor_off: float) -> void:
	var ic: Control = _upg_icon(d, box)
	ic.anchor_left = 0.5
	ic.anchor_right = 0.5
	ic.anchor_top = 1.0
	ic.anchor_bottom = 1.0
	ic.offset_left = -floorf(box * 0.5)
	ic.offset_right = floorf(box * 0.5)
	ic.offset_top = -floor_off - 24.0 - box
	ic.offset_bottom = -floor_off - 24.0
	hold.add_child(ic)


## ================================================================ A - SEKMELİ TEZGÂH
const A_DETAIL_W := 640.0


func _a_build(page: String) -> void:
	var items: Array = _items()
	_page_box.add_child(_a_header(items, page))
	var body := _h(24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(body)
	var left := _box(Color(P("panel"), 0.95), P("line"), 24, 2, 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_anim_nodes["center"] = left
	body.add_child(left)
	var right := _box(Color(P("panel"), 0.95), P("line"), 24, 2, 8)
	right.custom_minimum_size.x = A_DETAIL_W
	_anim_nodes["info"] = right
	body.add_child(right)
	if page == PAGE_UPGRADES:
		left.add_child(_a_upg_grid())
		right.add_child(_a_upg_detail(_upg_selected()))
	else:
		left.add_child(_a_grid(items, page))
		right.add_child(_a_detail(_selected(items, page)))


func _a_header(items: Array, page: String) -> Control:
	var h := _h(0)
	h.custom_minimum_size.y = 72
	var l := _h(0)
	l.custom_minimum_size.x = 300
	l.add_child(_pback())
	h.add_child(l)
	var mid := CenterContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := _box(Color(P("inset"), 0.92), P("line"), 0, 2, 8)
	var sbm := bar.get_theme_stylebox("panel") as StyleBoxFlat
	sbm.content_margin_left = 24
	sbm.content_margin_right = 24
	sbm.content_margin_top = 4
	var tabs := _h(36)
	for k: String in SECTIONS:
		tabs.add_child(_a_tab(items, k, k == page))
	bar.add_child(tabs)
	mid.add_child(bar)
	h.add_child(mid)
	var r := _h(0)
	r.custom_minimum_size.x = 300
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(_pbalance())
	h.add_child(r)
	_anim_nodes["topbar"] = h
	return h


func _a_tab(items: Array, kind: String, on: bool) -> Control:
	var p := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0)
	var v := _v(8)
	v.add_child(_sp(0, 4))
	var row := _h(10)
	row.add_child(_tab_icon(items, kind, 40))
	row.add_child(_lbl(_sec_name(kind), 32, P("accent") if on else P("dim")))
	var n: int = _can_n(items, kind)
	if n > 0 and not on: ## kaç tanesi alınabilir: küçük yeşil rozet
		var pill := _box(Color(P("good"), 0.16), Color(0, 0, 0, 0), 4, 0, 4)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pill.add_child(_lbl(str(n), 24, P("good")))
		row.add_child(pill)
	v.add_child(row)
	var ul := ColorRect.new()
	ul.color = P("accent") if on else Color(0, 0, 0, 0)
	ul.custom_minimum_size.y = 4
	ul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ul)
	p.add_child(v)
	_clickable(p, _on_tab_pressed.bind(kind), "tab:" + kind)
	return p


func _a_grid(items: Array, kind: String) -> Control:
	var list: Array = _by_cost(items, kind)
	var sel: Dictionary = _selected(items, kind)
	var v := _v(18)
	var hh := _h(12)
	hh.add_child(_lbl(_sec_title(kind), 40, P("text")))
	hh.add_child(_sp(0, 0, true))
	var c: Vector2i = _counts(items, kind)
	hh.add_child(_lbl("%d / %d açık" % [c.x, c.y], 24, P("dim")))
	v.add_child(hh)
	var cols: int = 5
	var rows: int = maxi(1, ceili(float(list.size()) / cols))
	var tile_w: float = floorf((1856.0 - 24.0 - A_DETAIL_W - 52.0 - (cols - 1) * 16.0) / cols)
	var tile_h: float = minf(400.0, floorf((830.0 - (rows - 1) * 16.0) / rows))
	var k: float = _char_k(list, tile_h - 70.0, tile_w - 40.0)
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 16)
	for it: Dictionary in list:
		g.add_child(_a_tile(it, _id(it) == _id(sel), tile_w, tile_h, k))
	v.add_child(g)
	return v


func _a_tile(it: Dictionary, on: bool, w: float, h: float, k: float) -> Control:
	var st: String = _state(it)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(P("inset"), P("accent") if on else Color(0, 0, 0, 0), 3, 6, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(w, h)
	var v := _v(0)
	var tex: Texture2D = _tex_of(it)
	if it["kind"] == MetaProgressScript.CHAR:
		var hold := Control.new()
		hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hold.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if tex != null:
			hold.add_child(_fig_sprite(tex, k, 4.0, st == "no"))
		v.add_child(hold)
	else:
		var cc: CenterContainer = _center_tex(tex, minf(h - 90.0, w - 50.0), st == "no")
		cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(cc)
	var pr: HBoxContainer = _pprice(it, 24)
	pr.custom_minimum_size.y = 44
	v.add_child(pr)
	p.add_child(v)
	_clickable(p, _select.bind(it), "item:" + _id(it))
	_anim_list("cards").append(p)
	return p


func _a_detail(it: Dictionary) -> Control:
	var v := _v(14)
	if it.is_empty():
		return v
	v.add_child(_stage_box(it, 340.0, 290.0, 64.0, P("inset")))
	var nh := _h(12)
	nh.add_child(_lbl(str(it["name"]), 48, P("text")))
	nh.add_child(_sp(0, 0, true))
	nh.add_child(_lbl(str(KIND_LOWER.get(it["kind"], "")), 24, P("dim")))
	v.add_child(nh)
	v.add_child(_pdesc(it, 32, A_DETAIL_W - 140.0, true))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_pbuy(it, 40, 80))
	return v


func _a_upg_grid() -> Control:
	var v := _v(18)
	var hh := _h(12)
	hh.add_child(_lbl("GELİŞTİRMELER", 40, P("text")))
	hh.add_child(_lbl("her koşuda geçerli", 24, P("dim")))
	hh.add_child(_sp(0, 0, true))
	var lv: Vector2i = _upg_levels()
	hh.add_child(_lbl("%d / %d seviye" % [lv.x, lv.y], 24, P("dim")))
	v.add_child(hh)
	var sel: String = str(_upg_selected()["id"])
	var cols: int = 5
	var tile_w: float = floorf((1856.0 - 24.0 - A_DETAIL_W - 52.0 - (cols - 1) * 16.0) / cols)
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 16)
	for d: Dictionary in MetaUpgradesScript.LIST:
		var id: String = str(d["id"])
		var l: int = MetaUpgradesScript.level(id)
		var mx: int = MetaUpgradesScript.max_level(id)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _sb(P("inset"), P("accent") if id == sel else Color(0, 0, 0, 0), 3, 6, 12))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.custom_minimum_size = Vector2(tile_w, 184)
		var tv := _v(8)
		tv.add_child(_upg_icon(d, 64))
		var nl := _lbl(str(d["name"]), 24, P("text"), HORIZONTAL_ALIGNMENT_CENTER)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size.x = 10
		tv.add_child(nl)
		tv.add_child(Pips.new(mx, l, P("accent") if l < mx else P("good"), P("panel2"), 8.0))
		tv.add_child(_lbl("%d / %d" % [l, mx], 24, P("good") if l >= mx else P("dim"), HORIZONTAL_ALIGNMENT_CENTER))
		p.add_child(tv)
		_clickable(p, _select_upg.bind(id), "upg:" + id)
		_anim_list("cards").append(p)
		g.add_child(p)
	v.add_child(g)
	return v


func _a_upg_detail(d: Dictionary) -> Control:
	var id: String = str(d["id"])
	var lv: int = MetaUpgradesScript.level(id)
	var mx: int = MetaUpgradesScript.max_level(id)
	var v := _v(16)
	v.add_child(_stage_box(d, 300.0, 192.0, 60.0, P("inset")))
	v.add_child(_lbl(str(d["name"]), 48, P("text")))
	v.add_child(_wrap(str(d["desc"]), 32, P("dim"), A_DETAIL_W - 60.0, 3))
	var lh := _h(12)
	lh.add_child(_lbl("SEVİYE", 24, P("dim")))
	lh.add_child(_sp(0, 0, true))
	lh.add_child(_lbl("%d / %d" % [lv, mx], 32, P("accent")))
	v.add_child(lh)
	v.add_child(Pips.new(mx, lv, P("accent"), P("inset"), 16.0))
	v.add_child(_upg_values(d))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_pupg_btn(id, 40, 80))
	var rb := _pbtn("ONAYLA?" if _confirm_id == "reset" else "Hepsini sıfırla", "danger" if _confirm_id == "reset" else "ghost", 24, 44)
	rb.pressed.connect(_on_reset_pressed)
	_tag_sid(rb, "reset")
	v.add_child(rb)
	return v


## ================================================================ B - VİTRİN ODASI
func _b_build(page: String) -> void:
	var items: Array = _items()
	_page_box.add_child(_b_header(items, page))
	var body := _h(0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(body)
	body.add_child(_sp(170)) ## sahne odanın sol alt köşesindeki lambadan uzak dursun
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stage)
	var info := _box(Color(0.04, 0.03, 0.02, 0.62), Color(0, 0, 0, 0), 32, 0, 10)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_anim_nodes["info"] = info
	body.add_child(info)
	var film := _h(12)
	film.alignment = BoxContainer.ALIGNMENT_CENTER
	film.custom_minimum_size.y = 132
	_page_box.add_child(film)
	if page == PAGE_UPGRADES:
		var d: Dictionary = _upg_selected()
		_b_stage(stage, d, page)
		info.add_child(_b_upg_info(d))
		for u: Dictionary in MetaUpgradesScript.LIST:
			film.add_child(_b_upg_thumb(u, str(u["id"]) == str(d["id"])))
	else:
		var it: Dictionary = _selected(items, page)
		_b_stage(stage, it, page)
		info.add_child(_b_info(it))
		for x: Dictionary in _by_cost(items, page):
			film.add_child(_b_thumb(x, _id(x) == _id(it)))


func _b_header(items: Array, page: String) -> Control:
	var h := _h(0)
	h.custom_minimum_size.y = 120
	var l := _h(0)
	l.custom_minimum_size.x = 300
	l.alignment = BoxContainer.ALIGNMENT_BEGIN
	var back: Button = _pback()
	back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	l.add_child(back)
	h.add_child(l)
	var tabs := _h(18)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k: String in SECTIONS:
		var on: bool = k == page
		var tv := _v(4)
		var p := _box(P("panel2") if on else Color(P("inset"), 0.85), P("accent") if on else P("line"), 10, 3, 8)
		p.add_child(_tab_icon(items, k, 56))
		tv.add_child(p)
		var tl := _lbl(_sec_name(k) if on else "", 24, P("accent"), HORIZONTAL_ALIGNMENT_CENTER)
		tl.custom_minimum_size.x = 80
		tv.add_child(tl)
		_clickable(p, _on_tab_pressed.bind(k), "tab:" + k)
		tabs.add_child(tv)
	h.add_child(tabs)
	var r := _h(0)
	r.custom_minimum_size.x = 300
	r.alignment = BoxContainer.ALIGNMENT_END
	var bal: Control = _pbalance()
	bal.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	r.add_child(bal)
	h.add_child(r)
	_anim_nodes["topbar"] = h
	return h


## Sahne: odanın zemininde spot (panel yok) + figür + yanlarda gezinme okları.
func _b_stage(stage: Control, it: Dictionary, page: String) -> void:
	var sb := StageBg.new(P("spot"), P("accent"), 70.0)
	sb.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(sb)
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.add_child(hold)
	if it.is_empty():
		return
	if page == PAGE_UPGRADES:
		_stage_upgrade(hold, it, 240.0, 70.0)
	else:
		var spr: TextureRect = _stage_figure(hold, _with_tex(it), 400.0 if page == MetaProgressScript.CHAR else 260.0, 70.0)
		if spr != null:
			_anim_nodes["figure"] = spr
	for side: int in [-1, 1]:
		var b := _pbtn("", "ghost", 32, 96, 64)
		var g := Glyph.new(G_LEFT if side < 0 else G_RIGHT, P("text"), 6)
		_btn_center(b, g)
		b.anchor_top = 0.5
		b.anchor_bottom = 0.5
		b.anchor_left = 0.0 if side < 0 else 1.0
		b.anchor_right = b.anchor_left
		b.offset_top = -80
		b.offset_bottom = 16
		b.offset_left = 24.0 if side < 0 else -88.0
		b.offset_right = b.offset_left + 64.0
		if page == PAGE_UPGRADES:
			b.pressed.connect(_b_step_upg.bind(side))
		else:
			b.pressed.connect(_step_selection.bind(page, side))
		_tag_sid(b, "step%d" % side)
		stage.add_child(b)


func _b_step_upg(dir: int) -> void:
	var ids: Array = MetaUpgradesScript.ids()
	var i: int = maxi(0, ids.find(str(_upg_selected()["id"])))
	_select_upg(str(ids[posmod(i + dir, ids.size())]))


func _b_info(it: Dictionary) -> Control:
	var v := _v(14)
	if it.is_empty():
		return v
	v.add_child(_pchip(it))
	v.add_child(_lbl(str(it["name"]), 72, P("text")))
	v.add_child(_lbl(str(KIND_LOWER.get(it["kind"], "")), 32, P("dim")))
	v.add_child(_sp(0, 6))
	v.add_child(_pdesc(it, 32, 600.0, true, 6))
	v.add_child(_sp(0, 0, false, true))
	var bb: Button = _pbuy(it, 40, 84)
	v.add_child(bb)
	return v


func _b_upg_info(d: Dictionary) -> Control:
	var id: String = str(d["id"])
	var lv: int = MetaUpgradesScript.level(id)
	var mx: int = MetaUpgradesScript.max_level(id)
	var v := _v(16)
	v.add_child(_lbl("KALICI GELİŞTİRME", 24, P("accent")))
	v.add_child(_lbl(str(d["name"]), 72, P("text")))
	v.add_child(_wrap(str(d["desc"]), 32, P("dim"), 620.0, 3))
	v.add_child(_sp(0, 10))
	var lh := _h(12)
	lh.add_child(_lbl("SEVİYE", 24, P("dim")))
	lh.add_child(_sp(0, 0, true))
	lh.add_child(_lbl("%d / %d" % [lv, mx], 32, P("accent")))
	v.add_child(lh)
	v.add_child(Pips.new(mx, lv, P("accent"), P("inset"), 18.0))
	v.add_child(_upg_values(d))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_pupg_btn(id, 40, 84))
	return v


func _b_thumb(it: Dictionary, on: bool) -> Control:
	var st: String = _state(it)
	var p := _box(P("panel2") if on else Color(P("inset"), 0.85), P("accent") if on else Color(0, 0, 0, 0), 6, 3, 6)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cc: Control = _icon(_small_tex(it), 96.0 if on else 72.0, st == "no")
	p.add_child(cc)
	if st == "open":
		var g := Glyph.new(G_CHECK, P("good"), 3)
		g.size_flags_horizontal = Control.SIZE_SHRINK_END
		g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		p.add_child(g)
	_clickable(p, _select.bind(it), "thumb:" + _id(it))
	_anim_list("cards").append(p)
	return p


func _b_upg_thumb(d: Dictionary, on: bool) -> Control:
	var id: String = str(d["id"])
	var lv: int = MetaUpgradesScript.level(id)
	var mx: int = MetaUpgradesScript.max_level(id)
	var v := _v(6)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var p := _box(P("panel2") if on else Color(P("inset"), 0.85), P("accent") if on else Color(0, 0, 0, 0), 4, 3, 6)
	p.add_child(_upg_icon(d, 64.0 if on else 48.0))
	v.add_child(p)
	v.add_child(Bar.new(float(lv) / float(maxi(1, mx)), P("accent") if lv < mx else P("good"), P("inset"), 8.0))
	_clickable(p, _select_upg.bind(id), "thumb:" + id)
	_anim_list("cards").append(v)
	return v


## ================================================================ C - OCAK BAŞI DEFTERİ (Ateş Işığı)
func _c_build(page: String) -> void:
	var items: Array = _items()
	var hd := _h(16)
	hd.custom_minimum_size.y = 96
	var t := _lbl("RUH MAĞAZASI", 64, P("accent"))
	t.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 1))
	t.add_theme_constant_override("outline_size", 10)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("shadow_offset_y", 5)
	hd.add_child(_sp(16))
	hd.add_child(t)
	hd.add_child(_sp(0, 0, true))
	var bal := _h(12)
	bal.add_child(DK.ShardIcon.new(44))
	_balance_label = FM.lbl(str(MetaProgressScript.shards()), 56, P("price"))
	bal.add_child(_balance_label)
	_anim_nodes["chip"] = bal
	hd.add_child(bal)
	hd.add_child(_sp(16))
	_anim_nodes["topbar"] = hd
	_page_box.add_child(hd)
	var body := _h(28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(body)
	## 1. sütun: bölümler (ana menü / ESC menüsü öğeleri)
	var c1 := _v(0)
	c1.custom_minimum_size.x = FM.COL_W
	for k: String in SECTIONS:
		var c: Vector2i = _counts(items, k)
		var n: int = _can_n(items, k)
		var sub: String = ("%d/%d seviye" if k == PAGE_UPGRADES else "%d/%d açık") % [c.x, c.y]
		if n > 0:
			sub += ", %d %s" % [n, "yükseltilebilir" if k == PAGE_UPGRADES else "alınabilir"]
		var b: Button = FM.item(_sec_name(k), sub, _tab_icon(items, k, 48), false, false)
		FM.set_selected(b, k == page)
		b.pressed.connect(_on_tab_pressed.bind(k))
		_tag_sid(b, "tab:" + k)
		c1.add_child(b)
	c1.add_child(_sp(0, 0, false, true))
	var back: Button = FM.item("Geri", "Ana menüye dön", Glyph.new(G_LEFT, P("dim"), 5), false, false)
	back.pressed.connect(_on_close_pressed)
	_tag_sid(back, "back")
	_close_btn = back
	c1.add_child(back)
	body.add_child(c1)
	## 2. sütun: yazı listesi
	var c2 := _v(6)
	c2.custom_minimum_size.x = 600
	_anim_nodes["center"] = c2
	var th := _h(12)
	th.add_child(FM.lbl(_sec_title(page), 40, P("text")))
	th.add_child(_sp(0, 0, true))
	var cc: Vector2i = _counts(items, page)
	th.add_child(_lbl(("%d / %d seviye" if page == PAGE_UPGRADES else "%d / %d açık") % [cc.x, cc.y], 24, P("dim")))
	c2.add_child(th)
	var ln := ColorRect.new()
	ln.color = P("line_hi")
	ln.custom_minimum_size.y = 3
	c2.add_child(ln)
	c2.add_child(_sp(0, 4))
	if page == PAGE_UPGRADES:
		var sel: String = str(_upg_selected()["id"])
		for d: Dictionary in MetaUpgradesScript.LIST:
			c2.add_child(_c_upg_row(d, str(d["id"]) == sel))
	else:
		var it_sel: Dictionary = _selected(items, page)
		var list: Array = _by_cost(items, page)
		var row_h: float = clampf(floorf(800.0 / maxf(1.0, float(list.size()))) - 6.0, 44.0, 72.0)
		for it: Dictionary in list:
			c2.add_child(_c_row(it, _id(it) == _id(it_sel), row_h))
	body.add_child(c2)
	## 3. sütun: ayrıntı (sahnenin üstünde yumuşak koyu zemin)
	var c3 := _box(P("panel"), Color(0, 0, 0, 0), 32, 0, 10)
	c3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_anim_nodes["info"] = c3
	if page == PAGE_UPGRADES:
		c3.add_child(_c_upg_detail(_upg_selected()))
	else:
		c3.add_child(_c_detail(_selected(items, page)))
	body.add_child(c3)


func _c_row(it: Dictionary, on: bool, row_h: float) -> Control:
	var st: String = _state(it)
	var p := _box(Color(P("accent"), 0.10) if on else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4)
	p.custom_minimum_size.y = row_h
	var h := _h(14)
	var mk := ColorRect.new()
	mk.color = P("accent") if on else Color(0, 0, 0, 0)
	mk.custom_minimum_size.x = 5
	mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(mk)
	h.add_child(_icon(_small_tex(it), minf(48.0, row_h - 8.0), st == "no"))
	var nl := FM.lbl(str(it["name"]), 32, P("accent") if on else (P("dim") if st == "no" else P("text")))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nl)
	h.add_child(_pprice(it, 32, false))
	h.add_child(_sp(10))
	p.add_child(h)
	_clickable(p, _select.bind(it), "row:" + _id(it))
	_anim_list("rows").append(p)
	return p


func _c_upg_row(d: Dictionary, on: bool) -> Control:
	var id: String = str(d["id"])
	var lv: int = MetaUpgradesScript.level(id)
	var mx: int = MetaUpgradesScript.max_level(id)
	var p := _box(Color(P("accent"), 0.10) if on else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4)
	p.custom_minimum_size.y = 34
	var h := _h(12)
	var mk := ColorRect.new()
	mk.color = P("accent") if on else Color(0, 0, 0, 0)
	mk.custom_minimum_size.x = 5
	mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(mk)
	h.add_child(_upg_icon(d, 32))
	var nl := FM.lbl(str(d["name"]), 24, P("accent") if on else P("text"))
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nl)
	var pp := Pips.new(mx, lv, P("accent") if lv < mx else P("good"), P("inset"), 8.0)
	pp.custom_minimum_size.x = 150
	pp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pp)
	var lvl := _lbl("%d/%d" % [lv, mx], 24, P("good") if lv >= mx else P("dim"), HORIZONTAL_ALIGNMENT_RIGHT)
	lvl.custom_minimum_size.x = 60
	h.add_child(lvl)
	h.add_child(_sp(8))
	p.add_child(h)
	_clickable(p, _select_upg.bind(id), "row:" + id)
	_anim_list("rows").append(p)
	return p


func _c_detail(it: Dictionary) -> Control:
	var v := _v(14)
	if it.is_empty():
		return v
	v.add_child(_stage_box(it, 280.0, 250.0, 50.0, Color(0, 0, 0, 0)))
	var nl := FM.lbl(str(it["name"]), 56, P("accent"))
	nl.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.04, 1))
	nl.add_theme_constant_override("outline_size", 6)
	v.add_child(nl)
	v.add_child(_lbl(str(KIND_LOWER.get(it["kind"], "")), 24, P("dim")))
	v.add_child(_pdesc(it, 32, 470.0, true, 5))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_pbuy(it, 40, 76))
	return v


func _c_upg_detail(d: Dictionary) -> Control:
	var id: String = str(d["id"])
	var lv: int = MetaUpgradesScript.level(id)
	var mx: int = MetaUpgradesScript.max_level(id)
	var v := _v(16)
	v.add_child(_stage_box(d, 260.0, 160.0, 50.0, Color(0, 0, 0, 0)))
	var nl := FM.lbl(str(d["name"]), 56, P("accent"))
	nl.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.04, 1))
	nl.add_theme_constant_override("outline_size", 6)
	v.add_child(nl)
	v.add_child(_wrap(str(d["desc"]), 32, P("dim"), 470.0, 3))
	var lh := _h(12)
	lh.add_child(_lbl("SEVİYE", 24, P("dim")))
	lh.add_child(_sp(0, 0, true))
	lh.add_child(_lbl("%d / %d" % [lv, mx], 32, P("accent")))
	v.add_child(lh)
	v.add_child(Pips.new(mx, lv, P("accent"), P("inset"), 14.0))
	v.add_child(_upg_values(d))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_pupg_btn(id, 40, 76))
	return v


## ================================================================ D - KART MASASI (Gece Sıvası)
func _d_build(page: String) -> void:
	var items: Array = _items()
	_page_box.add_child(_d_header(page))
	if page == PAGE_UPGRADES:
		_page_box.add_child(_d_upg_grid())
		return
	var list: Array = _by_cost(items, page)
	var pages: int = maxi(1, ceili(float(list.size()) / D_PER_PAGE))
	var pg: int = clampi(int(_d_pages.get(page, 0)), 0, pages - 1)
	var sel: Dictionary = _selected(items, page)
	var body := _h(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_box.add_child(body)
	body.add_child(_d_arrow(page, -1, pg > 0))
	var row := _h(24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown: Array = list.slice(pg * D_PER_PAGE, mini(list.size(), (pg + 1) * D_PER_PAGE))
	var card_w: float = floorf((1856.0 - 2.0 * 84.0 - 40.0 - 4.0 * 24.0) / D_PER_PAGE)
	var k: float = _char_k(list, 340.0, card_w - 60.0)
	for it: Dictionary in shown:
		row.add_child(_d_card(it, _id(it) == _id(sel) and not modal_open, card_w, k))
	body.add_child(row)
	body.add_child(_d_arrow(page, 1, pg < pages - 1))
	## sayfa noktaları
	var dots := _h(12)
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.custom_minimum_size.y = 40
	for i in pages:
		var r := ColorRect.new()
		r.color = P("accent") if i == pg else P("line_hi")
		r.custom_minimum_size = Vector2(28 if i == pg else 12, 12)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(r)
	dots.add_child(_sp(12))
	dots.add_child(_lbl("%d - %d / %d" % [pg * D_PER_PAGE + 1, pg * D_PER_PAGE + shown.size(), list.size()], 24, P("dim")))
	_page_box.add_child(dots)
	if modal_open and not sel.is_empty():
		_d_modal(sel)


func _d_header(page: String) -> Control:
	var h := _h(0)
	h.custom_minimum_size.y = 72
	var l := _h(0)
	l.custom_minimum_size.x = 300
	l.add_child(_pback())
	h.add_child(l)
	var seg := _h(8)
	seg.alignment = BoxContainer.ALIGNMENT_CENTER
	seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k: String in SECTIONS:
		var on: bool = k == page
		var b := Button.new()
		b.text = _sec_name(k)
		b.add_theme_font_size_override("font_size", 32)
		b.custom_minimum_size = Vector2(0, 56)
		for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var sb := _sb(P("panel3") if on else (P("panel2").lightened(0.06) if st == "hover" else P("panel2")), P("accent") if on else P("line"), 3, 6, 18.0)
			if st == "focus":
				sb = _sb(Color(0, 0, 0, 0), P("text"), 3, 6, 18.0)
			b.add_theme_stylebox_override(st, sb)
		for fc: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(fc, P("accent") if on else P("dim"))
		b.pressed.connect(_on_tab_pressed.bind(k))
		_tag_sid(b, "tab:" + k)
		seg.add_child(b)
	h.add_child(seg)
	var r := _h(0)
	r.custom_minimum_size.x = 300
	r.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(_pbalance())
	h.add_child(r)
	_anim_nodes["topbar"] = h
	return h


func _d_arrow(page: String, dir: int, enabled: bool) -> Button:
	var b := _pbtn("", "ghost" if enabled else "off", 32, 160, 64)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not enabled
	_btn_center(b, Glyph.new(G_LEFT if dir < 0 else G_RIGHT, P("text") if enabled else P("line_hi"), 6))
	b.pressed.connect(func() -> void:
		_d_pages[page] = int(_d_pages.get(page, 0)) + dir
		_anim_page_in = true
		_rebuild_list())
	_tag_sid(b, "page%d" % dir)
	return b


func _d_card(it: Dictionary, lifted: bool, w: float, k: float) -> Control:
	var st: String = _state(it)
	var wrap := MarginContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_theme_constant_override("margin_top", 0 if lifted else 16)
	wrap.add_theme_constant_override("margin_bottom", 16 if lifted else 0)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(P("panel2"), P("accent") if lifted else P("line"), 3, 10, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(w, 660)
	var v := _v(0)
	## sanat alanı: küçük sahne
	var art := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.clip_contents = true
	art.add_child(StageBg.new(P("spot"), P("accent") if st != "no" else P("line_hi"), 40.0))
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(hold)
	var tex: Texture2D = _tex_of(it)
	if tex != null:
		if it["kind"] == MetaProgressScript.CHAR:
			hold.add_child(_fig_sprite(tex, k, 32.0, st == "no"))
		else:
			hold.add_child(_fig_sprite(tex, _fit_k(tex, minf(200.0, w - 80.0)), 70.0, st == "no"))
	v.add_child(art)
	## ad + kısa satır
	var nb := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 14, 0, 0)
	var nv := _v(8)
	nv.add_child(_lbl(str(it["name"]), 40, P("text") if st != "no" else P("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	if it["kind"] == MetaProgressScript.CHAR:
		var sk := _h(10)
		sk.alignment = BoxContainer.ALIGNMENT_CENTER
		var d: Dictionary = _char_def(it)
		for key: String in ["skill_icon", "skill2_icon", "skill3_icon"]:
			var ip: String = str(d.get(key, ""))
			var s := _box(P("inset"), P("line"), 0, 3, 4)
			if ip != "" and ResourceLoader.exists(ip):
				s.add_child(_icon(load(ip) as Texture2D, 40, st == "no"))
			else:
				s.add_child(_lbl("R", 24, P("accent"), HORIZONTAL_ALIGNMENT_CENTER))
				s.custom_minimum_size = Vector2(40, 40)
			sk.add_child(s)
		nv.add_child(sk)
	else:
		nv.add_child(_lbl(str(KIND_LOWER.get(it["kind"], "")), 24, P("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	nb.add_child(nv)
	v.add_child(nb)
	## fiyat bandı
	var band := _box(P("inset"), Color(0, 0, 0, 0), 14, 0, 8)
	band.add_child(_pprice(it, 32))
	v.add_child(band)
	p.add_child(v)
	wrap.add_child(p)
	_clickable(p, _d_open.bind(it), "card:" + _id(it))
	_anim_list("cards").append(wrap)
	return wrap


func _d_open(it: Dictionary) -> void:
	_sel[str(it["kind"])] = it["key"]
	_confirm_id = ""
	modal_open = true
	_rebuild_list()


func _d_close() -> void:
	modal_open = false
	_confirm_id = ""
	_rebuild_list()


func _d_modal(it: Dictionary) -> void:
	var root := _page_box.get_parent().get_parent() as Control
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cc)
	var win := _box(P("panel2"), P("line_hi"), 28, 3, 10)
	win.custom_minimum_size = Vector2(1240, 720)
	var h := _h(32)
	h.add_child(_d_modal_stage(it))
	var v := _v(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_pchip(it))
	v.add_child(_lbl(str(it["name"]), 64, P("text")))
	v.add_child(_lbl(str(KIND_LOWER.get(it["kind"], "")), 24, P("dim")))
	v.add_child(_pdesc(it, 32, 560.0, true, 6))
	v.add_child(_sp(0, 0, false, true))
	var br := _h(16)
	var cb := _pbtn("KAPAT", "ghost", 32, 80, 200)
	cb.pressed.connect(_d_close)
	_tag_sid(cb, "close")
	br.add_child(cb)
	var bb: Button = _pbuy(it, 40, 80)
	bb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(bb)
	v.add_child(br)
	h.add_child(v)
	win.add_child(h)
	cc.add_child(win)
	root.add_child(ov)
	_overlay = ov
	UiAnim.reveal(win, 0.0, 0.16)


func _d_modal_stage(it: Dictionary) -> Control:
	var st := _stage_box(it, 0.0, 420.0, 70.0, P("inset"))
	st.custom_minimum_size.x = 480
	return st


func _d_upg_grid() -> Control:
	var g := GridContainer.new()
	g.columns = 5
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 20)
	g.add_theme_constant_override("v_separation", 20)
	var w: float = floorf((1856.0 - 4.0 * 20.0) / 5.0)
	var sel: String = str(_upg_selected()["id"])
	for d: Dictionary in MetaUpgradesScript.LIST:
		var id: String = str(d["id"])
		var lv: int = MetaUpgradesScript.level(id)
		var mx: int = MetaUpgradesScript.max_level(id)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _sb(P("panel2"), P("accent") if id == sel else P("line"), 3, 10, 16))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.custom_minimum_size = Vector2(w, 196)
		var v := _v(10)
		var top := _h(14)
		var s := _box(P("inset"), P("line"), 6, 3, 6)
		s.add_child(_upg_icon(d, 64))
		top.add_child(s)
		var tv := _v(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.alignment = BoxContainer.ALIGNMENT_CENTER
		var nl := _lbl(str(d["name"]), 32, P("text"))
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size.x = 10
		tv.add_child(nl)
		tv.add_child(_lbl("Seviye %d / %d" % [lv, mx], 24, P("good") if lv >= mx else P("dim")))
		top.add_child(tv)
		v.add_child(top)
		v.add_child(Pips.new(mx, lv, P("accent") if lv < mx else P("good"), P("inset"), 10.0))
		var f := _h(8)
		f.add_child(_sp(0, 0, true))
		if lv >= mx:
			f.add_child(_lbl("EN ÜST", 24, P("good")))
		else:
			var can: bool = MetaUpgradesScript.can_buy(id)
			f.add_child(DK.ShardIcon.new(20, not can))
			f.add_child(_lbl(str(MetaUpgradesScript.next_cost(id)), 32, P("price") if can else P("bad")))
		v.add_child(f)
		p.add_child(v)
		_clickable(p, _on_upgrade_pressed.bind(id), "upg:" + id)
		_anim_list("cards").append(p)
		g.add_child(p)
	return g
