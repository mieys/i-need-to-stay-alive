extends Node2D
class_name FxArcaneImpact
## Arcane Lanet gözünün yaratığa çarpması (2026-10-16, madde 188, onaylanan prototip; eski kafatası + 8 kollu yıldız + şok halkaları kalktı).
## fx_arcane_skull_bounce.gd _spawn_impact kurar (kaster ve uzak kopya aynı yol):
##   1. eflatun patlama (lanet_burst, dolu kütleler, dumana döner)
##   2. yaratığın ayağına basılan 2:1 lanet mührü (lanet_brand, dönen 4 rün çentiği, sonra kırılır) - zeminde, yaratıkların altında
##   3. kaynaktan hedefe kavisli "lanet ipi" (noktalı, kaynak ucundan çözülür) - zincir okunsun
## Her sekme %12 büyür (hop), Efsunlu Büyü ölçeği fx_scale.

const BuyucuFxScript := preload("res://scripts/buyucu_fx.gd")
const BounceScript := preload("res://scripts/fx_arcane_skull_bounce.gd")
const FPS := 20.0
const THREAD_LIFE := 8.0 / FPS
## Ayak mührü gövde merkezinin bu kadar altında (sanat pikseli; prototipte göz gövdeye, mühür ayağa).
const BRAND_DROP := 8.0

var p0: Vector2 = Vector2.ZERO ## sekmenin kalkış noktası (lanet ipi buradan)
var hop: int = 0
var fx_scale: float = 1.0
var elapsed: float = 0.0
var _n: Vector2 = Vector2.UP
var _amp: float = 0.0


func _ready() -> void:
	z_index = 50
	var size: float = fx_scale * (1.0 + BounceScript.HOP_GROWTH * float(hop))
	var pos: Vector2 = global_position
	## global_position add_child'dan SONRA kurulur - sayfalar bir kare sonra doğsun.
	call_deferred("_spawn_sheets", size)
	var b: Array = BounceScript.bulge(p0, pos)
	_n = b[0]
	_amp = b[1]


func _spawn_sheets(size: float) -> void:
	if not is_inside_tree():
		return
	var tree: SceneTree = get_tree()
	BuyucuFxScript.spawn_world(tree, "lanet_burst", global_position, 50, FPS, size)
	BuyucuFxScript.spawn_world(tree, "lanet_brand", global_position + Vector2(0.0, BRAND_DROP * BuyucuFxScript.PX * size), 0, FPS, size)
	var b: Array = BounceScript.bulge(p0, global_position)
	_n = b[0]
	_amp = b[1]


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= THREAD_LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var px: float = BuyucuFxScript.PX
	var pal: Array[Color] = BuyucuFxScript.HEX
	var k: float = elapsed / THREAD_LIFE
	var p1: Vector2 = global_position
	var s := Vector2(px, px)
	for q in range(40):
		var t: float = float(q) / 39.0
		if t < k or (q % 2 == 1 and k > 0.4):
			continue
		var w: Vector2 = p0.lerp(p1, t) + _n * sin(PI * t) * _amp
		draw_rect(Rect2(w - p1 - s * 0.5, s), pal[3] if q % 3 else pal[2])
