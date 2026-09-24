extends Control

## Görev sistemi (bkz. world_event_manager.gd) - ekranın sağında (HUD'un ENVANTER/altın butonlarının altında), aktif/uyarı
## aşamasındaki her görev için bir satır: isim, ilerleme çubuğu, kalan süre. UIKit'in
## diğer HUD panelleriyle AYNI "plaque" dokusu (bkz. lobby_menu.gd name_card kullanımı).

const ROW_WIDTH := 360.0
const ROW_HEIGHT := 40.0
const BAR_HEIGHT := 10.0

var _rows: Dictionary = {} ## id -> {panel, label, bar_bg, bar_fill, title, remaining}
var _vbox: VBoxContainer = null


## DÜZELTME (bkz. scripts/merchant_arrow.gd dosya başındaki AYNI düzeltme notu): bu Control'ün
## ebeveyni main.gd'de elle kurulan bir CanvasLayer - anchor/preset'in dayandığı "size" bu
## durumda viewport'un GERÇEK genişliğine hiç eşitlenmeyip küçük/varsayılan kalabiliyor (banner
## ekranın ortası yerine sol üstte, sağlık barının üstüne biniyor gibi görünüyordu). Anchor'lara
## GÜVENMEK yerine _process'te her karede get_viewport_rect() ile GERÇEK genişliği okuyup
## kendi rect'ini elle kuruyoruz - merchant_arrow.gd'nin _draw()'da yaptığının AYNISI, sadece
## bu bir Control ağacı olduğu için _draw yerine position/size üzerinden.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_vbox.add_theme_constant_override("separation", 6)
	add_child(_vbox)
	set_process(true)


## Kullanıcı isteği (2026-09-24): "Görev göstergeleri sağdaki butonların altında görünsün" - eskiden
## ekranın üst-ortasındaydı. Artık HUD'un sağ sütunundaki (minimap -> ENVANTER -> altın göstergesi ->
## varsa DEBUG) GÖRÜNÜR butonların en altındakinin hemen altına, sağ kenarlarıyla hizalı yerleşiyor.
## main.gd hud_anchor_controls'u doldurur; bulunamazsa (ör. test) eski sabit sağ-üst konuma düşer.
var hud_anchor_controls: Array = []
const BELOW_BUTTONS_GAP := 10.0


func _process(_delta: float) -> void:
	## _vbox'ı ZORLA ekran genişliğine germiyoruz (satırlar FILL yüzünden yayılırdı) - KENDİ doğal
	## (içerik kadar) genişliğinde bırakıp sağ kenara elle hizalıyoruz.
	var vp: Vector2 = get_viewport_rect().size
	var right_edge: float = vp.x - 20.0
	var top_y: float = 96.0
	var found: bool = false
	for c in hud_anchor_controls:
		if not (c is Control) or not is_instance_valid(c) or not (c as Control).is_visible_in_tree():
			continue
		var r: Rect2 = (c as Control).get_global_rect()
		if not found:
			right_edge = r.end.x
			top_y = r.end.y
			found = true
		else:
			top_y = maxf(top_y, r.end.y)
	if found:
		top_y += BELOW_BUTTONS_GAP
	_vbox.position = Vector2(right_edge - _vbox.size.x, top_y)
	_tick_countdowns(_delta)


## Kullanıcı isteği (2026-09-24): "Görev aktifleştiğinde ne zaman biteceğine dair geri sayım olmalı" - her satırın
## başlığının yanında kalan süre (dk:sn). Süre main.gd'den set_countdown ile gelir (uyarıda başlamaya, aktifken
## bitişe kalan süre - host'un world_event_started'daki "duration"ı). Bu Control oyun duraklayınca (seviye atlama/
## sandık ekranı) host'taki görev saatiyle birlikte durur, yani iki taraf aynı hızda sayar.
## Görev satırlarının ekrandaki en alt kenarı (satır yoksa -1) - main.gd'nin sağ üst bildirimleri (toast) bunun
## ALTINA yerleşir ki görev satırlarının üstüne binmesinler.
func get_rows_bottom_y() -> float:
	var bottom: float = -1.0
	for id in _rows.keys():
		var panel: Control = _rows[id]["panel"]
		if is_instance_valid(panel) and panel.is_visible_in_tree():
			bottom = maxf(bottom, panel.get_global_rect().end.y)
	return bottom


func set_countdown(id: int, seconds: float) -> void:
	if not _rows.has(id):
		return
	_rows[id]["remaining"] = maxf(seconds, 0.0)
	_refresh_label(id)


func _tick_countdowns(delta: float) -> void:
	for id in _rows.keys():
		var row: Dictionary = _rows[id]
		if float(row.get("remaining", -1.0)) < 0.0:
			continue
		var before: int = int(ceil(float(row["remaining"])))
		row["remaining"] = maxf(0.0, float(row["remaining"]) - delta)
		if int(ceil(float(row["remaining"]))) != before:
			_refresh_label(id)


func _refresh_label(id: int) -> void:
	var row: Dictionary = _rows[id]
	var title: String = String(row.get("title", ""))
	var remaining: float = float(row.get("remaining", -1.0))
	if remaining < 0.0:
		(row["label"] as Label).text = title
		return
	var secs: int = int(ceil(remaining))
	@warning_ignore("integer_division")
	(row["label"] as Label).text = "%s  %d:%02d" % [title, secs / 60, secs % 60]


func upsert(id: int, title: String, is_warning: bool) -> void:
	if _rows.has(id):
		_rows[id]["title"] = title
		_rows[id]["remaining"] = -1.0 ## yeni aşama - main.gd hemen ardından set_countdown ile yeniden kurar
		(_rows[id]["label"] as Label).add_theme_color_override("font_color", UIKit.C_BAD if is_warning else UIKit.C_TEXT)
		_refresh_label(id)
		return
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ROW_WIDTH, ROW_HEIGHT)
	panel.add_theme_stylebox_override("panel", UIKit.panel_style("plaque"))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	margin.add_child(v)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	## 24 = m5x7 3x (keskin); 16 1080p'de okunmuyordu (2026-09-24 ekran görüntüsü). Levha artık bej parşömen (oyun içi kit)
	## -> koyu kahve yazı, uyarı satırları kiremit kırmızısı.
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", UIKit.C_BAD if is_warning else UIKit.C_TEXT)
	v.add_child(label)
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(ROW_WIDTH - 20.0, BAR_HEIGHT)
	bar_bg.color = Color("#5a361d")
	v.add_child(bar_bg)
	var bar_fill := ColorRect.new()
	bar_fill.color = Color("#e0aa3e")
	bar_fill.size = Vector2(0.0, BAR_HEIGHT)
	bar_bg.add_child(bar_fill)
	_vbox.add_child(panel)
	_rows[id] = {"panel": panel, "label": label, "bar_bg": bar_bg, "bar_fill": bar_fill, "title": title, "remaining": -1.0}


func set_progress(id: int, value: float, target: float) -> void:
	if not _rows.has(id):
		return
	var row: Dictionary = _rows[id]
	var ratio: float = clamp(value / maxf(target, 0.001), 0.0, 1.0)
	var bg: ColorRect = row["bar_bg"]
	var fill: ColorRect = row["bar_fill"]
	fill.size = Vector2(bg.custom_minimum_size.x * ratio, BAR_HEIGHT)


func remove(id: int) -> void:
	if not _rows.has(id):
		return
	(_rows[id]["panel"] as Node).queue_free()
	_rows.erase(id)
