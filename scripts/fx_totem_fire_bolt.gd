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
##
## FPS (madde 215): eskiden her karede ~150 draw_rect + GDScript (bolt başına ~0,3 ms). Şimdi UÇUŞ tek MultiMesh çizimi
## (`shaders/totem_bolt.gdshader`: 29 örnek, konumlar uçuş ilerlemesinden shader'da hesaplanır), ATIŞ anı ve İSABET anı SPRITE SAYFASI
## (`tools/fx_bake.ps1` ile pişirildi: assets/fx/baked/totem_bolt_launch/impact_*; özgün çizim `tools/fx_bake_src/fx_totem_fire_bolt.gd`).
## Sadece "Patlayan Alev" evriminin hasar halkaları (blast_radius > 0) eskisi gibi kodla çizilir (nadir).
## Atış/isabet SESİ de burada (bu düğüm her atışta HER istemcide doğduğu için ses herkeste aynı çalar).
const PixelDraw := preload("res://scripts/pixel_draw.gd")
const ShamanSfx := preload("res://scripts/shaman_sfx.gd")
const BakedFx := preload("res://scripts/baked_fx.gd")
const BOLT_SHADER := preload("res://shaders/totem_bolt.gdshader")
const LAUNCH_FRAMES := preload("res://assets/fx/baked/totem_bolt_launch_frames.tres")
const IMPACT_FRAMES := preload("res://assets/fx/baked/totem_bolt_impact_frames.tres")
const TAIL_COUNT := 14
const _KINDS: Array = [[1, 4], [2, 3], [3, 3], [4, 5]] ## [shader türü, adet]: baş katmanı, dil, yörünge kor, kıvılcım (kuyruk 0 ayrı)

var start_pos: Vector2 = Vector2.ZERO
var _hit_sound_played: bool = false
## Mermi hedefi (Enemy). Takip ederken konumunu canlı okuruz; hedef sahnedan silinirse en son bilinen konumda patlamayla biter.
var target_ref: Node2D = null
var end_pos: Vector2 = Vector2.ZERO
var bolt_color: Color = Color(1.0, 0.55, 0.25)
## > 0 => isabette bu yarıçaplı patlama halkası da çizilir ("Patlayan Alev" evrimi, totem_attack.gd _explode). Salt görsel.
var blast_radius: float = 0.0

var travel_time: float = 0.26
var impact_time: float = 0.42

var _elapsed: float = 0.0
var _seed: int = 0
var _flight: MultiMeshInstance2D = null
var _mat: ShaderMaterial = null
var _launch: AnimatedSprite2D = null
var _impact: AnimatedSprite2D = null


static func spawn(parent: Node, p_start: Vector2, p_target: Node2D, p_color: Color, p_blast_radius: float = 0.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var bolt: TotemFireBolt = TotemFireBolt.new()
	bolt.start_pos = p_start
	bolt.end_pos = p_target.global_position if (p_target != null and is_instance_valid(p_target)) else p_start
	bolt.target_ref = p_target
	bolt.bolt_color = p_color
	bolt.blast_radius = p_blast_radius
	bolt._seed = randi()
	parent.add_child(bolt)


func _ready() -> void:
	top_level = true
	position = Vector2.ZERO
	z_index = 5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_flight()
	_launch = BakedFx.attach(self, LAUNCH_FRAMES, PixelDraw.TEXEL, false)
	_launch.position = start_pos
	_impact = AnimatedSprite2D.new()
	_impact.sprite_frames = IMPACT_FRAMES
	_impact.scale = Vector2(PixelDraw.TEXEL, PixelDraw.TEXEL)
	_impact.flip_h = randf() < 0.5 ## sabit pişirilmiş kıvılcım dağılımı her atışta aynı görünmesin
	_impact.visible = false
	add_child(_impact)
	call_deferred("_play_shot_sound")


## Uçuşun tüm parçaları tek MultiMesh: örnek başına özel veri (tür, k) - konum/renk shader'da.
func _build_flight() -> void:
	var t: float = PixelDraw.TEXEL
	var half: float = 8.0 * t
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_custom_data = true
	mm.mesh = mesh
	var total: int = TAIL_COUNT
	for g in _KINDS:
		total += int(g[1])
	mm.instance_count = total
	## Örnekler orijinde duruyor, konumlar shader'da hesaplanıyor -> kırpma kutusu atış/varış çevresini kapsamalı (yoksa kamera orijinden uzaktayken çizim atılır).
	var mid: Vector2 = (start_pos + end_pos) * 0.5
	mm.custom_aabb = AABB(Vector3(mid.x - 700.0, mid.y - 700.0, -1.0), Vector3(1400.0, 1400.0, 2.0))
	var idx: int = 0
	for k in range(1, TAIL_COUNT + 1):
		mm.set_instance_transform_2d(idx, Transform2D.IDENTITY)
		mm.set_instance_custom_data(idx, Color(0.0, float(k), 0.0, 0.0))
		idx += 1
	for g in _KINDS:
		for k in range(int(g[1])):
			mm.set_instance_transform_2d(idx, Transform2D.IDENTITY)
			mm.set_instance_custom_data(idx, Color(float(int(g[0])), float(k), 0.0, 0.0))
			idx += 1
	_mat = ShaderMaterial.new()
	_mat.shader = BOLT_SHADER
	_mat.set_shader_parameter("texel", t)
	_mat.set_shader_parameter("seed", _seed & 0x3FFFFFFF)
	_flight = MultiMeshInstance2D.new()
	_flight.multimesh = mm
	_flight.material = _mat
	_flight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_flight)


func _play_shot_sound() -> void:
	ShamanSfx.play_at(get_parent(), ShamanSfx.BOLT_SHOT, start_pos, -10.0, 0.08)


func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(target_ref):
		end_pos = target_ref.global_position
	if _elapsed >= travel_time + impact_time:
		queue_free()
		return
	if _elapsed <= travel_time:
		_mat.set_shader_parameter("start_pos", start_pos)
		_mat.set_shader_parameter("end_pos", end_pos)
		_mat.set_shader_parameter("u", clampf(_elapsed / travel_time, 0.0, 1.0))
		_mat.set_shader_parameter("el", _elapsed)
		_mat.set_shader_parameter("flick", int(_elapsed * 30.0))
		return
	if not _hit_sound_played:
		_hit_sound_played = true
		ShamanSfx.play_at(get_parent(), ShamanSfx.BOLT_HIT, end_pos, -9.0, 0.08)
		_flight.visible = false
		_launch.visible = false
		_impact.visible = true
		_impact.play(&"play")
	_impact.position = end_pos
	if blast_radius > 0.0:
		queue_redraw()


## Gece ışığı (bkz. night_glow.gd): kök (0,0)'da duruyor (top_level, dünya koordinatıyla çiziyor) - ışık uçan ateş
## topunun başında, isabetten sonra çarpma noktasında.
func get_glow_segment() -> Array:
	var p: Vector2 = _path(_elapsed / travel_time) if _elapsed <= travel_time else end_pos
	return [p, p]


## Yol üzerindeki konum: u = 0..1 (yumuşak başlangıç/bitiş).
func _path(u: float) -> Vector2:
	var c: float = clampf(u, 0.0, 1.0)
	var smooth_u: float = c * c * (3.0 - 2.0 * c)
	return start_pos.lerp(end_pos, smooth_u)


## Patlayan Alev evrimi: hasar yarıçapına kadar genişleyen kor halkası + sönen sıcak zemin (hasarın gerçek alanını gösterir).
## Sadece isabet aşamasında ve blast_radius > 0 iken (nadir); geri kalan isabet görseli pişirilmiş sayfada.
func _draw() -> void:
	if _elapsed <= travel_time or blast_radius <= 0.0:
		return
	var k: float = clampf((_elapsed - travel_time) / impact_time, 0.0, 1.0)
	var alpha: float = 1.0 - k
	var bk: float = minf(1.0, k * 2.2)
	PixelDraw.disc_dither(self, end_pos, blast_radius * bk, Color(1.0, 0.45, 0.12, 0.28 * alpha), 1, 1)
	PixelDraw.ring(self, end_pos, blast_radius * bk, Color(PixelDraw.fire_color(0.1 + 0.5 * bk), alpha * 0.9), 1)
	PixelDraw.ring(self, end_pos, blast_radius * bk * 0.7, Color(1.0, 0.85, 0.45, alpha * 0.6), 1, 3, 2, _elapsed * 20.0)
