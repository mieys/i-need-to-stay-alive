extends Node2D

## PROTOTİP (oyuna bağlı DEĞİL): Shaman E aura sınırı düğümü. HARİTANIN İÇİNDE zemin + su katmanlarının hemen arkasına girer (place_in_map):
## zeminin/suyun üstü, ağaç/ev/çalı/köprü/plato ve bütün karakterlerin altı. (İlk denemede GroundSlot kuralıyla "Harita"nın arkasındaydı ->
## 440 birimlik halka evin çatısının ve ağaçların ÜSTÜNDEN geçiyordu; küçük zemin efektlerinde fark edilmeyen sorun.) Düğüm dönüşümü
## kimlik (dünya = yerel), shader dünya ızgarasında çizer.
## Yarıçap her karede totemin KENDİ totem_radius'undan okunur ("Geniş Alan" evrimi x1,3 kendiliğinden izlenir).
## Açılış: yarıçap 0,45 sn'de taştan dışa açılır (ease-out), perde boyu 0,6 sn'de büyür. stop(): 0,45 sn'de söner ve silinir.

const SHADER_PATH := "res://tools/proto_20261111/shaman_aura/aura_sinir.gdshader"
const OPEN_TIME := 0.45
const GROW_TIME := 0.6
const FADE_TIME := 0.45
const MARGIN := 24.0 ## dünya: perde (en çok ~10 hücre) + koyu dudak payı

var variant: int = 0
var totem: Node2D = null
var _mat: ShaderMaterial = null
var _t: float = 0.0
var _fade: float = -1.0
var _drawn_r: float = -1.0


## Haritanın zemin katmanlarının (ana harita: "Yer" + "Su") hemen arkasına koy. Harita/katman yoksa sahnede olduğu yerde kalır.
static func place_in_map(node: Node2D, scene_root: Node) -> void:
	var map_node: Node = scene_root.get_node_or_null("Harita")
	if map_node == null:
		scene_root.add_child(node)
		return
	var after: Node = map_node.get_node_or_null("Su")
	if after == null:
		after = map_node.get_node_or_null("Yer")
	map_node.add_child(node)
	if after != null:
		map_node.move_child(node, after.get_index() + 1)


func _ready() -> void:
	z_index = 0
	z_as_relative = true
	global_position = Vector2.ZERO
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER_PATH)
	_mat.set_shader_parameter("variant", variant)
	material = _mat
	_sync()


func stop() -> void:
	if _fade < 0.0:
		_fade = 0.0


func _full_radius() -> float:
	if totem != null and is_instance_valid(totem):
		var v: Variant = totem.get("totem_radius")
		if v != null:
			return float(v)
	return 220.0


func _center() -> Vector2:
	if totem != null and is_instance_valid(totem):
		return totem.global_position
	return Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
	if _fade >= 0.0:
		_fade += delta
		if _fade >= FADE_TIME:
			queue_free()
			return
	_sync()


func _sync() -> void:
	var open_k: float = clampf(_t / OPEN_TIME, 0.0, 1.0)
	open_k = 1.0 - pow(1.0 - open_k, 3.0)
	var r: float = _full_radius() * maxf(open_k, 0.02)
	var a: float = clampf(_t / 0.3, 0.0, 1.0)
	if _fade >= 0.0:
		a *= 1.0 - clampf(_fade / FADE_TIME, 0.0, 1.0)
	_mat.set_shader_parameter("center", _center())
	_mat.set_shader_parameter("radius", r)
	_mat.set_shader_parameter("time_s", _t)
	_mat.set_shader_parameter("alpha_mult", a)
	_mat.set_shader_parameter("grow", clampf(_t / GROW_TIME, 0.0, 1.0))
	var full: float = _full_radius()
	if not is_equal_approx(full, _drawn_r):
		_drawn_r = full
		queue_redraw()


func _draw() -> void:
	var c: Vector2 = _center()
	var h: float = _drawn_r + MARGIN
	var a: Vector2 = to_local(c - Vector2(h, h))
	var b: Vector2 = to_local(c + Vector2(h, h))
	draw_rect(Rect2(a, b - a), Color.WHITE)
