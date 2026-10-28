extends Control

## LEVEL ATLAMA + PAZAR ekranının görünüşü - madde 386 prototipi "D - Gece Sıvası Yuvalar" (kullanıcı 2026-10-28: "D'yi oyuna al").
## Solda level kartı sütunu (kartların kendisi level_up_screen.gd'nin Button'ları - buraya taşınır, yüzleri fill_card ile kurulur),
## sağda 2x3 pazar yuvası + LoL tarzı ayrıntı kartı (SATIN AL) + pazarın kendi KARIŞTIR'ı, üstte seviye başlığı + bakiye
## (+ çok oyunculuda sayaç), altta DEVAM ET. Kurallar/fiyatlar level_market.gd'de; kart seçimi/kapanış akışı level_up_screen.gd'de.
## Yalnız masaüstü (telefon + evrim seviyeleri eski ekranında). Koordinatlar 1920x1080 tuvali (canvas_items germesi).
## Yuva: tık = seç (ayrıntı), çift tık / sağ tık = satın al (seyyar satıcıyla aynı), fare üstündeyken ayrıntı onu gösterir.

signal continue_pressed
## Pazarda altın harcandı (alım / karıştırma) - ekran kart karıştırma düğmesinin durumunu yeniler.
signal market_changed

const Market := preload("res://scripts/level_market.gd")
const DarkKit := preload("res://scripts/shop_dark_kit.gd")
const UiAnim := preload("res://scripts/ui_anim.gd")
const ModalSafeArea := preload("res://scripts/modal_safe_area.gd")
const StatIcon := preload("res://scripts/stat_icon.gd")
const TierSystemScript := preload("res://scripts/tier_system.gd")
const ROW_GLOW := preload("res://assets/ui/game/levelup_row_glow.png")
const DIE := preload("res://assets/ui/game/levelup_die.png")

const LEFT_RECT := Rect2(64, 156, 612, 784)
const RIGHT_RECT := Rect2(700, 156, 1156, 784)
const GO_RECT := Rect2(750, 966, 420, 72)
const CARD_H := 176.0
const SLOT_SIZE := Vector2(182, 256)
const SLOT_GAP := 14
const TIER_UPPER := ["SIRADAN", "NADİR", "EPİK", "EFSANEVİ"]
## level_up_screen.gd ROW_TIER_TEXT / ROW_GLOW_COLORS / ROW_VALUE_COLOR / ROW_COST_COLOR ile aynı aile
const TIER_TXT := [Color("#cdd1d6"), Color("#a6c6f4"), Color("#d8aef4"), Color("#f8a890")]
const TIER_RIM := [Color("#dfe4ea"), Color("#9cc4ff"), Color("#dcb0ff"), Color("#ffc65a")]
const VALUE_COL := Color("#ffd66e")
const COST_COL := Color("#ff9a86")
const COST_BG := Color("#2e1620")
const COST_FS := 32
const G_DOWN := ["..#..", "..#..", "#.#.#", ".###.", "..#.."]
## Kart yüzünde değer + bedel hapının sığması gereken genişlik: kart (612 - 2x20) - yüz payı 2x14 - simge 128 - ara 18.
const CARD_TEXT_W := 398.0

var _k = null
var _player: Node = null
var offers: Array = []
var shop_rerolls: int = 0
var selected: int = 0
var _hover: int = -1
var _chosen: int = -1

var _cards: Array = []
var _cards_box: VBoxContainer = null
var _free_badge_host: HBoxContainer = null
var _grid: GridContainer = null
var _slots: Array = []
var _detail: VBoxContainer = null
var _shop_reroll: Button = null
var _gold_lbl: Label = null
var _shard_lbl: Label = null
var _countdown: PanelContainer = null
var _countdown_lbl: Label = null
var go_button: Button = null


## level: başlık; cards: level_up_screen'in 3 kart Button'ı; level_reroll: ekranın kart karıştırma düğmesi (mantığı ekranda kalır).
func setup(player: Node, level: int, cards: Array, level_reroll: Button) -> void:
	_player = player
	_cards = cards
	_k = DarkKit.new(DarkKit.PAL_NIGHT)
	theme = _k.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_header(level)
	_build_left(level_reroll)
	_build_right()
	go_button = _k.btn("ÖNCE KART SEÇ", "primary", 40, GO_RECT.size.y, GO_RECT.size.x)
	go_button.name = "MarketContinue"
	go_button.disabled = true
	go_button.pressed.connect(func() -> void: continue_pressed.emit())
	_place(self, go_button, GO_RECT.position, GO_RECT.size)
	offers = Market.roll_offers(_player)
	_rebuild_slots()
	UISound.connect_all_buttons(self)
	_fit_safe_area()


## Çok oyunculuda grup paneli (katman 96) sağ şeridi kaplar: ekran dükkanlar gibi o şeridin soluna sığacak kadar küçülür
## (madde 36, ModalSafeArea); panel yoksa 1:1.
func _fit_safe_area() -> void:
	if not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = ModalSafeArea.rect(get_tree(), view)
	var s: float = minf(1.0, minf(safe.size.x / 1920.0, view.y / 1080.0))
	scale = Vector2(s, s)
	position = Vector2(0.0, roundf((view.y - 1080.0 * s) * 0.5))


## ---------------------------------------------------------------- iskelet
func _place(parent: Control, n: Control, pos: Vector2, sz: Vector2 = Vector2.ZERO) -> void:
	parent.add_child(n)
	n.position = pos
	if sz != Vector2.ZERO:
		n.custom_minimum_size = sz
		n.size = sz


## Sağ kenarı right_x'te sabit, en küçük boyu sola doğru büyür (ağaç dışında ölçülen genişlik yanlış çıkabiliyor).
func _place_right(n: Control, right_x: float, y: float) -> void:
	add_child(n)
	n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	n.offset_left = right_x
	n.offset_right = right_x
	n.offset_top = y
	n.offset_bottom = y


func _build_header(level: int) -> void:
	var t: Label = _k.lbl("SEVİYE %d" % level, 56, _k.c("accent"))
	t.name = "MarketTitle"
	_place(self, t, Vector2(64, 36))
	_place(self, _k.lbl("1 level kartı ücretsiz, pazar altınla", 32, _k.c("dim")), Vector2(64, 96))
	var row: HBoxContainer = _k.h(12)
	_countdown = _k.box(_k.c("inset"), _k.c("line_hi"), 8, 3, 6)
	var cr: HBoxContainer = _k.h(10)
	cr.add_child(_k.lbl("KALAN", 24, _k.c("dim")))
	_countdown_lbl = _k.lbl("", 32, _k.c("accent"))
	cr.add_child(_countdown_lbl)
	_countdown.add_child(cr)
	_countdown.visible = false
	row.add_child(_countdown)
	var cg: PanelContainer = _k.chip("gold", "ALTIN")
	_gold_lbl = cg.get_meta("label")
	row.add_child(cg)
	var cs: PanelContainer = _k.chip("shard", "PARÇACIK")
	_shard_lbl = cs.get_meta("label")
	row.add_child(cs)
	_place_right(row, 1856, 40)


func _sec_head(pat: Array, title: String) -> HBoxContainer:
	var r: HBoxContainer = _k.h(12)
	r.add_child(_k.glyph(pat, _k.c("accent"), 4))
	r.add_child(_k.lbl(title, 32, _k.c("accent")))
	return r


func _build_left(level_reroll: Button) -> void:
	var lb: PanelContainer = _k.box(_k.c("panel"), _k.c("line_hi"), 20, 3, 8)
	lb.name = "LevelCards"
	_place(self, lb, LEFT_RECT.position, LEFT_RECT.size)
	var lv: VBoxContainer = _k.v(16)
	lb.add_child(lv)
	var lh: HBoxContainer = _sec_head(DarkKit.G_STAR, "LEVEL KARTI")
	lh.add_child(_k.sp(0, 0, true))
	_free_badge_host = _k.h(0)
	lh.add_child(_free_badge_host)
	lv.add_child(lh)
	_cards_box = _k.v(16)
	lv.add_child(_cards_box)
	for card: Button in _cards:
		if not is_instance_valid(card):
			continue
		card.reparent(_cards_box, false)
		card.custom_minimum_size = Vector2(0, CARD_H)
		card.size_flags_horizontal = Control.SIZE_FILL
		card.flat = true
		for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			card.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		## Eski parşömen/satır parçaları gizli (level_up_screen.gd onları doldurmaya devam eder, görünmez).
		for c in card.get_children():
			if c is CanvasItem:
				(c as CanvasItem).visible = false
		card.set_meta("glow_texture", ROW_GLOW)
		card.set_meta("glow_card_size", Vector2(LEFT_RECT.size.x - 40.0, CARD_H))
		card.set_meta("glow_colors", TIER_RIM)
		UiAnim.skip(card) ## kartın kendi giriş/üstüne gelme/seçim animasyonu var
	lv.add_child(_k.sp(0, 0, false, true))
	if level_reroll:
		level_reroll.reparent(lv, false)
		level_reroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
		level_reroll.custom_minimum_size = Vector2(0, 60)
		level_reroll.size_flags_horizontal = Control.SIZE_FILL
		_k.btn_style(level_reroll, "ghost")
		level_reroll.icon = DIE
		level_reroll.add_theme_font_size_override("font_size", 32)
		level_reroll.remove_theme_constant_override("outline_size")
	_refresh_free_badge()


func _build_right() -> void:
	var rb: PanelContainer = _k.box(_k.c("panel"), _k.c("line_hi"), 20, 3, 8)
	rb.name = "Market"
	_place(self, rb, RIGHT_RECT.position, RIGHT_RECT.size)
	var rv: VBoxContainer = _k.v(16)
	rb.add_child(rv)
	var rh: HBoxContainer = _sec_head(DarkKit.G_BAG, "PAZAR")
	rh.add_child(_k.lbl("6 rastgele: silah, geliştirme, mana kalkanı, eşya", 24, _k.c("dim")))
	rv.add_child(rh)
	var body: HBoxContainer = _k.h(20)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rv.add_child(body)
	var gv: VBoxContainer = _k.v(16)
	body.add_child(gv)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	_grid.add_theme_constant_override("v_separation", SLOT_GAP)
	gv.add_child(_grid)
	gv.add_child(_k.sp(0, 0, false, true))
	_shop_reroll = _k.row_btn(_die_row(0), "ghost", 60, SLOT_SIZE.x * 3 + SLOT_GAP * 2)
	_shop_reroll.name = "MarketReroll"
	_shop_reroll.pressed.connect(_on_shop_reroll)
	gv.add_child(_shop_reroll)
	var dbox: PanelContainer = _k.box(_k.c("panel2"), _k.c("line_hi"), 20, 3, 6)
	dbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(dbox)
	_detail = _k.v(8)
	dbox.add_child(_detail)


func _die_row(cost: int) -> HBoxContainer:
	var r: HBoxContainer = _k.h(10)
	r.add_child(_k.icon(DIE, 33))
	r.add_child(_k.lbl("KARIŞTIR", 32, _k.c("text")))
	var a: HBoxContainer = _k.amt(cost, 24, _k.c("price"))
	a.name = "Cost"
	r.add_child(a)
	return r


## ---------------------------------------------------------------- level kartları
## data: {title, cat, tier, value, cost, cost_red, label, count, icon}
func fill_card(card: Button, data: Dictionary) -> void:
	var old: Node = card.get_node_or_null("MarketFace")
	if old:
		card.remove_child(old)
		old.queue_free()
	var tier: int = clampi(int(data.get("tier", 1)), 1, 4)
	var tc: Color = TIER_RIM[tier - 1]
	var face: PanelContainer = _k.box(_k.c("panel2"), Color(tc, 0.55), 14, 3, 6)
	face.name = "MarketFace"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(face)
	var r: HBoxContainer = _k.h(18)
	face.add_child(r)
	var tile: Control = _k.tile(_stat_tex(str(data.get("icon", ""))), 128, tc)
	r.add_child(tile)
	var v: VBoxContainer = _k.v(0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top: HBoxContainer = _k.h(8)
	top.add_child(_k.lbl(TIER_UPPER[tier - 1], 24, TIER_TXT[tier - 1]))
	var cat: String = "· " + str(data.get("cat", ""))
	if str(data.get("label", "")) != "":
		cat += " · " + str(data["label"])
	top.add_child(_k.clip(cat, 24, _k.c("dim"), 160))
	top.get_child(1).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var check: HBoxContainer = _k.h(6)
	check.name = "Chosen"
	check.add_child(_k.glyph(DarkKit.G_CHECK, _k.c("good"), 3))
	check.add_child(_k.lbl("SEÇİLDİ", 24, _k.c("good")))
	check.visible = false
	top.add_child(check)
	if int(data.get("count", 0)) > 0:
		var cnt: Label = _k.lbl("%dx alındı" % int(data["count"]), 24, _k.c("dim"))
		cnt.name = "Count"
		top.add_child(cnt)
	v.add_child(top)
	v.add_child(_k.clip(str(data.get("title", "")), 40, _k.c("text"), 360))
	var vr: HBoxContainer = _k.h(14)
	vr.add_child(_k.lbl(str(data.get("value", "")), 56, VALUE_COL))
	if bool(data.get("cost_red", true)):
		## Bedel (madde 379): kazancın yanında gözden kaçmasın - kırmızı hap içinde aşağı ok + 32 px (kullanıcı 2026-10-28: "çok ufak").
		var pill: PanelContainer = _k.box(COST_BG, Color(COST_COL, 0.8), 6, 2, 4)
		pill.name = "Cost"
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pr: HBoxContainer = _k.h(8)
		pr.add_child(_k.glyph(G_DOWN, COST_COL, 3))
		pr.add_child(_k.lbl(str(data.get("cost", "")), COST_FS, COST_COL))
		pill.add_child(pr)
		vr.add_child(pill)
	else:
		var cl: Label = _k.lbl(str(data.get("cost", "")), 24, _k.c("dim"))
		cl.size_flags_vertical = Control.SIZE_SHRINK_END
		vr.add_child(cl)
	v.add_child(vr)
	r.add_child(v)
	card.set_meta("mk_tier", tier)
	card.modulate = Color(1, 1, 1, card.modulate.a)


func _stat_tex(id: String) -> Texture2D:
	var f: String = str(StatIcon.ICON_PATHS.get(id, ""))
	return load(StatIcon.ICON_DIR + f) as Texture2D if f != "" else null


## Seçilen kart: altın kenar + SEÇİLDİ; diğerleri söner. -1 = henüz seçim yok.
func set_chosen(index: int) -> void:
	_chosen = index
	for i in _cards.size():
		var card: Button = _cards[i]
		if not is_instance_valid(card):
			continue
		var face: PanelContainer = card.get_node_or_null("MarketFace") as PanelContainer
		if face == null:
			continue
		var tier: int = int(card.get_meta("mk_tier", 1))
		var on: bool = i == index
		face.add_theme_stylebox_override("panel", _k.sb(_k.c("panel3") if on else _k.c("panel2"),
			_k.c("accent") if on else Color(TIER_RIM[tier - 1], 0.55), 3, 6, 14.0))
		var ch: Node = face.find_child("Chosen", true, false)
		if ch:
			(ch as CanvasItem).visible = on
		var cnt: Node = face.find_child("Count", true, false)
		if cnt:
			(cnt as CanvasItem).visible = not on
		if index >= 0 and not on:
			var tw := card.create_tween()
			tw.tween_property(card, "modulate", Color(1, 1, 1, 0.42), 0.25)
	if index >= 0:
		go_button.disabled = false
		go_button.text = "DEVAM ET"
	_refresh_free_badge()


func _refresh_free_badge() -> void:
	if _free_badge_host == null:
		return
	for c in _free_badge_host.get_children():
		c.queue_free()
	var used: bool = _chosen >= 0
	var p: PanelContainer = _k.box(_k.c("inset"), _k.c("line") if used else _k.c("good"), 6, 3, 4)
	var r: HBoxContainer = _k.h(8)
	r.add_child(_k.glyph(DarkKit.G_CHECK if used else DarkKit.G_STAR, _k.c("dim") if used else _k.c("good"), 3))
	r.add_child(_k.lbl("ÜCRETSİZ SEÇİM KULLANILDI" if used else "1 ÜCRETSİZ SEÇİM", 24, _k.c("dim") if used else _k.c("good")))
	p.add_child(r)
	_free_badge_host.add_child(p)


func set_countdown(sec: float) -> void:
	_countdown.visible = true
	_countdown_lbl.text = "%d sn" % int(ceil(maxf(sec, 0.0)))


## ---------------------------------------------------------------- pazar
func _rebuild_slots() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_slots.clear()
	for i in Market.OFFER_COUNT:
		if i < offers.size():
			var b: Button = _slot_button(i)
			_grid.add_child(b)
			_slots.append(b)
		else:
			var e: Panel = _k.empty_slot(SLOT_SIZE.x)
			e.custom_minimum_size = SLOT_SIZE
			_grid.add_child(e)
	selected = clampi(selected, 0, maxi(offers.size() - 1, 0))
	UISound.connect_all_buttons(_grid)
	refresh()
	UiAnim.cascade(_grid)


func _slot_button(i: int) -> Button:
	var b := Button.new()
	b.name = "Slot%d" % i
	b.flat = true
	b.custom_minimum_size = SLOT_SIZE
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UiAnim.skip(b)
	b.pressed.connect(_select.bind(i))
	b.gui_input.connect(_on_slot_input.bind(i))
	b.mouse_entered.connect(func() -> void:
		_hover = i
		_fill_slot(b, i)
		_refresh_detail())
	b.mouse_exited.connect(func() -> void:
		if _hover == i:
			_hover = -1
			_fill_slot(b, i)
			_refresh_detail())
	return b


func _on_slot_input(event: InputEvent, i: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var mb := event as InputEventMouseButton
	if (mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click) or mb.button_index == MOUSE_BUTTON_RIGHT:
		_select(i)
		buy(i)


func _select(i: int) -> void:
	selected = i
	refresh()


## Satın alır (level_market.gd: demirci/satıcı yolları); başarılıysa yuva "ALINDI" olur, diğerlerinin engelleri yenilenir.
func buy(i: int) -> bool:
	if i < 0 or i >= offers.size():
		return false
	if not Market.buy(_player, offers[i]):
		return false
	refresh.call_deferred() ## SATIN AL düğmesi kendi pressed sinyali içinde yeniden kurulmasın
	market_changed.emit()
	if i < _slots.size() and is_instance_valid(_slots[i]):
		var s: Control = _slots[i]
		s.modulate = Color(1.6, 1.45, 0.9)
		s.create_tween().tween_property(s, "modulate", Color.WHITE, 0.35)
	return true


func _on_shop_reroll() -> void:
	var cost: int = Market.reroll_cost(shop_rerolls)
	if GameManager.gold < cost:
		return
	GameManager.gold -= cost
	shop_rerolls += 1
	offers = Market.roll_offers(_player, offers.map(func(e: Dictionary) -> String: return Market.offer_id(e)))
	selected = 0
	_hover = -1
	_rebuild_slots()
	market_changed.emit()


## Bakiye, yuvalar (fiyat/engel/ALINDI), ayrıntı ve karıştırma düğmesi - her alım/karıştırma/seçim sonrası.
func refresh() -> void:
	_gold_lbl.text = str(GameManager.gold)
	_shard_lbl.text = str(GameManager.weapon_shards)
	for i in _slots.size():
		_fill_slot(_slots[i], i)
	var cost: int = Market.reroll_cost(shop_rerolls)
	var amt: Node = _shop_reroll.get_meta("row").get_node("Cost")
	var lab: Label = amt.get_meta("label")
	lab.text = str(cost)
	_shop_reroll.disabled = GameManager.gold < cost
	lab.add_theme_color_override("font_color", _k.c("dim") if _shop_reroll.disabled else _k.c("price"))
	_refresh_detail()


func _fill_slot(b: Button, i: int) -> void:
	for c in b.get_children():
		b.remove_child(c)
		c.queue_free()
	var e: Dictionary = offers[i]
	var d: Dictionary = Market.describe(e, _player)
	var col: Color = d["tag_col"]
	var sold: bool = bool(e.get("sold", false))
	var sel: bool = i == selected
	var hov: bool = i == _hover and not sel
	var face: PanelContainer = _k.box(_k.c("panel3") if sel else (_k.c("panel2") if hov else _k.c("inset")),
		_k.c("accent") if sel else Color(col, 1.0 if hov else 0.75), 8, 3, 6)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(face)
	var v: VBoxContainer = _k.v(4)
	face.add_child(v)
	v.add_child(_k.clip(str(d["tag"]), 24, col, SLOT_SIZE.x - 20, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_k.center(_icon(d, 112, sold)))
	v.add_child(_k.clip(str(d["name"]), 24, _k.c("text"), SLOT_SIZE.x - 20, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_k.sp(0, 0, false, true))
	v.add_child(_price_row(e, 24, true))
	if sold:
		v.modulate = Color(1, 1, 1, 0.3)
		face.add_child(_stamp(24))


func _icon(d: Dictionary, s: float, dim: bool = false) -> Control:
	if int(d["wtier"]) > 0:
		return _k.wicon(d["tex"], s, int(d["wtier"]), dim)
	return _k.icon(d["tex"], s, dim)


func _price_row(e: Dictionary, fs: int, center: bool) -> HBoxContainer:
	var r: HBoxContainer = _k.h(14)
	if center:
		r.alignment = BoxContainer.ALIGNMENT_CENTER
	var full: int = Market.full_price(e)
	if full > 0:
		r.add_child(_k.strike_lbl(str(full), 24, _k.c("dim")))
	var cost: int = Market.price(e)
	r.add_child(_k.amt(cost, fs, _k.c("bad") if GameManager.gold < cost else _k.c("price")))
	var sh: int = Market.shards(e)
	if sh > 0:
		r.add_child(_k.amt(sh, fs, _k.c("bad") if GameManager.weapon_shards < sh else DarkKit.SHARD_TEXT, "shard"))
	return r


func _stamp(fs: int) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p: PanelContainer = _k.box(Color(_k.c("inset"), 0.92), _k.c("good"), 8, 3, 4)
	var r: HBoxContainer = _k.h(8)
	r.add_child(_k.glyph(DarkKit.G_CHECK, _k.c("good"), 4 if fs >= 32 else 3))
	r.add_child(_k.lbl("ALINDI", fs, _k.c("good")))
	p.add_child(r)
	cc.add_child(p)
	return cc


func _refresh_detail() -> void:
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var i: int = _hover if _hover >= 0 else selected
	if i < 0 or i >= offers.size():
		_detail.add_child(_k.wrap("Pazarda alınabilecek bir şey kalmadı.", 24, _k.c("dim"), 460, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var e: Dictionary = offers[i]
	var d: Dictionary = Market.describe(e, _player)
	var col: Color = d["tag_col"]
	var pill: PanelContainer = _k.box(_k.c("inset"), col, 4, 2, 4)
	pill.add_child(_k.lbl(str(d["tag"]), 24, col))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_detail.add_child(pill)
	var well: PanelContainer = _k.box(_k.c("inset"), Color(col, 0.6), 8, 3, 6)
	well.custom_minimum_size = Vector2(176, 168)
	well.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	well.add_child(_k.center(_icon(d, 144)))
	_detail.add_child(well)
	_detail.add_child(_k.clip(str(d["name"]), 40, _k.c("text"), 470, HORIZONTAL_ALIGNMENT_CENTER))
	_detail.add_child(_k.wrap(str(d["sub"]), 24, _k.c("dim"), 470, HORIZONTAL_ALIGNMENT_CENTER))
	_detail.add_child(_k.hline())
	for ln in d["lines"]:
		var lr: HBoxContainer = _k.h(10)
		var g: Control = _k.glyph(DarkKit.G_DIAMOND, _k.c("good"), 3)
		g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		lr.add_child(g)
		lr.add_child(_k.wrap(str(ln), 24, _k.c("text"), 440))
		_detail.add_child(lr)
	_detail.add_child(_k.sp(0, 0, false, true))
	_detail.add_child(_price_row(e, 40, true))
	var reason: String = Market.block_reason(_player, e)
	if bool(e.get("sold", false)):
		var br: HBoxContainer = _k.h(8)
		br.add_child(_k.glyph(DarkKit.G_CHECK, _k.c("good"), 3))
		br.add_child(_k.lbl("ALINDI", 32, _k.c("good")))
		var done: Button = _k.row_btn(br, "off", 64)
		done.disabled = true
		_detail.add_child(done)
		return
	if reason != "":
		_detail.add_child(_k.wrap(reason, 24, _k.c("bad"), 470, HORIZONTAL_ALIGNMENT_CENTER))
	var label: String = {"wupgrade": "GELİŞTİR", "wplus": "GELİŞTİR", "upgrade": "GELİŞTİR", "shield": "SEÇ VE AL"}.get(str(e["type"]), "SATIN AL")
	var b: Button = _k.btn(label, "primary", 32, 64)
	b.name = "MarketBuy"
	b.disabled = reason != ""
	b.pressed.connect(buy.bind(i))
	UISound.connect_all_buttons(b)
	_detail.add_child(b)
