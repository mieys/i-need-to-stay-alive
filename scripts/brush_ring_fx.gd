extends Sprite2D

## SAKLANMA ÇALILIĞI ALGI HALKASI (madde 283, 2026-10-19; kullanıcı: "karakterin kendi genişliğinin 2 katı kadar uzaklığa doğru yuvarlak bir sınır çizilecek etrafında
## (LoL'deki Twitch Q gibi); halkanın dışındaki yaratıklar onu görmeyecek, içine girenler görüp saldırabilir"). Kullanıcı seçimi yarıçap ~36 dünya px (HideBrush.RING_RADIUS,
## kural hide_brush_manager.gd). Sadece SAHİBİNİN ekranında (player.gd set_brush_state; kukla çizmez - arkadaşlar can barı üstündeki göz simgesini görür, madde 275).
## Durum 1 (saklı) açık krem-yeşil, durum 2 (görüldü) kırmızı; 0 = solarak kaybolur. Ayak noktasında, 1 sanat pikseli = 1 dünya pikseli (ebeveyn ölçeğinden bağımsız).
## Önde kalan çalılık ön kopyaları (depth_occluders z 3) halkanın alt yarısını kesmesin diye z 4 mutlak: çizgi karakterin gövdesine değmez (tepesi başın ~14 px üstü).

const HideBrushScript := preload("res://scripts/hide_brush.gd")
const COLORS := {1: Color8(222, 240, 196), 2: Color8(240, 108, 78)}
const ALPHA := 0.62
const INNER_ALPHA := 0.22
const FADE := 0.18

static var _tex: ImageTexture = null

var state: int = 0
var _tween: Tween = null


## Halka dokusu (beyaz; renk modulate'te): R yarıçaplı 1 px çember + 2 px içeride soluk ikinci çember (yumuşaklık). Saf; testler çağırır.
static func build_image(r: float) -> Image:
	var n: int = int(ceilf(r)) * 2 + 3
	var c: float = float(n) * 0.5
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(n):
		for x in range(n):
			var d: float = Vector2(float(x) + 0.5 - c, float(y) + 0.5 - c).length()
			if absf(d - r) <= 0.5:
				img.set_pixel(x, y, Color(1, 1, 1, ALPHA))
			elif absf(d - (r - 2.0)) <= 0.5:
				img.set_pixel(x, y, Color(1, 1, 1, INNER_ALPHA))
	return img


static func ring_texture() -> Texture2D:
	if _tex == null:
		_tex = ImageTexture.create_from_image(build_image(HideBrushScript.RING_RADIUS))
	return _tex


func _ready() -> void:
	name = "BrushRing"
	texture = ring_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	centered = true
	z_as_relative = false
	z_index = 4
	modulate.a = 0.0
	visible = false
	_place()


func _process(_delta: float) -> void:
	if visible:
		_place()


func _place() -> void:
	var p: Node2D = get_parent() as Node2D
	var ps: float = absf(p.global_scale.y) if p != null else 1.0
	if ps < 0.01:
		ps = 1.0
	scale = Vector2.ONE / ps
	position = Vector2(0.0, HideBrushScript.FEET_OFFSET / ps)


func show_state(st: int) -> void:
	if st == state:
		return
	state = st
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if st == 0:
		_tween.tween_property(self, "modulate:a", 0.0, FADE)
		_tween.tween_callback(func() -> void: visible = false)
		return
	visible = true
	var col: Color = COLORS.get(st, COLORS[1])
	self_modulate = Color(col.r, col.g, col.b, 1.0)
	_tween.tween_property(self, "modulate:a", 1.0, FADE)
