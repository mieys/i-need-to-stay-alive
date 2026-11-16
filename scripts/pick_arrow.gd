extends Control

## SEÇİM OKU (madde 759, 2026-11-16; kullanıcı 4 prototipten "D ile B'yi birleştir": altın çerçeve + işaretçi ok). Seçili kartın Gömme Tepsi
## çerçevesinin (PortraitFace.FramedPortrait) çocuğu, tam boy; aşağı bakan 9x6 sanat px ok: ucu çerçevenin üst kenarının 2 sanat px içinde,
## gövdesi çerçevenin üstünde. YEREL koordinatta çizilir -> düğmenin nefes / basma ölçeğiyle birlikte hareket eder. Açıkken her yarım
## periyotta 1 sanat px AŞAĞI iner (piksel adımı, yumuşak değil); yukarı zıplasa ilk satırda başlık çubuğuna değerdi.
## Kullanım: const PickArrow := preload("res://scripts/pick_arrow.gd"); var a := PickArrow.new(); a.t = 3.0; holder.add_child(a); a.set_on(true)

const HudTheme := preload("res://scripts/hud_theme.gd")
## o dış hat, H açık altın üst sıra, A altın
const ROWS: Array[String] = ["ooooooooo", "oHHHHHHHo", ".oAAAAAo.", "..oAAAo..", "...oAo...", "....o...."]
const BOB_PERIOD := 1.1

var t: float = 3.0
var _on: bool = false
var _dy: float = 0.0
var _time: float = 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_on(on: bool) -> void:
	if on == _on:
		return
	_on = on
	_time = 0.0
	_dy = 0.0
	set_process(on)
	queue_redraw()


func is_on() -> bool:
	return _on


func _process(delta: float) -> void:
	_time += delta
	var dy: float = t if fmod(_time, BOB_PERIOD) >= BOB_PERIOD * 0.5 else 0.0
	if dy != _dy:
		_dy = dy
		queue_redraw()


func _draw() -> void:
	if not _on:
		return
	var x0: float = floorf((size.x - 9.0 * t) * 0.5)
	var y0: float = -4.0 * t + _dy
	for y in ROWS.size():
		var row: String = ROWS[y]
		for x in row.length():
			var ch: String = row[x]
			if ch == ".":
				continue
			var c: Color = HudTheme.OUTLINE if ch == "o" else (HudTheme.PICK_FRAME_HI if ch == "H" else HudTheme.ACCENT)
			draw_rect(Rect2(x0 + x * t, y0 + y * t, t, t), c)
