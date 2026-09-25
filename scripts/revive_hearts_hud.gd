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
	_regen_label.position = Vector2(0.0, 28.0)
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

## YENİDEN TASARIM (kullanıcı isteği 2026-09-25: "kalan dirilme haklarımızın göründüğü kalpleri yeniden daha iyi bir şekilde
## pixel tarzda tasarla"): eski 7x6 düz dolgulu, kesirli ölçekli (x2.6 - pikseller eşit değildi) kalp yerine 11x10 sanat
## pikselli, TAM SAYI ölçekli (x2, keskin) kalp: koyu kontur, üç tonlu gölgeleme (sol üst açık, sağ alt koyu), iki pikselli
## parlama ve sert gölge. Boş kalp aynı biçimde koyu/cam gibi; yenilenen kalp alttan yukarı soluk kırmızıyla dolar.
const HEART_ROWS: Array[String] = [
	"..XXX.XXX..",
	".XXXXXXXXX.",
	"XXXXXXXXXXX",
	"XXXXXXXXXXX",
	"XXXXXXXXXXX",
	".XXXXXXXXX.",
	"..XXXXXXX..",
	"...XXXXX...",
	"....XXX....",
	".....X.....",
]
const PX := 2.0 ## sanat pikseli -> ekran pikseli (tam sayı: keskin)
const HEART_SPACING := 26.0
const C_OUTLINE := Color(0.16, 0.04, 0.07, 1.0)
const C_BASE := Color(0.9, 0.2, 0.28, 1.0)
const C_LIGHT := Color(1.0, 0.46, 0.5, 1.0)
const C_SHADE := Color(0.62, 0.09, 0.19, 1.0)
const C_SHINE := Color(1.0, 0.92, 0.9, 1.0)
const C_EMPTY := Color(0.2, 0.18, 0.22, 0.85)
const C_EMPTY_LIGHT := Color(0.34, 0.31, 0.36, 0.85)
const C_REGEN := Color(0.78, 0.34, 0.42, 1.0)


static func _in_heart(x: int, y: int) -> bool:
	return y >= 0 and y < HEART_ROWS.size() and x >= 0 and x < HEART_ROWS[y].length() and HEART_ROWS[y][x] == "X"


func _draw() -> void:
	for i in range(MAX_REVIVES):
		var active: bool = i < revives_remaining
		var pos := Vector2(4.0 + float(i) * HEART_SPACING, 4.0)
		## Yenilenen kalp (ilk boş kalp = 0. kalp): sayacın ilerlemesi kadarı aşağıdan yukarı soluk kırmızı dolar.
		var fill: float = 0.0
		if i == 0 and not active and _regen_left >= 0.0:
			fill = clampf(1.0 - _regen_left / GameManager.REVIVE_REGEN_INTERVAL, 0.0, 1.0)
		_draw_pixel_heart(pos, active, fill)


func _draw_pixel_heart(pos: Vector2, active: bool, regen_fill: float = 0.0) -> void:
	var h: int = HEART_ROWS.size()
	## Sert gölge (1 sanat pikseli sağ-aşağı)
	for y in range(h):
		for x in range(HEART_ROWS[y].length()):
			if _in_heart(x, y):
				draw_rect(Rect2(pos + Vector2(x + 1, y + 1) * PX, Vector2(PX, PX)), Color(0, 0, 0, 0.35))
	for y in range(h):
		var row_filled: bool = regen_fill > 0.0 and float(h - y) <= regen_fill * float(h) + 0.001
		for x in range(HEART_ROWS[y].length()):
			if not _in_heart(x, y):
				continue
			var edge: bool = not (_in_heart(x - 1, y) and _in_heart(x + 1, y) and _in_heart(x, y - 1) and _in_heart(x, y + 1))
			var c: Color
			if edge:
				c = C_OUTLINE
			elif active:
				## Sağ-alt kontura komşu iç pikseller koyu, sol üst bölge açık, kalan taban.
				if not _in_heart(x + 2, y) or not _in_heart(x, y + 2) or not _in_heart(x + 1, y + 1):
					c = C_SHADE
				elif x + y <= 5:
					c = C_LIGHT
				else:
					c = C_BASE
				if (x == 2 and y == 2) or (x == 3 and y == 2) or (x == 2 and y == 3):
					c = C_SHINE
			elif row_filled:
				c = C_REGEN
			else:
				c = C_EMPTY_LIGHT if (x + y <= 5) else C_EMPTY
			draw_rect(Rect2(pos + Vector2(x, y) * PX, Vector2(PX, PX)), c)
