extends Node2D

## Talon'un Silah Salvosu (E): karakter ile HER silahı arasında pixel-art DEMİR ZİNCİR (kızgın demir: koyu çelik gövde + akkor turuncu ısı).
## Kullanıcı geri bildirimi (2026-09-21): "zincir efektlerini beğenmedim, pixel tarzda daha iyi yap". Eski hali eksene hizalı kare parçalardan
## oluşuyordu; çapraz zincirler kırık dama deseni gibi görünüyordu. Şimdi (1 texel detay, bkz. hafıza "Pixel density 48x48"):
##  - her halka zincir yönüne DÖNDÜRÜLMÜŞ ince oval (pixel'e oturtulmuş), ardışık halkalar dönüşümlü: yüzü bize dönük oval / kenardan görünen çubuk
##    => gerçek iç içe geçmiş zincir okunuşu, hangi açıda olursa olsun
##  - halkaların altında yer gölgesi (çim üstünde okunaklı), ısı dalgası her halkayı sırayla akkor turuncuya çevirir
##  - merkezde beli saran demir kemer halkası (perçinli, dönen turuncu işaret), silah ucunda kenetleyen kelepçe
##  - zincirden zaman zaman uçan kor kıvılcımları
## Player (yetkili) ve RemotePlayer (kozmetik kopya) ikisi de bu sahnenin ebeveyni olabilir: silah konumları player.owned_weapon_nodes /
## remote._weapon_icons'tan okunur, çizim iki tarafta AYNI koddur (bkz. proje kökündeki CLAUDE.md).
## Ömür: TalonMath.SALVO_DURATION (3sn) + kısa toparlanma; zincir merkezden dışa uzar, bitince toplanır.

const PixelDraw := preload("res://scripts/pixel_draw.gd")
const TalonMath := preload("res://scripts/talon_formation_math.gd")

const GROW_TIME := 0.2
const RETRACT_TIME := 0.25
const LINK_PITCH := 4.8 ## texel: iki halka merkezi arası (halka boyundan kısa => iç içe geçer)
const LINK_HALF_LEN := 3.1 ## texel: oval yarı boyu (zincir yönünde)
const LINK_HALF_WID := 1.9 ## texel: oval yarı eni
const BELT_RADIUS := 4.5 ## texel: merkezdeki kemer halkası

const C_IRON_D := Color(0.16, 0.12, 0.13, 1.0)
const C_IRON := Color(0.42, 0.36, 0.4, 1.0)
const C_HEAT_LO := Color(0.62, 0.2, 0.08, 1.0)
const C_HEAT_HI := Color(1.0, 0.62, 0.16, 1.0)
const C_WHITE_HOT := Color(1.0, 0.95, 0.7, 1.0)

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


## Zincir yönüne döndürülmüş ince oval (halka) çerçevesi: pixel'lere oturtulmuş noktalar.
func _oval(center: Vector2, dir: Vector2, half_len: float, half_wid: float, col: Color) -> void:
	var texel: float = PixelDraw.TEXEL
	var normal := Vector2(-dir.y, dir.x)
	const SAMPLES := 14
	for k in range(SAMPLES):
		var a: float = TAU * float(k) / float(SAMPLES)
		var p: Vector2 = center + dir * cos(a) * half_len * texel + normal * sin(a) * half_wid * texel
		PixelDraw.px(self, p, 1, col)


## Kenardan görünen halka: zincir yönünde kısa çubuk (+ üstte 1 texel parlak sırt).
func _bar(center: Vector2, dir: Vector2, col: Color, hi: Color) -> void:
	var texel: float = PixelDraw.TEXEL
	var normal := Vector2(-dir.y, dir.x)
	for s in [-1.5, -0.5, 0.5, 1.5]:
		PixelDraw.px(self, center + dir * texel * s, 1, col)
	PixelDraw.px(self, center + normal * texel * -0.7, 1, hi)


func _heat_color(h: float) -> Color:
	return C_IRON.lerp(C_HEAT_LO, clampf(h * 2.0, 0.0, 1.0)).lerp(C_HEAT_HI, clampf(h * 2.0 - 1.0, 0.0, 1.0))


func _draw() -> void:
	var extent: float = minf(1.0, _t / GROW_TIME)
	extent = minf(extent, clampf((_life() - _t) / RETRACT_TIME, 0.0, 1.0))
	if extent <= 0.0:
		return
	var origin: Vector2 = _host.global_position + Vector2(0, -6)
	var texel: float = PixelDraw.TEXEL
	var pts: Array = _weapon_points()
	var belt_r: float = texel * BELT_RADIUS
	## --- Merkez kemer halkası (zincirlerin bağlandığı yer) ---
	PixelDraw.ring(self, origin + Vector2(0, texel * 1.5), belt_r, Color(0.05, 0.03, 0.03, 0.4 * extent), 1) ## yer gölgesi
	PixelDraw.ring(self, origin, belt_r, C_IRON, 1)
	PixelDraw.ring(self, origin, belt_r - texel, C_IRON_D, 1)
	PixelDraw.ring(self, origin, belt_r, Color(C_HEAT_HI.r, C_HEAT_HI.g, C_HEAT_HI.b, 0.9 * extent), 1, 3, 4, _t * 14.0) ## dönen turuncu işaretler
	for k in range(6): ## perçinler
		var pa: float = float(k) * TAU / 6.0 + _t * 0.5
		PixelDraw.px(self, origin + Vector2(cos(pa), sin(pa)) * belt_r, 1, C_WHITE_HOT if k == 0 else C_IRON)
	for j in range(pts.size()):
		var end_full: Vector2 = pts[j]
		var v: Vector2 = end_full - origin
		var length: float = v.length()
		if length < texel * (BELT_RADIUS + 6.0):
			continue
		var dir: Vector2 = v / length
		var normal := Vector2(-dir.y, dir.x)
		var start_off: float = belt_r ## zincir kemerin kenarından başlar
		var usable: float = length - start_off - texel * 3.5 ## silah ucundaki kelepçeye kadar
		var reach: float = usable * extent
		var pitch: float = texel * LINK_PITCH
		var count: int = int(reach / pitch)
		## Hafif sarkma/titreşim: bağ gergin ama canlı.
		var sag_amp: float = texel * 1.4 * sin(_t * 6.0 + float(j) * 1.9)
		var pulse_f: float = fmod(_t * 1.5 + float(j) * 0.27, 1.0)
		for i in range(count):
			var f: float = (float(i) + 0.5) * pitch / maxf(usable, 1.0)
			var c: Vector2 = origin + dir * (start_off + f * usable) + normal * sag_amp * sin(f * PI)
			## Isı: ısı dalgası merkezden silaha akar; pulse_f'e yakın halkalar akkor
			var heat: float = 0.35 + 0.25 * sin(_t * 3.0 - float(i) * 0.7)
			var dp: float = absf(f - pulse_f)
			if dp < 0.08:
				heat = 1.0 - dp / 0.08 * 0.4
			var col: Color = _heat_color(heat)
			if heat > 0.9:
				col = col.lerp(C_WHITE_HOT, (heat - 0.9) * 6.0)
			## Yer gölgesi
			var shadow := Color(0.05, 0.03, 0.03, 0.35 * extent)
			if i % 2 == 0:
				_oval(c + Vector2(0, texel * 1.6), dir, LINK_HALF_LEN, LINK_HALF_WID, shadow)
				_oval(c, dir, LINK_HALF_LEN, LINK_HALF_WID, C_IRON_D)
				_oval(c, dir, LINK_HALF_LEN - 0.9, LINK_HALF_WID - 0.6, col)
			else:
				_bar(c + Vector2(0, texel * 1.6), dir, shadow, shadow)
				_bar(c, dir, col, C_WHITE_HOT if heat > 0.8 else C_HEAT_HI)
		## Kor kıvılcımı: zincirden yükselen tek pixel
		var seed_i: int = int(_t * 10.0) * 7 + j * 31
		if count > 2 and PixelDraw.hash01(seed_i) < 0.6:
			var k_idx: int = int(PixelDraw.hash01(seed_i + 3) * float(count))
			var rise: float = fmod(_t * 10.0, 1.0)
			var kf: float = (float(k_idx) + 0.5) * pitch / maxf(usable, 1.0)
			var kp: Vector2 = origin + dir * (start_off + kf * usable) + Vector2((PixelDraw.hash01(seed_i + 9) - 0.5) * texel * 3.0, -texel * (2.0 + rise * 7.0))
			PixelDraw.px(self, kp, 1, Color(1.0, 0.7, 0.2, 1.0 - rise))
		## Uç: büyürken parlak uç kıvılcımı
		if extent < 0.999 and count > 0:
			var tip: Vector2 = origin + dir * (start_off + reach)
			PixelDraw.px(self, tip, 2, C_WHITE_HOT)
		## Silah ucu: kenetleyen kelepçe (koyu çelik kare + akkor göz) ve nabız gibi atan ince halka
		if extent >= 0.999:
			var clasp: Vector2 = end_full - dir * texel * 2.5
			PixelDraw.px(self, clasp + Vector2(0, texel * 1.6), 3, Color(0.05, 0.03, 0.03, 0.35))
			PixelDraw.px(self, clasp, 3, C_IRON_D)
			PixelDraw.px(self, clasp, 2, C_IRON)
			var glow: float = 0.6 + 0.4 * sin(_t * 8.0 + float(j))
			PixelDraw.px(self, clasp, 1, C_HEAT_HI.lerp(C_WHITE_HOT, glow))
			var pr: float = texel * (4.0 + 0.7 * sin(_t * 9.0 + float(j)))
			PixelDraw.ring(self, end_full, pr, Color(C_HEAT_HI.r, C_HEAT_HI.g, C_HEAT_HI.b, 0.75), 1, 3, 3, _t * 10.0)
