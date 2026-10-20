extends Node2D

## ASA UCU PARTİKÜLLERİ (CLAUDE.md madde 299; prototip madde 295 "A - Sade Toz"). Kullanıcı (2026-10-19): "buz asası ucundan
## buza benzer parlak partikülleri ateş asası da ateş partikülleri döksün arcane asası morumsu sihirli partiküller döksün (hepsi
## harekete bağlı olarak arkada kalacak çıkardığı partiküller) yıldırım asasının ucunda elektrik parçacıkları olsun ve isabet ettiği
## yaratıklardan elektrik partikülleri dökülsün hafif" + seçim: "A ları beğendim fakat çok uzuyor parıltının kuyruğu, biraz daha kısa
## olmalı" (ömürler prototipin ~%60'ı).
##
## Partiküller asanın ÇİZİLİ UCUNDAN (weapon_tip.gd) DÜNYAYA bırakılır: asa yürüdükçe arkada iz kalır, dururken uçta hafif damla.
## Doğma hızı = taban + uç hızı x katsayı. Görsel tools/gen_staff_tip_fx.py sayfaları (1 sanat px = karakter pikseli 0,903 dünya px);
## parçacık başına düğüm YOK - fx_particle_trail.gd ile aynı GPU yolu (MultiMesh + shaders/particle_trail.gdshader, yaş/kare/hız
## shader'da). Yıldırım ucunda ayrıca sürekli küçük cızırtı (crackle_sheet, 0,04-0,08 sn'de bir yeni kare).
##
## İKİ YER (CLAUDE.md "MP iki-yer"): yerel weapon.gd ikonu VE uzak kuklanın ikon kopyası (remote_player.gd update_weapon_visuals)
## AYRI AYRI attach() çağırır; ağ verisi yok (her istemci kendi gördüğü ikonun ucundan doğurur). İkon gizliyken (HÜCUM çekilmesi,
## saklanma çalılığı, ölüm, görünmezlik: ata zincirinde modulate.a) doğurmaz; ikon silinince kalanlar söner, düğüm kendini siler.
## Yıldırım isabeti: fx_lightning_beam.gd hedefte make_hit_emitter() + emit_hit() (ışın sahnesi kukla tarafında da aynı).

const WeaponTipScript := preload("res://scripts/weapon_tip.gd")
const WeaponTierArtScript := preload("res://scripts/weapon_tier_art.gd")
const TRAIL_SHADER := preload("res://shaders/particle_trail.gdshader")

const TEXEL := 0.903 ## sanat pikseli -> dünya px (Şovalye karakter pikseli; silah pikseli 0,575 1080p'de kayboluyordu)
const FRAMES := 8
const MAX_TIP_SPEED := 220.0 ## dünya px/sn: daha hızlı uç (atılma, ışınlanma) doğma hızını artırmaz
const MAX_PER_FRAME := 8 ## uzun karede (takılma) bir seferde en fazla
const JITTER := 1.2 * TEXEL
## Oyuncularla (ve silahlarıyla) AYNI katman: orman örtüsü (z 2) ve derinlik ön kopyaları (z 3, depth_occluders.gd) silahı örttüğü yerde
## partikülleri de örter (z 5'te iken yamacın / ağacın arkasındaki oyuncunun asası örtülüyor, partikülleri üstte kalıyordu - gerçek
## çizici yakalaması). Sahne kökünde oyunculardan sonra eklendiği için aynı z'de onların üstünde çizilir.
const Z := 1
const MIN_ALPHA := 0.6 ## ata zinciri saydamlığı bunun altındaysa (çekiliyor / saklı) doğurmaz

## life: stilin en uzun ömrü (sayfanın kısa satırları erken biter). vx / vy: rastgele hız aralığı (dünya px/sn). rows: satır sayısı.
## Kıvılcım sayfalarının hareketi pişmiş (hız 0); satır = yön.
const STYLES := {
	"fire": {"sheet": preload("res://assets/fx/staff_tip/ember_sheet.png"), "cell": 5, "rows": 4, "life": 0.45,
		"base": 10.0, "per_px": 0.33, "vx": Vector2(-6.0, 6.0), "vy": Vector2(-26.0, -14.0)},
	"ice": {"sheet": preload("res://assets/fx/staff_tip/frost_sheet.png"), "cell": 7, "rows": 4, "life": 0.54,
		"base": 10.0, "per_px": 0.33, "vx": Vector2(-5.0, 5.0), "vy": Vector2(4.0, 12.0)},
	"arc": {"sheet": preload("res://assets/fx/staff_tip/mote_sheet.png"), "cell": 11, "rows": 4, "life": 0.51,
		"base": 10.0, "per_px": 0.33, "vx": Vector2(-5.0, 5.0), "vy": Vector2(-10.0, -3.0)},
	"elec": {"sheet": preload("res://assets/fx/staff_tip/spark_tip_sheet.png"), "cell": 21, "rows": 8, "life": 0.25,
		"base": 7.0, "per_px": 0.25, "vx": Vector2.ZERO, "vy": Vector2.ZERO, "crackle": true},
	"elec_hit": {"sheet": preload("res://assets/fx/staff_tip/spark_hit_sheet.png"), "cell": 29, "rows": 8, "life": 0.36,
		"base": 0.0, "per_px": 0.0, "vx": Vector2.ZERO, "vy": Vector2.ZERO},
	## Gökkuşağı Asası (madde 309): ışın paletinin (gokkusagi_isin.gdshader RB) 6 rengi x 3 satır (uzun toz / kısa toz / krem
	## merkezli parıltı); rastgele satır = tanecik başına rastgele renk. Hafifçe dağılıp çöken ışık tozu (ateş yükselir, buz düşer).
	"rainbow": {"sheet": preload("res://assets/fx/staff_tip/prism_sheet.png"), "cell": 5, "rows": 18, "life": 0.5,
		"base": 10.0, "per_px": 0.33, "vx": Vector2(-6.0, 6.0), "vy": Vector2(-4.0, 8.0)},
}
## weapon_tier_art.gd anahtarı -> stil
const KEY_STYLE := {"fire_staff": "fire", "buz_asasi": "ice", "arcane": "arc", "lightning_staff": "elec", "gokkusagi": "rainbow"}
const RAINBOW_ROWS_PER_COLOR := 3 ## prism_sheet satır 3k..3k+2 = RB[k] (tools/gen_staff_tip_fx.py)
const CRACKLE_SHEET := preload("res://assets/fx/staff_tip/crackle_sheet.png")
const CRACKLE_CELL := 17
const CRACKLE_FRAMES := 8
const HIT_RATE := 10.0 ## isabet kıvılcımı / sn (hafif)
const HIT_RX := 8.0 ## yaratık gövdesi elipsi (dünya px; prototipteki slime)
const HIT_RY := 5.5

var source: Sprite2D = null
var forward_deg: float = -45.0
var style: String = "fire"

var _cfg: Dictionary = {}
var _mm: MultiMesh = null
var _mat: ShaderMaterial = null
var _clock: float = 0.0
var _capacity: int = 0
var _next: int = 0
var _spawned: int = 0
var _acc: float = 0.0
var _last_tip: Vector2 = Vector2.ZERO
var _has_last: bool = false
var _last_emit_clock: float = -1.0e9
var _owned_source: bool = false ## kaynak bağlandıysa: kaynak gidince kendini siler (isabet yayıcısı elle silinir)
var _crackle: Sprite2D = null
var _crackle_t: float = 0.0
var _hit_acc: float = 0.0
var _pos := PackedVector2Array() ## doğuş konumu / saati (MultiMesh başsız çizicide geri okunamıyor; testler + hata ayıklama)
var _born := PackedFloat32Array()
var _row := PackedInt32Array() ## sayfa satırı (Gökkuşağı: renk = satır / RAINBOW_ROWS_PER_COLOR)


## Asa ikonuna partikül yayıcı bağlar (asa değilse null). key = weapon_tier_art.gd anahtarı.
static func attach(icon: Sprite2D, key: String) -> Node2D:
	if icon == null or not KEY_STYLE.has(key):
		return null
	var scene: Node = _scene_root(icon)
	if scene == null:
		return null
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/staff_tip_fx.gd"))
	fx.set("source", icon)
	fx.set("forward_deg", float(WeaponTierArtScript.FORWARD.get(key, -45.0)))
	fx.set("style", String(KEY_STYLE[key]))
	fx.set("_owned_source", true)
	scene.add_child.call_deferred(fx)
	return fx


## Kaynaksız yayıcı (Yıldırım isabeti): emit_hit() ile elle doğurulur, işi bitince release() çağrılır.
static func make_hit_emitter(near: Node) -> Node2D:
	var scene: Node = _scene_root(near)
	if scene == null:
		return null
	var fx := Node2D.new()
	fx.set_script(load("res://scripts/staff_tip_fx.gd"))
	fx.set("style", "elec_hit")
	scene.add_child.call_deferred(fx)
	return fx


static func _scene_root(n: Node) -> Node:
	var tree: SceneTree = n.get_tree() if n != null and n.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


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
	_cfg = STYLES.get(style, STYLES["fire"])
	top_level = true
	global_position = Vector2.ZERO
	z_index = Z
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var life: float = float(_cfg["life"])
	var peak: float = float(_cfg["base"]) + float(_cfg["per_px"]) * MAX_TIP_SPEED
	if style == "elec_hit":
		peak = HIT_RATE * 2.0
	_capacity = int(ceil(peak * life * 1.3)) + 8
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_custom_data = true
	_mm.mesh = _quad(float(_cfg["cell"]) * TEXEL * 0.5)
	_mm.instance_count = _capacity
	_mm.visible_instance_count = 0
	_pos.resize(_capacity)
	_born.resize(_capacity)
	_born.fill(-1.0e9)
	_row.resize(_capacity)
	_mat = ShaderMaterial.new()
	_mat.shader = TRAIL_SHADER
	_mat.set_shader_parameter("life", life)
	_mat.set_shader_parameter("drift", Vector2.ZERO)
	_mat.set_shader_parameter("gravity", 0.0)
	_mat.set_shader_parameter("texel", TEXEL)
	_mat.set_shader_parameter("frames", float(FRAMES))
	_mat.set_shader_parameter("variants", float(_cfg["rows"]))
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = _mm
	mmi.texture = _cfg["sheet"]
	mmi.material = _mat
	mmi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(mmi)
	if bool(_cfg.get("crackle", false)):
		_crackle = Sprite2D.new()
		_crackle.texture = CRACKLE_SHEET
		_crackle.hframes = CRACKLE_FRAMES
		_crackle.scale = Vector2.ONE * TEXEL
		_crackle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_crackle.visible = false
		add_child(_crackle)


## Ata zincirinde görünür + yeterince opak mı (HÜCUM çekilmesi / saklanma / ölüm / görünmezlik modulate.a ile gelir).
func _source_shown() -> bool:
	if not source.is_visible_in_tree():
		return false
	var a: float = source.self_modulate.a
	var n: Node = source
	while n != null and n is CanvasItem:
		a *= (n as CanvasItem).modulate.a
		if a < MIN_ALPHA:
			return false
		n = n.get_parent()
	return true


func _emit(at: Vector2, age0: float, vel: Vector2, row: int) -> void:
	var i: int = _next
	_next = (_next + 1) % _capacity
	_mm.set_instance_transform_2d(i, Transform2D(0.0, at))
	_mm.set_instance_custom_data(i, Color(_clock - age0, float(row), vel.x, vel.y))
	_pos[i] = at
	_born[i] = _clock - age0
	_row[i] = row
	_spawned = mini(_spawned + 1, _capacity)
	_mm.visible_instance_count = _spawned
	_last_emit_clock = _clock


func _rand_vel() -> Vector2:
	var vx: Vector2 = _cfg["vx"]
	var vy: Vector2 = _cfg["vy"]
	return Vector2(randf_range(vx.x, vx.y), randf_range(vy.x, vy.y))


func _process(delta: float) -> void:
	_clock += delta
	_mat.set_shader_parameter("clock", _clock)
	if not _owned_source:
		if _hit_acc < 0.0 and _clock - _last_emit_clock > float(_cfg["life"]) + 0.1:
			queue_free() ## release() sonrası kalanlar söndü
		return
	if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
		_set_crackle(false)
		if _clock - _last_emit_clock > float(_cfg["life"]) + 0.1:
			queue_free()
		return
	var tip: Vector2 = WeaponTipScript.tip_global(source, forward_deg)
	if not _source_shown():
		_has_last = false
		_acc = 0.0
		_set_crackle(false)
		return
	var speed: float = 0.0
	if _has_last and delta > 0.0:
		speed = minf(MAX_TIP_SPEED, tip.distance_to(_last_tip) / delta)
	_acc += (float(_cfg["base"]) + float(_cfg["per_px"]) * speed) * delta
	var n: int = mini(int(_acc), MAX_PER_FRAME)
	if n > 0:
		_acc -= float(int(_acc))
		var rows: int = int(_cfg["rows"])
		for k in range(n):
			var f: float = float(k + 1) / float(n)
			var at: Vector2 = (_last_tip.lerp(tip, f) if _has_last else tip) + Vector2(randf_range(-JITTER, JITTER), randf_range(-JITTER, JITTER))
			_emit(at, float(n - 1 - k) / float(n) * delta, _rand_vel(), randi() % rows)
	_last_tip = tip
	_has_last = true
	if _crackle != null:
		_crackle.global_position = tip
		_crackle_t -= delta
		if _crackle_t <= 0.0:
			_crackle_t = randf_range(0.04, 0.08)
			## %25 boş aralık: cızırtı titresin, sürekli yanan bir top gibi durmasın
			_set_crackle(randf() >= 0.25)
			_crackle.frame = randi() % CRACKLE_FRAMES
			_crackle.flip_h = randf() < 0.5
			_crackle.flip_v = randf() < 0.5


func _set_crackle(on: bool) -> void:
	if _crackle != null:
		_crackle.visible = on


## Yıldırım isabeti: hedef merkezi `center` için bu karenin kıvılcımlarını doğurur (fx_lightning_beam.gd her kare çağırır).
## Kıvılcım gövde elipsinin kenarından dışa doğru çıkar; sayfa satırı = dış yön (k x 45 derece, gen_staff_tip_fx.py).
func emit_hit(center: Vector2, delta: float) -> void:
	if _mm == null or _hit_acc < 0.0:
		return
	_hit_acc += HIT_RATE * delta
	while _hit_acc >= 1.0:
		_hit_acc -= 1.0
		var a: float = randf() * TAU
		var at: Vector2 = center + Vector2(cos(a) * HIT_RX, sin(a) * HIT_RY)
		var row: int = int(round(a / (PI / 4.0))) % 8
		_emit(at, 0.0, Vector2.ZERO, row)


## Şu an yaşayan partiküllerin DOĞUŞ konumları (dünya).
func alive_positions() -> PackedVector2Array:
	var out := PackedVector2Array()
	var life: float = float(_cfg.get("life", 0.0))
	for i in _born.size():
		if _clock - _born[i] < life:
			out.append(_pos[i])
	return out


## Şu an yaşayan partiküllerin sayfa satırları (alive_positions ile aynı sıra).
func alive_rows() -> PackedInt32Array:
	var out := PackedInt32Array()
	var life: float = float(_cfg.get("life", 0.0))
	for i in _born.size():
		if _clock - _born[i] < life:
			out.append(_row[i])
	return out


## Işın bitti: yeni kıvılcım yok, kalanlar sönünce düğüm kendini siler.
func release() -> void:
	_hit_acc = -1.0
