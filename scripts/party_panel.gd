extends Control

## (2026-09-25: artık SAĞ üstte, minimapın altında - bkz. RIGHT_MARGIN.) Klasik MMORPG "party frame" tarzı küçük bir
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


## YENİDEN TASARIM (kullanıcı isteği 2026-09-25): "grup paneli daha basit görünmeli aynı şekilde orda da kenarlıkların daha
## iyi olması gerekiyor can kalkan barları tıpkı karakterin üstündeki can kalkan barına benzer olmalı gereksiz yer
## kaplamaması gereksiz ayrıntılı olmaması için (genişliği buna uygun olmalı)" + "grup panelindeki hasar tablosunun da daha
## minimalist ve diğer panellerle uyumlu tasarlanması gerekiyor" + "grup paneli de sağda olsun" (minimapın altında).
## Eskiden: ahşap pencere + her satırda çukur parşömen kutu + ahşap çerçeveli portre + %10 çentikli parşömen çubuklar +
## çubuk içinde "can/maks" yazısı + ahşap butonlar (panel 280 px). Artık: tek sade koyu kutu (UIKit "hud_flat"), satırlar
## çerçevesiz; 48 px 1:1 portre (ince kenar), isim, altında karakter ÜSTÜNDEKİ çubuğun birebir aynısı (ui_mini_bar.gd ->
## overhead_bar.gd draw_pixel_bar) can + kalkan, küçük sade altın butonu. Panel ~254 px. Açılır pencereler panel sağda
## olduğu için artık SOLA açılır.
const PANEL_WIDTH := 238.0
const AVATAR_SIZE := 48.0 ## portre PNG'leri 48x48 - 1:1 çizilir (bulanık/yamuk ölçek yok)
const AVATAR_BOX := 52.0
const GOLD_BTN_SIZE := 26.0
## Karakter üstü çubuğun oranları (overhead_bar.gd HEIGHT 7 / kalkan x0.72) ekran ölçeğinde (1 dünya birimi = 2 px).
const HP_BAR_HEIGHT := 18.0
const SHIELD_BAR_HEIGHT := 14.0
const FS_ROW := 16 ## m5x7 2x - keskin
## Sağ üstteki minimap'in (hud.tscn MinimapControl: sağdan 36, alt kenar 186) hemen altı.
const RIGHT_MARGIN := 36.0
const TOP_Y := 198.0
const GOLD_ICON_PATH := "res://assets/ui/newui/icon_ingot.png"
const AVATAR_BG := preload("res://assets/ui/kit/hud_avatar_bg.png")
const MiniBarScript := preload("res://scripts/ui_mini_bar.gd")
const SHIELD_COLOR := Color(0.35, 0.72, 1.0, 1.0) ## overhead_bar.gd kalkan rengi ile AYNI
const HP_BG := Color(0.12, 0.04, 0.04, 1.0)
const SHIELD_BG := Color(0.04, 0.08, 0.14, 1.0)
const DAMAGE_BAR_COLOR := Color(1.0, 0.6, 0.28, 1.0)

## Kim ne zaman katıldı/ayrıldı diye satırların Node'larını her karede değil,
## bu aralıkta bir kontrol ediyoruz (satır içeriği - can/kalkan/isim/durum -
## yine de her karede güncelleniyor, bkz. _process/_update_rows).
const REFRESH_INTERVAL := 0.5

## Tek bir satırın Control referanslarını bir arada tutan basit yardımcı.
class PartyRow:
	var container: Control
	var avatar: TextureRect
	var name_label: Label
	var health_bar: Control ## ui_mini_bar.gd
	var shield_bar: Control ## ui_mini_bar.gd
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
	## Sağ üst, minimapın altı (bkz. RIGHT_MARGIN/TOP_Y). Kök sıfır genişlikte sağ kenara yapışık; arka plan kutusu
	## (Background) sağdan SOLA doğru büyür - içerik genişlese de ekran dışına taşmaz.
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -RIGHT_MARGIN
	offset_right = -RIGHT_MARGIN
	offset_top = TOP_Y
	offset_bottom = TOP_Y
	visible = false
	_build_static_ui()
	_rebuild_rows()
	## Sonradan yaratılan satır butonları (_create_row) kendi tık sesini ayrıca bağlar.
	UISound.connect_all_buttons(self)


func _build_static_ui() -> void:
	theme = UIKit.theme()
	var bg := PanelContainer.new()
	bg.name = "Background"
	bg.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	bg.add_theme_stylebox_override("panel", UIKit.panel_style("hud_flat"))
	bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(bg)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 6)
	bg.add_child(_list)
	## Başlık satırı: "GRUP" + sağda sade "Hasar" butonu (hasar sıralaması).
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_list.add_child(header)
	var title := Label.new()
	title.text = "GRUP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(title, FS_ROW, UIKit.HUD_TEXT_ACCENT, 0)
	header.add_child(title)

	_stats_button = Button.new()
	_stats_button.text = "Hasar"
	_stats_button.custom_minimum_size = Vector2(0, 24)
	_stats_button.tooltip_text = "Kimin ne kadar hasar verdiğini göster"
	_stats_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_stats_button.pressed.connect(_on_stats_button_pressed)
	UIKit.style_flat_button(_stats_button, FS_ROW)
	header.add_child(_stats_button)

	_build_gift_popup()
	_build_stats_popup()


func _build_gift_popup() -> void:
	_gift_popup = PanelContainer.new()
	_gift_popup.name = "GiftPopup"
	_gift_popup.visible = false
	_gift_popup.z_index = 100
	_gift_popup.add_theme_stylebox_override("panel", UIKit.panel_style("hud_flat"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_gift_popup.add_child(vbox)

	_gift_amount_label = Label.new()
	UIKit.style_label(_gift_amount_label, FS_ROW, UIKit.HUD_TEXT_ACCENT, 0)
	_gift_amount_label.text = "Altın gönder"
	vbox.add_child(_gift_amount_label)

	var presets_box := HBoxContainer.new()
	presets_box.add_theme_constant_override("separation", 4)
	vbox.add_child(presets_box)
	for amount in [10, 50, 100]:
		var btn := Button.new()
		btn.text = str(amount)
		btn.custom_minimum_size = Vector2(44, 26)
		UIKit.style_flat_button(btn, FS_ROW)
		btn.pressed.connect(_on_gift_amount_pressed.bind(amount))
		presets_box.add_child(btn)
	var all_btn := Button.new()
	all_btn.text = "Hepsi"
	all_btn.custom_minimum_size = Vector2(52, 26)
	UIKit.style_flat_button(all_btn, FS_ROW)
	all_btn.pressed.connect(_on_gift_amount_pressed.bind(-1))
	presets_box.add_child(all_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "İptal"
	cancel_btn.custom_minimum_size = Vector2(0, 26)
	UIKit.style_flat_button(cancel_btn, FS_ROW)
	cancel_btn.pressed.connect(_hide_gift_popup)
	vbox.add_child(cancel_btn)

	# Liste akışının (VBoxContainer) DIŞINDA, kök seviyesinde - böylece
	# satırların üstünde serbestçe konumlandırılıp en üstte çizilebiliyor.
	add_child(_gift_popup)


## Hasar sıralaması (kullanıcı isteği 2026-09-25: "daha minimalist ve diğer panellerle uyumlu, gereksiz çerçeve ayrıntısı
## olmasın") - grup paneliyle AYNI sade kutu; başlık + köşede küçük "x", satırlarda sıra/isim/hasar ve altında en çok
## vurana göre oranlı ince çubuk (karakter üstü çubuk diliyle).
func _build_stats_popup() -> void:
	_stats_popup = PanelContainer.new()
	_stats_popup.name = "StatsPopup"
	_stats_popup.visible = false
	_stats_popup.z_index = 100
	_stats_popup.add_theme_stylebox_override("panel", UIKit.panel_style("hud_flat"))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_stats_popup.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Hasar Sıralaması"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.style_label(title, FS_ROW, UIKit.HUD_TEXT_ACCENT, 0)
	header.add_child(title)
	## Kullanıcı bildirimi (eski): sadece kendi kapat butonuyla kapanmalı (dışına tıklayınca değil).
	var close_btn := Button.new()
	close_btn.text = "x"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.tooltip_text = "Kapat"
	UIKit.style_flat_button(close_btn, FS_ROW)
	close_btn.pressed.connect(_hide_stats_popup)
	header.add_child(close_btn)

	_stats_list = VBoxContainer.new()
	_stats_list.add_theme_constant_override("separation", 6)
	_stats_list.custom_minimum_size = Vector2(230, 0)
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

	visible = not _rows.is_empty()
	if not visible:
		_hide_stats_popup()


func _create_row(peer_id: int) -> PartyRow:
	var row := PartyRow.new()
	row.peer_id = peer_id

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_list.add_child(hbox)
	row.container = hbox

	## Portre: HUD avatar zemini + 1:1 portre + ince koyu kenar (ahşap çerçeve yok).
	var avatar_box := Panel.new()
	avatar_box.custom_minimum_size = Vector2(AVATAR_BOX, AVATAR_BOX)
	avatar_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avatar_border := StyleBoxFlat.new()
	avatar_border.bg_color = Color(0, 0, 0, 0)
	avatar_border.border_color = UIKit.HUD_FLAT_BORDER
	avatar_border.set_border_width_all(2)
	avatar_border.anti_aliasing = false
	avatar_box.add_theme_stylebox_override("panel", avatar_border)
	hbox.add_child(avatar_box)
	var avatar_bg := TextureRect.new()
	avatar_bg.texture = AVATAR_BG
	avatar_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_bg.stretch_mode = TextureRect.STRETCH_SCALE
	avatar_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar_bg.position = Vector2(2, 2)
	avatar_bg.size = Vector2(AVATAR_BOX - 4.0, AVATAR_BOX - 4.0)
	avatar_box.add_child(avatar_bg)
	avatar_box.move_child(avatar_bg, 0)
	var avatar := TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.position = Vector2((AVATAR_BOX - AVATAR_SIZE) * 0.5, (AVATAR_BOX - AVATAR_SIZE) * 0.5)
	avatar.size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar_box.add_child(avatar)
	row.avatar = avatar

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	## 1. satır: isim (taşarsa ...) + durum etiketi (YERDE / ÖLÜ) + küçük altın butonu
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	info_vbox.add_child(name_row)
	var name_label := Label.new()
	UIKit.style_label(name_label, FS_ROW, UIKit.HUD_TEXT_LIGHT, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_row.add_child(name_label)
	row.name_label = name_label
	var downed_label := Label.new()
	downed_label.text = "YERDE"
	UIKit.style_label(downed_label, FS_ROW, Color(1.0, 0.45, 0.4), 0)
	downed_label.visible = false
	name_row.add_child(downed_label)
	row.downed_label = downed_label

	var gold_button := Button.new()
	gold_button.custom_minimum_size = Vector2(GOLD_BTN_SIZE, GOLD_BTN_SIZE)
	gold_button.tooltip_text = "Altın gönder"
	gold_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gold_button.text = ""
	UIKit.style_flat_button(gold_button, FS_ROW)
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
			icon_rect.offset_left = 3.0
			icon_rect.offset_top = 3.0
			icon_rect.offset_right = -3.0
			icon_rect.offset_bottom = -3.0
			gold_button.add_child(icon_rect)
			gold_icon_applied = true
	if not gold_icon_applied:
		gold_button.text = "$"
	gold_button.pressed.connect(_on_gold_button_pressed.bind(peer_id))
	## Bu buton _ready()'deki tek seferlik UISound taramasından SONRA yaratıldığı için tık sesi burada elle bağlanır.
	if not gold_button.pressed.is_connected(UISound.play_click):
		gold_button.pressed.connect(UISound.play_click)
	name_row.add_child(gold_button)
	row.gold_button = gold_button

	## 2-3. satır: karakterin üstündeki çubuğun aynısı - can (yeşil->kırmızı) ve kalkan (mavi).
	row.health_bar = _make_mini_bar(HP_BAR_HEIGHT, HP_BG)
	info_vbox.add_child(row.health_bar)
	row.shield_bar = _make_mini_bar(SHIELD_BAR_HEIGHT, SHIELD_BG)
	info_vbox.add_child(row.shield_bar)
	return row


func _make_mini_bar(height: float, bg: Color) -> Control:
	var bar := Control.new()
	bar.set_script(MiniBarScript)
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.set("bg_color", bg)
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
	## Karakter üstü çubukla aynı yeşil; azaldıkça kırmızıya kayar (hud.gd update_health ile aynı geçiş).
	row.health_bar.call("set_values", pct, Color(0.84, 0.22, 0.22).lerp(Color(0.30, 0.82, 0.24), pct))
	row.health_bar.tooltip_text = "%d/%d" % [int(round(maxf(health, 0.0))), int(round(max_health))]

	## Kalkan çubuğu hep görünür (kalkansızken boş) - satır yüksekliği kalkan alınca zıplamasın.
	var shield_max: float = float(ally.get("item_shield_max"))
	var shield_hp: float = float(ally.get("item_shield_hp"))
	var sh_pct: float = clampf(shield_hp / max(shield_max, 0.001), 0.0, 1.0) if shield_max > 0.0 else 0.0
	row.shield_bar.call("set_values", sh_pct, SHIELD_COLOR)

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


## Panel ekranın SAĞINDA - açılır pencereler panelin (arka plan kutusunun) SOLUNA, tetikleyen butonun hizasında açılır:
## ekran dışına taşmaz ve panelin kendi satırlarını örtmez (gerçek oyun görüntüsünde butonun hemen soluna açılınca paneli
## örttüğü görüldü, 2026-09-25).
func _place_popup_left_of(popup: Control, anchor_btn: Control) -> void:
	popup.reset_size()
	var w: float = popup.get_combined_minimum_size().x
	var bg: Control = get_node_or_null("Background") as Control
	var left_x: float = bg.global_position.x if bg != null else anchor_btn.global_position.x
	popup.global_position = Vector2(left_x - w - 8.0, anchor_btn.global_position.y - 6.0)


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
	_place_popup_left_of(_stats_popup, _stats_button)


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
		UIKit.style_label(empty_lbl, FS_ROW, UIKit.HUD_TEXT_DIM, 0)
		_stats_list.add_child(empty_lbl)
		return
	var top: float = maxf(float(entries[0].get("dealt", 0.0)), 1.0)
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
		rank_lbl.custom_minimum_size = Vector2(22, 0)
		UIKit.style_label(rank_lbl, FS_ROW, UIKit.HUD_TEXT_ACCENT if i == 0 else UIKit.HUD_TEXT_DIM, 0)
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("name", "?"))
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.custom_minimum_size = Vector2(110, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.style_label(name_lbl, FS_ROW, UIKit.HUD_TEXT_LIGHT, 0)
		row.add_child(name_lbl)

		var dealt: float = float(entry.get("dealt", 0.0))
		var dmg_lbl := Label.new()
		dmg_lbl.text = "%d" % int(round(dealt))
		dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dmg_lbl.custom_minimum_size = Vector2(56, 0)
		UIKit.style_label(dmg_lbl, FS_ROW, DAMAGE_BAR_COLOR, 0)
		row.add_child(dmg_lbl)

		var bar: Control = _make_mini_bar(10.0, HP_BG)
		bar.call("set_values", clampf(dealt / top, 0.0, 1.0), DAMAGE_BAR_COLOR)
		block.add_child(bar)
