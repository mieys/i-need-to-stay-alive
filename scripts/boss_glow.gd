extends Node2D

## BOSS PARILTISI (Uçan Şeytan FİNAL: "dışa doğru parıltılı olmalı", 2026-10-09): bossun ARKASINDA, toplamalı (additive) yumuşak dairesel hale; nefes alır. Her peer yerelde kurar (kozmetik).
## Renk faz/büyüye göre değişir (set_glow_color): mavi-mor (normal), kızıl (faz 2), yeşil (iyileşme). Boss'un çocuğu, `show_behind_parent` ile sprite'ın altında.

const BASE_RADIUS := 150.0
var _color: Color = Color(0.5, 0.4, 1.0)
var _target: Color = Color(0.5, 0.4, 1.0)
var _radius: float = BASE_RADIUS
var _t: float = 0.0
static var _tex: GradientTexture2D = null


static func attach(boss: Node2D, radius: float = BASE_RADIUS) -> Node2D:
	var existing: Node = boss.get_node_or_null("BossGlow")
	if existing != null:
		return existing as Node2D
	var g := Node2D.new()
	g.set_script(load("res://scripts/boss_glow.gd"))
	g.name = "BossGlow"
	g.set("_radius", radius)
	boss.add_child(g)
	return g


func _ready() -> void:
	show_behind_parent = true
	z_index = -1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	if _tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1.0, 1.0, 1.0, 0.85))
		grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		_tex = GradientTexture2D.new()
		_tex.gradient = grad
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(0.5, 0.0)
		_tex.width = 256
		_tex.height = 256


func set_glow_color(c: Color) -> void:
	_target = c


func _process(delta: float) -> void:
	_t += delta
	_color = _color.lerp(_target, clampf(delta * 3.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	var pulse: float = 1.0 + 0.08 * sin(_t * 2.4)
	var r: float = _radius * pulse
	draw_texture_rect(_tex, Rect2(Vector2(-r, -r - 30.0), Vector2(r * 2.0, r * 2.0)), false, Color(_color.r, _color.g, _color.b, 0.55 + 0.1 * sin(_t * 2.4)))
