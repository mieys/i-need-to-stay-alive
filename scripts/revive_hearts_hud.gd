extends Control
class_name ReviveHeartsHUD

## Mini heart-shaped Revive display on the left edge.
## Shows 3 retro pixel-art hearts, lighting up red when available, gray when consumed.
## Kullanıcı isteği (2026-09-24): hiç hak kalmayınca 1 kalp 5 dakikada yenilenir ve "altında da bekleme süresi
## görünsün" - sayaç GameManager'da (bkz. _process_revive_regen), burada ilk kalbin altında m:ss gösterilir ve
## yenilenen kalp dolum oranında soluk kırmızıyla aşağıdan yukarı dolar.

const MAX_REVIVES := 3
var revives_remaining: int = 3
var _regen_left: float = -1.0
var _regen_label: Label = null

func _ready() -> void:
	custom_minimum_size = Vector2(90, 32)
	size = Vector2(90, 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_regen_label = Label.new()
	_regen_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_label(_regen_label, 24, Color(1.0, 0.72, 0.76), 3)
	_regen_label.position = Vector2(0.0, 24.0)
	_regen_label.visible = false
	add_child(_regen_label)
	queue_redraw()


func _process(_delta: float) -> void:
	var left: float = GameManager.get_local_revive_regen_left()
	if revives_remaining > 0:
		left = -1.0
	var shown: bool = left >= 0.0
	if shown != _regen_label.visible:
		_regen_label.visible = shown
	if shown:
		var secs: int = int(ceil(left))
		var text: String = "%d:%02d" % [secs / 60, secs % 60]
		if _regen_label.text != text:
			_regen_label.text = text
	## Dolum çizimi saniyede birkaç kez yenilensin yeter (her kare queue_redraw gereksiz).
	if absf(left - _regen_left) >= 0.5 or (left < 0.0) != (_regen_left < 0.0):
		_regen_left = left
		queue_redraw()

func set_revives(count: int) -> void:
	revives_remaining = clamp(count, 0, MAX_REVIVES)
	queue_redraw()

func _draw() -> void:
	var start_x: float = 4.0
	var spacing: float = 26.0
	var heart_size: float = 20.0
	
	for i in range(MAX_REVIVES):
		var active: bool = i < revives_remaining
		var pos := Vector2(start_x + i * spacing, 6.0)
		## Yenilenen kalp (ilk boş kalp = 0. kalp): sayacın ilerlemesi kadarı aşağıdan yukarı soluk kırmızı dolar.
		var fill: float = 0.0
		if i == 0 and not active and _regen_left >= 0.0:
			fill = clampf(1.0 - _regen_left / GameManager.REVIVE_REGEN_INTERVAL, 0.0, 1.0)
		_draw_pixel_heart(pos, active, fill)

func _draw_pixel_heart(pos: Vector2, active: bool, regen_fill: float = 0.0) -> void:
	# 7x7 pixel grid scaled by 2.6
	var scale_factor: float = 2.6
	var rows: Array[String] = [
		".XX.XX.",
		"XXXXXXX",
		"XXXXXXX",
		".XXXXX.",
		"..XXX..",
		"...X..."
	]
	
	var fill_color: Color = Color(0.95, 0.22, 0.28, 1.0) if active else Color(0.28, 0.28, 0.32, 0.7)
	var shine_color: Color = Color(1.0, 0.75, 0.8, 1.0) if active else Color(0.45, 0.45, 0.5, 0.8)
	var border_color: Color = Color(0.08, 0.04, 0.05, 0.95)
	
	# Draw drop shadow
	for y in range(rows.size()):
		var line: String = rows[y]
		for x in range(line.length()):
			if line[x] == 'X':
				draw_rect(Rect2(pos.x + x * scale_factor + 1.5, pos.y + y * scale_factor + 1.5, scale_factor, scale_factor), Color(0, 0, 0, 0.4))
				
	# Draw border / fill
	var regen_color := Color(0.72, 0.3, 0.36, 0.9)
	for y in range(rows.size()):
		var line: String = rows[y]
		## Satır, alttan (rows.size() - y) sırada; dolum oranı o kadar satırı kapsıyorsa soluk kırmızı çizilir.
		var row_filled: bool = regen_fill > 0.0 and float(rows.size() - y) <= regen_fill * float(rows.size()) + 0.001
		for x in range(line.length()):
			if line[x] == 'X':
				var c := regen_color if row_filled else fill_color
				# Highlight dot on top left
				if (x == 1 or x == 2) and y == 1:
					c = shine_color
				draw_rect(Rect2(pos.x + x * scale_factor, pos.y + y * scale_factor, scale_factor, scale_factor), c)
