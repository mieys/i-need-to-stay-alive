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

	## 1) Arkada kalan sönümlenen parıltılar.
	for p in _trail:
		var a: float = 1.0 - float(p["age"]) / float(p["life"])
		draw_circle(p["pos"] as Vector2, float(p["size"]),
			Color(light.r, light.g, light.b, a * 0.55 * alpha))

	## 2) Simgenin yörüngesinde dönen iki küçük cini.
	for i in 2:
		var oa := _elapsed * 6.0 + float(i) * PI
		var mopos := head + Vector2.from_angle(oa) * 9.0
		draw_circle(mopos, 2.0, Color(wave_color.r, wave_color.g, wave_color.b, 0.8 * alpha))
		draw_circle(mopos, 0.9, Color(1, 1, 1, 0.9 * alpha))

	## 3) Kalkan simgesi - hafif sallanarak süzülür; üç katman kontur
	## (kalın saydam -> orta -> ince parlak) hale hissi verir.
	var sway := sin(_elapsed * 9.0) * 0.12
	var pts := _glyph_outline(head, sway)
	draw_polyline(pts, Color(wave_color.r, wave_color.g, wave_color.b, 0.22 * alpha), 7.0, true)
	draw_polyline(pts, Color(wave_color.r, wave_color.g, wave_color.b, 0.65 * alpha), 3.0, true)
	draw_polyline(pts, Color(light.r, light.g, light.b, alpha), 1.5, true)
	draw_colored_polygon(pts, Color(wave_color.r, wave_color.g, wave_color.b, 0.25 * alpha))
	## Simge üstündeki parlak çekirdek.
	draw_circle(head + Vector2(0, -3).rotated(sway), 2.0, Color(1, 1, 1, 0.85 * alpha))


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


func _draw_arrival() -> void:
	var t := clampf((_elapsed - travel_time) / ripple_time, 0.0, 1.0)
	var fade := 1.0 - t
	var light := wave_color.lightened(0.45)

	## 1) Yukarı savrulan kıvılcımlar.
	for p in _sparks:
		var a: float = 1.0 - float(p["age"]) / float(p["life"])
		draw_circle(p["pos"] as Vector2, float(p["size"]),
			Color(light.r, light.g, light.b, a * 0.8))

	## 2) Dönen altıgen halka (kalkan simgesinin büyüyüp dağılması).
	var radius := 10.0 + 26.0 * t
	var rot := t * 0.7
	var pts := PackedVector2Array()
	for i in 7:
		var a := rot + float(i % 6) * TAU / 6.0
		pts.append(end_pos + Vector2.from_angle(a) * radius)
	draw_polyline(pts, Color(wave_color.r, wave_color.g, wave_color.b, fade * 0.9), 2.5, true)

	## 3) İçe dolan dolgu flaşı.
	var fill_pts := PackedVector2Array()
	for i in 7:
		var a := -rot * 0.6 + float(i % 6) * TAU / 6.0
		fill_pts.append(end_pos + Vector2.from_angle(a) * radius * (1.0 - t * 0.45))
	draw_colored_polygon(fill_pts, Color(wave_color.r, wave_color.g, wave_color.b, fade * 0.22))

	## 4) Merkez parlaması.
	draw_circle(end_pos, 10.0 + 14.0 * t, Color(wave_color.r, wave_color.g, wave_color.b, fade * 0.25))
	draw_circle(end_pos, 6.0 * (1.0 - t) + 2.0, Color(1, 1, 1, fade * 0.7))


## ---------- Totemin kendi nabız halkası (spawn_pulse) ----------

func _draw_pulse() -> void:
	var t := clampf(_elapsed / ripple_time, 0.0, 1.0)
	var fade := 1.0 - t
	var light := wave_color.lightened(0.45)

	## Yumuşak merkez parlaması.
	draw_circle(start_pos, 8.0 + 10.0 * t, Color(wave_color.r, wave_color.g, wave_color.b, fade * 0.18))

	## Büyüyen çift halka.
	var radius := 8.0 + 34.0 * t
	draw_arc(start_pos, radius, 0.0, TAU, 40, Color(wave_color.r, wave_color.g, wave_color.b, fade * 0.7), 2.0, true)
	draw_arc(start_pos, radius * 0.62, 0.0, TAU, 32, Color(light.r, light.g, light.b, fade * 0.45), 1.5, true)

	## Dönen 6 ışıyan çizgi.
	var rot := t * 1.2
	for i in 6:
		var a := rot + float(i) * TAU / 6.0
		var from := start_pos + Vector2.from_angle(a) * (radius * 0.85)
		var to := start_pos + Vector2.from_angle(a) * (radius * 1.15)
		draw_line(from, to, Color(light.r, light.g, light.b, fade * 0.55), 2.0, true)


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
