extends Control

## Görev sistemi (bkz. world_event_manager.gd) - ekranın sağında (HUD'un ENVANTER/altın butonlarının altında), aktif/uyarı
## aşamasındaki her görev için bir satır. UIKit'in diğer HUD panelleriyle AYNI "plaque" dokusu.
## Kullanıcı isteği (2026-09-24): "görev penceresi daha ufak olsun ayrıca görevlerin konumu görev penceresinin içinde
## gösterilsin" - satır 360 -> 250 px; solda koyu bir kutuda göreve dönen yön oku (alanın içindeysen yeşil nokta, konumu
## gizli görevde "?"), başlık satırının sağında mesafe, altta ilerleme çubuğu + kalan süre. Ekranın üst-ortasındaki
## ayrı pusula (world_event_marker.gd) bu yüzden kaldırıldı - konum artık tek yerde.

const ROW_WIDTH := 270.0
## GÜNCELLEME (kullanıcı bildirimi 2026-09-24: "görev ilerlemesi barı oyunla uygun görünmüyor ... ayrıca toplama görevinde
## toplama için bar yerine toplanması gereken miktar yazsın"): eski çubuk iki düz ColorRect'ti (8 px, çerçevesiz). Artık
## ana HUD çubuklarının AYNI piksel dokuları (hud_bar_under/fill, 9-patch) altın tonla + %10 çentikler, kitin gömme
## (inset_tight) çerçevesi içinde. Toplama görevinde (set_count_mode) çubuk yerine "toplanan/hedef" sayısı yazar.
const BAR_HEIGHT := 12.0
const BAR_TINT := Color("#e0aa3e")
const BAR_TICK_COUNT := 10
const BarUnder := preload("res://assets/ui/kit/hud_bar_under.png")
const BarFill := preload("res://assets/ui/kit/hud_bar_fill.png")
const ARROW_BOX := 40.0
const FS_ROW := 24 ## m5x7 3x (keskin; 16 1080p'de okunmuyor)
## Mesafe gösterimi: 10 dünya birimi = 1 m (oyuncu ~8 m/sn koşar).
const UNITS_PER_METER := 10.0

var _rows: Dictionary = {} ## id -> {panel, label, dist, time, bar_bg, bar_fill, arrow, title, remaining, target, radius, has_target}
var _vbox: VBoxContainer = null
var _player: Node2D = null


## Göreve dönen küçük yön oku (satırın solundaki koyu kutu). Salt çizim - veriyi banner her karede verir.
class ArrowBox extends Control:
	var dir: Vector2 = Vector2.ZERO ## sıfır: konum yok ("?") ; inside: alanın içindesin
	var inside: bool = false
	var hidden_location: bool = true
	var color: Color = Color("#e0aa3e")

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#3a2212"))
		draw_rect(r.grow(-2.0), Color("#5a361d"))
		var c: Vector2 = size * 0.5
		if hidden_location:
			var f: Font = get_theme_default_font()
			var fs: int = 32
			var ts: Vector2 = f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, Vector2(c.x - ts.x * 0.5, c.y + ts.y * 0.3), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
			return
		if inside:
			draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), Color("#3a2212"))
			draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color("#7fd04a"))
			return
		if dir == Vector2.ZERO:
			return
		## 16 yöne yuvarlanmış, piksel ızgarasına oturan ok (koyu kontur + renkli iç).
		var a: float = snappedf(dir.angle(), TAU / 16.0)
		var d := Vector2.from_angle(a)
		var perp := Vector2(-d.y, d.x)
		## Dışbükey üçgen baş + kalın gövde (içbükey tek çokgen yanlış üçgenleniyordu). Önce koyu kontur, sonra renk.
		var outline := Color("#1e120a")
		var tail: Vector2 = (c - d * 11.0).round()
		var neck: Vector2 = (c + d * 1.0).round()
		var tip: Vector2 = (c + d * 13.0).round()
		var hl: Vector2 = (neck + perp * 8.0).round()
		var hr: Vector2 = (neck - perp * 8.0).round()
		draw_line(tail, neck, outline, 8.0)
		draw_colored_polygon(PackedVector2Array([tip + d * 2.0, hl + perp * 2.0 - d * 1.5, hr - perp * 2.0 - d * 1.5]), outline)
		draw_line(tail + d, neck, color, 4.0)
		draw_colored_polygon(PackedVector2Array([tip, hl, hr]), color)


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
	_update_arrows()
	for id in _rows.keys():
		_apply_bar(_rows[id])


## Konumu olan görevler için yön oku + mesafe (her karede - oyuncu hareket ettikçe).
func set_target(id: int, pos: Vector2, radius: float) -> void:
	if not _rows.has(id):
		return
	_rows[id]["target"] = pos
	_rows[id]["radius"] = radius
	_rows[id]["has_target"] = true
	(_rows[id]["arrow"] as ArrowBox).hidden_location = false


func _update_arrows() -> void:
	if _rows.is_empty():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	for id in _rows.keys():
		var row: Dictionary = _rows[id]
		var arrow: ArrowBox = row["arrow"]
		var dist_label: Label = row["dist"]
		if not bool(row.get("has_target", false)) or _player == null:
			dist_label.text = ""
			arrow.queue_redraw()
			continue
		var to: Vector2 = (row["target"] as Vector2) - _player.global_position
		var inside: bool = to.length() <= float(row.get("radius", 0.0))
		arrow.inside = inside
		arrow.dir = to
		arrow.queue_redraw()
		var txt: String = "burada" if inside else "%dm" % int(round(to.length() / UNITS_PER_METER))
		if dist_label.text != txt:
			dist_label.text = txt


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
	(row["label"] as Label).text = String(row.get("title", ""))
	var remaining: float = float(row.get("remaining", -1.0))
	var time_label: Label = row["time"]
	if remaining < 0.0:
		time_label.text = ""
		return
	var secs: int = int(ceil(remaining))
	@warning_ignore("integer_division")
	time_label.text = "%d:%02d" % [secs / 60, secs % 60]


## is_warning: görev henüz başlamadı (uyarı aşaması) - başlık kiremit kırmızısı, ok soluk mavi; aktifken koyu kahve / altın.
func upsert(id: int, title: String, is_warning: bool) -> void:
	if not _rows.has(id):
		_build_row(id)
	var row: Dictionary = _rows[id]
	row["title"] = title
	row["remaining"] = -1.0 ## yeni aşama - main.gd hemen ardından set_countdown ile yeniden kurar
	(row["label"] as Label).add_theme_color_override("font_color", UIKit.C_BAD if is_warning else UIKit.C_TEXT)
	(row["time"] as Label).add_theme_color_override("font_color", UIKit.C_BAD if is_warning else UIKit.C_TEXT_DIM)
	(row["arrow"] as ArrowBox).color = Color("#9cc8ff") if is_warning else Color("#e0aa3e")
	_refresh_label(id)


func _small_label(align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", FS_ROW)
	l.add_theme_color_override("font_color", UIKit.C_TEXT_DIM)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_row(id: int) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(ROW_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", UIKit.panel_style("plaque"))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 4)
	panel.add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	margin.add_child(h)
	var arrow := ArrowBox.new()
	arrow.custom_minimum_size = Vector2(ARROW_BOX, ARROW_BOX)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(arrow)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	## 1. satır: başlık (solda, taşarsa ...) + mesafe (sağda)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	v.add_child(top)
	var label := _small_label(HORIZONTAL_ALIGNMENT_LEFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_color_override("font_color", UIKit.C_TEXT)
	top.add_child(label)
	var dist := _small_label(HORIZONTAL_ALIGNMENT_RIGHT)
	## 2. satır: ilerleme çubuğu + kalan süre
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	v.add_child(bottom)
	## İlerleme: kitin gömme çerçevesi içinde HUD çubuk dokusu (bkz. BAR_HEIGHT üstündeki not).
	var bar_bg := PanelContainer.new()
	bar_bg.add_theme_stylebox_override("panel", UIKit.panel_style("inset_tight"))
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bar_bg)
	var bar_fill := TextureProgressBar.new()
	bar_fill.texture_under = BarUnder
	bar_fill.texture_progress = BarFill
	bar_fill.nine_patch_stretch = true
	for m in ["stretch_margin_left", "stretch_margin_right", "stretch_margin_top", "stretch_margin_bottom"]:
		bar_fill.set(m, 2)
	bar_fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar_fill.tint_progress = BAR_TINT
	bar_fill.custom_minimum_size = Vector2(0.0, BAR_HEIGHT)
	bar_fill.min_value = 0.0
	bar_fill.max_value = 1.0
	bar_fill.step = 0.0
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(bar_fill)
	var ticks := Control.new()
	ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticks.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_fill.add_child(ticks)
	ticks.draw.connect(func() -> void:
		for t in range(1, BAR_TICK_COUNT):
			var x: float = round(ticks.size.x * float(t) / float(BAR_TICK_COUNT) * 0.5) * 2.0
			ticks.draw_rect(Rect2(x - 2.0, 0.0, 2.0, ticks.size.y), Color(0.12, 0.06, 0.02, 0.3)))
	ticks.resized.connect(ticks.queue_redraw)
	## Toplama görevi: çubuk yerine sayı (bkz. set_count_mode) - aynı yerde, kalın altın yazı.
	var count_label := _small_label(HORIZONTAL_ALIGNMENT_LEFT)
	count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	count_label.add_theme_color_override("font_color", UIKit.C_GOLD)
	count_label.visible = false
	bottom.add_child(count_label)
	bottom.add_child(dist)
	var time_label := _small_label(HORIZONTAL_ALIGNMENT_RIGHT)
	bottom.add_child(time_label)
	_vbox.add_child(panel)
	_rows[id] = {"panel": panel, "label": label, "dist": dist, "time": time_label, "bar_bg": bar_bg, "bar_fill": bar_fill,
		"count": count_label, "count_mode": false, "arrow": arrow, "title": "", "remaining": -1.0, "ratio": 0.0,
		"has_target": false}


## Toplama görevi (main.gd kind == "collect"): çubuk yerine "toplanan/hedef" sayısı gösterilir.
func set_count_mode(id: int, on: bool) -> void:
	if not _rows.has(id):
		return
	var row: Dictionary = _rows[id]
	row["count_mode"] = on
	(row["bar_bg"] as Control).visible = not on
	(row["count"] as Label).visible = on


func set_progress(id: int, value: float, target: float) -> void:
	if not _rows.has(id):
		return
	var row: Dictionary = _rows[id]
	row["ratio"] = clamp(value / maxf(target, 0.001), 0.0, 1.0)
	if bool(row.get("count_mode", false)):
		var txt: String = "%d/%d" % [int(round(value)), int(round(target))]
		if (row["count"] as Label).text != txt:
			(row["count"] as Label).text = txt
	_apply_bar(row)


func _apply_bar(row: Dictionary) -> void:
	var fill: TextureProgressBar = row["bar_fill"]
	var ratio: float = float(row.get("ratio", 0.0))
	if not is_equal_approx(fill.value, ratio):
		fill.value = ratio


func remove(id: int) -> void:
	if not _rows.has(id):
		return
	(_rows[id]["panel"] as Node).queue_free()
	_rows.erase(id)
