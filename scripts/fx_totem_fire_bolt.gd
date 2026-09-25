extends Node2D
class_name TotemFireBolt

## KOZMETİK efekt (hiçbir oyun mantığı YOK): Saldırı Totemi'nin yeteneğine özgü ateş topu. Totemin tepesindeki yaşayan alevden hedef
## düşmana doğru uçan bir ateş meteoru; arkasında sönen alev kuyruğu, çevresinde dönen kızgın kıvılcımlar, varışta patlayan ateş.
##
## Hasar hesabı buraya TAMAMEN dışarıdadır (bkz. totem_attack.gd _tick - enemy.take_damage). Bu node silinse bile skilin davranışı hiç
## değişmez. Kalkan Totemi'nin dalga efektiyle (totem_shield_wave.gd) AYNI "salt çizim" desenini kullanır: global_position tabanlı,
## top_level, sahne köküne eklenir.
##
## Kullanıcı geri bildirimi (2026-09-22): "ateş eden totemin ateş efekti berbat" -> SIFIRDAN yeniden çizildi (1 texel pixel-art, PixelDraw):
##  - UÇUŞ: katmanlı (kırmızı-turuncu-sarı-beyaz) yuvarlak ateş topu + yol boyunca ANALİTİK hesaplanan alev kuyruğu (kare hızından
##    bağımsız uzunluk, uzaklaştıkça küçülüp koyulaşan alev topakları) + topun etrafında sarmal dönen 3 kor + kuyruktan saçılan kıvılcım
##  - ATIŞ: alev orbundan çıkış patlaması (halka + parlama)
##  - İSABET: beyaz-sarı parlama, radyal alev dilleri, genişleyen çift ateş halkası, kavrulmuş zemin izi, savrulan kor + yükselen duman
## Atış/isabet SESİ de burada (bu düğüm her atışta HER istemcide doğduğu için ses herkeste aynı çalar).
const PixelDraw := preload("res://scripts/pixel_draw.gd")
const ShamanSfx := preload("res://scripts/shaman_sfx.gd")

var start_pos: Vector2 = Vector2.ZERO
var _hit_sound_played: bool = false
## Mermi hedefi (Enemy). Takip ederken konumunu canlı okuruz; hedef sahnedan silinirse en son bilinen konumda patlamayla biter.
var target_ref: Node2D = null
var end_pos: Vector2 = Vector2.ZERO
var bolt_color: Color = Color(1.0, 0.55, 0.25)

var travel_time: float = 0.26
var impact_time: float = 0.42

var _elapsed: float = 0.0
## Varış kıvılcımları (savrulan kor).
var _sparks: Array[Dictionary] = []
var _seed: int = 0


static func spawn(parent: Node, p_start: Vector2, p_target: Node2D, p_color: Color) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var bolt: TotemFireBolt = TotemFireBolt.new()
	bolt.start_pos = p_start
	bolt.end_pos = p_target.global_position if (p_target != null and is_instance_valid(p_target)) else p_start
	bolt.target_ref = p_target
	bolt.bolt_color = p_color
	bolt._seed = randi()
	parent.add_child(bolt)


func _ready() -> void:
	top_level = true
	position = Vector2.ZERO
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	call_deferred("_play_shot_sound")


func _play_shot_sound() -> void:
	ShamanSfx.play_at(get_parent(), ShamanSfx.BOLT_SHOT, start_pos, -10.0, 0.08)


func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(target_ref):
		end_pos = target_ref.global_position
	if _elapsed >= travel_time + impact_time:
		queue_free()
		return
	if _elapsed > travel_time and not _hit_sound_played:
		_hit_sound_played = true
		ShamanSfx.play_at(get_parent(), ShamanSfx.BOLT_HIT, end_pos, -9.0, 0.08)
	for s in _sparks:
		s["age"] = float(s["age"]) + delta
		s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * delta
		s["vel"] = (s["vel"] as Vector2) * (1.0 - 2.2 * delta) + Vector2(0, -30.0) * delta
	queue_redraw()


func _draw() -> void:
	if _elapsed <= travel_time:
		_draw_flight()
	else:
		_draw_impact()


## Gece ışığı (bkz. night_glow.gd): kök (0,0)'da duruyor (top_level, dünya koordinatıyla çiziyor) - ışık uçan ateş
## topunun başında, isabetten sonra çarpma noktasında.
func get_glow_segment() -> Array:
	var p: Vector2 = _path(_elapsed / travel_time) if _elapsed <= travel_time else end_pos
	return [p, p]


## Yol üzerindeki konum: u = 0..1 (yumuşak başlangıç/bitiş). Kuyruk, geçmiş u değerleri analitik okunarak çizilir.
func _path(u: float) -> Vector2:
	var c: float = clampf(u, 0.0, 1.0)
	var smooth_u: float = c * c * (3.0 - 2.0 * c)
	return start_pos.lerp(end_pos, smooth_u)


func _draw_flight() -> void:
	var t: float = PixelDraw.TEXEL
	var u: float = clampf(_elapsed / travel_time, 0.0, 1.0)
	var head: Vector2 = _path(u)
	var flick: int = int(_elapsed * 30.0)
	## --- Kuyruk: geçmiş konumlarda alev topakları (uzaklaştıkça küçük + soğuk renk), yanlara titreyen ---
	var tail_count: int = 14
	for k in range(tail_count, 0, -1):
		var f: float = float(k) / float(tail_count)
		var p: Vector2 = _path(u - float(k) * 0.028)
		var jit := Vector2(PixelDraw.hash01(_seed + k * 31 + flick) - 0.5, PixelDraw.hash01(_seed + k * 57 + flick * 3) - 0.5) * t * (2.0 + 5.0 * f)
		var col: Color = PixelDraw.fire_color(0.28 + 0.62 * f)
		col.a = 1.0 - f * 0.75
		var r: float = maxf(t * 1.2, (1.0 - f) * 4.6 * t)
		PixelDraw.disc(self, p + jit, r, col)
	## --- Top: katmanlı ateş (dıştan içe kırmızı -> turuncu -> sarı -> beyaz), hafif nabız ---
	var pulse: float = 0.5 + 0.5 * sin(_elapsed * 40.0)
	PixelDraw.disc(self, head, 5.4 * t + pulse * t, PixelDraw.fire_color(0.66))
	PixelDraw.disc(self, head, 4.3 * t, PixelDraw.fire_color(0.44))
	PixelDraw.disc(self, head, 3.0 * t, PixelDraw.fire_color(0.24))
	PixelDraw.disc(self, head, 1.6 * t, PixelDraw.fire_color(0.02))
	## Topun önünde küçük alev dilleri (uçuş yönünde)
	var dir: Vector2 = (end_pos - start_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var side := Vector2(-dir.y, dir.x)
	for s2 in [-1.0, 1.0]:
		PixelDraw.px(self, head + dir * t * 5.0 + side * s2 * t * 2.0, 1, PixelDraw.fire_color(0.3))
	PixelDraw.px(self, head + dir * t * 6.5, 1, PixelDraw.fire_color(0.1))
	## --- Sarmal dönen 3 kor (yörünge) ---
	for i in 3:
		var a: float = _elapsed * 22.0 + float(i) * TAU / 3.0
		var orbit := Vector2(cos(a), sin(a)) * 7.0 * t
		PixelDraw.px(self, head + orbit, 1, PixelDraw.fire_color(0.05 + 0.2 * float(i)))
	## --- Kuyruktan saçılan kıvılcımlar ---
	for j in 5:
		var seed_j: int = _seed + j * 101 + flick / 2
		var back: Vector2 = _path(u - (0.03 + 0.12 * PixelDraw.hash01(seed_j)))
		var off := Vector2(PixelDraw.hash01(seed_j + 7) - 0.5, PixelDraw.hash01(seed_j + 13) - 0.5) * 11.0 * t
		PixelDraw.px(self, back + off, 1, PixelDraw.fire_color(0.15 + 0.55 * PixelDraw.hash01(seed_j + 19)))
	## --- Atış anı: alev orbundan çıkış patlaması ---
	if _elapsed < 0.12:
		var m: float = _elapsed / 0.12
		PixelDraw.ring(self, start_pos, 3.0 * t + m * 12.0 * t, Color(PixelDraw.fire_color(0.1 + 0.6 * m), 1.0 - m), 1)
		PixelDraw.disc(self, start_pos, (1.0 - m) * 5.0 * t, Color(1.0, 0.85, 0.4, 1.0 - m))


func _draw_impact() -> void:
	var t: float = PixelDraw.TEXEL
	var k: float = clampf((_elapsed - travel_time) / impact_time, 0.0, 1.0)
	var alpha: float = 1.0 - k
	## Varış anı: kıvılcım/kor bir kez üretilir.
	if _sparks.is_empty():
		for i in 14:
			var ang: float = randf() * TAU
			_sparks.append({
				"pos": end_pos + Vector2(0, -4.0),
				"vel": Vector2.from_angle(ang) * randf_range(60.0, 190.0) + Vector2(0, -50.0),
				"age": 0.0,
				"life": randf_range(0.22, 0.42),
			})
	## Kavrulmuş zemin izi (koyu dither, yavaş solar)
	PixelDraw.disc_dither(self, end_pos + Vector2(0, 5.0), 17.0, Color(0.05, 0.02, 0.02, 0.35 * alpha), 1, 1)
	## Beyaz-sarı parlama (çok kısa) + sıcak çekirdek
	if k < 0.22:
		var fk: float = k / 0.22
		PixelDraw.disc(self, end_pos, (1.0 - fk * 0.5) * 11.0 * t, Color(1.0, 0.96, 0.7, 1.0 - fk))
		PixelDraw.disc(self, end_pos, (1.0 - fk) * 6.0 * t, Color(1.0, 1.0, 1.0, 1.0))
	## Radyal alev dilleri (yukarı eğilimli, uzayıp kısalır)
	var tongues: int = 8
	for i in tongues:
		var ang2: float = TAU * float(i) / float(tongues) + 0.3
		var len_px: float = (10.0 + 12.0 * PixelDraw.hash01(_seed + i * 17)) * sin(minf(1.0, k * 1.15) * PI) * t
		var dirv := Vector2(cos(ang2), sin(ang2) * 0.75 - 0.25)
		var steps: int = maxi(1, int(len_px / t))
		for s in range(steps):
			var f: float = float(s) / float(steps)
			PixelDraw.px(self, end_pos + dirv * (4.0 * t + f * len_px), 1 if f > 0.45 else 2, Color(PixelDraw.fire_color(0.05 + 0.85 * f), alpha))
	## Genişleyen çift ateş halkası
	PixelDraw.ring(self, end_pos, 4.0 * t + 22.0 * t * k, Color(PixelDraw.fire_color(0.12 + 0.6 * k), alpha * 0.95), 1)
	PixelDraw.ring(self, end_pos, 2.0 * t + 14.0 * t * k, Color(1.0, 0.88, 0.5, alpha * 0.7), 1, 3, 2, _elapsed * 30.0)
	## Savrulan kor
	for sp in _sparks:
		var life: float = float(sp["life"])
		var age: float = float(sp["age"])
		if age >= life:
			continue
		var sa: float = (1.0 - age / life) * alpha
		PixelDraw.px(self, sp["pos"], 2 if age < life * 0.35 else 1, Color(PixelDraw.fire_color(age / life * 0.9), sa))
	## Yükselen duman (dither gri topaklar)
	for i in 3:
		var ph: float = clampf(k * 1.2 - float(i) * 0.15, 0.0, 1.0)
		if ph <= 0.0:
			continue
		var sm: Vector2 = end_pos + Vector2((float(i) - 1.0) * 5.0 * t, -6.0 * t - ph * 20.0 * t)
		PixelDraw.disc_dither(self, sm, (3.0 + 3.0 * ph) * t, Color(0.16, 0.12, 0.12, 0.5 * (1.0 - ph)), i, 1)
