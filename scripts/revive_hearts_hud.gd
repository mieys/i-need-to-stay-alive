extends Control
class_name ReviveHeartsHUD

## Mini heart-shaped Revive display on the left edge.
## Shows 3 retro pixel-art hearts, lighting up red when available, gray when consumed.
## Kullanıcı isteği (2026-09-24): her kalp eksildiğinde (2 kalp 8 dk, 1 kalp 6,5 dk, 0 kalp 5 dk) bir kalp yenilenir ve "altında da bekleme süresi
## görünsün" - sayaç GameManager'da (bkz. _process_revive_regen), burada ilk kalbin altında m:ss gösterilir ve
## yenilenen kalp dolum oranında soluk kırmızıyla aşağıdan yukarı dolar.

const MAX_REVIVES := 4 ## 3 + kalıcı "Dirilme Hakkı" geliştirmesi (meta_upgrades.gd); boş kalpler hep 3 çizilir, 4. sadece hak varsa
const BASE_SLOTS := 3
var revives_remaining: int = 3
var _slots_shown: int = BASE_SLOTS
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
	if _dock_mode:
		_process_dock(left)
		return
	var shown: bool = left >= 0.0
	if shown != _regen_label.visible:
		_regen_label.visible = shown
	if shown:
		var secs: int = int(ceil(left))
		var text: String = "%d:%02d" % [secs / 60, secs % 60]
		## Yanında bekleyen arkadaşlar sayacı hızlandırıyor (bkz. GameManager.REVIVE_REGEN_ASSIST_BONUS): "x2.6" gibi.
		var rate: float = GameManager.get_local_revive_regen_rate()
		if rate > 1.01:
			text += " x%.1f" % rate
		if _regen_label.text != text:
			_regen_label.text = text
	## Dolum çizimi saniyede birkaç kez yenilensin yeter (her kare queue_redraw gereksiz).
	if absf(left - _regen_left) >= 0.5 or (left < 0.0) != (_regen_left < 0.0):
		_regen_left = left
		queue_redraw()

## ---------------------------------------------------------------- PANEL KİPİ (masaüstü oyuncu paneli)
## 2026-10-14 (panel yeniden tasarımı, kullanıcı: "kalp yenilenme geri sayımı paneli de daima görünür olmalı" + "geri sayım
## çok ufak ve hiç okunmuyor"): kalpler panelin içinde, altlarında HER ZAMAN duran koyu sayaç levhası. Sayaç yokken "-:--"
## (soluk); yanında bekleyen arkadaş sayacı hızlandırırken (bkz. GameManager.REVIVE_REGEN_ASSIST_BONUS) yazı YEŞİL olur -
## "x2.6" çarpanı levhaya sığmıyor. Yazı kalın piksel yazı tipinin tam katında (PixeloidSans 9 x 3). Telefon bu kipi açmaz.
const PixelIcons := preload("res://scripts/hud_pixel_icons.gd")
const DOCK_FONT: Font = preload("res://assets/fonts/PixeloidSans-Bold.ttf")
const DOCK_FONT_SIZE := 27
const DOCK_CAP := 21.0 ## rakam yüksekliği (7 sanat pikseli x 3)
const DOCK_PLATE_TOP := 28.0
const DOCK_PLATE_H := 34.0
const HudTheme := preload("res://scripts/hud_theme.gd")
const DOCK_PLATE_FILL := HudTheme.INSET
const DOCK_TIMER_COLOR := Color(1.0, 0.78, 0.8)
const DOCK_TIMER_BOOST := Color(0.62, 1.0, 0.6)
const DOCK_TIMER_IDLE := HudTheme.DIM
var _dock_mode: bool = false
var _dock_text: String = "-:--"
var _dock_color: Color = DOCK_TIMER_IDLE


func set_dock_mode(on: bool) -> void:
	if on == _dock_mode:
		return
	_dock_mode = on
	if on:
		custom_minimum_size = Vector2.ZERO
		if _regen_label:
			_regen_label.visible = false
	queue_redraw()


func _process_dock(left: float) -> void:
	var text: String = "-:--"
	var color: Color = DOCK_TIMER_IDLE
	if left >= 0.0:
		var secs: int = int(ceil(left))
		text = "%d:%02d" % [secs / 60, secs % 60]
		color = DOCK_TIMER_BOOST if GameManager.get_local_revive_regen_rate() > 1.01 else DOCK_TIMER_COLOR
	if text != _dock_text or color != _dock_color or absf(left - _regen_left) >= 0.5 or (left < 0.0) != (_regen_left < 0.0):
		_dock_text = text
		_dock_color = color
		_regen_left = left
		queue_redraw()


func _draw_dock_plate() -> void:
	var r := Rect2(0.0, DOCK_PLATE_TOP, size.x, DOCK_PLATE_H)
	PixelIcons.draw_plate(self, r, DOCK_PLATE_FILL)
	var w: float = DOCK_FONT.get_string_size(_dock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, DOCK_FONT_SIZE).x
	var p := Vector2(roundf((size.x - w) * 0.5), roundf(r.position.y + (r.size.y + DOCK_CAP) * 0.5))
	draw_string(DOCK_FONT, p, _dock_text, HORIZONTAL_ALIGNMENT_LEFT, -1, DOCK_FONT_SIZE, _dock_color)


## Oyuncu paneli (hud.gd dock) kalpleri küçük bir sekmeye koyar - yenilenme sayacı kalplerin ALTINA değil yanına gelsin.
func set_regen_label_position(p: Vector2) -> void:
	if _regen_label:
		_regen_label.position = p


func is_regen_visible() -> bool:
	return _regen_label != null and _regen_label.visible


func set_revives(count: int) -> void:
	revives_remaining = clamp(count, 0, MAX_REVIVES)
	_slots_shown = maxi(_slots_shown, revives_remaining) ## 4. hak bir kez görüldüyse koşu boyunca 4. (boş) kalp de kalır
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
	var slots: int = maxi(BASE_SLOTS, maxi(_slots_shown, mini(GameManager.max_revives, MAX_REVIVES))) ## 4. kalp geliştirmesi varsa boşken de görünür (yenilenir)
	## 4 kalp 90 px'e sığsın diye sıkışık yerleşim (22 px kalp, boşluksuz); 3 kalpte eski aralık.
	var spacing: float = 22.0 if slots > BASE_SLOTS else HEART_SPACING
	var left: float = 2.0 if slots > BASE_SLOTS else 4.0
	if _dock_mode:
		## Panel kipi: kalp sırası levhanın üstünde ortalı (3 kalp 74 px, 4 kalp 88 px), altında sayaç levhası.
		left = roundf((size.x - (float(slots - 1) * spacing + 22.0)) * 0.5)
		_draw_dock_plate()
	for i in range(slots):
		var active: bool = i < revives_remaining
		var pos := Vector2(left + float(i) * spacing, 4.0)
		## Yenilenen kalp (ilk boş kalp = revives_remaining. kalp): sayacın ilerlemesi kadarı aşağıdan yukarı soluk kırmızı dolar.
		var fill: float = 0.0
		if i == revives_remaining and _regen_left >= 0.0:
			fill = clampf(1.0 - _regen_left / GameManager.revive_regen_interval(revives_remaining), 0.0, 1.0)
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
