extends Control

## (2026-09-25: artık SAĞ üstte, minimapın altında - bkz. RIGHT_MARGIN; görünüm 2026-09-27: bkz. İKİNCİ TASARIM.) Klasik MMORPG "party frame" tarzı küçük bir
## müttefik paneli (kullanıcı isteği: "sağ taraf altın üretim butonlarına -
## maden/altın toplayıcı - ayrıldığı için mutlaka SOL tarafta olmalı"). Her
## satırda o müttefikin avatarı+ismi, can/kalkan barı VE tıklanınca miktar
## seçip altın hediye edilebilen küçük bir altın ikonu var.
##
## Kullanıcı notu: "eskiden ayrı bir altın verme paneli/butonu vardı, artık
## bu YENİ parti panelinden verilecek" - proje genelinde (tüm .gd/.tscn
## dosyaları) arandı, böyle eski bir panel/buton HİÇ bulunamadı; kaldırılacak
## bir şey yoktu, altın hediye özelliği doğrudan burada sıfırdan kuruldu
## (bkz. NetworkManager.request_give_gold/receive_gold_gift).
##
## remote_player.gd zaten sadece GERÇEK uzak oyuncu kuklalarını
## "remote_players" grubuna ekliyor (yerel oyuncu bu grupta DEĞİL, bkz. o
## script'in _ready() yorumu) - yani bu grubu taramak otomatik olarak
## "kendim HARİÇ tüm müttefikler" listesini verir (xp_orb.gd
## _resolve_attraction_target ile AYNI gevşek bağlı/loose-coupling desen).
## Tek oyunculu modda bu grup hep boş olduğu için panel kendiliğinden gizli
## kalır, ekstra bir kontrol gerekmez.


## YENİDEN TASARIM (kullanıcı isteği 2026-09-25): "grup paneli daha basit görünmeli ..." - ahşap pencere + parşömen
## kutular kaldırılıp tek sade koyu kutuya (UIKit "hud_flat") geçilmişti.
## İKİNCİ TASARIM (kullanıcı isteği 2026-09-27: "grup arayüzü diğer panellerle yakışmıyor diğer panellere benzemeli yapısı
## ve minimalist olmalı"): koyu kutu HUD'un geri kalanından (bej levhalı görev satırları, altın göstergesi, ENVANTER, can/
## kalkan levhaları) kopuk duruyordu. Artık her müttefik, hemen altındaki görev satırlarıyla (world_event_banner.gd) AYNI
## yapıda kendi levhası: perçinsiz bej levha (hud_plaque_clean.png, altın göstergesiyle aynı), solda görev okunun kutusuyla
## aynı koyu kutuda 1:1 portre, isim + durum, altında görev ilerleme çubuğuyla aynı gömme (inset_tight) çukurda HUD çubuk
## dokusu - can (kalın) ve kalkan (ince) TEK çukurda üst üste. "GRUP" başlığı kaldırıldı; altın butonu satırın sağında
## küçük ahşap buton, "Hasar" levhaların altında küçük ahşap buton. Açılır pencereler de aynı levha + ahşap butonlar.
const ROW_WIDTH := 270.0 ## world_event_banner.gd ROW_WIDTH ile aynı - sağ sütun tek hizada
const AVATAR_SIZE := 48.0 ## portre PNG'leri 48x48 - 1:1 çizilir (bulanık/yamuk ölçek yok)
const AVATAR_BORDER := 2.0
const GOLD_BTN_SIZE := 32.0
## Çubukların içine "şimdiki/en çok" sayısı yazılır (kullanıcı isteği 2026-10-09: "dostların can ve kalkan sayısı grup sekmesindeki barlarında görünmüyor"):
## Sayılar HUD'daki kendi can/kalkan sayısıyla AYNI "%d/%d" biçiminde; 2x (32 punto, rakam 14 px) piksel-net çizilir (bar_value_label.gd) -> çubuklar 10/6 -> 22/18 px.
## (Kullanıcı 2026-10-09 ikinci tur: "sayıların konumu aşağıda kalmış, zor okunuyor, sığmıyor": ilk sürüm 24 punto Label + 16/14 px çubuktu.)
const HP_BAR_HEIGHT := 22.0 ## 2026-10-13 (kullanıcı: "çok kalın ve kaba"): 30 -> 22; piksel çubuk (çerçeve+gölge payı 6 px dahil) - içte 16 px, yazı 1,5x (rakam 11 px)
const SHIELD_BAR_HEIGHT := 20.0 ## 27 -> 20 (içte 14 px)
const BarValueLabelScript: GDScript = preload("res://scripts/bar_value_label.gd")
const PartyPixelBarScript: GDScript = preload("res://scripts/party_pixel_bar.gd")
## Madde 479 (kullanıcı: "grup panelindeki müttefiklerin can ve kalkan barı da tıpkı skill barındaki gibi görünmesini sağlar mısın ama
## genişliklerini v.s mevcut genişliklerine göre hesapla ve can yenilenmeleri gözükmücek sadece mevcut canları kalkanları ve maksimum canları
## ve kalkanları gözükecek"): MASAÜSTÜNDE müttefik çubukları oyuncu panelindeki çubukla AYNI çizim (hud_pixel_bar.gd: D Pirinç Kapaklı, LoL
## hasar izi/iyileşme dolumu, ortada 9 punto "mevcut/azami"), boylar eskisi gibi (HP_BAR_HEIGHT / SHIELD_BAR_HEIGHT, genişlik satırı doldurur);
## yenilenme yazısı YOK (set_regen hiç çağrılmaz). Sayı çubuğun kendi yazısı (bar.text) -> health_label / shield_label null.
## Telefon eski çubuk + bar_value_label (ekran pikseli 9 punto telefonda okunmaz).
const HudPixelBarScript: GDScript = preload("res://scripts/hud_pixel_bar.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
## Madde 483 (kullanıcı madde 480 prototiplerinden "B yi beğendim"): MASAÜSTÜNDE grup paneli "B - Tek Konsol": bütün satırların ARKASINDA tek
## Gömme Tepsi (paneldeki yan kutu, _ListTray), satır levhaları kalkar (aynı içerik payıyla boş kutu), satırlar arası paneldeki ayraç; portre
## yuva çerçeveli (hud_tray_frame.gd) koyu kuyuda, altın düğmesi 42 px koyu yuva + çerçeve + oyundaki altın 2x, ad m5x7 32; "Hasar" tepsinin
## altına asılı kabarık ahşap sekme (HudTrayKit.plate). Telefon eski levhalarında.
const HudTrayKit := preload("res://scripts/hud_tray_kit.gd")
const HudTrayFrame := preload("res://scripts/hud_tray_frame.gd")
const TRAY_GOLD_BTN := 42.0
## Kullanıcı: "minimaple grup yapışık olmasın ve hasar butonunu da bunlara uygun yap": tepsi minimap çerçevesinin (alt kenarı y 196) 9 px
## altında başlar (TOP_Y 198 -> liste 208, tepsi 205), sağ kenarı listenin sağı = minimap çerçevesi / görev satırı / bildirimlerle aynı hizada.
const TRAY_TOP_Y := 208.0
## Hasar (kullanıcı: "hasar butonunu grup paneliyle bir yapma şansın var mı illa hasar yazmasına da gerek yok skill bardaki stat gösterme
## butonu gibi bişey yapabilirsin"): tepsinin İÇİNDE sağ alt köşede, paneldeki stat düğmesiyle (hud_stat_toggle.gd) aynı çizim - koyu levha +
## çubuk grafik + yön oku (kapalı "<": pencere sola açılır, açık ">"), yazısız. Kullanıcı (ekran görüntüsünde minimapin solunu işaretleyip):
## "grup istatistikleri butonu kırmızı kareye aldığım kısımda ayrı bir mini buton olarak gözüksün orası yerine" -> tepsinin İÇİNDE değil,
## minimap çerçevesinin SOLUNDA ayrı mini düğme (altı çerçevenin altıyla hizalı, 9 px boşluk; _place_stats_tab). Grup paneliyle görünür/gizlenir.
const PixelIcons := preload("res://scripts/hud_pixel_icons.gd")
const TRAY_TAB_SIZE := Vector2(64.0, 20.0)


class _StatsTab extends Button:
	const ARROW_CLOSED: Array[String] = ["..X", ".XX", "XXX", ".XX", "..X"]
	const ARROW_OPEN: Array[String] = ["X..", "XX.", "XXX", "XX.", "X.."]
	const BARS: Array[int] = [4, 8, 6, 11]
	const GOLD := Color(0.98, 0.82, 0.30)
	const VALUE := Color(0.97, 0.93, 0.84)
	var popup: Control = null
	func _ready() -> void:
		flat = true
		for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		var on: bool = is_instance_valid(popup) and popup.visible
		var hov: bool = is_hovered()
		var d := Vector2(0, 1) if on else Vector2.ZERO
		var plate: Color = HudTheme.DOCK_PLATE_ON if on else (HudTheme.DOCK_STRIPE if hov else HudTheme.DOCK_INSET)
		PixelIcons.draw_plate(self, Rect2(Vector2.ZERO, size), plate)
		draw_rect(Rect2(Vector2(2, 2), Vector2(size.x - 4, 1)), Color(GOLD, 0.55) if on else HudTheme.RIM_LO)
		var lit: bool = on or hov
		for i in BARS.size():
			var h: int = BARS[i]
			draw_rect(Rect2(Vector2(25 + i * 5, 15 - h) + d, Vector2(4, h)), HudTheme.OUTLINE)
			draw_rect(Rect2(Vector2(26 + i * 5, 16 - h) + d, Vector2(2, h - 2)), GOLD if lit else VALUE)
		PixelIcons.draw_flat(self, ARROW_OPEN if on else ARROW_CLOSED, Vector2(9, 5) + d, 2.0, GOLD)
const FS_ROW_TRAY := 32
var _list_tray: Panel = null

## Madde 491 (kullanıcı: "grup istatistik hasar arayüzünü oyunun arayüzüyle uyumlu görünmesini sağla çerçevenin vb"): MASAÜSTÜNDE Hasar
## Sıralaması penceresi eski bej levha (perçinsiz plaque, 24 punto, görev çubuğu dokusu, ahşap "x") yerine yanındaki grup paneliyle AYNI
## Gömme Tepsi (HudTrayKit.tray): başlık m5x7 32 + sol üst konsoldaki kabarık ahşap kapat düğmesi (piksel X), başlık/satır arası paneldeki
## ayraç, satırda sıra + grup satırıyla aynı yuva çerçeveli yakın yüz portresi + ad (kendin altın) + oyun sonu tablosu gibi iki sütun: sayı
## PixeloidSans 18 + altında 12 px piksel çubuk (verilen turuncu / alınan mavi, her sütun kendi en büyüğüne göre). Telefon eski levhada.
const DamageStats := preload("res://scripts/damage_stats.gd")
const STATS_PAD_X := 21.0 ## tepsi çerçevesi 12 px + 9 px pay
const STATS_PAD_Y := 18.0
const STATS_NUM_FONT: Font = preload("res://assets/fonts/PixeloidSans-Bold.ttf")
const STATS_NUM_FS := 18
const STATS_RANK_W := 27.0
const STATS_NAME_W := 108.0
const STATS_DEALT_W := 102.0 ## 3 px ızgara katı ("123.456" PixeloidSans 18 sığar)
const STATS_TAKEN_W := 90.0
const STATS_BAR_H := 12.0
const STATS_GAP := 9.0
## Pencere minimap çerçevesinin ÜST hizasında, sağ sütunun (minimap + Hasar sekmesi + grup tepsisi) hemen solunda açılır: bir satırı fazla
## (kendin) olsa da grup tepsisinin altına sarkmaz -> altındaki görev satırları / bildirimlerle (katman 100) çakışmaz (ilk denemede 4 kişide
## pencerenin alt sağ köşesi "ADAYA CANAVARLAR SALDIRIYOR" levhasının altında kalıyordu).


## Sol üst konsoldaki ENVANTER gibi kabarık ahşap düğme + 5x5 piksel X (1 sanat px = 3 ekran px).
class _StatsClose extends Button:
	const X_ROWS: Array[String] = ["X...X", ".X.X.", "..X..", ".X.X.", "X...X"] ## dil:yok (piksel deseni)
	func _ready() -> void:
		text = ""
		focus_mode = Control.FOCUS_NONE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		HudTrayKit.style_plate_button(self, 0.0)
	func _draw() -> void:
		var px: float = HudTrayKit.P
		var pos: Vector2 = ((size - Vector2(5.0, 5.0) * px) * 0.5).floor()
		var col: Color = HudTheme.DIM if get_draw_mode() == DRAW_PRESSED else HudTheme.TEXT
		PixelIcons.draw_flat(self, X_ROWS, pos, px, col)


## Paneldeki ayraç (grup satırları arasındakiyle aynı), kendi genişliği boyunca.
class _StatsDivider extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(0.0, 2.0 * HudTrayKit.P)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		HudTrayKit.draw_divider(self, 0.0, size.x, 0.0)


## Oyun sonu tablosunun çubuğu (game_over_board.gd _bar) Gömme Tepsi kuyusunda: 3 px dış hat + koyu kuyu + dolgu (üst 3 px açık).
class _StatsBar extends Control:
	var ratio: float = 0.0
	var fill: Color = Color.WHITE
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var p: float = HudTrayKit.P
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, HudTheme.OUTLINE)
		var inner: Rect2 = r.grow(-p)
		draw_rect(inner, HudTheme.DOCK_INSET)
		var w: float = roundf(inner.size.x * clampf(ratio, 0.0, 1.0) / p) * p
		if ratio > 0.0:
			w = maxf(w, p)
		if w > 0.0:
			draw_rect(Rect2(inner.position, Vector2(w, inner.size.y)), fill)
			draw_rect(Rect2(inner.position, Vector2(w, p)), fill.lightened(0.35))


class _ListTray extends Panel:
	var list: Control = null
	func _draw() -> void:
		if list == null or not is_instance_valid(list):
			return
		var inv: Transform2D = get_global_transform().affine_inverse()
		var kids: Array = list.get_children()
		var first: bool = true
		for k in kids:
			var c: Control = k as Control
			if c == null or not c.visible:
				continue
			if not first:
				var y: float = (inv * c.global_position).y - 6.0 ## satır arası boşluk (List separation 6) tam ayraç
				HudTrayKit.draw_divider(self, 18.0, size.x - 18.0, y)
			first = false


## Yuva çerçevesi (paneldeki yetenek yuvaları gibi) - ebeveyninin üstünde, kendi dikdörtgenine çizer.
class _TrayOverlay extends Control:
	var layer_px: float = 1.0
	func _draw() -> void:
		HudTrayFrame.draw(self, Rect2(Vector2.ZERO, size), layer_px)


static func _tray_ui() -> bool:
	return not MobileUIScript.enabled
const FS_ROW := 24 ## m5x7 3x - görev satırlarıyla aynı (16 1080p'de okunmuyor)
## Sağ üstteki minimap'in (hud.tscn MinimapControl: sağdan 36, alt kenar 186) hemen altı.
const RIGHT_MARGIN := 36.0
const TOP_Y := 198.0
const GOLD_ICON_PATH := "res://assets/ui/newui/icon_gold_coin.png" ## oyun içi altın parayla aynı (animasyonsuz ilk kare)
const AVATAR_BG := preload("res://assets/ui/kit/hud_avatar_bg.png")
const PortraitFace := preload("res://scripts/portrait_face.gd") ## yüz kırpımı + karakter arka planı (madde 458/464)
const PLAQUE_CLEAN := preload("res://assets/ui/game/hud_plaque_clean.png")
const BarUnder := preload("res://assets/ui/kit/hud_bar_under.png")
const BarFill := preload("res://assets/ui/kit/hud_bar_fill.png")
## Görev okunun kutusuyla aynı koyu çerçeve (world_event_banner.gd ArrowBox).
const HudTheme := preload("res://scripts/hud_theme.gd") ## madde 207: grup satırları + açılır pencereleri koyu HUD temasında
const BOX_OUTLINE := HudTheme.OUTLINE
const BOX_FILL := HudTheme.INSET
const SHIELD_COLOR := Color(0.35, 0.72, 1.0, 1.0) ## overhead_bar.gd kalkan rengi ile AYNI
const DAMAGE_BAR_COLOR := Color("#e0aa3e") ## görev çubuğunun altın tonu
## Hasar Sıralaması "Alınan" sütunu (2026-10-18): HUD'un uyarı kırmızısı; sayı sütunları aynı genişlikte.
const TAKEN_COLOR := HudTheme.BAD
const STAT_COL_W := 72.0

## Kim ne zaman katıldı/ayrıldı diye satırların Node'larını her karede değil,
## bu aralıkta bir kontrol ediyoruz (satır içeriği - can/kalkan/isim/durum -
## yine de her karede güncelleniyor, bkz. _process/_update_rows).
const REFRESH_INTERVAL := 0.5

## Tek bir satırın Control referanslarını bir arada tutan basit yardımcı.
class PartyRow:
	var container: Control
	var avatar: TextureRect
	var avatar_bg: TextureRect ## madde 464: karakter arka planı buraya (yoksa AVATAR_BG)
	var name_label: Label
	var health_bar: Control ## party_pixel_bar.gd (2026-10-10: karakter üstü çubuk stili)
	var shield_bar: Control
	var health_label: Control ## health_bar'ın içinde ortalı sayı (bar_value_label.gd; .text)
	var shield_label: Control ## shield_bar'ın içinde ortalı sayı (kalkan yoksa boş)
	var gold_button: Button
	var downed_label: Label
	var peer_id: int = 0

var _rows: Dictionary = {} ## peer_id(int) -> PartyRow
var _list: VBoxContainer = null
## Satırlar bir kaydırma kutusunda: telefonda kalabalık grup KÜÇÜLMEZ, kaydırılır (bkz. set_max_list_height).
var _list_scroll: ScrollContainer = null
var _max_list_h: float = 0.0
var _gift_popup: PanelContainer = null
var _gift_amount_label: Label = null
var _gift_target_peer: int = 0
var _refresh_timer: float = 0.0

## Kullanıcı isteği: "istatistiklerin oyun içinde de gözükebilsin, grup
## penceresinde bir buton olacak, kimin ne kadar vurduğu gösterilecek en çok
## vuran üstte olacak" - bkz. _build_stats_popup/_gather_live_stats.
var _stats_button: Button = null
var _stats_popup: PanelContainer = null
var _stats_list: VBoxContainer = null


func _ready() -> void:
	add_to_group(&"party_panel") ## modal pencereler bu şeridin soluna sığar (bkz. modal_safe_area.gd)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Sağ üst, minimapın altı (bkz. RIGHT_MARGIN/TOP_Y). Kök sıfır genişlikte sağ kenara yapışık; arka plan kutusu
	## (Background) sağdan SOLA doğru büyür - içerik genişlese de ekran dışına taşmaz.
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -RIGHT_MARGIN
	offset_right = -RIGHT_MARGIN
	offset_top = TRAY_TOP_Y if _tray_ui() else TOP_Y
	offset_bottom = offset_top
	visible = false
	_build_static_ui()
	_rebuild_rows()
	## Sonradan yaratılan satır butonları (_create_row) kendi tık sesini ayrıca bağlar.
	UISound.connect_all_buttons(self)


## Perçinsiz levha (altın göstergesiyle aynı: plaque.png payları + hud_plaque_clean.png dokusu; madde 207 HUD teması).
static func _plaque_style(pad_x: float, pad_y: float) -> StyleBoxTexture:
	var sb := MenuKit._tex_style("plaque.png", [6, 5, 6, 5], [pad_x, pad_y, pad_x, pad_y], false, MenuKit.GAME_DIR)
	sb.texture = PLAQUE_CLEAN
	return sb


static func _wood_button(text: String, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIKit.style_button(btn, "hud", true, FS_ROW)
	return btn


func _build_static_ui() -> void:
	theme = UIKit.theme()
	## "Background": levhaların + Hasar butonunun toplam alanı (main.gd görev satırlarını bunun ALTINA hizalar, açılır
	## pencereler bunun SOLUNA açılır). Kendisi çizim yapmaz.
	if _tray_ui():
		_list_tray = _ListTray.new()
		_list_tray.name = "ListTray"
		_list_tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list_tray.add_theme_stylebox_override("panel", HudTrayKit.tray(0.0, 0.0))
		_list_tray.visible = false
		add_child(_list_tray) ## Background'dan ÖNCE = satırların arkasında
	var bg := VBoxContainer.new()
	bg.name = "Background"
	bg.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	bg.add_theme_constant_override("separation", 0 if _tray_ui() else 6)
	bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 6)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list_scroll = ScrollContainer.new()
	_list_scroll.name = "ListScroll"
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	bg.add_child(_list_scroll)
	_list_scroll.add_child(_list)
	if _list_tray:
		_list_tray.list = _list
		_list.resized.connect(_fit_list_tray)
		_list.sort_children.connect(_fit_list_tray)

	## Levhaların altında, sağa yaslı küçük ahşap "Hasar" butonu (hasar sıralaması). Masaüstü: tepsinin içinde stat düğmesi gibi sekme.
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _tray_ui():
		bg.add_child(footer)
	else:
		footer.free()
		## kullanıcı: "alt sınırla çok bitişik aşağıdaki oyuncunun barları arada mesafe olmalı azcık" -> tepsinin altına 9 px pay
		## (çerçevenin iç kenarı listenin altında; son satırın çubukları 8 px yukarıda kalır)
		var bottom_pad := Control.new()
		bottom_pad.name = "TrayBottomPad"
		bottom_pad.custom_minimum_size = Vector2(0.0, 9.0)
		bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(bottom_pad)
	_stats_button = _StatsTab.new() if _tray_ui() else _wood_button("Hasar", Vector2(0, 32))
	_stats_button.tooltip_text = "Kimin ne kadar hasar verdiğini göster"
	_stats_button.pressed.connect(_on_stats_button_pressed)
	if _tray_ui():
		add_child(_stats_button) ## kökün çocuğu: konumu _place_stats_tab (minimapin solu)
	else:
		footer.add_child(_stats_button)
	if _tray_ui():
		_stats_button.custom_minimum_size = TRAY_TAB_SIZE
		_stats_button.tooltip_text = "Hasar sıralaması"
		_stats_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_build_gift_popup()
	_build_stats_popup()
	if _stats_button is _StatsTab:
		(_stats_button as _StatsTab).popup = _stats_popup
		_stats_popup.visibility_changed.connect(_stats_button.queue_redraw)


## Altın hediye penceresinin düğmesi: masaüstünde kabarık ahşap levha (HudTrayKit.plate) + m5x7 32, telefonda eski küçük ahşap düğme.
static func _gift_button(text: String, min_size: Vector2, tray: bool) -> Button:
	if not tray:
		return _wood_button(text, min_size)
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	HudTrayKit.style_plate_button(btn, 12.0)
	btn.add_theme_font_size_override("font_size", FS_ROW_TRAY)
	return btn


func _build_gift_popup() -> void:
	_gift_popup = PanelContainer.new()
	_gift_popup.name = "GiftPopup"
	_gift_popup.visible = false
	_gift_popup.z_index = 100
	## Madde 491 ek (kullanıcı: "Evet, onu da"): masaüstünde Hasar Sıralaması gibi Gömme Tepsi + 32 punto yazı + ayraç + kabarık ahşap düğmeler
	## (sol üst konsolun Envanter düğmesi); telefon eski bej levha + küçük ahşap düğmeler.
	var tray: bool = _tray_ui()
	_gift_popup.add_theme_stylebox_override("panel", HudTrayKit.tray(STATS_PAD_X, STATS_PAD_Y) if tray else _plaque_style(14.0, 10.0))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9 if tray else 6)
	_gift_popup.add_child(vbox)

	_gift_amount_label = Label.new()
	UIKit.style_label(_gift_amount_label, FS_ROW_TRAY if tray else FS_ROW, HudTheme.TEXT, 0)
	_gift_amount_label.text = "Altın gönder"
	vbox.add_child(_gift_amount_label)
	if tray:
		vbox.add_child(_StatsDivider.new())

	var presets_box := HBoxContainer.new()
	presets_box.add_theme_constant_override("separation", int(STATS_GAP) if tray else 4)
	vbox.add_child(presets_box)
	for amount in [10, 50, 100]:
		var btn := _gift_button(str(amount), Vector2(60, 42) if tray else Vector2(52, 32), tray)
		btn.pressed.connect(_on_gift_amount_pressed.bind(amount))
		presets_box.add_child(btn)
	var all_btn := _gift_button("Hepsi", Vector2(84, 42) if tray else Vector2(64, 32), tray)
	all_btn.pressed.connect(_on_gift_amount_pressed.bind(-1))
	presets_box.add_child(all_btn)

	var cancel_btn := _gift_button("İptal", Vector2(0, 42) if tray else Vector2(0, 32), tray)
	cancel_btn.pressed.connect(_hide_gift_popup)
	vbox.add_child(cancel_btn)

	# Liste akışının (VBoxContainer) DIŞINDA, kök seviyesinde - böylece
	# satırların üstünde serbestçe konumlandırılıp en üstte çizilebiliyor.
	add_child(_gift_popup)


## Hasar sıralaması - grup satırlarıyla AYNI levha; başlık + köşede küçük "x", satırlarda sıra/isim/hasar ve altında en çok
## vurana göre oranlı ince çubuk (görev çubuğuyla aynı gömme çukur + doku).
func _build_stats_popup() -> void:
	_stats_popup = PanelContainer.new()
	_stats_popup.name = "StatsPopup"
	_stats_popup.visible = false
	_stats_popup.z_index = 100
	var tray: bool = _tray_ui() ## madde 491: masaüstü Gömme Tepsi
	_stats_popup.add_theme_stylebox_override("panel", HudTrayKit.tray(STATS_PAD_X, STATS_PAD_Y) if tray else _plaque_style(14.0, 10.0))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 9 if tray else 6)
	_stats_popup.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Hasar Sıralaması"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(title, FS_ROW_TRAY if tray else FS_ROW, HudTheme.ACCENT, 0)
	header.add_child(title)
	## Kullanıcı bildirimi (eski): sadece kendi kapat butonuyla kapanmalı (dışına tıklayınca değil).
	var close_btn: Button = _StatsClose.new() if tray else _wood_button("x", Vector2(32, 32))
	if tray:
		close_btn.custom_minimum_size = Vector2(36.0, 36.0)
		close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.tooltip_text = "Kapat"
	close_btn.pressed.connect(_hide_stats_popup)
	header.add_child(close_btn)
	if tray:
		vbox.add_child(_StatsDivider.new())

	_stats_list = VBoxContainer.new()
	_stats_list.add_theme_constant_override("separation", 6)
	_stats_list.custom_minimum_size = Vector2(0 if tray else 330, 0)
	vbox.add_child(_stats_list)

	# _gift_popup ile AYNI sebep: liste akışının DIŞINDA, kök seviyesinde.
	add_child(_stats_popup)


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= REFRESH_INTERVAL:
		_refresh_timer = 0.0
		_rebuild_rows()
		if _stats_popup and _stats_popup.visible:
			_refresh_stats_popup()
	_update_rows()
## Hediye popup'ı dışına tıklanırsa kapatır - Button'lar kendi tıklamalarını
## zaten GUI input aşamasında tükettiği için (bkz. Godot input akışı), bu
## SADECE popup'ın dışına yapılan tıklamalarda tetiklenir, popup'ı açan
## tıklamayla çakışmaz.
## DÜZELTME (kullanıcı bildirimi: "İstatistikler penceresi kapat tuşuna
## basmamama rağmen başka bişeye basınca kapanıyor") - istatistik popup'ı
## eskiden hediye popup'ıyla AYNI "dışına tıklayınca kapan" davranışını
## paylaşıyordu; artık SADECE kendi Kapat butonuyla (bkz. _hide_stats_popup
## çağıran yerler) kapanıyor.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if _gift_popup and _gift_popup.visible:
		var gift_rect := Rect2(_gift_popup.global_position, _gift_popup.size)
		if not gift_rect.has_point(event.global_position):
			_hide_gift_popup()


func _current_allies() -> Array:
	if not is_inside_tree():
		return []
	var allies: Array = []
	for node in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(node):
			allies.append(node)
	return allies


## Katılan/ayrılan müttefiklere göre satır Node'larını ekler/siler - sadece
## REFRESH_INTERVAL'de bir çağrılır (ucuz olsa da her karede Node.new()/
## queue_free() döngüsüne gerek yok, can/kalkan/isim güncellemesi zaten her
## karede _update_rows() ile ayrı yapılıyor).
func _rebuild_rows() -> void:
	var allies: Array = _current_allies()
	var seen_ids: Dictionary = {}
	for ally in allies:
		var pid: int = int(ally.get("peer_id"))
		if pid <= 0:
			continue
		seen_ids[pid] = true
		if not _rows.has(pid):
			_rows[pid] = _create_row(pid)

	for pid in _rows.keys():
		if not seen_ids.has(pid):
			var row: PartyRow = _rows[pid]
			if row.container and is_instance_valid(row.container):
				row.container.queue_free()
			if _gift_target_peer == pid:
				_hide_gift_popup()
			_rows.erase(pid)

	visible = not _rows.is_empty() and not collapsed and _suppress.is_empty()
	_apply_list_height()
	if not visible:
		_hide_stats_popup()
		_hide_gift_popup()


## Telefonda grup paneli aç/kapa (kullanıcı isteği 2026-10-04, düğme chat'in altında - bkz. hud.gd _fit_mobile_party).
var collapsed: bool = false


func set_collapsed(v: bool) -> void:
	collapsed = v
	_rebuild_rows()


## Gizleme nedenleri (neden -> true). Panel katman 96'da (altın hediyesi için modal ekranların üstünde); kullanıcı (2026-10-19):
## "grup penceresi üstte görünmemeli ayarlar açıkken" -> ayarlar ekranı "settings" ile gizler; telefonda tam ekran pencereler
## (duraklatma, envanter, dükkanlar, level/sandık kartları, oyun bitti) hud.gd'den "phone_modal" ile.
var _suppress: Dictionary = {}


func set_suppressed(reason: String, on: bool) -> void:
	if on == _suppress.has(reason):
		return
	if on:
		_suppress[reason] = true
	else:
		_suppress.erase(reason)
	_rebuild_rows()


func is_suppressed() -> bool:
	return not _suppress.is_empty()


func has_allies() -> bool:
	return not _rows.is_empty()


## Sandık sırası efekti (bkz. chest_pass_fx.gd): bu müttefikin satırının ekrandaki (canvas) ortası; satır yoksa ya da panel
## gizliyse (telefonda kapalı) Vector2.INF.
func get_row_center(peer_id: int) -> Vector2:
	var row: PartyRow = _rows.get(peer_id) as PartyRow
	if row == null or not is_instance_valid(row.container) or not row.container.is_visible_in_tree():
		return Vector2.INF
	return row.container.get_global_transform_with_canvas() * (row.container.size * 0.5)


## Telefon (kullanıcı isteği 2026-10-04: "oyuncu sayısı çok fazla olunca grup paneli küçülmek yerine kaydırılsın"):
## satır listesi en fazla `h` (panel birimi) uzar, fazlası parmakla kaydırılır (touch_scroll.gd). h <= 0: sınırsız (masaüstü).
func set_max_list_height(h: float) -> void:
	_max_list_h = h
	_apply_list_height()


func _apply_list_height() -> void:
	if _list_scroll == null:
		return
	if _max_list_h <= 0.0:
		_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_list_scroll.custom_minimum_size.y = 0.0
		return
	_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_list_scroll.custom_minimum_size.y = minf(_max_list_h, _list.get_combined_minimum_size().y)


## Telefonda "Hasar" düğmesi panelin altında değil, HUD'un üst düğme sırasında (kullanıcı isteği 2026-10-04: "hasar butonu da
## üstte olmalı") - paneldeki kendi düğmesi gizlenir, sıralama penceresi o düğmenin hizasında açılır.
func set_footer_visible(v: bool) -> void:
	if _stats_button and _stats_button.get_parent() is Control:
		(_stats_button.get_parent() as Control).visible = v


## Telefon (madde 273): alt düğmenin yazısı - "Hasar" yerine "İstatistik" (pencere verilen + alınan hasarı gösteriyor).
func set_footer_text(t: String) -> void:
	if _stats_button:
		_stats_button.text = t


## Telefon (madde 273): alt düğme panel genişliğinde (prototipteki tam genişlik ahşap "İstatistik" düğmesi).
func set_footer_full_width(v: bool) -> void:
	if _stats_button:
		_stats_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if v else Control.SIZE_FILL
		_stats_button.custom_minimum_size.y = 40.0 if v else 32.0


func toggle_stats_popup(anchor: Control) -> void:
	if _stats_popup.visible:
		_hide_stats_popup()
		return
	_hide_gift_popup()
	_refresh_stats_popup()
	_stats_popup.visible = true
	_place_stats_popup(anchor)


## Telefon: panelin ve açık pencerelerinin dokunuşu joystick başlatmasın (bkz. touch_controls.gd joy_exclude).
func touch_blocking_controls() -> Array:
	return [get_node_or_null("Background"), _gift_popup, _stats_popup]


func _create_row(peer_id: int) -> PartyRow:
	var row := PartyRow.new()
	row.peer_id = peer_id

	var plaque := PanelContainer.new()
	plaque.custom_minimum_size = Vector2(ROW_WIDTH, 0.0)
	if _tray_ui(): ## madde 483: levha yok (ortak tepsi arkada), içerik payı aynı
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = 14.0
		empty.content_margin_right = 17.0 ## tepsi sağa taşmaz: altın düğmesi çerçeveden 5 px içeride
		empty.content_margin_top = 8.0
		empty.content_margin_bottom = 8.0
		plaque.add_theme_stylebox_override("panel", empty)
	else:
		plaque.add_theme_stylebox_override("panel", _plaque_style(14.0, 8.0))
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(plaque)
	row.container = plaque

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(hbox)

	## Portre: görev okunun kutusuyla aynı koyu çerçeve, içinde HUD avatarının zemini + 1:1 portre.
	var box_size: float = AVATAR_SIZE + AVATAR_BORDER * 2.0
	var avatar_box := Panel.new()
	avatar_box.custom_minimum_size = Vector2(box_size, box_size)
	avatar_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar_border := StyleBoxFlat.new()
	avatar_border.bg_color = BOX_FILL
	avatar_border.border_color = BOX_OUTLINE
	avatar_border.set_border_width_all(int(AVATAR_BORDER))
	avatar_border.anti_aliasing = false
	avatar_box.add_theme_stylebox_override("panel", avatar_border)
	hbox.add_child(avatar_box)
	var avatar_bg := TextureRect.new()
	avatar_bg.texture = AVATAR_BG
	avatar_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_bg.stretch_mode = TextureRect.STRETCH_SCALE
	avatar_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_bg.position = Vector2(AVATAR_BORDER, AVATAR_BORDER)
	avatar_bg.size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar_box.add_child(avatar_bg)
	row.avatar_bg = avatar_bg
	var avatar := TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.clip_contents = true
	avatar.position = Vector2(AVATAR_BORDER, AVATAR_BORDER)
	avatar.size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar_box.add_child(avatar)
	row.avatar = avatar
	if _tray_ui(): ## madde 483: koyu kuyu + paneldeki yuva çerçevesi (portrenin 4 px dışı)
		avatar_border.bg_color = HudTheme.DOCK_INSET
		avatar_border.set_border_width_all(0)
		var av_frame := _TrayOverlay.new()
		av_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av_frame.position = Vector2(AVATAR_BORDER - 4.0, AVATAR_BORDER - 4.0)
		av_frame.size = Vector2(AVATAR_SIZE + 8.0, AVATAR_SIZE + 8.0)
		avatar_box.add_child(av_frame)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info_vbox)

	## 1. satır: isim (taşarsa ...) + durum etiketi (YERDE / ÖLÜ)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(name_row)
	var name_label := Label.new()
	UIKit.style_label(name_label, FS_ROW_TRAY if _tray_ui() else FS_ROW, HudTheme.TEXT, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(name_label)
	row.name_label = name_label
	var downed_label := Label.new()
	downed_label.text = "YERDE"
	UIKit.style_label(downed_label, FS_ROW_TRAY if _tray_ui() else FS_ROW, HudTheme.BAD, 0)
	downed_label.visible = false
	name_row.add_child(downed_label)
	row.downed_label = downed_label

	## 2. satır: görev çubuğuyla aynı gömme çukur; içinde can (kalın) + kalkan (ince) üst üste.
	## 2026-10-10: gömme çukur (inset panel) kalktı - çubuklar karakter üstü çubuklarla aynı kendi çerçeveleriyle çizilir (party_pixel_bar.gd).
	var well := MarginContainer.new()
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	well.mouse_filter = Control.MOUSE_FILTER_PASS ## can değeri ipucu (tooltip) için
	info_vbox.add_child(well)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 0)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(bars)
	if not MobileUIScript.enabled:
		row.health_bar = _make_brass_bar(HP_BAR_HEIGHT, HudTheme.hp_color(1.0), BarKind.HP)
		bars.add_child(row.health_bar)
		row.shield_bar = _make_brass_bar(SHIELD_BAR_HEIGHT, HudTheme.SHIELD_BAR, BarKind.SHIELD)
		bars.add_child(row.shield_bar)
	else:
		row.health_bar = _make_pixel_bar(HP_BAR_HEIGHT, Color(0.12, 0.04, 0.04, 1.0))
		bars.add_child(row.health_bar)
		row.health_label = _add_bar_label(row.health_bar)
		row.shield_bar = _make_pixel_bar(SHIELD_BAR_HEIGHT, Color(0.04, 0.08, 0.14, 1.0))
		row.shield_bar.tint_progress = SHIELD_COLOR
		bars.add_child(row.shield_bar)
		row.shield_label = _add_bar_label(row.shield_bar)

	## Sağda küçük ahşap altın butonu (tıklanınca miktar seçip hediye).
	var gold_button := _wood_button("", Vector2(GOLD_BTN_SIZE, GOLD_BTN_SIZE))
	gold_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gold_button.tooltip_text = "Altın gönder"
	## İkon, boyutu garanti edilen ayrı bir TextureRect olarak butonun ÜSTÜNE (Button.icon tema/sürüme göre çok küçük kalıyordu).
	var gold_icon_applied: bool = false
	if ResourceLoader.exists(GOLD_ICON_PATH):
		var icon_tex: Texture2D = load(GOLD_ICON_PATH) as Texture2D
		if icon_tex:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon_rect.offset_left = 6.0
			icon_rect.offset_top = 6.0
			icon_rect.offset_right = -6.0
			icon_rect.offset_bottom = -6.0
			gold_button.add_child(icon_rect)
			gold_icon_applied = true
	if not gold_icon_applied:
		gold_button.text = "$"
	if _tray_ui(): ## madde 483: 42 px koyu yuva + yuva çerçevesi, altın 16 px x2
		gold_button.custom_minimum_size = Vector2(TRAY_GOLD_BTN, TRAY_GOLD_BTN)
		for st: Array in [["normal", HudTheme.DOCK_INSET], ["hover", HudTheme.DOCK_PLATE_ON], ["pressed", HudTheme.DEEP],
				["hover_pressed", HudTheme.DEEP], ["disabled", HudTheme.DOCK_INSET]]:
			var f := StyleBoxFlat.new()
			f.bg_color = st[1]
			gold_button.add_theme_stylebox_override(st[0], f)
		gold_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		for c in gold_button.get_children():
			if c is TextureRect:
				for side: String in ["offset_left", "offset_top"]:
					c.set(side, 5.0)
				for side2: String in ["offset_right", "offset_bottom"]:
					c.set(side2, -5.0)
		var gb_frame := _TrayOverlay.new()
		gb_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gb_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		gold_button.add_child(gb_frame)
	gold_button.pressed.connect(_on_gold_button_pressed.bind(peer_id))
	## Bu buton _ready()'deki tek seferlik UISound taramasından SONRA yaratıldığı için tık sesi burada elle bağlanır.
	if not gold_button.pressed.is_connected(UISound.play_click):
		gold_button.pressed.connect(UISound.play_click)
	hbox.add_child(gold_button)
	row.gold_button = gold_button
	return row


enum BarKind { HP, SHIELD }

## Madde 479: masaüstü müttefik çubuğu = oyuncu panelinin çubuğu (hud_pixel_bar.gd, ikonsuz birleşik kip).
func _make_brass_bar(height: float, fill: Color, kind: int) -> Control:
	var bar: Control = HudPixelBarScript.new()
	bar.set("merged", true)
	bar.set("fill", fill)
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar


## Satırdaki can / kalkan sayısı (masaüstünde çubuğun kendi yazısı, telefonda etiket) - testler de bunu okur.
static func row_value_text(row: PartyRow, shield: bool) -> String:
	var lbl: Control = row.shield_label if shield else row.health_label
	if lbl != null:
		return str(lbl.get("text"))
	var bar: Control = row.shield_bar if shield else row.health_bar
	return str(bar.get("text")) if bar != null else ""


func _make_pixel_bar(height: float, bg: Color) -> Control:
	var bar: Control = PartyPixelBarScript.new()
	bar.bg_color = bg
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar


## Çubuğun içine ortalanmış piksel-net sayı etiketi (çubuğun çocuğu: çubukla birlikte konumlanır/boyutlanır, fareyi geçirir).
func _add_bar_label(bar: Control) -> Control:
	var lbl: Control = BarValueLabelScript.new()
	lbl.max_font = 24 ## 2026-10-13: ince çubuk - 1,5x yazı
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(lbl)
	return lbl


## Görev ilerleme çubuğuyla (world_event_banner.gd) aynı HUD çubuk dokusu - 9 parçalı, piksel.
func _make_bar(height: float) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.texture_under = BarUnder
	bar.texture_progress = BarFill
	bar.nine_patch_stretch = true
	for m in ["stretch_margin_left", "stretch_margin_right", "stretch_margin_top", "stretch_margin_bottom"]:
		bar.set(m, 2)
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## Ortak tepsi: Background (satırlar) + solda 6 / üstte, altta 3 px (sağ kenar listeyle aynı), satır yoksa gizli.
func _fit_list_tray() -> void:
	if _list_tray == null or not is_instance_valid(_list):
		return
	var any: bool = false
	for c in _list.get_children():
		if c is Control and (c as Control).visible:
			any = true
			break
	_list_tray.visible = any
	if not any:
		return
	var inv: Transform2D = get_global_transform().affine_inverse()
	var bgc: Control = get_node_or_null("Background") as Control
	var r: Rect2 = bgc.get_global_rect() if bgc else _list.get_global_rect()
	var p0: Vector2 = (inv * r.position).round()
	var p1: Vector2 = (inv * r.end).round()
	_list_tray.position = p0 + Vector2(-6.0, -3.0)
	_list_tray.size = (p1 - p0) + Vector2(6.0, 6.0) ## sağ kenar = listenin sağı (minimap çerçevesiyle hizalı)
	_list_tray.queue_redraw()
	_place_stats_tab()


## İstatistik mini düğmesi: minimap çerçevesinin (HUD/MinimapControl/TrayFrame) solunda, alt kenarı çerçevenin altıyla hizalı, 9 px boşluk.
## Çerçeve yoksa tepsinin sol üstünün üstünde. Konum ekran pikselinde (iki katman da ölçeksiz).
func _place_stats_tab() -> void:
	if not (_stats_button is _StatsTab) or not is_instance_valid(_stats_button):
		return
	var hud: Node = get_parent().get_parent() if get_parent() != null else null
	var fr: Control = hud.get_node_or_null("MinimapControl/TrayFrame") as Control if hud != null else null
	var gp: Vector2
	if fr != null and fr.is_visible_in_tree():
		var r: Rect2 = fr.get_global_rect()
		gp = Vector2(r.position.x - 9.0 - TRAY_TAB_SIZE.x, r.end.y - TRAY_TAB_SIZE.y)
	else:
		var tr: Rect2 = _list_tray.get_global_rect()
		gp = Vector2(tr.position.x, tr.position.y - 9.0 - TRAY_TAB_SIZE.y)
	_stats_button.size = TRAY_TAB_SIZE
	_stats_button.global_position = gp.round()


func _update_rows() -> void:
	_fit_list_tray()
	for pid in _rows.keys():
		var row: PartyRow = _rows[pid]
		var ally: Node = _find_ally_node(pid)
		if not ally or not is_instance_valid(ally):
			continue
		_update_row(row, ally)


func _find_ally_node(peer_id: int) -> Node:
	if not is_inside_tree():
		return null
	for node in get_tree().get_nodes_in_group("remote_players"):
		if is_instance_valid(node) and int(node.get("peer_id")) == peer_id:
			return node
	return null


func _update_row(row: PartyRow, ally: Node) -> void:
	var p_name: String = str(ally.get("player_name"))
	if row.name_label.text != p_name:
		row.name_label.text = p_name

	var char_id: int = int(ally.get("char_id"))
	var def: Dictionary = Characters.get_def(char_id)
	var portrait_path: String = def.get("portrait", "")
	if portrait_path != "" and str(row.avatar.get_meta("portrait_path", "")) != portrait_path:
		row.avatar.set_meta("portrait_path", portrait_path)
		if ResourceLoader.exists(portrait_path):
			## Madde 458 (kullanıcı: "karakterlerin yüzleri portrede olsun vücutları değil, grup paneli de dahil") + madde 464: yakın yüz
			## (16x16, Büyücü çerçevesi) avatar kutusunda (48) tam 3 kat + karaktere özel bulanık arka plan aynı katla; yoksa eski 1:1 portre /
			## eski zemin. Tek kaynak PortraitFace (panel portresiyle aynı).
			var face: Texture2D = PortraitFace.face(char_id, PortraitFace.PARTY_N)
			row.avatar.texture = face if face else load(portrait_path)
			row.avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if face else TextureRect.STRETCH_KEEP_CENTERED
			var theme_bg: Texture2D = PortraitFace.background(char_id, PortraitFace.PARTY_N)
			if row.avatar_bg:
				row.avatar_bg.texture = theme_bg if theme_bg else AVATAR_BG

	var health: float = float(ally.get("health"))
	var max_health: float = max(float(ally.get("max_health")), 0.001)
	var pct: float = clampf(health / max_health, 0.0, 1.0)
	## Karakter üstü çubukla aynı yeşil; azaldıkça kırmızıya kayar (hud.gd update_health ile aynı geçiş).
	var tip: String = "%d/%d" % [int(round(maxf(health, 0.0))), int(round(max_health))]
	if row.health_label == null: ## madde 479: masaüstü pirinç kapaklı çubuk (sayı çubuğun içinde, yenilenme yok)
		row.health_bar.call("set_values", pct, HudTheme.hp_color(pct), tip)
	else:
		_set_bar(row.health_bar, pct, HudTheme.hp_color(pct)) ## madde 473: dock ile aynı
	var well: Control = row.health_bar.get_parent().get_parent() as Control
	if well != null and well.tooltip_text != tip:
		well.tooltip_text = tip
	if row.health_label != null and row.health_label.text != tip:
		row.health_label.text = tip

	## Kalkan çubuğu hep görünür (kalkansızken boş) - satır yüksekliği kalkan alınca zıplamasın.
	var shield_max: float = float(ally.get("item_shield_max"))
	var shield_hp: float = float(ally.get("item_shield_hp"))
	var sh_pct: float = clampf(shield_hp / max(shield_max, 0.001), 0.0, 1.0) if shield_max > 0.0 else 0.0
	var sh_tip: String = "%d/%d" % [int(round(maxf(shield_hp, 0.0))), int(round(shield_max))] if shield_max > 0.0 else ""
	if row.shield_label == null:
		row.shield_bar.call("set_values", sh_pct, HudTheme.SHIELD_BAR, sh_tip)
	else:
		_set_bar(row.shield_bar, sh_pct, SHIELD_COLOR)
		if row.shield_label.text != sh_tip:
			row.shield_label.text = sh_tip

	## Ölü/yerde yatan (downed) müttefik: portre griye boyanır ve durum yazısı çıkar (remote_player.gd ile aynı görsel dil).
	var is_dead: bool = bool(ally.get("is_dead"))
	var is_downed: bool = bool(ally.get("is_downed"))
	row.downed_label.visible = is_downed or is_dead
	row.downed_label.text = "ÖLÜ" if is_dead else "YERDE"
	row.gold_button.disabled = is_dead
	if is_dead or is_downed:
		row.avatar.modulate = Color(0.5, 0.5, 0.55, 1.0)
	else:
		row.avatar.modulate = Color(1, 1, 1, 1)


func _set_bar(bar: Control, ratio: float, tint: Color) -> void:
	if not is_equal_approx(bar.value, ratio):
		bar.value = ratio
	if not bar.tint_progress.is_equal_approx(tint):
		bar.tint_progress = tint


## Panel ekranın SAĞINDA - açılır pencereler panelin (arka plan kutusunun) SOLUNA, tetikleyen butonun hizasında açılır:
## ekran dışına taşmaz ve panelin kendi satırlarını örtmez (gerçek oyun görüntüsünde butonun hemen soluna açılınca paneli
## örttüğü görüldü, 2026-09-25).
func _place_popup_left_of(popup: Control, anchor_btn: Control) -> void:
	popup.reset_size()
	var w: float = popup.get_combined_minimum_size().x
	var bg: Control = get_node_or_null("Background") as Control
	var left_x: float = bg.global_position.x if bg != null else anchor_btn.global_position.x
	var x: float = left_x - w - 8.0
	var y: float = anchor_btn.global_position.y - 6.0
	## Madde 491 ek: masaüstünde ortak tepsinin 9 px solu (Hasar Sıralaması gibi) ve altı tepsinin altını geçmez - alt satırdaki dosta açılan
	## altın penceresi aşağıdaki görev satırları / bildirimlerin (katman 100) üstüne sarkmasın.
	if _tray_ui() and _list_tray != null and _list_tray.visible:
		var tr: Rect2 = _list_tray.get_global_rect()
		x = minf(left_x, tr.position.x) - w - 9.0
		y = minf(y, tr.end.y - popup.get_combined_minimum_size().y)
	## Telefonda panel SOL kenarda (bkz. hud.gd _fit_mobile_party) - solda yer yoksa panelin SAĞINA aç.
	if x < 8.0 and bg != null:
		x = bg.get_global_rect().end.x + 8.0
	popup.global_position = Vector2(x, y).round()


## Madde 491: masaüstünde minimap çerçevesinin üst hizası + sağ sütunun (grup tepsisi / Hasar sekmesi) solu; telefon eski yerleşim.
func _place_stats_popup(anchor_btn: Control) -> void:
	if not _tray_ui():
		_place_popup_left_of(_stats_popup, anchor_btn)
		return
	_stats_popup.reset_size()
	var w: float = _stats_popup.get_combined_minimum_size().x
	var right_x: float = INF
	var top_y: float = anchor_btn.global_position.y - 6.0
	for c: Control in [_list_tray, _stats_button]:
		if c != null and is_instance_valid(c) and c.is_visible_in_tree():
			right_x = minf(right_x, c.get_global_rect().position.x)
	var hud: Node = get_parent().get_parent() if get_parent() != null else null
	var fr: Control = hud.get_node_or_null("MinimapControl/TrayFrame") as Control if hud != null else null
	if fr != null and fr.is_visible_in_tree():
		var r: Rect2 = fr.get_global_rect()
		right_x = minf(right_x, r.position.x)
		top_y = r.position.y
	if right_x == INF:
		right_x = anchor_btn.global_position.x
	_stats_popup.global_position = Vector2(right_x - 9.0 - w, top_y).round()


func _on_gold_button_pressed(peer_id: int) -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	var ally: Node = _find_ally_node(peer_id)
	if not ally or not is_instance_valid(ally):
		return
	_hide_stats_popup()
	_gift_target_peer = peer_id
	var target_name: String = str(ally.get("player_name"))
	_gift_amount_label.text = tr("%s'e altın gönder\n(Senin altının: %d)") % [target_name, GameManager.gold]

	var row: PartyRow = _rows.get(peer_id)
	_gift_popup.visible = true
	if row and row.gold_button:
		_place_popup_left_of(_gift_popup, row.gold_button)


func _hide_gift_popup() -> void:
	if _gift_popup:
		_gift_popup.visible = false
	_gift_target_peer = 0


func _on_gift_amount_pressed(amount: int) -> void:
	if _gift_target_peer <= 0:
		_hide_gift_popup()
		return
	## amount == -1 -> "Hepsi" (tüm mevcut altın) - tıklama ANINDA okunuyor,
	## popup açılırken gösterilen değer bayatlamış olabilir diye.
	var send_amount: int = amount if amount > 0 else GameManager.gold
	if send_amount > 0:
		NetworkManager.request_give_gold(_gift_target_peer, send_amount)
	_hide_gift_popup()


func _on_stats_button_pressed() -> void:
	if _stats_popup.visible:
		_hide_stats_popup()
		return
	_hide_gift_popup()
	_refresh_stats_popup()
	_stats_popup.visible = true
	_place_stats_popup(_stats_button)


func _hide_stats_popup() -> void:
	if _stats_popup:
		_stats_popup.visible = false


## Kullanıcı isteği: "istatistiklerin oyun içinde de gözükebilsin" - kendi
## CANLI toplamımız player.gd match_damage_dealt'ten (bkz. orada
## on_damage_dealt notu - hasar verildikçe SÜREKLİ birikiyor), müttefiklerin
## CANLI toplamı main.gd _process_multiplayer_sync "dmg_dealt" alanıyla
## senkronize edilen remote_player.gd match_damage_dealt'ten (bkz. orada).
## Oyun SONU istatistik ekranındaki (main.gd _match_stats_by_peer/
## sync_match_stats) AYRI ve tek seferlik bir mekanizma - bu panel maç DEVAM
## EDERKEN de güncel olmalı olduğu için KARIŞTIRILMAMALI, zaten sürekli akan
## senkron kanalını (extra_state) kullanıyor.
func _gather_live_stats() -> Array:
	var entries: Array = []
	if is_inside_tree():
		var local_player: Node = get_tree().get_first_node_in_group("player")
		if is_instance_valid(local_player) and "match_damage_dealt" in local_player:
			var my_name: String = tr("Sen")
			if NetworkManager.is_multiplayer_active and NetworkManager.local_player_name != "":
				my_name = NetworkManager.local_player_name
			entries.append({"name": my_name, "dealt": float(local_player.get("match_damage_dealt")),
					"taken": float(local_player.get("match_damage_taken")) if "match_damage_taken" in local_player else 0.0,
					"char": GameManager.selected_char_id, "me": true})
		for ally in _current_allies():
			entries.append({"name": str(ally.get("player_name")), "dealt": float(ally.get("match_damage_dealt")),
					"taken": float(ally.get("match_damage_taken")) if "match_damage_taken" in ally else 0.0,
					"char": int(ally.get("char_id")) if "char_id" in ally else 0, "me": false})
	entries.sort_custom(func(a, b): return float(a["dealt"]) > float(b["dealt"]))
	return entries


func _refresh_stats_popup() -> void:
	if not _stats_list:
		return
	for child in _stats_list.get_children():
		_stats_list.remove_child(child) ## hemen çıkar: kuyruktaki eski satırlar bir kare pencereyi büyütmesin
		child.queue_free()
	var entries: Array = _gather_live_stats()
	if _tray_ui():
		_refresh_stats_tray(entries)
		_stats_popup.reset_size() ## oyuncu ayrılınca pencere küçülsün (sol üst sabit)
		return
	if entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Veri yok"
		UIKit.style_label(empty_lbl, FS_ROW, HudTheme.DIM, 0)
		_stats_list.add_child(empty_lbl)
		return
	var top: float = maxf(float(entries[0].get("dealt", 0.0)), 1.0)
	## Sütun başlıkları: verilen + ALINAN hasar (kullanıcı isteği 2026-10-18: "grup istatistiklerinde alınan hasar da olmalı").
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	_stats_list.add_child(head)
	var head_pad := Control.new()
	head_pad.custom_minimum_size = Vector2(30 + 8 + 110, 0)
	head_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_pad)
	for title_text: String in ["Verilen", "Alınan"]:
		var head_lbl := Label.new()
		head_lbl.text = title_text
		head_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head_lbl.custom_minimum_size = Vector2(STAT_COL_W, 0)
		UIKit.style_label(head_lbl, FS_ROW, HudTheme.DIM, 0)
		head.add_child(head_lbl)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 2)
		_stats_list.add_child(block)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		block.add_child(row)

		var rank_lbl := Label.new()
		rank_lbl.text = "%d." % (i + 1)
		rank_lbl.custom_minimum_size = Vector2(30, 0)
		UIKit.style_label(rank_lbl, FS_ROW, HudTheme.ACCENT if i == 0 else HudTheme.DIM, 0)
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("name", "?"))
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.custom_minimum_size = Vector2(110, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.style_label(name_lbl, FS_ROW, HudTheme.TEXT, 0)
		row.add_child(name_lbl)

		var dealt: float = float(entry.get("dealt", 0.0))
		var dmg_lbl := Label.new()
		dmg_lbl.text = "%d" % int(round(dealt))
		dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dmg_lbl.custom_minimum_size = Vector2(STAT_COL_W, 0)
		UIKit.style_label(dmg_lbl, FS_ROW, HudTheme.PRICE, 0)
		row.add_child(dmg_lbl)

		var taken_lbl := Label.new()
		taken_lbl.text = "%d" % int(round(float(entry.get("taken", 0.0))))
		taken_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		taken_lbl.custom_minimum_size = Vector2(STAT_COL_W, 0)
		UIKit.style_label(taken_lbl, FS_ROW, TAKEN_COLOR, 0)
		row.add_child(taken_lbl)

		var well := PanelContainer.new()
		well.add_theme_stylebox_override("panel", UIKit.panel_style("hud_inset_tight"))
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(well)
		var bar: TextureProgressBar = _make_bar(8.0)
		_set_bar(bar, clampf(dealt / top, 0.0, 1.0), DAMAGE_BAR_COLOR)
		well.add_child(bar)


## Madde 491: masaüstü Hasar Sıralaması satırları (Gömme Tepsi dili; düzen için bkz. _StatsClose üstündeki not).
func _refresh_stats_tray(entries: Array) -> void:
	if entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Veri yok"
		UIKit.style_label(empty_lbl, FS_ROW_TRAY, HudTheme.DIM, 0)
		_stats_list.add_child(empty_lbl)
		return
	var top_dealt: float = 1.0
	var top_taken: float = 1.0
	for e: Dictionary in entries:
		top_dealt = maxf(top_dealt, float(e.get("dealt", 0.0)))
		top_taken = maxf(top_taken, float(e.get("taken", 0.0)))
	## Sütun başlıkları (kullanıcı isteği 2026-10-18: "grup istatistiklerinde alınan hasar da olmalı").
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", int(STATS_GAP))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_list.add_child(head)
	var head_pad := Control.new()
	head_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(head_pad)
	for col: Array in [["Verilen", STATS_DEALT_W], ["Alınan", STATS_TAKEN_W]]:
		var head_lbl := Label.new()
		head_lbl.text = str(col[0])
		head_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head_lbl.custom_minimum_size = Vector2(float(col[1]), 0.0)
		UIKit.style_label(head_lbl, FS_ROW_TRAY, HudTheme.DIM, 0)
		head.add_child(head_lbl)
	for i in entries.size():
		if i > 0:
			_stats_list.add_child(_StatsDivider.new())
		var entry: Dictionary = entries[i]
		var me: bool = bool(entry.get("me", false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", int(STATS_GAP))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stats_list.add_child(row)

		var rank_lbl := Label.new()
		rank_lbl.text = "%d." % (i + 1)
		rank_lbl.custom_minimum_size = Vector2(STATS_RANK_W, 0.0)
		rank_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UIKit.style_label(rank_lbl, FS_ROW_TRAY, HudTheme.ACCENT if i == 0 else HudTheme.DIM, 0)
		row.add_child(rank_lbl)

		var portrait: Control = _stats_portrait(int(entry.get("char", 0)))
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(portrait)

		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("name", "?"))
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.custom_minimum_size = Vector2(STATS_NAME_W, 0.0)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UIKit.style_label(name_lbl, FS_ROW_TRAY, HudTheme.ACCENT if me else HudTheme.TEXT, 0)
		row.add_child(name_lbl)

		var dealt: float = float(entry.get("dealt", 0.0))
		var taken: float = float(entry.get("taken", 0.0))
		row.add_child(_stats_cell(dealt, dealt / top_dealt, HudTheme.STAT_DEALT, STATS_DEALT_W))
		row.add_child(_stats_cell(taken, taken / top_taken, HudTheme.STAT_TAKEN, STATS_TAKEN_W))


## Oyun sonu tablosunun hücresi (game_over_board.gd _stat_cell): sağa yaslı sayı (PixeloidSans 18, sütunun renginde) + altında çubuk.
func _stats_cell(v: float, ratio: float, col: Color, w: float) -> Control:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(w, 0.0)
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_theme_constant_override("separation", 6)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = DamageStats.fmt(v)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_override("font", STATS_NUM_FONT)
	UIKit.style_label(lbl, STATS_NUM_FS, col, 0)
	cell.add_child(lbl)
	var bar := _StatsBar.new()
	bar.ratio = clampf(ratio, 0.0, 1.0)
	bar.fill = col
	bar.custom_minimum_size = Vector2(0.0, STATS_BAR_H)
	cell.add_child(bar)
	return cell


## Grup satırının portresiyle aynı: koyu kuyuda karaktere özel bulanık arka plan + yakın yüz (16x16, 3x = 48) + yuva çerçevesi (4 px dışı).
func _stats_portrait(char_id: int) -> Control:
	var box := Control.new()
	box.custom_minimum_size = Vector2(AVATAR_SIZE + 8.0, AVATAR_SIZE + 8.0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var well := ColorRect.new()
	well.color = HudTheme.DOCK_INSET
	well.position = Vector2(4.0, 4.0)
	well.size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(well)
	var face: Texture2D = PortraitFace.face(char_id, PortraitFace.PARTY_N) if char_id > 0 else null
	var bg_tex: Texture2D = PortraitFace.background(char_id, PortraitFace.PARTY_N) if char_id > 0 else null
	for tex: Texture2D in [bg_tex if bg_tex else AVATAR_BG, face]:
		if tex == null:
			continue
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.clip_contents = true
		tr.position = Vector2(4.0, 4.0)
		tr.size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
		box.add_child(tr)
	var frame := _TrayOverlay.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = box.custom_minimum_size
	box.add_child(frame)
	return box
