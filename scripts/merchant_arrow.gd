extends Control

## Kullanıcı isteği: "seyyar satıcı geldiğinde oyunculara nerede olduğunun
## bildirimi verilmiyor (varolduğu sürece konumu ok ile gösterilmeli)" -
## minimap.gd'deki küçük "$" noktası (bkz. o dosya set_merchant_marker)
## yeterince fark edilmiyordu. Bu, kamera oyuncuyu ortaladığı için (bkz.
## player.tscn Camera2D, smoothing yok) ekran merkezi ETRAFINDA sabit bir
## yarıçapta duran, satıcının GERÇEK yönünü gösteren dönen bir ok - klasik
## "quest marker" tarzı. main.gd merchant_spawned/merchant_departed
## sinyalleriyle set_target_active(pos, true/false) çağırıp açıp kapatır.

const RING_RADIUS := 260.0
const ARROW_LENGTH := 26.0
const ARROW_WIDTH := 16.0
const HIDE_DISTANCE := 140.0 ## bu kadar yakınsa (etkileşim menzilinin biraz dışı) ok gizlenir - satıcının kendisi zaten görünür
const ARROW_FILL := Color(1.0, 0.85, 0.2, 0.95)
const ARROW_OUTLINE := Color(0.1, 0.08, 0.02, 0.85)

var _active: bool = false
var _target_pos: Vector2 = Vector2.ZERO
var _player: Node = null


func _ready() -> void:
	set_process(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_target_active(pos: Vector2, active: bool) -> void:
	_target_pos = pos
	_active = active
	queue_redraw()


func _process(_delta: float) -> void:
	if not _active:
		return
	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	queue_redraw()


func _draw() -> void:
	if not _active or not _player or not is_instance_valid(_player):
		return
	var to_target: Vector2 = _target_pos - _player.global_position
	var dist: float = to_target.length()
	if dist < HIDE_DISTANCE:
		return
	var dir: Vector2 = to_target / dist
	## Kamera oyuncuyu ortaladığı için (Camera2D oyuncunun ÇOCUĞU) ekran
	## merkezi ≈ oyuncunun ekran konumu - bkz. player.tscn.
	var center: Vector2 = size * 0.5
	var pos: Vector2 = center + dir * RING_RADIUS
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var tip: Vector2 = pos + dir * (ARROW_LENGTH * 0.5)
	var base_l: Vector2 = pos - dir * (ARROW_LENGTH * 0.5) + perp * (ARROW_WIDTH * 0.5)
	var base_r: Vector2 = pos - dir * (ARROW_LENGTH * 0.5) - perp * (ARROW_WIDTH * 0.5)
	var tri := PackedVector2Array([tip, base_l, base_r])
	draw_colored_polygon(tri, ARROW_FILL)
	draw_polyline(PackedVector2Array([tip, base_l, base_r, tip]), ARROW_OUTLINE, 2.5)
	var label: String = "Seyyar Satıcı"
	var font: Font = ThemeDB.fallback_font
	var label_pos: Vector2 = pos - dir * (ARROW_LENGTH * 0.5 + 4.0)
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(font, label_pos - Vector2(text_size.x * 0.5, 0.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.95, 0.8, 0.95))
