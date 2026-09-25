extends Node2D
class_name WaveBeamFx

## Melek'in (ve Oakley'nin Koruyucu Büyü'sünün) dosta kurduğu bağ: caster'dan hedefe doğru AKAN pixel-art enerji
## dalgası. fx_type: "heal" (can: yeşil dalga + akan kalpler) ya da "shield" (kalkan: mavi kırık/açısal dalga + akan
## kalkan rozetleri ve ok uçları). Bütün çizim pixel_draw.gd'nin sanat-piksel ızgarasındadır - yumuşak çizgi/daire yok.
##
## Ağ: bu sahne hem kaster'da hem (network_manager.gd broadcast_wave_fx ile) diğer istemcilerde AYNI setup()
## ile doğar, çizim iki tarafta da aynı koddur.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

var start_pos: Vector2 = Vector2.ZERO
var target_node: Node2D = null
var target_pos: Vector2 = Vector2.ZERO
## Işını yayan karakter (ör. Melek) - verilirse start_pos HER karede bu node'un konumunu takip eder (bkz. kullanıcı
## bildirimi: "efekt melek'i takip etmiyor"). Eskiden start_pos sadece setup() anında bir kez alınıyordu.
var caster_node: Node2D = null
var fx_type: String = "heal" ## "heal" or "shield"
var duration: float = 0.8
var elapsed: float = 0.0

const HEAL_DEEP := Color(0.05, 0.36, 0.2)
const HEAL_MID := Color(0.18, 0.82, 0.4)
const HEAL_LIGHT := Color(0.82, 1.0, 0.82)
const SHIELD_DEEP := Color(0.06, 0.2, 0.6)
const SHIELD_MID := Color(0.25, 0.68, 1.0)
const SHIELD_LIGHT := Color(0.88, 0.97, 1.0)

const HEART_ART: Array = [
	".oo.oo.",
	"ogggggo",
	"ogwgggo",
	".ogggo.",
	"..ogo..",
	"...o...",
]
const SHIELD_ART: Array = [
	"oooooo",
	"obwbbo",
	"obbbbo",
	"obbbbo",
	".obbo.",
	"..oo..",
]


func setup(p_from: Vector2, p_target: Node2D, p_type: String, p_caster: Node2D = null) -> void:
	start_pos = p_from
	target_node = p_target
	caster_node = p_caster
	fx_type = p_type
	global_position = Vector2.ZERO
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if target_node and is_instance_valid(target_node):
		target_pos = target_node.global_position
	else:
		target_pos = start_pos


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return
	if caster_node and is_instance_valid(caster_node):
		start_pos = caster_node.global_position
	if target_node and is_instance_valid(target_node):
		target_pos = target_node.global_position
	queue_redraw()


## Gece ışığı (bkz. night_glow.gd): kasterden hedefe dalga boyunca; iyileştirme yeşil, kalkan mavi.
func get_glow_segment() -> Array:
	return [start_pos, target_pos]


func get_night_glow_color() -> Color:
	return Color(0.5, 1.0, 0.6) if fx_type == "heal" else Color(0.45, 0.7, 1.0)


## Dalganın yol boyunca (0..1) yanal sapması - pixel dalga. heal: yumuşak sinüs, shield: açısal (üçgen) dalga.
func _wave_offset(t: float) -> float:
	var env: float = sin(t * PI)
	if fx_type == "heal":
		return 6.5 * env * sin(t * 11.0 - elapsed * 16.0)
	var x: float = t * 9.0 - elapsed * 11.0
	var tri: float = absf(x - floorf(x) - 0.5) * 4.0 - 1.0
	return 5.0 * env * tri


func _draw() -> void:
	var length: float = start_pos.distance_to(target_pos)
	if length < 2.0:
		return
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	var fade: float = minf(1.0, elapsed / 0.08)
	if progress > 0.65:
		fade = minf(fade, (1.0 - progress) / 0.35)
	var dir: Vector2 = (target_pos - start_pos) / length
	var normal := Vector2(-dir.y, dir.x)
	var is_heal: bool = fx_type == "heal"
	var deep: Color = HEAL_DEEP if is_heal else SHIELD_DEEP
	var mid: Color = HEAL_MID if is_heal else SHIELD_MID
	var light: Color = HEAL_LIGHT if is_heal else SHIELD_LIGHT
	deep.a = fade
	mid.a = fade
	light.a = fade

	## --- Dalga yolu: 3 katman (koyu kenar -> orta -> parlak çekirdek), parlak katman yol boyunca AKAR ---
	## İNCELTME (kullanıcı isteği 2026-09-25: "melek'in can ve kalkan basarken kurduğu bağın biraz incelmesi gerekiyor, çok
	## kalın görünüyor"): katman kalınlıkları 5/3/2 -> 3/2/1 sanat pikseli (ekranda ~12 px -> ~7 px), adım da sıklaştı ki
	## ince yol kopuk kopuk görünmesin. Renk dili ve akış aynı.
	var step: float = PixelDraw.TEXEL * 1.0
	var n: int = maxi(8, int(length / step))
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		pts.append(start_pos.lerp(target_pos, t) + normal * _wave_offset(t))
	for p in pts:
		PixelDraw.px(self, p, 3, deep)
	for p in pts:
		PixelDraw.px(self, p, 2, mid)
	for i in range(pts.size()):
		var t2: float = float(i) / float(n)
		if sin(t2 * 22.0 - elapsed * 34.0) > 0.25:
			PixelDraw.px(self, pts[i], 1, light)

	## --- Akan rozetler: caster'dan hedefe kayan kalpler (can) / kalkanlar (kalkan) ---
	var art: Array = HEART_ART if is_heal else SHIELD_ART
	var palette: Dictionary
	if is_heal:
		palette = {"o": Color(0.05, 0.4, 0.22, fade), "g": Color(0.35, 1.0, 0.55, fade), "w": Color(1.0, 1.0, 1.0, fade)}
	else:
		palette = {"o": Color(0.05, 0.2, 0.6, fade), "b": Color(0.3, 0.75, 1.0, fade), "w": Color(0.92, 1.0, 1.0, fade)}
	var arrive: float = 0.0
	for k in range(3):
		var pt: float = fmod(elapsed * 1.5 + float(k) / 3.0, 1.0)
		var ppos: Vector2 = start_pos.lerp(target_pos, pt) + normal * _wave_offset(pt)
		var edge: float = minf(1.0, sin(pt * PI) * 3.0) ## uçlarda küçülüp kaybolur
		if edge > 0.35:
			PixelDraw.art(self, ppos, art, palette, 2.0) ## rozetler 2x: 14x12 sanat pikseli (yol kalın olduğu için okunur olmalı)
		arrive = maxf(arrive, smoothstep(0.86, 1.0, pt))

	## --- Kalkan: dalga yönünü gösteren ok uçları (chevron) ---
	if not is_heal:
		for k in range(5):
			var ct: float = fmod(elapsed * 0.9 + float(k) / 5.0, 1.0)
			if sin(ct * PI) < 0.3:
				continue
			var c: Vector2 = start_pos.lerp(target_pos, ct) + normal * _wave_offset(ct)
			PixelDraw.px(self, c + dir * PixelDraw.TEXEL * 2.0, 1, light)
			PixelDraw.px(self, c - dir * PixelDraw.TEXEL + normal * PixelDraw.TEXEL * 2.0, 1, light)
			PixelDraw.px(self, c - dir * PixelDraw.TEXEL - normal * PixelDraw.TEXEL * 2.0, 1, light)

	## --- Uçlar: caster'da nabız gibi açılan pixel halka, hedefte rozet ulaşınca parlayan yıldız ---
	var pulse: float = fmod(elapsed * 2.5, 1.0)
	PixelDraw.ring(self, start_pos, 4.0 + pulse * 16.0, Color(mid.r, mid.g, mid.b, fade * (1.0 - pulse)), 1)
	if arrive > 0.05:
		var s: int = 2 if arrive > 0.6 else 1
		var star: Color = light
		star.a = fade * arrive
		PixelDraw.px(self, target_pos, s + 1, star)
		for off in [Vector2(6, 0), Vector2(-6, 0), Vector2(0, 6), Vector2(0, -6)]:
			PixelDraw.px(self, target_pos + off * arrive, s, mid)
