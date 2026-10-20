extends Node2D

## BANSHEE ÇIĞLIK DALGASI (2026-10-09, kullanıcı: "nereye ses dalgası yollayacağı hakkında uyarı verilir, düz ve kalın çizgiler halinde gönderir, duvarların arkasından geçemez"): dünya efekti.
## Konumdan `dir` yönünde `length` uzunluğunda, `width` kalınlığında şerit. WARN sn uyarı, sonra FIRE sn ses dalgası: şerit içindeki her oyuncuya BİR kez
## `damage` (take_special_damage "scream"). Uzunluğu çağıran duvara kadar kısaltır (enemy_abilities.clip_ray_to_walls). Yetkili örnek hasar verir; istemcideki kopya sadece çizer.
## data: dir (Vector2), length, width, warn, fire, burst (bool: ağızda halka patlaması - banshee_boss.gd çığlık başına TEK şeride koyar).
##
## GÖRÜNÜŞ (2026-10-19, kullanıcı: "ses çığlığı skill efektini daha iyi tasarla"; eski: düz dikdörtgen + ince yay çizgileri). Oyunun FX dili (madde 241 v3 /
## hafıza fx-texel-density): dolu kütleler, 1 piksel koyu arka kenar, krem ön kenar, saydamlık 4 basamaklı bantlarda (dither / nokta serpintisi yok), her uç sivrilir.
##  - UYARI: kapsül şerit (yuvarlak uçlu) soluk dolu gövde + iki yanda kenar rayı; ağızdan uca doğru DOLAN iç bant (dalganın ne zaman çıkacağını gösterir),
##    bandın başında küçük önizleme hilali, arkasında ileri kayan yön okları.
##  - DALGA: gövde krem bir an parlar ve söner; ağızdan uca hızla akan dolu hilal dalga cepheleri (ses dalgası) - şeridin iki ucunda küçülerek biter.
##  - burst: Banshee'nin ağzında iki genişleyen halka + kısa krem parlama.
## Dokular çalışma anında BİR kez üretilir (static önbellek, genişlik başına) - her karede yalnız draw_texture_rect + birkaç çokgen.

const AbilitiesScript := preload("res://scripts/enemy_abilities.gd")

const TEXEL := 0.6 ## dünya px / sanat pikseli (karakter dokusu ~0,6 dünya px; daha iri piksel karakterlerden kaba görünür)
const C_OUT := Color(0.12, 0.10, 0.25)
const C_DEEP := Color(0.29, 0.31, 0.62)
const C_MID := Color(0.45, 0.63, 0.92)
const C_LIGHT := Color(0.70, 0.89, 1.0)
const C_CREAM := Color(0.96, 0.99, 1.0)
const WAVE_SPACING := 36.0 ## ardışık dalga cepheleri arası (px)
const WAVE_TRAVEL_TIME := 0.2 ## ilk cephenin şeridi baştan sona geçme süresi (hasar zaten tüm şeritte - görsel hızla yetişir)
const CHEVRON_SPACING := 58.0
const END_TAPER := 42.0 ## dalga/ok bu mesafede uçlara doğru küçülür
const BURST_TIME := 0.34

static var _wave_tex_cache: Dictionary = {} ## sanat yüksekliği -> ImageTexture
static var _chevron_tex: ImageTexture = null

var data: Dictionary = {}
var authoritative: bool = false
var source: Node2D = null
var damage: float = 0.0

var _dir: Vector2 = Vector2.RIGHT
var _length: float = 400.0
var _width: float = 40.0
var _warn: float = 1.0
var _fire: float = 0.4
var _burst: bool = false
var _t: float = 0.0
var _hit: Dictionary = {}
var _wave_tex: ImageTexture = null
var _capsule: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	z_index = 8
	_dir = Vector2(data.get("dir", Vector2.RIGHT))
	if _dir.length() < 0.01:
		_dir = Vector2.RIGHT
	_dir = _dir.normalized()
	_length = float(data.get("length", 400.0))
	_width = float(data.get("width", 40.0))
	_warn = float(data.get("warn", 1.0))
	_fire = float(data.get("fire", 0.4))
	_burst = bool(data.get("burst", false))
	rotation = _dir.angle()
	_wave_tex = wave_texture(_width)
	_capsule = _capsule_points(0.0, _length, _width * 0.5)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= _warn + _fire:
		queue_free()
		return
	if authoritative and _t >= _warn:
		for p in AbilitiesScript.damageable_players(get_tree()):
			var id: int = (p as Node).get_instance_id()
			if _hit.has(id):
				continue
			if _in_lane((p as Node2D).global_position):
				_hit[id] = true
				AbilitiesScript.deal_special_damage(p, damage, source, "scream")


func _in_lane(world_pos: Vector2) -> bool:
	var local: Vector2 = to_local(world_pos)
	return local.x >= -AbilitiesScript.TARGET_BODY_RADIUS and local.x <= _length + AbilitiesScript.TARGET_BODY_RADIUS \
			and absf(local.y) <= _width * 0.5 + AbilitiesScript.TARGET_BODY_RADIUS


func _process(_delta: float) -> void:
	queue_redraw()


## Saydamlık 4 basamakta (bantlı sönüm, dither yok).
static func band(a: float) -> float:
	return clampf(ceilf(clampf(a, 0.0, 1.0) * 4.0) / 4.0, 0.0, 1.0)


## Uçlara yaklaşan dalga/ok küçülür (sert kesik yok).
func _taper(x: float) -> float:
	return clampf(minf(x, _length - x) / END_TAPER, 0.3, 1.0)


func _draw() -> void:
	var half: float = _width * 0.5
	if _t < _warn:
		_draw_warning(half)
		return
	var ft: float = _t - _warn
	var f: float = clampf(ft / _fire, 0.0, 1.0)
	## Gövde: krem parlama (ilk ~%30) -> soluk mavi, bantlı sönüm.
	var flash: float = band(1.0 - f / 0.3)
	if flash > 0.0:
		draw_colored_polygon(_capsule, Color(C_CREAM, 0.42 * flash))
	draw_colored_polygon(_capsule, Color(C_MID, 0.22 * band(1.0 - f)))
	draw_colored_polygon(_capsule_points(0.0, _length, half * 0.42), Color(C_LIGHT, 0.30 * band(1.0 - f)))
	## Dalga cepheleri: ilk cephe WAVE_TRAVEL_TIME'da uca varır, arkasından eşit aralıklı tren; hepsi ileri akar.
	var speed: float = maxf(_length / WAVE_TRAVEL_TIME, 900.0)
	var lead: float = ft * speed
	var alpha: float = band(1.15 - f)
	var tw: float = float(_wave_tex.get_width()) * TEXEL
	var th: float = float(_wave_tex.get_height()) * TEXEL
	var i: int = 0
	while true:
		var x: float = lead - float(i) * WAVE_SPACING
		i += 1
		if x < 0.0:
			break
		if x > _length:
			continue
		var s: float = _taper(x) * (1.0 if i % 2 == 1 else 0.84)
		var w: float = tw * (0.6 + 0.4 * s)
		draw_texture_rect(_wave_tex, Rect2(x - w, -th * s * 0.5, w, th * s), false, Color(1, 1, 1, alpha))
	if _burst:
		_draw_burst(ft)


func _draw_warning(half: float) -> void:
	var k: float = _t / _warn
	var pulse: float = 0.5 + 0.5 * sin(_t * 16.0)
	## Soluk dolu gövde (giderek koyulaşır) + iki kenar rayı.
	draw_colored_polygon(_capsule, Color(C_DEEP, 0.10 + 0.12 * band(k)))
	var rail_a: float = 0.45 + 0.25 * band(pulse)
	var rail_h: float = TEXEL * 2.0
	var r0: float = minf(half * 0.6, _length * 0.5)
	draw_rect(Rect2(r0, -half, maxf(_length - r0 * 2.0, 0.0), rail_h), Color(C_LIGHT, rail_a))
	draw_rect(Rect2(r0, half - rail_h, maxf(_length - r0 * 2.0, 0.0), rail_h), Color(C_LIGHT, rail_a))
	## Ağızdan uca dolan iç bant: dalga, bant uca vardığında çıkar.
	var fill_x: float = _length * k
	if fill_x > 2.0:
		draw_colored_polygon(_capsule_points(0.0, fill_x, half * 0.34), Color(C_LIGHT, 0.26))
		var s: float = 0.55 * _taper(fill_x)
		var tw: float = float(_wave_tex.get_width()) * TEXEL * 0.7
		var th: float = float(_wave_tex.get_height()) * TEXEL * s
		draw_texture_rect(_wave_tex, Rect2(fill_x - tw, -th * 0.5, tw, th), false, Color(1, 1, 1, 0.75))
	## Yön okları: dolan bandın arkasında yavaşça ileri kayar.
	var chev: ImageTexture = chevron_texture()
	var cw: float = float(chev.get_width()) * TEXEL
	var ch: float = float(chev.get_height()) * TEXEL
	var x: float = fmod(_t * 70.0, CHEVRON_SPACING) + CHEVRON_SPACING * 0.5
	while x < fill_x - cw:
		var cs: float = _taper(x)
		draw_texture_rect(chev, Rect2(x - cw * 0.5, -ch * cs * 0.5, cw, ch * cs), false, Color(1, 1, 1, 0.5))
		x += CHEVRON_SPACING


func _draw_burst(ft: float) -> void:
	for ring in 2:
		var lt: float = ft - float(ring) * 0.09
		if lt < 0.0 or lt > BURST_TIME:
			continue
		var e: float = lt / BURST_TIME
		var ease_e: float = 1.0 - pow(1.0 - e, 2.0)
		var r: float = lerpf(10.0, 64.0 - 14.0 * float(ring), ease_e)
		var w: float = lerpf(7.0, 1.5, e)
		var a: float = band(1.0 - e)
		draw_arc(Vector2.ZERO, r + w * 0.5 + TEXEL, 0.0, TAU, 40, Color(C_OUT, 0.55 * a), TEXEL * 1.5, false)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(C_LIGHT if ring == 0 else C_MID, 0.9 * a), w, false)
	var glow: float = band(1.0 - ft / 0.18)
	if glow > 0.0:
		draw_circle(Vector2.ZERO, 12.0, Color(C_CREAM, 0.55 * glow), true, -1.0, false)


## Yuvarlak uçlu kapsül (x0..x1, yarım kalınlık h) - uyarı/dalga gövdesi sert köşeli bitmesin.
static func _capsule_points(x0: float, x1: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r: float = minf(h, (x1 - x0) * 0.5)
	if r <= 0.1:
		return PackedVector2Array([Vector2(x0, -h), Vector2(x1, -h), Vector2(x1, h), Vector2(x0, h)])
	var steps: int = 6
	for s in steps + 1: ## sağ uç (üstten alta)
		var a: float = -PI * 0.5 + PI * float(s) / float(steps)
		pts.append(Vector2(x1 - r + cos(a) * r, sin(a) * h))
	for s in steps + 1: ## sol uç (alttan üste)
		var a: float = PI * 0.5 + PI * float(s) / float(steps)
		pts.append(Vector2(x0 + r + cos(a) * r, sin(a) * h))
	return pts


## Dolu hilal dalga cephesi ")" - ön kenar krem, gövde açık -> orta mavi, arka kenar koyu çizgi; uçlara doğru incelir.
static func wave_texture(lane_width: float) -> ImageTexture:
	var h: int = maxi(12, int(round(lane_width / TEXEL)))
	if _wave_tex_cache.has(h):
		return _wave_tex_cache[h]
	var bulge: float = 9.0
	var thick: float = 7.0
	var w: int = int(ceil(bulge + thick)) + 2
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mid_y: float = (float(h) - 1.0) * 0.5
	for y in h:
		var v: float = absf(float(y) - mid_y) / maxf(mid_y, 1.0)
		var front: float = float(w) - 1.0 - bulge * v * v ## ön kenar: ortada en önde, uçlarda geride
		var t: float = maxf(1.0, thick * (1.0 - pow(v, 1.6))) ## kalınlık uçlarda 1 piksele iner
		for x in w:
			var d: float = front - float(x) ## ön kenardan geriye mesafe
			if d < 0.0 or d > t:
				continue
			var c: Color
			if d < 1.0:
				c = Color(C_CREAM, 1.0)
			elif d < t * 0.45:
				c = Color(C_LIGHT, 0.95)
			elif d < t - 1.0:
				c = Color(C_MID, 0.85)
			else:
				c = Color(C_OUT, 0.8) if t >= 3.0 else Color(C_DEEP, 0.8)
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_wave_tex_cache[h] = tex
	return tex


## Küçük ">" yön oku (2 piksel kalın, koyu arka kenar).
static func chevron_texture() -> ImageTexture:
	if _chevron_tex != null:
		return _chevron_tex
	var w: int = 9
	var h: int = 15
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mid: int = int(h * 0.5)
	for y in h:
		var x_front: int = int(float(w - 2) - float(absi(y - mid)) * float(w - 3) / float(mid))
		for k in 3:
			var x: int = x_front - k
			if x < 0 or x >= w:
				continue
			img.set_pixel(x, y, Color(C_OUT, 0.7) if k == 2 else Color(C_LIGHT, 1.0) if k == 0 else Color(C_MID, 0.95))
	_chevron_tex = ImageTexture.create_from_image(img)
	return _chevron_tex
