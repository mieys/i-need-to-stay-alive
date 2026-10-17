extends Node2D
class_name FxArcaneSkullBounce

## Büyücü Kız'ın Arcane Lanet varyasyonu: yaratıktan yaratığa seken LANET GÖZÜ (2026-10-16, madde 188, onaylanan prototip
## tools/proto_20261016/gen_buyucu_buyu.py scene_e_lanet). Eski mor kafatası + hayalet kopyalar kalktı (mekanik aynı - hasar player.gd
## _run_buyucu_arcane_bounce'ta, bu düğüm sadece görsel).
##  - badem göz (16 yön sayfası lanet_eye, krem iris + dikey göz bebeği, seyrek eflatun hale) kavisli yoldan uçar (yukarı şişkinlik),
##  - arkasında incelen eflatun iz + düşen rün kıvılcımları, ilk sekmede kalkış noktasında lanet mührü (lanet_cast),
##  - varınca FxArcaneImpact: eflatun patlama + yaratığın ayağına lanet mührü + kaynaktan hedefe çözülen "lanet ipi".
## Her sekme %12 büyük (hop; ses de tizleşiyor). Uzak kopya network_manager.gd "arcane_skull_bounce" -> setup_positions (+ "hop").

const BuyucuFxScript := preload("res://scripts/buyucu_fx.gd")
const FPS := 20.0 ## prototip 50 ms kare
const HOP_GROWTH := 0.12
const TRAIL_MAX := 34.0 ## iz uzunluğu üst sınırı (dünya)
const SPARK_EVERY := 1.0 / FPS
const SPARK_LIFE := 3.0 / FPS

var from_pos: Vector2 = Vector2.ZERO
var to_target: Node2D = null
var to_pos: Vector2 = Vector2.ZERO
var speed: float = 750.0
var elapsed: float = 0.0
## Kaçıncı sekme (0 = karakterden ilk kalkış) - boyut + kalkış mührü. Uzak kopyaya "hop" ile gider.
var hop: int = 0

var _base: Vector2 = Vector2.ZERO ## düz hat üstündeki ilerleme noktası (kavis bunun üstüne eklenir)
var _traveled: float = 0.0
var _normal: Vector2 = Vector2.UP
var _amp: float = 0.0
var _trail: Array = [] ## görsel konum geçmişi (dünya, Vector2)
var _sparks: Array = [] ## [dünya konumu, yaş]
var _spark_t: float = 0.0
var _eye: Sprite2D = null
var _started: bool = false


func setup(p_from: Vector2, p_target: Node2D) -> void:
	from_pos = p_from
	to_target = p_target
	to_pos = to_target.global_position if is_instance_valid(to_target) else from_pos
	_begin()


func setup_positions(p_from: Vector2, p_to: Vector2) -> void:
	from_pos = p_from
	to_target = null
	to_pos = p_to
	_begin()


func _ready() -> void:
	z_index = 45
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_eye = Sprite2D.new()
	_eye.texture = BuyucuFxScript.tex("lanet_eye")
	_eye.hframes = int(BuyucuFxScript.SHEETS["lanet_eye"])
	_eye.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_eye.scale = Vector2.ONE * BuyucuFxScript.PX * _size()
	_eye.visible = false
	add_child(_eye)


func _size() -> float:
	return 1.0 + HOP_GROWTH * float(hop)


## Kavisli yol: düz hat + yukarı doğru sinüs şişkinliği (FxArcaneImpact lanet ipi aynı formülü kullanır).
static func bulge(p0: Vector2, p1: Vector2) -> Array:
	var d: Vector2 = p1 - p0
	var L: float = maxf(d.length(), 1.0)
	var n := Vector2(-d.y, d.x) / L
	if n.y > 0.0:
		n = -n
	return [n, minf(16.0 * BuyucuFxScript.PX, L * 0.16)]


func _begin() -> void:
	_started = true
	_base = from_pos
	_traveled = 0.0
	var b: Array = bulge(from_pos, to_pos)
	_normal = b[0]
	_amp = b[1]
	global_position = from_pos
	_trail = [from_pos]
	if _eye:
		_eye.visible = true
		_eye.scale = Vector2.ONE * BuyucuFxScript.PX * _size()
	if hop == 0 and is_inside_tree():
		BuyucuFxScript.spawn_world(get_tree(), "lanet_cast", from_pos, 46, FPS, scale.x)


func _process(delta: float) -> void:
	if not _started:
		return
	elapsed += delta
	if is_instance_valid(to_target):
		to_pos = to_target.global_position
	var dir: Vector2 = to_pos - _base
	var dist: float = dir.length()
	var step: float = speed * delta
	if dist <= step or dist < 6.0 or elapsed > 1.5:
		_spawn_impact()
		queue_free()
		return
	_base += dir / dist * step
	_traveled += step
	var p: float = _traveled / maxf(_traveled + dist - step, 1.0)
	var prev: Vector2 = global_position
	global_position = _base + _normal * sin(PI * clampf(p, 0.0, 1.0)) * _amp
	var v: Vector2 = global_position - prev
	if v.length() > 0.01 and _eye:
		_eye.frame = posmod(int(round(v.angle() / (TAU / 16.0))), 16)
	_trail.append(global_position)
	var total: float = 0.0
	for i in range(_trail.size() - 1, 0, -1):
		total += _trail[i].distance_to(_trail[i - 1])
		if total > TRAIL_MAX * scale.x:
			_trail = _trail.slice(i - 1)
			break
	_spark_t += delta
	if _spark_t >= SPARK_EVERY:
		_spark_t = 0.0
		_sparks.append([_trail[maxi(0, _trail.size() - 4)], 0.0])
	for s in _sparks:
		s[1] = float(s[1]) + delta
		s[0] = (s[0] as Vector2) + Vector2(0.0, 1.5 * BuyucuFxScript.PX * delta * FPS)
	_sparks = _sparks.filter(func(s: Array) -> bool: return float(s[1]) < SPARK_LIFE)
	queue_redraw()


func _spawn_impact() -> void:
	if get_tree() == null or get_tree().current_scene == null:
		return
	var impact := Node2D.new()
	impact.set_script(preload("res://scripts/fx_arcane_impact.gd"))
	impact.set("p0", from_pos)
	impact.set("hop", hop)
	impact.set("fx_scale", scale.x)
	get_tree().current_scene.add_child(impact)
	impact.global_position = to_pos


func _draw() -> void:
	var px: float = BuyucuFxScript.PX
	var inv: float = 1.0 / maxf(scale.x, 0.01)
	var pal: Array[Color] = BuyucuFxScript.HEX
	## 1) incelen iz: baştan kuyruğa genişlik 3 -> 0,6 sanat pikseli; 4 katman (koyu kenar, orta, açık, parlak çekirdek)
	var n: int = _trail.size()
	if n >= 2:
		var L: float = 0.0
		for i in range(n - 1):
			L += _trail[i].distance_to(_trail[i + 1])
		var acc: float = 0.0
		var sz: float = _size()
		for i in range(n - 1, 0, -1):
			var a: Vector2 = (_trail[i] - global_position) * inv
			var b: Vector2 = (_trail[i - 1] - global_position) * inv
			var seg: float = _trail[i].distance_to(_trail[i - 1])
			var ka: float = acc / maxf(L, 0.01)
			acc += seg
			var kb: float = acc / maxf(L, 0.01)
			var d: Vector2 = b - a
			if d.length() < 0.01:
				continue
			var nn: Vector2 = Vector2(-d.y, d.x).normalized()
			var wa: float = lerpf(3.0, 0.6, ka) * px * sz * 0.5
			var wb: float = lerpf(3.0, 0.6, kb) * px * sz * 0.5
			for layer in [[px * 0.6, 1.0, pal[1]], [0.0, 1.0, pal[2]], [0.0, 0.58, pal[3]], [0.0, 0.25, pal[4]]]:
				var ex: float = layer[0]
				var k: float = layer[1]
				if k < 0.5 and ka > 0.5:
					continue
				draw_colored_polygon(PackedVector2Array([a + nn * (wa * k + ex), b + nn * (wb * k + ex), b - nn * (wb * k + ex), a - nn * (wa * k + ex)]), layer[2])
	## 2) düşen rün kıvılcımları (artı -> tek piksel)
	var s := Vector2(px, px)
	for sp in _sparks:
		var c: Vector2 = ((sp[0] as Vector2) - global_position) * inv
		var age: float = float(sp[1])
		if age < 1.0 / FPS:
			draw_rect(Rect2(c - s * 0.5, s), pal[4])
			for d2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_rect(Rect2(c + d2 * px - s * 0.5, s), pal[3])
		else:
			draw_rect(Rect2(c - s * 0.5, s), pal[3] if age < 2.0 / FPS else pal[2])
