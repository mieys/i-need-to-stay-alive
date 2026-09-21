extends Node2D
class_name MatthewFoxShieldFx

## Matthew'ün ULTİ'sinin (Feda Kalkanı) tilki kulaklı pixel-art sihirli bariyeri. Tamamen kod ile, pixel_draw.gd'nin
## sanat-piksel ızgarasında çizilir (yumuşak daire/çokgen yok):
##  - basamaklı pixel halka + kenarda dönen parlak kesik çizgiler
##  - içi dither/tarama çizgili "sihirli cam" dolgu, yukarı kayan parlak şerit
##  - üstte iki büyük pixel tilki kulağı (arada bir seğirir)
##  - içeride dönen 3 tilki ateşi (kitsune-bi) küresi, arkasında pixel kuyruk
##  - patlayınca (pop) halka kırılıp pixel kıymıklar saçılır, kulaklar düşer
## Hem kaster'da hem (remote_player.gd _ensure_matthew_dome_visual) diğer istemcilerde AYNI sahne/çizim kullanılır.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const RADIUS: float = 44.0
const POP_DURATION: float = 0.4

const C_DARK := Color(0.6, 0.24, 0.02)
const C_ORANGE := Color(1.0, 0.6, 0.1)
const C_BRIGHT := Color(1.0, 0.8, 0.3)
const C_CREAM := Color(1.0, 0.95, 0.72)
const C_RED := Color(0.85, 0.28, 0.05)

## Sol kulak (sağ kulak = flip_x). o koyu kenar, a turuncu, b parlak kenar, c krem iç. 14x13 sanat pikseli.
const EAR_ART: Array = [
	"...oo.........",
	"..oaao........",
	"..oabao.......",
	".oaabbao......",
	".oaaccbao.....",
	"oaaacccbao....",
	"oaaaccccbao...",
	"oaaacccccbao..",
	"oaaaccccccbao.",
	"oaaacccccccbbo",
	".oaaaccccccbo.",
	"..oaaaccccbbo.",
	"...oooooooooo.",
]
const EAR_PALETTE := {
	"o": C_DARK,
	"a": C_ORANGE,
	"b": C_BRIGHT,
	"c": C_CREAM,
}

var elapsed: float = 0.0
var popping: bool = false
var pop_elapsed: float = 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	if popping:
		pop_elapsed += delta
		if pop_elapsed >= POP_DURATION:
			queue_free()
			return
	else:
		elapsed += delta
	queue_redraw()


func pop() -> void:
	if popping:
		return
	popping = true
	pop_elapsed = 0.0


func _c(col: Color, a_mult: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * a_mult)


func _draw() -> void:
	var t: float = elapsed
	var p: float = (pop_elapsed / POP_DURATION) if popping else 0.0
	var alive: float = 1.0 - p
	var texel: float = PixelDraw.TEXEL
	## Nefes: yarıçap 1 sanat pikseli iner/çıkar (basamaklı, yumuşak ölçek yok).
	var breath: float = roundf(sin(t * 2.8)) * texel
	var r: float = (RADIUS + breath) * (1.0 + p * 0.35)
	var rt: int = int(r / texel)

	## --- Sihirli cam dolgu: iki satırda bir tarama çizgisi + yukarı kayan parlak şerit ---
	var band_row: int = int(t * 16.0) % maxi(rt, 1)
	for iy in range(-rt, rt + 1, 2):
		var hw: float = sqrt(maxf(0.0, float(rt * rt) - float(iy * iy))) * texel
		if hw < texel:
			continue
		var y: float = float(iy) * texel
		var dist_to_band: int = absi(iy - (rt - 2 * band_row))
		var col: Color = C_ORANGE
		var a: float = 0.2
		if dist_to_band <= 2:
			col = C_BRIGHT
			a = 0.42
		draw_rect(Rect2(-hw, y - texel * 0.5, hw * 2.0, texel), _c(col, a * alive))

	## --- Halka: kalın turuncu + koyu iç kenar + dönen parlak kesikler + sol-üst vurgu ---
	PixelDraw.ring(self, Vector2.ZERO, r - texel * 1.6, _c(C_DARK, 0.9 * alive), 1)
	if not popping:
		PixelDraw.ring(self, Vector2.ZERO, r, C_ORANGE, 2)
		PixelDraw.ring(self, Vector2.ZERO, r, C_BRIGHT, 2, 5, 11, t * 22.0)
		PixelDraw.ring(self, Vector2.ZERO, r - texel * 0.4, C_CREAM, 1, 0, 0, 0.0, deg_to_rad(200.0), deg_to_rad(70.0))
		## 8 rün işareti (halkanın üstünde) - çift-tek sırayla nabız atar.
		for k in range(8):
			var a2: float = float(k) * TAU / 8.0 + PI / 8.0
			var pulse: bool = int(t * 3.0 + float(k)) % 2 == 0
			PixelDraw.px(self, Vector2(cos(a2), sin(a2)) * (r + texel * 2.0), 2 if pulse else 1, C_CREAM)
	else:
		## Kırılan halka: kesikler açılır.
		PixelDraw.ring(self, Vector2.ZERO, r, _c(C_ORANGE, alive), 2, 4, 5 + int(p * 30.0), p * 10.0)

	## --- Tilki kulakları (arada bir seğirir; patlamada düşer) ---
	var flick: float = -texel if (fmod(t, 2.6) < 0.12 and not popping) else 0.0
	var fall: float = p * p * 34.0
	var ear_alpha: float = alive
	var ear_pal: Dictionary = {}
	for key in EAR_PALETTE:
		ear_pal[key] = _c(EAR_PALETTE[key], ear_alpha)
	var ear_h: float = float(EAR_ART.size()) * texel
	var left_base := Vector2(cos(deg_to_rad(-124.0)), sin(deg_to_rad(-124.0))) * (r - texel * 1.0)
	var right_base := Vector2(cos(deg_to_rad(-56.0)), sin(deg_to_rad(-56.0))) * (r - texel * 1.0)
	PixelDraw.art(self, left_base + Vector2(-texel * 3.0, -ear_h * 0.42 + flick + fall), EAR_ART, ear_pal, 1.0, false)
	PixelDraw.art(self, right_base + Vector2(texel * 3.0, -ear_h * 0.42 + flick + fall), EAR_ART, ear_pal, 1.0, true)

	## --- Tilki ateşi küreleri (kitsune-bi): daire boyunca dönen 3 küre, arkasında sönen pixel kuyruk ---
	if not popping:
		for k in range(3):
			var base_a: float = t * 1.5 + float(k) * TAU / 3.0
			var orbit_r: float = r * 0.74
			for tail in range(5, -1, -1):
				var ta: float = base_a - float(tail) * 0.13
				var pos: Vector2 = Vector2(cos(ta), sin(ta) * 0.92) * orbit_r
				if tail == 0:
					PixelDraw.px(self, pos, 5, C_ORANGE)
					PixelDraw.px(self, pos, 3, C_BRIGHT)
					PixelDraw.px(self, pos + Vector2(0, -texel * 3.0 - roundf(sin(t * 18.0 + float(k)) * texel)), 2, C_CREAM)
				else:
					PixelDraw.px(self, pos, 3 if tail < 3 else 2, PixelDraw.fire_color(float(tail) / 6.0))
	else:
		## Kıymıklar: halkadan dışa saçılan pixel parçalar.
		for k in range(28):
			var ang: float = PixelDraw.hash01(k + 11) * TAU
			var speed_f: float = 0.85 + PixelDraw.hash01(k + 71) * 0.9
			var spos: Vector2 = Vector2(cos(ang), sin(ang)) * (r + p * r * speed_f)
			var sz: int = 2 if p < 0.55 else 1
			PixelDraw.px(self, spos, sz, _c(C_BRIGHT if k % 3 != 0 else C_RED, alive))
