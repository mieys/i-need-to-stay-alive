extends Control

## Görev sistemi (bkz. world_event_manager.gd) için "nerede olduğunu gösteren pusula oku" -
## scripts/merchant_arrow.gd'nin AYNI görsel dili (ekranın sabit bir noktasında duran, sadece
## YÖNÜNÜ hedefe göre değiştiren ok - bkz. o dosyadaki "kamera oyuncuyu ortaladığı için normal
## bir ok herhangi bir kenara düşebilir" notu), ama TEK hedef yerine aynı anda en fazla
## WorldEventManager.SLOT_COUNT (2) hedefi ALT ALTA gösterebiliyor - satıcı okuyla (kendi sabit
## 86px'lik üst-orta noktası) ÇAKIŞMASIN diye biraz daha aşağıdan (bkz. ANCHOR_TOP_OFFSET_BASE)
## başlıyor.

const ARROW_LENGTH := 20.0
const ARROW_WIDTH := 13.0
const ARROW_OUTLINE := Color(0.1, 0.08, 0.02, 0.85)
const ANCHOR_TOP_OFFSET_BASE := 150.0
const ROW_GAP := 46.0

var _player: Node = null
## id -> {"pos": Vector2, "label": String, "color": Color, "remaining": float, "duration": float}
var _entries: Dictionary = {}


func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func show_marker(id: int, pos: Vector2, label: String, color: Color, duration: float) -> void:
	_entries[id] = {"pos": pos, "label": label, "color": color, "remaining": duration, "duration": duration}
	queue_redraw()


func hide_marker(id: int) -> void:
	_entries.erase(id)
	queue_redraw()


func _process(delta: float) -> void:
	if _entries.is_empty():
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	for id in _entries.keys():
		var e: Dictionary = _entries[id]
		e["remaining"] = max(0.0, e["remaining"] - delta)
		_entries[id] = e
	queue_redraw()


func _format_countdown(seconds: float) -> String:
	var total: int = int(ceil(seconds))
	return "%d:%02d" % [total / 60, total % 60]


func _draw() -> void:
	if not _player or not is_instance_valid(_player) or _entries.is_empty():
		return
	var row := 0
	## Dictionary sırası GDScript'te ekleme sırasıyla aynıdır - id'ye göre sıralayıp her
	## karede aynı görevin aynı satırda kalmasını garanti ediyoruz (rastgele sıçramasın).
	var ids: Array = _entries.keys()
	ids.sort()
	for id in ids:
		var e: Dictionary = _entries[id]
		var dir: Vector2 = (e["pos"] as Vector2) - _player.global_position
		if dir.length() >= 1.0:
			_draw_row(dir.normalized(), e, row)
		row += 1


func _draw_row(dir: Vector2, e: Dictionary, row: int) -> void:
	var anchor := Vector2(get_viewport_rect().size.x * 0.5, ANCHOR_TOP_OFFSET_BASE + row * ROW_GAP)
	var color: Color = e["color"]
	var perp := Vector2(-dir.y, dir.x)
	var tip: Vector2 = anchor + dir * (ARROW_LENGTH * 0.5)
	var base_l: Vector2 = anchor - dir * (ARROW_LENGTH * 0.5) + perp * (ARROW_WIDTH * 0.5)
	var base_r: Vector2 = anchor - dir * (ARROW_LENGTH * 0.5) - perp * (ARROW_WIDTH * 0.5)
	draw_colored_polygon(PackedVector2Array([tip, base_l, base_r]), color)
	draw_polyline(PackedVector2Array([tip, base_l, base_r, tip]), ARROW_OUTLINE, 2.0)
	var font: Font = ThemeDB.fallback_font
	var label: String = String(e["label"])
	var label_pos: Vector2 = anchor + Vector2(ARROW_WIDTH * 0.5 + 10.0, 5.0)
	draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.95, 0.8, 0.95))
	var countdown: String = _format_countdown(e["remaining"])
	draw_string(font, label_pos + Vector2(0.0, 19.0), countdown, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, color)
