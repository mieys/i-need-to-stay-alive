extends Sprite2D
## Efsunlu silahın arkasındaki MMORPG tarzı parıltı (kullanıcı isteği 2026-10-04: "efsunlanan silahların arkaplanı hafif
## parıltılı olacak mmorpg oyunlardaki gibi. 1. kademe yeşil, 2 mavi, 3 mor, 4 sarı, 5 (final) kırmızı"; prototip onaylandı).
## Kademe = tier_for(efsun kaydı). Yerel: weapon.gd set_enchant takar. Uzak kopyalar: main.gd extra["ench_tiers"] (weapon_keys
## ile aynı sıra) -> remote_player.gd _apply_enchant_glows - ikisi de AYNI attach() yolundan geçer.
##
## Silah ikonunun (Sprite2D ya da AnimatedSprite2D - Yay) ÇOCUĞU olarak, ikonun ARKASINDA çizilir (show_behind_parent) -> ikonla birlikte döner,
## aynalanır, gizlenir. Hale, ikonun siluetinden DÜNYA pikseli çözünürlüğünde üretilir (ikonlar 200-250 px'lik kaynak,
## oyunda ~x0.22 çiziliyor - hale kaynak çözünürlüğünde yapılsa piksel stiline uymayan pürüzsüz bir bulanıklık olurdu):
## silüet ~1/f'e küçültülür, dışına GLOW_TEXELS dünya pikseli kademeli (bantlı) halka çizilir, sprite f katı ölçeklenir.
## Canlılık shader'da: yavaş nefes alan parlaklık + çapraz geçen bir parıltı şeridi + kenardan dışarı süzülen birkaç tek
## piksellik kıvılcım (final kademede biraz daha güçlü).

const TIER_COLORS: Array[Color] = [
	Color(0.30, 1.00, 0.30), ## 1 - yeşil
	Color(0.25, 0.55, 1.00), ## 2 - mavi
	Color(0.72, 0.30, 1.00), ## 3 - mor
	Color(1.00, 0.85, 0.15), ## 4 - sarı
	Color(1.00, 0.18, 0.15), ## 5 - kırmızı (final)
]
const GLOW_TEXELS := 4
## Genel parıltı yoğunluğu (hale opaklığı + parıltı şeridi + kıvılcımlar). Kullanıcı isteği 2026-10-04: "%20 azalt" -> 0,8.
const GLOW_INTENSITY := 0.8
## Halka bantları (silüete uzaklık 1..GLOW_TEXELS dünya pikseli) - içten dışa sönen opaklık.
const BAND_ALPHA: Array[float] = [1.0, 0.78, 0.5, 0.26]
const MOTE_COUNT := 3
const MOTE_COUNT_FINAL := 5
const MOTE_LIFE := 1.1
const MOTE_TRAVEL := 5.0

const GLOW_SHADER := """
shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float strength = 1.0;
uniform float phase = 0.0;
void fragment() {
	vec4 m = texture(TEXTURE, UV);
	if (m.a <= 0.0) { discard; }
	vec2 tex_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * tex_size);
	float t = TIME + phase;
	float pulse = 0.82 + 0.18 * sin(t * 2.3);
	float span = tex_size.x + tex_size.y;
	float sweep = fract(t / 2.8) * span * 1.5 - span * 0.25;
	float shine = step(abs(px.x + px.y - sweep), 1.5);
	// m.r: 1 = silüete bitişik bant, dışa doğru azalır
	// en içteki bant hafif açık (ışık çekirdeği), dış bantlar doygun renk
	float core = step(0.99, m.r);
	vec3 col = mix(glow_color.rgb, vec3(1.0), core * 0.22 + shine * 0.45);
	float a = (m.a * pulse + shine * 0.3 * m.a) * strength;
	a = floor(clamp(a, 0.0, 1.0) * 6.0 + 0.5) / 6.0;
	COLOR = vec4(col, a);
}
"""

static var _shader: Shader = null
## (kaynak doku, f) -> [ImageTexture hale, PackedVector2Array kenar pikselleri, Vector2 merkez]
static var _cache: Dictionary = {}

var tier: int = 1
var _icon: Node2D = null
var _src_tex: Texture2D = null
var _f: int = 1
var _edges: PackedVector2Array = PackedVector2Array()
var _centre: Vector2 = Vector2.ZERO
var _motes: Array = [] ## [{p: Vector2, d: Vector2, t: float}]
var _mote_layer: Node2D = null


## Bir silah ikonuna kademe parıltısı takar (varsa günceller). tier 0 = kaldır.
static func attach(icon: Node2D, new_tier: int) -> Node:
	if icon == null:
		return null
	var existing: Node = icon.get_node_or_null("EnchantGlow")
	if new_tier <= 0:
		if existing:
			existing.queue_free()
		return null
	if existing:
		existing.set("tier", clampi(new_tier, 1, 5))
		existing.call("_apply_tier")
		return existing
	var g: Sprite2D = (load("res://scripts/enchant_weapon_glow.gd") as GDScript).new()
	g.name = "EnchantGlow"
	g.tier = clampi(new_tier, 1, 5)
	icon.add_child(g)
	return g


func _ready() -> void:
	_icon = get_parent() as Node2D
	show_behind_parent = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GLOW_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("phase", randf() * 10.0)
	material = mat
	_mote_layer = MoteLayer.new()
	_mote_layer.glow = self
	add_child(_mote_layer)
	_apply_tier()
	_rebuild()


func _apply_tier() -> void:
	var mat := material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("glow_color", TIER_COLORS[clampi(tier, 1, 5) - 1])
	mat.set_shader_parameter("strength", (1.15 if tier >= 5 else 1.0) * GLOW_INTENSITY)


func _rebuild() -> void:
	var tex: Texture2D = _icon_texture()
	if tex == null:
		texture = null
		_src_tex = null
		return
	_src_tex = tex
	var gs: float = absf(_icon.get_global_transform().get_scale().x)
	_f = clampi(int(roundf(1.0 / maxf(gs, 0.001))), 1, 12)
	var key: String = "%s|%d" % [_src_tex.get_rid(), _f]
	if not _cache.has(key):
		_cache[key] = _build_glow(_src_tex, _f)
	var entry: Array = _cache[key]
	texture = entry[0]
	_edges = entry[1]
	_centre = entry[2]
	centered = bool(_icon.get("centered"))
	scale = Vector2.ONE * float(_f)
	offset = (_icon.get("offset") as Vector2) / float(_f)
	_motes.clear()


static func _build_glow(src: Texture2D, f: int) -> Array:
	var img: Image = src.get_image()
	if img == null:
		return [null, PackedVector2Array(), Vector2.ZERO]
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var sw: int = maxi(1, int(roundf(float(img.get_width()) / f)))
	var sh: int = maxi(1, int(roundf(float(img.get_height()) / f)))
	img.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
	var pad: int = GLOW_TEXELS + 1
	var w: int = sw + pad * 2
	var h: int = sh + pad * 2
	var mask := PackedByteArray()
	mask.resize(w * h)
	for y in sh:
		for x in sw:
			if img.get_pixel(x, y).a > 0.35:
				mask[(y + pad) * w + x + pad] = 1
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var edges := PackedVector2Array()
	var sum := Vector2.ZERO
	var n: int = 0
	for y in h:
		for x in w:
			if mask[y * w + x] == 1:
				## Silüetin içi: ikonun yarı saydam pikselleri arkadan hafif renk alsın.
				out.set_pixel(x, y, Color(1.0, 0.0, 0.0, 0.5))
				sum += Vector2(x, y)
				n += 1
				continue
			var best: float = 99.0
			for dy in range(-GLOW_TEXELS, GLOW_TEXELS + 1):
				var yy: int = y + dy
				if yy < 0 or yy >= h:
					continue
				for dx in range(-GLOW_TEXELS, GLOW_TEXELS + 1):
					var xx: int = x + dx
					if xx < 0 or xx >= w or mask[yy * w + xx] == 0:
						continue
					best = minf(best, sqrt(float(dx * dx + dy * dy)))
			var band: int = int(ceilf(best - 0.25)) ## 1..GLOW_TEXELS
			if band < 1 or band > GLOW_TEXELS:
				continue
			out.set_pixel(x, y, Color(1.0 - float(band - 1) / GLOW_TEXELS, 0.0, 0.0, BAND_ALPHA[band - 1]))
			if band == 1:
				edges.append(Vector2(x, y))
	var centre: Vector2 = (sum / maxf(1.0, float(n))) if n > 0 else Vector2(w, h) * 0.5
	return [ImageTexture.create_from_image(out), edges, centre]


func _process(delta: float) -> void:
	if _icon == null:
		return
	if _icon_texture() != _src_tex:
		_rebuild()
	flip_h = bool(_icon.get("flip_h"))
	flip_v = bool(_icon.get("flip_v"))
	if _edges.is_empty() or texture == null:
		return
	var want: int = MOTE_COUNT_FINAL if tier >= 5 else MOTE_COUNT
	while _motes.size() < want:
		## Kıvılcımlar aynı anda doğmasın - ömürleri dağıtılarak başlar.
		_motes.append(_new_mote(randf() * MOTE_LIFE))
	for i in _motes.size():
		var m: Dictionary = _motes[i]
		m["t"] += delta
		if m["t"] >= MOTE_LIFE:
			_motes[i] = _new_mote(0.0)
	_mote_layer.queue_redraw()


## İkonun o an çizdiği doku (AnimatedSprite2D'de geçerli kare).
func _icon_texture() -> Texture2D:
	if _icon is Sprite2D:
		return (_icon as Sprite2D).texture
	if _icon is AnimatedSprite2D:
		var a := _icon as AnimatedSprite2D
		if a.sprite_frames and a.sprite_frames.has_animation(a.animation):
			return a.sprite_frames.get_frame_texture(a.animation, a.frame)
	return null


## Efsun kaydından kademe (player.gd apply_enchant_choice: {"id", "ups": [..], "final"}): Temel = 1, her geliştirme +1
## (en fazla 4), Final = 5. "Seviye" efsunlarında (3 geliştirme) birebir Seviye 1-5. Efsun yok = 0.
static func tier_for(ench: Dictionary) -> int:
	if ench.is_empty() or str(ench.get("id", "")).is_empty():
		return 0
	if bool(ench.get("final", false)):
		return 5
	return mini(4, 1 + (ench.get("ups", []) as Array).size())


func _new_mote(t0: float) -> Dictionary:
	var p: Vector2 = _edges[randi() % _edges.size()]
	var d: Vector2 = (p - _centre).normalized()
	if d == Vector2.ZERO:
		d = Vector2.UP
	return {"p": p, "d": d, "t": t0}


## Kıvılcımlar ayrı düğümde: hale shader'ı draw_rect'leri de boyardı (kendi renk/opaklıkları kaybolurdu).
class MoteLayer extends Node2D:
	var glow: Sprite2D

	func _draw() -> void:
		var tex: Texture2D = glow.texture
		if tex == null:
			return
		var size: Vector2 = tex.get_size()
		var origin: Vector2 = (-size * 0.5 if glow.centered else Vector2.ZERO) + glow.offset
		var col: Color = TIER_COLORS[clampi(glow.tier, 1, 5) - 1].lerp(Color.WHITE, 0.45)
		for m in glow._motes:
			var k: float = float(m["t"]) / MOTE_LIFE
			var p: Vector2 = (m["p"] as Vector2) + (m["d"] as Vector2) * MOTE_TRAVEL * k
			if glow.flip_h:
				p.x = size.x - 1.0 - p.x
			if glow.flip_v:
				p.y = size.y - 1.0 - p.y
			var a: float = 1.0 if k < 0.6 else floorf((1.0 - k) / 0.4 * 3.0 + 0.5) / 3.0
			if a <= 0.0:
				continue
			draw_rect(Rect2((origin + p).floor(), Vector2.ONE), Color(col, a * GLOW_INTENSITY))
