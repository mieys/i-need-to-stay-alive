extends CanvasLayer

## GRAFİK AYARLARI penceresi - kullanıcı isteği (2026-10-03): "Düşük / Orta / Yüksek" hazır seviye + altında tek tek
## seçenekler, PC ve telefonda aynı. Ana menü ve duraklatma menüsündeki "Grafik" butonu açar (keybind_menu.gd ile AYNI
## "kendi penceresi olan, kodla kurulan popup" deseni - iki menüde ikinci bir kopya YOK). Değerler ve kaydetme tek yerde:
## UISound (GRAFİK AYARLARI notu); bu ekran sadece o API'yi çağırır. Bir seçenek elle değişirse seviye "Özel" görünür.

signal closed

const ROW_FS := 32
const BTN_FS := 32
const HINT_FS := 24

var _preset_buttons: Array[Button] = []
var _preset_label: Label = null
var _sun_check: CheckButton = null
var _ground_check: CheckButton = null
var _scale_buttons: Array[Button] = []
var _fps_buttons: Array[Button] = []


func _ready() -> void:
	add_to_group(&"gamepad_modal") ## kumandayla menü gezinmesi: açılınca ilk düğmeye odak (bkz. gamepad_ui.gd)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_build_ui()
	_refresh()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.03, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.theme = UIKit.theme()
	add_child(center)

	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(980, 0)
	outer.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
	center.add_child(outer)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	outer.add_child(v)

	var title := Label.new()
	title.text = "GRAFİK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(title, UIKit.FS_TITLE, UIKit.C_ACCENT, 0)
	v.add_child(title)

	## Kalite seviyesi
	var preset_row := _row(v, "Kalite")
	for i in range(3): ## Düşük / Orta / Yüksek ("Özel" seçilemez, sadece gösterilir)
		var b := _choice_button(UISound.GFX_PRESET_NAMES[i])
		var p: int = i
		b.pressed.connect(func() -> void:
			UISound.set_gfx_preset(p)
			_refresh())
		preset_row.add_child(b)
		_preset_buttons.append(b)
	_preset_label = Label.new()
	UIKit.style_label(_preset_label, HINT_FS, UIKit.C_TEXT_DIM, 0)
	_preset_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_preset_label)

	## Tek tek seçenekler
	_sun_check = CheckButton.new()
	_sun_check.toggled.connect(func(on: bool) -> void:
		UISound.set_gfx_option("sun_clouds", on)
		_refresh())
	_row(v, "Güneş ışığı / bulut gölgesi").add_child(_sun_check)

	_ground_check = CheckButton.new()
	_ground_check.toggled.connect(func(on: bool) -> void:
		UISound.set_gfx_option("ground_detail", on)
		_refresh())
	_row(v, "Zemin ayrıntısı").add_child(_ground_check)

	var scale_row := _row(v, "Çözünürlük")
	for s: float in UISound.RENDER_SCALES:
		var b := _choice_button("%%%d" % roundi(s * 100.0))
		var sv: float = s
		b.pressed.connect(func() -> void:
			UISound.set_gfx_option("render_scale", sv)
			_refresh())
		scale_row.add_child(b)
		_scale_buttons.append(b)

	var fps_row := _row(v, "FPS sınırı")
	for f: int in UISound.FPS_LIMITS:
		var b := _choice_button(str(f) if f > 0 else "Sınırsız")
		var fv: int = f
		b.pressed.connect(func() -> void:
			UISound.set_fps_limit(fv)
			_refresh())
		fps_row.add_child(b)
		_fps_buttons.append(b)

	var hint := Label.new()
	hint.text = "Oyun kasıyorsa kaliteyi düşür. Çözünürlük sadece oyun dünyasını etkiler, arayüz her zaman net kalır."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(hint, HINT_FS, UIKit.C_TEXT_DIM, 0)
	v.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "KAPAT"
	close_btn.custom_minimum_size = Vector2(0, 56)
	UIKit.style_button(close_btn, "wood", false, UIKit.FS_BODY)
	close_btn.pressed.connect(_on_close_pressed)
	v.add_child(close_btn)

	UISound.connect_all_buttons(self)


## Etiketli bej satır; sağ taraftaki kutuyu döndürür (butonlar/onay kutusu buna eklenir).
func _row(parent: Control, text: String) -> HBoxContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIKit.panel_style("inset"))
	parent.add_child(row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var l := Label.new()
	l.text = text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.style_label(l, ROW_FS, UIKit.C_TEXT, 0)
	h.add_child(l)
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	h.add_child(right)
	return right


func _choice_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 56)
	return b


func _style_choice(b: Button, selected: bool) -> void:
	UIKit.style_button(b, "green" if selected else "wood", false, BTN_FS)


func _refresh() -> void:
	for i in range(_preset_buttons.size()):
		_style_choice(_preset_buttons[i], UISound.gfx_preset == i)
	var name_now: String = UISound.GFX_PRESET_NAMES[UISound.gfx_preset]
	_preset_label.text = "Şu an: " + name_now + ("  (seçenekler elle değiştirildi)" if UISound.gfx_preset == UISound.GfxPreset.CUSTOM else "")
	_sun_check.set_pressed_no_signal(UISound.gfx_sun_clouds)
	_ground_check.set_pressed_no_signal(UISound.gfx_ground_detail)
	for i in range(_scale_buttons.size()):
		_style_choice(_scale_buttons[i], is_equal_approx(UISound.RENDER_SCALES[i], UISound.gfx_render_scale))
	for i in range(_fps_buttons.size()):
		_style_choice(_fps_buttons[i], UISound.FPS_LIMITS[i] == UISound.fps_limit)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
