extends Control

## Ekranın SOL kenarına sabit, klasik MMORPG "party frame" tarzı küçük bir
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


## Kullanıcı isteği (2026-09-24): "grup penceresi çok kötü görünüyor yeniden tasarlanmalı diğer panellere uygun
## okunabilirliği yüksek bir biçimde" - eski panel 216 px genişliğinde, 16 px (1080p'de okunmayan) isimler, 40 px avatar,
## yuvarlak köşeli yumuşak (StyleBoxFlat) 9/6 px çubuklar ve 28 px altın butonuydu. Yeni düzen HUD'un ana can/kalkan
## çubuklarıyla AYNI piksel dokuları (hud_bar_under/hud_bar_fill + renk tonu), 24 px (m5x7 3x) yazı, çerçeveli 48 px
## portre (1:1 piksel), çubuğun içinde "can/maks" yazısı ve 40 px altın butonu kullanır; başlıkta "GRUP" + İstatistik.
## YENİDEN TASARIM (kullanıcı bildirimi 2026-09-25, ekran görüntüsüyle: "grup paneli çok büyük görünüyor, can ve kalkan
## barları çok kalın ve çok yer kaplıyor, yeniden tasarlanması gerekiyor"). Eskiden her müttefik satırı ana HUD'un 44 px'lik
## ikonlu parşömen levhalarından İKİ tane (can + kalkan) + 60 px portre + 40 px altın butonu taşıyordu (satır ~120 px,
## panel 340 px genişlik - 3 müttefikte ekranın sol yarısını kaplıyordu). Artık MMO "party frame" sadeliği: 48 px 1:1 portre,
## isim satırı, altında İNCE can (14 px) ve kalkan (12 px) çubukları, değer yazısı çubuğun içinde küçük (16 px = m5x7 2x,
## keskin). Çubuklar yine ana HUD'la AYNI piksel dokuları (hud_bar_under/hud_bar_fill), AYNI renk dili (can yeşil->kırmızı,
## kalkan mavi) ve %10 çentikler - sadece çerçevesiz ve ince. Satır ~60 px, panel 280 px.
const PANEL_WIDTH := 280.0
const AVATAR_SIZE := 48.0 ## portre PNG'leri 48x48 - 1:1 çizilir (bulanık/yamuk ölçek yok)
const AVATAR_BOX := 52.0
const GOLD_BTN_SIZE := 32.0
const HP_BAR_HEIGHT := 14.0
const SHIELD_BAR_HEIGHT := 12.0
const BAR_TICK_COUNT := 10
const BAR_VALUE_FONT_SIZE := 16
const FS_ROW := 24
const GOLD_ICON_PATH := "res://assets/ui/newui/icon_ingot.png"
const BAR_UNDER := preload("res://assets/ui/kit/hud_bar_under.png")
const BAR_FILL := preload("res://assets/ui/kit/hud_bar_fill.png")
const AVATAR_BG := preload("res://assets/ui/kit/hud_avatar_bg.png")
const AVATAR_FRAME := preload("res://assets/ui/kit/hud_skill_frame_small.png")
const SHIELD_TINT := Color(0.24, 0.59, 0.91) ## hud.gd item_shield_bar ile AYNI

## Kim ne zaman katıldı/ayrıldı diye satırların Node'larını her karede değil,
## bu aralıkta bir kontrol ediyoruz (satır içeriği - can/kalkan/isim/durum -
## yine de her karede güncelleniyor, bkz. _process/_update_rows).
const REFRESH_INTERVAL := 0.5

## Tek bir satırın Control referanslarını bir arada tutan basit yardımcı.
class PartyRow:
	var container: PanelContainer
	var avatar: TextureRect
	var name_label: Label
	var health_bar: TextureProgressBar
	var health_label: Label
	var shield_bar: TextureProgressBar
	var shield_root: Control
	var shield_label: Label
	var gold_button: Button
	var downed_label: Label
	var peer_id: int = 0

var _rows: Dictionary = {} ## peer_id(int) -> PartyRow
var _list: VBoxContainer = null
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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 14.0
	## Kullanıcı isteği: "grup panelini biraz aşağı kaydır" - eski 120.0
	## değeri sol üstteki can/kalkan/avatar kümesine (CharacterCluster,
	## bkz. hud.gd) fazla yakındı, aşağı çekildi.
	## DÜZELTME (kullanıcı bildirimi: "revive haklarının göründüğü kalpler
	## grup paneli yüzünden görünmüyor") - 156.0 hala hud.tscn'deki
	## ReviveHearts kutusuyla (offset_top=160, offset_bottom=196) çakışıyordu,
	## bu panel ReviveHearts'ın altında ilk sıra Control'ü olarak ÜSTÜNE
	## çiziliyordu. ReviveHearts'ın alt sınırının (196) yeterince altına
	## çekildi.
	offset_top = 205.0
	visible = false
	_build_static_ui()
	_rebuild_rows()
	## DÜZELTME (kullanıcı isteği: "Button resmini oyunumdaki tüm butonlarla
	## değiştir") - bu panel (altın hediye popup'ındaki miktar/iptal
	## butonları) hiç UISound çağırmıyordu. NOT: bu tarama sadece _ready()
	## anında VAR OLAN butonları (gift popup) kapsar - _rebuild_rows()
	## sonradan yeni müttefik katıldıkça çağrılıp YENİ gold_button'lar
	## yarattığı için o buton kendi oluşturulduğu yerde (_create_row) AYRICA
	## ve elle stilleniyor (bkz. orası).
	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self)


func _build_static_ui() -> void:
	theme = UIKit.theme()
	var bg := PanelContainer.new()
	bg.name = "Background"
	bg.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	## Kullanıcı isteği (2026-09-24): oyun içi arayüzler menülerle aynı bej/ahşap kite geçti - küçük ahşap pencere + koyu yazı.
	bg.add_theme_stylebox_override("panel", UIKit.panel_style("window_small"))
	add_child(bg)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 6)
	bg.add_child(_list)
	## Başlık satırı: "GRUP" (kiremit başlık rengi) + sağda İstatistik butonu.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_list.add_child(header)
	var title := Label.new()
	title.text = "GRUP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(title, FS_ROW, UIKit.C_ACCENT, 0)
	var title_pad := MarginContainer.new()
	title_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_pad.add_theme_constant_override("margin_left", 8)
	title_pad.add_child(title)
	header.add_child(title_pad)

	## Kullanıcı isteği: "grup penceresinde bir buton olacak" - _list zaten
	## TEK VBoxContainer (satırların üstüne serbestçe eklenebilir,
	## _rebuild_rows() SADECE kendi PartyRow.container'larını ekler/siler,
	## başka çocuklara dokunmaz), bu yüzden buton en üste onun içine ekleniyor.
	_stats_button = Button.new()
	_stats_button.text = "İstatistik"
	_stats_button.custom_minimum_size = Vector2(0, 30) ## 2026-09-25 sadeleştirme: 36 -> 30
	## DÜZELTME (kullanıcı bildirimi: "grup paneli çok genişledi... istatistikler
	## butonu eklediğin için yanlışlıkla genişletmişsin") - bu butonun font_size
	## override'ı hiç yoktu, yani proje varsayılan temasının (theme.tres)
	## default_font_size=88'ini miras alıyordu - "İstatistik" metni 88px'te
	## panelin PANEL_WIDTH'ini (216) çok aşan bir minimum genişlik dayatıyordu,
	## bu yüzden TÜM panel genişlemiş görünüyordu. PANEL_WIDTH'in kendisi hiç
	## değişmemişti, sadece bu eksik override sorunun asıl kaynağıydı.
	## DÜZELTME (kullanıcı bildirimi: "istatistikler yazısı çok zor okunuyor") -
	## 16'dan 20'ye büyütüldü, buton yüksekliği de (26->32) buna uyacak şekilde arttı.
	_stats_button.add_theme_font_size_override("font_size", FS_ROW)
	_stats_button.tooltip_text = "Kimin ne kadar hasar verdiğini göster"
	_stats_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_stats_button.pressed.connect(_on_stats_button_pressed)
	ShopPanel._apply_mini_wood_button_style(_stats_button)
	header.add_child(_stats_button)

	_build_gift_popup()
	_build_stats_popup()


func _build_gift_popup() -> void:
	_gift_popup = PanelContainer.new()
	_gift_popup.name = "GiftPopup"
	_gift_popup.visible = false
	_gift_popup.z_index = 100
	_gift_popup.add_theme_stylebox_override("panel", UIKit.panel_style("window_small"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_gift_popup.add_child(vbox)

	_gift_amount_label = Label.new()
	UIKit.style_label(_gift_amount_label, 16, UIKit.C_ACCENT, 0)
	_gift_amount_label.text = "Altın gönder"
	vbox.add_child(_gift_amount_label)

	var presets_box := HBoxContainer.new()
	presets_box.add_theme_constant_override("separation", 4)
	vbox.add_child(presets_box)
	## DÜZELTME: bu butonların da (aşağı bkz. _stats_button üstündeki not ile
	## AYNI kök neden) font_size override'ı yoktu, tema varsayılanı (88px)
	## miras alıp devasa/taşan görünüyorlardı.
	for amount in [10, 50, 100]:
		var btn := Button.new()
		btn.text = str(amount)
		btn.custom_minimum_size = Vector2(44, 30)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_gift_amount_pressed.bind(amount))
		presets_box.add_child(btn)
	var all_btn := Button.new()
	all_btn.text = "Hepsi"
	all_btn.custom_minimum_size = Vector2(50, 30)
	all_btn.add_theme_font_size_override("font_size", 16)
	all_btn.pressed.connect(_on_gift_amount_pressed.bind(-1))
	presets_box.add_child(all_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "İptal"
	cancel_btn.add_theme_font_size_override("font_size", 16)
	cancel_btn.pressed.connect(_hide_gift_popup)
	vbox.add_child(cancel_btn)

	# Liste akışının (VBoxContainer) DIŞINDA, kök seviyesinde - böylece
	# satırların üstünde serbestçe konumlandırılıp en üstte çizilebiliyor.
	add_child(_gift_popup)


## Kullanıcı isteği: "grup penceresinde bir buton olacak o butondan minik bir
## panel açılıp kimin ne kadar vurduğu gösterilecek" - _gift_popup ile AYNI
## görsel dil/desen (bkz. yukarısı), sadece içeriği bir sıralama listesi.
func _build_stats_popup() -> void:
	_stats_popup = PanelContainer.new()
	_stats_popup.name = "StatsPopup"
	_stats_popup.visible = false
	_stats_popup.z_index = 100
	_stats_popup.add_theme_stylebox_override("panel", UIKit.panel_style("window_small"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_stats_popup.add_child(vbox)

	## DÜZELTME (kullanıcı bildirimi: "istatistikler butonuna tıklayınca açılan
	## paneli de biraz büyüt o da çok zor okunuyor ve ufacık") - başlık/satır
	## font boyutları ve listenin minimum genişliği büyütüldü (bkz. aşağıdaki
	## _refresh_stats_popup'taki satır etiketleri - AYNI oranda büyütüldü).
	var title := Label.new()
	title.text = "Hasar Sıralaması"
	UIKit.style_label(title, 24, UIKit.C_ACCENT, 0)
	vbox.add_child(title)

	_stats_list = VBoxContainer.new()
	_stats_list.add_theme_constant_override("separation", 5)
	_stats_list.custom_minimum_size = Vector2(240, 0)
	vbox.add_child(_stats_list)

	var close_btn := Button.new()
	close_btn.text = "Kapat"
	close_btn.custom_minimum_size = Vector2(0, 30)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(_hide_stats_popup)
	ShopPanel._apply_mini_wood_button_style(close_btn)
	vbox.add_child(close_btn)

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

	visible = not _rows.is_empty()
	if not visible:
		_hide_stats_popup()


func _create_row(peer_id: int) -> PartyRow:
	var row := PartyRow.new()
	row.peer_id = peer_id

	var container := PanelContainer.new()
	container.add_theme_stylebox_override("panel", UIKit.panel_style("inset_tight"))
	_list.add_child(container)
	row.container = container

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	container.add_child(hbox)

	## Portre: HUD avatar zemini + 1:1 portre + küçük yetenek çerçevesi (9-patch, köşeler ölçeklenmez).
	var avatar_box := Control.new()
	avatar_box.custom_minimum_size = Vector2(AVATAR_BOX, AVATAR_BOX)
	avatar_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(avatar_box)
	var avatar_bg := TextureRect.new()
	avatar_bg.texture = AVATAR_BG
	avatar_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_bg.stretch_mode = TextureRect.STRETCH_SCALE
	avatar_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar_bg.position = Vector2(2, 2)
	avatar_bg.size = Vector2(AVATAR_BOX - 4.0, AVATAR_BOX - 4.0)
	avatar_box.add_child(avatar_bg)
	var avatar := TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.position = Vector2((AVATAR_BOX - AVATAR_SIZE) * 0.5, (AVATAR_BOX - AVATAR_SIZE) * 0.5)
	avatar.size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar_box.add_child(avatar)
	row.avatar = avatar
	var frame := NinePatchRect.new()
	frame.texture = AVATAR_FRAME
	frame.patch_margin_left = 8
	frame.patch_margin_top = 8
	frame.patch_margin_right = 8
	frame.patch_margin_bottom = 8
	frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = Vector2(AVATAR_BOX, AVATAR_BOX)
	avatar_box.add_child(frame)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vbox)

	## 1. satır: isim (taşarsa ...) + durum etiketi (YERDE / ÖLÜ)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	info_vbox.add_child(name_row)
	var name_label := Label.new()
	UIKit.style_label(name_label, FS_ROW, UIKit.C_TEXT, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(name_label)
	row.name_label = name_label
	var downed_label := Label.new()
	downed_label.text = "YERDE"
	UIKit.style_label(downed_label, FS_ROW, UIKit.C_BAD, 0)
	downed_label.visible = false
	name_row.add_child(downed_label)
	row.downed_label = downed_label

	## 2-3. satır: ince can ve kalkan çubukları (bkz. PANEL_WIDTH üstündeki yeniden tasarım notu), içinde "değer/maks".
	var hp_parts: Array = _make_slim_bar(HP_BAR_HEIGHT)
	info_vbox.add_child(hp_parts[0])
	row.health_bar = hp_parts[1]
	row.health_label = hp_parts[2]
	var sh_parts: Array = _make_slim_bar(SHIELD_BAR_HEIGHT)
	info_vbox.add_child(sh_parts[0])
	row.shield_root = sh_parts[0]
	row.shield_bar = sh_parts[1]
	row.shield_label = sh_parts[2]
	row.shield_bar.tint_progress = SHIELD_TINT

	var gold_button := Button.new()
	gold_button.custom_minimum_size = Vector2(GOLD_BTN_SIZE, GOLD_BTN_SIZE)
	gold_button.tooltip_text = "Altın gönder"
	gold_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	## DÜZELTME (kullanıcı isteği: "altın verme butonuna altın ikonu
	## eklensin"): eskiden Button.icon + expand_icon'a güveniliyordu - ikon
	## dosyası (icon_ingot.png) gerçekten var ama Button'ın kendi ikon
	## çizimi (tema/sürüme göre) çok küçük/belirsiz kalabiliyordu, kullanıcı
	## hiç ikon yokmuş gibi algılıyordu. Artık avatar TextureRect'iyle
	## (bkz. yukarısı) AYNI güvenilir desen kullanılıyor - ikon, boyutu
	## garanti edilen ayrı bir TextureRect olarak butonun ÜSTÜNE ekleniyor,
	## böylece görünürlüğü motor/tema davranışına bağlı kalmıyor.
	gold_button.text = ""
	var gold_icon_applied: bool = false
	if ResourceLoader.exists(GOLD_ICON_PATH):
		var icon_tex: Texture2D = load(GOLD_ICON_PATH) as Texture2D
		if icon_tex:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			const GOLD_ICON_INSET := 4.0
			icon_rect.offset_left = GOLD_ICON_INSET
			icon_rect.offset_top = GOLD_ICON_INSET
			icon_rect.offset_right = -GOLD_ICON_INSET
			icon_rect.offset_bottom = -GOLD_ICON_INSET
			gold_button.add_child(icon_rect)
			gold_icon_applied = true
	if not gold_icon_applied:
		gold_button.text = "$"
	gold_button.pressed.connect(_on_gold_button_pressed.bind(peer_id))
	## Bu buton _ready()'deki tek seferlik UISound taramasından SONRA (yeni
	## bir müttefik katıldığında _rebuild_rows() ile) oluşturulduğu için o
	## taramadan hiç geçmiyor - kare/ikon butonu olduğu için zaten genel
	## taramadan atlanırdı (bkz. ui_sound.gd _looks_like_icon_slot), bu
	## yüzden burada elle KARE mini ahşap stil + tık sesi uygulanıyor (aynı
	## desen: hud.gd'deki shield_mode_slots).
	if not gold_button.pressed.is_connected(UISound.play_click):
		gold_button.pressed.connect(UISound.play_click)
	ShopPanel._apply_mini_wood_button_style(gold_button)
	gold_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(gold_button)
	row.gold_button = gold_button

	return row


## İnce çubuk: [kök Control, TextureProgressBar, değer Label]. Ana HUD'la aynı dolgu dokuları + %10 çentikler, çerçevesiz
## (bkz. PANEL_WIDTH üstündeki yeniden tasarım notu). Yazı çubuğun ortasında, koyu konturla her renkte okunur.
func _make_slim_bar(height: float) -> Array:
	var root := Control.new()
	root.custom_minimum_size = Vector2(0.0, height)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar: TextureProgressBar = _make_bar(height)
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bar)
	var ticks := Control.new()
	ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.add_child(ticks)
	ticks.draw.connect(func() -> void:
		for t in range(1, BAR_TICK_COUNT):
			var x: float = round(ticks.size.x * float(t) / float(BAR_TICK_COUNT) * 0.5) * 2.0
			ticks.draw_rect(Rect2(x - 1.0, 2.0, 2.0, maxf(ticks.size.y - 4.0, 1.0)), Color(0.12, 0.06, 0.02, 0.3)))
	ticks.resized.connect(ticks.queue_redraw)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.offset_top = -3.0
	lbl.offset_bottom = 3.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", BAR_VALUE_FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)
	return [root, bar, lbl]


## HUD'un ana can/kalkan çubuğuyla aynı dokular (9-patch esnetme) - ton update'te verilir.
func _make_bar(height: float) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.texture_under = BAR_UNDER
	bar.texture_progress = BAR_FILL
	bar.nine_patch_stretch = true
	bar.stretch_margin_left = 2
	bar.stretch_margin_right = 2
	bar.stretch_margin_top = 2
	bar.stretch_margin_bottom = 2
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.custom_minimum_size = Vector2(0, height)
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _update_rows() -> void:
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
			row.avatar.texture = load(portrait_path)

	var health: float = float(ally.get("health"))
	var max_health: float = max(float(ally.get("max_health")), 0.001)
	var pct: float = clampf(health / max_health, 0.0, 1.0)
	row.health_bar.value = pct
	## hud.gd update_health ile AYNI yeşil -> kırmızı geçiş
	row.health_bar.tint_progress = Color(0.84, 0.22, 0.22).lerp(Color(0.36, 0.78, 0.29), pct)
	var hp_text: String = "%d/%d" % [int(round(maxf(health, 0.0))), int(round(max_health))]
	if row.health_label.text != hp_text:
		row.health_label.text = hp_text

	## Kalkan levhası ana HUD'daki gibi HEP görünür (kalkansızken "0/0", boş) - satır yüksekliği kalkan alınca zıplamasın.
	var shield_max: float = float(ally.get("item_shield_max"))
	var shield_hp: float = float(ally.get("item_shield_hp"))
	row.shield_bar.value = clampf(shield_hp / max(shield_max, 0.001), 0.0, 1.0) if shield_max > 0.0 else 0.0
	var sh_text: String = "%d/%d" % [int(round(maxf(shield_hp, 0.0))), int(round(maxf(shield_max, 0.0)))]
	if row.shield_label.text != sh_text:
		row.shield_label.text = sh_text

	## Ölü/yerde yatan (downed) müttefik: eski can değeri donmuş gibi
	## görünmesin diye avatar griye boyanır ve "İNDİRİLDİ" yazısı çıkar -
	## remote_player.gd'nin downed karakteri boyaması (Color(0.5,0.5,0.55))
	## ile aynı görsel dil (bkz. update_extra_state_from_net).
	var is_dead: bool = bool(ally.get("is_dead"))
	var is_downed: bool = bool(ally.get("is_downed"))
	row.downed_label.visible = is_downed or is_dead
	row.downed_label.text = "ÖLÜ" if is_dead else "YERDE"
	row.gold_button.disabled = is_dead
	if is_dead or is_downed:
		row.avatar.modulate = Color(0.5, 0.5, 0.55, 1.0)
	else:
		row.avatar.modulate = Color(1, 1, 1, 1)


func _on_gold_button_pressed(peer_id: int) -> void:
	if not NetworkManager.is_multiplayer_active:
		return
	var ally: Node = _find_ally_node(peer_id)
	if not ally or not is_instance_valid(ally):
		return
	_hide_stats_popup()
	_gift_target_peer = peer_id
	var target_name: String = str(ally.get("player_name"))
	_gift_amount_label.text = "%s'e altın gönder\n(Senin altının: %d)" % [target_name, GameManager.gold]

	var row: PartyRow = _rows.get(peer_id)
	_gift_popup.visible = true
	if row and row.gold_button:
		var btn_pos: Vector2 = row.gold_button.global_position
		_gift_popup.global_position = btn_pos + Vector2(row.gold_button.size.x + 6.0, -10.0)


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
	_stats_popup.global_position = _stats_button.global_position + Vector2(_stats_button.size.x + 6.0, -10.0)


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
			var my_name: String = "Sen"
			if NetworkManager.is_multiplayer_active and NetworkManager.local_player_name != "":
				my_name = NetworkManager.local_player_name
			entries.append({"name": my_name, "dealt": float(local_player.get("match_damage_dealt"))})
		for ally in _current_allies():
			entries.append({"name": str(ally.get("player_name")), "dealt": float(ally.get("match_damage_dealt"))})
	entries.sort_custom(func(a, b): return float(a["dealt"]) > float(b["dealt"]))
	return entries


func _refresh_stats_popup() -> void:
	if not _stats_list:
		return
	for child in _stats_list.get_children():
		child.queue_free()
	var entries: Array = _gather_live_stats()
	if entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Veri yok"
		UIKit.style_label(empty_lbl, 16, UIKit.C_TEXT_DIM, 0)
		_stats_list.add_child(empty_lbl)
		return
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_stats_list.add_child(row)

		var rank_lbl := Label.new()
		rank_lbl.text = "%d." % (i + 1)
		rank_lbl.custom_minimum_size = Vector2(24, 0)
		UIKit.style_label(rank_lbl, 16, UIKit.C_ACCENT if i == 0 else UIKit.C_TEXT_DIM, 0)
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("name", "?"))
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size = Vector2(120, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.style_label(name_lbl, 16, UIKit.C_TEXT, 0)
		row.add_child(name_lbl)

		var dmg_lbl := Label.new()
		dmg_lbl.text = "%d" % int(round(float(entry.get("dealt", 0.0))))
		dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dmg_lbl.custom_minimum_size = Vector2(58, 0)
		UIKit.style_label(dmg_lbl, 16, Color(UIKit.INK["damage"]), 0)
		row.add_child(dmg_lbl)
