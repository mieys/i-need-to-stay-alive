extends "res://scripts/level_market_view.gd"

## PROTOTİP (oyuna bağlı DEĞİL, 2026-11-06): pazarda KAYITLI seçenek YEŞİL (kullanıcı: "kayıtlı eşyanın yeşil bir şekilde görünmesini
## istiyorum, komple uyumlu durmalı"). Gerçek level_market_view.gd'den türer; yalnız kayıtlı yuvanın/satırın görünüşünü, kilit
## düğmesini, ayrıntıdaki kayıt satırını ve kuyunun kenarını yeniden boyar. Yeşil artık YALNIZ "kayıtlı" demek: silah geliştirme
## satırlarının eski yeşil tür kenarı (TAG_WUP) bütün varyantlarda silahın turuncusuna (TAG_WEAPON) döner.
##   A Yosun Kenar   - yeşil kenar + yeşil "KAYITLI" + yeşil kilit
##   B Yosun Kuyu    - A + yuvanın içi koyu yosun tonu
##   C Kilitli Etiket - yeşil kenar + kilit simgeli yeşil etiket (yazı yerine)
##   D Köşe Kilidi   - yeşil kenar + yazı yok, kilit düğmesinin yerinde hep duran yeşil kilit rozeti
## Renkler paletten türetilir (HudTheme.GOOD ve INSET karışımları), kitte yeni rol açılmadan önce bakmak için.

const HT := preload("res://scripts/hud_theme.gd")
const G_TEXT := HT.GOOD ## #b5d98a: kayıt yazısı / simgesi (paletteki "iyi" yeşili)
const G_RIM := Color("#8fb466") ## kenar: GOOD'un bir ton koyusu (turuncu/mavi/mor tür kenarlarıyla karışmaz)
const G_DK := Color("#3d5126") ## koyu yosun: düğme / etiket kenarı
const G_BTN := Color("#7c9f52") ## kayıtlı kilit düğmesi dolgusu
const G_PILL := Color("#2c3a1b") ## etiket zemini (INSET -> yosun)

var variant: String = "A"


func _fill(section: String, i: int) -> void:
	super._fill(section, i)
	var b: Control = _slot_node(section, i)
	if b == null:
		return
	for n: String in ["ProtoPill", "ProtoBadge"]:
		var old: Node = b.get_node_or_null(n)
		if old:
			b.remove_child(old)
			old.queue_free()
	var e: Dictionary = _offer(section, i)
	var face: PanelContainer = b.get_node_or_null("Face")
	if e.is_empty() or face == null or _ban_armed == _key(section, i):
		return
	var saved: bool = Market.is_saved(e)
	var hov: bool = _hover == [section, i]
	var sold: bool = bool(e.get("sold", false))
	var fill: Color = _k.c("panel2") if hov else _k.c("inset")
	if not saved:
		if str(e.get("type", "")) in ["wupgrade", "wplus"]:
			face.add_theme_stylebox_override("panel", _k.sb(fill, Color(Market.TAG_WEAPON, 1.0 if hov else 0.75), 3, 6, 6.0))
		return
	if variant == "B":
		fill = HT.INSET.lerp(Color("#3a4c22"), 0.42 if hov else 0.34)
	face.add_theme_stylebox_override("panel", _k.sb(fill, G_RIM if hov else Color(G_RIM, 0.9), 3, 6, 6.0))
	var tag: Label = null
	for l: Node in face.find_children("*", "Label", true, false):
		if (l as Label).text == "KAYITLI":
			tag = l
	var show_tag: bool = not (hov and not sold)
	match variant:
		"A", "B":
			if tag:
				tag.add_theme_color_override("font_color", G_TEXT)
		"C":
			if tag:
				if section == "items":
					tag.text = "" ## boy aynı kalır, etiket üstte bindirilir
					if show_tag:
						var pill: PanelContainer = _pill()
						pill.name = "ProtoPill"
						b.add_child(pill)
						pill.size = pill.get_combined_minimum_size()
						pill.position = Vector2(floorf((SLOT_SIZE.x - pill.size.x) * 0.5), 5.0)
				else:
					var par: Node = tag.get_parent()
					var idx: int = tag.get_index()
					var pill2: PanelContainer = _pill()
					pill2.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
					par.add_child(pill2)
					par.move_child(pill2, idx)
					par.remove_child(tag)
					tag.queue_free()
		"D":
			if tag:
				tag.text = ""
			if show_tag:
				var badge: PanelContainer = PanelContainer.new()
				badge.name = "ProtoBadge"
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				badge.add_theme_stylebox_override("panel", _k.sb(G_BTN, G_DK, 3, 4, 0.0))
				var cc := CenterContainer.new()
				cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cc.add_child(_k.glyph(DarkKit.G_LOCK, HT.ACCENT_TEXT, 2))
				badge.add_child(cc)
				b.add_child(badge)
				badge.size = Vector2(TOOL_SIZE, TOOL_SIZE)
				var w: float = b.custom_minimum_size.x
				badge.position = Vector2(6, 6) if section == "items" else Vector2(w - TOOL_SIZE * 2.0 - 12.0, 6)
	## kilit düğmesi (üstündeyken): kayıtlıyken altın yerine yeşil
	var tools: Control = b.get_node_or_null("Tools")
	if tools:
		var lock: Button = tools.get_node("Lock")
		lock.add_theme_stylebox_override("normal", _k.sb(G_BTN, G_DK, 3, 4, 10.0))
		lock.add_theme_stylebox_override("hover", _k.sb(G_BTN.lightened(0.1), G_DK, 3, 4, 10.0))
		lock.add_theme_stylebox_override("pressed", _k.sb(G_BTN.darkened(0.12), G_DK, 3, 4, 10.0))
		_tint_glyph(lock, HT.ACCENT_TEXT)
		b.move_child(tools, b.get_child_count() - 1)


func _pill() -> PanelContainer:
	var p: PanelContainer = _k.box(G_PILL, G_RIM, 0.0, 2, 3)
	var st: StyleBox = p.get_theme_stylebox("panel")
	st.content_margin_left = 6.0
	st.content_margin_right = 8.0
	st.content_margin_top = 0.0
	st.content_margin_bottom = 4.0 ## m5x7 24 satırın altı etiketten taşıyordu
	var r: HBoxContainer = _k.h(6)
	var g: Control = _k.glyph(DarkKit.G_LOCK, G_TEXT, 2)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(g)
	r.add_child(_k.lbl("KAYITLI", 24, G_TEXT))
	p.add_child(r)
	return p


func _status_line(pat: Array, col: Color, t: String) -> HBoxContainer:
	return super._status_line(pat, col, t) ## madde 433 sonrası temel görünüm zaten yeşil yazar


func _refresh_detail() -> void:
	super._refresh_detail()
	if _detail == null or _detail.get_child_count() == 0:
		return
	var section: String = str(_focus[0]) if _focus.size() == 2 else "items"
	var i: int = int(_focus[1]) if _focus.size() == 2 else 0
	var e: Dictionary = _offer(section, i)
	var well: PanelContainer = _detail.get_child(0) as PanelContainer
	if e.is_empty() or well == null:
		return
	if Market.is_saved(e):
		var fill: Color = HT.INSET.lerp(Color("#3a4c22"), 0.34) if variant == "B" else _k.c("inset")
		well.add_theme_stylebox_override("panel", _k.sb(fill, G_RIM, 3, 6, 6.0))
	elif str(e.get("type", "")) in ["wupgrade", "wplus"]:
		well.add_theme_stylebox_override("panel", _k.sb(_k.c("inset"), Color(Market.TAG_WEAPON, 0.6), 3, 6, 6.0))
