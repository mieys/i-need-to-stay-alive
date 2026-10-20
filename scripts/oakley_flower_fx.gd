extends Node2D

## OAKLEY ÇİÇEĞİ "YAPRAK HALKASI" (2026-10-19, madde 285 prototip C seçildi; kullanıcı: "halkada sadece yaprak olsun son formunda tohum da var"
## -> açmışta altın taç yaprakları YOK, 6 yaprak). Çiçeğin sanat diliyle (kalın kontur, 3 yeşil) sivri yapraklar 2:1 yörüngede döner,
## arkalarında sürekli 1 px "savrulma" izi; yerde krem-yeşil ışık havuzu + yaprak gölgeleri. Çiçek büyüdükçe gelişir:
## filiz 2 yaprak / tomurcuk 4 / açmış 6, yörünge ve havuz büyür, hızlanır; büyüme anında yapraklar dışa savrulup yerine oturur, yeni yaprak
## küçük parıltıyla belirir. Prototip: tools/proto_20261019/cicek_efekt_proto.py (LeafHalo) - sayılar ve çizim kuralları AYNI.
##
## FPS (2026-10-19, kullanıcı: "bu spritesheet dimi kastırmaz yani oyunu?"): ilk sürüm her karede _draw ile ~150 piksel dikdörtgeni + Bresenham iz
## çiziyordu - ölçüldü: açmış çiçek başına kare başı ~0,54 ms CPU, ekranda 12 çiçekle kare 5,3 -> 12,3 ms. Artık BOYAMA GPU'da
## (shaders/oakley_yaprak_halkasi.gdshader); burada yalnız 6 yaprağın konumu hesaplanır (leaf_pos, tek kaynak + testli) ve çiçek başına TEK
## materyale 4 parametre yazılır (sadece ekrandaki çiçekler). Üç dörtgen aynı materyali paylaşır: zemin (bu betiğin düğümünde - çiçeğin kardeşi,
## haritanın hemen üstü, madde 284), arka (çiçekte sprite'tan ÖNCE) ve ön (sprite'tan SONRA); katman = dörtgenin 1x1 dokusunun kırmızısı.
## Konumlar çiçeğin yerel koordinatında (kök = çiçek merkezi, FOOT_Y = yere değdiği satır), 1 px = 1 dünya (çiçek sanatıyla aynı).
## Ağ yok: her istemci kendi çiçeğini kurar. Gece ışığı kataloğu bu betiği (zemin düğümü) anahtar alır.

const HaloShader := preload("res://shaders/oakley_yaprak_halkasi.gdshader")

const FOOT_Y := 20.0 ## oakley_flower.gd FOOT_Y
const R: Array[float] = [10.0, 14.0, 19.0] ## yörünge yarıçapı (yatay; dikey x0,45)
const POOL: Array[float] = [10.0, 14.0, 19.0] ## havuz yarıçapı (2:1)
const H: Array[float] = [6.0, 9.0, 12.0] ## yörüngenin yerden yüksekliği
const N_LEAF: Array[int] = [2, 4, 6]
const MAX_LEAVES := 6 ## shader dizileri (leaf_a / leaf_b) bu uzunlukta
const SPEED: Array[float] = [1.3, 1.5, 1.7] ## rad/sn
const TRANS := 0.6 ## büyüme geçişi (sn)
const FLING := 8.0 ## geçişte dışa savrulma (px)
const BIRTH := 0.45 ## doğuşta belirme (sn)
const LEAF_PAL := {"o": Color8(26, 59, 41), "1": Color8(64, 112, 48), "2": Color8(122, 162, 61), "3": Color8(168, 204, 92)}
const LEAF_ROWS: Array[String] = [
	"....ooo",
	"..oo33o",
	".o3332o",
	"o22221o",
	"o2211o.",
	"o11oo..",
	".oo....",
]
## Dörtgen: yörünge (19 + 8 savrulma + yaprak + iz) ve havuzun altı + yeni yaprak parıltısı (yaprağın 8 px üstü) sığar.
const QUAD_ORIGIN := Vector2(-32.0, -24.0)
const QUAD_SIZE := Vector2(64.0, 56.0)
enum { LAYER_GROUND, LAYER_BACK, LAYER_FRONT }
const LAYER_NAMES: Array[String] = ["FxGround", "FxBack", "FxFront"]
## Zemin parçasının ağaç ön kopyası örtüsü (depth_occluders `depth_props`): havuz (en çok 19 + taşma) + gölgeler, ayak = havuzun alt kenarı.
const GROUND_HALF_W := 22.0
const GROUND_HEIGHT := 22.0
const GROUND_FOOT := FOOT_Y - 1.0 + 10.0 + 1.0

static var _leaf_tex: Texture2D = null
static var _layer_tex: Array[Texture2D] = []

var flower: Node2D = null ## oakley_flower.gd (zemin düğümü çiçekle birlikte silinir)


## Çiçeğin durumu: [t (yaş), faz (birikmiş açı), eski aşama, yeni aşama, geçiş 0..1, doğuş alfası].
static func state(t: float, phase: float, s_from: int, s_to: int, grow_age: float) -> Array:
	return [t, phase, s_from, s_to, clampf(grow_age / TRANS, 0.0, 1.0), _ease_out(t / BIRTH)]


static func _ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)


static func _ease_back(k: float) -> float: ## hafif taşma (yerine oturma)
	k = clampf(k, 0.0, 1.0)
	var c: float = 1.9
	return 1.0 + (c + 1.0) * pow(k - 1.0, 3.0) + c * pow(k - 1.0, 2.0)


static func _lerp_stage(vals: Array[float], s_from: int, s_to: int, f: float) -> float:
	return vals[s_from] + (vals[s_to] - vals[s_from]) * f


## Prototipteki band(): saydamlık 5 basamakta (düz bantlı ışık dili). Shader'daki band() ile aynı yuvarlama.
static func _band(a: float) -> float:
	return clampf(floorf(a * 5.0 + 0.5) / 5.0, 0.0, 1.0)


static func orbit_radius(st: Array) -> float:
	var k: float = st[4]
	var r: float = _lerp_stage(R, st[2], st[3], _ease_back(k))
	if k < 1.0:
		r += sin(k * PI) * FLING
	return r


static func orbit_height(st: Array) -> float:
	return _lerp_stage(H, st[2], st[3], _ease_out(st[4]))


## Yaprağın açısal yeri: eski aralıktan yeni aralığa kayar (2 -> 4 -> 6 yaprakta sıçrama yok), yeni yaprak yeni aralıkta belirir.
static func _slot_angle(idx: int, s_from: int, s_to: int, k: float) -> float:
	var n_to: int = N_LEAF[s_to]
	var n_from: int = N_LEAF[s_from]
	var a_to: float = TAU * float(idx) / float(n_to)
	if idx >= n_from or n_from == n_to:
		return a_to
	return lerpf(TAU * float(idx) / float(n_from), a_to, _ease_out(k))


## (x, yerdeki izdüşüm y, havadaki y, açı) - çiçeğin yerel koordinatında. r/h verilirse (kare başı güncelleme) yeniden hesaplanmaz.
static func leaf_pos(st: Array, idx: int, r: float = -1.0, h: float = -1.0) -> Vector4:
	if r < 0.0:
		r = orbit_radius(st)
	if h < 0.0:
		h = orbit_height(st)
	var ang: float = float(st[1]) + _slot_angle(idx, st[2], st[3], st[4])
	var bob: float = sin(float(st[0]) * 2.4 + float(idx)) * 1.2
	var gy: float = FOOT_Y - 1.0 + sin(ang) * r * 0.45
	return Vector4(cos(ang) * r, gy, gy - h + bob, ang)


static func leaf_alpha(st: Array, idx: int) -> float:
	var a: float = st[5]
	if idx >= N_LEAF[st[2]] and st[4] < 1.0:
		a *= _ease_out(float(st[4]) * 1.5)
	return a


static func leaf_texture() -> Texture2D:
	if _leaf_tex == null:
		var w: int = 0
		for row in LEAF_ROWS:
			w = maxi(w, row.length())
		var img := Image.create(w, LEAF_ROWS.size(), false, Image.FORMAT_RGBA8)
		for y in LEAF_ROWS.size():
			var row: String = LEAF_ROWS[y]
			for x in row.length():
				if LEAF_PAL.has(row[x]):
					img.set_pixel(x, y, LEAF_PAL[row[x]])
		_leaf_tex = ImageTexture.create_from_image(img)
	return _leaf_tex


## Katman kimliği: dörtgenin 1x1 dokusunun kırmızısı (0 zemin, 0,5 arka, 1 ön) - üç dörtgen tek materyali paylaşsın diye.
static func _layer_texture(layer: int) -> Texture2D:
	if _layer_tex.is_empty():
		for l in 3:
			var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
			img.set_pixel(0, 0, Color(float(l) * 0.5, 0.0, 0.0, 1.0))
			_layer_tex.append(ImageTexture.create_from_image(img))
	return _layer_tex[layer]


static func make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HaloShader
	m.set_shader_parameter("leaf_tex", leaf_texture())
	m.set_shader_parameter("origin", QUAD_ORIGIN)
	m.set_shader_parameter("size", QUAD_SIZE)
	return m


static func make_quad(mat: ShaderMaterial, layer: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = LAYER_NAMES[layer]
	s.texture = _layer_texture(layer)
	s.centered = false
	s.position = QUAD_ORIGIN
	s.scale = QUAD_SIZE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = mat
	return s


## Kare başı: yaprak konumları + yarıçaplar + parıltı -> materyal (4 parametre). Boyama kuralları shader'da.
static func update_material(mat: ShaderMaterial, st: Array) -> void:
	var r: float = orbit_radius(st)
	var h: float = orbit_height(st)
	var n: int = N_LEAF[st[3]]
	var leaf_a := PackedVector4Array()
	var leaf_b := PackedVector4Array()
	leaf_a.resize(MAX_LEAVES)
	leaf_b.resize(MAX_LEAVES)
	for idx in n:
		var p: Vector4 = leaf_pos(st, idx, r, h)
		leaf_a[idx] = Vector4(p.x, p.z, p.w, leaf_alpha(st, idx))
		leaf_b[idx] = Vector4(p.y, p.z - sin(p.w) * r * 0.45, 0.0, 0.0) ## gölge satırı, iz elipsinin merkezi
	var k: float = st[4]
	var pool: float = round(_lerp_stage(POOL, st[2], st[3], _ease_back(k)) * 2.0) * 0.5
	var spark: float = _band((1.0 - k * 2.0) * float(st[5])) if k < 0.5 else 0.0
	mat.set_shader_parameter("leaf_a", leaf_a)
	mat.set_shader_parameter("leaf_b", leaf_b)
	mat.set_shader_parameter("p0", Vector4(r, pool, st[5], 0.0))
	mat.set_shader_parameter("p1", Vector4(float(n), float(N_LEAF[st[2]]), spark, 0.0))
