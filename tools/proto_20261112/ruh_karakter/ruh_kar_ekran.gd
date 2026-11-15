extends "res://scripts/soul_shop_screen.gd"

## Ruh Mağazası KARAKTER AYRINTISI prototipleri (2026-11-12, kullanıcı: "dükkanda karakter açıklamaları uzun olduğu için hepsi
## okunamıyor. sağdaki karakter göstergesi arayüzünü daha farklı ve anlaşılır tasarlamamız gerekiyor, diğer arayüz
## tasarımlarına dokunmadan"). Gerçek soul_shop_screen.gd'den TÜRER; YALNIZ karakterin sağ ayrıntısı (_detail) ezilir -
## sol bölümler, orta liste, diğer bölümlerin ayrıntısı birebir aynı. Oyuna bağlı DEĞİL.
##   variant "now" = bugünkü, "a" Yetenek Sekmeleri, "b" Açılır Liste, "c" Defter Sayfaları, "d" Oyun İçi İpucu.
## Ortak: açıklama KESİLMEZ (tam metin), m5x7 32 (stil rehberi; eski 24 kalıntı), yeteneğin türü renkli etiket (oyundaki ipucuyla
## aynı `HudTooltip.make_tag`), bekleme süresi metinden ayrılıp saat simgesiyle, sayılar/hasar/can/kalkan oyundaki ipucunun renkleriyle.

const HudTooltip := preload("res://scripts/hud_tooltip.gd")
const CD_ICON := preload("res://assets/ui/stat_mini/cooldown_reduction.png")
const BODY_FS := 32
const G_DOWN := ["#####", ".###.", "..#.."]

var variant: String = "a"
var sk_sel: int = 0 ## A/B/D: seçili yetenek (0 = pasif, sonra Q/E/R; pasifi olmayan karakterde 0 = Q)
var dpage: String = "genel" ## C: "genel" | "yetenek"
var _tip: Control = null ## D: açık ipucu


func _select(it: Dictionary, dir: int = 0) -> void:
	if str(it.get("kind", "")) == MetaProgressScript.CHAR:
		sk_sel = 0
		dpage = "genel"
	super(it, dir)


func _rebuild_list(reset_scroll: bool = false) -> void:
	_hide_tip()
	super(reset_scroll)


func _detail(it: Dictionary) -> Control:
	if variant == "now" or it.is_empty() or str(it["kind"]) != MetaProgressScript.CHAR:
		return super(it)
	match variant:
		"a":
			return _detail_a(it)
		"b":
			return _detail_b(it)
		"c":
			return _detail_c(it)
	return _detail_d(it)


## ---------------------------------------------------------------- veri: yetenek girdileri
## {key, name, icon, kind, note, cd, body}: tür ("ULTİ: ..." / "TEMEL (not): ...") etikete, sondaki "(22sn bekleme)" saate ayrılır.
func _entries(it: Dictionary) -> Array:
	var d: Dictionary = _char_def(it)
	var out: Array = []
	var p: String = str(d.get("passive", ""))
	if p != "":
		var pn: Array = _passive_split(p)
		out.append({"key": "P", "name": str(pn[0]) if str(pn[0]) != "" else "Pasif", "icon": str(d.get("passive_icon", "")),
				"kind": "PASİF", "note": "", "cd": "", "body": str(pn[1])})
	for q: Array in [["Q", "skill_name", "skill_icon", "skill_desc", "YETENEK"], ["E", "skill2_name", "skill2_icon", "skill2_desc", "TEMEL"],
			["R", "skill3_name", "skill3_icon", "skill3_desc", "ULTİ"]]:
		var raw: String = str(d.get(q[3], ""))
		var ks: Array = _kind_split(raw)
		var cd: String = ""
		var re := RegEx.new()
		re.compile("\\s*\\((\\d+(?:[.,]\\d+)?)\\s*sn bekleme\\)")
		var m: RegExMatch = re.search(str(ks[2]))
		if m != null:
			cd = "%s sn" % m.get_string(1)
		var body: String = re.sub(str(ks[2]), "", true).strip_edges()
		out.append({"key": q[0], "name": str(d.get(q[1], "")), "icon": str(d.get(q[2], "")),
				"kind": str(ks[0]) if str(ks[0]) != "" else str(q[4]), "note": _soft_case(str(ks[1])), "cd": cd, "body": body})
	return out


## "TEMEL (maksimum canının %4'ünü harcar): ..." -> ["TEMEL", "maksimum canının %4'ünü harcar", "..."]; "GOLEM FORMU (...)" de tür sayılır.
func _kind_split(desc: String) -> Array:
	var re := RegEx.new()
	re.compile("^\\s*(\\p{Lu}+(?: \\p{Lu}+)*)\\s*(?:\\(([^)]*)\\))?\\s*:\\s*")
	var m: RegExMatch = re.search(desc)
	if m == null or m.get_string(1).length() <= 1:
		return ["", "", desc]
	return [m.get_string(1), m.get_string(2), desc.substr(m.get_end())]


## Pasifin başındaki kısa ad ("Kan Emme: ...") -> [ad, gövde] (skill_icon.gd _split_passive_name ile aynı kural).
func _passive_split(desc: String) -> Array:
	var i: int = desc.find(": ")
	if i <= 0 or i > 28:
		return ["", desc]
	var head: String = desc.substr(0, i)
	if head == head.to_upper():
		return ["", desc]
	var re := RegEx.new()
	re.compile("[0-9(),%]")
	if re.search(head) != null:
		return ["", desc]
	return [head, desc.substr(i + 2)]


## "BASILIP KAPATILABİLİR" -> "Basılıp kapatılabilir" (Türkçe İ/I).
func _soft_case(s: String) -> String:
	if s == "" or s != s.to_upper():
		return s
	var low: String = s.replace("İ", "i").replace("I", "ı").to_lower()
	return low.substr(0, 1).to_upper() + low.substr(1)


## Oyundaki yetenek ipucunun boyaması (skill_icon.gd _format_lol_style ile aynı mürekkepler, HudTheme.INK).
func _lol(text: String) -> String:
	var ink: Dictionary = HT.INK
	for kw: Array in [["hasar", "damage"], ["Hasar", "damage"], ["can", "health"], ["Can", "health"], ["kalkan", "shield"], ["Kalkan", "shield"]]:
		text = text.replace(str(kw[0]), "[color=%s]%s[/color]" % [ink[kw[1]], kw[0]])
	for pair: Array in [["mana", "kalkan"], ["Mana", "Kalkan"]]:
		text = text.replace("%s [color=%s]%s[/color]" % [pair[0], ink["shield"], pair[1]], "[color=%s]%s %s[/color]" % [ink["shield"], pair[0], pair[1]])
	for kw: Array in [["saldırı hızı", "attack_speed"], ["bekleme", "cooldown"]]:
		text = text.replace(str(kw[0]), "[color=%s]%s[/color]" % [ink[kw[1]], kw[0]])
	var re := RegEx.new()
	re.compile("(\\[[^\\]]*\\]|%?\\d+(?:[.,]\\d+)?(?:\\s*saniye|\\s*sn)?)")
	var res: String = ""
	var last: int = 0
	for m: RegExMatch in re.search_all(text):
		res += text.substr(last, m.get_start() - last)
		var s: String = m.get_string()
		res += s if s.begins_with("[") else "[color=%s]%s[/color]" % [ink["value"], s]
		last = m.get_end()
	return res + text.substr(last)


## ---------------------------------------------------------------- ortak parçalar
func _rich(bb: String, fs: int = BODY_FS, c: Color = C_TEXT) -> RichTextLabel:
	var r: RichTextLabel = HudTooltip.make_rich(fs, c)
	r.text = bb
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


## Yetenek ikonu kuyuda + köşede tuş harfi (seçili = altın kenar).
func _slot(e: Dictionary, box: float, sel: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _sb(C_INSET, C_ACCENT if sel else C_LINE_HI, 3, 4, 3.0))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ip: String = str(e["icon"])
	if ip != "" and ResourceLoader.exists(ip):
		p.add_child(_icon(load(ip) as Texture2D, box))
	else:
		var k0 := _lbl(str(e["key"]), 32, C_ACCENT, HORIZONTAL_ALIGNMENT_CENTER)
		k0.custom_minimum_size = Vector2(box, box)
		p.add_child(k0)
	var key := _lbl(str(e["key"]), 32 if box >= 64.0 else 24, C_ACCENT if sel else C_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	key.size_flags_horizontal = Control.SIZE_SHRINK_END
	key.size_flags_vertical = Control.SIZE_SHRINK_END
	key.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	key.add_theme_constant_override("shadow_offset_x", 2)
	p.add_child(key)
	return p


## Tür etiketi + saat simgesi + bekleme süresi.
func _meta(e: Dictionary) -> HBoxContainer:
	var h := _h(10)
	h.add_child(HudTooltip.make_tag(str(e["kind"])))
	if str(e["cd"]) != "":
		h.add_child(_sp(4))
		var ic := TextureRect.new()
		ic.texture = CD_ICON
		ic.custom_minimum_size = Vector2(24, 24)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		h.add_child(_lbl(str(e["cd"]), 32, Color(str(HT.INK["cooldown"]))))
	return h


## Notu ("maksimum canının %4'ünü harcar", "Basılıp kapatılabilir") ayrı soluk satır, açıklama tam metin.
func _body_box(e: Dictionary) -> VBoxContainer:
	var v := _v(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if str(e["note"]) != "":
		v.add_child(_rich("[color=#%s]%s[/color]" % [C_DIM.to_html(false), _lol(str(e["note"]))], BODY_FS, C_DIM))
	v.add_child(_rich(_lol(str(e["body"]))))
	return v


func _stat_chips(it: Dictionary, cols: int) -> GridContainer:
	var bs: Dictionary = Characters.get_base_stats(int(it["key"]))
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 22)
	g.add_theme_constant_override("v_separation", 6)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var atk: int = int(bs.get("atk", 0))
	for row: Array in [["max_health", "Can", str(int(bs.get("hp", 100)))], ["speed", "Hız", str(int(bs.get("speed", 252)))],
			["damage", "Saldırı Gücü", str(int(bs.get("ap", 10)))], ["fire_rate", "Saldırı Hızı", ("%+d%%" % atk) if atk != 0 else "%0"]]:
		var h := _h(8)
		h.add_child(_icon(_stat_tex(row[0]), 32))
		var v := _v(-6)
		v.add_child(_lbl(row[2], 32, C_TEXT))
		v.add_child(_lbl(row[1], 16, C_DIM))
		h.add_child(v)
		g.add_child(h)
	return g


## Küçük sahne (figür) + sağında ad, tür, statlar.
func _compact_head(it: Dictionary, sw: float, shh: float, fig_h: float) -> HBoxContainer:
	var h := _h(18)
	var st := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 8)
	st.custom_minimum_size = Vector2(sw, shh)
	st.clip_contents = true
	st.add_child(StageBg.new(C_SPOT, C_ACCENT, 24.0))
	var hold := Control.new()
	hold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.add_child(hold)
	_anim_nodes["stage"] = st
	var spr: TextureRect = _stage_figure(hold, _with_tex(it), fig_h, 24.0)
	if spr != null:
		_anim_nodes["figure"] = spr
	h.add_child(st)
	var col := _v(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_gold_title(str(it["name"])))
	col.add_child(_lbl("Karakter", 32, C_DIM))
	col.add_child(_sp(0, 6))
	col.add_child(_stat_chips(it, 2))
	h.add_child(col)
	return h


func _scroll_of(c: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(c)
	return sc


func _on_sk(i: int) -> void:
	if i == sk_sel:
		return
	sk_sel = i
	_rebuild_list()


## ---------------------------------------------------------------- A: YETENEK SEKMELERİ (LoL şampiyon sayfası)
## Küçük sahne + ad + statlar; altında P Q E R büyük ikon sekmeleri (fare üstüne gelince / tıklayınca / gamepad odağı seçer);
## seçilenin TAM açıklaması tek koyu kuyuda (ad, tür, bekleme, not, metin).
func _detail_a(it: Dictionary) -> Control:
	var ents: Array = _entries(it)
	sk_sel = clampi(sk_sel, 0, ents.size() - 1)
	var v := _v(14)
	v.add_child(_compact_head(it, 210, 214, 172))
	var tabs := _h(10)
	for i in ents.size():
		var e: Dictionary = ents[i]
		var on: bool = i == sk_sel
		var card := _box(Color(C_ACCENT, 0.12) if on else Color(C_INSET, 0.55), C_ACCENT if on else C_LINE, 8, 3, 6)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ch := _h(10)
		ch.alignment = BoxContainer.ALIGNMENT_CENTER
		var ip: String = str(e["icon"])
		ch.add_child(_icon(load(ip) as Texture2D if ip != "" and ResourceLoader.exists(ip) else null, 48))
		var kc: PanelContainer = HudTooltip.make_keycap(str(e["key"]))
		kc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ch.add_child(kc)
		card.add_child(ch)
		var b: Button = _clickable(card, _on_sk.bind(i), "sk:%d" % i)
		b.mouse_entered.connect(_on_sk.bind(i))
		b.focus_entered.connect(_on_sk.bind(i))
		tabs.add_child(card)
	v.add_child(tabs)
	var e2: Dictionary = ents[sk_sel]
	var well := _box(C_INSET, C_ACCENT_DK, 18, 3, 6)
	well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var wv := _v(10)
	var hd := _h(12)
	var nm := FM.lbl(str(e2["name"]).to_upper(), 32, C_ACCENT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hd.add_child(nm)
	hd.add_child(_meta(e2))
	wv.add_child(hd)
	wv.add_child(HudTooltip.make_divider())
	wv.add_child(_body_box(e2))
	well.add_child(_scroll_of(wv))
	v.add_child(well)
	v.add_child(_buy_btn(it, 40, 76))
	return v


## ---------------------------------------------------------------- B: AÇILIR LİSTE (akordeon)
## Küçük sahne + ad + statlar; yetenekler alt alta başlık satırı (ikon, ad, tür, bekleme, ok); seçili satır açılır ve tam metni gösterir.
func _detail_b(it: Dictionary) -> Control:
	var ents: Array = _entries(it)
	sk_sel = clampi(sk_sel, 0, ents.size() - 1)
	var v := _v(8)
	v.add_child(_compact_head(it, 170, 172, 136))
	for i in ents.size():
		var e: Dictionary = ents[i]
		var on: bool = i == sk_sel
		var row := _box(Color(C_ACCENT, 0.08) if on else Color(C_INSET, 0.55), C_ACCENT_DK if on else C_LINE, 8, 3, 6)
		var rv := _v(8)
		var hp := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4)
		var hd := _h(12)
		hp.add_child(hd)
		hd.add_child(_slot(e, 48, on))
		var nm := FM.lbl(str(e["name"]), 32, C_ACCENT if on else C_TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hd.add_child(nm)
		hd.add_child(_meta(e))
		hd.add_child(Glyph.new(G_DOWN if on else G_RIGHT, C_ACCENT if on else C_DIM, 4))
		hd.add_child(_sp(4))
		rv.add_child(hp)
		if on:
			row.size_flags_vertical = Control.SIZE_EXPAND_FILL
			rv.add_child(HudTooltip.make_divider())
			rv.add_child(_scroll_of(_body_box(e)))
			rv.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(rv)
		_clickable(hp, _on_sk.bind(i), "sk:%d" % i)
		v.add_child(row)
	v.add_child(_buy_btn(it, 40, 76))
	return v


## ---------------------------------------------------------------- C: DEFTER SAYFALARI (GENEL / YETENEKLER)
## Üstte iki sekme. GENEL = büyük sahne + ad + statlar + yeteneklerin adları (satıra basınca YETENEKLER'e geçer);
## YETENEKLER = sahnesiz, dört yeteneğin tam metni alt alta (sığmazsa kayar).
func _detail_c(it: Dictionary) -> Control:
	var ents: Array = _entries(it)
	var v := _v(12)
	var tabs := _h(0)
	for pg: Array in [["genel", "GENEL"], ["yetenek", "YETENEKLER"]]:
		var on: bool = dpage == pg[0]
		var tp := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0, 4)
		tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tv := _v(0)
		tp.add_child(tv)
		var tl := FM.lbl(str(pg[1]), 32, C_ACCENT if on else C_DIM)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tl.custom_minimum_size.y = 46
		tv.add_child(tl)
		var ln := ColorRect.new()
		ln.color = C_ACCENT if on else C_LINE
		ln.custom_minimum_size.y = 6 if on else 3
		ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tv.add_child(ln)
		_clickable(tp, _on_page.bind(str(pg[0])), "pg:" + str(pg[0]))
		tabs.add_child(tp)
	v.add_child(tabs)
	if dpage == "genel":
		v.add_child(_detail_stage(it))
		var th := _h(14)
		th.add_child(_gold_title(str(it["name"])))
		var kl := _lbl("Karakter", 32, C_DIM)
		kl.size_flags_vertical = Control.SIZE_SHRINK_END
		th.add_child(kl)
		v.add_child(th)
		v.add_child(_stat_chips(it, 4))
		v.add_child(_sp(0, 4))
		for i in ents.size():
			var e: Dictionary = ents[i]
			var row := _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 2, 0, 4)
			var hd := _h(14)
			hd.add_child(_slot(e, 48, false))
			var nm := FM.lbl(str(e["name"]), 32, C_TEXT)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hd.add_child(nm)
			hd.add_child(_meta(e))
			hd.add_child(_sp(6))
			row.add_child(hd)
			_clickable(row, _on_page.bind("yetenek"), "skrow:%d" % i)
			v.add_child(row)
		v.add_child(_sp(0, 0, false, true))
	else:
		var list := _v(18)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for i in ents.size():
			var e: Dictionary = ents[i]
			if i > 0:
				list.add_child(HudTooltip.make_divider())
			var hd := _h(14)
			hd.add_child(_slot(e, 48, false))
			var nv := _v(2)
			nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nv.add_child(FM.lbl(str(e["name"]), 32, C_ACCENT))
			nv.add_child(_meta(e))
			hd.add_child(nv)
			list.add_child(hd)
			list.add_child(_body_box(e))
		var lm := MarginContainer.new()
		lm.add_theme_constant_override("margin_right", 18)
		lm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lm.add_child(list)
		var sc := _scroll_of(lm)
		_tag_sid(sc, "c_scroll")
		v.add_child(sc)
	v.add_child(_buy_btn(it, 40, 76))
	return v


func _on_page(pg: String) -> void:
	if pg == dpage:
		return
	dpage = pg
	_rebuild_list()


## ---------------------------------------------------------------- D: OYUN İÇİ İPUCU
## Büyük sahne + ad + statlar + yetenek satırları (ikon, ad, tür, bekleme; açıklama YOK). Fare üstüne gelince / gamepad odağında
## oyundaki yetenek ipucunun AYNISI (koyu levha, ikon + ad + tür + bekleme, ayraç, tam metin) satırın soluna açılır.
func _detail_d(it: Dictionary) -> Control:
	var ents: Array = _entries(it)
	var v := _v(12)
	v.add_child(_detail_stage(it))
	var th := _h(14)
	th.add_child(_gold_title(str(it["name"])))
	var kl := _lbl("Karakter", 32, C_DIM)
	kl.size_flags_vertical = Control.SIZE_SHRINK_END
	th.add_child(kl)
	v.add_child(th)
	v.add_child(_stat_chips(it, 4))
	v.add_child(_sp(0, 2))
	for i in ents.size():
		var e: Dictionary = ents[i]
		var row := _box(Color(C_INSET, 0.55), C_LINE, 8, 3, 6)
		var hd := _h(14)
		hd.add_child(_slot(e, 48, false))
		var nm := FM.lbl(str(e["name"]), 32, C_TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hd.add_child(nm)
		hd.add_child(_meta(e))
		hd.add_child(_sp(6))
		row.add_child(hd)
		var b: Button = _clickable(row, _show_tip.bind(i, row, e), "tip:%d" % i)
		b.mouse_entered.connect(_show_tip.bind(i, row, e))
		b.focus_entered.connect(_show_tip.bind(i, row, e))
		b.mouse_exited.connect(_hide_tip)
		b.focus_exited.connect(_hide_tip)
		v.add_child(row)
	var hint := _lbl("Yeteneğin üstüne gel: tam açıklama", 16, C_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(hint)
	v.add_child(_sp(0, 0, false, true))
	v.add_child(_buy_btn(it, 40, 76))
	return v


func _show_tip(i: int, row: Control, e: Dictionary) -> void:
	_hide_tip()
	if not is_instance_valid(row) or not row.is_inside_tree():
		return
	sk_sel = i
	var tip: PanelContainer = HudTooltip.make_panel(516.0)
	var vb := _v(9)
	tip.add_child(vb)
	var hd := _h(12)
	var iw := PanelContainer.new()
	iw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iw.add_theme_stylebox_override("panel", HudTooltip.well_style(3.0, 3.0))
	iw.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var ip: String = str(e["icon"])
	iw.add_child(_icon(load(ip) as Texture2D if ip != "" and ResourceLoader.exists(ip) else null, 48))
	hd.add_child(iw)
	var hc := _v(3)
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc.add_child(FM.lbl(str(e["name"]).to_upper(), 32, HT.ACCENT))
	hc.add_child(_meta(e))
	hd.add_child(hc)
	var kc: PanelContainer = HudTooltip.make_keycap(str(e["key"]))
	kc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hd.add_child(kc)
	vb.add_child(hd)
	vb.add_child(HudTooltip.make_divider())
	vb.add_child(_body_box(e))
	tip.modulate.a = 0.0
	add_child(tip)
	_tip = tip
	_place_tip(tip, row)


func _place_tip(tip: Control, row: Control) -> void:
	await get_tree().process_frame
	if not is_instance_valid(tip) or not is_instance_valid(row):
		return
	tip.reset_size()
	var r: Rect2 = row.get_global_rect()
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var x: float = r.position.x - tip.size.x - 24.0
	var y: float = clampf(r.get_center().y - tip.size.y * 0.5, 12.0, vs.y - tip.size.y - 12.0)
	tip.position = Vector2(roundf(x), roundf(y))
	tip.modulate.a = 1.0


func _hide_tip() -> void:
	if is_instance_valid(_tip):
		_tip.queue_free()
	_tip = null
