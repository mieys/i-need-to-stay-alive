extends Node2D
class_name TotemShieldWave

## KOZMETİK efekt (SADECE GÖRSEL, hiçbir oyun mantığı YOK) - YENİDEN TASARIM:
## Kalkan Totemi'nden müttefike doğru süzülen küçük, parlayan bir KALKAN
## SİMGESİ. Yumuşak, hafif yukarı kamburlaşan bir yay (quadratic bezier)
## çizerek uçar; etrafında iki küçük cini döner, arkasında sönümlenen
## parıltılar bırakır. Hedefe varınca dönen altıgen bir halka + yükselen
## kıvılcımlarla "kalkan uygulandı" hissi verir ve kaybolur.
##
## Kalkan miktarı hesabı buraya TAMAMEN dışarıdadır (bkz. totem_shield.gd
## _tick) - bu node silinse bile skilin davranışı hiç değişmez. totem_shield.gd
## AYNI spawn/spawn_pulse API'sini çağırdığı için imzalar ve null-guard'lar
## korunmuştur (bkz. tests/test_totem_shield_wave_v2.gd).
##
## ESKİ TASARIMDAN FARKLAR: )))-biçimli radyo yayları yerine uçan kalkan
## simgesi; ayrıca eski _draw'daki "dist < 1.0: return" erken çıkışı yüzünden
## spawn_pulse (start==end) HİÇ ÇİZİLMİYORDU - nabız halkası artık kendi
## _draw_pulse moduyla gerçekten görünür.

## Kullanıcı isteği (2026-09-21): Shaman totem efektleri SIFIRDAN pixel tarzında (1 texel detay, bkz. hafıza "Pixel density 48x48"):
## düzgün çizgi/daire/çokgen çizimleri kaldırıldı, hepsi PixelDraw ile ızgaraya oturan pixel'ler. API (spawn/spawn_pulse/_glyph_*/_draw_*)
## korundu.
const PixelDraw := preload("res://scripts/pixel_draw.gd")

## Uçan pixel kalkan simgesi (7x8): k = koyu hat, b = ana renk, w = parlak, . = boş
const SHIELD_ART := [
	"kkkkkkk",
	"kbbwbbk",
	"kbwwwbk",
	"kbbwbbk",
	"kbbbbbk",
	".kbbbk.",
	"..kbk..",
	"...k...",
]

var start_pos: Vector2 = Vector2.ZERO
## Dalga hedefi (Player/RemotePlayer). Takip ederken konumunu canlı okuruz;
## hedef sahneden silinirse en son bilinen konumda ripple ile biter.
var ally_ref: Node2D = null
var end_pos: Vector2 = Vector2.ZERO
var wave_color: Color = Color(0.35, 0.65, 1.0)

var travel_time: float = 0.5
var ripple_time: float = 0.3

var _elapsed: float = 0.0
var _arrival_started: bool = false
var _trail_acc: float = 0.0
## Uçuş izindeki parıltılar.
var _trail: Array[Dictionary] = []
## Varış anında savrulan kıvılcımlar.
var _sparks: Array[Dictionary] = []

## Kalkan simgesinin yerel konturu (merkezli, ~18px boyunda): üstte hafif
## çentikli omuzlar, alta doğru sivrilen klasik kalkan silueti.
const GLYPH_POINTS := [
	Vector2(-6, -7), Vector2(0, -9), Vector2(6, -7),
	Vector2(6, -1), Vector2(0, 9), Vector2(-6, -1),
]


## global_position tabanlı çalışır (top_level=true, bkz. _ready) - ebeveynin
## transformundan bağımsız, sahne köküne eklenir.
static func spawn_pulse(parent: Node, p_center: Vector2, p_color: Color) -> void:
	## Totemden her tick'te yayılan KISA nabız halkası - dalga hedefi
	## menzilde olmasa bile totemin canlı olduğunu/kalkan verildiğini her
	## açıdan görünür kılar (tek oyunculu mod dahil).
	if parent == null or not is_instance_valid(parent):
		return
	var pulse: TotemShieldWave = TotemShieldWave.new()
	pulse.start_pos = p_center
	pulse.end_pos = p_center
	pulse.wave_color = p_color
	pulse.travel_time = 0.0
	pulse.ripple_time = 0.45
	parent.add_child(pulse)


static func spawn(parent: Node, p_start: Vector2, p_ally: Node2D, p_color: Color) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if p_ally == null or not is_instance_valid(p_ally):
		return
	var wave: TotemShieldWave = TotemShieldWave.new()
	wave.start_pos = p_start
	wave.ally_ref = p_ally
	wave.end_pos = p_ally.global_position
	wave.wave_color = p_color
	parent.add_child(wave)


func _ready() -> void:
	top_level = true
	position = Vector2.ZERO
	z_index = 60


## Gece ışığı (bkz. night_glow.gd): kök (0,0)'da - ışık totemden müttefike dalga boyunca.
func get_glow_segment() -> Array:
	return [start_pos, end_pos]


func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(ally_ref):
		end_pos = ally_ref.global_position
	## Uçuş -> varış geçişi: kıvılcım patlaması (bir kez).
	if _elapsed > travel_time and not _arrival_started:
		_arrival_started = true
		_burst_arrival_sparks()
	## Uçuş sırasında sabit oranla iz parıltısı bırak.
	if travel_time > 0.0 and _elapsed <= travel_time:
		_trail_acc += delta
		while _trail_acc >= 0.024 and _trail.size() < 24:
			_trail_acc -= 0.024
			_emit_trail_sparkle(_glyph_head())
	if _trail_acc > 0.1:
		_trail_acc = 0.0
	_update_particles(delta)
	if _elapsed >= travel_time + ripple_time:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if travel_time <= 0.0:
		_draw_pulse()
	elif _elapsed <= travel_time:
		_draw_travel()
	else:
		_draw_arrival()


## ---------- Uçuş ----------

## Uçuş yolu: totemden hedefe yumuşak, hafif yukarı kamburlaşan yay.
func _bezier_point(t: float) -> Vector2:
	var ctrl: Vector2 = (start_pos + end_pos) * 0.5 \
		+ Vector2(0, -start_pos.distance_to(end_pos) * 0.22)
	var inv := 1.0 - t
	return inv * inv * start_pos + 2.0 * inv * t * ctrl + t * t * end_pos


func _glyph_head() -> Vector2:
	if travel_time <= 0.0:
		return end_pos
	var t := clampf(_elapsed / travel_time, 0.0, 1.0)
	var smooth_t := t * t * (3.0 - 2.0 * t)
	return _bezier_point(smooth_t)


## Kalkan simgesinin o anki (sallanmış) kapalı kontur noktaları.
func _glyph_outline(center: Vector2, sway: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in GLYPH_POINTS:
		pts.append(center + (p as Vector2).rotated(sway))
	pts.append(pts[0])
	return pts


func _draw_travel() -> void:
	var head: Vector2 = _glyph_head()
	var t := clampf(_elapsed / travel_time, 0.0, 1.0)
	## Başta kısa fade-in, sonda yumuşak fade-out.
	var alpha: float = 1.0
	if t < 0.1:
		alpha = t / 0.1
	elif t > 0.9:
		alpha = (1.0 - t) / 0.1
	var light := wave_color.lightened(0.45)
	var dark := wave_color.darkened(0.45)

	## 1) Arkada kalan sönümlenen pixel parıltılar.
	for p in _trail:
		var a: float = 1.0 - float(p["age"]) / float(p["life"])
		PixelDraw.px(self, p["pos"] as Vector2, 1, Color(light.r, light.g, light.b, a * 0.8 * alpha))

	## 2) Simgenin yörüngesinde dönen iki minik pixel.
	for i in 2:
		var oa := _elapsed * 6.0 + float(i) * PI
		var mopos := head + Vector2.from_angle(oa) * 9.0
		PixelDraw.px(self, mopos, 1, Color(wave_color.r, wave_color.g, wave_color.b, 0.9 * alpha))
		PixelDraw.px(self, mopos + Vector2(PixelDraw.TEXEL, 0), 1, Color(1, 1, 1, 0.8 * alpha))

	## 3) Pixel kalkan simgesi - hafif sallanarak süzülür (bkz. SHIELD_ART).
	var sway: float = sin(_elapsed * 9.0) * PixelDraw.TEXEL * 0.8
	var pal := {
		"k": Color(dark.r, dark.g, dark.b, alpha),
		"b": Color(wave_color.r, wave_color.g, wave_color.b, alpha),
		"w": Color(light.r, light.g, light.b, alpha),
	}
	PixelDraw.art(self, head + Vector2(sway, 0), SHIELD_ART, pal, 1.0)
	## Simge üstünde kısa bir parlama çizgisi
	PixelDraw.px(self, head + Vector2(sway - PixelDraw.TEXEL, -PixelDraw.TEXEL * 2.0), 1, Color(1, 1, 1, 0.85 * alpha))


## ---------- Varış ----------

func _burst_arrival_sparks() -> void:
	for i in 8:
		## Açı ağırlıklı olarak yukarı (-PI..0) - kalkan "yükselir" hissi.
		var angle := randf_range(-PI, 0.0)
		_sparks.append({
			"pos": end_pos,
			"vel": Vector2.from_angle(angle) * randf_range(40.0, 110.0),
			"age": 0.0,
			"life": randf_range(0.25, 0.5),
			"size": randf_range(1.5, 2.8),
		})


func _hex_ring(center: Vector2, radius: float, rot: float, col: Color) -> void:
	var prev: Vector2 = center + Vector2.from_angle(rot) * radius
	for i in range(1, 7):
		var nxt: Vector2 = center + Vector2.from_angle(rot + float(i) * TAU / 6.0) * radius
		PixelDraw.line(self, prev, nxt, col, 1)
		prev = nxt


func _draw_arrival() -> void:
	var t := clampf((_elapsed - travel_time) / ripple_time, 0.0, 1.0)
	var fade := 1.0 - t
	var light := wave_color.lightened(0.45)

	## 1) Yukarı savrulan pixel kıvılcımlar.
	for p in _sparks:
		var a: float = 1.0 - float(p["age"]) / float(p["life"])
		PixelDraw.px(self, p["pos"] as Vector2, 1 if float(p["size"]) < 2.2 else 2, Color(light.r, light.g, light.b, a * 0.9))

	## 2) Dönen pixel altıgen halka (kalkanın oturması) - iki halka, içteki ters döner.
	var radius := 10.0 + 26.0 * t
	_hex_ring(end_pos, radius, t * 0.7, Color(wave_color.r, wave_color.g, wave_color.b, fade * 0.95))
	_hex_ring(end_pos, radius * 0.62, -t * 1.1, Color(light.r, light.g, light.b, fade * 0.55))

	## 3) Merkez parlaması: kısa dither + parlak çekirdek.
	if t < 0.5:
		PixelDraw.disc_dither(self, end_pos, 12.0 * (1.0 - t), Color(wave_color.r, wave_color.g, wave_color.b, 0.55 * fade), int(_elapsed * 40.0), 1)
	PixelDraw.px(self, end_pos, 2 if t < 0.4 else 1, Color(1, 1, 1, fade * 0.9))


## ---------- Totemin kendi nabız halkası (spawn_pulse) ----------

func _draw_pulse() -> void:
	var t := clampf(_elapsed / ripple_time, 0.0, 1.0)
	var fade := 1.0 - t
	var light := wave_color.lightened(0.45)

	## Kısa merkez parlaması (dither).
	if t < 0.4:
		PixelDraw.disc_dither(self, start_pos, 8.0 + 8.0 * t, Color(wave_color.r, wave_color.g, wave_color.b, 0.4 * (1.0 - t / 0.4)), int(_elapsed * 40.0), 1)

	## Büyüyen çift pixel halka (yer düzlemine hafif basık - 3/4 görünüm).
	var radius := 8.0 + 34.0 * t
	PixelDraw.ring(self, start_pos, radius, Color(wave_color.r, wave_color.g, wave_color.b, fade * 0.85), 1)
	PixelDraw.ring(self, start_pos, radius * 0.62, Color(light.r, light.g, light.b, fade * 0.55), 1, 3, 2, _elapsed * 16.0)

	## Dönen 6 ışıyan pixel işaret.
	var rot := t * 1.2
	for i in 6:
		var a := rot + float(i) * TAU / 6.0
		var from := start_pos + Vector2.from_angle(a) * (radius * 0.9)
		var to := start_pos + Vector2.from_angle(a) * (radius * 1.15)
		PixelDraw.line(self, from, to, Color(light.r, light.g, light.b, fade * 0.7), 1)


## ---------- Parçacık ortak güncelleme ----------

func _update_particles(delta: float) -> void:
	_step_particle_list(_trail, delta)
	_step_particle_list(_sparks, delta)
	for i in range(_trail.size() - 1, -1, -1):
		if float(_trail[i]["age"]) >= float(_trail[i]["life"]):
			_trail.remove_at(i)
	for i in range(_sparks.size() - 1, -1, -1):
		if float(_sparks[i]["age"]) >= float(_sparks[i]["life"]):
			_sparks.remove_at(i)


func _step_particle_list(list: Array[Dictionary], delta: float) -> void:
	for p in list:
		p["age"] = float(p["age"]) + delta
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta


func _emit_trail_sparkle(at: Vector2) -> void:
	_trail.append({
		"pos": at + Vector2(randf_range(-3, 3), randf_range(-3, 3)),
		"vel": Vector2(randf_range(-8, 8), randf_range(-14, -4)),
		"age": 0.0,
		"life": randf_range(0.25, 0.45),
		"size": randf_range(1.5, 3.0),
	})
