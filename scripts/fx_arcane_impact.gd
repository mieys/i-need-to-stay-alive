extends Node2D
class_name FxArcaneImpact

## Arcane Lanet kafatası düşmana çarptığında oluşan ARCANE PATLAMASI - PIXEL tarzı, SIFIRDAN (kullanıcı isteği, 2026-09-22: "büyücü kızın hortum ve
## arcane patlaması ile pasif skill efektini sıfırdan, daha iyi, pixel tarzda tasarla"). Eskiden 48x48'lik raster bir sprite sheet'ti; artık
## tamamen prosedürel 1-texel çizim (bkz. pixel_draw.gd, hafıza "Pixel density 48x48"), her istemcide aynı (bkz. fx_arcane_skull_bounce.gd _spawn_impact):
##   1. beyaz-eflatun çarpma parlaması (ilk 0.1 sn)
##   2. 8 kollu yıldız ışını (uzun/kısa dönüşümlü) - patlamanın "kırılma" hissi
##   3. iki genişleyen şok halkası (biri kesikli, ters yönde dönen) + koyu mor dither "boşluk" diski
##   4. dışa savrulan elmas kristal kırıkları (arcane parçalar)
##   5. merkezden yukarı süzülüp dağılan hayalet KAFATASI (lanetin imzası - projektil de aynı kafatasıdır)

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const LIFE := 0.6
const SKULL := [
	"..WWWWWWW..",
	".WLLLLLLLW.",
	"WLLLLLLLLLW",
	"WLLLLLLLLLW",
	"WLDDDLDDDLW",
	"WLDEDLDEDLW",
	"WLDDDLDDDLW",
	".WLLLDLLLW.",
	"..WLLLLLW..",
	"..WLWLWLW..",
	"...WWWWW...",
]

var elapsed: float = 0.0
var _seed: int = 0
var _shards: Array = [] ## [dir, dist_scale, kind]


func _ready() -> void:
	z_index = 50
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_seed = randi()
	for i in range(8):
		_shards.append([Vector2.from_angle(TAU * float(i) / 8.0 + randf_range(-0.2, 0.2)), randf_range(0.8, 1.2), i % 2])


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = PixelDraw.TEXEL
	var k: float = clampf(elapsed / LIFE, 0.0, 1.0)
	var ease_out: float = 1.0 - pow(1.0 - k, 2.4)
	var fade: float = 1.0 - pow(k, 1.6)
	## --- koyu mor dither "boşluk" diski (zemin izi) ---
	PixelDraw.disc_dither(self, Vector2.ZERO, (10.0 + 30.0 * ease_out) * 1.0, Color(0.32, 0.06, 0.5, 0.42 * fade), int(elapsed * 30.0), 1)
	## --- çarpma parlaması ---
	if k < 0.17:
		var fk: float = k / 0.17
		PixelDraw.disc(self, Vector2.ZERO, (1.0 - fk * 0.4) * 9.0 * t, Color(0.96, 0.86, 1.0, 1.0 - fk))
		PixelDraw.disc(self, Vector2.ZERO, (1.0 - fk) * 5.0 * t, Color(1, 1, 1, 1.0))
	## --- 8 kollu yıldız ışını ---
	for i in range(8):
		var a: float = TAU * float(i) / 8.0 + PI / 8.0
		var long_ray: bool = (i % 2) == 0
		var reach: float = ((26.0 if long_ray else 15.0) * ease_out + 4.0) * 1.0
		var dir: Vector2 = Vector2.from_angle(a)
		var steps: int = maxi(1, int(reach / t))
		for s in range(steps):
			var f: float = float(s) / float(steps)
			var col: Color = Color(0.98, 0.9, 1.0, fade) if f < 0.4 else Color(0.78, 0.4, 1.0, fade * (1.0 - f * 0.6))
			PixelDraw.px(self, dir * (3.0 * t + f * reach), 1, col)
	## --- şok halkaları ---
	PixelDraw.ring(self, Vector2.ZERO, 5.0 + 40.0 * ease_out, Color(0.86, 0.6, 1.0, fade * 0.95), 1)
	PixelDraw.ring(self, Vector2.ZERO, 3.0 + 24.0 * ease_out, Color(0.7, 0.36, 1.0, fade * 0.8), 1, 3, 2, -elapsed * 40.0)
	## --- elmas kristal kırıkları ---
	for sh in _shards:
		var dir2: Vector2 = sh[0]
		var pos: Vector2 = dir2 * (8.0 + 38.0 * ease_out * float(sh[1]))
		var col2: Color = Color(0.95, 0.8, 1.0, fade) if int(sh[2]) == 0 else Color(0.72, 0.44, 1.0, fade)
		PixelDraw.px(self, pos, 1, col2)
		PixelDraw.px(self, pos + Vector2(t, 0), 1, Color(col2, col2.a * 0.7))
		PixelDraw.px(self, pos + Vector2(-t, 0), 1, Color(col2, col2.a * 0.7))
		PixelDraw.px(self, pos + Vector2(0, t), 1, Color(col2, col2.a * 0.7))
		PixelDraw.px(self, pos + Vector2(0, -t), 1, Color(col2, col2.a * 0.7))
	## --- hayalet kafatası: yukarı süzülür, beyazdan mora solar ---
	if k > 0.08:
		var sk: float = (k - 0.08) / 0.92
		var a_skull: float = (1.0 - sk) * 0.9
		var pal: Dictionary = {
			"W": Color(0.42, 0.14, 0.62, a_skull),
			"L": Color(0.98, 0.9, 1.0, a_skull).lerp(Color(0.78, 0.5, 1.0, a_skull), sk),
			"D": Color(0.2, 0.04, 0.3, a_skull),
			"E": Color(1.0, 0.5, 1.0, a_skull),
		}
		PixelDraw.art(self, Vector2(0, -6.0 - 20.0 * sk), SKULL, pal, 1.0)
