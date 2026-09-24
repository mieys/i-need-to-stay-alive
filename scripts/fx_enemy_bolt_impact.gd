extends Node2D

## Menzilli yaratık mermisinin (enemy_projectile.gd) çarpma efekti - piksel tarzı (kullanıcı isteği 2026-09-23:
## "mermileri pixel tarzda yeniden tasarlar mısın"). Eskiden genel amaçlı fx_ring.gd'nin pürüzsüz, anti-aliased
## draw_arc halkasıydı. Artık mermi renginde genişleyip solan 8 piksellik halka + dışa savrulan 6 kıvılcım pikseli.
##
## PERF (iki pencereli gerçek testte ölçüldü - 200 Demon'da saniyede ~100 isabet, aynı anda ~30 efekt): ilk sürüm
## PixelDraw.ring ile her karede ~100 piksellik tam halka çiziyordu; SADECE bu efektler kaldırılınca host 27 -> 17.5
## ms'ye iniyordu. Artık halka 8 sabit yönlü piksel (yönler önceden hesaplı) ve aynı anda en fazla MAX_ALIVE efekt
## çiziliyor - oyuncunun üstünde üst üste binen 30 efekt zaten tek bir parlama gibi görünüyordu, fazlası atlanıyor.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const LIFE := 0.28
const MAX_ALIVE := 16
const RING_DIRS: Array[Vector2] = [
	Vector2(1, 0), Vector2(0.7071, 0.7071), Vector2(0, 1), Vector2(-0.7071, 0.7071),
	Vector2(-1, 0), Vector2(-0.7071, -0.7071), Vector2(0, -1), Vector2(0.7071, -0.7071),
]
## Kıvılcımlar halkayla çakışmasın diye ara açılarda (~22.5 derece kaydırılmış) ve farklı hızlarda.
const SPARK_DIRS: Array[Vector2] = [
	Vector2(0.924, 0.383), Vector2(-0.383, 0.924), Vector2(-0.924, -0.383),
	Vector2(0.383, -0.924), Vector2(-0.924, 0.383), Vector2(0.924, -0.383),
]

static var _alive: int = 0

var color: Color = Color(1.0, 0.55, 0.15, 1.0)
var _t: float = 0.0
var _counted: bool = false


func _ready() -> void:
	if _alive >= MAX_ALIVE:
		queue_free()
		return
	_alive += 1
	_counted = true
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _exit_tree() -> void:
	if _counted:
		_alive -= 1
		_counted = false


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var p: float = clampf(_t / LIFE, 0.0, 1.0)
	var ease_out: float = 1.0 - (1.0 - p) * (1.0 - p)
	var fade: float = 1.0 - p
	var hot: Color = color.lightened(0.45)
	## Çarpma anının ilk karelerinde parlak çekirdek.
	if p < 0.35:
		PixelDraw.px(self, Vector2.ZERO, 3, Color(hot.r, hot.g, hot.b, 0.9 * (1.0 - p / 0.35)))
	var ring_r: float = 4.0 + 14.0 * ease_out
	var ring_col := Color(color.r, color.g, color.b, fade * 0.9)
	for d in RING_DIRS:
		PixelDraw.px(self, d * ring_r, 1, ring_col)
	var spark_col := Color(hot.r, hot.g, hot.b, fade)
	for i in range(SPARK_DIRS.size()):
		PixelDraw.px(self, SPARK_DIRS[i] * (5.0 + (16.0 + float(i % 3) * 4.0) * ease_out), 1, spark_col)
