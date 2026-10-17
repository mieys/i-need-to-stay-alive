extends CanvasLayer

## SEYYAR SATICI ekranı - "KLASİK PAZAR" (League of Legends dükkan düzeni). Kullanıcı 2026-10-16'da 4 prototipten A'yı seçti
## (tools/proto_20261016/dukkan_proto.gd, madde 195, 197): solda (KALDIRILDI) stat filtre sütunu, ortada stok kademe kademe (PARÇALAR / EPİK /
## EFSANEVİ), sağda seçilenin TARİF AĞACI (sendeki parçalar yeşil onaylı, bugün stokta olan parça sarı elmaslı) + statlar + pasif +
## SATIN AL, altta ÇANTAN (sahip olunan eşyalar; seç + SAT). Görünüş: shop_dark_kit.gd (kayrak + altın).
##
## KURALLAR (değişmedi, eski ekrandan):
##  - Stok traveling_merchant.gd'de oyuncu başına ÜRETİLİR, ziyaret boyunca sabit; setup()'a verilir. Her kart ziyaret başına 1 kez alınır:
##    "satıldı" kaydı KARTIN sözlüğünde (entry["sold"]) - TravelingMerchant._current_stock ile AYNI nesneler, ekranı kapatıp açmak hakkı
##    yenilemez; YENİLE (altınla, reroll_cost) ya da yeni ziyaret taze sözlükler üretir.
##  - Fiyat = Items.plan_purchase (sahip olunan parçalar - alt parçalar dahil - tüketilip fiyattan düşülür) + GameManager.apply_shop_discount.
##  - Satış iadesi Items.sell_refund (tam fiyatın %50'si), player.sell_owned_item; ikon parçalanıp altına döner (gold_reward_fx.gd).
##  - Oyunu DURDURMAZ (kişisel/asenkron alışveriş); başka bir modal oyunu durdurunca gizlenir, bitince geri gelir (bkz. _process).
##  - register_blocking_panel: açıkken ESC duraklatma menüsünü açmaz, yetenek tuşları oyuna gitmez (madde 31).
## SATIN ALMA: kartı seç + SATIN AL, ya da karta ÇİFT TIK / SAĞ TIK (LoL gibi). Kumanda: D-pad kartı seçer, A satın alır.
## Eski ekrandaki kart başı "AL" düğmeleri ve sağdaki DURUMUN stat paneli bu tasarımda yok (_buy_buttons testler için boş kalır).
## Sol stat FİLTRE sütunu 2026-10-17'de kullanıcı isteğiyle KALDIRILDI ("gereksiz"); kartlar artık hiç solmaz.
## SEÇİM TEK İŞARET: odaklanan kart zaten seçilir (focus_entered), bu yüzden kartta ayrıca kumanda odak halkası YOK - yuva halkası
## (DarkKit.tile "SelRing") tek göstergedir (eskiden tıklanan kartta iki halka üst üste görünüyordu).
## ANİMASYON (madde 200 ilkeleri): kartlar sırayla belirir (UiAnim.cascade), üstüne gelince nefes (UiAnim.pop), yuva halkası belirir,
## ayrıntı paneli seçim değişince yumuşakça gelir (UiAnim.reveal), çanta yuvaları nefes alır.
##
## YERLEŞİM DÖNGÜSÜ KORUMASI (2026-10-06 donma + çökme, madde 20): ayrıntı sütunu SABİT genişlikte; açıklama kaydırma kutusunun en az
## genişliği çubuk payıyla baştan ayrılır (DESC_SCROLLBAR_RESERVE) - çubuk görünüp kaybolunca genişlik <-> yükseklik döngüsü kurulmasın;
## tarif alanı sabit boyutlu (ağaç sığmazsa küçük yuvayla yeniden kurulur), seçim pencere boyunu değiştirmez.
## TELEFON (MobileUI): katman PHONE_K büyür, pencere güvenli alanı doldurur; stok + çanta kaydırma kutusunda
## (_phone_scroll), ayrıntı paneli kendi kaydırma kutusunda ("SidePanelScroll" - pencere boyu içerikten türemesin).

signal closed

const UiAnim := preload("res://scripts/ui_anim.gd")
const ModalSafeArea := preload("res://scripts/modal_safe_area.gd")
const EventSfx := preload("res://scripts/event_sfx.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const ReadingUiWatcher := preload("res://scripts/reading_ui_watcher.gd")
const GoldRewardFx := preload("res://scripts/gold_reward_fx.gd")
const DarkKit := preload("res://scripts/shop_dark_kit.gd")

const NPC_FRAMES := "res://assets/npc/seyyar_satici/seyyar_satici_frames.tres"
const WINDOW_SCALE := 1.0
const PHONE_K := 1.5
## Açıklama kutusunun dikey çubuk için ayrılan payı (px) - pay çubuktan büyük olmalı (bkz. dosya başı "yerleşim döngüsü").
const DESC_SCROLLBAR_RESERVE := 28.0
## Pasif açıklama kutusunun (masaüstü) EN AZ yüksekliği: 4 satır (22 px/satır; en uzun pasif 3 satır). Eskiden 56 px (2 satır) idi - 3 satırlık pasifler kırpılıp çubuk çıkıyordu.
## Sabit değer: seçim değişince pencere boyu oynamaz (yerleşim döngüsü koruması). Telefonda tüm panel zaten kaydığı için 0.
const DESC_MIN_H := 88.0
## Özellikler bloğu sabit yüksekliği için: en çok stat satırı (Rüzgâr Yürüyen Çizmeleri = 4), satır yüksekliği (24 px ikon), satır arası, "PASİF" başlığı (+ pay).
const STAT_ROWS_MAX := 4
const STAT_ROW_H := 24.0
const STAT_ROW_GAP := 2.0
const PROPS_GAP := 4.0
const PASSIVE_HEAD_H := 24.0
const DETAIL_W := 640.0
const DETAIL_W_PHONE := 440.0
## Tarif alanı sabit yüksekliği: en uzun ağaç (48 px yuva, 3 kat / epik + "ŞUNA DÖNÜŞÜR" sırası) 264 px - 8 pay (eskiden 332, ~60 px boşluk).
const TREE_H := 272.0
const CELL_W := 150.0
const CELL_TILE := 96.0
const BAG_TILE := 48.0

## Stat satırlarının simgeleri (Items.STAT_LABELS anahtarı -> doku).
const STAT_ICONS := {
	"damage_bonus": "res://assets/ui/stat_mini/damage.png", "item_fire_rate_percent": "res://assets/ui/stat_mini/fire_rate.png",
	"crit_chance_bonus": "res://assets/ui/stat_mini/crit_chance.png", "max_health": "res://assets/ui/level_up_icons/stat_max_health.png",
	"item_health_regen": "res://assets/ui/stat_mini/health_regen.png", "lifesteal_percent": "res://assets/ui/stat_mini/lifesteal.png",
	"item_shield_power_flat": "res://assets/ui/stat_mini/shield_amount.png", "item_shield_regen_flat": "res://assets/ui/stat_mini/shield_regen.png",
	"item_shield_regen_percent": "res://assets/ui/stat_mini/shield_regen.png", "shield_pen_percent": "res://assets/ui/stat_mini/shield_pen_percent.png",
	"cooldown_reduction_percent": "res://assets/ui/stat_mini/cooldown_reduction.png", "item_speed_percent": "res://assets/ui/stat_mini/speed.png",
	"dodge_chance": "res://assets/ui/stat_mini/dodge.png", "heal_shield_power": "res://assets/ui/stat_mini/heal_power.png",
	"luck": "res://assets/ui/stat_mini/luck.png", "exp_gain_percent": "res://assets/ui/level_up_icons/stat_exp_gain.png",
	"shield_protection_bonus": "res://assets/ui/stat_mini/shield_protection.png",
}

var _k = DarkKit.new(DarkKit.PAL_SLATE)
var _player: Node = null
var _stock: Array = []
var _selected_index: int = -1
## Stok indeksine göre: kart (odaklanabilir PanelContainer) ve fiyat yazısı (sayı ya da "SATILDI").
var _card_panels: Array = []
var _price_labels: Array = []
var _buy_buttons: Array = [] ## bu tasarımda kart başı AL yok (eski testlerin okuduğu alan; hep boş)
var _cells: Array = [] ## [{card, holder, amt, strike}]
var _merchant: Node = null
var _reroll_btn: Button = null
var _reroll_amt: HBoxContainer = null
var _stock_box: VBoxContainer = null
var _view_bag: int = -1 ## çantada seçili eşya (GameManager.owned_items dizini), -1 = stoktaki seçim gösterilir

var _details_col: VBoxContainer ## ayrıntı içeriği (seçim değişince yumuşakça gelir)
var _details_name: Label
var _details_tier: Label
var _details_icon_holder: CenterContainer
var _details_price: HBoxContainer
var _details_full_row: HBoxContainer
var _details_full: Label
var _details_tree_head: Label
var _details_tree_area: Control
var _details_stats: GridContainer
var _details_passive_head: Label
var _details_desc: Label
var _details_note: Label
var _buy_btn: Button
var _buy_btn_lbl: Label
var _buy_btn_amt: HBoxContainer

var _bag_body: HBoxContainer = null
var _bag_tiles: Dictionary = {} ## owned_items dizini -> yuva (parçalanma efektinin başlangıç noktası)
var _sell_btn: Button = null
var _sell_amt: HBoxContainer = null
var _gold_label: Label = null
var _timer_label: Label = null
var _timer_bar: DarkKit.Bar = null
var _tick: float = 0.0
var _last_sig: int = 0
var _fit_callables: Array[Callable] = []
var _last_reserved: float = -1.0
var _phone: bool = false
var _phone_scroll: ScrollContainer = null


## Seyyar satıcı dükkanı açıkken karakter okuma (read) pozuna geçer - bkz. ReadingUiWatcher.
func _enter_tree() -> void:
	add_to_group(ReadingUiWatcher.GROUP)


func setup(player: Node, stock: Array, merchant: Node = null) -> void:
	_player = player
	_stock = stock
	_sort_stock_by_cost()
	_merchant = merchant
	EventSfx.play(get_tree(), &"shop_open")
	## HUD'un üstündeki geçici yazıların (satıcı sayacı, ipuçları) üstünde; grup paneli (96) bilerek bunun da üstünde (madde 36).
	layer = 80
	_build_ui()
	UiAnim.window_in(self)
	## Bu ekran get_tree().paused KULLANMAZ: main.gd'nin genel ESC/duraklatma kontrolü üstüne pause menüsü açmasın.
	GameManager.register_blocking_panel(self)
	## Duraklamada da çalışsın ki kendini gizleyip geri açabilsin (bkz. _process).
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	## 2026-09-24 kilit düzeltmesi: bu ekranın karartması tüm tıklamaları yutar; level atlama / sandık gibi ALTTAKİ katmanlarda açılıp
	## oyunu duraklatan bir modal varken ekran gizlenir (gizli CanvasLayer girdi almaz), duraklama bitince aynen geri gelir.
	var paused_by_other: bool = get_tree().paused
	if visible == paused_by_other:
		visible = not paused_by_other
	if paused_by_other:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_on_close_pressed()
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.25
		if not _phone:
			_refit_if_party_changed()
		_refresh_header()
		_refresh_reroll_button()
		## Altın / eşyalar başka yoldan da değişebilir (paylaşılan altın, sandık, envanterden satış) - fiyatlar sahip olunan parçalara bağlı.
		if _state_sig() != _last_sig:
			_refresh_all_buy_states()


func _state_sig() -> int:
	return hash([GameManager.gold, str(GameManager.owned_items)])


# ------------------------------------------------------------------ pencere iskeleti

## Telefonda pencerenin kaplayacağı alan (katman koordinatı = ekran / PHONE_K).
func _phone_rect() -> Rect2:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = MobileUIScript.safe_margins(get_viewport())
	return Rect2(safe.position / PHONE_K, (view - safe.position - safe.size) / PHONE_K)


## Container çocuğun ölçeğini her yerleşimde 1'e sıfırladığı için ölçek ve konum yerleşim BİTTİKTEN sonra (sort_children) verilir;
## pencere grup panelinin (sağ üst, layer 96) soluna sığıp GÜVENLİ ALANDA ortalanır (modal_safe_area.gd), sığmazsa küçülür.
func _apply_window_scale(window: Control) -> void:
	var fit_scale := func() -> void:
		if not is_instance_valid(window):
			return
		window.pivot_offset = window.size * 0.5
		var view: Vector2 = window.get_viewport_rect().size
		var safe: Rect2 = ModalSafeArea.rect(window.get_tree(), view)
		var fit: float = minf(safe.size.x * 0.97 / maxf(1.0, window.size.x), safe.size.y * 0.97 / maxf(1.0, window.size.y))
		window.scale = Vector2.ONE * minf(WINDOW_SCALE, fit)
		## position (ham, ölçeksiz) kullanılır - 4.7'de global_position pivot/ölçek kaymasını içeriyor.
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


## Grup paneli sonradan görünür/gizli olursa ya da genişliği değişirse pencere yeniden sığdırılır.
func _refit_if_party_changed() -> void:
	var reserved: float = ModalSafeArea.reserved_right(get_tree(), get_viewport().get_visible_rect().size)
	if is_equal_approx(reserved, _last_reserved):
		return
	_last_reserved = reserved
	for c in _fit_callables:
		if c.is_valid():
			c.call()


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
	col.add_child(body)
	_stock_box = _k.v(10)
	if _phone:
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_phone_scroll = ScrollContainer.new()
		_phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_phone_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_phone_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_phone_scroll.follow_focus = true
		var inner: VBoxContainer = _k.v(14)
		inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(_stock_box)
		inner.add_child(_build_bag())
		_phone_scroll.add_child(inner)
		body.add_child(_phone_scroll)
	else:
		body.add_child(_stock_box)
	body.add_child(_build_details())
	if not _phone:
		col.add_child(_build_bag())
	_populate_stock()

	UISound.connect_all_buttons(self)
	_refresh_all_buy_states()
	_refresh_reroll_button()
	_refresh_header()
	if not _stock.is_empty():
		_select_index(0)


## Başlık: satıcı portresi | SEYYAR SATICI + ayrılmasına kalan süre ...... YENİLE | altın | X
func _build_header() -> HBoxContainer:
	var row: HBoxContainer = _k.h(16)
	var por: PanelContainer = _k.box(_k.c("inset"), _k.c("line_hi"), 2.0)
	var sf := load(NPC_FRAMES) as SpriteFrames
	if sf != null and sf.has_animation(&"idle_down"):
		por.add_child(_k.icon(sf.get_frame_texture(&"idle_down", 0), 64.0 if _phone else 96.0))
	row.add_child(por)
	var tv: VBoxContainer = _k.v(2)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_child(_k.lbl("SEYYAR SATICI", 40 if _phone else 48, _k.c("accent")))
	var tr: HBoxContainer = _k.h(10)
	tr.add_child(_k.lbl("Ayrılmasına", 24, _k.c("dim")))
	_timer_label = _k.lbl("", 24, _k.c("text"))
	_timer_label.custom_minimum_size.x = 56
	tr.add_child(_timer_label)
	_timer_bar = DarkKit.Bar.new(1.0, _k.c("accent"), _k.c("inset"), 10, 150)
	tr.add_child(_timer_bar)
	tv.add_child(tr)
	row.add_child(tv)
	row.add_child(_k.sp(0, 0, true))
	## YENİLE: altınla taze stok (fiyat ziyaret başına artar - reroll_cost; sayaç TravelingMerchant'ta).
	var rr: HBoxContainer = _k.h(10)
	rr.add_child(_k.glyph(DarkKit.G_REROLL, _k.c("text"), 3))
	rr.add_child(_k.lbl("YENİLE", 32, _k.c("text")))
	_reroll_amt = _k.amt(0, 32, _k.c("price"))
	rr.add_child(_reroll_amt)
	_reroll_btn = _k.row_btn(rr, "ghost", 56, 236)
	_reroll_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reroll_btn.tooltip_text = "Stoğu altınla yenile (her yenilemede fiyat artar)"
	_reroll_btn.pressed.connect(_on_reroll_pressed)
	row.add_child(_reroll_btn)
	var gc: PanelContainer = _k.chip("gold", "Altın")
	_gold_label = gc.get_meta("label")
	row.add_child(gc)
	var close_btn: Button = _k.btn("X", "ghost", 32, 56, 56)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_on_close_pressed)
	row.add_child(close_btn)
	return row


func _refresh_header() -> void:
	if _gold_label:
		_gold_label.text = str(GameManager.gold)
	if _timer_label == null:
		return
	var has_timer: bool = _merchant != null and is_instance_valid(_merchant) and _merchant.has_method("get_visit_time_left")
	var row: Control = _timer_label.get_parent() as Control
	row.visible = has_timer
	if not has_timer:
		return
	var left: float = maxf(0.0, float(_merchant.get_visit_time_left()))
	var total: float = maxf(1.0, float(_merchant.get_visit_duration())) if _merchant.has_method("get_visit_duration") else 180.0
	_timer_label.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	_timer_bar.set_frac(left / total)


# ------------------------------------------------------------------ orta: stok (kademe satırları)

## Kademe satırları (traveling_merchant.gd: 4 parça, 4 epik, 4 efsanevi); kartlar stok sırasıyla (bkz. _sort_stock_by_cost).
func _populate_stock() -> void:
	for c in _stock_box.get_children():
		_stock_box.remove_child(c)
		c.queue_free()
	for old in _card_panels:
		if is_instance_valid(old):
			(old as Node).remove_from_group(&"gamepad_first_focus") ## yenilemede silinen kart ilk odak adayı kalmasın
	_card_panels.clear()
	_price_labels.clear()
	_cells.clear()
	_card_panels.resize(_stock.size())
	_price_labels.resize(_stock.size())
	_cells.resize(_stock.size())
	for i in _cells.size():
		_cells[i] = {}
	var titles: Array = ["PARÇALAR", "EPİK EŞYALAR", "EFSANEVİ EŞYALAR"]
	var rows: Array[HBoxContainer] = []
	for kd in [Items.KADEME_PARCA, Items.KADEME_EPIK, Items.KADEME_EFSANEVI]:
		var idxs: Array = []
		for i in _stock.size():
			if str(_stock[i].get("type", "")) == "item" and Items.kademe(str(_stock[i].get("key", ""))) == kd:
				idxs.append(i)
		if idxs.is_empty():
			continue
		var head: HBoxContainer = _k.h(10)
		var bar := ColorRect.new()
		bar.color = DarkKit.TIER_COL[kd - 1]
		bar.custom_minimum_size = Vector2(6, 26)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(bar)
		head.add_child(_k.lbl(titles[kd - 1], 32, (DarkKit.TIER_COL[kd - 1] as Color).lightened(0.2)))
		_stock_box.add_child(head)
		var row: HBoxContainer = _k.h(12)
		for i: int in idxs:
			row.add_child(_build_cell(i))
		_stock_box.add_child(row)
		rows.append(row)
	if not _phone:
		_stock_box.add_child(_k.sp(0, 0, false, true))
		var hint: HBoxContainer = _k.h(8)
		hint.add_child(_k.glyph(DarkKit.G_DIAMOND, _k.c("price"), 2))
		## Kırpılan etiket: ipucu stok sütununu genişletmesin.
		hint.add_child(_k.clip("Yeşil fiyat: sendeki parçalar düşüldü · çift tık / sağ tık: satın al", 24, _k.c("dim"), 600.0))
		_stock_box.add_child(hint)
	## Kumanda: dükkan açılınca ilk odak ilk kartta (gamepad_ui.gd FIRST_FOCUS_GROUP).
	if not _card_panels.is_empty() and _card_panels[0] != null:
		(_card_panels[0] as Node).add_to_group(&"gamepad_first_focus")
	for i in _cells.size():
		_refresh_cell(i)
	UISound.connect_all_buttons(self)
	## Giriş animasyonu (madde 200): başlıklar + satırlar sırayla belirir, her satırın kartları da tek tek (YENİLE'de de).
	const ENTRY_STEP := 0.07
	const ENTRY_DELAY := 0.04
	UiAnim.cascade(_stock_box, ENTRY_STEP, 16, ENTRY_DELAY)
	for r: HBoxContainer in rows:
		UiAnim.cascade(r, 0.045, 8, ENTRY_DELAY + float(r.get_index()) * ENTRY_STEP)


func _build_cell(index: int) -> PanelContainer:
	var entry: Dictionary = _stock[index]
	var key: String = str(entry.get("key", ""))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _k.sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 4.0))
	card.custom_minimum_size.x = CELL_W
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.tooltip_text = Items.item_name(key)
	card.gui_input.connect(_on_card_gui_input.bind(index))
	## Kumanda: odaklanan kart seçilir (yuva halkası göstergedir - ayrıca GamepadFocusHelper halkası EKLENMEZ, çift halka olurdu), A satın alır.
	card.focus_mode = Control.FOCUS_ALL
	card.focus_entered.connect(_select_index.bind(index))
	card.mouse_entered.connect(UiAnim.pop.bind(card)) ## üstüne gelince nefes (madde 200); odak gelince _select_index zaten ring gösterir
	var col: VBoxContainer = _k.v(4)
	card.add_child(col)
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(CELL_TILE + 12, CELL_TILE + 12)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	col.add_child(_k.clip(Items.item_name(key), 24, _k.c("text"), CELL_W - 8.0, HORIZONTAL_ALIGNMENT_CENTER))
	var pr: HBoxContainer = _k.h(6)
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	var a: HBoxContainer = _k.amt(0, 24, _k.c("price"))
	pr.add_child(a)
	var st: DarkKit.StrikeLabel = _k.strike_lbl("", 24, _k.c("dim"))
	pr.add_child(st)
	col.add_child(pr)
	_cells[index] = {"card": card, "holder": holder, "amt": a, "strike": st}
	_card_panels[index] = card
	_price_labels[index] = a.get_meta("label")
	return card


## Kartın yuvası (seçim halkası / satıldı) + fiyat satırı: sendeki parçalar düşülmüşse yeşil yeni fiyat + üstü çizili tam fiyat;
## altın yetmiyorsa kırmızı; alınamıyorsa (yuva dolu / zaten sende) sebebin kısası.
func _refresh_cell(index: int) -> void:
	if index < 0 or index >= _cells.size() or (_cells[index] as Dictionary).is_empty():
		return
	var cell: Dictionary = _cells[index]
	var entry: Dictionary = _stock[index]
	var key: String = str(entry.get("key", ""))
	var sold: bool = _entry_sold(entry)
	var holder: CenterContainer = cell["holder"]
	for c in holder.get_children():
		holder.remove_child(c)
		c.queue_free()
	var kd: int = Items.kademe(key)
	holder.add_child(_k.tile(Items.icon(key), CELL_TILE, DarkKit.TIER_COL[clampi(kd, 1, 3) - 1], {"sel": index == _selected_index and _view_bag < 0, "sold": sold}))
	var a: HBoxContainer = cell["amt"]
	var lab: Label = a.get_meta("label")
	var coin_node: Control = a.get_child(0) as Control
	var st: DarkKit.StrikeLabel = cell["strike"]
	st.visible = false
	if sold:
		coin_node.visible = false
		lab.text = "SATILDI"
		lab.add_theme_color_override("font_color", _k.c("dim"))
	else:
		var reason: String = Items.purchase_block_reason(key, GameManager.owned_items, _part_slots())
		var cost: int = _entry_cost(entry)
		var full: int = GameManager.apply_shop_discount(Items.cost(key))
		if reason != "":
			coin_node.visible = false
			lab.text = "SENDE VAR" if Items.owns(GameManager.owned_items, key) else "YUVA DOLU"
			lab.add_theme_color_override("font_color", _k.c("dim"))
		else:
			coin_node.visible = true
			lab.text = str(cost)
			var col: Color = _k.c("price")
			if GameManager.gold < cost:
				col = _k.c("bad")
			elif cost < full:
				col = _k.c("good")
			lab.add_theme_color_override("font_color", col)
			if cost < full:
				st.text = str(full)
				st.visible = true


func _on_card_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_select_index(index)
			if mb.double_click:
				_on_buy_pressed(index)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_select_index(index)
			_on_buy_pressed(index)
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		## Kumanda/klavye: odaktaki kartı satın al (satılmış/yetersiz altınlı kartta _on_buy_pressed sessizce çıkar).
		_select_index(index)
		_on_buy_pressed(index)


func _select_index(index: int) -> void:
	if index < 0 or index >= _stock.size():
		return
	var prev: int = _selected_index
	var was_bag: bool = _view_bag >= 0
	_selected_index = index
	_view_bag = -1
	for i in [prev, index]:
		_set_cell_ring(int(i), int(i) == index)
	if was_bag:
		_refresh_bag()
	_refresh_details()
	if index != prev or was_bag:
		UiAnim.reveal(_details_col)


func _set_cell_ring(index: int, on: bool) -> void:
	if index < 0 or index >= _cells.size() or (_cells[index] as Dictionary).is_empty():
		return
	var holder: CenterContainer = _cells[index]["holder"]
	if holder.get_child_count() == 0:
		return
	var ring: Node = holder.get_child(0).get_node_or_null("SelRing")
	if ring:
		var was_on: bool = (ring as Control).visible
		(ring as Control).visible = on
		if on and not was_on:
			UiAnim.reveal(ring as Control, 0.0, 0.12)


# ------------------------------------------------------------------ sağ: ayrıntı (tarif ağacı + statlar + SATIN AL)

func _detail_w() -> float:
	return DETAIL_W_PHONE if _phone else DETAIL_W


func _build_details() -> Control:
	var panel: PanelContainer = _k.box(_k.c("panel2"), _k.c("line"), 18.0)
	panel.custom_minimum_size.x = _detail_w()
	var inner_w: float = _detail_w() - 36.0
	var dv: VBoxContainer = _k.v(6)
	_details_col = dv
	if _phone:
		## Telefonda panel içeriği kendi kaydırma kutusunda: en az yüksekliği 0, pencere boyu içerikten türemez.
		var sc := ScrollContainer.new()
		sc.name = "SidePanelScroll"
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_child(sc)
		dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(dv)
	else:
		panel.add_child(dv)
	var head: HBoxContainer = _k.h(16)
	_details_icon_holder = CenterContainer.new()
	_details_icon_holder.custom_minimum_size = Vector2(72, 72)
	_details_icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_details_icon_holder)
	var nv: VBoxContainer = _k.v(0)
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_name = _k.clip("", 32 if _phone else 40, _k.c("text"), 10.0)
	_details_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.add_child(_details_name)
	_details_tier = _k.lbl("", 24, _k.c("dim"))
	nv.add_child(_details_tier)
	head.add_child(nv)
	var pv: VBoxContainer = _k.v(0)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	_details_price = _k.amt(0, 40, _k.c("price"))
	_details_price.alignment = BoxContainer.ALIGNMENT_END
	pv.add_child(_details_price)
	_details_full_row = _k.h(6)
	_details_full_row.alignment = BoxContainer.ALIGNMENT_END
	_details_full_row.add_child(_k.lbl("tam fiyat", 24, _k.c("dim")))
	_details_full = _k.strike_lbl("", 24, _k.c("dim"))
	_details_full_row.add_child(_details_full)
	pv.add_child(_details_full_row)
	head.add_child(pv)
	dv.add_child(head)
	dv.add_child(_k.hline())
	_details_tree_head = _k.lbl("TARİF", 24, _k.c("dim"))
	dv.add_child(_details_tree_head)
	_details_tree_area = Control.new()
	_details_tree_area.custom_minimum_size = Vector2(inner_w, TREE_H)
	_details_tree_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dv.add_child(_details_tree_area)
	## ÖZELLİKLER bloğu: statlar ALT ALTA (tek sütun, kullanıcı isteği 2026-10-17) + PASİF. Masaüstünde bloğun en az yüksekliği SABİT
	## (en kalabalık eşya = 4 stat satırı + başlık + pasif kutusu): az statlı eşyada boşalan yer pasif kutusuna kalır, seçim pencere boyunu oynatmaz.
	var props: VBoxContainer = _k.v(int(PROPS_GAP))
	props.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not _phone:
		props.custom_minimum_size.y = STAT_ROWS_MAX * STAT_ROW_H + (STAT_ROWS_MAX - 1) * STAT_ROW_GAP + 2.0 * PROPS_GAP + PASSIVE_HEAD_H + DESC_MIN_H
	dv.add_child(props)
	_details_stats = GridContainer.new()
	_details_stats.columns = 1
	_details_stats.add_theme_constant_override("h_separation", 24)
	_details_stats.add_theme_constant_override("v_separation", int(STAT_ROW_GAP))
	_details_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	props.add_child(_details_stats)
	_details_passive_head = _k.lbl("PASİF", 24, _k.c("accent"))
	props.add_child(_details_passive_head)
	var desc_scroll := ScrollContainer.new()
	desc_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	## En az genişlik çubuk payıyla baştan sabit (bkz. dosya başı "yerleşim döngüsü").
	desc_scroll.custom_minimum_size = Vector2(inner_w, 0 if _phone else DESC_MIN_H)
	if _phone:
		desc_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED ## telefonda tüm panel zaten kayar
	props.add_child(desc_scroll)
	_details_desc = _k.wrap("", 24, _k.c("text"), inner_w - DESC_SCROLLBAR_RESERVE)
	_details_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_scroll.add_child(_details_desc)
	var br: HBoxContainer = _k.h(14)
	_details_note = _k.wrap("", 24, _k.c("dim"), 10.0)
	_details_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_note.custom_minimum_size.y = 56
	br.add_child(_details_note)
	var row: HBoxContainer = _k.h(12)
	_buy_btn_lbl = _k.lbl("SATIN AL", 32, _k.btn_tc("primary"))
	_buy_btn_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	row.add_child(_buy_btn_lbl)
	_buy_btn_amt = _k.amt(0, 32, _k.btn_tc("primary"))
	row.add_child(_buy_btn_amt)
	_buy_btn = _k.row_btn(row, "primary", 64, 260.0 if _phone else 300.0)
	_buy_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	_buy_btn.pressed.connect(_on_detail_action)
	br.add_child(_buy_btn)
	dv.add_child(br)
	return panel


## Ayrıntıda gösterilen eşya: çantadan seçilen ya da stoktaki seçili kart.
func _view_key() -> String:
	if _view_bag >= 0 and _view_bag < GameManager.owned_items.size():
		return str((GameManager.owned_items[_view_bag] as Dictionary).get("key", ""))
	if _selected_index >= 0 and _selected_index < _stock.size():
		return str(_stock[_selected_index].get("key", ""))
	return ""


func _refresh_details() -> void:
	if _details_name == null:
		return
	var key: String = _view_key()
	if key == "" or not Items.DEFS.has(key):
		return
	var from_bag: bool = _view_bag >= 0
	var kd: int = clampi(Items.kademe(key), 1, 3)
	var tc: Color = DarkKit.TIER_COL[kd - 1]
	_details_name.text = Items.item_name(key)
	_details_name.add_theme_color_override("font_color", tc.lightened(0.25))
	_details_tier.text = Items.KADEME_NAMES[kd - 1].to_upper() + ("  ·  ÇANTANDA" if from_bag else "")
	_details_tier.add_theme_color_override("font_color", tc)
	for c in _details_icon_holder.get_children():
		_details_icon_holder.remove_child(c)
		c.queue_free()
	_details_icon_holder.add_child(_k.tile(Items.icon(key), 72.0, tc))
	## Fiyat: stokta ödenecek (parçalar düşülmüş) + tam fiyat; çantada satış iadesi.
	var plab: Label = _details_price.get_meta("label")
	var entry: Dictionary = {} if from_bag else _stock[_selected_index]
	var cost: int = 0
	var full: int = GameManager.apply_shop_discount(Items.cost(key))
	if from_bag:
		plab.text = "+%d" % Items.sell_refund(key)
		plab.add_theme_color_override("font_color", _k.c("good"))
		_details_full_row.visible = false
	else:
		cost = _entry_cost(entry)
		plab.text = str(cost)
		plab.add_theme_color_override("font_color", _k.c("good") if cost < full else (_k.c("bad") if GameManager.gold < cost else _k.c("price")))
		_details_full_row.visible = cost < full
		_details_full.text = str(full)
	_rebuild_tree(key, from_bag)
	## Statlar + pasif
	for c in _details_stats.get_children():
		_details_stats.remove_child(c)
		c.queue_free()
	var stats: Dictionary = (Items.get_def(key) as Dictionary).get("stats", {})
	for s: String in stats:
		if Items.PASSIVE_ONLY_STATS.has(s) or not Items.STAT_LABELS.has(s):
			continue
		_details_stats.add_child(_stat_line(s, float(stats[s])))
	var passive: String = str((Items.get_def(key) as Dictionary).get("passive", ""))
	_details_passive_head.visible = passive != ""
	_details_desc.text = passive
	## Sebep + not + düğme
	var block: String = ""
	var note: String = ""
	if from_bag:
		note = "Satış iadesi tam fiyatın %%%d'i." % int(round(Items.SELL_REFUND_RATIO * 100.0))
		_set_action_button("SAT", "+%d" % Items.sell_refund(key), "ghost", true)
	else:
		var sold: bool = _entry_sold(entry)
		if sold:
			block = "Bu ziyarette alındı"
		else:
			block = Items.purchase_block_reason(key, GameManager.owned_items, _part_slots())
			if block == "" and GameManager.gold < cost:
				block = "Yetersiz altın (%d eksik)" % (cost - GameManager.gold)
		var consumed: Array = []
		for idx in Items.plan_purchase(key, GameManager.owned_items).get("consume", []):
			if int(idx) >= 0 and int(idx) < GameManager.owned_items.size():
				consumed.append(Items.item_name(str((GameManager.owned_items[int(idx)] as Dictionary).get("key", ""))))
		note = ("Tüketilir: " + ", ".join(consumed)) if not consumed.is_empty() else "Ziyaret başına her eşyadan 1 tane alınır."
		_set_action_button("SATILDI" if sold else "SATIN AL", "" if sold else str(cost), "primary", _entry_can_buy(entry, _selected_index))
	## Alınamıyorsa sebep (kırmızı) not yerine yazılır.
	_details_note.text = block if block != "" else note
	_details_note.add_theme_color_override("font_color", _k.c("bad") if block != "" else _k.c("dim"))


func _set_action_button(text: String, amount: String, kind: String, enabled: bool) -> void:
	_k.btn_style(_buy_btn, kind)
	_buy_btn.disabled = not enabled
	var tc: Color = _k.btn_tc(kind) if enabled else _k.c("dim")
	_buy_btn_lbl.text = text
	_buy_btn_lbl.add_theme_color_override("font_color", tc)
	_buy_btn_amt.visible = amount != ""
	var al: Label = _buy_btn_amt.get_meta("label")
	al.text = amount
	al.add_theme_color_override("font_color", tc)


func _on_detail_action() -> void:
	if _view_bag >= 0:
		_on_sell_pressed()
	else:
		_on_buy_pressed(_selected_index)


func _stat_line(s: String, val: float) -> HBoxContainer:
	var row: HBoxContainer = _k.h(8)
	row.add_child(_k.icon(DarkKit.tex(str(STAT_ICONS.get(s, ""))), 24.0))
	var lab: Array = Items.STAT_LABELS[s]
	var txt: String = ("+%%%s %s" % [_num(val * 100.0), lab[0]]) if bool(lab[1]) else ("+%s %s" % [_num(val), lab[0]])
	row.add_child(_k.lbl(txt, 24, _k.c("text")))
	return row


static func _num(v: float) -> String:
	return str(int(round(v))) if is_equal_approx(v, round(v)) else ("%.1f" % v).replace(".", ",")


## Tarif ağacı (kök üstte, parçalar altta, dirsekli çizgiler) + "ŞUNA DÖNÜŞÜR" sırası; sabit boyutlu alana sığmazsa küçük yuvayla kurulur.
func _rebuild_tree(key: String, from_bag: bool) -> void:
	for c in _details_tree_area.get_children():
		_details_tree_area.remove_child(c)
		c.queue_free()
	var area: Vector2 = _details_tree_area.custom_minimum_size
	var content: VBoxContainer = _k.v(10)
	var has_recipe: bool = not (Items.recipe(key) as Array).is_empty()
	var ups: Array = Items.builds_into(key)
	var ups_h: float = 0.0 if ups.is_empty() else 34.0 + 56.0
	_details_tree_head.text = "TARİF" if has_recipe else "ŞUNA DÖNÜŞÜR"
	if has_recipe:
		var pool: Array = []
		if not from_bag:
			for e in GameManager.owned_items:
				pool.append(str((e as Dictionary).get("key", "")))
		var data: Dictionary = _tree_data(key, pool, false, true)
		var built: Control = null
		for s: float in [72.0, 56.0, 48.0]:
			var fs: int = 24
			var w: float = _tree_w(data, s, 12.0 if s > 50.0 else 8.0, fs)
			var hh: float = _tree_h(data, s, fs)
			if (w <= area.x and hh + ups_h <= area.y) or s == 48.0:
				built = _tree_view(data, s, 12.0 if s > 50.0 else 8.0, fs)
				break
		content.add_child(_k.center(built))
	if not ups.is_empty():
		if has_recipe:
			content.add_child(_k.lbl("ŞUNA DÖNÜŞÜR", 24, _k.c("dim")))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		flow.custom_minimum_size.x = area.x
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for u: String in ups:
			var t: Control = _k.tile(Items.icon(u), 48.0, DarkKit.TIER_COL[clampi(Items.kademe(u), 1, 3) - 1], {"stock": _in_stock(u)})
			t.mouse_filter = Control.MOUSE_FILTER_PASS
			t.tooltip_text = "%s (%d altın)" % [Items.item_name(u), Items.cost(u)]
			flow.add_child(t)
		content.add_child(flow)
	if not has_recipe and ups.is_empty():
		content.add_child(_k.lbl("Temel eşya", 24, _k.c("dim")))
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.position = Vector2.ZERO
	cc.size = area
	cc.add_child(content)
	_details_tree_area.add_child(cc)


func _in_stock(key: String) -> bool:
	for e in _stock:
		if str((e as Dictionary).get("key", "")) == key and not _entry_sold(e):
			return true
	return false


## Ağaç düğümü: owned = sendeki parça (tüketilecek, Items._obtain ile AYNI sıra), covered = sendeki bir parçanın alt parçası (soluk).
func _tree_data(key: String, pool: Array, covered: bool, is_root: bool) -> Dictionary:
	var st: String = "need"
	if covered:
		st = "covered"
	elif not is_root and pool.has(key):
		pool.erase(key)
		st = "owned"
	var n: Dictionary = {"key": key, "state": st, "kids": []}
	for comp in Items.recipe(key):
		(n["kids"] as Array).append(_tree_data(str(comp), pool, st == "owned" or st == "covered", false))
	return n


## Düğüm genişliği = yuva ya da altındaki fiyat/SENDE yazısı (hangisi genişse).
func _tree_w(n: Dictionary, s: float, gx: float, fs: int) -> float:
	var own: float = s
	match str(n["state"]):
		"owned":
			own = maxf(s, _k.tw("SENDE", fs))
		"need":
			own = maxf(s, _k.amt_w(Items.cost(str(n["key"])), fs))
	var kids: Array = n["kids"]
	if kids.is_empty():
		return own
	var w: float = 0.0
	for k: Dictionary in kids:
		w += _tree_w(k, s, gx, fs)
	w += gx * (kids.size() - 1)
	return maxf(own, w)


func _tree_depth(n: Dictionary) -> int:
	var d: int = 0
	for k: Dictionary in n["kids"]:
		d = maxi(d, _tree_depth(k))
	return d + 1


func _tree_h(n: Dictionary, s: float, fs: int) -> float:
	var depth: int = _tree_depth(n)
	return depth * (s + fs + 8.0) + (depth - 1) * 8.0 + 6.0


func _tree_view(data: Dictionary, s: float, gx: float, fs: int) -> Control:
	var lh: float = fs + 8.0
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ln := DarkKit.Lines.new()
	host.add_child(ln)
	var w: float = _tree_w(data, s, gx, fs)
	host.custom_minimum_size = Vector2(w + 12.0, _tree_h(data, s, fs))
	ln.size = host.custom_minimum_size
	_tree_place(data, 6.0, 0, host, ln, Vector2.INF, s, gx, lh, fs)
	return host


func _tree_place(n: Dictionary, x0: float, d: int, host: Control, ln: DarkKit.Lines, anchor: Vector2, s: float, gx: float, lh: float, fs: int) -> void:
	var w: float = _tree_w(n, s, gx, fs)
	var cx: float = floorf(x0 + w * 0.5)
	var y: float = 6.0 + d * (s + lh + 8.0)
	var key: String = n["key"]
	var st: String = n["state"]
	var t: Control = _k.tile(Items.icon(key), s, DarkKit.TIER_COL[clampi(Items.kademe(key), 1, 3) - 1],
			{"dim": st == "covered", "owned": st == "owned", "stock": d > 0 and st == "need" and _in_stock(key)})
	t.position = Vector2(cx - s * 0.5, y)
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	t.tooltip_text = "%s (%d altın)%s" % [Items.item_name(key), Items.cost(key), "  - sende var" if st == "owned" else ""]
	host.add_child(t)
	if st != "covered":
		var pl: Control
		var pw: float
		if st == "owned":
			pl = _k.lbl("SENDE", fs, _k.c("good"))
			pw = _k.tw("SENDE", fs)
		else:
			pl = _k.amt(Items.cost(key), fs, _k.c("price"))
			pw = _k.amt_w(Items.cost(key), fs)
		pl.position = Vector2(floorf(cx - pw * 0.5), y + s + 2.0)
		host.add_child(pl)
	if anchor != Vector2.INF:
		var midy: float = floorf((anchor.y + y) * 0.5)
		var col: Color = _k.c("good") if st == "owned" else (_k.c("line") if st == "covered" else _k.c("line_hi"))
		ln.segs.append([PackedVector2Array([anchor, Vector2(anchor.x, midy), Vector2(cx, midy), Vector2(cx, y)]), col, 3.0])
	var kids: Array = n["kids"]
	var kw: float = 0.0
	for k: Dictionary in kids:
		kw += _tree_w(k, s, gx, fs)
	kw += gx * maxi(0, kids.size() - 1)
	var xs: float = x0 + (w - kw) * 0.5
	for k: Dictionary in kids:
		_tree_place(k, xs, d + 1, host, ln, Vector2(cx, y + s + lh - 2.0), s, gx, lh, fs)
		xs += _tree_w(k, s, gx, fs) + gx


# ------------------------------------------------------------------ alt: çanta (sahip olunan eşyalar + SAT)

func _build_bag() -> PanelContainer:
	var p: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), 12.0)
	var row: HBoxContainer = _k.h(22)
	p.add_child(row)
	var cap: VBoxContainer = _k.v(0)
	cap.alignment = BoxContainer.ALIGNMENT_CENTER
	cap.add_child(_k.lbl("ÇANTAN", 32, _k.c("text")))
	cap.add_child(_k.lbl("seç + SAT", 24, _k.c("dim")))
	row.add_child(cap)
	_bag_body = _k.h(22)
	_bag_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_bag_body)
	var sv: VBoxContainer = _k.v(4)
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	var sr: HBoxContainer = _k.h(10)
	sr.add_child(_k.lbl("SAT", 32, _k.c("text")))
	_sell_amt = _k.amt(0, 32, _k.c("good"))
	sr.add_child(_sell_amt)
	_sell_btn = _k.row_btn(sr, "ghost", 56, 180)
	_sell_btn.pressed.connect(_on_sell_pressed)
	sv.add_child(_sell_btn)
	sv.add_child(_k.lbl("tam fiyatın %%%d'i" % int(round(Items.SELL_REFUND_RATIO * 100.0)), 24, _k.c("dim"), HORIZONTAL_ALIGNMENT_CENTER))
	row.add_child(sv)
	return p


func _refresh_bag() -> void:
	if _bag_body == null:
		return
	for c in _bag_body.get_children():
		_bag_body.remove_child(c)
		c.queue_free()
	_bag_tiles.clear()
	if _view_bag >= GameManager.owned_items.size():
		_view_bag = -1
	## [kademe, gösterilen en çok boş yuva dahil yuva sayısı, akış genişliği]
	for grp: Array in [[Items.KADEME_PARCA, 7, 378.0], [Items.KADEME_EPIK, 6, 324.0], [Items.KADEME_EFSANEVI, 5, 270.0]]:
		var kd: int = grp[0]
		var limit: int = Items.slot_limit(kd, _part_slots())
		var mine: Array = []
		for i in GameManager.owned_items.size():
			if Items.kademe(str((GameManager.owned_items[i] as Dictionary).get("key", ""))) == kd:
				mine.append(i)
		var gv: VBoxContainer = _k.v(4)
		gv.add_child(_k.lbl("%s %d/%d" % [DarkKit.TIER_NAME[kd - 1], mine.size(), limit], 24, DarkKit.TIER_COL[kd - 1]))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		flow.custom_minimum_size.x = float(grp[2]) if not _phone else 0.0
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i: int in mine:
			flow.add_child(_bag_cell(i, kd))
		for e in range(mini(limit - mine.size(), maxi(0, int(grp[1]) - mine.size()))):
			flow.add_child(_k.empty_slot(BAG_TILE))
		gv.add_child(flow)
		_bag_body.add_child(gv)
	var can_sell: bool = _view_bag >= 0
	_sell_btn.disabled = not can_sell
	_sell_amt.visible = can_sell
	if can_sell:
		(_sell_amt.get_meta("label") as Label).text = "+%d" % Items.sell_refund(_view_key())
	UISound.connect_all_buttons(_bag_body)
	if _view_bag >= 0 and _bag_tiles.has(_view_bag):
		var bt: Node = _bag_tiles[_view_bag] as Node
		var sel_ring: Node = bt.get_node_or_null("SelRing") if bt != null else null
		if sel_ring != null:
			UiAnim.reveal(sel_ring as Control, 0.0, 0.12)


func _bag_cell(index: int, kd: int) -> Control:
	var key: String = str((GameManager.owned_items[index] as Dictionary).get("key", ""))
	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", _k.sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4, 0.0)) ## pay 0: akış genişliği yuva sayısına tam yetsin
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cell.tooltip_text = "%s\n%s" % [Items.item_name(key), Items.describe(key)]
	cell.focus_mode = Control.FOCUS_ALL
	GamepadFocusHelper.add_focus_ring(cell)
	cell.mouse_entered.connect(UiAnim.pop.bind(cell)) ## madde 200
	cell.gui_input.connect(_on_bag_gui_input.bind(index))
	var t: Control = _k.tile(Items.icon(key), BAG_TILE, DarkKit.TIER_COL[kd - 1], {"sel": index == _view_bag})
	cell.add_child(t)
	_bag_tiles[index] = t
	return cell


func _on_bag_gui_input(event: InputEvent, index: int) -> void:
	var pick: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			or (event.is_action_pressed("ui_accept") and not event.is_echo())
	if not pick:
		return
	_view_bag = -1 if _view_bag == index else index
	_set_cell_ring(_selected_index, _view_bag < 0)
	_refresh_bag()
	_refresh_details()
	UiAnim.reveal(_details_col)


## Çantada seçili eşyayı satar (player.sell_owned_item: stat geri alınır, iade altına eklenir); yuvanın ikonu parçalanıp altına döner.
func _on_sell_pressed() -> void:
	if _view_bag < 0 or _view_bag >= GameManager.owned_items.size():
		return
	var index: int = _view_bag
	var key: String = str((GameManager.owned_items[index] as Dictionary).get("key", ""))
	var from: Vector2 = Vector2.ZERO
	var sz: Vector2 = Vector2.ZERO
	var t: Control = _bag_tiles.get(index) as Control
	if t != null and is_instance_valid(t) and t.is_inside_tree():
		var xf: Transform2D = t.get_global_transform_with_canvas()
		var a: Vector2 = xf * Vector2.ZERO
		var b: Vector2 = xf * t.size
		from = (a + b) * 0.5
		sz = (b - a).abs()
	var refund: int = Items.sell_refund(key)
	if _player and is_instance_valid(_player) and _player.has_method("sell_owned_item"):
		refund = int(_player.sell_owned_item(index))
	else:
		GameManager.owned_items.remove_at(index)
		GameManager.gold += refund
	if sz != Vector2.ZERO and refund > 0:
		GoldRewardFx.show_shatter(get_tree(), refund, from, Items.icon(key), sz)
	_view_bag = -1
	_refresh_all_buy_states()


# ------------------------------------------------------------------ fiyat / satın alma (kurallar eski ekranla aynı)

const MERCHANT_PRICE_TIER_DURATION := 150.0 ## enemy_spawner.gd tier_duration ile AYNI değer (testle eşitliği sınanır - test_tier_pacing)
const MERCHANT_PRICE_EARLY_SCALE := 0.25 ## Kademe 1'de taban fiyatın ~%25'i
const MERCHANT_PRICE_PER_TIER_GROWTH := 0.12 ## Kademe başına +%12
## Karıştırma fiyatının TEK kaynağı (level_up_screen.gd / enchant_screen.gd _reroll_cost da bunu çağırır):
##   taban = REROLL_BASE_COST x satıcı fiyat ölçeği (Kademe/zaman eğrisi, Kademe 1'e oranlanmış: K1 3, K5 ~9, K15 ~23 altın)
##   fiyat = taban x (1 + o ekranda/ziyarette yapılan karıştırma sayısı) -> 3, 6, 9, 12 ...
const REROLL_BASE_COST := 3.0


static func reroll_cost(rerolls_done: int) -> int:
	var tier: int = clampi(1 + int(GameManager.game_time / MERCHANT_PRICE_TIER_DURATION), 1, 15)
	var price_scale: float = (MERCHANT_PRICE_EARLY_SCALE + float(tier - 1) * MERCHANT_PRICE_PER_TIER_GROWTH) / MERCHANT_PRICE_EARLY_SCALE
	var base: int = maxi(1, int(round(REROLL_BASE_COST * price_scale)))
	return base * (1 + maxi(0, rerolls_done))


## Ruhani "Para" pasifi indirimi (GameManager.apply_shop_discount) tek seferde, en sonda.
func _entry_cost(entry: Dictionary) -> int:
	return GameManager.apply_shop_discount(_entry_cost_raw(entry))


## Eşya: tarif fiyatı, sahip olunan parçalar düşülür (Items.plan_purchase). Zaman ölçeklemesi yok (kullanıcı 2026-10-02).
func _entry_cost_raw(entry: Dictionary) -> int:
	var key: String = entry.get("key", "")
	match entry.get("type"):
		"item":
			return int(Items.plan_purchase(key, GameManager.owned_items).get("cost", Items.cost(key)))
	return 0


## Kademe satırları için kademeye, satır içinde fiyata göre (kullanıcı: "ucuzdan pahalıya"). Dizi YERİNDE sıralanır (satıcının stoğu).
func _sort_stock_by_cost() -> void:
	_stock.sort_custom(func(a, b):
		var ka: int = Items.kademe(str(a.get("key", "")))
		var kb: int = Items.kademe(str(b.get("key", "")))
		if ka != kb:
			return ka < kb
		return _entry_cost(a) < _entry_cost(b))


func _entry_sold(entry: Dictionary) -> bool:
	return bool(entry.get("sold", false))


func _entry_can_buy(entry: Dictionary, _index: int) -> bool:
	if _entry_sold(entry):
		return false
	var key: String = entry.get("key", "")
	var cost: int = _entry_cost(entry)
	if GameManager.gold < cost:
		return false
	match entry.get("type"):
		"item":
			return Items.purchase_block_reason(key, GameManager.owned_items, _part_slots()) == ""
	return false


## Parça yuvası sayısı (seviye başına 1) - oyuncu yoksa (test) 1.
func _part_slots() -> int:
	if _player and _player.has_method("get_max_item_slots"):
		return int(_player.get_max_item_slots())
	return 1


func _on_buy_pressed(index: int) -> void:
	if index < 0 or index >= _stock.size():
		return
	var entry: Dictionary = _stock[index]
	if not _entry_can_buy(entry, index):
		return
	var key: String = entry.get("key", "")
	var cost: int = _entry_cost(entry)
	match entry.get("type"):
		"item":
			## Tarifli satın alma: sahip olunan bileşenler tüketilir (player.acquire_item kaydı da yazar).
			var plan: Dictionary = Items.plan_purchase(key, GameManager.owned_items)
			if _player and _player.has_method("acquire_item") and _player.acquire_item(key, plan, cost):
				GameManager.gold -= cost
				entry["sold"] = true
	_refresh_all_buy_states()
	if _entry_sold(entry):
		_flash_card(index)


## Satın alınan kartın kısa parlaması (alındığının görsel onayı).
func _flash_card(index: int) -> void:
	if index < 0 or index >= _card_panels.size() or not is_instance_valid(_card_panels[index]):
		return
	var p: Control = _card_panels[index]
	p.modulate = Color(1.6, 1.45, 0.9)
	var tw: Tween = p.create_tween()
	tw.tween_property(p, "modulate", Color.WHITE, 0.35)


## Kartlar (fiyat / satıldı), çanta, ayrıntı ve altın - satın alma / satış / dışarıdan değişim sonrası.
func _refresh_all_buy_states() -> void:
	for i in _cells.size():
		_refresh_cell(i)
	_refresh_bag()
	_refresh_details()
	_refresh_reroll_button()
	_refresh_header()
	_last_sig = _state_sig()


func _refresh_reroll_button() -> void:
	if not _reroll_btn:
		return
	if not _merchant or not is_instance_valid(_merchant):
		_reroll_btn.visible = false
		return
	var cost: int = int(_merchant.get_reroll_cost())
	var lab: Label = _reroll_amt.get_meta("label")
	if lab.text != str(cost):
		lab.text = str(cost)
	_reroll_btn.disabled = GameManager.gold < cost
	lab.add_theme_color_override("font_color", _k.c("dim") if _reroll_btn.disabled else _k.c("price"))


## Altın ödeyip (reroll_cost) TravelingMerchant'tan taze stok ister; kartları (ve "SATILDI" durumlarını) sıfırdan kurar.
func _on_reroll_pressed() -> void:
	if not _merchant or not is_instance_valid(_merchant):
		return
	var new_stock: Variant = _merchant.try_reroll_stock()
	if new_stock == null:
		return
	_stock = new_stock
	_sort_stock_by_cost()
	_selected_index = -1
	_view_bag = -1
	_populate_stock()
	_refresh_all_buy_states()
	if not _stock.is_empty():
		_select_index(0)


func _on_close_pressed() -> void:
	GameManager.unregister_blocking_panel(self)
	closed.emit()
	queue_free()
