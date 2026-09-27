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
const HP_BAR_HEIGHT := 10.0
const SHIELD_BAR_HEIGHT := 6.0
const FS_ROW := 24 ## m5x7 3x - görev satırlarıyla aynı (16 1080p'de okunmuyor)
## Sağ üstteki minimap'in (hud.tscn MinimapControl: sağdan 36, alt kenar 186) hemen altı.
const RIGHT_MARGIN := 36.0
const TOP_Y := 198.0
const GOLD_ICON_PATH := "res://assets/ui/newui/icon_ingot.png"
const AVATAR_BG := preload("res://assets/ui/kit/hud_avatar_bg.png")
const PLAQUE_CLEAN := preload("res://assets/ui/game/hud_plaque_clean.png")
const BarUnder := preload("res://assets/ui/kit/hud_bar_under.png")
const BarFill := preload("res://assets/ui/kit/hud_bar_fill.png")
## Görev okunun kutusuyla aynı koyu çerçeve (world_event_banner.gd ArrowBox).
const BOX_OUTLINE := Color("#3a2212")
const BOX_FILL := Color("#5a361d")
const SHIELD_COLOR := Color(0.35, 0.72, 1.0, 1.0) ## overhead_bar.gd kalkan rengi ile AYNI
const DAMAGE_BAR_COLOR := Color("#e0aa3e") ## görev çubuğunun altın tonu

## Kim ne zaman katıldı/ayrıldı diye satırların Node'larını her karede değil,
## bu aralıkta bir kontrol ediyoruz (satır içeriği - can/kalkan/isim/durum -
## yine de her karede güncelleniyor, bkz. _process/_update_rows).
const REFRESH_INTERVAL := 0.5

## Tek bir satırın Control referanslarını bir arada tutan basit yardımcı.
class PartyRow:
	var container: Control
	var avatar: TextureRect
	var name_label: Label
	var health_bar: TextureProgressBar
	var shield_bar: TextureProgressBar
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


## Perçinsiz bej levha (altın göstergesiyle aynı: plaque.png payları + hud_plaque_clean.png dokusu).
static func _plaque_style(pad_x: float, pad_y: float) -> StyleBoxTexture:
	var sb := MenuKit._tex_style("plaque.png", [6, 5, 6, 5], [pad_x, pad_y, pad_x, pad_y], false, MenuKit.GAME_DIR)
	sb.texture = PLAQUE_CLEAN
	return sb


static func _wood_button(text: String, min_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIKit.style_button(btn, "wood", true, FS_ROW)
	return btn


func _build_static_ui() -> void:
	theme = UIKit.theme()
	## "Background": levhaların + Hasar butonunun toplam alanı (main.gd görev satırlarını bunun ALTINA hizalar, açılır
	## pencereler bunun SOLUNA açılır). Kendisi çizim yapmaz.
	var bg := VBoxContainer.new()
	bg.name = "Background"
	bg.custom_minimum_size = Vector2(ROW_WIDTH, 0)
	bg.add_theme_constant_override("separation", 6)
	bg.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bg.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 6)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(_list)

	## Levhaların altında, sağa yaslı küçük ahşap "Hasar" butonu (hasar sıralaması).
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(footer)
	_stats_button = _wood_button("Hasar", Vector2(0, 32))
	_stats_button.tooltip_text = "Kimin ne kadar hasar verdiğini göster"
	_stats_button.pressed.connect(_on_stats_button_pressed)
	footer.add_child(_stats_button)

	_build_gift_popup()
	_build_stats_popup()


func _build_gift_popup() -> void:
	_gift_popup = PanelContainer.new()
	_gift_popup.name = "GiftPopup"
	_gift_popup.visible = false
	_gift_popup.z_index = 100
	_gift_popup.add_theme_stylebox_override("panel", _plaque_style(14.0, 10.0))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_gift_popup.add_child(vbox)

	_gift_amount_label = Label.new()
	UIKit.style_label(_gift_amount_label, FS_ROW, UIKit.C_TEXT, 0)
	_gift_amount_label.text = "Altın gönder"
	vbox.add_child(_gift_amount_label)

	var presets_box := HBoxContainer.new()
	presets_box.add_theme_constant_override("separation", 4)
	vbox.add_child(presets_box)
	for amount in [10, 50, 100]:
		var btn := _wood_button(str(amount), Vector2(52, 32))
		btn.pressed.connect(_on_gift_amount_pressed.bind(amount))
		presets_box.add_child(btn)
	var all_btn := _wood_button("Hepsi", Vector2(64, 32))
	all_btn.pressed.connect(_on_gift_amount_pressed.bind(-1))
	presets_box.add_child(all_btn)

	var cancel_btn := _wood_button("İptal", Vector2(0, 32))
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
	_stats_popup.add_theme_stylebox_override("panel", _plaque_style(14.0, 10.0))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_stats_popup.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Hasar Sıralaması"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(title, FS_ROW, UIKit.C_ACCENT, 0)
	header.add_child(title)
	## Kullanıcı bildirimi (eski): sadece kendi kapat butonuyla kapanmalı (dışına tıklayınca değil).
	var close_btn := _wood_button("x", Vector2(32, 32))
	close_btn.tooltip_text = "Kapat"
	close_btn.pressed.connect(_hide_stats_popup)
	header.add_child(close_btn)

	_stats_list = VBoxContainer.new()
	_stats_list.add_theme_constant_override("separation", 6)
	_stats_list.custom_minimum_size = Vector2(250, 0)
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

	var plaque := PanelContainer.new()
	plaque.custom_minimum_size = Vector2(ROW_WIDTH, 0.0)
	plaque.add_theme_stylebox_override("panel", _plaque_style(14.0, 8.0))
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_child(plaque)
	row.container = plaque

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(hbox)

	## Portre: görev okunun kutusuyla aynı koyu çerçeve, içinde HUD avatarının bej zemini + 1:1 portre.
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

	## 2. satır: görev çubuğuyla aynı gömme çukur; içinde can (kalın) + kalkan (ince) üst üste.
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UIKit.panel_style("inset_tight"))
	well.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	well.mouse_filter = Control.MOUSE_FILTER_PASS ## can değeri ipucu (tooltip) için
	info_vbox.add_child(well)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(bars)
	row.health_bar = _make_bar(HP_BAR_HEIGHT)
	bars.add_child(row.health_bar)
	row.shield_bar = _make_bar(SHIELD_BAR_HEIGHT)
	row.shield_bar.tint_progress = SHIELD_COLOR
	bars.add_child(row.shield_bar)

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
	gold_button.pressed.connect(_on_gold_button_pressed.bind(peer_id))
	## Bu buton _ready()'deki tek seferlik UISound taramasından SONRA yaratıldığı için tık sesi burada elle bağlanır.
	if not gold_button.pressed.is_connected(UISound.play_click):
		gold_button.pressed.connect(UISound.play_click)
	hbox.add_child(gold_button)
	row.gold_button = gold_button
	return row


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
	_set_bar(row.health_bar, pct, Color(0.84, 0.22, 0.22).lerp(Color(0.30, 0.82, 0.24), pct))
	var tip: String = "%d/%d" % [int(round(maxf(health, 0.0))), int(round(max_health))]
	var well: Control = row.health_bar.get_parent().get_parent() as Control
	if well != null and well.tooltip_text != tip:
		well.tooltip_text = tip

	## Kalkan çubuğu hep görünür (kalkansızken boş) - satır yüksekliği kalkan alınca zıplamasın.
	var shield_max: float = float(ally.get("item_shield_max"))
	var shield_hp: float = float(ally.get("item_shield_hp"))
	var sh_pct: float = clampf(shield_hp / max(shield_max, 0.001), 0.0, 1.0) if shield_max > 0.0 else 0.0
	_set_bar(row.shield_bar, sh_pct, SHIELD_COLOR)

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


func _set_bar(bar: TextureProgressBar, ratio: float, tint: Color) -> void:
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
		UIKit.style_label(empty_lbl, FS_ROW, UIKit.C_TEXT_DIM, 0)
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
		rank_lbl.custom_minimum_size = Vector2(30, 0)
		UIKit.style_label(rank_lbl, FS_ROW, UIKit.C_ACCENT if i == 0 else UIKit.C_TEXT_DIM, 0)
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("name", "?"))
		name_lbl.clip_text = true
		name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_lbl.custom_minimum_size = Vector2(110, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UIKit.style_label(name_lbl, FS_ROW, UIKit.C_TEXT, 0)
		row.add_child(name_lbl)

		var dealt: float = float(entry.get("dealt", 0.0))
		var dmg_lbl := Label.new()
		dmg_lbl.text = "%d" % int(round(dealt))
		dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dmg_lbl.custom_minimum_size = Vector2(64, 0)
		UIKit.style_label(dmg_lbl, FS_ROW, UIKit.C_GOLD, 0)
		row.add_child(dmg_lbl)

		var well := PanelContainer.new()
		well.add_theme_stylebox_override("panel", UIKit.panel_style("inset_tight"))
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(well)
		var bar: TextureProgressBar = _make_bar(8.0)
		_set_bar(bar, clampf(dealt / top, 0.0, 1.0), DAMAGE_BAR_COLOR)
		well.add_child(bar)
