extends RefCounted

## Efekt ısıtma: ilk kullanımda takılmayı oyun açılırken öderiz.
##
## 1) Shader'lar (madde 215): mermi izi / totem ateş topu / Melek R halkası shader'ları ilk kez çizildiği karede boru hattı derlemesi yüzünden takılma
## (ölçüm: ilk Melek R'de ~190 ms) yapıyordu. Oyun sahnesi açılırken her shader'ı neredeyse görünmez, ekran köşesinde tek örnekle birkaç kare çizeriz.
##
## 2) FPS turu (2026-10-18, ölçüm: yeteneklerin ilk kullanımında 10-40 ms'lik tek karelik takılmalar; Şovalye R, Büyücü Q/E/R, Cadı Q gibi bazıları verbose
## günlükte 80-160 ms):
##  a) Yeteneklerin/silahların ilk kullanımında çalışma zamanında load() ile okunan kaynaklar (ses örnekleri .wav/.mp3, doku sayfaları, SpriteFrames .tres,
##     FX sahneleri ve betikleri) - liste scripts/fx_warmup_list.gd (tools/gen_fx_warmup_list.ps1 üretir). Bunlar oyun açılırken kare başına kısa bir bütçeyle
##     yüklenir ve TUTULUR: ResourceLoader önbelleği zayıf referansla çalışır, kimse tutmazsa kaynak hemen boşalır ve bir sonraki load() diskten okur
##     (örn. her Tabanca atışında tabanca_govde.png yeniden okunuyordu).
##  b) Yeni bir canvas shader'ının ilk çizimi 6 shader varyantını diskten yükletip boru hattı kurdurur (~15-30 ms). Yeteneklerin kullandığı shader'lar
##     (dosya listesi + çalışma zamanında kod olarak üretilenler: Elara, Hadime Kabus formu, Talon atılışı) kare başına BİR tanesi çizilerek ısıtılır.
## class_name yok (preload ile kullanılır).

const TrailShader := preload("res://shaders/particle_trail.gdshader")
const BoltShader := preload("res://shaders/totem_bolt.gdshader")
const RingShader := preload("res://shaders/melek_holy_ring.gdshader")
const TrailSheet := preload("res://assets/fx/projectile_trails/arcane_c_sheet.png")
const WarmListScript := preload("res://scripts/fx_warmup_list.gd")
const ElaraFxScript := preload("res://scripts/elara_fx.gd")
const HadimeMathScript := preload("res://scripts/hadime_math.gd")
const TalonDashScript := preload("res://scripts/fx_talon_dash.gd")
const TreeCrystalGlowScript := preload("res://scripts/mission_tree_crystal_glow.gd") ## görev ağacı kristal maskesi (~7 ms piksel döngüsü, kare başına 1/6'sı)

## Yeteneklerin ilk kullanımında yeni canvas shader'ı olarak derlenen shader dosyaları (yoksa atlanır).
const EXTRA_SHADERS: Array[String] = [
	"res://shaders/yumusak_parilti.gdshader", ## toplamalı parıltıların yerine yumuşak parıltı (2026-11-08, soft_glow_blend.gd)
	"res://shaders/gorev_altin_ton.gdshader", ## Kaçan Hazine (madde 496)
	"res://shaders/gorev_karanlik_halka.gdshader", ## Gezici Işık (madde 496)
	"res://shaders/oakley_yaprak_halkasi.gdshader", ## Oakley çiçeği Yaprak Halkası (madde 316) - ilk çiçekte derleme takılmasın
	"res://shaders/talon_form.gdshader",
	"res://shaders/talon_form_weapon.gdshader",
	"res://shaders/assasin_ghost.gdshader",
	"res://shaders/ruh_hali.gdshader", ## ruh hâli (madde 438) - ilk level ekranında derleme takılmasın
	"res://shaders/zindan_zemin.gdshader", ## zindan haritası zemin taşları (madde 449)
	"res://shaders/assasin_passive_outline.gdshader",
	"res://shaders/slime_buff_outline.gdshader", ## Minik Cadı büyüsü dış hattı (madde 523) - ilk büyüde derleme takılmasın
	"res://shaders/melek_bond.gdshader",
	"res://shaders/melek_halo_tint.gdshader",
	"res://shaders/matthew_glow.gdshader",
	"res://shaders/matthew_fox_shield.gdshader",
	"res://shaders/lightning_yellow.gdshader",
	"res://shaders/mana_shield.gdshader",
	"res://shaders/shield_dome.gdshader",
	"res://shaders/hit_flash.gdshader",
	"res://shaders/blood_tint.gdshader",
	"res://shaders/gokkusagi_isin.gdshader", ## Gökkuşağı Asası ışını: shader ilk ÇİZİMDE derlenir (~20 ms), kaynak listesi bunu ısıtamaz (madde 312)
]
## AÇILIŞ (2026-11-07, kullanıcı: "oyun başladığında evde doğunca anlık drop, ilk saniyelerde FPS düşük"; ölçüm fps_micro -Mode acilis: ilk 3 sn'de
## 40-70 ms'lik ~25 kare = bu ısınma + zindan ön kurulumu): liste kaynakları artık YÜKLEME EKRANININ iş parçacığında okunur (loading_screen.gd
## _load_worker -> adopt), yükleme katmanı (loading_overlay.gd, grup "loading_overlay") ekrandayken shader'lar COVERED_BUDGET_US bütçesiyle
## kare başına birden çok ısıtılır; katman is_finished() + zindan warm_done()'u bekleyip öyle kalkar. Katmansız açılışta eski kare bütçesi.
const COVERED_BUDGET_US := 30000
## Shader derlemesi ÇİZİMDE olur (_warm_shader yalnız dörtgeni ekler, süresi bütçeye yansımaz): katman ekrandayken kare başına en çok bu kadar (~45 ms/shader).
const COVERED_SHADERS_PER_FRAME := 3
## Kare başına kaynak yüklemeye ayrılan en çok süre (µs). Bir kaynak ~0,5-6 ms (ses örneği / doku sayfası / FX sahnesi): kare başına 1-2 kaynak, ~2 sn'de biter.
const LOAD_BUDGET_US := 3000
const WARM_LAYER := 100
## Arka planda ısıtılan shader dörtgenleri dünyanın ALTINDA çizilir: bazı shader'lar girdi alfasını (modulate) yok sayıp opak çıkar (hit_flash, lightning_yellow...) ve köşede 6x6 px'lik leke görünürdü.
const WARM_LAYER_BEHIND := -100

static var _held: Array = [] ## oturum boyunca tutulan kaynaklar
static var _next_path: int = 0
static var _next_shader: int = 0
static var _shader_sources: Array = [] ## ısıtılacak Shader'lar (ilk kare doldurulur)
static var _stepper: Callable = Callable()
static var _layer: CanvasLayer = null
static var _crystal_done: bool = false ## görev ağacı kristal maskeleri hazır (TreeCrystalGlowScript.warm_step)


static func run(host: Node) -> void:
	if host == null or not host.is_inside_tree():
		return
	var layer := CanvasLayer.new()
	layer.layer = WARM_LAYER
	var root := Node2D.new()
	root.modulate = Color(1, 1, 1, 0.01)
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(root)
	var quad := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	for sh in [TrailShader, BoltShader]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = 1
		mm.set_instance_transform_2d(0, Transform2D(0.0, Vector2(2, 2)))
		mm.set_instance_custom_data(0, Color(0, 0, 0, 0))
		var mmi := MultiMeshInstance2D.new()
		mmi.multimesh = mm
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mmi.material = mat
		if sh == TrailShader:
			mmi.texture = TrailSheet
		root.add_child(mmi)
	var ring := Node2D.new()
	var ring_mat := ShaderMaterial.new()
	ring_mat.shader = RingShader
	ring_mat.set_shader_parameter("radius1", 2.0)
	ring.material = ring_mat
	ring.draw.connect(func() -> void: ring.draw_rect(Rect2(0, 0, 4, 4), Color.WHITE))
	root.add_child(ring)
	host.add_child(layer)
	host.get_tree().create_timer(0.5).timeout.connect(layer.queue_free)
	_start_background_warmup(host.get_tree())


## Shader çizimi + kaynak yüklemeyi kareye yayan adımlayıcıyı başlatır (zaten çalışıyorsa ya da bittiyse bir şey yapmaz).
static func _start_background_warmup(tree: SceneTree) -> void:
	if tree == null or _stepper.is_valid():
		return
	## Liste üreticisi (tools/fx_warmup_collect.gd) ısınmayı KAPATIR: yoksa önceden yüklenen kaynaklar günlükte görünmez ve liste küçülür.
	if OS.get_environment("FXW_COLLECT") != "":
		return
	if _shader_sources.is_empty() and _next_shader == 0:
		_shader_sources.append(ElaraFxScript.make_material(0).shader)
		_shader_sources.append(HadimeMathScript.warm_shader())
		_shader_sources.append(TalonDashScript.warm_shader())
		for path in EXTRA_SHADERS:
			if ResourceLoader.exists(path):
				var sh: Shader = load(path) as Shader
				if sh != null:
					_shader_sources.append(sh)
	if _next_shader >= _shader_sources.size() and _next_path >= WarmListScript.PATHS.size() and _crystal_done:
		return
	_stepper = _step.bind(tree)
	tree.process_frame.connect(_stepper)


## Yükleme ekranının iş parçacığında okunmuş liste kaynakları (oturum boyunca tutulur; _step'te load() önbellekten gelir).
static func adopt(resources: Array) -> void:
	_held.append_array(resources)


## Arka plan ısınması (shader + kaynak + kristal maskeleri) bitti mi / hiç başlamadı mı.
static func is_finished() -> bool:
	return not _stepper.is_valid()


static func _step(tree: SceneTree) -> void:
	var t0: int = Time.get_ticks_usec()
	var covered: bool = tree.get_node_count_in_group(&"loading_overlay") > 0
	var budget: int = COVERED_BUDGET_US if covered else LOAD_BUDGET_US
	## Kare başına BİR shader (katman ekrandayken bütçe kadar): yeni materyal + 4x4'lük neredeyse görünmez dörtgen birkaç kare çizilir (boru hattı kurulur), sonra silinir.
	var warmed: int = 0
	while _next_shader < _shader_sources.size():
		_warm_shader(tree, _shader_sources[_next_shader] as Shader)
		_next_shader += 1
		warmed += 1
		if not covered or warmed >= COVERED_SHADERS_PER_FRAME:
			break
	var paths: Array[String] = WarmListScript.PATHS
	while _next_path < paths.size() and Time.get_ticks_usec() - t0 < budget:
		var p: String = paths[_next_path]
		_next_path += 1
		if ResourceLoader.exists(p):
			var r: Resource = load(p)
			if r != null:
				_held.append(r)
	if _next_path >= paths.size() and not _crystal_done:
		_crystal_done = TreeCrystalGlowScript.warm_step()
	if _next_shader >= _shader_sources.size() and _next_path >= paths.size() and _crystal_done:
		tree.process_frame.disconnect(_stepper)
		_stepper = Callable()
		_shader_sources.clear() ## Shader'lar zaten ilgili sınıflarda/önbellekte tutuluyor


static func _warm_shader(tree: SceneTree, sh: Shader) -> void:
	if sh == null or tree.root == null:
		return
	if _layer == null or not is_instance_valid(_layer):
		_layer = CanvasLayer.new()
		_layer.layer = WARM_LAYER_BEHIND
		tree.root.add_child(_layer)
	var n := Node2D.new()
	n.modulate = Color(1, 1, 1, 0.01)
	n.position = Vector2(2, 2)
	var mat := ShaderMaterial.new()
	mat.shader = sh
	n.material = mat
	n.draw.connect(func() -> void: n.draw_rect(Rect2(0, 0, 3, 3), Color.WHITE))
	_layer.add_child(n)
	tree.create_timer(0.15).timeout.connect(n.queue_free)
