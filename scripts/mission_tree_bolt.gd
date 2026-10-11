extends Node2D

## Görev ağacının kristal mermisi (2026-10-10; mission_tree.gd). Hedefe güdümlü küçük mavi kristal parçası + ışık izi, piksel tarzı (kodla çizilir).
## HER istemcide yerel doğar (ağaç her istemcide var, aynı hedefleme kuralı); hasarı SADECE damage > 0 olan (host / tek oyunculu) kopya işler.

const SPEED := 430.0
const MAX_LIFE := 1.6
const HIT_RADIUS := 10.0
const CORE := Color(0.62, 0.92, 1.0)
const EDGE := Color(0.22, 0.55, 0.9)
const TRAIL := Color(0.45, 0.8, 1.0, 0.45)

var target: Node2D = null
var damage: float = 0.0
var _dir := Vector2.RIGHT
var _life := 0.0
var _trail: PackedVector2Array = PackedVector2Array()


func setup(p_target: Node2D, p_damage: float) -> void:
	target = p_target
	damage = p_damage


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_life += delta
	if _life > MAX_LIFE:
		queue_free()
		return
	if target != null and is_instance_valid(target) and target.get("is_dead") != true:
		var to: Vector2 = target.global_position + Vector2(0.0, -10.0) - global_position
		if to.length() <= HIT_RADIUS + SPEED * delta:
			_hit()
			return
		_dir = to.normalized()
	elif _life > 0.3:
		queue_free()
		return
	_trail.append(global_position)
	if _trail.size() > 5:
		_trail.remove_at(0)
	global_position += _dir * SPEED * delta
	rotation = _dir.angle()
	queue_redraw()


func _hit() -> void:
	if damage > 0.0 and target.has_method("take_damage"):
		target.call("take_damage", damage)
	queue_free()


func _draw() -> void:
	## iz (yerel uzayda): eski konumlardan kristale doğru incelen çizgi
	for i in range(_trail.size()):
		var lp: Vector2 = to_local(_trail[i])
		var a: float = float(i + 1) / float(_trail.size() + 1)
		draw_rect(Rect2(lp.round() - Vector2(1, 1), Vector2(2, 2)), Color(TRAIL.r, TRAIL.g, TRAIL.b, TRAIL.a * a))
	## kristal: 7x3 piksel eşkenar dörtgen
	draw_colored_polygon(PackedVector2Array([Vector2(5, 0), Vector2(0, -2), Vector2(-4, 0), Vector2(0, 2)]), EDGE)
	draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(0, -1), Vector2(-2, 0), Vector2(0, 1)]), CORE)
