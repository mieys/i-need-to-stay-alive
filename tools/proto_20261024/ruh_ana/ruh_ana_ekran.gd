extends "res://scripts/soul_shop_screen.gd"

## Ruh Mağazası ANA EKRAN prototipleri (2026-10-24, oyuna bağlı DEĞİL). Gerçek soul_shop_screen.gd'den türer: tema, renkler, yazı,
## arka plan, üst şerit, düğmeler, kategori/geliştirme sayfaları AYNI; sadece _build_home() yerleşimi değişir.
##   "a" Büyük Vitrin      - üstte tek büyük öne çıkan öğe (sahne + bilgi + hedef/diğer alınabilirler), altta 5 sade bölüm kartı
##   "b" Beş Kapı          - ekranı dolduran 5 uzun bölüm sütunu, her birinde büyük vitrin öğesi; altta ince hedef şeridi
##   "c" Menü + Önizleme   - solda 5 büyük bölüm girişi, sağda odaktaki bölümün tüm öğeleri (üstüne gelince değişir)
##   "d" Koleksiyon Rafları - her bölüm bir raf: öğeler rafta yan yana durur (alınamayan = silüet), altta geliştirme şeridi
## variant "" = bugünkü ana sayfa (karşılaştırma).

var variant: String = ""
var focus_kind: String = "char" ## C: soldaki menüde odaktaki bölüm

const SECTIONS := ["char", "weapon", "pet", "spirit", "upgrades"]
const SECTION_BLURB := {
	"char": "Koşuya bu kahramanlarla başla; her birinin kendi Q / E / R yetenekleri var.",
	"weapon": "Karakter seçiminde başlangıç silahı olarak seçebileceğin silahlar.",
	"pet": "Koşu boyunca yanında dolaşan, küçük bir avantaj veren yol arkadaşları.",
	"spirit": "F tuşuyla kullanılan ruhani yetenekler.",
	"upgrades": "Kalıcı güçlendirmeler; her koşuda geçerli.",
}
const KIND_LOWER := {"char": "Karakter", "weapon": "Silah", "pet": "Evcil hayvan", "spirit": "Ruhani yetenek"}
const GO_TEXT := {"char": "KARAKTERLERE GİT", "weapon": "SİLAHLARA GİT", "pet": "EVCİL HAYVANLARA GİT", "spirit": "RUHANİ YETENEKLERE GİT",
		"upgrades": "GELİŞTİRMELERE GİT"}
const C_SIL := Color("#4a3b2d") ## D: alınamayan öğenin silüet rengi

var _sil_mat: ShaderMaterial = null


## D: raf - arka duvar basamaklı koyulaşır, altta ahşap raf tahtası (üst ışık + ön yüz + alt kenar + gölge).
class ShelfBg extends Control:
	var floor_off: float = 64.0
	var top: Color
	var bottom: Color
	var wood: Color
	var wood_hi: Color
	var wood_dk: Color

	func _init(fo: float, t: Color, b: Color, w: Color, whi: Color, wdk: Color) -> void:
		floor_off = fo
		top = t
		bottom = b
		wood = w
		wood_hi = whi
		wood_dk = wdk
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y: float = floorf(size.y - floor_off)
		var n: int = 5
		var bh: float = ceilf(y / n)
		for i in n:
			draw_rect(Rect2(0, i * bh, size.x, minf(bh, y - i * bh)), top.lerp(bottom, float(i) / float(n - 1)))
		draw_rect(Rect2(0, y, size.x, 6), wood_hi)
		draw_rect(Rect2(0, y + 6, size.x, 12), wood)
		draw_rect(Rect2(0, y + 18, size.x, 3), wood_dk)
		draw_rect(Rect2(0, y + 21, size.x, 8), Color(0, 0, 0, 0.22))
		## raf ayakları (iki uçta)
		for x: float in [18.0, size.x - 30.0]:
			draw_rect(Rect2(x, y + 21, 12, 14), wood_dk)


func _build_home() -> void:
	match variant:
		"a":
			_home_a()
		"b":
			_home_b()
		"c":
			_home_c()
		"d":
			_home_d()
		_:
			super._build_home()


## ---------------------------------------------------------------- ortak
func _sec_name(kind: String) -> String:
	return "Geliştirmeler" if kind == PAGE_UPGRADES else str(KIND_TILE.get(kind, kind))


func _sec_title(kind: String) -> String:
	return "GELİŞTİRMELER" if kind == PAGE_UPGRADES else str(KIND_NAMES.get(kind, kind))


func _can_n(list: Array) -> int:
	var n: int = 0
	for it: Dictionary in list:
		if _state(it) == "can":
			n += 1
	return n


func _upg_can_n() -> int:
	var n: int = 0
	for d: Dictionary in MetaUpgradesScript.LIST:
		if MetaUpgradesScript.can_buy(str(d["id"])):
			n += 1
	return n


## Bölümün vitrin öğesi: alınabilir en ucuz -> alınamayan en ucuz -> açık olan.
func _rep(items: Array, kind: String) -> Dictionary:
	var list: Array = _of_kind(items, kind)
	return list[0] if not list.is_empty() else {}


## Alınabilir en ucuz geliştirme (yoksa ilk).
func _rep_upgrade() -> Dictionary:
	var best: Dictionary = {}
	for d: Dictionary in MetaUpgradesScript.LIST:
		var id: String = str(d["id"])
		if MetaUpgradesScript.can_buy(id) and (best.is_empty() or MetaUpgradesScript.next_cost(id) < MetaUpgradesScript.next_cost(str(best["id"]))):
			best = d
	return best if not best.is_empty() else MetaUpgradesScript.LIST[0]


## Koleksiyon sırası (durumdan bağımsız, ucuzdan pahalıya) - raf/ızgarada öğeler yer değiştirmesin.
func _by_cost(items: Array, kind: String) -> Array:
	var a: Array = items.filter(func(i: Dictionary) -> bool: return i["kind"] == kind)
	a.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["cost"]) < int(y["cost"]))
	return a


func _sec_icon(items: Array, kind: String, box: float) -> Control:
	if kind == PAGE_UPGRADES:
		return _icon(_stat_tex("damage"), box)
	var it: Dictionary = _rep(items, kind)
	if it.is_empty():
		return _icon(null, box)
	return _icon(_tex_of(it) if kind == MetaProgressScript.WEAPON else it.get("icon", null), box)


func _open_item(it: Dictionary) -> void:
	_sel[str(it["kind"])] = it["key"]
	_on_tab_pressed(str(it["kind"]))


func _counts(items: Array, kind: String) -> Vector2i:
	if kind == PAGE_UPGRADES:
		return _upg_levels()
	var list: Array = _of_kind(items, kind)
	return Vector2i(_open_count(list), list.size())


## "AÇIK 1/10" + çubuk.
func _progress(items: Array, kind: String, fs: int = 24, bar_h: float = 10.0) -> VBoxContainer:
	var c: Vector2i = _counts(items, kind)
	var v := _v(6)
	var h := _h(8)
	h.add_child(_lbl("SEVİYE" if kind == PAGE_UPGRADES else "AÇIK", fs, C_DIM))
	h.add_child(_sp(0, 0, true))
	h.add_child(_lbl("%d/%d" % [c.x, c.y], fs, C_ACCENT))
	v.add_child(h)
	v.add_child(_expand(Bar.new(float(c.x) / float(maxi(1, c.y)), C_ACCENT, C_INSET, bar_h)))
	return v


## Yeşil "N alınabilir" / "Hepsi açık" / "Kıymık biriktir".
func _avail_line(items: Array, kind: String, fs: int = 24, center: bool = true) -> HBoxContainer:
	var n: int = _upg_can_n() if kind == PAGE_UPGRADES else _can_n(_of_kind(items, kind))
	var c: Vector2i = _counts(items, kind)
	var h := _h(8)
	if center:
		h.alignment = BoxContainer.ALIGNMENT_CENTER
	if n > 0:
		h.add_child(DK.ShardIcon.new(fs * 0.75))
		h.add_child(_lbl("%d %s" % [n, "yükseltilebilir" if kind == PAGE_UPGRADES else "alınabilir"], fs, C_GOOD))
	elif c.x >= c.y:
		h.add_child(Glyph.new(G_CHECK, C_GOOD, 3))
		h.add_child(_lbl("Hepsi açık", fs, C_GOOD))
	else:
		h.add_child(_lbl("Kıymık biriktir", fs, C_DIM))
	return h


## Düğme: yazı + sağ ok (genişlik yazıdan ölçülür).
func _arrow_btn(t: String, kind: String = "primary", fs: int = 32, h: float = 64.0) -> Button:
	var w: float = MenuKit.font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 90.0
	var b := _btn("", kind, fs, h, w)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := _h(14)
	var tc: Color = C_ACCENT_TEXT if kind == "primary" else C_TEXT
	var l := _lbl(t, fs, tc)
	if kind == "primary":
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	row.add_child(l)
	row.add_child(Glyph.new(G_RIGHT, tc, 4))
	cc.add_child(row)
	b.add_child(cc)
	return b


func _silhouette(ci: CanvasItem) -> void:
	if _sil_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform vec4 col : source_color;\nvoid fragment() { COLOR = vec4(col.rgb, texture(TEXTURE, UV).a * col.a); }\n"
		_sil_mat = ShaderMaterial.new()
		_sil_mat.shader = sh
		_sil_mat.set_shader_parameter("col", C_SIL)
	ci.material = _sil_mat


func _vline() -> ColorRect:
	var r := ColorRect.new()
	r.color = C_LINE
	r.custom_minimum_size = Vector2(3, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


var _crop_cache: Dictionary = {}


## Öğenin büyük görseli: karakterde tam boy kare, silahta boş kenarı kırpılmış ikon (silah ikonları tuvalin ortasında küçük çizili), diğerlerinde ikon.
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


func _with_tex(it: Dictionary) -> Dictionary:
	var d: Dictionary = it.duplicate()
	d["icon"] = _tex_of(it)
	return d


## Tek ikonun kutuya sığan tam kat ölçeği (silah ikonlarının kaynak çözünürlükleri farklı -> ortak ölçek küçükleri cüce bırakır).
func _fit_k(tex: Texture2D, box: float) -> float:
	var big: float = maxf(tex.get_size().x, tex.get_size().y)
	var k: float = floorf(box / big)
	return k if k >= 1.0 else box / big


## Karakter sırası için ORTAK tam kat ölçek (göreli boylar doğru kalsın); karakter olmayan sırada her ikon kendi ölçeğini alır (_fit_k).
func _row_scale(list: Array, max_h: float, max_w: float) -> float:
	var k: float = 64.0
	for it: Dictionary in list:
		var tex: Texture2D = _tex_of(it)
		if tex == null:
			continue
		var ts: Vector2 = tex.get_size()
		if it["kind"] == MetaProgressScript.CHAR:
			k = minf(k, minf(floorf(max_h / ts.y), floorf(max_w / ts.x)))
		else:
			k = minf(k, floorf(minf(max_h, max_w) / maxf(ts.x, ts.y)))
	return maxf(1.0, k)


## Tabana oturan figür (ebeveynin alt ortasına çapalı; lift = tabandan yukarı).
func _fig_sprite(tex: Texture2D, k: float, lift: float) -> TextureRect:
	var spr := TextureRect.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spr.stretch_mode = TextureRect.STRETCH_SCALE
	spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ts: Vector2 = tex.get_size() * k
	spr.anchor_left = 0.5
	spr.anchor_right = 0.5
	spr.anchor_top = 1.0
	spr.anchor_bottom = 1.0
	spr.offset_left = -floorf(ts.x * 0.5)
	spr.offset_right = spr.offset_left + ts.x
	spr.offset_top = -lift - ts.y
	spr.offset_bottom = -lift
	return spr


## Geliştirme vitrini: ikon sahnede süzülür (StageBg zemin halkasının üstünde).
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


## ================================================================ A - BÜYÜK VİTRİN
func _home_a() -> void:
	_page_box.add_child(_topbar("GERİ", _on_close_pressed, DK.ShardIcon.new(38), "RUH MAĞAZASI"))
	var items: Array = _items()
	var hero: Control = _a_hero(items)
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(hero)
	var row := _h(20)
	row.custom_minimum_size.y = 300
	for k: String in SECTIONS:
		row.add_child(_a_card(items, k))
	_page_box.add_child(row)


func _a_hero(items: Array) -> Control:
	var p := _box(C_PANEL, C_LINE_HI, 20, 3, 8)
	_anim_nodes["featured"] = p
	var it: Dictionary = _featured(items)
	var goal: Dictionary = _goal(items)
	var featured_is_goal: bool = false
	if it.is_empty():
		it = goal
		featured_is_goal = true
	if it.is_empty():
		p.add_child(_lbl("HER ŞEY AÇIK", 64, C_GOOD, HORIZONTAL_ALIGNMENT_CENTER))
		return p
	var h := _h(28)
	p.add_child(h)
	## sahne
	var st := _box(C_INSET, C_LINE_HI, 0, 3, 8)
	st.custom_minimum_size.x = 620
	st.add_child(StageBg.new(C_SPOT, C_ACCENT, 70.0))
	st.add_child(CornerFrame.new(C_ACCENT, 26.0, 10.0))
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(hold)
	_stage_figure(hold, _with_tex(it), 300.0, 70.0)
	h.add_child(st)
	## bilgi
	var v := _v(14)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge: PanelContainer = _status_badge(it)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(badge)
	v.add_child(_lbl(str(it["name"]), 64))
	if it["kind"] == MetaProgressScript.CHAR:
		v.add_child(_skill_rows(it, 32, 560))
		var stats0: GridContainer = _stat_rows(it, 24)
		stats0.columns = 4
		stats0.add_theme_constant_override("h_separation", 26)
		v.add_child(stats0)
	else:
		v.add_child(_wrap(str(it["desc"]), 32, C_DIM, 600, 3))
	v.add_child(_sp(0, 0, false, true))
	var buy_row := _h(20)
	var bb: Button = _buy_btn(it, 40, 84, "feat_buy")
	bb.custom_minimum_size.x = 400
	buy_row.add_child(bb)
	if _state(it) == "can":
		var kv := _v(-4)
		kv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kv.add_child(_lbl("alınca kalan", 24, C_DIM))
		var kh := _h(8)
		kh.add_child(DK.ShardIcon.new(20))
		kh.add_child(_lbl(str(MetaProgressScript.shards() - int(it["cost"])), 32, C_PRICE))
		kv.add_child(kh)
		buy_row.add_child(kv)
	v.add_child(buy_row)
	h.add_child(v)
	h.add_child(_vline())
	## sağ: hedef + diğer alınabilirler
	var r := _v(14)
	r.custom_minimum_size.x = 470
	if not featured_is_goal and not goal.is_empty():
		r.add_child(_goal_box(goal))
	r.add_child(_lbl("BUNLARI DA ALABİLİRSİN", 24, C_ACCENT))
	var others: Array = items.filter(func(i: Dictionary) -> bool: return _state(i) == "can" and _id(i) != _id(it))
	others.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["cost"]) < int(y["cost"]))
	if others.is_empty():
		r.add_child(_lbl("Şimdilik başka alınabilecek öğe yok", 24, C_DIM))
	for i in mini(3, others.size()):
		r.add_child(_a_mini_row(others[i]))
	h.add_child(r)
	return p


func _a_mini_row(it: Dictionary) -> Control:
	var p := _box(C_INSET, C_LINE, 8, 3, 6)
	var h := _h(14)
	var slot := _box(C_PANEL2, C_LINE, 4, 3, 4)
	slot.add_child(_icon(_tex_of(it) if it["kind"] == MetaProgressScript.WEAPON else it["icon"], 56))
	h.add_child(slot)
	var tv := _v(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_lbl(str(it["name"]), 32))
	tv.add_child(_lbl(str(KIND_LOWER.get(it["kind"], "")), 24, C_DIM))
	h.add_child(tv)
	h.add_child(_price(it, 32))
	h.add_child(_sp(6))
	p.add_child(h)
	_clickable(p, _open_item.bind(it), "mini:" + _id(it))
	_anim_list("tiles").append(p)
	return p


func _a_card(items: Array, kind: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(C_PANEL, C_LINE_HI, 3, 8, 3))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(CardBg.new(C_PANEL3, C_PANEL, C_SPOT))
	var m := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		m.add_theme_constant_override(side, 18)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := _v(10)
	v.add_child(_sp(0, 6))
	v.add_child(_sec_icon(items, kind, 104))
	v.add_child(_lbl(_sec_name(kind), 40, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_progress(items, kind))
	v.add_child(_avail_line(items, kind))
	m.add_child(v)
	p.add_child(m)
	_clickable(p, _on_tab_pressed.bind(kind), "tile:" + kind)
	_anim_list("tiles").append(p)
	return p


## ================================================================ B - BEŞ KAPI
func _home_b() -> void:
	_page_box.add_child(_topbar("GERİ", _on_close_pressed, DK.ShardIcon.new(38), "RUH MAĞAZASI"))
	var items: Array = _items()
	var row := _h(20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for k: String in SECTIONS:
		row.add_child(_b_door(items, k))
	_page_box.add_child(row)
	var goal: Dictionary = _goal(items)
	if not goal.is_empty():
		_page_box.add_child(_b_goal_strip(goal))


func _b_door(items: Array, kind: String) -> Control:
	var p := _box(C_PANEL, C_LINE_HI, 3, 3, 8)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := _v(0)
	p.add_child(v)
	## başlık levhası
	var hd := _box(C_PANEL2, Color(0, 0, 0, 0), 14, 0, 6)
	hd.add_child(_lbl(_sec_name(kind), 40, C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(hd)
	v.add_child(_hline())
	## sahne
	var st := _box(C_INSET, Color(0, 0, 0, 0), 0, 0, 0)
	st.size_flags_vertical = Control.SIZE_EXPAND_FILL
	st.clip_contents = true
	st.add_child(StageBg.new(C_SPOT, C_ACCENT, 120.0))
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(hold)
	v.add_child(st)
	v.add_child(_hline())
	## vitrin öğesinin adı + fiyatı
	var info := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 14, 0, 0)
	var iv := _v(4)
	if kind == PAGE_UPGRADES:
		var d: Dictionary = _rep_upgrade()
		var id: String = str(d["id"])
		_stage_upgrade(hold, d, 192.0, 120.0)
		iv.add_child(_lbl("SIRADAKİ GELİŞTİRME", 24, C_GOOD if MetaUpgradesScript.can_buy(id) else C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
		iv.add_child(_lbl(str(d["name"]), 32, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
		var ph := _h(8)
		ph.alignment = BoxContainer.ALIGNMENT_CENTER
		ph.add_child(_lbl("Sv %d" % MetaUpgradesScript.level(id), 24, C_DIM))
		ph.add_child(Glyph.new(G_RIGHT, C_DIM, 3))
		ph.add_child(_lbl("%d" % (MetaUpgradesScript.level(id) + 1), 24, C_TEXT))
		ph.add_child(_sp(10))
		ph.add_child(DK.ShardIcon.new(24, not MetaUpgradesScript.can_buy(id)))
		ph.add_child(_lbl(str(MetaUpgradesScript.next_cost(id)), 32, C_PRICE if MetaUpgradesScript.can_buy(id) else C_BAD))
		iv.add_child(ph)
	else:
		var it: Dictionary = _rep(items, kind)
		if not it.is_empty():
			_stage_figure(hold, _with_tex(it), 380.0 if kind == MetaProgressScript.CHAR else 200.0, 120.0)
			var cap: String = {"can": "ŞİMDİ ALABİLİRSİN", "no": "SIRADAKİ", "open": "HEPSİ SENDE"}[_state(it)]
			iv.add_child(_lbl(cap, 24, C_GOOD if _state(it) != "no" else C_DIM, HORIZONTAL_ALIGNMENT_CENTER))
			iv.add_child(_lbl(str(it["name"]), 32, C_TEXT, HORIZONTAL_ALIGNMENT_CENTER))
			iv.add_child(_price(it, 32))
	info.add_child(iv)
	v.add_child(info)
	v.add_child(_hline())
	## ilerleme
	var foot := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 16, 0, 0)
	var fv := _v(10)
	fv.add_child(_progress(items, kind))
	fv.add_child(_avail_line(items, kind))
	foot.add_child(fv)
	v.add_child(foot)
	## alt bant
	var band := _box(C_PANEL2, Color(0, 0, 0, 0), 12, 0, 6)
	var bh := _h(12)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.add_child(_lbl("İNCELE", 32, C_ACCENT))
	bh.add_child(Glyph.new(G_RIGHT, C_ACCENT, 4))
	band.add_child(bh)
	v.add_child(band)
	_clickable(p, _on_tab_pressed.bind(kind), "tile:" + kind)
	_anim_list("tiles").append(p)
	return p


func _b_goal_strip(goal: Dictionary) -> Control:
	var p := _box(C_PANEL, C_LINE_HI, 12, 3, 8)
	var h := _h(18)
	h.add_child(_sp(6))
	h.add_child(_lbl("SIRADAKİ HEDEF", 24, C_ACCENT))
	h.add_child(_icon(goal["icon"], 48))
	h.add_child(_lbl(str(goal["name"]), 32))
	var bar := Bar.new(float(MetaProgressScript.shards()) / float(maxi(1, int(goal["cost"]))), C_ACCENT, C_INSET, 16.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	h.add_child(DK.ShardIcon.new(24))
	h.add_child(_lbl("%d / %d" % [MetaProgressScript.shards(), int(goal["cost"])], 32, C_DIM))
	h.add_child(_lbl("%d kaldı" % _need(goal), 32, C_PRICE))
	h.add_child(_sp(6))
	p.add_child(h)
	return p


## ================================================================ C - MENÜ + ÖNİZLEME
func _home_c() -> void:
	_page_box.add_child(_topbar("GERİ", _on_close_pressed, DK.ShardIcon.new(38), "RUH MAĞAZASI"))
	var items: Array = _items()
	var body := _h(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(body)
	var left := _v(12)
	left.custom_minimum_size.x = 540
	for k: String in SECTIONS:
		left.add_child(_c_entry(items, k, k == focus_kind))
	left.add_child(_sp(0, 0, false, true))
	var goal: Dictionary = _goal(items)
	if not goal.is_empty():
		left.add_child(_goal_box(goal))
	body.add_child(left)
	body.add_child(_c_preview(items, focus_kind))


func _c_entry(items: Array, kind: String, on: bool) -> Control:
	var p := _box(C_PANEL2 if on else C_PANEL, C_ACCENT if on else C_LINE_HI, 3, 3, 8)
	var h := _h(0)
	var stripe := ColorRect.new()
	stripe.color = C_ACCENT if on else Color(0, 0, 0, 0)
	stripe.custom_minimum_size.x = 8
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(stripe)
	var m := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 14, 0, 0)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hh := _h(16)
	var slot := _box(C_INSET, C_LINE, 4, 3, 4)
	slot.add_child(_sec_icon(items, kind, 72))
	hh.add_child(slot)
	var tv := _v(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_child(_lbl(_sec_name(kind), 40, C_ACCENT if on else C_TEXT))
	var c: Vector2i = _counts(items, kind)
	var sub := _h(8)
	sub.add_child(_lbl(("%d/%d seviye" if kind == PAGE_UPGRADES else "%d/%d açık") % [c.x, c.y], 24, C_DIM))
	sub.add_child(_sp(0, 0, true))
	sub.add_child(_avail_line(items, kind, 24, false))
	tv.add_child(sub)
	tv.add_child(_expand(Bar.new(float(c.x) / float(maxi(1, c.y)), C_ACCENT, C_INSET, 8.0)))
	hh.add_child(tv)
	hh.add_child(_sp(4))
	hh.add_child(Glyph.new(G_RIGHT, C_ACCENT if on else C_LINE_HI, 4))
	hh.add_child(_sp(4))
	m.add_child(hh)
	h.add_child(m)
	p.add_child(h)
	_clickable(p, _on_tab_pressed.bind(kind), "tile:" + kind)
	_anim_list("tiles").append(p)
	return p


func _c_preview(items: Array, kind: String) -> Control:
	var p := _box(C_PANEL, C_LINE_HI, 24, 3, 8)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_anim_nodes["center"] = p
	var v := _v(14)
	p.add_child(v)
	var hh := _h(16)
	hh.add_child(_lbl(_sec_title(kind), 48, C_ACCENT))
	hh.add_child(_sp(0, 0, true))
	var c: Vector2i = _counts(items, kind)
	hh.add_child(_lbl(("%d/%d seviye" if kind == PAGE_UPGRADES else "%d/%d açık") % [c.x, c.y], 32, C_DIM))
	v.add_child(hh)
	v.add_child(_wrap(str(SECTION_BLURB.get(kind, "")), 24, C_DIM, 900, 2))
	v.add_child(_hline())
	if kind == PAGE_UPGRADES:
		v.add_child(_c_upg_grid())
	else:
		v.add_child(_c_item_grid(_by_cost(items, kind)))
	v.add_child(_sp(0, 0, false, true))
	var f := _h(16)
	f.add_child(_avail_line(items, kind, 32, false))
	f.add_child(_sp(0, 0, true))
	var go: Button = _arrow_btn(str(GO_TEXT[kind]), "primary", 32, 64)
	go.pressed.connect(_on_tab_pressed.bind(kind))
	_tag_sid(go, "go:" + kind)
	f.add_child(go)
	v.add_child(f)
	return p


func _c_item_grid(list: Array) -> Control:
	var g := GridContainer.new()
	g.columns = 5 if list.size() <= 10 else 6
	g.size_flags_vertical = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	var rows: int = ceili(float(list.size()) / float(g.columns))
	var is_char: bool = not list.is_empty() and list[0]["kind"] == MetaProgressScript.CHAR
	## önizleme alanı ~1240x640: kartlar alanı doldurur, figürler ortak tam kat ölçekle
	var card_h: float = floorf((640.0 - (rows - 1) * 14.0) / rows)
	var card_w: float = floorf((1240.0 - (g.columns - 1) * 14.0) / g.columns)
	var fig_h: float = card_h - 100.0
	var k: float = _row_scale(list, fig_h, card_w - 28.0)
	for it: Dictionary in list:
		var st: String = _state(it)
		var bd: Color = {"open": C_GOOD, "can": C_ACCENT, "no": C_LINE}[st]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _sb(C_INSET, bd, 3, 6, 3))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = card_h
		card.add_child(CardBg.new(C_PANEL3 if st == "can" else C_PANEL2, C_INSET, C_SPOT if st != "no" else C_LINE))
		var pad := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 10, 0, 0)
		var cv := _v(4)
		var tex: Texture2D = _tex_of(it)
		if is_char:
			var hold := Control.new()
			hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hold.size_flags_vertical = Control.SIZE_EXPAND_FILL
			hold.custom_minimum_size.y = fig_h
			if tex != null:
				var spr: TextureRect = _fig_sprite(tex, k, 0.0)
				if st == "no":
					spr.modulate = Color(0.52, 0.52, 0.58, 1.0)
				hold.add_child(spr)
			cv.add_child(hold)
		else:
			var cc := CenterContainer.new()
			cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if tex != null:
				var tr := TextureRect.new()
				tr.texture = tex
				tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				tr.custom_minimum_size = (tex.get_size() * _fit_k(tex, minf(fig_h, card_w - 28.0))).floor()
				tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
				if st == "no":
					tr.modulate = Color(0.52, 0.52, 0.58, 1.0)
				cc.add_child(tr)
			cv.add_child(cc)
		var nl := _lbl(str(it["name"]), 24, C_TEXT if st != "no" else C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		nl.clip_text = true
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.custom_minimum_size.x = 10
		cv.add_child(nl)
		cv.add_child(_price(it, 24))
		pad.add_child(cv)
		card.add_child(pad)
		_clickable(card, _open_item.bind(it), "item:" + _id(it))
		_anim_list("cards").append(card)
		g.add_child(card)
	return g


func _c_upg_grid() -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 24)
	g.add_theme_constant_override("v_separation", 8)
	for d: Dictionary in MetaUpgradesScript.LIST:
		var id: String = str(d["id"])
		var lv: int = MetaUpgradesScript.level(id)
		var mx: int = MetaUpgradesScript.max_level(id)
		var h := _h(12)
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(_upg_icon(d, 40))
		var nl := _lbl(str(d["name"]), 24)
		nl.custom_minimum_size.x = 250
		h.add_child(nl)
		var pp := Pips.new(mx, lv, C_ACCENT, C_INSET, 10.0)
		pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(pp)
		h.add_child(_lbl("%d/%d" % [lv, mx], 24, C_GOOD if lv >= mx else C_DIM))
		g.add_child(h)
	return g


## ================================================================ D - KOLEKSİYON RAFLARI
const D_LABEL_W := 300.0
const D_FLOOR := 66.0 ## raf tahtasının alttan uzaklığı (öğenin ayağı buraya basar)


func _home_d() -> void:
	_page_box.add_child(_topbar("GERİ", _on_close_pressed, DK.ShardIcon.new(38), "RUH MAĞAZASI"))
	var items: Array = _items()
	var v := _v(14)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_box.add_child(v)
	var chars: Control = _d_shelf(items, MetaProgressScript.CHAR, D_LABEL_W, 190.0)
	chars.size_flags_stretch_ratio = 1.35 ## karakter rafı daha yüksek (tam boy figürler)
	v.add_child(chars)
	v.add_child(_d_shelf(items, MetaProgressScript.WEAPON, D_LABEL_W, 104.0))
	var pair := _h(14)
	pair.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pair.add_child(_d_shelf(items, MetaProgressScript.PET, 250.0, 104.0))
	pair.add_child(_d_shelf(items, MetaProgressScript.SPIRIT, 250.0, 80.0))
	v.add_child(pair)
	v.add_child(_d_upgrades(items))


func _d_label(items: Array, kind: String, w: float) -> Control:
	var lb := _box(C_PANEL2, Color(0, 0, 0, 0), 18, 0, 6)
	lb.custom_minimum_size.x = w
	var lv := _v(10)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_child(_lbl(_sec_name(kind), 40))
	lv.add_child(_progress(items, kind))
	lv.add_child(_avail_line(items, kind, 24, false))
	lb.add_child(lv)
	return lb


func _d_shelf(items: Array, kind: String, label_w: float, max_h: float) -> Control:
	var list: Array = _by_cost(items, kind)
	var row := _box(C_PANEL, C_LINE_HI, 3, 3, 8)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := _h(0)
	row.add_child(h)
	h.add_child(_d_label(items, kind, label_w))
	var shelf := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0)
	shelf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf.add_child(ShelfBg.new(D_FLOOR, C_INSET, C_PANEL, C_PANEL3, C_LINE_HI, C_ACCENT_DK.darkened(0.4)))
	var m := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 0)
	var sm := StyleBoxEmpty.new()
	sm.content_margin_left = 20
	sm.content_margin_right = 12
	sm.content_margin_top = 12
	m.add_theme_stylebox_override("panel", sm)
	var items_h := _h(0)
	items_h.alignment = BoxContainer.ALIGNMENT_CENTER
	items_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hh := _h(8)
	hh.add_child(items_h)
	hh.add_child(Glyph.new(G_RIGHT, C_ACCENT, 4))
	items_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(hh)
	shelf.add_child(m)
	h.add_child(shelf)
	## öğe genişliği: ekrana sığacak kadar (17 silah tek sırada)
	var shelf_w: float = 1856.0 - label_w - 80.0
	if kind == MetaProgressScript.PET or kind == MetaProgressScript.SPIRIT:
		shelf_w = (1856.0 - 14.0) * 0.5 - label_w - 80.0
	var item_w: float = clampf(floorf(shelf_w / maxf(1.0, float(list.size()))), 64.0, 170.0)
	var k: float = _row_scale(list, max_h, item_w - 14.0)
	for it: Dictionary in list:
		var tex: Texture2D = _tex_of(it)
		var kk: float = k if kind == MetaProgressScript.CHAR or tex == null else _fit_k(tex, minf(max_h, item_w - 14.0))
		items_h.add_child(_d_item(it, item_w, kk))
	_clickable(row, _on_tab_pressed.bind(kind), "tile:" + kind)
	_anim_list("tiles").append(row)
	return row


func _d_item(it: Dictionary, w: float, k: float) -> Control:
	var st: String = _state(it)
	var is_char: bool = it["kind"] == MetaProgressScript.CHAR
	var col := _v(0)
	col.custom_minimum_size.x = w
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(hold)
	var tex: Texture2D = _tex_of(it)
	if tex != null:
		var spr: TextureRect = _fig_sprite(tex, k, -2.0 if is_char else 10.0) ## karakter ayağı tahtaya basar, ikonlar hafif üstünde durur
		if st == "no" and it["kind"] != MetaProgressScript.SPIRIT:
			_silhouette(spr)
		elif st == "no":
			spr.modulate = Color(0.45, 0.43, 0.47, 1.0)
		hold.add_child(spr)
	col.add_child(_sp(0, D_FLOOR - 44.0))
	var pr: HBoxContainer = _price(it, 24)
	pr.custom_minimum_size.y = 32
	col.add_child(pr)
	col.add_child(_sp(0, 12))
	return col


func _d_upgrades(items: Array) -> Control:
	var row := _box(C_PANEL, C_LINE_HI, 3, 3, 8)
	var h := _h(0)
	row.add_child(h)
	h.add_child(_d_label(items, PAGE_UPGRADES, D_LABEL_W))
	var m := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 14, 0, 0)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cells := _h(10)
	cells.alignment = BoxContainer.ALIGNMENT_CENTER
	for d: Dictionary in MetaUpgradesScript.LIST:
		var id: String = str(d["id"])
		var lv: int = MetaUpgradesScript.level(id)
		var mx: int = MetaUpgradesScript.max_level(id)
		var cv := _v(6)
		var slot := _box(C_INSET, C_GOOD if lv >= mx else C_LINE, 4, 3, 4)
		slot.add_child(_upg_icon(d, 48))
		cv.add_child(slot)
		var b := Bar.new(float(lv) / float(maxi(1, mx)), C_ACCENT if lv < mx else C_GOOD, C_INSET, 10.0, 56.0)
		cv.add_child(b)
		cells.add_child(cv)
	var hh := _h(8)
	cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(cells)
	hh.add_child(Glyph.new(G_RIGHT, C_ACCENT, 4))
	hh.add_child(_sp(4))
	m.add_child(hh)
	h.add_child(m)
	_clickable(row, _on_tab_pressed.bind(PAGE_UPGRADES), "tile:upgrades")
	_anim_list("tiles").append(row)
	return row
