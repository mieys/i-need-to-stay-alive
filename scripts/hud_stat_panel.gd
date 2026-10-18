extends Control

## Oyuncu panelinin (hud.gd dock) SOLUNA yapışık mini stat paneli (LoL tarzı), kullanıcı isteği (2026-10-14): "skill ve can mana barı
## penceresinin sol tarafına minik bir stat paneli ... 2 sütun 4 satır 8 stat, portrenin altındaki butonla açılsın, üstünde 1-2
## butonları 2. sayfaya geçsin (16 stat). Can-kalkan miktarı ve toplama mesafesi olmasın, önemliden önemsize."
## "Sayılar ASLA taşmamalı" (sütun genişliği en geniş olası yazıdan; aşan değer kısaltılır).
## Normalde kapalı; aç/kapa = hud_stat_toggle.gd (portre altı). Panelin sağ 12 px'i ana panelin ARKASINDA kalır (efsanevi panelin aynası),
## altı efsanevi panelin altıyla hizalı. Sayfa sekmeleri panelin üst kenarına biner. Sadece masaüstü (telefon HUD'u kurmaz).
## 2026-10-18 (kullanıcı: "yazılar ve ikonlar çok çirkin, LoL gibi olsun, okunurluk"; 3 prototipten "B - Düz Glif" seçildi):
## panel ÖLÇEKSİZ (hud.gd DOCK_UI_SCALE 0,92 piksel yazıyı/simgeyi düzensiz çiziyordu), LoL HUD'u gibi düz tek renk pürüzsüz simgeler
## (tools/proto_20261018/gen_stat_icons_lol2.py el "b", 48 px -> 24 px doğrusal süzgeç), kalın koyu hatlı Nunito yazı. Simge + yazı
## ayrı LINEAR çocukta (_content; Nunito içe aktarımı 2x örnekli -> NEAREST'te pürüzlü olurdu), ahşap çerçeve bu düğümde (NEAREST).

const PixelIcons := preload("res://scripts/hud_pixel_icons.gd")
const StatsPanelScript := preload("res://scripts/stats_panel.gd")
const BASE_FONT: Font = preload("res://assets/fonts/Nunito-SemiBold.ttf")
const ICON_DIR := "res://assets/ui/stat_mini_lol/" ## <id>.png, 48x48, 24 px çizilir
const FONT_PX := 16
const TAB_FONT_PX := 12
const EMBOLDEN := 0.35 ## SemiBold'u kalınlaştırır (Bold dosyası yok)
const TEXT_OUTLINE := 4
static var _font: FontVariation = null
const HudTheme := preload("res://scripts/hud_theme.gd")
const OUTLINE := HudTheme.OUTLINE
const PLATE := HudTheme.INSET
const STRIPE := HudTheme.STRIPE
const VALUE := Color(0.97, 0.93, 0.84)
const TAB_ON := HudTheme.RIM_HI
const TAB_OFF := HudTheme.RIM_LO
const TAB_OFF_TEXT := HudTheme.DIM
const ICON := 24.0
const ROW_H := 28.0
const PAD := 3.0 ## hücre sol/sağ payı
const GAP := 5.0 ## simge-yazı arası
const INSET := 3.0 ## levha içi pay
const EDGE := 7.0 ## ahşap kenar -> levha
const OVERLAP := 12.0 ## sağ kenar ana panelin altına girer (hud.gd DOCK_LEGEND_OVERLAP ile aynı)
const TAB_SIZE := Vector2(20, 16)
const TAB_BITE := 4.0 ## sekme panelin üst kenarına bu kadar biner
const TAB_X := 10.0
## Sütun bu yazıların en genişine göre açılır; bundan geniş bir değer _fit ile kısaltılır - panel hiç taşmaz.
const WORST: Array[String] = ["%600", "%250", "9999", "999.9", "x9.99"]
const REFRESH_INTERVAL := 0.25

## En önemliden en önemsize; 8'li iki sayfa. [id (= ICON_DIR/<id>.png), ad, ipucu anahtarı ya da metni]
## İpucu "@anahtar" ise stats_panel.gd STAT_TIPS / EXTRA_ROWS metni kullanılır (Özellikler penceresiyle tek kaynak).
const STATS: Array = [
	["damage", "Saldırı Gücü", "@damage"],
	["fire_rate", "Saldırı Hızı", "@fire_rate"],
	["crit_chance", "Kritik Şansı", "Kritik Şansı: vuruşlarının kritik olma ihtimali (ilk silahın)."],
	["crit_damage", "Kritik Hasarı", "Kritik Hasarı: kritik vuruşun normal hasara oranı (%150 = 1,5 kat, ilk silahın)."],
	["cooldown_reduction", "Bekleme Azaltma", "@cooldown_reduction"],
	["lifesteal", "Can Çalma", "@lifesteal"],
	["dodge", "Sıvışma", "@dodge"],
	["speed", "Hareket Hızı", "@speed"],
	["shield_pen_percent", "Kalkan Delme", "@shield_pen_percent"],
	["range", "Menzil", "@range"],
	["shield_protection", "Mana Kalkanı Soğurma", "@shield_protection"],
	["shield_amount", "Mana Kalkanı Miktarı", "@shield_amount"],
	["shield_regen", "Mana Kalkanı Yenilenmesi", "@shield_regen"],
	["health_regen", "Can Yenilenmesi", "@health_regen"],
	["heal_power", "İyileştirme Gücü", "@heal_power"],
	["luck", "Şans", "@luck"],
]
const PER_PAGE := 8

## Oturum içinde hatırlanır (yeni koşuda/HUD yeniden kurulunca aynı sayfa).
static var remembered_page: int = 0

var page: int = 0
var _tex: Dictionary = {}
var _values: Array[String] = []
var _cells: Array[Control] = []
var _tabs: Array[Control] = []
var _tab_hover: int = -1
var _timer: float = 0.0
var _panel_box: StyleBox = null
var _tips: Dictionary = {}
var _content: Control = null ## LINEAR süzgeçli çocuk: simgeler + yazı
var _hover_cell: int = -1


static func font() -> Font:
	if _font == null:
		_font = FontVariation.new()
		_font.base_font = BASE_FONT
		_font.variation_embolden = EMBOLDEN
	return _font


static func value_w() -> float:
	var w: float = 0.0
	for t in WORST:
		w = maxf(w, font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x)
	return ceilf(w)


static func col_w() -> float:
	return PAD + ICON + GAP + value_w() + PAD


static func plate_size() -> Vector2:
	return Vector2(2.0 * col_w() + 2.0 * INSET, 4.0 * ROW_H + 2.0 * INSET)


## Ahşap panel (sekmeler HARİÇ).
static func panel_size() -> Vector2:
	var ps: Vector2 = plate_size()
	return Vector2(EDGE + ps.x + 4.0 + OVERLAP, EDGE + ps.y + EDGE)


## Düğümün tamamı: üstte sekmeler (panelin üst kenarına TAB_BITE kadar biner).
static func node_size() -> Vector2:
	return panel_size() + Vector2(0.0, TAB_SIZE.y - TAB_BITE)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel_box = UIKit.panel_style("status_badge")
	page = clampi(remembered_page, 0, 1)
	_build_tips()
	for s in STATS:
		_tex[s[0]] = load(ICON_DIR + str(s[0]) + ".png") as Texture2D
	_values.resize(STATS.size())
	_values.fill("-")
	_content = Control.new()
	_content.name = "Content"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_content.size = node_size()
	_content.draw.connect(_draw_content)
	add_child(_content)
	for k in PER_PAGE:
		var a := Control.new()
		a.name = "Cell%d" % k
		a.position = _cell_pos(k)
		a.size = Vector2(col_w(), ROW_H)
		a.mouse_filter = Control.MOUSE_FILTER_PASS
		a.mouse_entered.connect(func() -> void:
			_hover_cell = k
			_redraw())
		a.mouse_exited.connect(func() -> void:
			if _hover_cell == k:
				_hover_cell = -1
			_redraw())
		add_child(a)
		_cells.append(a)
	for i in 2:
		var t := Control.new()
		t.name = "Tab%d" % (i + 1)
		t.position = Vector2(TAB_X + i * (TAB_SIZE.x + 2.0), 0.0)
		t.size = TAB_SIZE
		t.mouse_filter = Control.MOUSE_FILTER_STOP
		t.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		t.tooltip_text = "Sayfa %d" % (i + 1)
		t.gui_input.connect(_on_tab_input.bind(i))
		t.mouse_entered.connect(func() -> void:
			_tab_hover = i
			_redraw())
		t.mouse_exited.connect(func() -> void:
			if _tab_hover == i:
				_tab_hover = -1
			_redraw())
		add_child(t)
		_tabs.append(t)
	custom_minimum_size = node_size()
	size = node_size()
	_apply_page_tips()
	_refresh()


func _redraw() -> void:
	queue_redraw()
	if _content:
		_content.queue_redraw()


func _build_tips() -> void:
	var extra: Dictionary = {}
	for row in StatsPanelScript.EXTRA_ROWS:
		extra[row[0]] = str(row[2])
	for s in STATS:
		var tip: String = str(s[2])
		if tip.begins_with("@"):
			var key: String = tip.substr(1)
			tip = str(StatsPanelScript.STAT_TIPS.get(key, extra.get(key, s[1])))
		_tips[s[0]] = tip


func _apply_page_tips() -> void:
	for k in PER_PAGE:
		_cells[k].tooltip_text = _tips[STATS[page * PER_PAGE + k][0]]


func set_page(p: int) -> void:
	p = clampi(p, 0, 1)
	if p == page:
		return
	page = p
	remembered_page = p
	_apply_page_tips()
	_redraw()


func _on_tab_input(event: InputEvent, i: int) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		if i != page:
			UISound.play_click()
		set_page(i)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_timer = 0.0
		_refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = REFRESH_INTERVAL
		_refresh()


func _player() -> Node:
	if not is_inside_tree():
		return null
	var p: Node = get_tree().get_first_node_in_group("player")
	return p if is_instance_valid(p) else null


static func _pct(v: float) -> String:
	return "%%%d" % int(round(v * 100.0))


static func _num(v: float) -> String:
	return StatsPanelScript.format_luck(snappedf(v, 0.1))


## Sütuna sığmayan değeri kısaltır: 12500 -> "12k", %1234 -> "%1k", ondalık atılır; yine de sığmazsa sondan kırpılır.
static func fit(t: String) -> String:
	var budget: float = value_w()
	var f: Font = font()
	if f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x <= budget:
		return t
	var pre: String = "%" if t.begins_with("%") else ("x" if t.begins_with("x") else "")
	var num: float = float(t.substr(pre.length()))
	var alt: String = pre + (("%dk" % int(num / 1000.0)) if absf(num) >= 1000.0 else str(int(num)))
	while alt.length() > 1 and f.get_string_size(alt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x > budget:
		alt = alt.substr(0, alt.length() - 1)
	return alt


func _refresh() -> void:
	## Görünürlük bildirimi _ready()'den ÖNCE gelebilir (hud.gd _create_player_dock): _values henüz boyutlanmadı.
	if _values.size() != STATS.size():
		return
	var p: Node = _player()
	if p == null:
		return
	var v: Dictionary = values_for(p)
	var changed: bool = false
	for i in STATS.size():
		var t: String = fit(str(v.get(STATS[i][0], "-")))
		if t != _values[i]:
			_values[i] = t
			changed = true
	if changed:
		_redraw()


## Ham değer yazıları (kısaltmadan önce) - stats_panel.gd ile aynı kaynaklar.
static func values_for(p: Node) -> Dictionary:
	var w = p.call("get_primary_weapon") if p.has_method("get_primary_weapon") else null
	var regen: float = float(p.get("heal_regen_card_bonus") if "heal_regen_card_bonus" in p else 0.0) \
		+ float(p.get("item_health_regen") if "item_health_regen" in p else 0.0)
	return {
		"damage": str(int(w.damage)) if w else "0",
		"fire_rate": "%%%d" % int(round(float(p.call("get_attack_speed_bonus_percent")))) if p.has_method("get_attack_speed_bonus_percent") else "-",
		"crit_chance": _pct(float(w.crit_chance)) if w else "-",
		"crit_damage": _pct(float(w.crit_damage)) if w else "-",
		"cooldown_reduction": _pct(float(p.call("get_cooldown_reduction"))) if p.has_method("get_cooldown_reduction") else "-",
		"lifesteal": StatsPanelScript.format_percent(float(p.call("get_total_lifesteal"))) if p.has_method("get_total_lifesteal") else "-",
		"dodge": _pct(float(p.get("dodge_chance"))) if "dodge_chance" in p else "-",
		"speed": str(int(round(float(p.call("get_base_move_speed"))))) if p.has_method("get_base_move_speed") else "-",
		"shield_pen_percent": _pct(float(p.get("shield_pen_percent"))) if "shield_pen_percent" in p else "-",
		"range": _pct(float(p.get("weapon_range_bonus"))) if "weapon_range_bonus" in p else "-",
		"shield_protection": _pct(float(p.get("shield_protection"))) if "shield_protection" in p else "-",
		"shield_amount": _pct(float(p.get("shield_max_percent"))) if "shield_max_percent" in p else "-",
		"shield_regen": _num(float(p.get("item_shield_regen_flat"))) if "item_shield_regen_flat" in p else "-",
		"health_regen": _num(regen),
		"heal_power": _pct(float(p.call("get_heal_shield_power"))) if p.has_method("get_heal_shield_power") else "-",
		"luck": _num(float(p.get("luck"))) if "luck" in p else "-",
	}


## Yazı _content üstüne (LINEAR), kalın koyu hatlı.
func _text(pos: Vector2, s: String, col: Color, px: int = FONT_PX) -> void:
	var f: Font = font()
	_content.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, TEXT_OUTLINE, OUTLINE)
	_content.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _tab_rect(i: int) -> Rect2:
	var active: bool = i == page
	return Rect2(Vector2(TAB_X + i * (TAB_SIZE.x + 2.0), 0.0), TAB_SIZE + (Vector2(0.0, TAB_BITE) if active else Vector2.ZERO))


func _draw_tab(i: int) -> void:
	var active: bool = i == page
	var r: Rect2 = _tab_rect(i)
	var fill: Color = TAB_ON if active else (TAB_OFF.lightened(0.15) if _tab_hover == i else TAB_OFF)
	draw_rect(Rect2(r.position + Vector2(2, 0), Vector2(r.size.x - 4, r.size.y)), OUTLINE)
	draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(r.size.x, r.size.y - 2)), OUTLINE)
	draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 2 if active else 4)), fill)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 2)), fill.lightened(0.25))


func _cell_pos(k: int) -> Vector2:
	var inner := Vector2(EDGE + INSET, TAB_SIZE.y - TAB_BITE + EDGE + INSET)
	return inner + Vector2((k % 2) * col_w(), (k / 2) * ROW_H)


func _draw() -> void:
	var p := Vector2(0.0, TAB_SIZE.y - TAB_BITE)
	## Etkin olmayan sekme panelin ARKASINDA, etkin olan önünde (panelle birleşir).
	for i in 2:
		if i != page:
			_draw_tab(i)
	draw_style_box(_panel_box, Rect2(p, panel_size()))
	_draw_tab(page)
	var plate := Rect2(p + Vector2(EDGE, EDGE), plate_size())
	PixelIcons.draw_plate(self, plate, PLATE)
	var inner: Rect2 = plate.grow(-INSET)
	var cw: float = col_w()
	if _hover_cell >= 0:
		draw_rect(Rect2(_cell_pos(_hover_cell), Vector2(cw, ROW_H)), Color(HudTheme.RIM_LO, 0.55))
	draw_rect(Rect2(inner.position + Vector2(cw - 1.0, 3.0), Vector2(2.0, inner.size.y - 6.0)), STRIPE)
	for r in range(1, 4):
		draw_rect(Rect2(inner.position + Vector2(3.0, r * ROW_H), Vector2(inner.size.x - 6.0, 1.0)), STRIPE)


## LINEAR çocuk: 48 px simgeler 24 px'e (1080p'de kutu ortalaması, büyük pencerede keskin) + değer ve sekme yazıları.
func _draw_content() -> void:
	var f: Font = font()
	var base: float = roundf((ROW_H - (f.get_ascent(FONT_PX) + f.get_descent(FONT_PX))) * 0.5 + f.get_ascent(FONT_PX))
	for k in PER_PAGE:
		var i: int = page * PER_PAGE + k
		var cell: Vector2 = _cell_pos(k)
		var tex: Texture2D = _tex.get(STATS[i][0]) as Texture2D
		if tex:
			_content.draw_texture_rect(tex, Rect2(cell + Vector2(PAD, roundf((ROW_H - ICON) * 0.5)), Vector2(ICON, ICON)), false)
		_text(Vector2(cell.x + PAD + ICON + GAP, cell.y + base), _values[i], VALUE)
	for t in 2:
		var r: Rect2 = _tab_rect(t)
		var label: String = str(t + 1)
		var tw: float = f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, TAB_FONT_PX).x
		_text(r.position + Vector2(roundf((r.size.x - tw) * 0.5), 12.0), label, VALUE if t == page else TAB_OFF_TEXT, TAB_FONT_PX)
