extends Node
class_name WindowDragHandler

## Kullanıcı isteği: "dükkan/envanter v.b gibi pencereleri tutup sürükleyerek
## konumlarını değiştirebilelim istiyorum oyunda" - bu bileşen herhangi bir
## pencerenin (Control) kökü ALTINA ayrı bir Node olarak eklenip (mevcut
## shop_panel.gd/inventory_panel.gd/stats_panel.gd script'leriyle çakışmadan)
## belirtilen "tutamaç" (handle_path, ör. başlık çubuğu) üzerinde fare sol
## tuşu basılı tutulup sürüklenince pencereyi (window_path) taşır.
##
## Control.global_position kullanılır çünkü bu, anchor/offset ayarından
## BAĞIMSIZ olarak boyutu SABİT tutup sadece konumu kaydırır (Godot bunu
## offset_left/top'u güncelleyip offset_right/bottom'u da aynı miktarda
## kaydırarak yapar) - yani panel hangi anchor_preset'te olursa olsun çalışır.

@export var window_path: NodePath = NodePath("..")
@export var handle_path: NodePath
## Pencere ekran dışına tamamen sürüklenip kaybolmasın diye sınırlama.
@export var clamp_to_screen: bool = true

var _window: Control = null
var _handle: Control = null
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_window = get_node_or_null(window_path) as Control
	if not _window:
		push_warning("WindowDragHandler: window bulunamadı (%s)" % get_parent().name)
		return
	## ÖNEMLİ: handle_path, DragHandler node'una göre DEĞİL, pencerenin
	## (_window) kendisine göre çözülür - eskiden yanlışlıkla
	## get_node_or_null(handle_path) SELF (DragHandler) üzerinden
	## çağrılıyordu, ama DragHandler'ın hiç çocuğu yok (Frame/HeaderBG vb.
	## hepsi _window'un altında) - bu yüzden handle HER ZAMAN null bulunup
	## sürükleme hiç çalışmıyordu (bkz. kullanıcı bildirimi: "tutup çekme
	## kaydırma olayı falan olmadı").
	_handle = _window.get_node_or_null(handle_path) as Control
	if not _handle:
		push_warning("WindowDragHandler: handle bulunamadı (%s -> %s)" % [get_parent().name, handle_path])
		return
	## Tutamaç eskiden mouse_filter=IGNORE olabiliyordu (sadece görsel arka
	## plan amaçlıydı) - sürükleme sinyalini alabilmesi için STOP'a çekilir.
	_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_handle.gui_input.connect(_on_handle_gui_input)


func _on_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_offset = _window.get_global_mouse_position() - _window.global_position
		else:
			_dragging = false


func _process(_delta: float) -> void:
	if not _dragging or not _window:
		return
	var new_pos: Vector2 = _window.get_global_mouse_position() - _drag_offset
	if clamp_to_screen:
		var vp_size: Vector2 = _window.get_viewport_rect().size
		new_pos.x = clamp(new_pos.x, 0.0, max(0.0, vp_size.x - _window.size.x))
		new_pos.y = clamp(new_pos.y, 0.0, max(0.0, vp_size.y - _window.size.y))
	_window.global_position = new_pos
