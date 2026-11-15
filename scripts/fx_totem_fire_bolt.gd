extends Node2D
class_name TotemFireBolt

## KOZMETİK efekt (hiçbir oyun mantığı YOK): Saldırı Totemi'nin (Shaman Q) ateş topu - "A - KOR TOPU" (madde 567; prototip madde 562 A,
## kullanıcı seçti). Q rün taşının rün merkezinden (TotemAttack.BOLT_ORIGIN_OFFSET) hedefin GÖVDESİNE düz uçan küçük kor topu + kısa
## kuyruk (3 topak), çıkışta küçük dört köşeli parlama, isabette parlama -> radyal alev parçaları -> düşüp sönen kor.
## "Patlayan Alev" (shaman_qf, blast_radius > 0): aynı alev parçaları patlama yarıçapına kadar saçılır (eski dither'li halka kalktı).
##
## Hasar hesabı buraya TAMAMEN dışarıdadır (totem_attack.gd _tick - enemy.take_damage); bu node silinse bile skilin davranışı değişmez.
## Çok oyunculu: gerçek totem _tick'te, ağ görsel kopyası kendi _process'inde AYNI spawn'ı çağırır (ek RPC yok).
## Piksel: 1 efekt pikseli = karakter pikseli 0,903 dünya (madde 295); dokular tools/gen_shaman_kor_topu.py (yanma alevi paleti,
## dither yok). Çizim: kare başı ~5 doku + isabette 8-12 dikdörtgen (eski MultiMesh shader + pişmiş sayfalar silindi).

const ShamanSfx := preload("res://scripts/shaman_sfx.gd")
const IceFreezeStatus := preload("res://scripts/fx_ice_freeze_status.gd") ## body_rect: yaratığın görünen bedeni

const PX := 0.903
## UÇAN TOP (2026-11-13, kullanıcı GIF'i gönderdi: "ateş topunun yan durması gerekiyor"): eski kor başı + 3 kuyruk topağı yerine
## tools/fx_kaynak/ates_topu_dikey.gif'in saat tersine 90 derece döndürülmüş hali (tools/gen_gif_fire_fx.py -> ates_topu_*; 28x10 kare,
## baş SAĞDA = +x uçuş yönü, 10 kare / 60 ms). Uçuş yönüne döndürülüp başı _head_pos'a oturur. kor_bas/kor_kuyruk dosyaları duruyor.
const BALL_FRAMES: SpriteFrames = preload("res://assets/fx/shaman_kor/ates_topu_frames.tres")
const BALL_HEAD_OFFSET := Vector2(-7.0, 0.0) ## sanat px: kare merkezinden başın (sıcak çekirdek) merkezine ters ofset
const BALL_FPS := 1000.0 / 60.0
const TEX_CORE: Texture2D = preload("res://assets/fx/shaman_kor/kor_merkez.png")
const TEX_STAR: Texture2D = preload("res://assets/fx/shaman_kor/kor_yildiz.png")
const TEX_STAR_SMALL: Texture2D = preload("res://assets/fx/shaman_kor/kor_yildiz_k.png")
const FIRE_ORANGE := Color8(250, 148, 51)
const FIRE_RED := Color8(214, 76, 31)
const FIRE_DARK := Color8(102, 26, 15)
## ATIŞ ANI (madde 570, kullanıcı: "ateş topu atılacağı anda bir efekt çıksın, böyle ruhsuz olmuş"): taşın rününden hedef yönüne fışkıran
## 3 alev dili (namlu alevi) + büyük parlama yıldızı, yön konisinde saçılıp düşen kıvılcımlar, iki küçük duman topağı. Hepsi yanma alevi
## paleti, 1 piksel = PX, dither yok. Taşın geri tepmesi + rün parlaması totem tarafında (TotemAttack._on_fired).
const MUZZLE_TIME := 0.26 ## alev dilleri büyür (ilk %35) sonra kısalıp söner
const MUZZLE_LEN := 10.0 ## alev dili en uzun hâli (piksel)
const MUZZLE_SPREAD := 0.42 ## yan dillerin açısı (rad)
const MUZZLE_OFFSET := 7.0 ## dünya: alev taşın İÇİNDE değil, hedefe bakan kenarından fışkırır (taşın parıltısında kaybolmasın)
const LAUNCH_SPARKS := 9
const SPARK_LIFE := 0.38
const SPARK_GRAVITY := 140.0 ## dünya/sn²
const SMOKE_LIFE := 0.5
const FIRE_YELLOW := Color8(255, 219, 117)
const FIRE_WHITE := Color8(255, 244, 207)
const SMOKE := Color8(107, 90, 78)
const IMPACT_FLASH := 0.06
const BURST_BITS := 8
const BURST_BITS_BLAST := 12
const BURST_REACH := 7.0 ## dünya birimi (patlama yoksa)

var start_pos: Vector2 = Vector2.ZERO
var target_ref: Node2D = null
var end_pos: Vector2 = Vector2.ZERO
## Gece ışığı rengi (night_glow_catalog.gd "cp": "bolt_color").
var bolt_color: Color = Color(1.0, 0.55, 0.25)
var blast_radius: float = 0.0

var travel_time: float = 0.3
var impact_time: float = 0.32

var _elapsed: float = 0.0
var _hit_sound_played: bool = false
var _bit_phase: float = 0.0
var _launch_dir: Vector2 = Vector2.RIGHT


static func spawn(parent: Node, p_start: Vector2, p_target: Node2D, p_color: Color, p_blast_radius: float = 0.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var bolt: TotemFireBolt = TotemFireBolt.new()
	bolt.start_pos = p_start
	bolt.end_pos = hit_point(p_target) if (p_target != null and is_instance_valid(p_target)) else p_start
	bolt.target_ref = p_target
	bolt.bolt_color = p_color
	bolt.blast_radius = p_blast_radius
	parent.add_child(bolt)


## Nişan noktası: yaratığın görünen bedeninin ortası (ayak değil); beden okunamazsa ayağın biraz üstü.
static func hit_point(target: Node2D) -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	var body: Rect2 = IceFreezeStatus.body_rect(target)
	if body.size == Vector2.ZERO:
		return target.global_position + Vector2(0.0, -10.0)
	return target.global_transform * body.get_center()


func _ready() -> void:
	top_level = true
	position = Vector2.ZERO
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bit_phase = randf() * TAU ## isabet parçaları her atışta aynı açıda durmasın
	var d: Vector2 = end_pos - start_pos
	_launch_dir = d.normalized() if d.length() > 0.01 else Vector2.RIGHT
	call_deferred("_play_shot_sound")


func _play_shot_sound() -> void:
	ShamanSfx.play_at(get_parent(), ShamanSfx.BOLT_SHOT, start_pos, -10.0, 0.08)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed <= travel_time and is_instance_valid(target_ref):
		end_pos = hit_point(target_ref)
	if _elapsed >= travel_time + impact_time:
		queue_free()
		return
	if _elapsed > travel_time and not _hit_sound_played:
		_hit_sound_played = true
		ShamanSfx.play_at(get_parent(), ShamanSfx.BOLT_HIT, end_pos, -9.0, 0.08)
	queue_redraw()


func get_glow_segment() -> Array:
	var p: Vector2 = _head_pos() if _elapsed <= travel_time else end_pos
	return [p, p]


func _head_pos() -> Vector2:
	return start_pos.lerp(end_pos, clampf(_elapsed / travel_time, 0.0, 1.0))


static func _smooth(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


func _tex(tex: Texture2D, pos: Vector2, alpha: float) -> void:
	draw_set_transform(pos, 0.0, Vector2(PX, PX))
	draw_texture(tex, -tex.get_size() * 0.5, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO)


## Atışa özgü sözde rastgele 0..1 (her bolt kendi _bit_phase'iyle; kare kare titremez).
func _rnd(i: int, salt: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + _bit_phase * 78.233 + salt) * 43758.5453, 1.0)


func _px_at(p: Vector2, col: Color, size_px: float = 1.0) -> void:
	var sz: float = PX * size_px
	draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)


## Atış anı: namlu alevi + parlama + kıvılcım + duman (taşın rün merkezinden, hedef yönüne).
func _draw_launch(t: float) -> void:
	var dir: Vector2 = _launch_dir
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var mouth: Vector2 = start_pos + dir * MUZZLE_OFFSET
	## parlama yıldızı (taşın kenarında): önce büyük, sonra küçük
	if t < 0.1:
		_tex(TEX_STAR, mouth, 1.0)
	elif t < 0.17:
		_tex(TEX_STAR_SMALL, mouth, 1.0)
	## namlu alevi: ortada uzun, iki yanda kısa dil; büyür, kısalır, renk soğur
	if t < MUZZLE_TIME:
		var k: float = t / MUZZLE_TIME
		var grow: float = smoothstep(0.0, 0.35, k) * (1.0 - smoothstep(0.35, 1.0, k))
		for tongue in [[0.0, 1.0], [-MUZZLE_SPREAD, 0.6], [MUZZLE_SPREAD, 0.6]]:
			var tdir: Vector2 = dir.rotated(float(tongue[0]))
			var n: int = int(round(MUZZLE_LEN * float(tongue[1]) * grow))
			for j in range(n):
				var u: float = float(j) / maxf(1.0, float(n))
				var col: Color = FIRE_WHITE if (u < 0.2 and k < 0.5) else (FIRE_YELLOW if u < 0.45 else (FIRE_ORANGE if u < 0.75 else FIRE_RED))
				var p: Vector2 = mouth + tdir * float(j) * PX
				_px_at(p, col)
				## dipte kalın: orta dil 3, yan diller 2 piksel
				if u < 0.55:
					var edge: Color = FIRE_YELLOW if u < 0.25 else FIRE_ORANGE
					_px_at(p + side * PX, edge)
					if tongue[0] == 0.0:
						_px_at(p - side * PX, edge)
	## kıvılcımlar: yön konisinde saçılır, yerçekimiyle düşer, renk soğuyarak söner
	for i in range(LAUNCH_SPARKS):
		var age: float = t - 0.02 * float(i % 3)
		if age < 0.0 or age > SPARK_LIFE:
			continue
		var ang: float = (_rnd(i, 1.0) * 2.0 - 1.0) * 0.9
		var spd: float = 60.0 + 60.0 * _rnd(i, 2.0)
		var v: Vector2 = dir.rotated(ang) * spd
		var p: Vector2 = mouth + v * age + Vector2(0.0, 0.5 * SPARK_GRAVITY * age * age)
		var u: float = age / SPARK_LIFE
		var col: Color = FIRE_YELLOW if u < 0.3 else (FIRE_ORANGE if u < 0.6 else (FIRE_RED if u < 0.85 else FIRE_DARK))
		_px_at(p, col, 2.0 if u < 0.25 else 1.0)
	## duman: iki küçük topak, geriye-yukarı süzülür, büyüyüp söner
	for i in range(2):
		var age2: float = t - 0.05 - 0.05 * float(i)
		if age2 < 0.0 or age2 > SMOKE_LIFE:
			continue
		var u2: float = age2 / SMOKE_LIFE
		var p2: Vector2 = start_pos - dir * (2.0 + 3.0 * u2) * PX + side * (float(i) * 2.0 - 1.0) * 1.5 * PX + Vector2(0.0, -10.0 * age2)
		_px_at(p2, Color(SMOKE, 0.55 * (1.0 - u2)), 2.0 + float(int(u2 * 2.0)))


func _draw() -> void:
	if _elapsed < SMOKE_LIFE + 0.1:
		_draw_launch(_elapsed)
	if _elapsed <= travel_time:
		var p: Vector2 = _head_pos()
		var d: Vector2 = end_pos - start_pos
		var ang: float = d.angle() if d.length() > 0.01 else _launch_dir.angle()
		var n: int = BALL_FRAMES.get_frame_count(&"fly")
		var tex: Texture2D = BALL_FRAMES.get_frame_texture(&"fly", int(_elapsed * BALL_FPS) % n)
		draw_set_transform(p, ang, Vector2(PX, PX))
		draw_texture(tex, -tex.get_size() * 0.5 + BALL_HEAD_OFFSET)
		draw_set_transform(Vector2.ZERO)
		return
	_draw_burst(_elapsed - travel_time)


## İsabet: kısa parlama -> radyal alev parçaları (1x2 piksel) -> düşüp sönen koyu kor; patlama evriminde parçalar yarıçapa kadar.
func _draw_burst(age: float) -> void:
	var c: Vector2 = end_pos
	if age < IMPACT_FLASH:
		_tex(TEX_STAR, c, 1.0)
		return
	var k: float = clampf((age - IMPACT_FLASH) / maxf(0.01, impact_time - IMPACT_FLASH), 0.0, 1.0)
	var blast: bool = blast_radius > 0.0
	var n: int = BURST_BITS_BLAST if blast else BURST_BITS
	var reach: float = blast_radius * 0.9 if blast else BURST_REACH
	for i in range(n):
		var ang: float = float(i) * TAU / float(n) + 0.3 + _bit_phase
		var dist: float = 3.0 + reach * _smooth(k)
		var p: Vector2 = c + Vector2(cos(ang), sin(ang) * 0.8) * dist
		if k < 0.55:
			draw_rect(Rect2(p - Vector2(PX * 0.5, PX), Vector2(PX, PX * 2.0)), FIRE_ORANGE if k < 0.25 else FIRE_RED)
		else:
			var a: float = 1.0 - (k - 0.55) / 0.45
			draw_rect(Rect2(p + Vector2(-PX * 0.5, 4.0 * (k - 0.55) - PX * 0.5), Vector2(PX, PX)), Color(FIRE_DARK, a))
	if k < 0.4:
		_tex(TEX_CORE, c, 1.0 - k / 0.4)
