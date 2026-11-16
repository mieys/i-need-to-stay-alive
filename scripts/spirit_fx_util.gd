extends RefCounted

## Ruhani yetenek efektlerinin ortak çizim yardımcıları (madde 734; seçilen prototipler madde 730: Can A, Adc B, Tank B,
## Taktiksel A, Kalkan Bağı A). Efekt kökleri Player/RemotePlayer'ın (0,5 ölçekli) çocuğu olarak scale 2 + ayak noktasına
## (FEET_LOCAL) konur: kökün yerel birimi = 1 DÜNYA birimi = prototipteki 1 piksel, (0, 0) = ayak. Bu yüzden tüm sayılar
## prototipteki (x - ayak_x, y - ayak_y) değerleriyle birebir aynı.
## TİTREŞİM YOK (hafıza no-dither): yumuşaklık yalnız düz alfa bantları (band()).

const FEET_LOCAL := Vector2(0.0, 30.0) ## oyuncu kökünün yerel biriminde ayak teması (gölge sprite'a gömülü, hafıza pixel-style-fx)
const ROOT_SCALE := Vector2(2.0, 2.0)
const GHOST_SHADER := preload("res://scenes/fx_ghost_silhouette.gdshader")

const CREAM := Color8(255, 246, 220)
const GOLD2 := Color8(232, 170, 52)
const GOLD3 := Color8(252, 222, 120)
const GOLD4 := Color8(255, 248, 214)
const HEAL3 := Color8(168, 228, 132)
const FIRE2 := Color8(230, 94, 36)
const FIRE3 := Color8(250, 166, 58)
const FIRE4 := Color8(255, 234, 150)
const STEEL3 := Color8(172, 210, 244)
const WIND3 := Color8(172, 240, 238)
const WIND4 := Color8(240, 255, 252)
const MANA3 := Color8(184, 212, 255)
const MANA4 := Color8(242, 247, 255)

const DIAM: Array[String] = [".#.", "#.#", ".#."]
const CHEVRON: Array[String] = ["..#..", ".#.#.", "#...#"]

static var _ghost_mat: ShaderMaterial = null


static func band(a: float, n: int = 4) -> float:
	return clampf(roundf(a * float(n)) / float(n), 0.0, 1.0)


static func ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)


static func ease_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t


static func ease_io(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func overshoot(t: float, k: float = 1.2) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 + (k + 1.0) * pow(t - 1.0, 3.0) + k * pow(t - 1.0, 2.0)


static func hash01(i: int) -> float:
	var v: int = (i * 73856093) ^ 0x5bd1e995
	v = ((v ^ (v >> 13)) * 0x5bd1e995) & 0xffffffff
	return float((v ^ (v >> 15)) & 0xffff) / 65535.0


static func with_a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## Kök (dünya birimi) uzayında 1 piksel = 1x1 dikdörtgen; koordinat piksele oturtulur.
static func px(ci: CanvasItem, x: float, y: float, col: Color) -> void:
	ci.draw_rect(Rect2(floorf(x), floorf(y), 1.0, 1.0), col)


## 4 uçlu pırıltı (prototip sparkle): kol boyu k; k >= 2'de merkeze bitişik pikseller de çekirdek rengi.
static func sparkle(ci: CanvasItem, x: float, y: float, k: int, core: Color, arm: Color, a: float = 1.0) -> void:
	if k <= 0 or a <= 0.004:
		return
	var cx: float = floorf(x)
	var cy: float = floorf(y)
	for i in range(1, k + 1):
		var c: Color = with_a(core if (i == 1 and k >= 2) else arm, a)
		ci.draw_rect(Rect2(cx + i, cy, 1, 1), c)
		ci.draw_rect(Rect2(cx - i, cy, 1, 1), c)
		ci.draw_rect(Rect2(cx, cy + i, 1, 1), c)
		ci.draw_rect(Rect2(cx, cy - i, 1, 1), c)
	ci.draw_rect(Rect2(cx, cy, 1, 1), with_a(core, a))


## ASCII glif ('#' = piksel), merkezi (cx, cy) - prototip m_glyph ile aynı yerleşim.
static func glyph(ci: CanvasItem, rows: Array[String], cx: float, cy: float, col: Color) -> void:
	if col.a <= 0.004:
		return
	var h: int = rows.size()
	var w: int = 0
	for r in rows:
		w = maxi(w, r.length())
	var x0: float = floorf(cx) - float(w / 2)
	var y0: float = floorf(cy) - float(h / 2)
	for y in range(h):
		var r: String = rows[y]
		for x in range(r.length()):
			if r[x] == "#":
				ci.draw_rect(Rect2(x0 + x, y0 + y, 1, 1), col)


## Dolu elips (piksel merkezleri içerde) satır satır; küçük şekiller için (ışık sütunu ucu).
static func ellipse(ci: CanvasItem, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	if rx < 0.5 or ry < 0.5 or col.a <= 0.004:
		return
	for yi in range(int(floorf(cy - ry)) - 1, int(ceilf(cy + ry)) + 1):
		var dy: float = (float(yi) + 0.5 - cy) / ry
		if absf(dy) > 1.0:
			continue
		var half: float = rx * sqrt(1.0 - dy * dy)
		var xa: int = int(ceilf(cx - half - 0.5))
		var xb: int = int(floorf(cx + half - 0.5))
		if xb >= xa:
			ci.draw_rect(Rect2(xa, yi, xb - xa + 1, 1), col)


## Pişmiş yatay sayfadan bir kareyi (hframes) merkezi (cx, cy) olacak şekilde çizer.
static func frame(ci: CanvasItem, tex: Texture2D, hframes: int, idx: int, cx: float, cy: float, col: Color) -> void:
	if tex == null or col.a <= 0.004:
		return
	var fw: float = float(tex.get_width()) / float(hframes)
	var fh: float = float(tex.get_height())
	idx = clampi(idx, 0, hframes - 1)
	ci.draw_texture_rect_region(tex, Rect2(floorf(cx) - fw * 0.5, floorf(cy) - fh * 0.5, fw, fh), Rect2(fw * idx, 0.0, fw, fh), col)


## Ayağa oturtulmuş, dünya birimli efekt kökü kurar (Player/RemotePlayer çocuğu için).
static func setup_root(n: Node2D) -> void:
	n.scale = ROOT_SCALE
	n.position = FEET_LOCAL
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Kökün üstüne çizilen katman (karakterin ÖNÜ): ayrı Node2D, kendi draw sinyaline bağlı.
static func front_layer(parent: Node2D, draw_fn: Callable, z: int = 2) -> Node2D:
	var f := Node2D.new()
	f.z_index = z
	f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(f)
	f.draw.connect(draw_fn)
	return f


## Karakter karesinden düz renkli silüet (hayalet) - renk/alfa = self_modulate.
static func ghost_material() -> ShaderMaterial:
	if _ghost_mat == null:
		_ghost_mat = ShaderMaterial.new()
		_ghost_mat.shader = GHOST_SHADER
	return _ghost_mat


## host'un (Player/RemotePlayer) görünen karakter sprite'ı: AnimatedSprite2D "anim" alanı.
static func host_sprite(host: Node) -> AnimatedSprite2D:
	if host == null or not is_instance_valid(host):
		return null
	var a: Variant = host.get("anim")
	if a is AnimatedSprite2D and is_instance_valid(a):
		return a as AnimatedSprite2D
	return null


## Sprite'ın şu anki karesinin silüet kopyası (dünyada; konum/ölçek/yön kaynağınkiyle aynı). Ebeveyne eklenmez.
static func make_ghost(src: AnimatedSprite2D, col: Color) -> Sprite2D:
	if src == null or src.sprite_frames == null:
		return null
	var tex: Texture2D = src.sprite_frames.get_frame_texture(src.animation, src.frame)
	if tex == null:
		return null
	var g := Sprite2D.new()
	g.texture = tex
	g.centered = src.centered
	g.offset = src.offset
	g.flip_h = src.flip_h
	g.flip_v = src.flip_v
	g.material = ghost_material()
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.self_modulate = col
	return g
