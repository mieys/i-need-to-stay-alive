extends CanvasLayer

## DEMİRCİ ekranı - "ÖRS VİTRİNİ" (RPG gelişim ekranı). Kullanıcı 2026-10-16'da 4 prototipten A'yı seçti
## (tools/proto_20261016/dukkan_proto.gd, madde 195, 197). Üç sekme de aynı iskelet:
##   solda SİLAHLARIN (kontürlü ikon + özellik adı + renkli ustalık çubuğu) + MANA KALKANIN,
##   ortada seçilenin VİTRİNİ (ışık havuzunda büyük ikon, ad, açıklama; GELİŞTİR'de "USTALIK YOLU" izi),
##   sağda sekmenin seçenekleri (SİLAH AL: 15 silah ızgarası / GELİŞTİR: 4 geliştirme + final satırları, seçili satır açık /
##   MANA KALKANI: 3 tür + alınan türün geliştirmeleri) + GEREKENLER (parçacık / altın: gereken - sende) + büyük eylem düğmesi.
## Görünüş: shop_dark_kit.gd (koyu ahşap + kehribar). Kurallar/fiyatlar weapon_shop_logic.gd'de (TEK kaynak); bu dosya gösterir ve çağırır.
## Örs etkileşimi / iç mekan: weapon_shop.gd.
## Satın alma: satırı/kartı seç + eylem düğmesi, ya da çift tık; kumandada D-pad seçer, A satın alır.
## BİLİNÇLİ OLARAK get_tree().paused YOK (kişisel alışveriş, iç mekan güvenli); başka modal oyunu durdurunca gizlenir.
## YERLEŞİM: gövde yüksekliği sabit (BODY_H) - seçim/sekme pencere boyunu değiştirmez; açıklama kaydırma kutusunun en az genişliği çubuk
## payıyla sabit (DESC_SCROLLBAR_RESERVE, merchant_shop_screen.gd ile aynı donma düzeltmesi). TELEFON: katman PHONE_K büyür, pencere
## güvenli alanı doldurur, sol/orta sütunlar kendi kaydırma kutularında, sağ sütun _phone_scroll'da.

signal closed

const UiAnim := preload("res://scripts/ui_anim.gd")
const Logic := preload("res://scripts/weapon_shop_logic.gd")
const WeaponCatalogScript := preload("res://scripts/weapon_catalog.gd")
const ModalSafeArea := preload("res://scripts/modal_safe_area.gd")
const EventSfx := preload("res://scripts/event_sfx.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const ReadingUiWatcher := preload("res://scripts/reading_ui_watcher.gd")
const DarkKit := preload("res://scripts/shop_dark_kit.gd")
const WeaponScript := preload("res://scripts/weapon.gd")
const DamageStats := preload("res://scripts/damage_stats.gd")
const DMG_COL := Color("#e8885a") ## verilen hasar yazısı (oyun sonu tablosuyla aynı)

const WINDOW_SCALE := 1.0
const PHONE_K := 1.5
const DESC_SCROLLBAR_RESERVE := 28.0
const LEFT_W := 340.0
const CENTER_W := 480.0
const RIGHT_W := 588.0
const BODY_H := 720.0
const SHOW_H := 320.0

enum Tab { WEAPONS, SHIELDS, ENCHANTS }
const TAB_ORDER := [Tab.WEAPONS, Tab.ENCHANTS, Tab.SHIELDS] ## sekme düğmelerinin sırası: SİLAH AL | GELİŞTİR | MANA KALKANI
const TAB_NAMES := {Tab.WEAPONS: "SİLAH AL", Tab.ENCHANTS: "GELİŞTİR", Tab.SHIELDS: "MANA KALKANI"}

var _k = DarkKit.new(DarkKit.PAL_WOOD)
var _player: Node = null
var _tab: int = Tab.WEAPONS
var _selected: Dictionary = {} ## {"type": "weapon"|"shield"|"upgrade"|"wupgrade", "key", "index", "slot", "final"}
var _trait_slot: int = 0 ## GELİŞTİR sekmesinde seçili silah kopyası (owned_weapons dizini)
## Sağ sütundaki seçenekler: {entry, panel, price (Label), shard_cost (Label), sub (Label)}.
var _rows: Array = []
var _fit_callables: Array[Callable] = []
var _last_reserved: float = -1.0
var _phone: bool = false
var _stats_timer: float = 0.0
var _last_sig: int = 0
var _left_sig: int = 0
var _dmg_labels: Dictionary = {} ## silah anahtarı -> "Hasar" satırı etiketi (kart yeniden kurulmadan canlı güncellenir)

var _gold_label: Label = null
var _shard_label: Label = null
var _tab_buttons: Dictionary = {}
var _status_label: Label = null
var _list_title: Label = null
var _list_sub: Label = null ## GELİŞTİR: "2/4 · sıra serbest"
var _list_box: VBoxContainer = null
var _left_box: VBoxContainer = null
var _phone_scroll: ScrollContainer = null

var _show_icon: CenterContainer = null
var _show_badge: PanelContainer = null
var _details_name: Label
var _details_trait: Label
var _details_kind: Label
var _details_desc: Label
var _track_box: VBoxContainer = null
var _details_shard_row: PanelContainer
var _details_shard: Label ## gereken parçacık
var _details_shard_have: Label ## "/ sendeki"
var _details_shard_ok: DarkKit.Glyph
var _details_gold: Label
var _details_gold_have: Label
var _details_gold_ok: DarkKit.Glyph
var _tier_row: HBoxContainer = null
var _details_block: Label
var _action_btn: Button
var _action_lbl: Label
var _action_glyph: DarkKit.Glyph


## Seyyar satıcıdaki gibi: ekran açıkken karakter okuma (read) pozuna geçer - bkz. ReadingUiWatcher.
func _enter_tree() -> void:
	add_to_group(ReadingUiWatcher.GROUP)


func setup(player: Node) -> void:
	_player = player
	EventSfx.play(get_tree(), &"shop_open")
	layer = 80
	_build_ui()
	UiAnim.window_in(self)
	## Oyunu duraklatmayan ekran: ESC aynı basışla duraklatma menüsünü açmasın, yetenek tuşları sızmasın (madde 31).
	GameManager.register_blocking_panel(self)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	## Başka bir modal (level atlama/sandık) oyunu duraklatınca ekran gizlenir, bitince geri gelir.
	var paused_by_other: bool = get_tree().paused
	if visible == paused_by_other:
		visible = not paused_by_other
	if paused_by_other:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_on_close_pressed()
		return
	_stats_timer -= delta
	if _stats_timer <= 0.0:
		_stats_timer = 0.25
		_refresh_weapon_damage()
		if not _phone:
			_refit_if_party_changed()
		## Altın / parçacık / silahlar başka yoldan da değişebilir (sandık payı, görev ödülü) - sadece durum değiştiyse yenile.
		if _state_sig() != _last_sig:
			_refresh_all()


# ------------------------------------------------------------------ iskelet

func _phone_rect() -> Rect2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = MobileUIScript.safe_margins(get_viewport())
	return Rect2(safe.position / PHONE_K, (view - safe.position - safe.size) / PHONE_K)


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_phone = MobileUIScript.enabled
	var window := PanelContainer.new()
	var wst: StyleBoxFlat = _k.sb(_k.c("panel"), _k.c("line_hi"), 3, 8)
	wst.content_margin_left = 24
	wst.content_margin_right = 24
	wst.content_margin_top = 18
	wst.content_margin_bottom = 20
	wst.shadow_color = Color(0, 0, 0, 0.45)
	wst.shadow_size = 14
	wst.shadow_offset = Vector2(0, 8)
	window.add_theme_stylebox_override("panel", wst)
	var th: Theme = _k.theme()
	if _phone:
		scale = Vector2.ONE * PHONE_K
		window.theme = th
		add_child(window)
		var r: Rect2 = _phone_rect()
		window.position = r.position
		window.size = r.size
		window.custom_minimum_size = r.size
	else:
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.theme = th
		add_child(center)
		center.add_child(window)
		_apply_window_scale(window)

	var col: VBoxContainer = _k.v(14)
	window.add_child(col)
	col.add_child(_build_header())
	col.add_child(_k.hline())
	var body: HBoxContainer = _k.h(18)
	if _phone:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		body.custom_minimum_size.y = BODY_H
	col.add_child(body)
	body.add_child(_side_scroll(_build_left(), 280.0 if _phone else LEFT_W))
	body.add_child(_side_scroll(_build_center(), 360.0 if _phone else CENTER_W))
	var right: VBoxContainer = _build_right()
	if _phone:
		_phone_scroll = ScrollContainer.new()
		_phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_phone_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_phone_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_phone_scroll.follow_focus = true
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_phone_scroll.add_child(right)
		body.add_child(_phone_scroll)
	else:
		right.custom_minimum_size.x = RIGHT_W
		body.add_child(right)
	UISound.connect_all_buttons(self)
	_show_tab(Tab.WEAPONS)


## Masaüstünde sütun olduğu gibi (sabit genişlik); telefonda kendi kaydırma kutusunda (pencere boyu içerikten türemesin).
func _side_scroll(content: Control, w: float) -> Control:
	content.custom_minimum_size.x = w
	if not _phone:
		return content
	var sc := ScrollContainer.new()
	sc.name = "SidePanelScroll"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size.x = w + 12.0
	sc.add_child(content)
	return sc


## Container çocuğun ölçeğini her yerleşimde sıfırladığı için ölçek ve konum yerleşim BİTTİKTEN sonra (sort_children) verilir;
## pencere grup panelinin soluna sığıp güvenli alanda ortalanır (modal_safe_area.gd), sığmazsa küçülür.
func _apply_window_scale(window: Control) -> void:
	var fit_scale := func() -> void:
		if not is_instance_valid(window):
			return
		window.pivot_offset = window.size * 0.5
		var view: Vector2 = window.get_viewport_rect().size
		var safe: Rect2 = ModalSafeArea.rect(window.get_tree(), view)
		var fit: float = minf(safe.size.x * 0.97 / maxf(1.0, window.size.x), safe.size.y * 0.97 / maxf(1.0, window.size.y))
		window.scale = Vector2.ONE * minf(WINDOW_SCALE, fit)
		var parent_ci := window.get_parent() as CanvasItem
		var center_local: Vector2 = safe.get_center()
		if parent_ci:
			center_local = parent_ci.get_global_transform().affine_inverse() * center_local
		window.position = (center_local - window.size * 0.5).round()
	_fit_callables.append(fit_scale)
	var parent: Node = window.get_parent()
	if parent is Container:
		(parent as Container).sort_children.connect(fit_scale)
	else:
		window.resized.connect(fit_scale)
	fit_scale.call()


func _refit_if_party_changed() -> void:
	var reserved: float = ModalSafeArea.reserved_right(get_tree(), get_viewport().get_visible_rect().size)
	if is_equal_approx(reserved, _last_reserved):
		return
	_last_reserved = reserved
	for c in _fit_callables:
		if c.is_valid():
			c.call()


## Başlık: [çekiç DEMİRCİ] SİLAH AL | GELİŞTİR | MANA KALKANI ........ parçacık | altın | X
func _build_header() -> HBoxContainer:
	var row: HBoxContainer = _k.h(14)
	var plq: PanelContainer = _k.box(_k.c("inset"), _k.c("line_hi"), 10.0)
	var ph: HBoxContainer = _k.h(12)
	ph.add_child(_k.glyph(DarkKit.G_HAMMER, _k.c("accent"), 4))
	ph.add_child(_k.lbl("DEMİRCİ", 40 if _phone else 48, _k.c("accent")))
	plq.add_child(ph)
	row.add_child(plq)
	var tabs: HBoxContainer = _k.h(6)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for t: int in TAB_ORDER:
		var name_t: String = TAB_NAMES[t]
		var b: Button = _k.btn(name_t, "tab", 32, 56, _k.tw(name_t, 32) + 44.0)
		b.pressed.connect(_show_tab.bind(t))
		tabs.add_child(b)
		_tab_buttons[t] = b
	row.add_child(tabs)
	row.add_child(_k.sp(0, 0, true))
	var c1: PanelContainer = _k.chip("shard", "Parçacık")
	_shard_label = c1.get_meta("label")
	row.add_child(c1)
	var c2: PanelContainer = _k.chip("gold", "Altın")
	_gold_label = c2.get_meta("label")
	row.add_child(c2)
	var close_btn: Button = _k.btn("X", "ghost", 32, 56, 56)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_on_close_pressed)
	row.add_child(close_btn)
	return row


# ------------------------------------------------------------------ sol: silahların + mana kalkanın

func _build_left() -> VBoxContainer:
	_left_box = _k.v(10)
	return _left_box


func _refresh_left() -> void:
	if _left_box == null:
		return
	for c in _left_box.get_children():
		_left_box.remove_child(c)
		c.queue_free()
	_dmg_labels.clear()
	var max_w: int = Logic.max_weapons(_player) if is_instance_valid(_player) else 3
	var head: HBoxContainer = _k.h(10)
	head.add_child(_k.lbl("SİLAHLARIN", 32, _k.c("accent")))
	head.add_child(_k.lbl("%d/%d" % [GameManager.owned_weapons.size(), max_w], 24, _k.c("dim")))
	_left_box.add_child(head)
	for i in range(maxi(max_w, GameManager.owned_weapons.size())):
		if i < GameManager.owned_weapons.size():
			_left_box.add_child(_weapon_card(i))
		else:
			var empty: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 12.0)
			var eh: HBoxContainer = _k.h(14)
			eh.add_child(_k.empty_slot(64))
			var ev: VBoxContainer = _k.v(0)
			ev.alignment = BoxContainer.ALIGNMENT_CENTER
			ev.add_child(_k.lbl("Boş yuva", 32, _k.c("dim")))
			ev.add_child(_k.lbl("SİLAH AL sekmesinden", 24, _k.c("dim")))
			eh.add_child(ev)
			empty.add_child(eh)
			_left_box.add_child(empty)
	_left_box.add_child(_k.sp(0, 4))
	_left_box.add_child(_k.lbl("MANA KALKANIN", 32, _k.c("accent")))
	_left_box.add_child(_shield_card())
	UISound.connect_all_buttons(_left_box)


func _slot_tier(slot: int) -> int:
	var ench: Dictionary = Logic.slot_enchant(slot)
	if ench.is_empty():
		return 1
	if bool(ench.get("final", false)):
		return 5
	return mini(4, 1 + (ench.get("ups", []) as Array).size())


func _tier_color(t: int) -> Color:
	return DarkKit.ENCH_COL[t] if t >= 2 else _k.c("dim")


## Renkli ustalık çubuğu (yeşil-mavi-mor-mor-kırmızı = efsun kontür sırası).
func _pips(slot: int, w: float, ht: float = 10.0) -> DarkKit.TierPips:
	var ench: Dictionary = Logic.slot_enchant(slot)
	var n: int = (ench.get("ups", []) as Array).size() + (1 if bool(ench.get("final", false)) else 0)
	var cols: Array = [DarkKit.ENCH_COL[2], DarkKit.ENCH_COL[3], DarkKit.ENCH_COL[4], DarkKit.ENCH_COL[4], DarkKit.ENCH_COL[5]]
	return DarkKit.TierPips.new(cols, n, _k.c("inset"), w, ht)


## Silah kartı: kontürlü ikon + ad (+ kademe) + özellik adı + ustalık çubuğu. GELİŞTİR sekmesinde tıklanınca o kopya seçilir.
func _weapon_card(slot: int) -> PanelContainer:
	var key: String = str((GameManager.owned_weapons[slot] as Dictionary).get("key", ""))
	var sel: bool = _tab == Tab.ENCHANTS and slot == _trait_slot
	var p: PanelContainer = _k.box(_k.c("panel3") if sel else _k.c("panel2"), _k.c("accent") if sel else _k.c("line"), 12.0)
	var row: HBoxContainer = _k.h(14)
	p.add_child(row)
	row.add_child(_k.wicon(WeaponCatalogScript.icon(key), 64.0, _slot_tier(slot)))
	var v: VBoxContainer = _k.v(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nh: HBoxContainer = _k.h(10)
	nh.add_child(_k.lbl(str(WeaponCatalogScript.NAMES.get(key, key)), 32, _k.c("text")))
	var t: int = _slot_tier(slot)
	nh.add_child(_k.lbl(DarkKit.ROMAN[t - 1], 24, _tier_color(t)))
	v.add_child(nh)
	var def: Dictionary = EnchantDefs.get_def(Logic.slot_trait_id(slot))
	v.add_child(_k.clip(str(def.get("name", "")), 24, _k.c("dim"), 200.0))
	var ph: HBoxContainer = _k.h(8)
	ph.add_child(_pips(slot, 120.0))
	var taken: int = Logic.wupgrade_taken_count(slot)
	var fin: bool = bool(Logic.slot_enchant(slot).get("final", false))
	var rows_n: int = maxi(0, Logic.slot_upgrade_rows(slot).size() - 1)
	var ptxt: String = "TAMAM" if fin else ("FİNAL HAZIR" if rows_n > 0 and taken >= rows_n else "%d/%d" % [taken, rows_n])
	ph.add_child(_k.lbl(ptxt, 24, _k.c("accent") if (fin or taken >= rows_n) and rows_n > 0 else _k.c("dim")))
	v.add_child(ph)
	## Bu oyunda bu silahın verdiği toplam hasar (kullanıcı isteği 2026-10-17); etiket _process'te canlı güncellenir.
	var dl: Label = _k.lbl(_weapon_dmg_text(key), 24, DMG_COL)
	_dmg_labels[key] = dl
	v.add_child(dl)
	row.add_child(v)
	if _tab == Tab.ENCHANTS:
		p.mouse_filter = Control.MOUSE_FILTER_STOP
		p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		p.gui_input.connect(_on_trait_slot_input.bind(slot))
	return p


## "Hasar 12.345 · %38" - henüz vurmadıysa "Hasar -".
func _weapon_dmg_text(key: String) -> String:
	var d: Dictionary = DamageStats.weapon_damage(key)
	if float(d["dmg"]) <= 0.0:
		return "Hasar -"
	return "Hasar %s · %%%d" % [DamageStats.fmt(float(d["dmg"])), int(round(float(d["share"]) * 100.0))]


func _refresh_weapon_damage() -> void:
	for key in _dmg_labels.keys():
		var l: Label = _dmg_labels[key]
		if is_instance_valid(l):
			l.text = _weapon_dmg_text(str(key))


func _on_trait_slot_input(event: InputEvent, slot: int) -> void:
	var pick: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if pick and slot != _trait_slot:
		_trait_slot = slot
		_selected = {}
		_show_tab(Tab.ENCHANTS)


## Sahip olunan mana kalkanı: ikon + ad + taban/geliştirilmiş değerler.
func _shield_card() -> PanelContainer:
	var p: PanelContainer = _k.box(_k.c("panel2"), _k.c("line"), 12.0)
	var stats: Dictionary = ShieldEnchantDefs.stats()
	if stats.is_empty():
		p.add_child(_k.lbl("Yok", 32, _k.c("dim")))
		return p
	var v: VBoxContainer = _k.v(6)
	p.add_child(v)
	var hh: HBoxContainer = _k.h(12)
	hh.add_child(_k.tile(DarkKit.tex(str(ShieldEnchantDefs.ICONS.get(str(stats["key"]), ""))), 56.0, _k.c("line_hi")))
	hh.add_child(_k.expand(_k.wrap(str(stats["name"]), 32, _k.c("text"), 10.0)))
	v.add_child(hh)
	var delay_text: String = "yok" if bool(stats["always_regen"]) else "%s sn" % Logic._num(float(stats["delay"]))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 16)
	g.add_theme_constant_override("v_separation", 0)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair: Array in [["Kalkan", str(int(round(float(stats["power"]))))], ["Soğurma", "%%%d" % int(round(float(stats["absorption"]) * 100.0))],
			["Yenilenme", "%s/sn" % Logic._num(float(stats["regen"]))], ["Bekleme", delay_text]]:
		var cell: HBoxContainer = _k.h(6)
		cell.add_child(_k.lbl(str(pair[0]), 24, _k.c("dim")))
		cell.add_child(_k.lbl(str(pair[1]), 24, DarkKit.SHARD_TEXT))
		g.add_child(cell)
	v.add_child(g)
	return p


# ------------------------------------------------------------------ orta: vitrin

func _build_center() -> VBoxContainer:
	var cv: VBoxContainer = _k.v(10)
	var vit: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 0.0)
	vit.custom_minimum_size.y = 200.0 if _phone else SHOW_H
	vit.add_child(DarkKit.Spot.new(_k.c("spot"), 0.84))
	_show_icon = CenterContainer.new()
	_show_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vit.add_child(_show_icon)
	var corner := MarginContainer.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_theme_constant_override("margin_left", 12)
	corner.add_theme_constant_override("margin_top", 12)
	_show_badge = _k.box(Color(0, 0, 0, 0), _k.c("line"), 6.0, 2, 3)
	_show_badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_show_badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_show_badge.add_child(_k.lbl("", 24, _k.c("dim")))
	corner.add_child(_show_badge)
	vit.add_child(corner)
	cv.add_child(vit)
	var nh: HBoxContainer = _k.h(14)
	_details_name = _k.lbl("", 40, _k.c("text"))
	nh.add_child(_details_name)
	_details_trait = _k.lbl("", 32, _k.c("accent"))
	nh.add_child(_details_trait)
	cv.add_child(nh)
	_details_kind = _k.lbl("", 24, _k.c("dim"))
	cv.add_child(_details_kind)
	var desc_scroll := ScrollContainer.new()
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var w: float = 360.0 if _phone else CENTER_W
	desc_scroll.custom_minimum_size = Vector2(w, 0 if _phone else 96)
	if _phone:
		desc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cv.add_child(desc_scroll)
	_details_desc = _k.wrap("", 24, _k.c("text"), w - DESC_SCROLLBAR_RESERVE)
	_details_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_scroll.add_child(_details_desc)
	_track_box = _k.v(6)
	cv.add_child(_track_box)
	return cv


## Vitrin: seçilen satırın nesnesi (katalog silahı / sahip olunan silah kopyası / kalkan türü).
func _refresh_center() -> void:
	if _show_icon == null:
		return
	for c in _show_icon.get_children():
		_show_icon.remove_child(c)
		c.queue_free()
	for c in _track_box.get_children():
		_track_box.remove_child(c)
		c.queue_free()
	var badge_lbl: Label = _show_badge.get_child(0) as Label
	_show_badge.visible = false
	_details_trait.text = ""
	var big: float = 150.0 if _phone else 240.0
	if _selected.is_empty():
		_details_name.text = ""
		_details_kind.text = ""
		_details_desc.text = "Önce bir silah al: her silah kendi özelliğiyle gelir, geliştirmeleri burada satılır." if _tab == Tab.ENCHANTS else ""
		return
	var key: String = str(_selected.get("key", ""))
	match str(_selected.get("type", "")):
		"weapon":
			var owned: bool = GameManager.owns_weapon(key)
			_show_icon.add_child(_k.wicon(WeaponCatalogScript.icon(key), big, 1, false))
			_details_name.text = str(WeaponCatalogScript.NAMES.get(key, key)).to_upper()
			_details_kind.text = ("Yakın dövüş" if WeaponCatalogScript.MELEE_KEYS.has(key) else "Menzilli") + ("  ·  SENDE" if owned else "")
			var def: Dictionary = EnchantDefs.get_def(EnchantDefs.trait_of(key))
			_details_trait.text = str(def.get("name", ""))
			var desc: String = str(WeaponCatalogScript.DESCRIPTIONS.get(key, "")).replace(" · ", "\n")
			if not def.is_empty():
				desc += "\n\nÖZELLİĞİ - %s: %s" % [str(def.get("name", "")), str((def.get("base", {}) as Dictionary).get("text", ""))]
			_details_desc.text = desc
		"wupgrade":
			var slot: int = int(_selected.get("slot", 0))
			var t: int = _slot_tier(slot)
			_show_icon.add_child(_k.wicon(WeaponCatalogScript.icon(key), big, t))
			_show_badge.visible = true
			badge_lbl.text = "KADEME %s" % DarkKit.ROMAN[t - 1]
			badge_lbl.add_theme_color_override("font_color", _tier_color(t))
			_show_badge.add_theme_stylebox_override("panel", _k.sb(Color(_tier_color(t), 0.18), _tier_color(t), 2, 3, 6.0))
			var def2: Dictionary = EnchantDefs.get_def(Logic.slot_trait_id(slot))
			_details_name.text = str(WeaponCatalogScript.NAMES.get(key, key)).to_upper()
			_details_trait.text = str(def2.get("name", ""))
			_details_kind.text = "TEMEL ÖZELLİK"
			_details_desc.text = str((def2.get("base", {}) as Dictionary).get("text", ""))
			_build_track(slot)
		"shield", "upgrade":
			var sk: String = key
			_show_icon.add_child(_k.icon(DarkKit.tex(str(ShieldEnchantDefs.ICONS.get(sk, ""))), big * 0.8))
			var d: Dictionary = ShieldEnchantDefs.TYPES.get(sk, {})
			_details_name.text = ShieldEnchantDefs.type_name(sk).to_upper()
			_details_kind.text = "Mana Kalkanı türü" if str(_selected.get("type")) == "shield" else "Mana Kalkanı geliştirmesi"
			_details_desc.text = "%s\n\n%s\nBir tür seçildi mi değiştirilemez; diğer türler kilitlenir." % [str(d.get("desc", "")), _shield_stat_lines(sk)]


## "Kalkan: 160\nHasar soğurma: %60\nYenilenme: 4/sn\nBekleme: yok" (o türün tabanı).
func _shield_stat_lines(key: String) -> String:
	var d: Dictionary = ShieldEnchantDefs.TYPES.get(key, {})
	if d.is_empty():
		return ""
	var delay_text: String = "yok (savaşta da dolar)" if bool(d.get("always_regen", false)) else "%s sn" % Logic._num(float(d["delay"]))
	return "Mana Kalkanı: %d\nHasar soğurma: %%%d\nYenilenme: %s/sn\nBekleme: %s" % [
		int(round(float(d["power"]))), int(round(float(d["absorption"]) * 100.0)), Logic.type_regen_text(d), delay_text]


## USTALIK YOLU: temel elmas -> I..IV -> taç (final); alınan bölümler yeşil, seçili rozet vurgulu.
func _build_track(slot: int) -> void:
	_track_box.add_child(_k.lbl("USTALIK YOLU", 24, _k.c("dim")))
	var track: HBoxContainer = _k.h(0)
	track.alignment = BoxContainer.ALIGNMENT_CENTER
	var base: PanelContainer = _k.box(_k.c("panel3"), _k.c("line_hi"), 0.0, 3, 6)
	base.custom_minimum_size = Vector2(48, 48)
	base.add_child(_k.center(_k.glyph(DarkKit.G_DIAMOND, _k.c("text"), 4)))
	track.add_child(base)
	var rows: Array = Logic.slot_upgrade_rows(slot)
	var sel_idx: int = int(_selected.get("index", -1)) if str(_selected.get("type", "")) == "wupgrade" else -1
	for idx in rows.size():
		var bar := ColorRect.new()
		bar.color = _k.c("good") if Logic.wupgrade_taken(slot, idx) else _k.c("line")
		bar.custom_minimum_size = Vector2(30 if not _phone else 14, 6)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(bar)
		track.add_child(_up_badge(slot, idx, 60.0 if Logic.wupgrade_is_final(slot, idx) else 48.0, idx == sel_idx))
	_track_box.add_child(track)


## Geliştirme durumu: taken / avail / locked (final, 4 geliştirme bitmeden).
func _row_state(slot: int, idx: int) -> String:
	if Logic.wupgrade_taken(slot, idx):
		return "taken"
	if Logic.wupgrade_is_final(slot, idx) and Logic.wupgrade_taken_count(slot) < Logic.slot_upgrade_rows(slot).size() - 1:
		return "locked"
	return "avail"


## Roma rakamlı rozet (final = taç / kilit, alınan = onay).
func _up_badge(slot: int, idx: int, s: float, sel: bool) -> PanelContainer:
	var st: String = _row_state(slot, idx)
	var final_up: bool = Logic.wupgrade_is_final(slot, idx)
	var fill: Color = _k.c("panel2")
	var bd: Color = _k.c("line_hi")
	var tc: Color = _k.c("text")
	match st:
		"taken":
			fill = _k.c("good").darkened(0.62)
			bd = _k.c("good")
			tc = _k.c("good")
		"locked":
			fill = _k.c("inset")
			bd = _k.c("line")
			tc = _k.c("dim")
	if sel:
		fill = _k.c("accent")
		bd = _k.c("accent").lightened(0.3)
		tc = _k.c("accent_text")
	if final_up and st != "locked" and not sel:
		bd = DarkKit.ENCH_COL[5]
	var p: PanelContainer = _k.box(fill, bd, 0.0, 3, 6)
	p.custom_minimum_size = Vector2(s, s)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var px: int = maxi(2, int(s / 18.0))
	if final_up:
		p.add_child(_k.center(_k.glyph(DarkKit.G_LOCK if st == "locked" else DarkKit.G_CROWN, tc, px)))
	elif st == "taken" and not sel:
		p.add_child(_k.center(_k.glyph(DarkKit.G_CHECK, tc, px)))
	else:
		var l: Label = _k.lbl(DarkKit.ROMAN[clampi(idx, 0, 4)], 24 if s < 64.0 else 32, tc, HORIZONTAL_ALIGNMENT_CENTER)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		p.add_child(l)
	return p


# ------------------------------------------------------------------ sağ: seçenekler + GEREKENLER + eylem düğmesi

func _build_right() -> VBoxContainer:
	var rv: VBoxContainer = _k.v(8)
	var head: HBoxContainer = _k.h(12)
	_list_title = _k.lbl("", 32, _k.c("accent"))
	head.add_child(_list_title)
	_list_sub = _k.lbl("", 24, _k.c("dim"))
	head.add_child(_list_sub)
	head.add_child(_k.sp(0, 0, true))
	_status_label = _k.lbl("", 24, _k.c("dim"), HORIZONTAL_ALIGNMENT_RIGHT)
	head.add_child(_status_label)
	rv.add_child(head)
	_list_box = _k.v(8)
	rv.add_child(_list_box)
	rv.add_child(_k.sp(0, 0, false, true))
	rv.add_child(_k.lbl("GEREKENLER", 24, _k.c("dim")))
	var mats: HBoxContainer = _k.h(10)
	## Parçacık satırı (parçacık istemeyen seçimde gizli) + altın satırı: [ikon] gereken / sende [onay|çarpı]
	_details_shard_row = _k.box(_k.c("inset"), _k.c("line"), 10.0)
	_details_shard_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sh: HBoxContainer = _k.h(10)
	sh.add_child(_k.shard(32))
	sh.add_child(_k.expand(_k.lbl("Parçacık", 24, _k.c("dim"))))
	_details_shard = _k.lbl("", 32, _k.c("price"))
	sh.add_child(_details_shard)
	_details_shard_have = _k.lbl("", 24, _k.c("dim"))
	sh.add_child(_details_shard_have)
	_details_shard_ok = _k.glyph(DarkKit.G_CHECK, _k.c("good"), 3)
	sh.add_child(_details_shard_ok)
	_details_shard_row.add_child(sh)
	mats.add_child(_details_shard_row)
	var gold_row: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 10.0)
	gold_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gh: HBoxContainer = _k.h(10)
	gh.add_child(_k.coin(32))
	gh.add_child(_k.expand(_k.lbl("Altın", 24, _k.c("dim"))))
	_details_gold = _k.lbl("", 32, _k.c("price"))
	gh.add_child(_details_gold)
	_details_gold_have = _k.lbl("", 24, _k.c("dim"))
	gh.add_child(_details_gold_have)
	_details_gold_ok = _k.glyph(DarkKit.G_CHECK, _k.c("good"), 3)
	gh.add_child(_details_gold_ok)
	gold_row.add_child(gh)
	mats.add_child(gold_row)
	rv.add_child(mats)
	_tier_row = _k.h(10)
	rv.add_child(_tier_row)
	_details_block = _k.clip("", 24, _k.c("bad"), 10.0)
	_details_block.custom_minimum_size.y = 28
	rv.add_child(_details_block)
	var arow: HBoxContainer = _k.h(12)
	_action_glyph = _k.glyph(DarkKit.G_HAMMER, _k.btn_tc("primary"), 4)
	arow.add_child(_action_glyph)
	_action_lbl = _k.lbl("GELİŞTİR", 40, _k.btn_tc("primary"))
	_action_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	arow.add_child(_action_lbl)
	_action_btn = _k.row_btn(arow, "primary", 76, 10.0)
	_action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_btn.pressed.connect(func() -> void: _on_buy_pressed(_selected))
	rv.add_child(_action_btn)
	return rv


func _show_tab(tab: int) -> void:
	_tab = tab
	for t in _tab_buttons:
		_k.btn_style(_tab_buttons[t] as Button, "tab_on" if t == tab else "tab")
	for c in _list_box.get_children():
		_list_box.remove_child(c)
		c.queue_free()
	_rows.clear()
	match tab:
		Tab.WEAPONS:
			_list_title.text = "SİLAHLAR"
			_build_weapon_rows()
		Tab.SHIELDS:
			_list_title.text = "MANA KALKANI"
			_build_shield_rows()
		_:
			_list_title.text = "GELİŞTİRMELER"
			_build_trait_rows()
	UISound.connect_all_buttons(self)
	## Kumanda: sekme açılınca ilk odak ilk seçenekte (gamepad_ui.gd FIRST_FOCUS_GROUP).
	for r in _rows:
		(r["panel"] as Node).remove_from_group(&"gamepad_first_focus")
	if not _rows.is_empty():
		(_rows[0]["panel"] as Node).add_to_group(&"gamepad_first_focus")
	## Varsayılan seçim: sıradaki mantıklı adım (alınmamış ilk seçenek), yoksa ilki.
	_selected = {}
	for r in _rows:
		if _row_open(r["entry"]):
			_selected = r["entry"]
			break
	if _selected.is_empty() and not _rows.is_empty():
		_selected = _rows[0]["entry"]
	_refresh_all()


## Seçenek henüz alınmamış mı (sahip olunan silah / alınan geliştirme / seçilmiş tür = kapalı).
func _row_open(entry: Dictionary) -> bool:
	match str(entry.get("type", "")):
		"weapon":
			return not GameManager.owns_weapon(str(entry.get("key", "")))
		"wupgrade":
			return not Logic.wupgrade_taken(int(entry.get("slot", 0)), int(entry.get("index", 0)))
		"shield":
			return GameManager.shield_enchant == ""
		"upgrade":
			var limit: int = Logic.upgrade_limit(int(entry.get("index", 0)))
			return limit <= 0 or Logic.upgrade_count(int(entry.get("index", 0))) < limit
	return true


## SİLAH AL: 15 silah 5 sütunlu ızgarada (ikon + fiyat); ad/açıklama vitrinde.
func _build_weapon_rows() -> void:
	var grid := GridContainer.new()
	grid.columns = 4 if _phone else 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in Logic.weapon_keys():
		var entry := {"type": "weapon", "key": str(key)}
		var cell: PanelContainer = _option_panel(entry)
		var v: VBoxContainer = _k.v(4)
		cell.add_child(v)
		var holder := CenterContainer.new()
		holder.custom_minimum_size = Vector2(84, 84)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(holder)
		var pr: HBoxContainer = _k.h(6)
		pr.alignment = BoxContainer.ALIGNMENT_CENTER
		var a: HBoxContainer = _k.amt(0, 24, _k.c("price"))
		pr.add_child(a)
		v.add_child(pr)
		cell.tooltip_text = str(WeaponCatalogScript.NAMES.get(key, key))
		grid.add_child(cell)
		_rows.append({"entry": entry, "panel": cell, "price": a.get_meta("label"), "coin": a.get_child(0), "holder": holder,
				"shard_cost": _k.lbl("", 24), "sub": _k.lbl("", 24)})
	_list_box.add_child(grid)


## MANA KALKANI: 3 tür (tek seferlik, kalıcı) + alınan türün geliştirmeleri.
func _build_shield_rows() -> void:
	for key in Logic.shield_keys():
		_list_box.add_child(_build_line_row({"type": "shield", "key": str(key)}))
	var lines: Array = Logic.upgrade_lines()
	if lines.is_empty():
		_list_box.add_child(_k.wrap("Geliştirmeler, bir mana kalkanı türü aldıktan sonra burada satılır.", 24, _k.c("dim"), 10.0))
		return
	_list_box.add_child(_k.lbl("GELİŞTİRMELER", 24, _k.c("dim")))
	for i in range(lines.size()):
		_list_box.add_child(_build_line_row({"type": "upgrade", "key": GameManager.shield_enchant, "index": i}))


## GELİŞTİR: seçili silah kopyasının 4 geliştirmesi + final (sıra serbest; final 4'ü bitince açılır).
func _build_trait_rows() -> void:
	var count: int = GameManager.owned_weapons.size()
	_status_label.text = ""
	if count == 0:
		_list_box.add_child(_k.wrap("Önce bir silah al: her silah kendi özelliğiyle gelir, geliştirmeleri burada satılır.", 24, _k.c("dim"), 10.0))
		return
	_trait_slot = clampi(_trait_slot, 0, count - 1)
	var wkey: String = str((GameManager.owned_weapons[_trait_slot] as Dictionary).get("key", ""))
	for r in Logic.slot_upgrade_rows(_trait_slot):
		var entry := {"type": "wupgrade", "key": wkey, "slot": _trait_slot, "index": int(r["index"]), "final": bool(r["final"])}
		_list_box.add_child(_build_line_row(entry))


## Odaklanabilir, tıklanabilir seçenek kutusu (kumanda: odak = seçim, A = satın al; fare: tık = seçim, çift tık = satın al).
func _option_panel(entry: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _k.sb(_k.c("panel2"), _k.c("line"), 3, 6, 8.0))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_row_gui_input.bind(entry))
	panel.focus_mode = Control.FOCUS_ALL
	GamepadFocusHelper.add_focus_ring(panel)
	panel.focus_entered.connect(_select.bind(entry))
	return panel


## Satır: [rozet / ikon] ad (+ seçiliyse açıklama) ........ fiyat (altın + parçacık) | ALINDI / SENDE / KİLİTLİ
func _build_line_row(entry: Dictionary) -> PanelContainer:
	var panel: PanelContainer = _option_panel(entry)
	var row: HBoxContainer = _k.h(12)
	panel.add_child(row)
	var lead := CenterContainer.new()
	lead.custom_minimum_size = Vector2(44, 44)
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lead)
	var tv: VBoxContainer = _k.v(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_l: Label = _k.clip(_entry_name(entry), 32, _k.c("text"), 10.0)
	tv.add_child(name_l)
	var sub: Label = _k.wrap("", 24, _k.c("dim"), 10.0)
	tv.add_child(sub)
	row.add_child(tv)
	var pv: VBoxContainer = _k.v(0)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.custom_minimum_size.x = 92
	var a: HBoxContainer = _k.amt(0, 24, _k.c("price"))
	a.alignment = BoxContainer.ALIGNMENT_END
	pv.add_child(a)
	var s: HBoxContainer = _k.amt(0, 24, DarkKit.SHARD_TEXT, "shard")
	s.alignment = BoxContainer.ALIGNMENT_END
	pv.add_child(s)
	row.add_child(pv)
	_rows.append({"entry": entry, "panel": panel, "price": a.get_meta("label"), "coin": a.get_child(0), "shard_row": s,
			"shard_cost": s.get_meta("label"), "sub": sub, "name": name_l, "lead": lead})
	return panel


func _entry_name(entry: Dictionary) -> String:
	var key: String = str(entry.get("key", ""))
	match str(entry.get("type", "")):
		"weapon":
			return str(WeaponCatalogScript.NAMES.get(key, key.capitalize()))
		"shield":
			return ShieldEnchantDefs.type_name(key)
		"upgrade":
			return "Geliştirme %d" % (int(entry.get("index", 0)) + 1)
		"wupgrade":
			var rows: Array = Logic.slot_upgrade_rows(int(entry.get("slot", 0)))
			var i: int = int(entry.get("index", 0))
			return str((rows[i] as Dictionary)["name"]) if i >= 0 and i < rows.size() else "?"
	return key


# ------------------------------------------------------------------ durum / fiyat / satın alma

func _entry_price(entry: Dictionary) -> int:
	match str(entry.get("type", "")):
		"weapon":
			return Logic.weapon_price(GameManager.owned_weapons.size())
		"shield":
			return Logic.shield_price()
		"upgrade":
			return Logic.upgrade_price(int(entry.get("index", 0)))
		"wupgrade":
			return Logic.wupgrade_price(int(entry.get("slot", 0)), int(entry.get("index", 0)))
	return 0


## "" = alınabilir (altın hariç).
func _entry_block(entry: Dictionary) -> String:
	var key: String = str(entry.get("key", ""))
	match str(entry.get("type", "")):
		"weapon":
			if not is_instance_valid(_player):
				return "" ## ekran kapanırken oyuncu silinmiş olabilir - silinmiş nesne tipli parametreye geçemez
			return Logic.weapon_block_reason(_player, key)
		"shield":
			return Logic.shield_block_reason(key)
		"upgrade":
			return Logic.upgrade_block_reason(int(entry.get("index", 0)))
		"wupgrade":
			return Logic.wupgrade_block_reason(int(entry.get("slot", 0)), int(entry.get("index", 0)))
	return "?"


func _entry_shard_cost(entry: Dictionary) -> int:
	if str(entry.get("type", "")) == "wupgrade":
		return Logic.entry_shard_cost("wfinal" if bool(entry.get("final", false)) else "wupgrade")
	return Logic.entry_shard_cost(str(entry.get("type", "")))


func _entry_can_buy(entry: Dictionary) -> bool:
	return _entry_block(entry) == "" and GameManager.gold >= _entry_price(entry)


func _on_buy_pressed(entry: Dictionary) -> void:
	if entry.is_empty() or not _entry_can_buy(entry):
		return
	var key: String = str(entry.get("key", ""))
	var ok: bool = false
	match str(entry.get("type", "")):
		"weapon":
			ok = Logic.buy_weapon(_player, key)
		"shield":
			ok = Logic.buy_shield(_player, key)
		"upgrade":
			ok = Logic.buy_upgrade(_player, int(entry.get("index", 0)))
		"wupgrade":
			ok = Logic.buy_wupgrade(_player, int(entry.get("slot", 0)), int(entry.get("index", 0)))
	if not ok:
		return
	if str(entry.get("type", "")) == "shield":
		_show_tab(Tab.SHIELDS) ## tür alınınca geliştirme satırları belirir, diğer türler kilitlenir
		for r in _rows:
			if str(r["entry"].get("type", "")) == "upgrade":
				_select(r["entry"]) ## seçimi ilk geliştirmeye al: sıradaki adım
				break
		return
	if str(entry.get("type", "")) == "wupgrade":
		## Bir geliştirme alınınca seçim sıradaki açık geliştirmeye geçer (final 4'ü bitince açılır).
		for r in _rows:
			if _row_open(r["entry"]) and r["entry"] != entry:
				_selected = r["entry"]
				break
	_refresh_all()
	_flash_bought(entry)


## Satın alınan seçeneğin kısa parlaması (her panelin kendi tween'i; art arda alımda parlak kalmasın).
func _flash_bought(entry: Dictionary) -> void:
	for r in _rows:
		if r["entry"] == entry and is_instance_valid(r["panel"]):
			var p: Control = r["panel"]
			if p.has_meta("flash_tween"):
				var old: Variant = p.get_meta("flash_tween")
				if old is Tween and (old as Tween).is_valid():
					(old as Tween).kill()
			p.modulate = Color(1.6, 1.45, 0.9)
			var tw: Tween = p.create_tween()
			tw.tween_property(p, "modulate", Color.WHITE, 0.35)
			p.set_meta("flash_tween", tw)


func _on_row_gui_input(event: InputEvent, entry: Dictionary) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_select(entry)
		if (event as InputEventMouseButton).double_click:
			_on_buy_pressed(entry)
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		_select(entry)
		_on_buy_pressed(entry)


func _select(entry: Dictionary) -> void:
	_selected = entry
	_refresh_all()


## Seçenekler, sol sütun, vitrin, gerekenler, altın/parçacık.
func _refresh_all() -> void:
	if _gold_label:
		_gold_label.text = str(GameManager.gold)
	if _shard_label:
		_shard_label.text = "%d" % GameManager.weapon_shards
	for r in _rows:
		_refresh_row(r)
	_refresh_status()
	## Sol sütun yalnız silahlar / kalkan / sekme / seçili kopya değişince yeniden kurulur (her seçimde değil).
	var left_sig: int = hash([str(GameManager.owned_weapons), GameManager.shield_enchant, str(GameManager.shield_enchant_ups), _tab, _trait_slot])
	if left_sig != _left_sig:
		_left_sig = left_sig
		_refresh_left()
	_refresh_center()
	_refresh_details()
	_last_sig = _state_sig()


## Ekranın gösterdiği her şeyin ucuz özeti (değişmediyse _refresh_all atlanır).
func _state_sig() -> int:
	return hash([GameManager.gold, GameManager.weapon_shards, str(GameManager.owned_weapons), GameManager.shield_enchant,
			str(GameManager.shield_enchant_ups), str(_selected), _tab, _trait_slot])


func _refresh_row(r: Dictionary) -> void:
	var entry: Dictionary = r["entry"]
	var key: String = str(entry.get("key", ""))
	var kind: String = str(entry.get("type", ""))
	var price: Label = r["price"]
	var coin: Control = r["coin"]
	var sel: bool = _selected == entry
	var closed_row: bool = false
	var price_text: String = "%d" % _entry_price(entry)
	var price_color: Color = _k.c("price") if GameManager.gold >= _entry_price(entry) else _k.c("bad")
	if _entry_block(entry) != "":
		price_color = _k.c("dim") ## yuva dolu / parçacık yetmiyor / final kilitli: fiyat soluk
	var sub: Label = r["sub"]
	match kind:
		"weapon":
			if GameManager.owns_weapon(key):
				price_text = "SENDE"
				price_color = _k.c("good")
				closed_row = true
			## Yuva yalnız seçim / sahiplik değişince yeniden kurulur.
			var vis: String = "%s|%s" % [sel, closed_row]
			if str(r.get("vis", "")) != vis:
				r["vis"] = vis
				var holder: CenterContainer = r["holder"]
				for c in holder.get_children():
					holder.remove_child(c)
					c.queue_free()
				var t: Control = _k.tile(null, 76.0, _k.c("line_hi") if not sel else _k.c("accent"), {"sel": sel, "dim": closed_row})
				var ic: Control = _k.wicon(WeaponCatalogScript.icon(key), 64.0, 1, closed_row)
				ic.position = ((t.size - ic.size) * 0.5).floor()
				t.add_child(ic)
				holder.add_child(t)
		"shield":
			sub.text = Logic.shield_summary(key)
			if GameManager.shield_enchant == key:
				price_text = "SENDE"
				price_color = _k.c("good")
				closed_row = true
			elif GameManager.shield_enchant != "":
				price_text = "KİLİTLİ"
				price_color = _k.c("dim")
				closed_row = true
			var dim_icon: bool = closed_row and GameManager.shield_enchant != key
			_set_lead(r, "s%s" % dim_icon, func() -> Control: return _k.icon(DarkKit.tex(str(ShieldEnchantDefs.ICONS.get(key, ""))), 44.0, dim_icon))
		"upgrade":
			var idx: int = int(entry.get("index", 0))
			var limit: int = Logic.upgrade_limit(idx)
			sub.text = "%s  (%d/%s)" % [Logic.upgrade_effect_text(idx).replace("\n", ", "), Logic.upgrade_count(idx), "∞" if limit <= 0 else str(limit)]
			if limit > 0 and Logic.upgrade_count(idx) >= limit:
				price_text = "TAMAM"
				price_color = _k.c("good")
				closed_row = true
			_set_lead(r, "u", func() -> Control:
				var badge: PanelContainer = _k.box(_k.c("panel3"), _k.c("line_hi"), 0.0, 3, 6)
				badge.custom_minimum_size = Vector2(40, 40)
				badge.add_child(_k.lbl(DarkKit.ROMAN[clampi(idx, 0, 4)], 24, _k.c("text"), HORIZONTAL_ALIGNMENT_CENTER))
				return badge)
		"wupgrade":
			var w_slot: int = int(entry.get("slot", 0))
			var w_idx: int = int(entry.get("index", 0))
			var w_rows: Array = Logic.slot_upgrade_rows(w_slot)
			## Açıklama yalnız seçili satırda (diğerleri tek satır ad - liste kısa kalsın).
			sub.text = str((w_rows[w_idx] as Dictionary)["text"]) if sel and w_idx >= 0 and w_idx < w_rows.size() else ""
			sub.visible = sub.text != ""
			if Logic.wupgrade_taken(w_slot, w_idx):
				price_text = "ALINDI"
				price_color = _k.c("good")
				closed_row = true
			var n: Label = r["name"]
			n.add_theme_color_override("font_color", _k.c("dim") if _row_state(w_slot, w_idx) == "locked" else _k.c("text"))
			_set_lead(r, "w%s|%s" % [_row_state(w_slot, w_idx), sel], func() -> Control: return _up_badge(w_slot, w_idx, 44.0, sel))
	if kind != "wupgrade":
		sub.visible = sub.text != ""
	price.text = price_text
	price.add_theme_color_override("font_color", price_color)
	coin.visible = not closed_row
	## Parçacık maliyeti: sadece alınabilir satırlarda; yetmiyorsa kırmızı.
	if r.has("shard_row"):
		var shard_cost: int = _entry_shard_cost(entry)
		(r["shard_row"] as Control).visible = shard_cost > 0 and not closed_row
		var scl: Label = r["shard_cost"]
		scl.text = "%d" % shard_cost
		scl.add_theme_color_override("font_color", DarkKit.SHARD_TEXT if GameManager.weapon_shards >= shard_cost else _k.c("bad"))
	else:
		(r["shard_cost"] as Label).text = "%d" % _entry_shard_cost(entry)
	var fill: Color = _k.c("panel3") if sel else (_k.c("inset") if closed_row else _k.c("panel2"))
	var bd: Color = _k.c("accent") if sel else _k.c("line")
	(r["panel"] as PanelContainer).add_theme_stylebox_override("panel", _k.sb(fill, bd, 3, 6, 8.0))


## Satır başı simgesi; aynı görünüşse (sig) eskisi kalır - seçimlerde gereksiz düğüm kurulmasın.
func _set_lead(r: Dictionary, sig: String, make: Callable) -> void:
	if str(r.get("lead_sig", "")) == sig:
		return
	r["lead_sig"] = sig
	var lead: CenterContainer = r["lead"]
	for c in lead.get_children():
		lead.remove_child(c)
		c.queue_free()
	lead.add_child(make.call())


func _refresh_status() -> void:
	if _status_label == null:
		return
	if _list_sub:
		_list_sub.text = ""
	if _tab == Tab.WEAPONS or _tab == Tab.ENCHANTS:
		_status_label.text = "Silah yuvası %d/%d" % [GameManager.owned_weapons.size(), Logic.max_weapons(_player) if is_instance_valid(_player) else 3]
		if _list_sub:
			_list_sub.text = "%d/4 · sıra serbest" % Logic.wupgrade_taken_count(_trait_slot) if _tab == Tab.ENCHANTS and not GameManager.owned_weapons.is_empty() else ""
	elif GameManager.shield_enchant == "":
		_status_label.text = "Şu an: Standart"
	else:
		_status_label.text = "Şu an: %s" % ShieldEnchantDefs.type_name(GameManager.shield_enchant)


## GEREKENLER (gereken / sende), kademe değişimi, sebep ve eylem düğmesi.
func _refresh_details() -> void:
	if _details_gold == null:
		return
	for c in _tier_row.get_children():
		_tier_row.remove_child(c)
		c.queue_free()
	if _selected.is_empty():
		_details_shard_row.visible = false
		_details_gold.text = "-"
		_details_gold_have.text = ""
		_details_gold_ok.visible = false
		_details_block.text = ""
		_set_action("GELİŞTİR" if _tab == Tab.ENCHANTS else "SATIN AL", false)
		return
	var price: int = _entry_price(_selected)
	var shard_cost: int = _entry_shard_cost(_selected)
	var closed_row: bool = not _row_open(_selected)
	_details_shard_row.visible = shard_cost > 0
	_details_shard.text = "%d" % shard_cost
	_details_shard_have.text = "/ %d" % GameManager.weapon_shards
	var s_ok: bool = GameManager.weapon_shards >= shard_cost
	_details_shard.add_theme_color_override("font_color", _k.c("price") if s_ok else _k.c("bad"))
	_details_shard_ok.rows = DarkKit.G_CHECK if s_ok else DarkKit.G_X
	_details_shard_ok.set_color(_k.c("good") if s_ok else _k.c("bad"))
	_details_gold.text = "%d" % price
	_details_gold_have.text = "/ %d" % GameManager.gold
	var g_ok: bool = GameManager.gold >= price
	_details_gold.add_theme_color_override("font_color", _k.c("price") if g_ok else _k.c("bad"))
	_details_gold_ok.visible = true
	_details_gold_ok.rows = DarkKit.G_CHECK if g_ok else DarkKit.G_X
	_details_gold_ok.set_color(_k.c("good") if g_ok else _k.c("bad"))
	var block: String = _entry_block(_selected)
	if block == "" and not g_ok:
		block = "Yetersiz altın"
	_details_block.text = block
	## Silah geliştirmesi: kademe (kontür rengi) değişimi.
	var kind: String = str(_selected.get("type", ""))
	if kind == "wupgrade" and not closed_row:
		var slot: int = int(_selected.get("slot", 0))
		var t0: int = _slot_tier(slot)
		var t1: int = 5 if bool(_selected.get("final", false)) else mini(4, t0 + 1)
		if t1 != t0:
			_tier_row.add_child(_k.lbl("Kademe", 24, _k.c("dim")))
			for t in [t0, t1]:
				var b: PanelContainer = _k.box(Color(_tier_color(t), 0.18), _tier_color(t), 4.0, 2, 3)
				b.add_child(_k.lbl(" %s " % DarkKit.ROMAN[t - 1], 24, _tier_color(t)))
				_tier_row.add_child(b)
				if t == t0:
					_tier_row.add_child(_k.glyph(DarkKit.G_ARROW, _k.c("dim"), 3))
			_tier_row.add_child(_k.lbl("kontür %s" % ["", "", "yeşil", "mavi", "mor", "kırmızı"][t1], 24, _k.c("dim")))
	if kind == "wupgrade" and not closed_row:
		var s_slot: int = int(_selected.get("slot", 0))
		var s_t0: int = _slot_tier(s_slot)
		var s_t1: int = 5 if bool(_selected.get("final", false)) else mini(4, s_t0 + 1)
		if s_t1 != s_t0:
			## Kademe başına stat (weapon.gd TIER_*): geliştirme silahı güçlendirir.
			var d_dmg: int = roundi((WeaponScript.tier_damage_mult(s_t1) / WeaponScript.tier_damage_mult(s_t0) - 1.0) * 100.0)
			var d_spd: int = roundi((WeaponScript.tier_fire_rate_mult(s_t0) / WeaponScript.tier_fire_rate_mult(s_t1) - 1.0) * 100.0)
			_tier_row.add_child(_k.lbl("+%%%d hasar, +%%%d saldırı hızı" % [d_dmg, d_spd], 24, _k.c("good")))
	var label: String = "SATIN AL"
	match kind:
		"wupgrade", "upgrade":
			label = "GELİŞTİR"
		"shield":
			label = "SEÇ VE AL"
	if closed_row:
		label = {"weapon": "SENDE", "shield": "SEÇİLDİ" if GameManager.shield_enchant == str(_selected.get("key", "")) else "KİLİTLİ"}.get(kind, "ALINDI")
	_set_action(label, _entry_can_buy(_selected))


func _set_action(text: String, enabled: bool) -> void:
	_action_btn.disabled = not enabled
	var tc: Color = _k.btn_tc("primary") if enabled else _k.c("dim")
	_action_lbl.text = text
	_action_lbl.add_theme_color_override("font_color", tc)
	_action_glyph.visible = text == "GELİŞTİR"
	_action_glyph.set_color(tc)


func _on_close_pressed() -> void:
	GameManager.unregister_blocking_panel(self)
	closed.emit()
	queue_free()
