extends "res://scripts/level_market_view.gd"

## PAZAR YENİ TASARIM prototipleri (2026-11-08, kullanıcı: "bu pazarın tasarımı için çerçeveler ve renkler haricinde herşeyin komple
## değiştiği 4 yeni prototip hazırlar mısın"). OYUNA BAĞLI DEĞİL.
## Gerçek level_market_view.gd'den TÜRER: veri (Market.describe / fiyat / tarif ağacı), kit, simge / fiyat çizicileri, kaydet-yasak düğmeleri
## aynı; ÇERÇEVE = madde 462 envanter çift ahşap çerçevesi (dış RIM + OUTLINE, iç panel + RIM_LO), RENKLER = hud_theme / kit. Yerleşim, yuva
## biçimi, ayrıntı alanı ve akış her varyantta baştan:
##   A Tezgâh Rafları - üstte iki raf (6 eşya TEK SIRA + 3 geliştirme yan yana, altlarında ahşap raf tahtası), altta YATAY ayrıntı şeridi
##                      (simge | ad + açıklama | tarif | fiyat + SATIN AL); Karıştır solda, DEVAM sağ altta
##   B Dükkân Listesi - solda 9 satırlık LİSTE (Stardew dükkânı gibi; GELİŞTİRMELER / EŞYALAR başlıklı iki grup, satır = simge + ad + tür +
##                      fiyat), sağda BÜYÜK ÖNİZLEME (simge 192, ad 48, açıklama 32, tarif, SATIN AL)
##   C Kart Vitrini   - ayrıntı paneli YOK: 9 kendi kendine yeten kart (simge + ad + açıklamanın ilk satırı + fiyat + kartın kendi SATIN AL /
##                      GELİŞTİR düğmesi), sağda dikey RAY (bakiye levhası, Karıştır, yasak hakkı, DEVAM)
##   D Vitrin Sahnesi - ortada SAHNE: seçilen tek şey büyük (simge 240, raf tahtası, ad 48, açıklama, tarif, SATIN AL), altta 9 küçük yuvalık
##                      ŞERİT (3 geliştirme | 6 eşya); Karıştır / DEVAM şeridin altında iki uçta
## Kullanım: pazar_yeni_capture.gd (pick = seçili, saved = kayıtlı gösterimi).

var variant: String = "A"
var pick: Array = ["items", 2]

const PLANK := [[HudTheme.RIM_HI, 3.0], [HudTheme.RIM, 6.0], [HudTheme.OUTLINE, 3.0]]


func setup_market(player: Node, _level: int, given: Dictionary = {}) -> void:
	mode = "market"
	_base(player)
	offers = given
	## C ailesinde + B2/B4'te seçili = alınabilen ilk kayıtsız eşya (altın düğme görünsün); B1/B3 tarifli + alınamayanı gösterir
	if (variant.length() == 2 and variant.begins_with("C")) or variant in ["B2", "B4"]:
		for i in _list("items").size():
			var e: Dictionary = _list("items")[i]
			if not Market.is_saved(e) and Market.block_reason(_player, e) == "":
				pick = ["items", i]
				break
	_focus = pick
	call("_build_" + variant)
	UISound.connect_all_buttons(self)


## ---------------------------------------------------------------- ortak parçalar
## Madde 462 çerçevesi: dış RIM + OUTLINE (pay 8), iç panel + RIM_LO.
func _frame(rect: Rect2, nm: String, pad: float = 14.0) -> PanelContainer:
	var rb: PanelContainer = _k.box(HudTheme.RIM, HudTheme.OUTLINE, 8, 4, 6)
	rb.name = nm
	_place(self, rb, rect.position, rect.size)
	var win: PanelContainer = _k.box(_k.c("panel"), HudTheme.RIM_LO, pad, 3, 4)
	rb.add_child(win)
	return win


func _list(section: String) -> Array:
	return offers.get(section, [])


func _d(e: Dictionary) -> Dictionary:
	return Market.describe(e, _player)


func _sel(section: String, i: int) -> bool:
	return pick == [section, i]


func _picked() -> Dictionary:
	return _offer(str(pick[0]), int(pick[1]))


## [kenar, dolgu]: kademe/tür rengi; seçili altın + PANEL3; kayıtlı yosun (madde 433).
func _rim_fill(e: Dictionary, d: Dictionary, sel: bool, base_fill: Color) -> Array:
	var rim: Color = Color(d["tag_col"], 0.75)
	var fill: Color = base_fill
	if sel:
		rim = _k.c("accent")
		fill = _k.c("panel3")
	if Market.is_saved(e):
		rim = HudTheme.SAVED_EDGE
		fill = HudTheme.SAVED_FILL_HOVER if sel else HudTheme.SAVED_FILL
	return [rim, fill]


func _plank() -> VBoxContainer:
	var p: VBoxContainer = _k.v(0)
	for spec: Array in PLANK:
		var c := ColorRect.new()
		c.color = spec[0]
		c.custom_minimum_size = Vector2(0, float(spec[1]))
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(c)
	return p


func _purse(fs: int = 32) -> HBoxContainer:
	var r: HBoxContainer = _k.h(18)
	r.add_child(_k.amt(GameManager.gold, fs, _k.c("price")))
	r.add_child(_k.amt(GameManager.weapon_shards, fs, DarkKit.SHARD_TEXT, "shard"))
	return r


func _reroll(w: float) -> Button:
	var b: Button = _k.row_btn(_die_row(Market.reroll_cost(shop_rerolls)), "ghost", 56, w)
	b.name = "MarketReroll"
	return b


func _bans() -> HBoxContainer:
	var r: HBoxContainer = _k.h(8)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var g: Control = _k.glyph(DarkKit.G_X, _k.c("bad"), 3)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(g)
	r.add_child(_k.lbl(tr("YASAK HAKKI %d/%d") % [Market.bans_left(), Market.BAN_LIMIT], 24, _k.c("text")))
	return r


func _go(w: float, h: float) -> Button:
	var b: Button = _k.btn("DEVAM ET", "primary", 40, h, w)
	b.name = "MarketContinue"
	return b


## Kaydet + yasakla (fare üstündeyken; prototipte seçili öğede gösterilir).
func _tools() -> HBoxContainer:
	var r: HBoxContainer = _k.h(6)
	r.add_child(_proto_tool("Lock", DarkKit.G_LOCK, _k.c("text")))
	r.add_child(_proto_tool("Ban", DarkKit.G_X, _k.c("bad")))
	return r


## Eski satır köşesi araç düğmesi (oyundaki `_tool_btn` madde 472'da kalktı; prototip kendi kopyasını kullanır).
func _proto_tool(n: String, pat: Array, col: Color) -> Button:
	var b := Button.new()
	b.name = n
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(32, 32)
	b.size = b.custom_minimum_size
	_k.btn_style(b, "ghost", 4)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(_k.glyph(pat, col, 2))
	b.add_child(cc)
	return b


func _verb(e: Dictionary) -> String:
	return {"wupgrade": "GELİŞTİR", "wplus": "GELİŞTİR", "upgrade": "GELİŞTİR"}.get(str(e["type"]), "SATIN AL")


func _buy_row(e: Dictionary, btn_w: float, fs: int = 32, h: float = 56.0) -> HBoxContainer:
	var r: HBoxContainer = _k.h(14)
	var pr: HBoxContainer = _price_row(e, fs, false)
	pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(pr)
	r.add_child(_k.sp(0, 0, true))
	var b: Button = _k.btn(_verb(e), "primary", fs, h, btn_w)
	b.disabled = Market.block_reason(_player, e) != ""
	r.add_child(b)
	return r


func _lines(d: Dictionary, w: float, fs: int = 32, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> VBoxContainer:
	var v: VBoxContainer = _k.v(6)
	for ln in d["lines"]:
		v.add_child(_k.wrap(str(ln), fs, _k.c("text"), w, align))
	return v


## Eşyanın doğrudan alt parçaları (seyyar satıcının ağacı, tek kat); tarifsizse boş.
func _recipe(e: Dictionary, area: Vector2) -> Control:
	if str(e["type"]) != "item" or (Items.recipe(str(e["key"])) as Array).is_empty():
		return null
	return RecipeTree.fit_row(_k, RecipeTree.data(str(e["key"]), RecipeTree.owned_pool(), false, true, RECIPE_LEVELS), area,
			RECIPE_SIZES, RECIPE_FS)


func _saved_tag(fs: int = 16) -> HBoxContainer:
	var r: HBoxContainer = _k.h(6)
	var g: Control = _k.glyph(DarkKit.G_LOCK, HudTheme.SAVED, 2)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(g)
	r.add_child(_k.lbl("KAYITLI", fs, HudTheme.SAVED))
	return r


func _well(d: Dictionary, e: Dictionary, icon: float, pad: float) -> PanelContainer:
	var saved: bool = Market.is_saved(e)
	var w: PanelContainer = _k.box(HudTheme.SAVED_FILL if saved else _k.c("inset"),
			HudTheme.SAVED_EDGE if saved else Color(d["tag_col"], 0.75), pad, 3, 6)
	w.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	w.add_child(_k.center(_icon(d, icon)))
	return w


## ================================================================ A - Tezgâh Rafları
const A_TILE := Vector2(232, 236)
const A_UPG := Vector2(482, 112)


func _build_A() -> void:
	var win: PanelContainer = _frame(Rect2(200, 78, 1520, 540), "ShelfWindow")
	var v: VBoxContainer = _k.v(10)
	win.add_child(v)
	var head: HBoxContainer = _k.h(12)
	head.add_child(_sec_head(DarkKit.G_BAG, "EŞYALAR"))
	head.add_child(_k.sp(0, 0, true))
	head.add_child(_purse(32))
	v.add_child(head)
	var shelf: HBoxContainer = _k.h(12)
	for i in _list("items").size():
		shelf.add_child(_tile_A(_list("items")[i], i))
	v.add_child(shelf)
	v.add_child(_plank())
	v.add_child(_sec_head(DarkKit.G_HAMMER, "GELİŞTİRMELER"))
	var ur: HBoxContainer = _k.h(12)
	for i in _list("upgrades").size():
		ur.add_child(_upg_A(_list("upgrades")[i], i))
	v.add_child(ur)
	v.add_child(_plank())
	var dwin: PanelContainer = _frame(Rect2(200, 630, 1520, 206), "DetailStrip")
	dwin.add_child(_strip_A())
	var bottom: HBoxContainer = _k.h(20)
	bottom.add_child(_reroll(340))
	bottom.add_child(_bans())
	_place(self, bottom, Vector2(200, 852))
	_place(self, _go(400, 60), Vector2(1320, 852), Vector2(400, 60))


func _tile_A(e: Dictionary, i: int) -> Control:
	var d: Dictionary = _d(e)
	var sel: bool = _sel("items", i)
	var rf: Array = _rim_fill(e, d, sel, _k.c("inset"))
	var box: PanelContainer = _k.box(rf[1], rf[0], 10, 6 if sel else 3, 6)
	box.custom_minimum_size = A_TILE
	var v: VBoxContainer = _k.v(4)
	box.add_child(v)
	var top: HBoxContainer = _k.h(6)
	top.custom_minimum_size.y = 32
	if Market.is_saved(e):
		top.add_child(_saved_tag())
	else:
		top.add_child(_k.lbl(str(d.get("kind", "")), 16, _k.c("dim")))
	top.add_child(_k.sp(0, 0, true))
	if sel:
		top.add_child(_tools())
	v.add_child(top)
	v.add_child(_k.center(_icon(d, 112)))
	v.add_child(_k.clip(str(d["name"]), 24, _k.c("text"), A_TILE.x - 24, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_k.sp(0, 0, false, true))
	v.add_child(_price_row(e, 24, true))
	return box


func _upg_A(e: Dictionary, i: int) -> Control:
	var d: Dictionary = _d(e)
	var sel: bool = _sel("upgrades", i)
	var rf: Array = _rim_fill(e, d, sel, _k.c("inset"))
	var box: PanelContainer = _k.box(rf[1], rf[0], 10, 6 if sel else 3, 6)
	box.custom_minimum_size = A_UPG
	var r: HBoxContainer = _k.h(14)
	box.add_child(r)
	var ic: CenterContainer = _k.center(_icon(d, 80))
	ic.custom_minimum_size.x = 88
	r.add_child(ic)
	var v: VBoxContainer = _k.v(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_k.clip(str(d["name"]), 24, HudTheme.ACCENT_SOFT, 230))
	v.add_child(_k.clip(str(d.get("row_sub", d["sub"])), 32, _k.c("text"), 230))
	r.add_child(v)
	var rv: VBoxContainer = _k.v(8)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_child(_k.lbl(str(d.get("row_badge", "")), 24, _k.c("dim"), HORIZONTAL_ALIGNMENT_RIGHT))
	rv.add_child(_price_row(e, 24, false))
	r.add_child(rv)
	return box


func _strip_A() -> Control:
	var e: Dictionary = _picked()
	var d: Dictionary = _d(e)
	var h: HBoxContainer = _k.h(22)
	var well: PanelContainer = _well(d, e, 128, 8)
	well.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(well)
	var tv: VBoxContainer = _k.v(4)
	tv.custom_minimum_size.x = 600
	tv.add_child(_k.clip(str(d["name"]), 40, _k.c("text"), 600))
	if str(d["sub"]) != "":
		tv.add_child(_k.clip(str(d["sub"]), 24, _k.c("dim"), 600))
	tv.add_child(_lines(d, 600))
	h.add_child(tv)
	var rec: Control = _recipe(e, Vector2(330, 120))
	var rv: VBoxContainer = _k.v(6)
	rv.custom_minimum_size.x = 330
	if rec:
		rv.add_child(_k.lbl("TARİF", 24, _k.c("dim")))
		rv.add_child(_k.center(rec))
	h.add_child(rv)
	var bv: VBoxContainer = _k.v(8)
	bv.custom_minimum_size.x = 300
	if Market.is_saved(e):
		bv.add_child(_saved_tag(24))
	bv.add_child(_k.sp(0, 0, false, true))
	var pr: HBoxContainer = _price_row(e, 32, true)
	bv.add_child(pr)
	var b: Button = _k.btn(_verb(e), "primary", 32, 56, 300)
	b.disabled = Market.block_reason(_player, e) != ""
	bv.add_child(b)
	h.add_child(bv)
	return h


## ================================================================ B - Dükkân Listesi
const B_LIST_W := 640.0


func _build_B() -> void:
	var win: PanelContainer = _frame(Rect2(250, 60, 1420, 792), "ListWindow")
	var h: HBoxContainer = _k.h(18)
	win.add_child(h)
	var lb: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 12, 3, 6)
	lb.custom_minimum_size.x = B_LIST_W
	h.add_child(lb)
	var lv: VBoxContainer = _k.v(6)
	lb.add_child(lv)
	lv.add_child(_sec_head(DarkKit.G_HAMMER, "GELİŞTİRMELER"))
	for i in _list("upgrades").size():
		lv.add_child(_row_B(_list("upgrades")[i], "upgrades", i))
	lv.add_child(_k.sp(0, 8))
	lv.add_child(_sec_head(DarkKit.G_BAG, "EŞYALAR"))
	for i in _list("items").size():
		lv.add_child(_row_B(_list("items")[i], "items", i))
	h.add_child(_preview_B())
	var bottom: HBoxContainer = _k.h(20)
	bottom.add_child(_reroll(340))
	bottom.add_child(_bans())
	_place(self, bottom, Vector2(250, 866))
	_place(self, _go(400, 56), Vector2(1270, 866), Vector2(400, 56))


func _row_B(e: Dictionary, section: String, i: int) -> Control:
	var d: Dictionary = _d(e)
	var sel: bool = _sel(section, i)
	var rf: Array = _rim_fill(e, d, sel, Color(_k.c("panel3"), 0.35) if i % 2 == 0 else Color(0, 0, 0, 0))
	var edge: Color = rf[0] if (sel or Market.is_saved(e)) else Color(0, 0, 0, 0)
	var box: PanelContainer = _k.box(rf[1], edge, 8, 3, 6)
	box.custom_minimum_size.y = 64
	var r: HBoxContainer = _k.h(14)
	box.add_child(r)
	## kademe/tür rengi satırın solunda ince şerit (liste satırında kenar yerine)
	var stripe := ColorRect.new()
	stripe.color = Color(d["tag_col"], 0.85)
	stripe.custom_minimum_size = Vector2(6, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(stripe)
	var ic: CenterContainer = _k.center(_icon(d, 48))
	ic.custom_minimum_size.x = 52
	r.add_child(ic)
	var v: VBoxContainer = _k.v(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if section == "upgrades":
		v.add_child(_k.clip(str(d["name"]), 16, HudTheme.ACCENT_SOFT, 300))
		v.add_child(_k.clip(str(d.get("row_sub", d["sub"])), 32, _k.c("text"), 300))
	else:
		v.add_child(_k.clip(str(d["name"]), 32, _k.c("text"), 300))
	r.add_child(v)
	if Market.is_saved(e):
		var st: HBoxContainer = _saved_tag()
		st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(st)
	var tag: Label = _k.lbl(str(d.get("row_badge", "")) if section == "upgrades" else str(d.get("kind", "")), 16, _k.c("dim"))
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(tag)
	var pr: HBoxContainer = _price_row(e, 24, false)
	pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.custom_minimum_size.x = 120
	pr.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(pr)
	return box


func _preview_B() -> Control:
	var e: Dictionary = _picked()
	var d: Dictionary = _d(e)
	var pv: PanelContainer = _k.box(_k.c("panel2"), HudTheme.SAVED_EDGE if Market.is_saved(e) else d["tag_col"], 18, 3, 6)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = _k.v(10)
	pv.add_child(v)
	var top: HBoxContainer = _k.h(12)
	if Market.is_saved(e):
		top.add_child(_saved_tag(24))
	top.add_child(_k.sp(0, 0, true))
	top.add_child(_tools())
	v.add_child(top)
	v.add_child(_well(d, e, 160, 12))
	v.add_child(_k.clip(str(d["name"]), 48, _k.c("text"), 660, HORIZONTAL_ALIGNMENT_CENTER))
	if str(d["sub"]) != "":
		v.add_child(_k.clip(str(d["sub"]), 24, _k.c("dim"), 660, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_k.hline())
	v.add_child(_lines(d, 660))
	var rec: Control = _recipe(e, Vector2(660, 120))
	if rec:
		v.add_child(_k.lbl("TARİF", 24, _k.c("dim")))
		v.add_child(_k.center(rec))
	v.add_child(_k.sp(0, 0, false, true))
	var top_purse: HBoxContainer = _purse(24)
	top_purse.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(top_purse)
	v.add_child(_buy_row(e, 320))
	return pv


## ================================================================ C - Kart Vitrini
const C_CARD := Vector2(410, 226)
const C_UPG := Vector2(410, 200)
const C_RAIL := 300.0


func _build_C() -> void:
	var win: PanelContainer = _frame(Rect2(140, 66, 1640, 840), "CardWindow")
	var h: HBoxContainer = _k.h(18)
	win.add_child(h)
	var cv: VBoxContainer = _k.v(10)
	h.add_child(cv)
	cv.add_child(_sec_head(DarkKit.G_HAMMER, "GELİŞTİRMELER"))
	var ur: HBoxContainer = _k.h(14)
	for i in _list("upgrades").size():
		ur.add_child(_card_C(_list("upgrades")[i], "upgrades", i))
	cv.add_child(ur)
	cv.add_child(_k.sp(0, 4))
	cv.add_child(_sec_head(DarkKit.G_BAG, "EŞYALAR"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for i in _list("items").size():
		grid.add_child(_card_C(_list("items")[i], "items", i))
	cv.add_child(grid)
	## sağ ray: bakiye levhası, karıştır, yasak hakkı, ipucu, DEVAM
	var rail: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 14, 3, 6)
	rail.custom_minimum_size.x = C_RAIL
	h.add_child(rail)
	var rv: VBoxContainer = _k.v(14)
	rail.add_child(rv)
	var plaque: PanelContainer = _k.box(HudTheme.INSET, HudTheme.RIM_HI, 12, 3, 4)
	var pv: VBoxContainer = _k.v(6)
	pv.add_child(_k.amt(GameManager.gold, 32, _k.c("price")))
	pv.add_child(_k.amt(GameManager.weapon_shards, 32, DarkKit.SHARD_TEXT, "shard"))
	plaque.add_child(pv)
	rv.add_child(plaque)
	rv.add_child(_k.sp(0, 0, false, true))
	rv.add_child(_k.wrap("Kartın düğmesiyle al. Üstüne gel: kaydet ya da yasakla.", 24, _k.c("dim"), C_RAIL - 28.0))
	rv.add_child(_bans())
	rv.add_child(_reroll(C_RAIL - 28.0))
	rv.add_child(_go(C_RAIL - 28.0, 72))


func _card_C(e: Dictionary, section: String, i: int) -> Control:
	var d: Dictionary = _d(e)
	var sel: bool = _sel(section, i)
	var rf: Array = _rim_fill(e, d, sel, _k.c("inset"))
	var box: PanelContainer = _k.box(rf[1], rf[0], 14, 6 if sel else 3, 6)
	box.custom_minimum_size = C_UPG if section == "upgrades" else C_CARD
	var v: VBoxContainer = _k.v(8)
	box.add_child(v)
	var top: HBoxContainer = _k.h(14)
	var well: PanelContainer = _k.box(HudTheme.DEEP, Color(0, 0, 0, 0), 6, 0, 6)
	well.add_child(_k.center(_icon(d, 96)))
	well.custom_minimum_size = Vector2(108, 108)
	top.add_child(well)
	var tv: VBoxContainer = _k.v(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hr: HBoxContainer = _k.h(6)
	if Market.is_saved(e):
		hr.add_child(_saved_tag())
	elif section == "items":
		hr.add_child(_k.lbl(str(d.get("kind", "")), 16, _k.c("dim")))
	else:
		hr.add_child(_k.lbl(str(d.get("row_badge", "")), 16, _k.c("dim")))
	hr.add_child(_k.sp(0, 0, true))
	if sel:
		hr.add_child(_tools())
	hr.custom_minimum_size.y = 32
	tv.add_child(hr)
	if section == "upgrades":
		tv.add_child(_k.clip(str(d["name"]), 24, HudTheme.ACCENT_SOFT, 240))
		tv.add_child(_k.clip(str(d.get("row_sub", d["sub"])), 32, _k.c("text"), 240))
	else:
		tv.add_child(_k.clip(str(d["name"]), 32, _k.c("text"), 240))
	top.add_child(tv)
	v.add_child(top)
	if section == "items" and not (d["lines"] as Array).is_empty():
		var dl: Label = _k.wrap(str(d["lines"][0]), 24, _k.c("text"), C_CARD.x - 28.0)
		dl.max_lines_visible = 2
		dl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(dl)
	v.add_child(_k.sp(0, 0, false, true))
	v.add_child(_buy_row(e, 170, 24, 44))
	return box


## ================================================================ D - Vitrin Sahnesi
func _build_D() -> void:
	var stage: PanelContainer = _frame(Rect2(500, 46, 920, 660), "Stage", 22)
	var v: VBoxContainer = _k.v(8)
	stage.add_child(v)
	var e: Dictionary = _picked()
	var d: Dictionary = _d(e)
	## üst satır: yasak hakkı (HUD panelinin üstüne binmesin diye sahnede) + bakiye
	var top: HBoxContainer = _k.h(12)
	top.add_child(_bans())
	if Market.is_saved(e):
		top.add_child(_saved_tag(24))
	top.add_child(_k.sp(0, 0, true))
	top.add_child(_purse(24))
	v.add_child(top)
	var well: PanelContainer = _well(d, e, 144, 12)
	v.add_child(well)
	var pl: VBoxContainer = _plank()
	pl.custom_minimum_size.x = 300
	pl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pl)
	v.add_child(_k.clip(str(d["name"]), 48, _k.c("text"), 840, HORIZONTAL_ALIGNMENT_CENTER))
	if str(d["sub"]) != "":
		v.add_child(_k.clip(str(d["sub"]), 24, _k.c("dim"), 840, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lines(d, 820, 32, HORIZONTAL_ALIGNMENT_CENTER))
	var rec: Control = _recipe(e, Vector2(820, 96))
	if rec:
		v.add_child(_k.center(rec))
	v.add_child(_k.sp(0, 0, false, true))
	var br: HBoxContainer = _k.h(18)
	br.alignment = BoxContainer.ALIGNMENT_CENTER
	br.add_child(_tools())
	var pr: HBoxContainer = _price_row(e, 32, false)
	pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	br.add_child(pr)
	var b: Button = _k.btn(_verb(e), "primary", 32, 56, 320)
	b.disabled = Market.block_reason(_player, e) != ""
	br.add_child(b)
	v.add_child(br)
	var strip: PanelContainer = _frame(Rect2(240, 718, 1440, 178), "Strip", 14)
	var sh: HBoxContainer = _k.h(12)
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_child(sh)
	for i in _list("upgrades").size():
		sh.add_child(_thumb_D(_list("upgrades")[i], "upgrades", i))
	var div := ColorRect.new()
	div.color = HudTheme.RIM_LO
	div.custom_minimum_size = Vector2(3, 0)
	div.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dm: MarginContainer = MarginContainer.new()
	dm.add_theme_constant_override("margin_left", 12)
	dm.add_theme_constant_override("margin_right", 12)
	dm.add_child(div)
	sh.add_child(dm)
	for i in _list("items").size():
		sh.add_child(_thumb_D(_list("items")[i], "items", i))
	_place(self, _reroll(340), Vector2(240, 908))
	_place(self, _go(400, 56), Vector2(1280, 908), Vector2(400, 56))


func _thumb_D(e: Dictionary, section: String, i: int) -> Control:
	var d: Dictionary = _d(e)
	var sel: bool = _sel(section, i)
	var rf: Array = _rim_fill(e, d, sel, _k.c("inset"))
	var box: PanelContainer = _k.box(rf[1], rf[0], 6, 6 if sel else 3, 6)
	box.custom_minimum_size = Vector2(130, 140)
	var v: VBoxContainer = _k.v(2)
	box.add_child(v)
	v.add_child(_k.center(_icon(d, 80)))
	if section == "upgrades":
		v.add_child(_k.lbl(str(d.get("row_badge", "")), 16, _k.c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_k.sp(0, 0, false, true))
	v.add_child(_price_row(e, 24, true))
	return box


## ================================================================ C AİLESİ (C1-C4; 2026-11-08 kullanıcı: "C ye benzer daha çok prototip
## üret veya C yi geliştirip daha iyi hale getir"). C'nin özü korunur: ayrıntı paneli YOK, her kart kendi kendine yeter + kendi düğmesi.
## Hepsinde C'nin dertleri giderildi: sağ raydaki boş alan yok, açıklama 32 (24 "çok ufak" bulunmuştu), kademe rengi simge kuyusunda,
## 9 sarı düğme yerine yalnız seçili kartın düğmesi altın (diğerleri ahşap), "EŞYA" yazısı simgeyle.
##   C1 Sakin Izgara      - 3 x 3 eşit kart (1. sıra geliştirmeler), açıklama simgenin yanında; karıştır/DEVAM pencere dışında panelin iki yanında
##   C2 Dikey Kartlar     - 6 eşya evrim kartı dilinde DİKEY kart (kuyu + ortalı ad + açıklama kuyusu + tam genişlik düğme), altta 3 geliştirme + eylem
##   C3 Tarifli Kartlar   - solda geliştirme sütunu + bakiye/karıştır/DEVAM, sağda 2 x 3 geniş eşya kartı: PARÇALAR (sahip olunan yeşil tik)
##   C4 Fiyat Etiketli    - düğme yok: kartın altına asılı ahşap FİYAT ETİKETİ satın alır (seçili altın); geliştirmeler solda, eşyalar 3 x 2
const CF_RECT := Rect2(130, 30, 1660, 870) ## içerik 1616 x 826 (çerçeve 8 + iç pay 14)
const CF_FOOT_Y := 914.0 ## pencere dışı eylem satırı (oyuncu panelinin iki yanı: panel x 665-1255)


func _cf_tint(d: Dictionary) -> Color:
	return HudTheme.DEEP.lerp(Color(d["tag_col"]), 0.16)


## TUZAK (2026-11-08): "→" m5x7'de YOK (yedek fontla çizilir: ince, bulanık ve satırı uzatır -> Label'ın tek tip satır boyuyla
## hesaplanan yüksekliğine sığmaz, ellipsis 1. satıra düşer / 1 satırlık açıklama hiç çizilmez). "»" fontta var.
func _cf_txt(t: String) -> String:
	return t.replace("→", "»")


func _cf_kind(d: Dictionary, section: String) -> String:
	if section == "upgrades":
		return _cf_txt("%s  %s" % [str(d["name"]), str(d.get("row_badge", ""))])
	return str(d.get("kind", ""))


## Tür satırı: kayıtlıysa yeşil KAYITLI; değilse çekiç / heybe simgesi + tür (kademe rengine yakın).
func _cf_chip(e: Dictionary, d: Dictionary, section: String) -> HBoxContainer:
	if Market.is_saved(e):
		return _saved_tag()
	var r: HBoxContainer = _k.h(8)
	var col: Color = Color(d["tag_col"]).lerp(_k.c("text"), 0.3)
	var g: Control = _k.glyph(DarkKit.G_HAMMER if section == "upgrades" else DarkKit.G_BAG, col, 2)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(g)
	r.add_child(_k.lbl(_cf_kind(d, section), 16, col))
	return r


func _cf_card(e: Dictionary, d: Dictionary, sel: bool, sz: Vector2, pad: float = 14.0, r: int = 8) -> PanelContainer:
	var rf: Array = _rim_fill(e, d, sel, _k.c("inset"))
	var box: PanelContainer = _k.box(rf[1], rf[0], pad, 5 if sel else 3, r)
	box.custom_minimum_size = sz
	return box


## Kademe renkli simge kuyusu; büyük kartlarda tür + araçlar kuyunun köşelerinde (ayrı satır yer kaplamasın).
func _cf_well(e: Dictionary, d: Dictionary, section: String, sel: bool, sz: Vector2, icon: float, overlay: bool) -> PanelContainer:
	var w: PanelContainer = _k.box(_cf_tint(d), Color(0, 0, 0, 0), 0, 0, 6)
	w.custom_minimum_size = sz
	w.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_child(layer)
	var ic: CenterContainer = _k.center(_icon(d, icon))
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ic)
	if overlay:
		var chip: HBoxContainer = _cf_chip(e, d, section)
		chip.position = Vector2(10, 8)
		layer.add_child(chip)
		if sel:
			var t: HBoxContainer = _tools()
			t.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
			t.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			layer.add_child(t)
	return w


func _cf_desc(d: Dictionary, w: float, max_lines: int, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l: Label = _k.wrap(_cf_txt("\n".join(PackedStringArray(d["lines"]))), 32, _k.c("text"), w, align)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.max_lines_visible = max_lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


## Yalnız seçili kartın düğmesi altın; diğerleri ahşap (9 sarı düğme gürültüsü yok); alınamıyorsa kapalı.
func _cf_buy(e: Dictionary, sel: bool, w: float, h: float = 52.0) -> Button:
	var b: Button = _k.btn(_verb(e), "primary" if sel else "ghost", 32, h, w)
	b.disabled = Market.block_reason(_player, e) != ""
	return b


## Pencere dışı eylemler: solda bakiye levhası + karıştır, sağda yasak hakkı + DEVAM (oyuncu panelinin iki yanı).
func _cf_footer_out() -> void:
	var left: HBoxContainer = _k.h(14)
	var plaque: PanelContainer = _k.box(HudTheme.INSET, HudTheme.RIM_HI, 10, 3, 4)
	plaque.add_child(_purse(32))
	left.add_child(plaque)
	left.add_child(_reroll(250))
	_place(self, left, Vector2(CF_RECT.position.x, CF_FOOT_Y), Vector2(520, 64))
	var right: HBoxContainer = _k.h(18)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(_bans())
	right.add_child(_go(250, 72))
	_place(self, right, Vector2(1270, CF_FOOT_Y - 4.0), Vector2(CF_RECT.end.x - 1270.0, 72))


func _cf_buy_row(e: Dictionary, sel: bool, btn_w: float) -> HBoxContainer:
	var br: HBoxContainer = _k.h(14)
	var pr: HBoxContainer = _price_row(e, 32, false)
	pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	br.add_child(pr)
	br.add_child(_k.sp(0, 0, true))
	br.add_child(_cf_buy(e, sel, btn_w))
	return br


## Geliştirme/kart başı: [kuyu 96 | tür + araçlar, başlık, (ilk etki satırı)].
func _cf_upg_head(e: Dictionary, d: Dictionary, sel: bool, tw: float, effect_lines: int) -> HBoxContainer:
	var top: HBoxContainer = _k.h(14)
	top.add_child(_cf_well(e, d, "upgrades", false, Vector2(96, 96), 96, false))
	var tv: VBoxContainer = _k.v(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hr: HBoxContainer = _k.h(6)
	hr.custom_minimum_size.y = 32
	hr.add_child(_cf_chip(e, d, "upgrades"))
	hr.add_child(_k.sp(0, 0, true))
	if sel:
		hr.add_child(_tools())
	tv.add_child(hr)
	tv.add_child(_k.clip(str(d.get("row_sub", d["name"])), 32, _k.c("text"), tw))
	if effect_lines > 0:
		tv.add_child(_cf_desc({"lines": (d["lines"] as Array).slice(0, 1)}, tw, effect_lines))
	top.add_child(tv)
	return top


## ---------------------------------------------------------------- C1 Sakin Izgara
const C1_CARD := Vector2(530, 267)


func _build_C1() -> void:
	var win: PanelContainer = _frame(CF_RECT, "CardWindow")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	win.add_child(grid)
	for i in _list("upgrades").size():
		grid.add_child(_card_C1(_list("upgrades")[i], "upgrades", i))
	for i in _list("items").size():
		grid.add_child(_card_C1(_list("items")[i], "items", i))
	_cf_footer_out()


func _card_C1(e: Dictionary, section: String, i: int) -> Control:
	var d: Dictionary = _d(e)
	var sel: bool = _sel(section, i)
	var box: PanelContainer = _cf_card(e, d, sel, C1_CARD, 14)
	var v: VBoxContainer = _k.v(8)
	box.add_child(v)
	var tw: float = C1_CARD.x - 34.0 - 104.0 - 16.0
	if section == "upgrades":
		v.add_child(_cf_upg_head(e, d, sel, tw, 2))
	else:
		var top: HBoxContainer = _k.h(16)
		top.add_child(_cf_well(e, d, section, false, Vector2(104, 104), 96, false))
		var tv: VBoxContainer = _k.v(4)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hr: HBoxContainer = _k.h(6)
		hr.custom_minimum_size.y = 32
		hr.add_child(_cf_chip(e, d, section))
		hr.add_child(_k.sp(0, 0, true))
		if sel:
			hr.add_child(_tools())
		tv.add_child(hr)
		tv.add_child(_k.clip(str(d["name"]), 32, _k.c("text"), tw))
		tv.add_child(_cf_desc(d, tw, 2))
		top.add_child(tv)
		v.add_child(top)
	v.add_child(_k.sp(0, 0, false, true))
	v.add_child(_cf_buy_row(e, sel, 200))
	return box


## ---------------------------------------------------------------- C2 Dikey Kartlar
const C2_ITEM := Vector2(257, 470)
const C2_UPG_W := 404.0


func _build_C2() -> void:
	var win: PanelContainer = _frame(CF_RECT, "CardWindow")
	var v: VBoxContainer = _k.v(10)
	win.add_child(v)
	v.add_child(_sec_head(DarkKit.G_BAG, "EŞYALAR"))
	var ir: HBoxContainer = _k.h(14)
	for i in _list("items").size():
		ir.add_child(_card_C2(_list("items")[i], i))
	v.add_child(ir)
	v.add_child(_k.sp(0, 2))
	v.add_child(_sec_head(DarkKit.G_HAMMER, "GELİŞTİRMELER"))
	var br: HBoxContainer = _k.h(14)
	br.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in _list("upgrades").size():
		var e: Dictionary = _list("upgrades")[i]
		var d: Dictionary = _d(e)
		var sel: bool = _sel("upgrades", i)
		var box: PanelContainer = _cf_card(e, d, sel, Vector2(C2_UPG_W, 0), 12, 15)
		var uv: VBoxContainer = _k.v(6)
		box.add_child(uv)
		uv.add_child(_cf_upg_head(e, d, sel, C2_UPG_W - 30.0 - 96.0 - 14.0, 2))
		uv.add_child(_k.sp(0, 0, false, true))
		uv.add_child(_cf_buy_row(e, sel, 180))
		br.add_child(box)
	## eylem bloğu: bakiye levhası, yasak hakkı, karıştır, DEVAM
	var act: VBoxContainer = _k.v(10)
	act.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plaque: PanelContainer = _k.box(HudTheme.INSET, HudTheme.RIM_HI, 10, 3, 4)
	var pr: HBoxContainer = _purse(32)
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	plaque.add_child(pr)
	act.add_child(plaque)
	var bans: HBoxContainer = _bans()
	bans.alignment = BoxContainer.ALIGNMENT_CENTER
	act.add_child(bans)
	act.add_child(_k.sp(0, 0, false, true))
	act.add_child(_reroll(0))
	act.add_child(_go(0, 64))
	br.add_child(act)
	v.add_child(br)


func _card_C2(e: Dictionary, i: int) -> Control:
	var d: Dictionary = _d(e)
	var sel: bool = _sel("items", i)
	var box: PanelContainer = _cf_card(e, d, sel, C2_ITEM, 12, 15)
	var iw: float = C2_ITEM.x - 30.0
	var v: VBoxContainer = _k.v(8)
	box.add_child(v)
	v.add_child(_cf_well(e, d, "items", sel, Vector2(iw, 116), 96, true))
	var nm: Label = _k.wrap(str(d["name"]), 32, _k.c("text"), iw, HORIZONTAL_ALIGNMENT_CENTER)
	nm.max_lines_visible = 2
	v.add_child(nm)
	var dw: PanelContainer = _k.box(HudTheme.WIN_INSET, Color(0, 0, 0, 0), 8, 0, 8)
	dw.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dl: Label = _cf_desc(d, iw - 16.0, 4, HORIZONTAL_ALIGNMENT_CENTER)
	dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dw.add_child(dl)
	v.add_child(dw)
	v.add_child(_price_row(e, 32, true))
	v.add_child(_cf_buy(e, sel, 0))
	return box


## ---------------------------------------------------------------- C3 Tarifli Kartlar
const C3_LEFT := 430.0
const C3_UPG_H := 176.0
const C3_ITEM := Vector2(577, 244)


func _build_C3() -> void:
	var win: PanelContainer = _frame(CF_RECT, "CardWindow")
	var h: HBoxContainer = _k.h(18)
	win.add_child(h)
	var lv: VBoxContainer = _k.v(10)
	lv.custom_minimum_size.x = C3_LEFT
	h.add_child(lv)
	lv.add_child(_sec_head(DarkKit.G_HAMMER, "GELİŞTİRMELER"))
	for i in _list("upgrades").size():
		lv.add_child(_upg_C3(_list("upgrades")[i], i))
	lv.add_child(_k.sp(0, 0, false, true))
	lv.add_child(_reroll(C3_LEFT))
	lv.add_child(_go(C3_LEFT, 72))
	var rv: VBoxContainer = _k.v(10)
	h.add_child(rv)
	var head: HBoxContainer = _sec_head(DarkKit.G_BAG, "EŞYALAR")
	head.add_child(_k.sp(0, 0, true))
	head.add_child(_bans())
	head.add_child(_k.sp(10, 0))
	var plaque: PanelContainer = _k.box(HudTheme.INSET, HudTheme.RIM_HI, 6, 3, 4)
	plaque.add_child(_purse(32))
	head.add_child(plaque)
	rv.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for i in _list("items").size():
		grid.add_child(_card_C3(_list("items")[i], i))
	rv.add_child(grid)


func _upg_C3(e: Dictionary, i: int) -> Control:
	var d: Dictionary = _d(e)
	var sel: bool = _sel("upgrades", i)
	var box: PanelContainer = _cf_card(e, d, sel, Vector2(C3_LEFT, C3_UPG_H), 12)
	var v: VBoxContainer = _k.v(4)
	box.add_child(v)
	var top: HBoxContainer = _k.h(12)
	top.add_child(_cf_well(e, d, "upgrades", false, Vector2(96, 96), 96, false))
	var tv: VBoxContainer = _k.v(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hr: HBoxContainer = _k.h(6)
	hr.add_child(_cf_chip(e, d, "upgrades"))
	hr.add_child(_k.sp(0, 0, true))
	if sel:
		hr.add_child(_tools())
	tv.add_child(hr)
	tv.add_child(_k.clip(str(d.get("row_sub", d["name"])), 32, _k.c("text"), 170))
	tv.add_child(_price_row(e, 32, false))
	top.add_child(tv)
	var b: Button = _cf_buy(e, sel, 136)
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(b)
	v.add_child(top)
	v.add_child(_cf_desc({"lines": (d["lines"] as Array).slice(0, 1)}, C3_LEFT - 30.0, 1))
	return box


func _card_C3(e: Dictionary, i: int) -> Control:
	var d: Dictionary = _d(e)
	var sel: bool = _sel("items", i)
	var box: PanelContainer = _cf_card(e, d, sel, C3_ITEM, 14)
	var h: HBoxContainer = _k.h(16)
	box.add_child(h)
	## sol: kuyu + fiyat + düğme
	var lc: VBoxContainer = _k.v(6)
	lc.custom_minimum_size.x = 144
	lc.add_child(_cf_well(e, d, "items", false, Vector2(144, 104), 96, false))
	lc.add_child(_k.sp(0, 0, false, true))
	lc.add_child(_price_row(e, 32, true))
	lc.add_child(_cf_buy(e, sel, 144))
	h.add_child(lc)
	## sağ: tür + araçlar, ad, açıklama, PARÇALAR
	var tw: float = C3_ITEM.x - 34.0 - 144.0 - 16.0
	var rc: VBoxContainer = _k.v(6)
	rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hr: HBoxContainer = _k.h(10)
	hr.add_child(_cf_chip(e, d, "items"))
	if str(e["type"]) == "weapon":
		hr.add_child(_k.lbl(str(d["sub"]), 16, _k.c("dim")))
	hr.add_child(_k.sp(0, 0, true))
	if sel:
		hr.add_child(_tools())
	rc.add_child(hr)
	rc.add_child(_k.clip(str(d["name"]), 32, _k.c("text"), tw))
	var parts: Control = _parts_C3(e)
	rc.add_child(_cf_desc(d, tw, 2 if parts else 3))
	if parts:
		rc.add_child(_k.sp(0, 0, false, true))
		rc.add_child(parts)
	h.add_child(rc)
	return box


## Tarifin doğrudan parçaları: sahip olunan yeşil kenar + tik, eksik sönük (seyyar satıcının ağacının tek katlık özeti).
func _parts_C3(e: Dictionary) -> Control:
	if str(e["type"]) != "item":
		return null
	var rec: Array = Items.recipe(str(e["key"]))
	if rec.is_empty():
		return null
	var pool: Array = RecipeTree.owned_pool()
	var r: HBoxContainer = _k.h(8)
	var l: Label = _k.lbl("PARÇALAR", 16, _k.c("dim"))
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(l)
	for k in rec:
		var key: String = str(k)
		var have: bool = pool.has(key)
		if have:
			pool.erase(key)
		var w: PanelContainer = _k.box(HudTheme.SAVED_FILL if have else HudTheme.DEEP, _k.c("good") if have else _k.c("line"), 2, 2, 4)
		var layer := Control.new()
		layer.custom_minimum_size = Vector2(48, 48)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic: CenterContainer = _k.center(_k.icon(Items.icon(key), 48, not have))
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(ic)
		if have:
			var g: Control = _k.glyph(DarkKit.G_CHECK, _k.c("good"), 2)
			g.position = Vector2(34, 36)
			layer.add_child(g)
		w.add_child(layer)
		r.add_child(w)
	return r


## ---------------------------------------------------------------- C4 Fiyat Etiketli
const C4_LEFT := 400.0
const C4_TAB := Vector2(320, 56)
const C4_TAB_IN := 28.0 ## etiketin kartın içine binen payı (yarısı dışarı sarkar)


func _build_C4() -> void:
	var win: PanelContainer = _frame(CF_RECT, "CardWindow")
	var h: HBoxContainer = _k.h(18)
	win.add_child(h)
	var lv: VBoxContainer = _k.v(10)
	lv.custom_minimum_size.x = C4_LEFT
	h.add_child(lv)
	lv.add_child(_sec_head(DarkKit.G_HAMMER, "GELİŞTİRMELER"))
	for i in _list("upgrades").size():
		lv.add_child(_tag_card_C4(_list("upgrades")[i], "upgrades", i, Vector2(C4_LEFT, 253)))
	var rv: VBoxContainer = _k.v(10)
	h.add_child(rv)
	rv.add_child(_sec_head(DarkKit.G_BAG, "EŞYALAR"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	for i in _list("items").size():
		grid.add_child(_tag_card_C4(_list("items")[i], "items", i, Vector2(390, 386)))
	rv.add_child(grid)
	_cf_footer_out()


## Kart gövdesi + altına asılı fiyat etiketi (etiket = düğme: fiyat + fiil; seçili altın, diğerleri ahşap, alınamıyorsa kapalı).
func _tag_card_C4(e: Dictionary, section: String, i: int, sz: Vector2) -> Control:
	var d: Dictionary = _d(e)
	var sel: bool = _sel(section, i)
	var col: VBoxContainer = _k.v(int(-C4_TAB_IN))
	col.custom_minimum_size = sz
	var body: PanelContainer = _cf_card(e, d, sel, Vector2(sz.x, sz.y - (C4_TAB.y - C4_TAB_IN)), 14, 10)
	col.add_child(body)
	var v: VBoxContainer = _k.v(8)
	body.add_child(v)
	var iw: float = sz.x - 34.0
	if section == "items":
		v.add_child(_cf_well(e, d, section, sel, Vector2(iw, 112), 96, true))
		v.add_child(_k.clip(str(d["name"]), 32, _k.c("text"), iw, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(_cf_desc(d, iw, 4, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		v.add_child(_cf_upg_head(e, d, sel, iw - 110.0, 2))
	v.add_child(_k.sp(0, C4_TAB_IN - 8.0, false, true))
	## etiket
	var row: HBoxContainer = _k.h(16)
	var blocked: bool = Market.block_reason(_player, e) != ""
	if sel and not blocked:
		## altın etikette fiyat koyu yazı (altın üstünde altın / mavi parçacık okunmuyordu)
		var pr: HBoxContainer = _k.h(14)
		pr.add_child(_k.amt(Market.price(e), 32, _k.btn_tc("primary")))
		if Market.shards(e) > 0:
			pr.add_child(_k.amt(Market.shards(e), 32, _k.btn_tc("primary"), "shard"))
		row.add_child(pr)
	else:
		row.add_child(_price_row(e, 32, false))
	row.add_child(_k.lbl(_verb(e), 32, _k.c("dim") if blocked else _k.btn_tc("primary" if sel else "ghost")))
	var tab: Button = _k.row_btn(row, "primary" if sel else "ghost", C4_TAB.y, C4_TAB.x)
	tab.disabled = blocked
	col.add_child(_k.center(tab))
	return col


## ================================================================ B AİLESİ (B1-B4; 2026-11-08 kullanıcı: "dükkan listesini beğendim ancak daha iyi
## olabilir. 4 prototip hazırla buna ince ayar yaptığın"). B'nin iskeleti aynı: solda 9 satırlık liste (GELİŞTİRMELER / EŞYALAR), sağda büyük
## önizleme. Hepsinde B'nin dertleri giderildi: satırdaki 16'lık minik yazılar (silah adı, SİLAH/EŞYA, kademe) kalktı ya da 32 oldu, fiyat 24 -> 32,
## önizlemede fiyat solda / bakiye sağda dağınıktı -> tek yerde; kapalı SATIN AL yerine nedeni yazar ("600 altın eksik"); geliştirmede başlık
## geliştirmenin ADI (silah adı tür satırında); "→" -> "»" (m5x7'de ok yok).
##   B1 Sade Liste      - B'nin aynısı, cilalı: tür satırı + araçlar önizlemenin başında, HESAP şeridi (FİYAT / ELİNDE / KALAN), tam genişlik düğme
##   B2 Kutulu Bölmeler - envanter dili: GELİŞTİRMELER / EŞYALAR ayrı opak kutular, yuva çerçeveli simgeler; önizleme = envanter seçim kartı (ad levhası,
##                        simge + açıklama yan yana); eylemler pencerenin içinde alt şeritte
##   B3 Geniş Önizleme  - liste dar (520), önizleme geniş: yatay baş (simge 144 | tür, ad, büyük fiyat | KAYDET / YASAKLA yazılı düğmeler),
##                        açıklama kuyusu, TARİF kutusu
##   B4 Defter          - liste fiyat defteri gibi: kutusuz satırlar, ad ile fiyat arası noktalı çizgi, satır altı ince çizgi; önizleme ortalı sayfa
##                        (raf tahtası ayracı, noktalı fiş satırları)
const BF_RECT := Rect2(250, 60, 1420, 792) ## B ile aynı pencere (içerik 1376 x 748)


func _bf_title(e: Dictionary, d: Dictionary) -> String:
	return str(d.get("row_sub", d["name"])) if _is_upg(e) else str(d["name"])


func _is_upg(e: Dictionary) -> bool:
	return ["wupgrade", "wplus", "upgrade"].has(str(e["type"]))


## Tür satırı (32): eşya = heybe + tür (+ silahta "Silah yuvası n/m"); geliştirme = çekiç + silah adı + kademe.
func _bf_kind(e: Dictionary, d: Dictionary, align_center: bool = false) -> HBoxContainer:
	var r: HBoxContainer = _k.h(12)
	if align_center:
		r.alignment = BoxContainer.ALIGNMENT_CENTER
	var col: Color = Color(d["tag_col"]).lerp(_k.c("text"), 0.3)
	var upg: bool = _is_upg(e)
	var g: Control = _k.glyph(DarkKit.G_HAMMER if upg else DarkKit.G_BAG, col, 3)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(g)
	if upg:
		r.add_child(_k.lbl(str(d["name"]), 32, col))
		r.add_child(_k.lbl(_cf_txt(str(d.get("row_badge", ""))), 32, _k.c("dim")))
	else:
		r.add_child(_k.lbl(str(d.get("kind", "")), 32, col))
		if str(e["type"]) == "weapon":
			r.add_child(_k.lbl(str(d["sub"]), 32, _k.c("dim")))
	if Market.is_saved(e):
		r.add_child(_saved_tag(16))
	return r


func _bf_lines(d: Dictionary, w: float, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> VBoxContainer:
	var v: VBoxContainer = _k.v(4)
	for ln in d["lines"]:
		v.add_child(_k.wrap(_cf_txt(str(ln)), 32, _k.c("text"), w, align))
	return v


## Alınamıyorsa düğme nedeni yazar ("600 altın eksik" / "Yuva dolu" ...).
func _bf_buy(e: Dictionary, w: float, h: float = 64.0) -> Button:
	var why: String = Market.block_reason(_player, e)
	var b: Button = _k.btn(_verb(e) if why == "" else why, "primary", 32, h, w)
	b.disabled = why != ""
	return b


## HESAP şeridi: FİYAT | ELİNDE | KALAN (kalan eksi = kırmızı).
func _bf_ledger(e: Dictionary) -> PanelContainer:
	var box: PanelContainer = _k.box(HudTheme.WIN_INSET, _k.c("line"), 10, 3, 6)
	var r: HBoxContainer = _k.h(12)
	box.add_child(r)
	var cost: int = Market.price(e)
	var sh: int = Market.shards(e)
	var left: HBoxContainer = _k.h(14)
	left.add_child(_k.amt(GameManager.gold - cost, 32, _k.c("bad") if GameManager.gold < cost else _k.c("good")))
	if sh > 0:
		left.add_child(_k.amt(GameManager.weapon_shards - sh, 32, _k.c("bad") if GameManager.weapon_shards < sh else _k.c("good"), "shard"))
	var have: HBoxContainer = _k.h(14)
	have.add_child(_k.amt(GameManager.gold, 32, _k.c("price")))
	if sh > 0:
		have.add_child(_k.amt(GameManager.weapon_shards, 32, DarkKit.SHARD_TEXT, "shard"))
	var cells: Array = [["FİYAT", _price_row(e, 32, false)], ["ELİNDE", have], ["KALAN", left]]
	for k in cells.size():
		if k > 0:
			var sep := ColorRect.new()
			sep.color = _k.c("line")
			sep.custom_minimum_size = Vector2(3, 0)
			sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.add_child(sep)
		## başlık yazıyla aynı boyda (32, sönük) ve değerin solunda: 16'lık başlık okunmuyordu
		var cv: HBoxContainer = _k.h(10)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_child(_k.lbl(cells[k][0], 32, _k.c("dim")))
		cv.add_child(cells[k][1])
		r.add_child(cv)
	return box


## Liste satırı: [kademe şeridi | simge 48 | ad 32 | (noktalı çizgi) | kademe rozeti 32 | fiyat 32]; kayıtlıda yeşil kilit.
func _bf_row(e: Dictionary, section: String, i: int, o: Dictionary = {}) -> Control:
	var d: Dictionary = _d(e)
	var sel: bool = _sel(section, i)
	var saved: bool = Market.is_saved(e)
	var zebra: Color = Color(_k.c("panel3"), 0.35) if (i % 2 == 0 and bool(o.get("zebra", true))) else Color(0, 0, 0, 0)
	var rf: Array = _rim_fill(e, d, sel, zebra)
	var edge: Color = rf[0] if (sel or saved) else Color(0, 0, 0, 0)
	var box: PanelContainer = _k.box(rf[1], edge, float(o.get("pad", 8.0)), 3, 6)
	box.custom_minimum_size.y = float(o.get("h", 64.0))
	var r: HBoxContainer = _k.h(14)
	box.add_child(r)
	if bool(o.get("stripe", true)):
		var stripe := ColorRect.new()
		stripe.color = Color(d["tag_col"], 0.85)
		stripe.custom_minimum_size = Vector2(6, 0)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(stripe)
	if bool(o.get("slot", false)):
		## envanter yuvası gibi: koyu kare + kademe renkli kenar
		var slot: PanelContainer = _k.box(HudTheme.DEEP, Color(d["tag_col"], 0.75), 2, 3, 4)
		slot.add_child(_k.center(_icon(d, 48)))
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(slot)
	else:
		var ic: CenterContainer = _k.center(_icon(d, 48))
		ic.custom_minimum_size.x = 52
		r.add_child(ic)
	var name_l: Label = _k.lbl(_bf_title(e, d), 32, _k.c("text"))
	r.add_child(name_l)
	if bool(o.get("leader", false)):
		r.add_child(_bf_leader())
	else:
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if saved:
		var g: Control = _k.glyph(DarkKit.G_LOCK, HudTheme.SAVED, 3)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(g)
	if section == "upgrades" and bool(o.get("badge", true)):
		var bl: Label = _k.lbl(_cf_txt(str(d.get("row_badge", ""))), 32, _k.c("dim"))
		r.add_child(bl)
	var pr: HBoxContainer = _price_row(e, 32, false)
	pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.custom_minimum_size.x = float(o.get("price_w", 150.0))
	pr.alignment = BoxContainer.ALIGNMENT_END
	r.add_child(pr)
	return box


## Defter noktalı çizgisi (ad ile fiyat arası).
func _bf_leader() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.custom_minimum_size = Vector2(24, 32)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = _k.c("line_hi")
	var paint := func() -> void:
		var y: float = floorf(c.size.y * 0.5 + 6.0)
		var x: float = 9.0
		while x < c.size.x - 9.0:
			c.draw_rect(Rect2(x, y, 3, 3), col)
			x += 12.0
	c.draw.connect(paint)
	return c


func _bf_list(width: float, o: Dictionary, sep: int = 6) -> PanelContainer:
	var lb: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 12, 3, 6)
	lb.custom_minimum_size.x = width
	var lv: VBoxContainer = _k.v(sep)
	lb.add_child(lv)
	lv.add_child(_sec_head(DarkKit.G_HAMMER, "GELİŞTİRMELER"))
	for i in _list("upgrades").size():
		lv.add_child(_bf_row(_list("upgrades")[i], "upgrades", i, o))
		if bool(o.get("rule", false)):
			lv.add_child(_k.hline(_k.c("line"), 3.0))
	lv.add_child(_k.sp(0, 8))
	lv.add_child(_sec_head(DarkKit.G_BAG, "EŞYALAR"))
	for i in _list("items").size():
		lv.add_child(_bf_row(_list("items")[i], "items", i, o))
		if bool(o.get("rule", false)) and i < _list("items").size() - 1:
			lv.add_child(_k.hline(_k.c("line"), 3.0))
	return lb


func _bf_bottom_out() -> void:
	var bottom: HBoxContainer = _k.h(20)
	bottom.add_child(_reroll(340))
	bottom.add_child(_bans())
	_place(self, bottom, Vector2(BF_RECT.position.x, 866))
	_place(self, _go(400, 56), Vector2(BF_RECT.end.x - 400.0, 866), Vector2(400, 56))


func _bf_recipe_block(e: Dictionary, area: Vector2, center_head: bool = false) -> Control:
	var rec: Control = _recipe(e, area)
	if rec == null:
		return null
	var v: VBoxContainer = _k.v(6)
	var hd: Label = _k.lbl("TARİF", 32, HudTheme.ACCENT_SOFT, HORIZONTAL_ALIGNMENT_CENTER if center_head else HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(hd)
	v.add_child(_k.center(rec))
	return v


## ---------------------------------------------------------------- B1 Sade Liste
func _build_B1() -> void:
	var win: PanelContainer = _frame(BF_RECT, "ListWindow")
	var h: HBoxContainer = _k.h(18)
	win.add_child(h)
	h.add_child(_bf_list(640, {}))
	var e: Dictionary = _picked()
	var d: Dictionary = _d(e)
	var pv: PanelContainer = _k.box(_k.c("panel2"), HudTheme.SAVED_EDGE if Market.is_saved(e) else d["tag_col"], 18, 3, 6)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(pv)
	var v: VBoxContainer = _k.v(10)
	pv.add_child(v)
	var top: HBoxContainer = _k.h(12)
	top.add_child(_bf_kind(e, d))
	top.add_child(_k.sp(0, 0, true))
	top.add_child(_tools())
	v.add_child(top)
	v.add_child(_well(d, e, 112, 10))
	v.add_child(_k.clip(_bf_title(e, d), 48, _k.c("text"), 660, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_k.hline())
	v.add_child(_bf_lines(d, 660))
	var rb: Control = _bf_recipe_block(e, Vector2(660, 140))
	if rb:
		v.add_child(rb)
	v.add_child(_k.sp(0, 0, false, true))
	v.add_child(_bf_ledger(e))
	v.add_child(_bf_buy(e, 0))
	_bf_bottom_out()


## ---------------------------------------------------------------- B2 Kutulu Bölmeler
const B2_RECT := Rect2(250, 40, 1420, 850) ## alt eylem şeridi pencerenin içinde (içerik 1376 x 806)


func _build_B2() -> void:
	var win: PanelContainer = _frame(B2_RECT, "ListWindow")
	var outer: VBoxContainer = _k.v(14)
	win.add_child(outer)
	var h: HBoxContainer = _k.h(18)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(h)
	var lv: VBoxContainer = _k.v(12)
	lv.custom_minimum_size.x = 640
	h.add_child(lv)
	var o: Dictionary = {"stripe": false, "slot": true, "h": 60.0, "zebra": false, "pad": 4.0}
	for spec: Array in [["upgrades", DarkKit.G_HAMMER, "GELİŞTİRMELER"], ["items", DarkKit.G_BAG, "EŞYALAR"]]:
		var sb_: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 12, 3, 6)
		var sv: VBoxContainer = _k.v(6)
		sb_.add_child(sv)
		sv.add_child(_sec_head(spec[1], spec[2]))
		for i in _list(spec[0]).size():
			sv.add_child(_bf_row(_list(spec[0])[i], spec[0], i, o))
		lv.add_child(sb_)
	## önizleme = envanter seçim kartı
	var e: Dictionary = _picked()
	var d: Dictionary = _d(e)
	var pv: PanelContainer = _k.box(_k.c("panel2"), HudTheme.SAVED_EDGE if Market.is_saved(e) else d["tag_col"], 16, 3, 15)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(pv)
	var v: VBoxContainer = _k.v(14)
	pv.add_child(v)
	var plate: PanelContainer = _k.box(HudTheme.INSET, HudTheme.RIM_HI, 12, 3, 6)
	var ph: HBoxContainer = _k.h(12)
	plate.add_child(ph)
	var nm: Label = _k.clip(_bf_title(e, d), 48, HudTheme.ACCENT, 400)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(nm)
	var tl: HBoxContainer = _tools()
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(tl)
	v.add_child(plate)
	## simge + tür + açıklama + tarif tek büyük kuyuda (kısa açıklamalı eşyada boşluk kuyunun içinde kalır, panel boş görünmez)
	var body: PanelContainer = _k.box(HudTheme.WIN_INSET, Color(0, 0, 0, 0), 16, 0, 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)
	var bv: VBoxContainer = _k.v(16)
	body.add_child(bv)
	var mid: HBoxContainer = _k.h(18)
	var wl: PanelContainer = _well(d, e, 144, 12)
	wl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mid.add_child(wl)
	var tv: VBoxContainer = _k.v(10)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_bf_kind(e, d))
	tv.add_child(_bf_lines(d, 470))
	mid.add_child(tv)
	bv.add_child(mid)
	var rb: Control = _bf_recipe_block(e, Vector2(640, 140))
	if rb:
		bv.add_child(rb)
	var br: HBoxContainer = _k.h(14)
	var fl: Label = _k.lbl("FİYAT", 32, _k.c("dim"))
	br.add_child(fl)
	var pr: HBoxContainer = _price_row(e, 48, false)
	pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	br.add_child(pr)
	br.add_child(_k.sp(0, 0, true))
	br.add_child(_bf_buy(e, 300, 72))
	v.add_child(br)
	## alt şerit pencerenin içinde: karıştır + yasak hakkı | bakiye levhası + DEVAM
	var bar: HBoxContainer = _k.h(18)
	bar.add_child(_reroll(320))
	bar.add_child(_bans())
	bar.add_child(_k.sp(0, 0, true))
	var plaque: PanelContainer = _k.box(HudTheme.INSET, HudTheme.RIM_HI, 10, 3, 4)
	plaque.add_child(_purse(32))
	bar.add_child(plaque)
	bar.add_child(_go(380, 64))
	outer.add_child(bar)


## ---------------------------------------------------------------- B3 Geniş Önizleme
func _build_B3() -> void:
	var win: PanelContainer = _frame(BF_RECT, "ListWindow")
	var h: HBoxContainer = _k.h(18)
	win.add_child(h)
	h.add_child(_bf_list(520, {"badge": false, "price_w": 130.0}))
	var e: Dictionary = _picked()
	var d: Dictionary = _d(e)
	var pv: PanelContainer = _k.box(_k.c("panel2"), HudTheme.SAVED_EDGE if Market.is_saved(e) else d["tag_col"], 18, 3, 6)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(pv)
	var v: VBoxContainer = _k.v(14)
	pv.add_child(v)
	## yatay baş: simge | tür + ad + büyük fiyat | yazılı kaydet / yasakla
	var head: HBoxContainer = _k.h(20)
	head.add_child(_well(d, e, 144, 14))
	var tv: VBoxContainer = _k.v(6)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_bf_kind(e, d))
	var nm: Label = _k.wrap(_bf_title(e, d), 48, _k.c("text"), 330)
	nm.max_lines_visible = 2
	tv.add_child(nm)
	tv.add_child(_k.sp(0, 0, false, true))
	tv.add_child(_price_row(e, 48, false))
	head.add_child(tv)
	var tools: VBoxContainer = _k.v(10)
	tools.add_child(_bf_tool_lbl("Lock", DarkKit.G_LOCK, "KAYDET", HudTheme.SAVED))
	tools.add_child(_bf_tool_lbl("Ban", DarkKit.G_X, "YASAKLA", _k.c("bad")))
	head.add_child(tools)
	v.add_child(head)
	var dw: PanelContainer = _k.box(HudTheme.WIN_INSET, Color(0, 0, 0, 0), 18, 0, 12)
	dw.add_child(_bf_lines(d, 740))
	v.add_child(dw)
	var rb: Control = _bf_recipe_block(e, Vector2(740, 170))
	if rb:
		v.add_child(rb)
	v.add_child(_k.sp(0, 0, false, true))
	var br: HBoxContainer = _k.h(18)
	var have: HBoxContainer = _k.h(12)
	have.add_child(_k.lbl("ELİNDE", 32, _k.c("dim")))
	have.add_child(_purse(32))
	have.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	br.add_child(have)
	br.add_child(_k.sp(0, 0, true))
	br.add_child(_bf_buy(e, 400, 64))
	v.add_child(br)
	_bf_bottom_out()


## Yazılı araç düğmesi (simge + KAYDET / YASAKLA); prototipte durağan.
func _bf_tool_lbl(n: String, pat: Array, t: String, col: Color) -> Button:
	var r: HBoxContainer = _k.h(10)
	var g: Control = _k.glyph(pat, col, 3)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(g)
	r.add_child(_k.lbl(t, 32, _k.c("text")))
	var b: Button = _k.row_btn(r, "ghost", 56, 220)
	b.name = n
	return b


## ---------------------------------------------------------------- B4 Defter
func _build_B4() -> void:
	var win: PanelContainer = _frame(BF_RECT, "ListWindow")
	var h: HBoxContainer = _k.h(18)
	win.add_child(h)
	h.add_child(_bf_list(640, {"stripe": false, "zebra": false, "leader": true, "rule": true, "h": 60.0}, 3))
	var e: Dictionary = _picked()
	var d: Dictionary = _d(e)
	var pv: PanelContainer = _k.box(_k.c("panel2"), HudTheme.SAVED_EDGE if Market.is_saved(e) else d["tag_col"], 22, 3, 6)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(pv)
	var v: VBoxContainer = _k.v(12)
	pv.add_child(v)
	var top: HBoxContainer = _k.h(12)
	top.add_child(_k.sp(0, 0, true))
	top.add_child(_tools())
	v.add_child(top)
	v.add_child(_bf_kind(e, d, true))
	v.add_child(_k.clip(_bf_title(e, d), 48, _k.c("text"), 650, HORIZONTAL_ALIGNMENT_CENTER))
	var pl: VBoxContainer = _plank()
	v.add_child(pl)
	v.add_child(_well(d, e, 128, 12))
	v.add_child(_bf_lines(d, 650, HORIZONTAL_ALIGNMENT_CENTER))
	var rb: Control = _bf_recipe_block(e, Vector2(650, 104), true)
	if rb:
		v.add_child(rb)
	v.add_child(_k.sp(0, 0, false, true))
	## fiş satırları: Fiyat ..... / Elinde ..... / çizgi / Kalan ..... (eksi kırmızı)
	var cost: int = Market.price(e)
	var sh: int = Market.shards(e)
	var left: HBoxContainer = _k.h(14)
	left.add_child(_k.amt(GameManager.gold - cost, 32, _k.c("bad") if GameManager.gold < cost else _k.c("good")))
	if sh > 0:
		left.add_child(_k.amt(GameManager.weapon_shards - sh, 32, _k.c("bad") if GameManager.weapon_shards < sh else _k.c("good"), "shard"))
	for spec: Array in [["Fiyat", _price_row(e, 32, false)], ["Elinde", _purse(32)], ["", null], ["Kalan", left]]:
		if spec[1] == null:
			v.add_child(_k.hline(_k.c("line_hi"), 3.0))
			continue
		var fr: HBoxContainer = _k.h(10)
		fr.add_child(_k.lbl(spec[0], 32, _k.c("dim") if spec[0] != "Kalan" else _k.c("text")))
		fr.add_child(_bf_leader())
		fr.add_child(spec[1])
		v.add_child(fr)
	v.add_child(_bf_buy(e, 0))
	_bf_bottom_out()
