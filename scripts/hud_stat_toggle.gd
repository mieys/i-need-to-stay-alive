extends Control

## Portrenin (seviye rozetinin) altındaki küçük düğme: mini stat panelini (hud_stat_panel.gd) açar/kapar - kullanıcı isteği 2026-10-14
## ("normalde kapalı olacak ancak karakter portresinin altındaki boşlukta butonla açılacak"). Seçilen prototip "B": koyu levha +
## küçük çubuk grafik + yön oku (kapalı "<" = sola açılır, açık ">" + basılı). Açık/kapalı oturum içinde hatırlanır.

const PixelIcons := preload("res://scripts/hud_pixel_icons.gd")
const SIZE := Vector2(64, 20)
const HudTheme := preload("res://scripts/hud_theme.gd")
const OUTLINE := HudTheme.OUTLINE
const PLATE := HudTheme.INSET
const PLATE_ON := HudTheme.PLATE_ON
const PLATE_HOVER := HudTheme.PLATE_HOVER
const GOLD := Color(0.98, 0.82, 0.30)
const VALUE := Color(0.97, 0.93, 0.84)
const ARROW_CLOSED: Array[String] = ["..X", ".XX", "XXX", ".XX", "..X"]
const ARROW_OPEN: Array[String] = ["X..", "XX.", "XXX", "XX.", "X.."]
const BARS: Array[int] = [4, 8, 6, 11]

static var remembered_open: bool = false

var panel: Control = null ## hud.gd bağlar
var _hover: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tooltip_text = "İstatistikler"
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())


func bind_panel(p: Control) -> void:
	panel = p
	if is_instance_valid(panel):
		panel.visible = remembered_open
	queue_redraw()


func is_open() -> bool:
	return is_instance_valid(panel) and panel.visible


func set_open(on: bool) -> void:
	remembered_open = on
	if is_instance_valid(panel):
		panel.visible = on
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		UISound.play_click()
		set_open(not is_open())
		accept_event()


func _draw() -> void:
	var on: bool = is_open()
	var d := Vector2(0, 1) if on else Vector2.ZERO
	PixelIcons.draw_plate(self, Rect2(Vector2.ZERO, size), PLATE_ON if on else (PLATE_HOVER if _hover else PLATE))
	draw_rect(Rect2(Vector2(2, 2), Vector2(size.x - 4, 1)), Color(GOLD, 0.55) if on else HudTheme.RIM_LO)
	var lit: bool = on or _hover
	for i in BARS.size():
		var h: int = BARS[i]
		draw_rect(Rect2(Vector2(25 + i * 5, 15 - h) + d, Vector2(4, h)), OUTLINE)
		draw_rect(Rect2(Vector2(26 + i * 5, 16 - h) + d, Vector2(2, h - 2)), GOLD if lit else VALUE)
	PixelIcons.draw_flat(self, ARROW_OPEN if on else ARROW_CLOSED, Vector2(9, 5) + d, 2.0, GOLD)
