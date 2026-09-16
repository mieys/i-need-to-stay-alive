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

const PAL_WINDOW_BG := Color(0.47, 0.39, 0.23, 1.0)
const PAL_WINDOW_BORDER := Color(0.25, 0.15, 0.08, 1.0)
const PAL_ACCENT := Color(0.83, 0.56, 0.30, 1.0)

const ROW_HEIGHT := 56.0
const PANEL_WIDTH := 216.0
const AVATAR_SIZE := 40.0
const GOLD_BTN_SIZE := 28.0
const GOLD_ICON_PATH := "res://assets/ui/newui/icon_ingot.png"
const PARTY_BAR_SCRIPT := preload("res://scripts/party_bar.gd")

## Kim ne zaman katıldı/ayrıldı diye satırların Node'larını her karede değil,
## bu aralıkta bir kontrol ediyoruz (satır içeriği - can/kalkan/isim/durum -
## yine de her karede güncelleniyor, bkz. _process/_update_rows).
const REFRESH_INTERVAL := 0.5

## Tek bir satırın Control referanslarını bir arada tutan basit yardımcı.
class PartyRow:
	var container: PanelContainer
	var avatar: TextureRect
	var name_label: Label
	var health_bar: Control
	var shield_bar: Control
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
	var bg := PanelContainer.new()
	bg.name = "Background"
	bg.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PAL_WINDOW_BG
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = PAL_WINDOW_BORDER
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 6)
	bg.add_child(_list)

	## Kullanıcı isteği: "grup penceresinde bir buton olacak" - _list zaten
	## TEK VBoxContainer (satırların üstüne serbestçe eklenebilir,
	## _rebuild_rows() SADECE kendi PartyRow.container'larını ekler/siler,
	## başka çocuklara dokunmaz), bu yüzden buton en üste onun içine ekleniyor.
	_stats_button = Button.new()
	_stats_button.text = "İstatistik"
	_stats_button.custom_minimum_size = Vector2(0, 32)
	## DÜZELTME (kullanıcı bildirimi: "grup paneli çok genişledi... istatistikler
	## butonu eklediğin için yanlışlıkla genişletmişsin") - bu butonun font_size
	## override'ı hiç yoktu, yani proje varsayılan temasının (theme.tres)
	## default_font_size=88'ini miras alıyordu - "İstatistik" metni 88px'te
	## panelin PANEL_WIDTH'ini (216) çok aşan bir minimum genişlik dayatıyordu,
	## bu yüzden TÜM panel genişlemiş görünüyordu. PANEL_WIDTH'in kendisi hiç
	## değişmemişti, sadece bu eksik override sorunun asıl kaynağıydı.
	## DÜZELTME (kullanıcı bildirimi: "istatistikler yazısı çok zor okunuyor") -
	## 16'dan 20'ye büyütüldü, buton yüksekliği de (26->32) buna uyacak şekilde arttı.
	_stats_button.add_theme_font_size_override("font_size", 20)
	_stats_button.tooltip_text = "Kimin ne kadar hasar verdiğini göster"
	_stats_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_stats_button.pressed.connect(_on_stats_button_pressed)
	ShopPanel._apply_mini_wood_button_style(_stats_button)
	_list.add_child(_stats_button)

	_build_gift_popup()
	_build_stats_popup()


func _build_gift_popup() -> void:
	_gift_popup = PanelContainer.new()
	_gift_popup.name = "GiftPopup"
	_gift_popup.visible = false
	_gift_popup.z_index = 100
	var style := StyleBoxFlat.new()
	style.bg_color = PAL_WINDOW_BG
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = PAL_ACCENT
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_gift_popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_gift_popup.add_child(vbox)

	_gift_amount_label = Label.new()
	_gift_amount_label.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	_gift_amount_label.add_theme_font_size_override("font_size", 14)
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
	var style := StyleBoxFlat.new()
	style.bg_color = PAL_WINDOW_BG
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = PAL_ACCENT
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_stats_popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_stats_popup.add_child(vbox)

	## DÜZELTME (kullanıcı bildirimi: "istatistikler butonuna tıklayınca açılan
	## paneli de biraz büyüt o da çok zor okunuyor ve ufacık") - başlık/satır
	## font boyutları ve listenin minimum genişliği büyütüldü (bkz. aşağıdaki
	## _refresh_stats_popup'taki satır etiketleri - AYNI oranda büyütüldü).
	var title := Label.new()
	title.text = "Hasar Sıralaması"
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	title.add_theme_font_size_override("font_size", 18)
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
	container.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0, 0, 0, 0.25)
	row_style.set_corner_radius_all(6)
	row_style.content_margin_left = 4
	row_style.content_margin_right = 4
	row_style.content_margin_top = 4
	row_style.content_margin_bottom = 4
	container.add_theme_stylebox_override("panel", row_style)
	_list.add_child(container)
	row.container = container

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	container.add_child(hbox)

	var avatar_clip := Control.new()
	avatar_clip.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar_clip.clip_contents = true
	hbox.add_child(avatar_clip)
	var avatar := TextureRect.new()
	avatar.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar_clip.add_child(avatar)
	row.avatar = avatar

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.clip_text = true
	info_vbox.add_child(name_label)
	row.name_label = name_label

	var health_bar := Control.new()
	health_bar.set_script(PARTY_BAR_SCRIPT)
	health_bar.custom_minimum_size = Vector2(0, 9)
	health_bar.set_colors(Color(0.30, 0.82, 0.24, 1.0), Color(0.12, 0.04, 0.04, 1.0))
	info_vbox.add_child(health_bar)
	row.health_bar = health_bar

	var shield_bar := Control.new()
	shield_bar.set_script(PARTY_BAR_SCRIPT)
	shield_bar.custom_minimum_size = Vector2(0, 6)
	shield_bar.set_colors(Color(0.35, 0.72, 1.0, 1.0), Color(0.04, 0.08, 0.14, 1.0))
	info_vbox.add_child(shield_bar)
	row.shield_bar = shield_bar

	var downed_label := Label.new()
	downed_label.text = "İNDİRİLDİ"
	downed_label.add_theme_font_size_override("font_size", 11)
	downed_label.add_theme_color_override("font_color", Color(0.85, 0.3, 0.3))
	downed_label.visible = false
	info_vbox.add_child(downed_label)
	row.downed_label = downed_label

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
	hbox.add_child(gold_button)
	row.gold_button = gold_button

	return row


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
	row.health_bar.set_ratio(health / max_health)

	var shield_max: float = float(ally.get("item_shield_max"))
	row.shield_bar.visible = shield_max > 0.0
	if shield_max > 0.0:
		var shield_hp: float = float(ally.get("item_shield_hp"))
		row.shield_bar.set_ratio(shield_hp / max(shield_max, 0.001))

	## Ölü/yerde yatan (downed) müttefik: eski can değeri donmuş gibi
	## görünmesin diye avatar griye boyanır ve "İNDİRİLDİ" yazısı çıkar -
	## remote_player.gd'nin downed karakteri boyaması (Color(0.5,0.5,0.55))
	## ile aynı görsel dil (bkz. update_extra_state_from_net).
	var is_dead: bool = bool(ally.get("is_dead"))
	var is_downed: bool = bool(ally.get("is_downed"))
	row.downed_label.visible = is_downed and not is_dead
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
		empty_lbl.add_theme_font_size_override("font_size", 16)
		empty_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
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
		rank_lbl.add_theme_font_size_override("font_size", 16)
		rank_lbl.add_theme_color_override("font_color", Color(0.83, 0.56, 0.30) if i == 0 else Color(0.8, 0.8, 0.75))
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("name", "?"))
		name_lbl.clip_text = true
		name_lbl.custom_minimum_size = Vector2(120, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		row.add_child(name_lbl)

		var dmg_lbl := Label.new()
		dmg_lbl.text = "%d" % int(round(float(entry.get("dealt", 0.0))))
		dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dmg_lbl.custom_minimum_size = Vector2(58, 0)
		dmg_lbl.add_theme_font_size_override("font_size", 16)
		dmg_lbl.add_theme_color_override("font_color", Color(1, 0.55, 0.35))
		row.add_child(dmg_lbl)
