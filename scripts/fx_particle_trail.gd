extends Node2D

## Mermi arkasında bırakılan PARÇACIK izi (kullanıcı istekleri 2026-09-24: "füze ateşlendiğinde arkasında partiküller
## bıraksın füze olduğu hissedilsin" + "ateş asası, buz asası ateşlendiğinde attığı atışın arkasında kendine uygun
## partiküller olsun" - "pixel tarzda yapıp spritesheete dönüştür performans düşüşü olmaması için").
##
## Görseller tools/gen_projectile_trail_fx.py'nin pişirdiği sayfalar (her stil: 8 karelik parçacık ömrü x 2 varyant,
## kare 12x12 sanat pikseli). PERF: parçacık başına Node YOK - tek bu Node tüm canlı parçacıkları _draw'da sayfadan
## draw_texture_rect_region ile çizer. Mermiyle birlikte silinmesin diye sahnenin köküne (current_scene) eklenir: mermi
## yaşarken onun konumuna parçacık bırakır, mermi yok olunca (ya da çarpıp patlama animasyonuna geçince) yeni parçacık
## bırakmayı keser, kalanlar sönünce kendini siler.
##
## FPS (madde 215): parçacıklar artık GPU'da. Her parçacık bir MultiMesh örneği (konum = doğduğu yer, özel veri = doğuş saati,
## varyant, hız); yaşa göre konum/yerçekimi/sayfa karesi `shaders/particle_trail.gdshader`da hesaplanır, kare başı GDScript
## döngüsü + `_draw` yok (eskiden iz başına ~0,03 ms, fişekte 2 iz). Düğüm sadece doğurur ve saati shader'a yazar.
##
## Kullanım: `ParticleTrail.attach(mermi, "missile" | "fire" | "ice")` - projectile.gd (PARTICLE_TRAILS, sahne adına göre)
## ve firework_projectile.gd çağırır. Diğer oyunculardaki kozmetik mermiler AYNI sahne/script olduğu için (bkz.
## network_manager.gd broadcast_projectile) iz orada da aynen görünür.

const TEXEL := 1.212 ## PixelDraw.TEXEL - 1 sanat pikseli
const CELL := 12
const FRAMES := 8
const VARIANTS := 2
const TRAIL_SHADER := preload("res://shaders/particle_trail.gdshader")

## stil -> ayarlar. interval: bırakma aralığı (sn), life: parçacık ömrü (sn), drift: dünya birimi/sn kayma (yukarı eksi),
## jitter: bırakılış konumuna rastgele sapma (birim), back: merminin gerisine (uçuş yönünün tersine) kaydırma (birim).
const STYLES := {
	"missile": {"sheet": preload("res://assets/fx/projectile_trails/missile_sheet.png"), "interval": 0.035, "life": 0.5, "drift": Vector2(0.0, -16.0), "jitter": 2.0, "back": 6.0},
	"fire": {"sheet": preload("res://assets/fx/projectile_trails/fire_sheet.png"), "interval": 0.03, "life": 0.36, "drift": Vector2(0.0, -26.0), "jitter": 3.0, "back": 4.0},
	"ice": {"sheet": preload("res://assets/fx/projectile_trails/ice_sheet.png"), "interval": 0.04, "life": 0.45, "drift": Vector2(0.0, 10.0), "jitter": 4.0, "back": 4.0},
	## MERMİ SANATI (madde 201, tools/gen_mermi_sprites.py): sanat pikseli = silah/mermi pikseli (texel 0,575 dünya px), hücre "cell"
	## piksel; her parçacık kendi hızıyla (speed = [en az, en çok] dünya px/sn, rastgele yön) ve yerçekimiyle (gravity) uçar.
	"zehir_damla": {"sheet": preload("res://assets/fx/projectile_trails/zehir_damla_sheet.png"), "interval": 0.022, "life": 0.33, "drift": Vector2.ZERO,
		"jitter": 0.5, "back": 1.0, "texel": 0.575, "cell": 5, "speed": Vector2(0.0, 5.0), "gravity": 80.0}, ## Tüftüf A: düşen zehir damlası
	"arcane_c": {"sheet": preload("res://assets/fx/projectile_trails/arcane_c_sheet.png"), "interval": 0.014, "life": 0.19, "drift": Vector2.ZERO,
		"jitter": 2.25, "back": 6.0, "texel": 0.575, "cell": 5, "speed": Vector2(4.0, 12.0), "gravity": 0.0}, ## Arcane C: mor kıvılcım
	"buz_c": {"sheet": preload("res://assets/fx/projectile_trails/buz_c_sheet.png"), "interval": 0.014, "life": 0.22, "drift": Vector2.ZERO,
		"jitter": 2.25, "back": 7.0, "texel": 0.575, "cell": 5, "speed": Vector2(3.0, 9.0), "gravity": 15.0}, ## Buz C: camgöbeği kar artısı
	"fisek_kivilcim": {"sheet": preload("res://assets/fx/projectile_trails/fisek_kivilcim_sheet.png"), "interval": 0.012, "life": 0.25, "drift": Vector2.ZERO,
		"jitter": 0.75, "back": 8.0, "texel": 0.575, "cell": 5, "speed": Vector2(7.5, 22.0), "gravity": 30.0}, ## Fişek A: düşen kıvılcım
	"fisek_duman": {"sheet": preload("res://assets/fx/projectile_trails/fisek_duman_sheet.png"), "interval": 0.016, "life": 0.5, "drift": Vector2(0.0, -5.0),
		"jitter": 0.5, "back": 9.0, "texel": 0.575, "cell": 9, "speed": Vector2(0.0, 3.0), "gravity": 0.0}, ## Fişek A: yükselen duman
}

var source: Node2D = null
var style: String = "missile"
var _cfg: Dictionary = {}
var _mm: MultiMesh = null
var _mat: ShaderMaterial = null
var _clock: float = 0.0 ## iz düğümünün kendi saati (dünya saatinden bağımsız, küçük kalsın -> float hassasiyeti)
var _capacity: int = 0
var _next: int = 0
var _spawned: int = 0
var _last_emit_clock: float = -1.0e9
var _acc: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _has_last: bool = false
var _variant_toggle: int = 0


## Mermiye iz bağlar. İz, merminin HEMEN ARKASINDA (ağaç sırasında önünde -> altında) çizilir.
static func attach(projectile: Node2D, trail_style: String) -> Node2D:
	if projectile == null or not STYLES.has(trail_style):
		return null
	var tree: SceneTree = projectile.get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var trail := Node2D.new()
	trail.set_script(load("res://scripts/fx_particle_trail.gd"))
	trail.set("source", projectile)
	trail.set("style", trail_style)
	tree.current_scene.add_child.call_deferred(trail)
	return trail


## Tek bir parçacığı çizen kare (köşeler merkeze göre, UV sayfa hücresi içinde 0..1).
static func _quad(half: float) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _ready() -> void:
	_cfg = STYLES.get(style, STYLES["missile"])
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	global_position = Vector2.ZERO
	var texel: float = float(_cfg.get("texel", TEXEL))
	var cell: int = int(_cfg.get("cell", CELL))
	var life: float = float(_cfg["life"])
	_capacity = int(ceil(life / float(_cfg["interval"]))) * 2 + 4
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_custom_data = true
	_mm.mesh = _quad(float(cell) * texel * 0.5)
	_mm.instance_count = _capacity
	_mm.visible_instance_count = 0
	_mat = ShaderMaterial.new()
	_mat.shader = TRAIL_SHADER
	_mat.set_shader_parameter("life", life)
	_mat.set_shader_parameter("drift", _cfg["drift"])
	_mat.set_shader_parameter("gravity", float(_cfg.get("gravity", 0.0)))
	_mat.set_shader_parameter("texel", texel)
	_mat.set_shader_parameter("frames", float(FRAMES))
	_mat.set_shader_parameter("variants", float(VARIANTS))
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = _mm
	mmi.texture = _cfg["sheet"]
	mmi.material = _mat
	mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(mmi)
	## Mermiden önce çizilsin (ağaç sırası) - parçacıklar mermi sprite'ının altında kalır.
	if source and is_instance_valid(source) and source.get_parent() == get_parent():
		get_parent().move_child(self, source.get_index())


func _source_emitting() -> bool:
	if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
		return false
	if source.get("_impacted") == true or source.get("_done") == true:
		return false
	return true


func _emit(at: Vector2, age0: float, vel: Vector2) -> void:
	var i: int = _next
	_next = (_next + 1) % _capacity
	_variant_toggle = (_variant_toggle + 1) % VARIANTS
	_mm.set_instance_transform_2d(i, Transform2D(0.0, at))
	_mm.set_instance_custom_data(i, Color(_clock - age0, float(_variant_toggle), vel.x, vel.y))
	_spawned = mini(_spawned + 1, _capacity)
	_mm.visible_instance_count = _spawned


func _process(delta: float) -> void:
	_clock += delta
	_mat.set_shader_parameter("clock", _clock)
	if _source_emitting():
		var pos: Vector2 = source.global_position
		var back: Vector2 = Vector2.ZERO
		if _has_last and pos.distance_to(_last_pos) > 0.1:
			back = (_last_pos - pos).normalized() * float(_cfg["back"])
		_acc += delta
		var interval: float = float(_cfg["interval"])
		## Aralıktaki her bırakma, son konumla şimdiki arasında eşit dağılır (hızlı mermide boşluklu olmasın).
		var n: int = int(_acc / interval)
		if n > 0:
			_acc -= float(n) * interval
			var j: float = float(_cfg["jitter"])
			for i in range(n):
				var f: float = float(i + 1) / float(n)
				var at: Vector2 = (_last_pos.lerp(pos, f) if _has_last else pos) + back
				at += Vector2(randf_range(-j, j), randf_range(-j, j))
				var vel := Vector2.ZERO
				if _cfg.has("speed"):
					var sp: Vector2 = _cfg["speed"]
					vel = Vector2.from_angle(randf() * TAU) * randf_range(sp.x, sp.y)
				_emit(at, float(n - 1 - i) * interval, vel)
			_last_emit_clock = _clock
		_last_pos = pos
		_has_last = true
	elif _clock - _last_emit_clock > float(_cfg["life"]) + 0.1:
		queue_free()
