extends Node2D

## Talon'un Silah Salvosu (E): karakter ile HER silahı arasında kırmızı/turuncu pixel-art zincirli bağ. Silahlar
## karakterin etrafında dönerken zincir uçları silah ikonlarını izler - yani bağ silahların konumuyla birlikte döner.
##  - Player (yetkili) ve RemotePlayer (kozmetik kopya) ikisi de bu sahnenin ebeveyni olabilir: silah konumları
##    player.owned_weapon_nodes / remote._weapon_icons'tan okunur, çizim iki tarafta AYNI koddur.
##  - Ömür: TalonMath.SALVO_DURATION (3sn) + kısa çıkış/toparlanma animasyonu; zincir merkezden dışa uzar, bitince toplanır.
## Bağ halkaları dönüşümlü olarak "halka" ve "çubuk" çizilir (pixel-art zincir okuması), üstünde merkezden silaha
## akan parlak bir kıvılcım gider.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const TalonMath := preload("res://scripts/talon_formation_math.gd")

const GROW_TIME := 0.2
const RETRACT_TIME := 0.25
const LINK_SPACING := 6.0 ## sanat pikseli (halka/çubuk sanatı 2x ölçekli çizilir: 6 sanat pikseli genişlik)

const RING_ART: Array = [
	"oyo",
	"y.y",
	"oyo",
]
const RING_PAL := {"o": Color(0.72, 0.16, 0.05), "y": Color(1.0, 0.58, 0.14)}
const BAR_H_ART: Array = ["yhy"]
const BAR_V_ART: Array = ["y", "h", "y"]
const BAR_PAL := {"y": Color(1.0, 0.5, 0.1), "h": Color(1.0, 0.86, 0.4)}

var _host: Node2D = null
var _t: float = 0.0


func _ready() -> void:
	top_level = true
	z_index = 0
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_host = get_parent() as Node2D
	global_position = Vector2.ZERO


func _life() -> float:
	return TalonMath.SALVO_DURATION + RETRACT_TIME


func _weapon_points() -> Array:
	var pts: Array = []
	if _host == null or not is_instance_valid(_host):
		return pts
	if "owned_weapon_nodes" in _host:
		for w in _host.owned_weapon_nodes:
			if is_instance_valid(w) and w.has_method("set_icon_offset"):
				pts.append((w as Node2D).global_position)
	elif "_weapon_icons" in _host:
		for ic in _host._weapon_icons:
			if is_instance_valid(ic):
				pts.append((ic as Node2D).global_position)
	return pts


func _process(delta: float) -> void:
	_t += delta
	if _host == null or not is_instance_valid(_host) or _t >= _life():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var extent: float = minf(1.0, _t / GROW_TIME)
	extent = minf(extent, clampf((_life() - _t) / RETRACT_TIME, 0.0, 1.0))
	if extent <= 0.0:
		return
	var origin: Vector2 = _host.global_position + Vector2(0, -6)
	var texel: float = PixelDraw.TEXEL
	var pts: Array = _weapon_points()
	## Merkez düğümü: gövdede küçük pixel halka (zincirlerin bağlandığı yer).
	PixelDraw.ring(self, origin, texel * 3.0, Color(1.0, 0.55, 0.12), 2)
	PixelDraw.px(self, origin, 2, Color(1.0, 0.9, 0.5))
	for j in range(pts.size()):
		var end_full: Vector2 = pts[j]
		var v: Vector2 = end_full - origin
		var length: float = v.length()
		if length < texel * 4.0:
			continue
		var dir: Vector2 = v / length
		var normal := Vector2(-dir.y, dir.x)
		var reach: float = length * extent
		var spacing: float = texel * LINK_SPACING
		var count: int = int(reach / spacing)
		var horizontal: bool = absf(dir.x) >= absf(dir.y)
		## Hafif sarkma/titreşim: bağ gergin ama canlı.
		var sag_amp: float = texel * 1.5 * sin(_t * 7.0 + float(j) * 1.9)
		for i in range(1, count + 1):
			var f: float = (float(i) - 0.5) * spacing / length
			var pos: Vector2 = origin + v * f + normal * sag_amp * sin(f * PI)
			if i % 2 == 0:
				PixelDraw.art(self, pos, RING_ART, RING_PAL, 2.0)
			else:
				PixelDraw.art(self, pos, BAR_H_ART if horizontal else BAR_V_ART, BAR_PAL, 2.0)
		## Merkezden silaha akan parlak kıvılcım.
		var spark_f: float = fmod(_t * 1.8 + float(j) * 0.31, 1.0)
		if spark_f * length <= reach:
			var sp: Vector2 = origin + v * spark_f
			PixelDraw.px(self, sp, 2, Color(1.0, 0.95, 0.65))
			PixelDraw.px(self, sp - dir * texel * 2.0, 1, Color(1.0, 0.7, 0.2))
		## Silah ucu: nabız gibi atan pixel halka (bağın silaha kenetlendiği yer).
		if extent >= 0.999:
			var pr: float = texel * (4.0 + 0.9 * sin(_t * 9.0 + float(j)))
			PixelDraw.ring(self, end_full, pr, Color(1.0, 0.5, 0.1), 1, 3, 2, _t * 10.0)
