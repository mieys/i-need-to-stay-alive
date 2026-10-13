extends Node2D

## Korsan "Patlat" menzil göstergesi (kullanıcı isteği 2026-10-12): Patlat artık sadece Korsan'ın KENDİ görüş alanındaki
## bombaları patlatır; bu ince, kesik çizgili elips o sınırı gösterir (sisin kendi elipsiyle AYNI formül:
## vision_fog.gd VISION_RADIUS x gece çarpanı, genişlik x VISION_WIDTH_SCALE). Sadece yerel oyuncuya görünür (kozmetik,
## senkron gerekmez), yerde bomba varken player.gd açar.

const VisionFogScript: GDScript = preload("res://scripts/vision_fog.gd")

const DASH_COUNT := 56
const POINTS_PER_DASH := 3
## Göz yormasın: sönük turuncu, ince, dolgu yok, nabız yok.
const COLOR := Color(1.0, 0.62, 0.25, 0.26)
const LINE_WIDTH := 1.4

var _radius: float = -1.0


func _ready() -> void:
	top_level = true ## oyuncunun 0,5 ölçeğini miras almasın, dünya birimiyle çizilsin
	z_index = 0 ## negatif z harita altında kalır (bkz. fx_korsan_zone.gd)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false


func _process(_delta: float) -> void:
	if not visible:
		return
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return
	global_position = parent.global_position
	var r: float = VisionFogScript.current_radius(get_tree())
	## Gece/gündüz geçişinde yarıçap her karede azıcık değişir; 56 kesikli antialiaslı çizgiyi her karede yeniden kurmamak için 1 px'lik adımlarla.
	if absf(r - _radius) >= 1.0 or _radius < 0.0:
		_radius = r
		queue_redraw()


func _draw() -> void:
	if _radius <= 0.0:
		return
	var rx: float = _radius * VisionFogScript.VISION_WIDTH_SCALE
	var ry: float = _radius
	var step: float = TAU / float(DASH_COUNT)
	## Her dilimin ilk yarısı çizilir, ikinci yarısı boş - kesik çizgi.
	for i: int in range(DASH_COUNT):
		var a0: float = step * float(i)
		var pts := PackedVector2Array()
		for k: int in range(POINTS_PER_DASH):
			var a: float = a0 + step * 0.5 * float(k) / float(POINTS_PER_DASH - 1)
			pts.append(Vector2(cos(a) * rx, sin(a) * ry))
		draw_polyline(pts, COLOR, LINE_WIDTH, true)
