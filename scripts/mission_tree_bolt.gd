extends Node2D

## Görev ağacının kristal mermisi (2026-10-10; mission_tree.gd). Hedefe güdümlü mavi kristal kıymığı + ışık izi, piksel tarzı (kodla çizilir).
## 2026-10-19 (kullanıcı: "ağacın attığı atışlar çok ufak ve görünmüyor"; madde 317): kıymık 9x4 -> 21x10 dünya px, toplamsal hale + kalın parlak iz +
## arkada sönen kıvılcımlar + isabette küçük parlama halkası (ortak çizim mission_tree_fx_draw.gd). Hasar isabet anında, parlama sonra söner.
## HER istemcide yerel doğar (ağaç her istemcide var, aynı hedefleme kuralı); hasarı SADECE damage > 0 olan (host / tek oyunculu) kopya işler.

const Fx := preload("res://scripts/mission_tree_fx_draw.gd")

const SPEED := 400.0
const MAX_LIFE := 1.6
const HIT_RADIUS := 10.0
const AIM_UP := Vector2(0.0, -10.0)
const TRAIL_PX := 44.0 ## iz boyu (dünya px)
const SPARK_EVERY := 0.035
const SPARK_LIFE := 0.3
const HIT_FX_TIME := 0.22

var target: Node2D = null
var damage: float = 0.0
var _dir := Vector2.RIGHT
var _life := 0.0
var _trail: PackedVector2Array = PackedVector2Array()
var _sparks: Array = [] ## [dünya konumu, yaş]
var _spark_acc := 0.0
var _hit_t := -1.0 ## >= 0: isabet parlaması oynuyor (mermi artık uçmuyor)
var _glow: Node2D = null


func setup(p_target: Node2D, p_damage: float) -> void:
	target = p_target
	damage = p_damage


func _ready() -> void:
	z_index = 6
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow = Fx.make_glow_child(self, _draw_glow)


func _redraw() -> void:
	queue_redraw()
	if _glow:
		_glow.queue_redraw()


func _process(delta: float) -> void:
	_life += delta
	for s: Array in _sparks:
		s[1] = float(s[1]) + delta
	while not _sparks.is_empty() and float(_sparks[0][1]) >= SPARK_LIFE:
		_sparks.remove_at(0)
	if _hit_t >= 0.0:
		_hit_t += delta
		if _hit_t >= HIT_FX_TIME and _sparks.is_empty():
			queue_free()
			return
		_redraw()
		return
	if _life > MAX_LIFE:
		queue_free()
		return
	if target != null and is_instance_valid(target) and target.get("is_dead") != true:
		var to: Vector2 = target.global_position + AIM_UP - global_position
		if to.length() <= HIT_RADIUS + SPEED * delta:
			global_position += to
			_hit()
			return
		_dir = to.normalized()
	elif _life > 0.3:
		queue_free()
		return
	_trail = Fx.push_trail(_trail, global_position, 3.0, TRAIL_PX)
	global_position += _dir * SPEED * delta
	_spark_acc += delta
	if _spark_acc >= SPARK_EVERY:
		_spark_acc = 0.0
		_sparks.append([global_position - _dir * 5.0 + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)), 0.0])
	_redraw()


func _hit() -> void:
	if damage > 0.0 and target.has_method("take_damage"):
		target.call("take_damage", damage)
	_hit_t = 0.0
	_trail.clear()
	_redraw()


func _draw() -> void:
	if _hit_t < 0.0:
		Fx.shard(self, Vector2.ZERO, _dir, 12.0, 9.0, 5.0)


## Toplamsal katman: iz, kıvılcımlar, baş halesi, isabet parlaması.
func _draw_glow(ci: Node2D) -> void:
	Fx.draw_trail(ci, _trail, 1.0, 5.0, Color(Fx.MID.r, Fx.MID.g, Fx.MID.b, 0.6), Color(Fx.CORE.r, Fx.CORE.g, Fx.CORE.b, 0.7))
	for s: Array in _sparks:
		var k: float = 1.0 - float(s[1]) / SPARK_LIFE
		var px: float = 2.0 if k > 0.5 else 1.0
		var p: Vector2 = ci.to_local(s[0]).round()
		ci.draw_rect(Rect2(p, Vector2(px, px)), Color(Fx.CORE.r, Fx.CORE.g, Fx.CORE.b, 0.9 * k))
	if _hit_t < 0.0:
		Fx.disc(ci, Vector2.ZERO, 12.0, Color(Fx.MID.r, Fx.MID.g, Fx.MID.b, 0.14))
		Fx.disc(ci, Vector2.ZERO, 8.0, Color(Fx.MID.r, Fx.MID.g, Fx.MID.b, 0.24))
		return
	var k2: float = clampf(_hit_t / HIT_FX_TIME, 0.0, 1.0)
	Fx.disc(ci, Vector2.ZERO, 3.0 + 7.0 * k2, Color(Fx.CORE.r, Fx.CORE.g, Fx.CORE.b, 0.55 * (1.0 - k2)))
	Fx.ring(ci, Vector2.ZERO, 4.0 + 12.0 * k2, Color(Fx.MID.r, Fx.MID.g, Fx.MID.b, 0.85 * (1.0 - k2)), 2.0)
	for j in range(6):
		var p2: Vector2 = (Vector2.from_angle(TAU * float(j) / 6.0 + 0.3) * (3.0 + 14.0 * k2)).round()
		ci.draw_rect(Rect2(p2 - Vector2(1, 1), Vector2(2, 2)), Color(Fx.CORE.r, Fx.CORE.g, Fx.CORE.b, 1.0 - k2))
