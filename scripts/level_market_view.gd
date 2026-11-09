extends Control

## LEVEL ATLAMA ekranının görünüşü - iki kip (madde 432, kullanıcı 2026-11-06: menü "karmaşık" bulunuyordu -> önce kart, sonra pazar):
##  - "cards": level_up_screen.gd'nin 3 kart Button'ı ekranın ortasında tek sütun (madde 396 "C - Artı / Eksi" yüzleri, fill_card)
##    + kart karıştırma. Karta tıklamak seçer ve ekranı kapatır (DEVAM yok).
##  - "market": level_market_screen.gd'nin içi, seviye kuyruğunun SONUNDA bir kez (madde 472 "B3 - Geniş Önizleme"): solda
##    GELİŞTİRMELER + EŞYALAR satır listesi, sağda geniş önizleme (yazılı KAYDET / YASAKLA, tarif, ELİNDE + SATIN AL), altta
##    KARIŞTIR + yasak hakkı ve DEVAM ET (+ çok oyunculuda sayaç). Satıra TIKLAMAK = seç; alma önizlemedeki düğmeyle.
## Kurallar/fiyatlar level_market.gd'de. Koordinatlar 1920x1080 tuvali (canvas_items germesi); simgeler 48 px sanatın tam katı.
## Yalnız masaüstü (telefon eski ekranında, pazarsız).

signal continue_pressed
## Pazarda altın harcandı / seçenekler değişti (alım, karıştırma, yasak).
signal market_changed

const Market := preload("res://scripts/level_market.gd")
const DarkKit := preload("res://scripts/shop_dark_kit.gd")
const UiAnim := preload("res://scripts/ui_anim.gd")
const ModalSafeArea := preload("res://scripts/modal_safe_area.gd")
const StatIcon := preload("res://scripts/stat_icon.gd")
const ROW_GLOW := preload("res://assets/ui/game/levelup_row_glow.png")
const DIE := preload("res://assets/ui/game/levelup_die.png")

## ---------------------------------------------------------------- kart kipi (madde 396 ölçüleri -> madde 456)
## Madde 456 (kullanıcı 2026-11-08, prototip `tools/proto_20261107/kart_yumusak` "M"): simge ÇERÇEVESİZ (madalyon kutusu yok), kademe
## rengi satırın kenarında (HudTheme.LEVEL_TIER_EDGE), "LEVEL KARTI" başlığı ve "Bir kart seç" yazısı yok, çerçeveler büyük (yazı kenara
## yapışmasın): sütun 380 -> 456, satır 88 -> 108, satır iç payı 12/10 -> 21/15, kartlar arası 8 -> 12.
const LEFT_W := 456.0
const PANEL_PAD := 16
## Kart satırı (prototip C): 48 px simge (288'lik sanatın tam bölümü, keskin) + başlık 32 / kazanç 24 / bedel 24 (bedelsiz kartta bedel
## satırı gizli). Satır kutusu koyu kuyu + kademe renkli kenar, seçilince / üstündeyken açık dolgu + altın kenar.
const CARD_H := 108.0 ## en uzun satırın kendi boyu + pay (test_card_lines_fit_every_card ölçer)
const CARD_PAD_X := 21.0
const CARD_PAD_Y := 15.0
const CARD_GAP := 16.0
const CARD_MEDAL := 48.0 ## simge yuvası (madde 456'ten beri çerçevesiz, simgeyle aynı boy)
const CARD_ICON := 48.0
const CARD_SEP := 12
## Kart yazı sütunu: sütun 456 - 2x16 - satır payı 2x21 - simge 48 - ara 16 = 318 (başlık 32, kazanç/bedel satırı buna sığar).
const CARD_TEXT_W := LEFT_W - 2.0 * PANEL_PAD - 2.0 * CARD_PAD_X - CARD_MEDAL - CARD_GAP
const CARD_EDGE_ALPHA := 0.55 ## kademe kenarı (satırın kendisi; madalyon halkası yerine)
## level_up_screen.gd ROW_GLOW_COLORS / ROW_VALUE_COLOR / ROW_COST_COLOR ile aynı aile
const TIER_RIM := [Color("#dfe4ea"), Color("#9cc4ff"), Color("#dcb0ff"), Color("#ffc65a")]
## Kısık kazanç yeşili / bedel kırmızısı (eski parlak altın değer + kırmızı hap "göz yorucu"ydu).
const GAIN_COL := Color("#a9cf9b")
const COST_COL := Color("#d99386")
const G_UP := ["..#..", ".###.", "#.#.#", "..#..", "..#.."]
const G_DOWN := ["..#..", "..#..", "#.#.#", ".###.", "..#.."]

## ---------------------------------------------------------------- pazar kipi
## Madde 472 (kullanıcı 2026-11-08, prototip `tools/proto_20261108/pazar_yeni` "B3 - Geniş Önizleme"): solda dar LİSTE (GELİŞTİRMELER /
## EŞYALAR satırları: kademe şeridi + simge 48 + ad 32 + fiyat 32), sağda GENİŞ ÖNİZLEME (simge 144 | tür + ad 48 + fiyat 48 | yazılı
## KAYDET / YASAKLA; açıklama kuyusu; TARİF + ŞUNA DÖNÜŞÜR yan yana; ELİNDE + SATIN AL - alınamıyorsa düğme nedeni yazar). Karıştır +
## yasak hakkı pencerenin altında solda, DEVAM sağda (oyuncu panelinin iki yanı). Pencere envanterin çift ahşap çerçevesi (madde 462).
## Madde 518 (kullanıcı 2026-11-09: "pazarı azıcık küçült"): 1420x792 -> 1300x720, liste 520 -> 480, satır 64 -> 58; pencerenin ALT
## kenarı yerinde (852) - karıştır / DEVAM satırı oyuncu panelinin yanında kalır, pencere yukarıdan kısalır.
const MARKET_W := 1300.0
const PANEL_H := 720.0
const MARKET_BOTTOM := 852.0
const MARKET_RECT := Rect2((1920.0 - MARKET_W) * 0.5, MARKET_BOTTOM - PANEL_H, MARKET_W, PANEL_H)
## 56 -> 57 (madde 532): DEVAM ET yol tabelası 19 sanat satırı (sivri uç tek pikselde ortalanır); karıştır da aynı boyda kalsın.
const GO_H := 57.0
const BOTTOM_Y := MARKET_RECT.end.y + 14.0
## DEVAM + KARIŞTIR 400 / 340 -> 300 (madde 518): pencere daralınca oyuncu paneline biniyorlardı. Panel en geniş hâlinde (F yuvası açık,
## 1920 ekranda yaklaşık x 629-1291, üstü y 910) iki düğmenin de ~19 px dışında kalır.
const GO_W := 300.0
const GO_RECT := Rect2(MARKET_RECT.end.x - GO_W, BOTTOM_Y, GO_W, GO_H)
const LIST_W := 480.0
const BODY_GAP := 18.0
const SEC_PAD := 12
## Liste satırı: [kademe şeridi 6 | simge 48 | ad 32 | (kilit) | fiyat 32]; satır iç payı yanlarda 8, üst/altta ROW_PAD_Y (58 = 48 + 2x5).
## (Madde 497: ikonu kademe kenarlı 60 px yuvaya almak denendi, kullanıcı "çerçevesiz daha iyiymiş" dedi, geri alındı.)
const ROW_H := 58.0
const ROW_PAD_Y := 5.0
const ROW_GAP := 5
const ROW_PRICE_W := 130.0
## Silah çizimi bu kareye sığan en büyük tam katla çizilir (kullanıcı 2026-11-06: "silahlar çok büyük görünüyor"); kademe kontürü /
## parıltı pazarda çizilmez.
const WEAPON_FIT := 96.0
## Önizleme: simge 48 px sanatın 3 katı (keskin); yazı alanı = pencere - liste - aralar - önizleme payı.
const DETAIL_ICON := 144.0
const DETAIL_PAD := 18.0
const DETAIL_TEXT_W := MARKET_W - 2.0 * PANEL_PAD - LIST_W - BODY_GAP - 2.0 * DETAIL_PAD - 6.0
const TOOL_W := 230.0 ## yazılı KAYDET / YASAKLA düğmeleri
const TOOL_H := 56.0
## YASAKLA iki basış ister; ilk basıştan sonra bu kadar saniye "TEKRAR BAS" durumunda kalır.
const BAN_ARM_SEC := 3.0
const BUY_W := 400.0
const BUY_H := 64.0
## Eşya önizlemesi (madde 433 ek 5): TARİF (yalnız doğrudan alt eşyalar) + ŞUNA DÖNÜŞÜR; ikisi de varsa yan yana (tarif RECIPE_SIDE_W).
## Ağaç alana sığan en büyük yuva boyuyla çizilir (104 = 48 px sanatın 2 katı; yükseklik yuva + fiyat yazısı + 14 ister).
const RecipeTree := preload("res://scripts/recipe_tree.gd")
const RECIPE_AREA := Vector2(720.0, 144.0) ## en çok DETAIL_TEXT_W (728)
const RECIPE_SIDE_W := 470.0
const RECIPE_SIZES := [104.0, 64.0, 56.0]
const RECIPE_FS := 24
const RECIPE_LEVELS := 1
## ŞUNA DÖNÜŞÜR simgeleri (madde 494, kullanıcı: "çok ufak"): 104 = 48 px sanatın 2 katı (TARİF yuvalarıyla aynı), sığmazsa 56 (1 kat).
## Ara boylar sanatı büyütmez, yalnız boş kenar ekler (icon_tr tam kat çizer). Yükseklik bütçesi: tarifli eşyada TARİF ağacının boyu
## (sıra büyümesin), tarifsizde UPS_AREA_H (104'lük iki sıra).
const UPS_SIZES := [104.0, 56.0]
const UPS_GAP := 6.0
const UPS_AREA_H := 220.0
## Kayıtlı seçeneğin renkleri hud_theme.gd SAVED_* (madde 433 "B - Yosun Kuyu" + kilit simgesi).
const HudTheme := preload("res://scripts/hud_theme.gd")
const Signpost := preload("res://scripts/pixel_signpost.gd")

var mode: String = ""
var _k = null
var _player: Node = null
## Pazar: {"items": [...], "upgrades": [...]} (level_market.gd seçenekleri)
var offers: Dictionary = {"items": [], "upgrades": []}
var shop_rerolls: int = 0
## Ayrıntıda gösterilen seçenek [bölüm, dizin] (fare / odak üstündeki; ayrılınca sonuncusu kalır)
## SEÇİLİ seçenek (tık): ayrıntı bunu gösterir, SATIN AL bunu alır (madde 433 ek 3).
var _focus: Array = ["items", 0]
var _hover: Array = []
var _ban_armed: String = ""
var _ban_armed_at: int = 0
var _chosen: int = -1
## Eşya penceresi (madde 494): açık pencere, onu açan simge, eşya anahtarı; açıklama yüksekliği ölçen gizli etiket
var _pop: Control = null
var _pop_owner: Control = null
var _pop_key: String = ""

var _cards: Array = []
var _cards_box: VBoxContainer = null
var _free_badge_host: HBoxContainer = null
var _item_box: VBoxContainer = null
var _upg_box: VBoxContainer = null
var _slots: Dictionary = {"items": [], "upgrades": []}
var _detail: VBoxContainer = null
var _detail_box: PanelContainer = null ## madde 462: kenarı seçilenin rengi (envanter kartı gibi)
var _shop_reroll: Button = null
var _ban_lbl: Label = null
var _countdown: PanelContainer = null
var _countdown_lbl: Label = null
var go_button: Button = null


func _base(player: Node) -> void:
	_player = player
	_k = DarkKit.new(DarkKit.PAL_NIGHT)
	theme = _k.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Kart kipi. cards: level_up_screen'in 3 kart Button'ı; level_reroll: ekranın kart karıştırma düğmesi (mantığı ekranda kalır).
func setup_cards(player: Node, level: int, cards: Array, level_reroll: Button) -> void:
	mode = "cards"
	_base(player)
	_cards = cards
	## 1920x1080 tuvalinin ortası (pazar penceresiyle aynı koordinatlar); boy içerikten, her boy değişiminde yeniden ortalanır.
	var col: VBoxContainer = _k.v(12)
	col.name = "CardColumn"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.resized.connect(func() -> void: col.position = ((Vector2(1920.0, 1080.0) - col.size) * 0.5).round())
	var head: HBoxContainer = _k.h(20)
	var t: Label = _k.lbl(tr("SEVİYE %d") % level, 56, _k.c("accent"))
	t.name = "MarketTitle"
	head.add_child(t) ## madde 456: "Bir kart seç" yazısı yok (kullanıcı 2026-11-08)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(head)
	var lb: PanelContainer = _build_left(level_reroll)
	lb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER ## başlık daha genişse sütun yine 380
	col.add_child(lb)
	var ch: HBoxContainer = _k.h(0)
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_child(_build_countdown())
	col.add_child(ch)
	UISound.connect_all_buttons(self)
	_fit_safe_area()


## Pazar kipi. given: hazır seçenekler (boşsa level_market.gd open_offers - kayıtlılar + yeni çekiliş).
func setup_market(player: Node, _level: int, given: Dictionary = {}) -> void:
	mode = "market"
	_base(player)
	## Başlık satırı ve pencereye yapışık bakiye sekmesi yok: bakiye önizlemenin altında ("ELİNDE", madde 472).
	_build_market()
	go_button = _go_signpost()
	go_button.name = "MarketContinue"
	go_button.pressed.connect(func() -> void: continue_pressed.emit())
	_place(self, go_button, GO_RECT.position, GO_RECT.size)
	var ch: HBoxContainer = _k.h(0)
	ch.custom_minimum_size = Vector2(0, GO_H)
	ch.add_child(_build_countdown())
	_place(self, ch, Vector2(GO_RECT.end.x + 16.0, GO_RECT.position.y))
	offers = given if not given.is_empty() else Market.open_offers(_player)
	_rebuild_slots()
	UISound.connect_all_buttons(self)
	_fit_safe_area()


## SATIN AL ile DEVAM ET aynı altın düğmeydi, oyuncular karıştırıyordu (madde 532, kullanıcı seçimi prototip madde 530 "B - Ok Tabela"):
## DEVAM ET = sağı sivri AHŞAP YOL TABELASI (pixel_signpost.gd; kenar rengi zemin, krem yazı), SATIN AL altın kalır + heybe / çekiç glifi.
## Tabela yazısı Label'da: kitin Label gölgesi (Button yazısı gölgesiz), ucun genişliği kadar soldan ortalanır (kutunun içerik payı).
func _go_signpost() -> Button:
	var w: int = int(GO_W) / Signpost.PX
	var h: int = int(GO_H) / Signpost.PX
	var b := Button.new()
	b.custom_minimum_size = GO_RECT.size
	b.add_theme_stylebox_override("normal", Signpost.box(w, h, HudTheme.RIM, HudTheme.OUTLINE))
	b.add_theme_stylebox_override("hover", Signpost.box(w, h, HudTheme.RIM_HI, HudTheme.OUTLINE))
	for st: String in ["pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, Signpost.box(w, h, HudTheme.RIM_LO, HudTheme.OUTLINE))
	b.add_theme_stylebox_override("disabled", Signpost.box(w, h, HudTheme.STRIPE, HudTheme.OUTLINE))
	b.add_theme_stylebox_override("focus", Signpost.box(w, h, HudTheme.RIM, HudTheme.ACCENT, true))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.offset_right = -float(Signpost.tip_px(h))
	cc.offset_bottom = -float(Signpost.PX)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l: Label = _k.lbl("DEVAM ET", 40, HudTheme.TEXT)
	l.name = "Text"
	cc.add_child(l)
	b.add_child(cc)
	return b


## Alınabilir seçenekte SATIN AL / GELİŞTİR: altın düğme + heybe (eşya) / çekiç (geliştirme) glifi. Alınamıyorsa düğme nedeni yazar (eski).
func _buy_button(upgrade: bool) -> Button:
	var r: HBoxContainer = _k.h(16)
	r.add_child(_k.glyph(DarkKit.G_HAMMER if upgrade else DarkKit.G_BAG, _k.c("accent_text"), 3))
	var l: Label = _k.lbl("GELİŞTİR" if upgrade else "SATIN AL", 32, _k.c("accent_text"))
	l.name = "Verb"
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0)) ## altın zeminde gölge yazıyı kalın gösterir
	r.add_child(l)
	return _k.row_btn(r, "primary", BUY_H, BUY_W)


## Grup paneli (HUD, katman 96, çok oyunculuda sağ şerit) bu ekranlar açıkken görünmez: düzen o şeridin soluna ortalanınca sola
## kayık duruyordu (kullanıcı 2026-10-28). Bekleyen oyuncular wait_overlay.gd'de görünmeye devam eder.
func _enter_tree() -> void:
	get_tree().call_group(&"party_panel", &"set_suppressed", "level_market", true)
	## Görev satırları (main.gd WorldEventBannerLayer, katman 40) pazarın sağ üstüne biniyordu (kullanıcı ekran görüntüsü 2026-11-07).
	get_tree().call_group(&"world_event_banner_layer", &"hide")


func _exit_tree() -> void:
	get_tree().call_group(&"party_panel", &"set_suppressed", "level_market", false)
	get_tree().call_group(&"world_event_banner_layer", &"show")


## Düzen ekranın tam ortasında 1:1; başka bir şey sağ şeridi ayırırsa (ModalSafeArea) o alana ortalanıp gerekirse küçülür.
func _fit_safe_area() -> void:
	if not is_inside_tree():
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var safe: Rect2 = ModalSafeArea.rect(get_tree(), view)
	var need: float = (MARKET_W if mode == "market" else LEFT_W) + 48.0
	var s: float = minf(1.0, minf(safe.size.x / need, view.y / 1080.0))
	scale = Vector2(s, s)
	position = Vector2(roundf(safe.position.x + safe.size.x * 0.5 - 960.0 * s), roundf((view.y - 1080.0 * s) * 0.5))


## ---------------------------------------------------------------- iskelet
func _place(parent: Control, n: Control, pos: Vector2, sz: Vector2 = Vector2.ZERO) -> void:
	parent.add_child(n)
	n.position = pos
	if sz != Vector2.ZERO:
		n.custom_minimum_size = sz
		n.size = sz


## Sağ alt köşesi (right_x, bottom_y)'de sabit, en küçük boyu sola ve yukarı büyür (ağaç dışında ölçülen boy yanlış çıkabiliyor).
func _place_corner(n: Control, right_x: float, bottom_y: float) -> void:
	add_child(n)
	n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	n.grow_vertical = Control.GROW_DIRECTION_BEGIN
	n.offset_left = right_x
	n.offset_right = right_x
	n.offset_top = bottom_y
	n.offset_bottom = bottom_y


## Çok oyunculu sayaç (görününce yerleşim kaymaz: kart kipinde sütunun altında, pazarda DEVAM'ın sağında).
func _build_countdown() -> PanelContainer:
	_countdown = _k.box(_k.c("inset"), _k.c("line_hi"), 8, 3, 6)
	_countdown.name = "Countdown"
	_countdown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var cr: HBoxContainer = _k.h(10)
	cr.add_child(_k.lbl("KALAN", 24, _k.c("dim")))
	_countdown_lbl = _k.lbl("", 32, _k.c("accent"))
	cr.add_child(_countdown_lbl)
	_countdown.add_child(cr)
	_countdown.modulate.a = 0.0 ## yer kaplasın (kart sütunu zıplamasın), görünmesin
	return _countdown


func set_countdown(sec: float) -> void:
	if _countdown == null:
		return
	_countdown.modulate.a = 1.0
	_countdown_lbl.text = tr("%d sn") % int(ceil(maxf(sec, 0.0)))


func _sec_head(pat: Array, title: String, note: String = "") -> HBoxContainer:
	var r: HBoxContainer = _k.h(12)
	r.add_child(_k.glyph(pat, _k.c("accent"), 3)) ## madde 462: envanterin HEYBE başlığı gibi 3 kat simge
	r.add_child(_k.lbl(title, 32, _k.c("accent")))
	if note != "":
		r.add_child(_k.lbl(note, 24, _k.c("dim")))
	return r


## ---------------------------------------------------------------- level kartları (kart kipi)
## Sütunun boyu içeriği kadar; rozet kutusuz ("1 ÜCRETSİZ" / "KULLANILDI").
func _build_left(level_reroll: Button) -> PanelContainer:
	var lb: PanelContainer = _k.box(_k.c("panel"), _k.c("line_hi"), PANEL_PAD, 3, 8)
	lb.name = "LevelCards"
	lb.custom_minimum_size = Vector2(LEFT_W, 0.0)
	var lv: VBoxContainer = _k.v(CARD_SEP)
	lb.add_child(lv)
	## (madde 432: "1 ÜCRETSİZ" rozeti kalktı - pazar ayrı ekranda, kart zaten hep ücretsiz; _free_badge_host boş kalır)
	## (madde 456: "★ LEVEL KARTI" başlık satırı kalktı - kullanıcı 2026-11-08 "level kartında level kartı yazmasın")
	_cards_box = _k.v(CARD_SEP)
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
		card.set_meta("glow_card_size", Vector2(LEFT_W - 2.0 * PANEL_PAD, CARD_H))
		card.set_meta("glow_colors", TIER_RIM)
		UiAnim.skip(card) ## kartın kendi giriş/üstüne gelme/seçim animasyonu var
	lv.add_child(_k.sp(0, 4))
	if level_reroll:
		level_reroll.reparent(lv, false)
		level_reroll.set_anchors_preset(Control.PRESET_TOP_LEFT)
		level_reroll.custom_minimum_size = Vector2(0, 48)
		level_reroll.size_flags_horizontal = Control.SIZE_FILL
		_k.btn_style(level_reroll, "ghost")
		level_reroll.icon = DIE
		level_reroll.add_theme_font_size_override("font_size", 24)
		level_reroll.remove_theme_constant_override("outline_size")
	_refresh_free_badge()
	return lb


## data: {title, tier, value, cost, cost_red, label, icon} - kademe adı / tür / açıklama satırı YOK (kullanıcı 2026-10-28: "epik ve
## açıklaması vb görünmesin"); kademe yalnız madalyon halkasının renginde. Prototip C "Artı / Eksi" (madde 396): başlık 32, altında
## "▲ kazanç" yeşil + "▼ bedel" kırmızı (24, aynı hizada) - büyük sayı / hap yok. Takas kartında kazancın yanında neyin arttığı
## (label, ör. "+70 Azami Can") yazar, çünkü başlık kartın adıdır (ör. "Demir Kabuk").
func fill_card(card: Button, data: Dictionary) -> void:
	var old: Node = card.get_node_or_null("MarketFace")
	if old:
		card.remove_child(old)
		old.queue_free()
	var tier: int = clampi(int(data.get("tier", 1)), 1, 4)
	var face := PanelContainer.new()
	face.name = "MarketFace"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(face)
	var r: HBoxContainer = _k.h(int(CARD_GAP))
	face.add_child(r)
	var med := PanelContainer.new()
	med.name = "Medal"
	med.mouse_filter = Control.MOUSE_FILTER_IGNORE
	med.custom_minimum_size = Vector2(CARD_MEDAL, CARD_MEDAL)
	med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var mc := CenterContainer.new()
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(_card_icon(_stat_tex(str(data.get("icon", "")))))
	med.add_child(mc)
	r.add_child(med)
	var v: VBoxContainer = _k.v(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: Label = _k.clip(str(data.get("title", "")), 32, _k.c("text"), CARD_TEXT_W)
	title.name = "Title"
	v.add_child(title)
	var gain_txt: String = str(data.get("value", ""))
	if str(data.get("label", "")) != "":
		gain_txt += " " + str(data["label"])
	var gain: HBoxContainer = _sign_line(G_UP, GAIN_COL, gain_txt)
	gain.name = "Gain"
	v.add_child(gain)
	var cost: HBoxContainer
	if bool(data.get("cost_red", true)):
		cost = _sign_line(G_DOWN, COST_COL, str(data.get("cost", "")))
	else:
		cost = _k.h(6)
		cost.add_child(_k.lbl(str(data.get("cost", "")), 24, _k.c("dim")))
	cost.name = "Cost"
	## Madde 398'den beri düz kartlar bedelsiz: ikinci satırda tek başına sönük "artar" kalıyordu -> bedelsiz kartta gizli (madde 456).
	cost.visible = bool(data.get("cost_red", true))
	v.add_child(cost)
	r.add_child(v)
	card.set_meta("mk_tier", tier)
	_style_card(card, _cards.find(card) == _chosen and _chosen >= 0)
	card.modulate = Color(1, 1, 1, card.modulate.a)


## ▲ / ▼ + 24 px yazı (ok 2 px piksel, yazıyla dikeyde ortalı).
func _sign_line(pat: Array, col: Color, t: String) -> HBoxContainer:
	var r: HBoxContainer = _k.h(6)
	var g: Control = _k.glyph(pat, col, 2)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(g)
	r.add_child(_k.lbl(t, 24, col))
	return r


## Level simgeleri 288 px (48'in 6 katı): 48'de NEAREST tam örnekler (keskin), başka boydaki sanat doğrusal.
func _card_icon(t: Texture2D) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(CARD_ICON, CARD_ICON)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if t:
		var ts: Vector2 = t.get_size()
		var exact: bool = int(ts.x) % int(CARD_ICON) == 0 and int(ts.y) % int(CARD_ICON) == 0
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if exact else CanvasItem.TEXTURE_FILTER_LINEAR
	return tr


## Satır kutusu + madalyon halkası: seçili = açık dolgu + altın kenar / altın halka, değilse koyu kuyu + kademe renkli halka.
func _style_card(card: Button, on: bool) -> void:
	var face: PanelContainer = card.get_node_or_null("MarketFace") as PanelContainer
	if face == null:
		return
	var tier: int = int(card.get_meta("mk_tier", 1))
	## Madde 456: kademe rengi satırın kenarında (madalyon halkası yerine; simge çerçevesiz - kullanıcı 2026-11-08 "simgelerin dışında
	## çerçeve olmasın"); üstünde / seçili = açık dolgu + altın kenar.
	var edge: Color = _k.c("accent") if on else Color(HudTheme.LEVEL_TIER_EDGE[tier - 1], CARD_EDGE_ALPHA)
	var fs = _k.sb(_k.c("panel3") if on else Color(_k.c("inset"), 0.6), edge, 3, 8)
	fs.content_margin_left = CARD_PAD_X
	fs.content_margin_right = CARD_PAD_X
	fs.content_margin_top = CARD_PAD_Y
	fs.content_margin_bottom = CARD_PAD_Y
	face.add_theme_stylebox_override("panel", fs)
	var med: PanelContainer = face.find_child("Medal", true, false) as PanelContainer
	if med:
		med.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


## Fare kartın üstündeyken (level_up_screen.gd _on_card_hover): hale yerine seçili kartın görünüşü (altın kenar); seçimden sonra dokunmaz.
func hover_card(card: Button, on: bool) -> void:
	if _chosen >= 0 or not is_instance_valid(card):
		return
	_style_card(card, on)


func _stat_tex(id: String) -> Texture2D:
	var f: String = str(StatIcon.ICON_PATHS.get(id, ""))
	return load(StatIcon.ICON_DIR + f) as Texture2D if f != "" else null


## Seçilen kart: açık dolgu + altın kenar; diğerleri söner. -1 = henüz seçim yok.
func set_chosen(index: int) -> void:
	_chosen = index
	for i in _cards.size():
		var card: Button = _cards[i]
		if not is_instance_valid(card):
			continue
		var on: bool = i == index
		_style_card(card, on)
		if index >= 0 and not on:
			var tw := card.create_tween()
			tw.tween_property(card, "modulate", Color(1, 1, 1, 0.42), 0.25)
	_refresh_free_badge()


func _refresh_free_badge() -> void:
	if _free_badge_host == null:
		return
	for c in _free_badge_host.get_children():
		c.queue_free()
	var used: bool = _chosen >= 0
	var col: Color = _k.c("dim") if used else _k.c("good")
	var r: HBoxContainer = _k.h(6)
	var g: Control = _k.glyph(DarkKit.G_CHECK if used else DarkKit.G_STAR, col, 2)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(g)
	r.add_child(_k.lbl("KULLANILDI" if used else "1 ÜCRETSİZ", 24, col))
	_free_badge_host.add_child(r)


## ---------------------------------------------------------------- pazar iskeleti
## Pencere envanterin (inventory_panel.gd _build_chest) ÇİFT AHŞAP ÇERÇEVESİ (madde 462): dış `RIM` dolgu + `OUTLINE` 4 px kenar, iç
## `panel` + `RIM_LO` 3 px kenar; içerik kenardan PANEL_PAD (8 + 8). Madde 472 (B3): solda tek opak liste kuyusu (GELİŞTİRMELER üstte,
## EŞYALAR altta), sağda önizleme. Önizlemenin kenarı NÖTR ahşap (kullanıcı 2026-11-08: "dışı neden mor gözüküyor" - eskiden seçilenin
## nadirlik rengiydi); kademe rengi simge kuyusunun kenarında ve satırın şeridinde.
const FRAME_RIM_PAD := 8.0
const FRAME_WIN_PAD := PANEL_PAD - FRAME_RIM_PAD
## Önizlemedeki durum satırları + AÇIKLAMA (eskiden 24, "çok ufak"). Açıklama başlığın altında, üstten hizalı (madde 494; ortalanmış
## deneme beğenilmedi). Madde 494'te sığdıkça 48'e çıkıyordu; madde 518'de (kullanıcı 2026-11-09: "item açıklamasındaki yazılar çok
## büyük") hep 32 - m5x7'de 16/32/48 dışı boy yok (stil rehberi), 48 -> 32 tek basamak.
const DESC_FS := 32
const DESC_PAD := 18.0 ## açıklama kuyusunun iç payı
const DESC_GAP := 4 ## açıklama satırları arası

## ŞUNA DÖNÜŞÜR simgesine tıklayınca açılan eşya penceresi (madde 494): envanterin çift ahşap çerçevesi + yetenek ipucu gibi simgeye
## basamaklı uçla bağlı; üstte yer yoksa altta açılır. Dışına tık / Esc / aynı simgeye tekrar tık kapatır.
const POP_W := 640.0
const POP_ICON := 96.0
const POP_WIN_PAD := 14.0 ## iç panelin iç payı
const POP_RECIPE_H := 130.0 ## tarif sırasına ayrılan yükseklik (yuva 64 + fiyat + pay = 102)
const POP_FS := 32
const POP_NAME_FS := 48
const POP_GAP := 6.0 ## pencere kenarı ile simge arası: simgenin üstündeki "ŞUNA DÖNÜŞÜR" başlığı tam örtülür (yarım kesilmesin), uç simgeye değer
const POP_SCREEN_PAD := 8.0
const POP_RECIPE_SIZES := [64.0, 56.0]
const NOTCH_PX := 3.0
const NOTCH_ROWS := 4


func _build_market() -> void:
	var rb: PanelContainer = _k.box(HudTheme.RIM, HudTheme.OUTLINE, FRAME_RIM_PAD, 4, 6)
	rb.name = "Market"
	_place(self, rb, MARKET_RECT.position, MARKET_RECT.size)
	var win: PanelContainer = _k.box(_k.c("panel"), HudTheme.RIM_LO, FRAME_WIN_PAD, 3, 4)
	win.name = "MarketWindow"
	rb.add_child(win)
	var body: HBoxContainer = _k.h(int(BODY_GAP))
	body.name = "MarketBody"
	win.add_child(body)
	## liste: GELİŞTİRMELER + EŞYALAR satırları tek kuyuda
	var lb: PanelContainer = _k.box(_k.c("inset"), _k.c("line"), SEC_PAD, 3, 6)
	lb.name = "MarketList"
	lb.custom_minimum_size.x = LIST_W
	body.add_child(lb)
	var lv: VBoxContainer = _k.v(ROW_GAP)
	lb.add_child(lv)
	var uh: HBoxContainer = _sec_head(DarkKit.G_HAMMER, "GELİŞTİRMELER")
	uh.name = "UpgradesHead"
	lv.add_child(uh)
	_upg_box = _k.v(ROW_GAP)
	_upg_box.name = "UpgradeRows"
	lv.add_child(_upg_box)
	lv.add_child(_k.sp(0, 8))
	var ih: HBoxContainer = _sec_head(DarkKit.G_BAG, "EŞYALAR")
	ih.name = "ItemsHead"
	lv.add_child(ih)
	_item_box = _k.v(ROW_GAP)
	_item_box.name = "ItemRows"
	lv.add_child(_item_box)
	## önizleme
	var dbox: PanelContainer = _k.box(_k.c("panel2"), _k.c("line_hi"), DETAIL_PAD, 3, 6)
	dbox.name = "Detail"
	dbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(dbox)
	_detail_box = dbox
	_detail = _k.v(14)
	dbox.add_child(_detail)
	## pencerenin altında solda: tek karıştırma + yasak hakkı (DEVAM sağda, setup_market)
	var bottom: HBoxContainer = _k.h(20)
	bottom.name = "MarketBottom"
	_shop_reroll = _k.row_btn(_die_row(0), "ghost", GO_H, GO_W)
	_shop_reroll.name = "MarketReroll"
	_shop_reroll.tooltip_text = "Kaydettiklerin yerinde kalır, gerisi yenilenir"
	_shop_reroll.pressed.connect(reroll)
	bottom.add_child(_shop_reroll)
	var br: HBoxContainer = _k.h(8)
	br.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg: Control = _k.glyph(DarkKit.G_X, _k.c("bad"), 3)
	bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	br.add_child(bg)
	_ban_lbl = _k.lbl("", 24, _k.c("text"))
	_ban_lbl.name = "BanCount"
	br.add_child(_ban_lbl)
	bottom.add_child(br)
	_place(self, bottom, Vector2(MARKET_RECT.position.x, BOTTOM_Y))


func _die_row(cost: int) -> HBoxContainer:
	var r: HBoxContainer = _k.h(10)
	r.add_child(_k.icon(DIE, 33))
	r.add_child(_k.lbl("KARIŞTIR", 32, _k.c("text")))
	var a: HBoxContainer = _k.amt(cost, 24, _k.c("price"))
	a.name = "Cost"
	r.add_child(a)
	return r


## "→" m5x7'de YOK (yedek fontla ince/bulanık çizilir ve satırı uzatır -> Label'ın tek tip satır boyuyla hesaplanan yüksekliğine sığmayıp
## kesilir, madde 465 ek); fontta olan "»" ile yazılır.
static func _txt(t: String) -> String:
	return t.replace("→", "»")


static func _is_upgrade(e: Dictionary) -> bool:
	return ["wupgrade", "wplus", "upgrade"].has(str(e.get("type", "")))


## Satırın / önizlemenin başlığı: eşyada adı; silah geliştirmesinde geliştirmenin ADI (silah adı tür satırında), güçlendirmede
## "Güçlendirme +N"; kalkan geliştirmesinde satırda etkisi, önizlemede kalkanın adı (etkisi açıklamada).
func _title(e: Dictionary, d: Dictionary, detail: bool = false) -> String:
	match str(e.get("type", "")):
		"wupgrade":
			return str(d.get("row_sub", d["name"]))
		"wplus":
			return str(d["sub"])
		"upgrade":
			return str(d["name"]) if detail else _txt(str(d.get("row_sub", d["name"])))
	return str(d["name"])


## ---------------------------------------------------------------- pazar satırları
func _rebuild_slots() -> void:
	for section: String in Market.SECTIONS:
		_rebuild_section(section)
	refresh()


func _rebuild_section(section: String) -> void:
	var host: Container = _item_box if section == "items" else _upg_box
	for c in host.get_children():
		host.remove_child(c)
		c.queue_free()
	var list: Array = []
	var arr: Array = offers.get(section, [])
	for i in int(Market.SECTION_SIZE[section]):
		if i < arr.size():
			var b: Button = _slot_button(section, i)
			host.add_child(b)
			list.append(b)
		else:
			var e: Panel = _k.empty_slot(ROW_H)
			e.custom_minimum_size = Vector2(0, ROW_H)
			host.add_child(e)
	_slots[section] = list
	UISound.connect_all_buttons(host)
	UiAnim.cascade(host)


## Liste satırı: tık = SEÇ (önizleme onu gösterir; alma önizlemedeki SATIN AL ile). Kaydet / yasakla önizlemede yazılı düğmeler.
func _slot_button(section: String, i: int) -> Button:
	var b := Button.new()
	b.name = "%s%d" % ["Slot" if section == "items" else "Upgrade", i]
	b.flat = true
	b.custom_minimum_size = Vector2(0, ROW_H)
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UiAnim.skip(b)
	b.pressed.connect(_on_slot_pressed.bind(section, i))
	b.mouse_entered.connect(_set_hover.bind(section, i, true))
	b.mouse_exited.connect(_on_slot_mouse_exited.bind(section, i))
	b.focus_entered.connect(_set_hover.bind(section, i, true))
	b.focus_exited.connect(_set_hover.bind(section, i, false))
	return b


func _on_slot_mouse_exited(section: String, i: int) -> void:
	_check_hover_left.call_deferred(section, i)


func _check_hover_left(section: String, i: int) -> void:
	if _hover != [section, i]:
		return
	var b: Control = _slot_node(section, i)
	var vp: Viewport = get_viewport()
	if b != null and vp != null:
		var h: Control = vp.gui_get_hovered_control()
		if h != null and (h == b or b.is_ancestor_of(h)):
			return
	_set_hover(section, i, false)


## Üstüne gelmek yalnız satırı vurgular; önizleme SEÇİLİ olanı gösterir (madde 433 ek 3: fareyi SATIN AL'a götürürken aradaki satırlar
## önizlemeyi değiştirmesin).
func _set_hover(section: String, i: int, on: bool) -> void:
	var prev: Array = _hover
	if on:
		_hover = [section, i]
	elif _hover == [section, i]:
		_hover = []
	## Hover bir satırdan ötekine geçince eski satır yeniden çizilmezse vurgulu kalır (mouse_exited kontrolü _hover değiştiği için erken döner).
	if prev.size() == 2 and prev != _hover and prev != [section, i]:
		_fill(str(prev[0]), int(prev[1]))
	_fill(section, i)


func _key(section: String, i: int) -> String:
	return "%s:%d" % [section, i]


func _offer(section: String, i: int) -> Dictionary:
	var arr: Array = offers.get(section, [])
	return arr[i] if i >= 0 and i < arr.size() else {}


## Tık = SEÇ (kullanıcı 2026-11-06: "tıklayınca hemen almasın, sağdaki önizlemeden alma tuşuyla alınsın").
func _on_slot_pressed(section: String, i: int) -> void:
	_select(section, i)


func _select(section: String, i: int) -> void:
	var old: Array = _focus
	_focus = [section, i]
	if old.size() == 2 and old != _focus:
		_fill(str(old[0]), int(old[1]))
	_fill(section, i)
	_refresh_detail()


func _on_buy_pressed() -> void:
	if _focus.size() != 2:
		return
	var section: String = str(_focus[0])
	var i: int = int(_focus[1])
	if not buy(section, i):
		var s: Control = _slot_node(section, i)
		if s:
			s.modulate = Color(1.5, 0.75, 0.7)
			s.create_tween().tween_property(s, "modulate", Color.WHITE, 0.3)
		_refresh_detail()


func _slot_node(section: String, i: int) -> Control:
	var list: Array = _slots.get(section, [])
	return list[i] if i < list.size() and is_instance_valid(list[i]) else null


## Satın alır (level_market.gd: demirci/satıcı yolları); başarılıysa satır "ALINDI" olur, diğerlerinin engelleri yenilenir.
func buy(section: String, i: int) -> bool:
	var e: Dictionary = _offer(section, i)
	if e.is_empty() or not Market.buy(_player, e):
		return false
	refresh.call_deferred()
	market_changed.emit()
	var s: Control = _slot_node(section, i)
	if s:
		s.modulate = Color(1.6, 1.45, 0.9)
		s.create_tween().tween_property(s, "modulate", Color.WHITE, 0.35)
	return true


## KAYDET aç/kapa: kayıtlı seçenek karıştırmada yerinde kalır, sonraki pazarda yeniden gelir (alınınca düşer).
func toggle_save(section: String, i: int) -> void:
	var e: Dictionary = _offer(section, i)
	if e.is_empty() or bool(e.get("sold", false)):
		return
	Market.set_saved(e, not Market.is_saved(e))
	_select(section, i)


## YASAKLA: ilk basış kurar ("TEKRAR BAS", BAN_ARM_SEC), ikinci basış yasaklar - satıra ücretsiz yeni seçenek gelir.
func press_ban(section: String, i: int) -> void:
	var e: Dictionary = _offer(section, i)
	if e.is_empty() or bool(e.get("sold", false)) or Market.bans_left() <= 0:
		return
	var k: String = _key(section, i)
	if _ban_armed != k or Time.get_ticks_msec() - _ban_armed_at > int(BAN_ARM_SEC * 1000.0):
		_ban_armed = k
		_ban_armed_at = Time.get_ticks_msec()
		## yöntem bağlaması (lambda değil): ekran önce kapanırsa bağlantı kendiliğinden düşer ("Lambda capture ... freed" olmasın)
		get_tree().create_timer(BAN_ARM_SEC, true).timeout.connect(_disarm_ban.bind(k, section, i))
		_select(section, i)
		return
	_ban_armed = ""
	if not Market.ban(e):
		return
	offers[section] = Market.replace_at(_player, offers, section, i)
	_rebuild_section(section)
	refresh()
	market_changed.emit()


func _disarm_ban(k: String, section: String, i: int) -> void:
	if _ban_armed == k and Time.get_ticks_msec() - _ban_armed_at >= int(BAN_ARM_SEC * 1000.0) - 50:
		_ban_armed = ""
		_fill(section, i)
		_refresh_detail()


## Tek KARIŞTIR iki bölümü birden yeniler (kaydedilenler yerinde kalır); bedel satıcının formülü, sayaç bu pazara ait.
func reroll() -> void:
	var cost: int = Market.reroll_cost(shop_rerolls)
	if GameManager.gold < cost:
		return
	GameManager.gold -= cost
	shop_rerolls += 1
	offers = Market.reroll(_player, offers)
	_hover = []
	_ban_armed = ""
	_rebuild_slots()
	market_changed.emit()


## Satırlar (fiyat/engel/ALINDI/kayıt), önizleme (bakiye dahil), karıştırma ve yasak hakkı - her alım/karıştırma/yasak sonrası.
func refresh() -> void:
	if mode != "market":
		return
	for section: String in Market.SECTIONS:
		for i in (_slots[section] as Array).size():
			_fill(section, i)
	var cost: int = Market.reroll_cost(shop_rerolls)
	var amt: Node = _shop_reroll.get_meta("row").get_node("Cost")
	var lab: Label = amt.get_meta("label")
	lab.text = str(cost)
	_shop_reroll.disabled = GameManager.gold < cost
	lab.add_theme_color_override("font_color", _k.c("dim") if _shop_reroll.disabled else _k.c("price"))
	_ban_lbl.text = tr("YASAK HAKKI %d/%d") % [Market.bans_left(), Market.BAN_LIMIT]
	_ban_lbl.add_theme_color_override("font_color", _k.c("dim") if Market.bans_left() <= 0 else _k.c("text"))
	_refresh_detail()


## Satır yüzü: zebra / üstünde (açık dolgu + kademe kenarı) / SEÇİLİ (altın kenar) / kayıtlı (madde 433 "B - Yosun Kuyu": yosun iç +
## yeşil kenar + adın sağında kilit) / yasak kurulu (kırmızı kenar). Solda kademe rengi şerit; alınmışsa fiyat yerine "ALINDI".
func _fill(section: String, i: int) -> void:
	var b: Control = _slot_node(section, i)
	if b == null:
		return
	var old: Node = b.get_node_or_null("Face")
	if old:
		b.remove_child(old)
		old.queue_free()
	var e: Dictionary = _offer(section, i)
	if e.is_empty():
		return
	var d: Dictionary = Market.describe(e, _player)
	var col: Color = d["tag_col"]
	var sold: bool = bool(e.get("sold", false))
	var saved: bool = Market.is_saved(e)
	var hov: bool = _hover == [section, i]
	var sel: bool = _focus == [section, i]
	var fill: Color = Color(_k.c("panel3"), 0.35) if i % 2 == 0 else Color(0, 0, 0, 0)
	var rim: Color = Color(0, 0, 0, 0)
	if hov:
		fill = _k.c("panel2")
		rim = Color(col, 0.75)
	if sel:
		fill = _k.c("panel3")
		rim = _k.c("accent")
	if saved:
		rim = HudTheme.SAVED_EDGE if hov or sel else Color(HudTheme.SAVED_EDGE, 0.9)
		fill = HudTheme.SAVED_FILL_HOVER if hov or sel else HudTheme.SAVED_FILL
	if _ban_armed == _key(section, i):
		rim = _k.c("bad")
	var face: PanelContainer = _k.box(fill, rim, 8, 3, 6)
	var fsb: StyleBox = face.get_theme_stylebox("panel") ## _k.sb her çağrıda yeni kutu: payı değiştirmek başka satırı etkilemez
	fsb.content_margin_top = ROW_PAD_Y
	fsb.content_margin_bottom = ROW_PAD_Y
	face.name = "Face"
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(face)
	b.move_child(face, 0)
	var r: HBoxContainer = _k.h(14)
	face.add_child(r)
	var stripe := ColorRect.new()
	stripe.name = "TierStripe"
	stripe.color = Color(col, 0.35 if sold else 0.85)
	stripe.custom_minimum_size = Vector2(6, 0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(stripe)
	var ic: CenterContainer = _k.center(_icon(d, 48.0, sold))
	ic.custom_minimum_size.x = 52
	r.add_child(ic)
	var title: Label = _k.lbl(_title(e, d), 32, _k.c("dim") if sold else _k.c("text"))
	title.name = "Title"
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(title)
	if saved:
		var g: Control = _k.glyph(DarkKit.G_LOCK, HudTheme.SAVED, 3)
		g.name = "SavedLock"
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(g)
	if sold:
		var st: HBoxContainer = _k.h(8)
		st.name = "Sold"
		st.alignment = BoxContainer.ALIGNMENT_END
		st.custom_minimum_size.x = ROW_PRICE_W
		var cg: Control = _k.glyph(DarkKit.G_CHECK, _k.c("good"), 3)
		cg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		st.add_child(cg)
		st.add_child(_k.lbl("ALINDI", 32, _k.c("good")))
		r.add_child(st)
	else:
		var pr: HBoxContainer = _price_row(e, 32, false)
		pr.name = "Price"
		pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pr.custom_minimum_size.x = ROW_PRICE_W
		pr.alignment = BoxContainer.ALIGNMENT_END
		r.add_child(pr)


func _icon(d: Dictionary, s: float, dim: bool = false) -> Control:
	if int(d["wtier"]) > 0:
		return _weapon_icon(d["tex"], s, dim)
	return _k.icon(d["tex"], s, dim)


## Silah sanatı 48 px tuvalin ortasına ince/çapraz çizili: boş kenar kırpılır (AtlasTexture) ve WEAPON_FIT karesine sığan en
## büyük TAM katla çizilir (2026-10-28 "çok ufak" -> kutuyu dolduruyordu; 2026-11-06 "çok büyük" -> eşyalarla aynı boy). Kademe
## kontürü / parıltısı YOK (kullanıcı 2026-11-06); kademe önizlemede yazıyla.
func _weapon_icon(t: Texture2D, box: float, dim: bool) -> Control:
	var host := Control.new()
	host.custom_minimum_size = Vector2(box, box)
	host.size = host.custom_minimum_size
	host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if t == null:
		return host
	var region: Rect2 = _used_region(t)
	var at := AtlasTexture.new()
	at.atlas = t
	at.region = region
	## Küçük piksel çizimi tam katla büyür; sığmayan büyük doku (madde 402: eski 250 px ikonlar) oranla küçülür + doğrusal
	## süzgeç (shop_dark_kit.gd icon_tr ile aynı kural).
	var fit: float = minf(box, WEAPON_FIT)
	var big: float = maxf(region.size.x, region.size.y)
	var shrink: bool = big > fit
	var k: float = fit / big if shrink else maxf(1.0, floorf(fit / big))
	var sz: Vector2 = (region.size * k).floor()
	var tr := TextureRect.new()
	tr.texture = at
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if shrink else CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.size = sz
	tr.position = ((host.size - sz) * 0.5).floor()
	if dim:
		tr.modulate = Color(0.45, 0.45, 0.5, 1.0)
	host.add_child(tr)
	return host


## Dokunun dolu piksel dikdörtgeni (önbellekli; satırlar her üstüne gelişte yeniden kurulur).
static var _region_cache: Dictionary = {}
func _used_region(t: Texture2D) -> Rect2:
	var key: String = t.resource_path if t.resource_path != "" else str(t.get_rid().get_id())
	if not _region_cache.has(key):
		var img: Image = t.get_image()
		var r: Rect2i = img.get_used_rect() if img else Rect2i()
		_region_cache[key] = Rect2(r) if r.size.x > 0 and r.size.y > 0 else Rect2(Vector2.ZERO, t.get_size())
	return _region_cache[key]


func _price_row(e: Dictionary, fs: int, center: bool) -> HBoxContainer:
	var r: HBoxContainer = _k.h(14)
	if center:
		r.alignment = BoxContainer.ALIGNMENT_CENTER
	var full: int = Market.full_price(e)
	if full > 0:
		r.add_child(_k.strike_lbl(str(full), mini(fs, 32), _k.c("dim")))
	var cost: int = Market.price(e)
	r.add_child(_k.amt(cost, fs, _k.c("bad") if GameManager.gold < cost else _k.c("price")))
	var sh: int = Market.shards(e)
	if sh > 0:
		r.add_child(_k.amt(sh, fs, _k.c("bad") if GameManager.weapon_shards < sh else DarkKit.SHARD_TEXT, "shard"))
	return r


## ---------------------------------------------------------------- önizleme
## [simge kuyusu 144 | tür satırı + ad 48 + fiyat 48 | KAYDET / YASAKLA] + açıklama kuyusu + (TARİF | ŞUNA DÖNÜŞÜR) + [ELİNDE ... SATIN AL].
func _refresh_detail() -> void:
	if _detail == null:
		return
	_close_item_popup() ## önizleme yeniden kurulurken simgeler gider; açık pencere de kapanır
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	var section: String = str(_focus[0]) if _focus.size() == 2 else "items"
	var i: int = int(_focus[1]) if _focus.size() == 2 else 0
	var e: Dictionary = _offer(section, i)
	if e.is_empty():
		for s: String in Market.SECTIONS:
			if not (offers.get(s, []) as Array).is_empty():
				section = s
				i = 0
				e = _offer(s, 0)
				_focus = [s, 0] ## SATIN AL önizlemede görüneni alsın
				break
	if e.is_empty():
		_detail.add_child(_k.wrap("Pazarda alınabilecek bir şey kalmadı.", DESC_FS, _k.c("dim"), DETAIL_TEXT_W, HORIZONTAL_ALIGNMENT_CENTER))
		return
	var d: Dictionary = Market.describe(e, _player)
	var saved: bool = Market.is_saved(e)
	var sold: bool = bool(e.get("sold", false))
	## baş
	var head: HBoxContainer = _k.h(20)
	head.name = "DetailHead"
	var well: PanelContainer = _k.box(HudTheme.SAVED_FILL if saved else _k.c("inset"),
			HudTheme.SAVED_EDGE if saved else Color(d["tag_col"], 0.75), 14, 3, 6)
	well.name = "DetailWell"
	well.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	well.add_child(_k.center(_icon(d, DETAIL_ICON, sold)))
	head.add_child(well)
	var tv: VBoxContainer = _k.v(6)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_kind_row(e, d))
	var nm: Label = _k.wrap(_title(e, d, true), 48, _k.c("text"), 10.0)
	nm.name = "DetailName"
	nm.max_lines_visible = 2
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(nm)
	tv.add_child(_k.sp(0, 0, false, true))
	tv.add_child(_price_row(e, 48, false))
	head.add_child(tv)
	var tools: VBoxContainer = _k.v(10)
	tools.add_child(_save_button(section, i, saved, sold))
	tools.add_child(_ban_button(section, i, sold))
	head.add_child(tools)
	_detail.add_child(head)
	## açıklama kuyusu: başlığın hemen altında, yazıya göre sıkı, satırlar ÜSTTEN hizalı (madde 494; kullanıcı 2026-11-08: ortalanmış hâli
	## beğenilmedi, "üstten hizalı daha iyi"); boşluk kuyunun altında kalır. Yazı hep DESC_FS (32; madde 518).
	var lines: Array = d["lines"]
	if not lines.is_empty():
		var dw: PanelContainer = _k.box(HudTheme.WIN_INSET, Color(0, 0, 0, 0), DESC_PAD, 0, 12)
		dw.name = "DescWell"
		var dv: VBoxContainer = _k.v(DESC_GAP)
		dv.name = "DescLines"
		for ln in lines:
			var dl: Label = _k.wrap(_txt(str(ln)), DESC_FS, _k.c("text"), DETAIL_TEXT_W - 2.0 * DESC_PAD)
			dv.add_child(dl)
		dw.add_child(dv)
		_detail.add_child(dw)
	if _ban_armed == _key(section, i):
		_detail.add_child(_status_line(DarkKit.G_X, _k.c("bad"),
			tr("Yasaklamak için tekrar bas: bu oyun boyunca bir daha çıkmaz (kalan hak %d)") % Market.bans_left()))
	if str(e["type"]) == "item":
		_add_recipe(str(e["key"]))
	_detail.add_child(_k.sp(0, 0, false, true)) ## kalan boşluk altta: ELİNDE / SATIN AL satırını aşağıda tutar
	## alt: ELİNDE (bakiye) + SATIN AL / GELİŞTİR (alınamıyorsa düğme nedeni yazar ve kapalı; madde 433 ek 3: alma YALNIZ bu düğmeyle)
	var foot: HBoxContainer = _k.h(18)
	foot.name = "DetailFoot"
	var have: HBoxContainer = _k.h(12)
	have.name = "Purse"
	have.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	have.add_child(_k.lbl("ELİNDE", 32, _k.c("dim")))
	have.add_child(_k.amt(GameManager.gold, 32, _k.c("price")))
	have.add_child(_k.amt(GameManager.weapon_shards, 32, DarkKit.SHARD_TEXT, "shard"))
	foot.add_child(have)
	foot.add_child(_k.sp(0, 0, true))
	if sold:
		var br: HBoxContainer = _k.h(8)
		br.alignment = BoxContainer.ALIGNMENT_CENTER
		br.custom_minimum_size = Vector2(BUY_W, BUY_H)
		br.add_child(_k.glyph(DarkKit.G_CHECK, _k.c("good"), 3))
		br.add_child(_k.lbl("ALINDI", 32, _k.c("good")))
		foot.add_child(br)
	else:
		var reason: String = Market.block_reason(_player, e)
		var bb: Button = _k.btn(reason, "primary", 32, BUY_H, BUY_W) if reason != "" else _buy_button(_is_upgrade(e))
		bb.name = "BuyButton"
		bb.disabled = reason != ""
		bb.pressed.connect(_on_buy_pressed)
		foot.add_child(bb)
	_detail.add_child(foot)
	UISound.connect_all_buttons(_detail)


## Tür satırı (32): eşyada heybe + tür (SİLAH / EŞYA / MANA KALKANI; nadirlik yazısı YOK, o kuyunun kenarında) + silahta "Silah yuvası
## n/m"; geliştirmede çekiç + silah adı + kademe ("III » IV").
func _kind_row(e: Dictionary, d: Dictionary) -> HBoxContainer:
	var r: HBoxContainer = _k.h(12)
	r.name = "KindRow"
	var col: Color = Color(d["tag_col"]).lerp(_k.c("text"), 0.3)
	var upg: bool = _is_upgrade(e)
	var g: Control = _k.glyph(DarkKit.G_HAMMER if upg else DarkKit.G_BAG, col, 3)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(g)
	if upg:
		if str(e["type"]) != "upgrade":
			r.add_child(_k.lbl(str(d["name"]), 32, col))
		var bl: Label = _k.lbl(_txt(str(d.get("row_badge", ""))), 32, _k.c("dim"))
		bl.name = "Badge"
		r.add_child(bl)
	else:
		var kl: Label = _k.lbl(str(d.get("kind", "")), 32, col)
		kl.name = "Kind"
		r.add_child(kl)
		if str(e["type"]) == "weapon":
			r.add_child(_k.lbl(str(d["sub"]), 32, _k.c("dim")))
	return r


## Yazılı KAYDET düğmesi (madde 472; eskiden satırın köşesinde simge). Kayıtlıyken yeşil "KAYITLI" (basınca kayıt kalkar).
## Düğmeler kendi basışlarında önizlemeyle yeniden kurulduğu için ERTELENMİŞ bağlanır.
func _save_button(section: String, i: int, saved: bool, sold: bool) -> Button:
	var r: HBoxContainer = _k.h(10)
	var g: Control = _k.glyph(DarkKit.G_LOCK, _k.c("accent_text") if saved else HudTheme.SAVED, 3)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(g)
	r.add_child(_k.lbl("KAYITLI" if saved else "KAYDET", 32, _k.c("accent_text") if saved else _k.c("text")))
	var b: Button = _k.row_btn(r, "ghost", TOOL_H, TOOL_W)
	b.name = "SaveButton"
	if saved: ## kayıtlıyken yeşil (altın "primary" değil; madde 433)
		b.add_theme_stylebox_override("normal", _k.sb(HudTheme.SAVED_BTN, HudTheme.SAVED_BTN_EDGE, 3, 6, 10.0))
		b.add_theme_stylebox_override("hover", _k.sb(HudTheme.SAVED_BTN.lightened(0.1), HudTheme.SAVED_BTN_EDGE, 3, 6, 10.0))
		b.add_theme_stylebox_override("pressed", _k.sb(HudTheme.SAVED_BTN.darkened(0.12), HudTheme.SAVED_BTN_EDGE, 3, 6, 10.0))
	b.tooltip_text = "Kaydı kaldır" if saved else "Kaydet: karıştırınca ve sonraki seviyede kaybolmaz"
	b.disabled = sold
	b.pressed.connect(toggle_save.bind(section, i), CONNECT_DEFERRED)
	return b


## Yazılı YASAKLA düğmesi: ilk basış kurar (kırmızı "TEKRAR BAS"), ikinci basış yasaklar; hak bitince kapalı.
func _ban_button(section: String, i: int, sold: bool) -> Button:
	var armed: bool = _ban_armed == _key(section, i)
	var r: HBoxContainer = _k.h(10)
	var g: Control = _k.glyph(DarkKit.G_X, Color.WHITE if armed else _k.c("bad"), 3)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(g)
	r.add_child(_k.lbl("TEKRAR BAS" if armed else "YASAKLA", 32, Color.WHITE if armed else _k.c("text")))
	var b: Button = _k.row_btn(r, "ghost", TOOL_H, TOOL_W)
	b.name = "BanButton"
	if armed:
		b.add_theme_stylebox_override("normal", _k.sb(_k.c("bad"), _k.c("bad").darkened(0.3), 3, 6, 10.0))
		b.add_theme_stylebox_override("hover", _k.sb(_k.c("bad").lightened(0.1), _k.c("bad").darkened(0.3), 3, 6, 10.0))
	b.tooltip_text = tr("Yasakla (iki kez bas): bu oyun boyunca bir daha çıkmaz · kalan hak %d") % Market.bans_left()
	b.disabled = sold or Market.bans_left() <= 0
	b.pressed.connect(press_ban.bind(section, i), CONNECT_DEFERRED)
	return b


## TARİF (alt eşyalar; sendekiler "SENDE", alt parçaları ipucunda) + ŞUNA DÖNÜŞÜR (bu eşyanın girdiği tarifler) - seyyar satıcının
## ağacı (scripts/recipe_tree.gd). İkisi de varsa yan yana (önizleme dikeyde sığsın).
func _add_recipe(key: String) -> void:
	var has_recipe: bool = not (Items.recipe(key) as Array).is_empty()
	var ups: Array = Items.builds_into(key)
	if not has_recipe and ups.is_empty():
		return
	var row: HBoxContainer = _k.h(24)
	row.name = "RecipeRow"
	var recipe_w: float = 0.0 ## TARİF sütununun genişliği / ağaç boyu: ŞUNA DÖNÜŞÜR kalan yere ve aynı yüksekliğe sığar
	var recipe_h: float = UPS_AREA_H
	if has_recipe:
		var rv: VBoxContainer = _k.v(6)
		rv.add_child(_k.lbl("TARİF", 32, HudTheme.ACCENT_SOFT))
		## Yalnız DOĞRUDAN alt eşyalar, kök yok (eşya başlıkta): tam ağaç efsanevide 9 yaprağı 32 px'e küçültüp okunmaz yapıyordu (kullanıcı
		## 2026-11-07: "çok zor okunuyor, ufacıklar").
		var area: Vector2 = RECIPE_AREA if ups.is_empty() else Vector2(RECIPE_SIDE_W, RECIPE_AREA.y)
		var tv: Control = RecipeTree.fit_row(_k, RecipeTree.data(key, RecipeTree.owned_pool(), false, true, RECIPE_LEVELS), area,
				RECIPE_SIZES, RECIPE_FS)
		tv.name = "RecipeTree"
		rv.add_child(tv)
		row.add_child(rv)
		recipe_w = maxf(tv.custom_minimum_size.x, _k.tw("TARİF", 32))
		recipe_h = tv.custom_minimum_size.y
	if not ups.is_empty():
		var uv: VBoxContainer = _k.v(6)
		uv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		uv.add_child(_k.lbl("ŞUNA DÖNÜŞÜR", 32, HudTheme.ACCENT_SOFT))
		var flow := HFlowContainer.new()
		flow.name = "BuildsInto"
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		var ups_w: float = DETAIL_TEXT_W - recipe_w - 24.0 if has_recipe else DETAIL_TEXT_W
		flow.custom_minimum_size.x = ups_w
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var chip_s: float = _ups_size(ups.size(), ups_w, recipe_h)
		for u: String in ups:
			flow.add_child(_item_chip(u, chip_s))
		uv.add_child(flow)
		row.add_child(uv)
	_detail.add_child(row)


## ---------------------------------------------------------------- eşya penceresi (madde 494)
## ŞUNA DÖNÜŞÜR simgesi: tıklanınca eşyanın ne olduğunu ayrı pencerede gösterir (yetenek ipucu gibi, ama pazarın ahşap çerçevesinde).
## Görünmez düz Button (el imleci + tık sesi + klavye/kumanda) + üstünde yuva; üstüne gelince / pencere açıkken seçim halkası yanar.
func _item_chip(key: String, s: float) -> Button:
	var b := Button.new()
	b.name = "Chip_%s" % key
	b.flat = true
	b.custom_minimum_size = Vector2(s, s)
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	UiAnim.skip(b)
	b.add_child(_k.tile(Items.icon(key), s, DarkKit.TIER_COL[clampi(Items.kademe(key), 1, 3) - 1]))
	b.tooltip_text = tr("%s (%d altın)") % [tr(Items.item_name(key)), Items.cost(key)]
	b.mouse_entered.connect(_chip_ring.bind(b))
	b.mouse_exited.connect(_chip_ring.bind(b))
	b.focus_entered.connect(_chip_ring.bind(b))
	b.focus_exited.connect(_chip_ring.bind(b))
	b.pressed.connect(_toggle_item_popup.bind(key, b))
	return b


## Seçim halkası: fare üstünde / odakta / penceresi açıkken yanık.
func _chip_ring(b: Button) -> void:
	if not is_instance_valid(b) or b.get_child_count() == 0:
		return
	var ring: Node = b.get_child(0).get_node_or_null("SelRing")
	if ring:
		(ring as CanvasItem).visible = b.is_hovered() or b.has_focus() or _pop_owner == b


func _toggle_item_popup(key: String, chip: Button) -> void:
	if _pop != null and _pop_owner == chip:
		_close_item_popup()
	else:
		_open_item_popup(key, chip)


## Pencere: dış çerçeve pazarla aynı ahşap (RIM + OUTLINE), iç panel RIM_LO; [simge | tür + ad 48 + fiyat] + açıklama kuyusu + TARİF.
## Boyu içerikten çıkar; yerleşince (resized) simgenin üstüne (yer yoksa altına) basamaklı uçla oturtulur.
func _open_item_popup(key: String, chip: Button) -> void:
	_close_item_popup()
	var e: Dictionary = {"type": "item", "key": key}
	var d: Dictionary = Market.describe(e, _player)
	var inner_w: float = POP_W - 2.0 * FRAME_RIM_PAD - 2.0 * POP_WIN_PAD
	var rb: PanelContainer = _k.box(HudTheme.RIM, HudTheme.OUTLINE, FRAME_RIM_PAD, 4, 6)
	rb.name = "ItemPopup"
	rb.mouse_filter = Control.MOUSE_FILTER_STOP ## içine tık altındaki pencereye geçmesin
	rb.custom_minimum_size.x = POP_W
	var win: PanelContainer = _k.box(_k.c("panel"), HudTheme.RIM_LO, POP_WIN_PAD, 3, 4)
	rb.add_child(win)
	var col: VBoxContainer = _k.v(12)
	win.add_child(col)
	## baş: kademe kenarlı simge kuyusu | tür + ad + fiyat
	var head: HBoxContainer = _k.h(16)
	var well: PanelContainer = _k.box(_k.c("inset"), Color(Color(d["tag_col"]), 0.75), 10, 3, 6)
	well.name = "PopupWell"
	well.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	well.add_child(_k.center(_icon(d, POP_ICON)))
	head.add_child(well)
	var tv: VBoxContainer = _k.v(4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_kind_row(e, d))
	var nm: Label = _k.wrap(_title(e, d, true), POP_NAME_FS, _k.c("text"), inner_w - (POP_ICON + 20.0) - 16.0)
	nm.name = "PopupName"
	tv.add_child(nm)
	tv.add_child(_price_row(e, POP_FS, false))
	head.add_child(tv)
	col.add_child(head)
	## açıklama: stat satırları + pasif
	var lines: Array = d["lines"]
	if not lines.is_empty():
		var dw: PanelContainer = _k.box(HudTheme.WIN_INSET, Color(0, 0, 0, 0), 14, 0, 10)
		dw.name = "PopupDesc"
		var dv: VBoxContainer = _k.v(DESC_GAP)
		for ln in lines:
			dv.add_child(_k.wrap(_txt(str(ln)), POP_FS, _k.c("text"), inner_w - 28.0))
		dw.add_child(dv)
		col.add_child(dw)
	## tarif: neden yapıldığı (doğrudan alt eşyalar, pazardaki TARİF ile aynı ağaç)
	if not (Items.recipe(key) as Array).is_empty():
		col.add_child(_k.lbl("TARİF", POP_FS, HudTheme.ACCENT_SOFT))
		var rt: Control = RecipeTree.fit_row(_k, RecipeTree.data(key, RecipeTree.owned_pool(), false, true, RECIPE_LEVELS),
				Vector2(inner_w, POP_RECIPE_H), POP_RECIPE_SIZES, RECIPE_FS)
		rt.name = "PopupRecipe"
		col.add_child(rt)
	rb.draw.connect(_draw_popup_notch.bind(rb))
	## Çerçeve ağaca girerken etiketler henüz genişliğini bilmez, asgari boy şişkin çıkar ve boy ona yapışır -> asgari boy değişince
	## boy asgariye çekilir; sonra yerleşim.
	rb.minimum_size_changed.connect(rb.reset_size)
	rb.resized.connect(_place_item_popup)
	_pop = rb
	_pop_owner = chip
	_pop_key = key
	chip.set_meta("tip", chip.tooltip_text)
	chip.tooltip_text = "" ## pencere açıkken ad/fiyat ipucu üstüne binmesin
	add_child(rb) ## en son çocuk = en üstte
	_chip_ring(chip)
	UiAnim.reveal(rb, 0.2, 0.12)


func _close_item_popup() -> void:
	var owner_chip: Button = _pop_owner as Button if is_instance_valid(_pop_owner) else null
	var pop: Control = _pop if is_instance_valid(_pop) else null
	_pop = null
	_pop_owner = null
	_pop_key = ""
	if pop != null:
		if pop.get_parent() == self:
			remove_child(pop)
		pop.queue_free()
	if owner_chip != null:
		owner_chip.tooltip_text = str(owner_chip.get_meta("tip", owner_chip.tooltip_text))
		_chip_ring(owner_chip)


## Pencereyi simgenin ÜSTÜNE ortalar; yer yoksa ALTINA, o da yoksa SOLUNA, sonra SAĞINA (simgeler artık 104 px ve satır önizlemenin
## ortalarında - 525 px'lik pencere ne üstte ne altta sığabiliyordu); ekrana sığdırır, uç simgeye bakar. Konumlar görünümün 1920x1080 yerelinde.
## meta "notch" = [uç kenarı boyunca simge ortası, pencerenin simgeye göre yeri ("above" | "below" | "left" | "right")].
func _place_item_popup() -> void:
	if not is_instance_valid(_pop) or not is_instance_valid(_pop_owner) or _pop.size.x < 1.0:
		return
	var sz: Vector2 = _pop.size
	var chip_r: Rect2 = get_global_transform().affine_inverse() * _grect(_pop_owner)
	var cx: float = chip_r.position.x + chip_r.size.x * 0.5
	var cy: float = chip_r.position.y + chip_r.size.y * 0.5
	var lo: float = POP_SCREEN_PAD
	var pos := Vector2.ZERO
	var side: String = "above"
	if chip_r.position.y - POP_GAP - sz.y >= lo:
		pos = Vector2(cx - sz.x * 0.5, chip_r.position.y - POP_GAP - sz.y)
	elif chip_r.end.y + POP_GAP + sz.y <= 1080.0 - lo:
		side = "below"
		pos = Vector2(cx - sz.x * 0.5, chip_r.end.y + POP_GAP)
	elif chip_r.position.x - POP_GAP - sz.x >= lo:
		side = "left"
		pos = Vector2(chip_r.position.x - POP_GAP - sz.x, cy - sz.y * 0.5)
	elif chip_r.end.x + POP_GAP + sz.x <= 1920.0 - lo:
		side = "right"
		pos = Vector2(chip_r.end.x + POP_GAP, cy - sz.y * 0.5)
	else:
		pos = Vector2(cx - sz.x * 0.5, lo) ## hiçbiri sığmıyor (olmamalı): tepeye yaslan
	pos.x = clampf(pos.x, lo, maxf(lo, 1920.0 - sz.x - lo))
	pos.y = clampf(pos.y, lo, maxf(lo, 1080.0 - sz.y - lo))
	pos = pos.round()
	_pop.position = pos
	var vertical: bool = side == "above" or side == "below"
	_pop.set_meta("notch", [roundf((cx - pos.x) if vertical else (cy - pos.y)), side])
	_pop.queue_redraw()


## Basamaklı uç (yetenek ipucuyla aynı 3 px piksel dili): dolgu çerçevenin ahşabı (RIM), 1 piksellik OUTLINE kenar. d = çerçeve kenarından
## dışa uzaklık; satır 0 çerçevenin 4 px'lik dış hattını açar (ağız), sonraki satırlar daralıp tek pikselde biter. Uç, pencerenin simgeye
## bakan kenarında: üstteki pencerenin alt kenarında aşağı, soldaki pencerenin sağ kenarında sağa...
func _draw_popup_notch(pop: Control) -> void:
	if not pop.has_meta("notch"):
		return
	var nm: Array = pop.get_meta("notch")
	var side: String = str(nm[1])
	var vertical: bool = side == "above" or side == "below"
	var edge_len: float = pop.size.x if vertical else pop.size.y
	var c: float = clampf(float(nm[0]), NOTCH_PX * 8.0, edge_len - NOTCH_PX * 8.0)
	var outward: float = 1.0 if (side == "above" or side == "left") else -1.0 ## d artarken eksende yön (alt / sağ kenar +, üst / sol -)
	var base: float = pop.size.y if side == "above" else (pop.size.x if side == "left" else 0.0)
	var a0: float = roundf(c - NOTCH_PX * 0.5)
	## satır: [d başı, d sonu, dolgu yarı genişliği (hücre), dış hat hücresi (-1 yok)]
	var rows: Array = [[-4.0, 0.0, 3, -1], [0.0, 3.0, 2, 3], [3.0, 6.0, 1, 2], [6.0, 9.0, 0, 1], [9.0, 12.0, -1, 0]]
	for r: Array in rows:
		var d0: float = float(r[0])
		var d1: float = float(r[1])
		var o0: float = base + d0 if outward > 0.0 else base - d1 ## kenara dik eksendeki başlangıç
		var ext: float = d1 - d0
		var half: int = int(r[2])
		if half >= 0:
			_notch_rect(pop, vertical, a0 - half * NOTCH_PX, (2 * half + 1) * NOTCH_PX, o0, ext, HudTheme.RIM)
		var o: int = int(r[3])
		if o >= 0:
			_notch_rect(pop, vertical, a0 - o * NOTCH_PX, NOTCH_PX, o0, ext, HudTheme.OUTLINE)
			if o > 0:
				_notch_rect(pop, vertical, a0 + o * NOTCH_PX, NOTCH_PX, o0, ext, HudTheme.OUTLINE)


## a = kenar boyunca başlangıç/uzunluk, o = kenara dik başlangıç/kalınlık; dikey uçta (üst/alt kenar) x = a, yatay uçta x = o.
func _notch_rect(pop: Control, vertical: bool, a: float, a_len: float, o: float, o_len: float, col: Color) -> void:
	pop.draw_rect(Rect2(a, o, a_len, o_len) if vertical else Rect2(o, a, o_len, a_len), col)


## Pencerenin dışına tık / Esc kapatır. Penceredeki tık ve açan simgenin kendi tıkı (aç/kapa) burada kapatmaz.
func _input(event: InputEvent) -> void:
	if _pop == null:
		return
	var mb := event as InputEventMouseButton
	if mb != null:
		if not mb.pressed:
			return
		if _grect(_pop).has_point(mb.position) or (is_instance_valid(_pop_owner) and _grect(_pop_owner).has_point(mb.position)):
			return
		_close_item_popup()
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		_close_item_popup()
		get_viewport().set_input_as_handled()
		GameManager.mark_ui_cancel_consumed()


## Denetimin ekran koordinatındaki dikdörtgeni (görünüm ölçeklense bile boyut dahil).
static func _grect(c: Control) -> Rect2:
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)


## ŞUNA DÖNÜŞÜR yuva boyu: n simge w genişliğe sarılırken toplam yüksekliği h'yi aşmayan EN BÜYÜK boy; hiçbiri sığmazsa en küçük.
func _ups_size(n: int, w: float, h: float) -> float:
	for s: float in UPS_SIZES:
		var per_row: int = maxi(1, int(floorf((w + UPS_GAP) / (s + UPS_GAP))))
		var rows: int = ceili(float(n) / float(per_row))
		if rows * s + (rows - 1) * UPS_GAP <= h:
			return s
	return float(UPS_SIZES[UPS_SIZES.size() - 1])


func _status_line(pat: Array, col: Color, t: String) -> HBoxContainer:
	var r: HBoxContainer = _k.h(10)
	var g: Control = _k.glyph(pat, col, 2)
	g.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	r.add_child(g)
	r.add_child(_k.wrap(t, DESC_FS, col, DETAIL_TEXT_W - 24.0))
	return r
