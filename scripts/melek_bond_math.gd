extends RefCounted

## Melek Q/E bağı "A Işık İpi" (madde 212) - sabitler + saf hesaplar. Kullananlar: melek_bond_fx.gd (dostun bel halkası +
## yaşam döngüsü), melek_bond_ribbon.gd (ip şeridi), melek_halo_fx.gd (Melek'in halesi), tests/test_melek_bond_fx.gd.
## Formüller prototiple aynı (tools/proto_20261017/gen_melek_bag.py bond_a); prototip 15 kare/sn çizildi, süreler saniyeye çevrildi.

const HaloTable := preload("res://scripts/melek_halo_table.gd")

## 1 sanat pikseli = 1 Melek pikseli (dünya birimi) - halka/glif sayfaları (tools/gen_melek_bond_fx.py) bu yoğunlukta.
const TEXEL_W := 2.2368375 * EntityScale.SIZE * 0.5
const PROTO_FPS := 15.0
const HEAD_TIME := 7.0 / PROTO_FPS ## kuruluş: parlak baş Melek'in halesinden dosta
const WAVE_SPEED := 13.0 * PROTO_FPS ## dalga paketi, sanat pikseli/sn (~176 dünya/sn)
const DISSOLVE_TIME := 7.0 / PROTO_FPS
const BRIGHT_TIME := 2.0 / PROTO_FPS
const LIFT := 5.0 ## kavis: ipin ortası bu kadar sanat pikseli yukarıda (Bezier kontrol noktası 2x)
const SAMPLE_STEP := 3.0 ## ip örnek aralığı (sanat pikseli; dalga paketi 19 px'lik dalga boyunda 6 örnek, sapma doğrusal aradeğer)
const STRIP_HALF := 7.5 ## şerit ağının yarı genişliği (sapma + yarı genişlik + kontur + hücre payı)
const RING_RX := 9.5 ## dostun bel halkası yarıçapı (sanat pikseli)

## [kontur, koyu, orta, açık, parlak] - prototiple aynı
const LIFE := [Color8(22, 64, 30), Color8(46, 142, 60), Color8(96, 208, 98), Color8(178, 248, 160), Color8(242, 255, 230)]
const MANA := [Color8(18, 34, 88), Color8(40, 88, 186), Color8(86, 148, 242), Color8(166, 208, 255), Color8(238, 248, 255)]
const HOLY := [Color8(92, 58, 18), Color8(186, 130, 36), Color8(240, 194, 72), Color8(255, 230, 140), Color8(255, 252, 222)]
const CREAM := Color8(255, 250, 228)


static func palette(kind: String) -> Array:
	return MANA if kind == "shield" else LIFE


## Dalga paketi geçerken: Q yeşilden hale altınına, E kreme.
static func hot_palette(kind: String) -> Array:
	return [MANA[0], MANA[1], MANA[3], MANA[4], CREAM] if kind == "shield" else [LIFE[0], LIFE[1], HOLY[2], HOLY[3], CREAM]


## Kuruluşta koşan başın s'i (ease_out); kuruluş bittiyse total + 1 (ip tam).
static func head_s(t: float, total: float) -> float:
	if t >= HEAD_TIME:
		return total + 1.0
	var u: float = clampf(t / HEAD_TIME, 0.0, 1.0)
	return total * (1.0 - (1.0 - u) * (1.0 - u))


## Taban eğrisinin (p0 = 0 -> p1, kontrol ortada 2*LIFT yukarı) yaklaşık yay boyu.
static func bezier_length(p1: Vector2) -> float:
	var ctrl: Vector2 = p1 * 0.5 + Vector2(0.0, -2.0 * LIFT)
	var acc: float = 0.0
	var prev := Vector2.ZERO
	for i in range(1, 25):
		var u: float = i / 24.0
		var b: Vector2 = 2.0 * (1.0 - u) * u * ctrl + u * u * p1
		acc += b.distance_to(prev)
		prev = b
	return acc


## Bitiş: ortadan başlayan, hilal gibi incelen kopmalar -> yarı genişlik çarpanı 0..1.
static func dissolve_keep(s: float, total: float, dis: float) -> float:
	if dis <= 0.0:
		return 1.0
	var u: float = s / maxf(total, 1.0)
	var pat: float = 0.55 * sin(u * 23.0 + 1.7) + 0.45 * sin(u * 9.0 + 1.7 * 2.3)
	var mid: float = 1.0 - absf(u - 0.5) * 2.0
	var thr: float = 1.0 - 2.2 * dis - 0.6 * mid * dis
	return pow(clampf((thr - pat) / 0.5, 0.0, 1.0), 0.7)


## İp örnekleri (sanat pikseli uzayı, kök = halenin pikseli), paketli diziler: {"base", "nrm": PackedVector2Array (taban
## noktası, yukarı yönlü normal), "s", "disp", "hw": PackedFloat32Array (yay boyu, sapma, yarı genişlik), "hot": PackedByteArray
## (dalga paketi), "total": float}. p1: bitiş (p0'a göre); t: sn (duran dalga); packets: [Vector2(merkez s, ağırlık)];
## head: başın s'i; dis: çözülme 0..1. FPS (madde 170/194 dersi): 300 dünyalık en uzun bağda iç içe Array + her örnekte her
## paket için exp/pow kare başı ~1,2 ms tutuyordu -> paketli diziler, 3 px örnek aralığı, paketten uzak örnekte exp yok.
static func ribbon_samples(p1: Vector2, t: float, packets: Array, head: float, dis: float) -> Dictionary:
	var n: int = maxi(8, int(p1.length() / SAMPLE_STEP) + 2)
	var ctrl: Vector2 = p1 * 0.5 + Vector2(0.0, -2.0 * LIFT)
	var c2: Vector2 = 2.0 * ctrl
	var d2: Vector2 = 2.0 * (p1 - 2.0 * ctrl) ## teğet = c2 + u * d2
	var base := PackedVector2Array()
	var nrm := PackedVector2Array()
	var sv := PackedFloat32Array()
	base.resize(n + 1)
	nrm.resize(n + 1)
	sv.resize(n + 1)
	var s_acc: float = 0.0
	var prev := Vector2.ZERO
	for i in range(n + 1):
		var u: float = float(i) / n
		var b: Vector2 = (c2 * (1.0 - u) + p1 * u) * u
		var tan: Vector2 = c2 + d2 * u
		if i > 0:
			s_acc += b.distance_to(prev)
		prev = b
		base[i] = b
		var tl: float = tan.length()
		nrm[i] = Vector2(tan.y, -tan.x) / tl if tl > 1e-6 else Vector2.UP
		sv[i] = s_acc
	var total: float = s_acc
	var disp := PackedFloat32Array()
	var hw := PackedFloat32Array()
	var hot := PackedByteArray()
	disp.resize(n + 1)
	hw.resize(n + 1)
	hot.resize(n + 1)
	var np: int = packets.size()
	var ph: float = 0.9 * t
	for i in range(n + 1):
		var s: float = sv[i]
		var edge: float = minf(s, total - s)
		var taper: float = 1.0 if edge >= 10.0 else pow(clampf(edge / 10.0, 0.0, 1.0), 0.6)
		var g: float = 0.0
		var osc: float = 0.0
		for k in range(np):
			var pk: Vector2 = packets[k]
			var q: float = s - pk.x
			if q > -30.0 and q < 30.0:
				var qa: float = q * 0.1
				var qb: float = q / 9.0
				g = maxf(g, pk.y * exp(-qa * qa))
				osc += pk.y * exp(-qb * qb) * sin(TAU * q / 19.0)
		disp[i] = (sin(TAU * (s / 30.0 - ph)) + 3.0 * osc) * taper
		var w: float = (0.9 + 0.9 * g) * (0.55 + 0.45 * taper)
		if dis > 0.0:
			w *= dissolve_keep(s, total, dis)
		if s > head:
			w = 0.0
		elif head < total:
			w *= clampf((head - s) / 6.0 + 0.35, 0.0, 1.0)
		hw[i] = w
		hot[i] = 1 if g > 0.35 else 0
	return {"base": base, "nrm": nrm, "s": sv, "disp": disp, "hw": hw, "hot": hot, "total": total}


## Melek'in halesinin `toward` tarafındaki altın pikselinin DÜNYA konumu (melek_halo_table.gd) + o sprite'ın piksel ızgarası.
## Dönüş: [nokta, ızgara kökü (karenin sol üst köşesi), sanat pikselinin dünya boyu]. Kayıt yoksa sprite'ın tepe ortası.
static func halo_point(caster: Node2D, toward: Vector2) -> Array:
	var s: AnimatedSprite2D = null
	if caster != null and is_instance_valid(caster):
		s = caster.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if s == null or s.sprite_frames == null or not s.sprite_frames.has_animation(s.animation):
		var p: Vector2 = caster.global_position if caster != null and is_instance_valid(caster) else Vector2.ZERO
		return [p + Vector2(0.0, -32.0), p, TEXEL_W]
	var tex: Texture2D = s.sprite_frames.get_frame_texture(s.animation, s.frame)
	var size := Vector2(48.0, 48.0)
	var px := Vector2(24.0, 4.5)
	if tex is AtlasTexture:
		var at := tex as AtlasTexture
		size = at.region.size
		var sheet: String = at.atlas.resource_path.get_file().get_basename() if at.atlas != null else ""
		var by_sheet: Dictionary = HaloTable.POINTS.get(sheet, {})
		var pts: Variant = by_sheet.get(Vector2i(at.region.position), null)
		if pts != null:
			var left: Vector2 = pts[0]
			var right: Vector2 = pts[1]
			if s.flip_h:
				left = Vector2(size.x - left.x, left.y)
				right = Vector2(size.x - right.x, right.y)
			var a: Vector2 = s.to_global(s.offset + left - size * 0.5)
			var b: Vector2 = s.to_global(s.offset + right - size * 0.5)
			px = left if absf(toward.x - a.x) < absf(toward.x - b.x) else right
	return [s.to_global(s.offset + px - size * 0.5), s.to_global(s.offset - size * 0.5), absf(s.global_scale.x)]


## Glif sayfası karesi (assets/fx/melek_bond/glyphs.png): 0-2 artı r3/r2/r1, 3-4 kristal, 5-8 yıldız 4/3/2/1, 9-10 koşan baş.
static func glyph_frame(kind: String, k: int) -> int:
	match kind:
		"plus_big":
			return 0 if k < 5 else 2
		"plus":
			return 1 if k < 5 else 2
		"crystal":
			return 3 if k < 5 else 4
		"star":
			return 5 + clampi(k, 0, 3)
	return 2
