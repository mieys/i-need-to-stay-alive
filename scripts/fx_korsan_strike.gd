extends Node2D

## Korsan'ın Bombardıman'ı (R) tek bir mermisi: yerde kırmızı-turuncu pixel hedef işareti (daralan kesikli halka +
## artı), gökten dumanlı bir top mermisi iner, tam STRIKE_FALL_TIME sonunda patlar (fx_korsan_explosion.tscn).
## player.gd hasarı AYNI süre sonra uygular (KorsanFxMath.STRIKE_FALL_TIME tek kaynak). Diğer istemcilerde de
## network_manager.gd "hitscan_impact" ile bu sahne doğar; setup(radius, color) patlama yarıçapını verir.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const KorsanFxMath := preload("res://scripts/korsan_fx_math.gd")
const EXPLOSION_SCENE := preload("res://scenes/fx_korsan_explosion.tscn")

const DROP_HEIGHT := 190.0

const SHELL_ART: Array = [
	".ooo.",
	"odddo",
	"dmhdd",
	"odddo",
	".ooo.",
]
const SHELL_PAL := {
	"o": Color(0.05, 0.05, 0.09),
	"d": Color(0.16, 0.16, 0.22),
	"m": Color(0.3, 0.3, 0.4),
	"h": Color(0.7, 0.7, 0.85),
}

var blast_radius: float = KorsanFxMath.STRIKE_RADIUS
var _t: float = 0.0
var _exploded: bool = false


func setup(radius: float, _color: Color = Color.WHITE) -> void:
	blast_radius = radius


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 11


func _process(delta: float) -> void:
	_t += delta
	var fall: float = KorsanFxMath.STRIKE_FALL_TIME
	if not _exploded and _t >= fall:
		_exploded = true
		var boom: Node2D = EXPLOSION_SCENE.instantiate() as Node2D
		add_child(boom)
		boom.position = Vector2.ZERO
		if boom.has_method("setup"):
			boom.setup(blast_radius, Color(1.0, 0.6, 0.2))
	## patlama efekti kendi ömrünü bitirince (çocuk silinince) bu düğüm de gider
	if _exploded and get_child_count() == 0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fall: float = KorsanFxMath.STRIKE_FALL_TIME
	if _t >= fall:
		return
	var k: float = _t / fall
	var texel: float = PixelDraw.TEXEL
	## Hedef işareti: dışarıdan içeri daralan kesikli halka + 4 köşe çentiği + ortada yanıp sönen artı
	var ring_r: float = blast_radius * (1.0 - 0.35 * k)
	var blink: bool = int(_t * 20.0) % 2 == 0
	var col: Color = Color(1.0, 0.32, 0.12) if blink else Color(1.0, 0.72, 0.2)
	PixelDraw.ring(self, Vector2.ZERO, ring_r, col, 1, 4, 4, _t * 30.0)
	for q in range(4):
		var a: float = float(q) * PI * 0.5 + PI * 0.25
		PixelDraw.px(self, Vector2(cos(a), sin(a)) * (ring_r + texel * 2.0), 2, col)
	for off in [Vector2(0, 0), Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
		PixelDraw.px(self, off * texel, 1, col)
	## Mermi gölgesi: mermi yaklaştıkça büyüyen dither
	PixelDraw.disc_dither(self, Vector2.ZERO, blast_radius * 0.16 * (0.4 + 0.6 * k), Color(0.02, 0.02, 0.04, 0.6), 0, 1)
	## Mermi: karesel hızlanarak düşer, arkasında sönen pixel duman/ateş izi
	var y: float = -DROP_HEIGHT * (1.0 - k) * (1.0 - k)
	for i in range(1, 7):
		var ty: float = y - float(i) * texel * 3.0
		var tk: float = float(i) / 7.0
		PixelDraw.px(self, Vector2(sin(_t * 30.0 + float(i)) * texel, ty), 3 if i < 3 else 2, PixelDraw.fire_color(0.15 + tk * 0.8))
	PixelDraw.art(self, Vector2(0, y), SHELL_ART, SHELL_PAL, 1.0)
	## Mermi ucundaki kıvılcım
	PixelDraw.px(self, Vector2(texel * 2.0, y - texel * 3.0), 1, Color(1.0, 0.9, 0.5))
