extends Node2D

## ZEHİR ASASI "A - Zehir Damlası" damlaları (madde 410; prototip tools/proto_20261106/zehir_asasi_proto.py, kullanıcı seçimi A).
## - Mermi izi (projectile.gd, dart_projectile): uçan damlanın kuyruğundan TRAIL_RATE/sn damla kopar, yerçekimiyle uçuşun ALTINDAKİ
##   zemine düşer ve küçük gölcük olur. Merminin yerden yüksekliği bilinmez (uzak kopyada sahip yok, konum _ready'den sonra gelir):
##   iki tarafta AYNI sabit model - silahtan çıkışta H_START, H_BLEND px uçunca H_END (hedefin gövdesi) (`trail_height`).
## - Asa ucu (staff_tip_fx.gd "poison" stili): asanın başından seyrek damla düşer, sahibin ayak hizasında gölcük olur.
## - İsabet (projectile.gd _spawn_impact): SPLASH_N damlalı taç sıçraması + büyük gölcük (eski fx_poison_hit yerine).
## Yükseklik benzetimi shell_casing_fx.gd gibi: yer düzlemindeki nokta g + yükseklik z, çizim (g.x, g.y - z). Damlalar havada AIR_Z'de
## (karakterlerin üstünde), gölcükler haritanın hemen üstündeki zemin katmanında (enemy_abilities.place_on_ground - kan lekesiyle aynı).
## Tek yönetici düğüm (sahne başına, tembel kurulur), iki _draw (hava + zemin), sprite/düğüm yok; tavanlar MAX_DROPS / MAX_PUDDLES
## (aşılınca en eski düşer), boşken işlemez. Kozmetik: kaster ve uzak kopya kendi damlalarını üretir (ek RPC yok).
## Doku tools/gen_zehir_damla_fx.py (hücre 12x7, sanat pikseli WORLD_PX = mermi/silah pikseli).

const EnemyAbilities := preload("res://scripts/enemy_abilities.gd")
const TEX := preload("res://assets/fx/poison/zehir_damla_a.png")
const NODE_NAME := "PoisonDripFx"
const WORLD_PX := 0.575
const CELL_W := 12
## Hücre içindeki dolu bölge (sol üstten): 0 damla, 1 hızlı damla, 2 asa ucu damlası, 3 küçük gölcük, 4 büyük gölcük.
const REGIONS := [Rect2(0, 0, 2, 2), Rect2(12, 0, 2, 3), Rect2(24, 0, 3, 3), Rect2(36, 0, 7, 3), Rect2(48, 0, 11, 5)]
const K_DROP := 0
const K_FAST := 1
const K_BIG := 2
const K_PUDDLE := 3
const K_PUDDLE_BIG := 4
const FAST_VZ := -120.0 ## bundan hızlı düşen damla uzun (2x3) kare
const GRAVITY := 300.0 ## dünya px/sn^2
const AIR_Z := 55
const MAX_DROPS := 160
const MAX_PUDDLES := 120
const PUDDLE_LIFE := 0.75
const PUDDLE_LIFE_BIG := 0.9
const FADE_FROM := 0.5 ## ömrün bu kesrinden sonra 4 adımda söner (dither / yumuşak geçiş yok)
## mermi izi
const TRAIL_RATE := 26.0 ## damla / sn
const TRAIL_BACK := 5.5 ## kuyruk: merkezin bu kadar gerisi (dünya px)
const H_START := 56.0
const H_END := 8.0
const H_BLEND := 150.0
## isabet
const SPLASH_N := 6
const SPLASH_BODY := 10.0 ## isabet noktası ayak hizasındaysa (kaster mermiyi yaratığın konumuna ışınlar) gövdenin bu kadar üstünden

var _drops: Array = [] ## {g: Vector2, z, vz, vx, k}
var _puddles: Array = [] ## {p: Vector2, t, life, k}
var _ground: Node2D = null


class GroundLayer extends Node2D:
	var mgr: Node2D = null

	func _draw() -> void:
		if is_instance_valid(mgr):
			mgr.call("_draw_puddles", self)


## Mermi izi damlası: from = kuyruk (dünya), dir = uçuş yönü, traveled = silahtan beri uçulan yol.
static func trail_drop(tree: SceneTree, from: Vector2, dir: Vector2, traveled: float) -> void:
	var m := _mgr(tree)
	if m == null:
		return
	var gy: float = from.y + trail_height(traveled)
	var vy: float = dir.y * 40.0 + randf_range(0.0, 20.0)
	m.call("_add", Vector2(from.x + randf_range(-1.0, 1.0), gy), gy - from.y, -vy, dir.x * 40.0, K_DROP)


## Uçuşun altındaki zeminin mermiden uzaklığı (sabit model, bkz. üst not).
static func trail_height(traveled: float) -> float:
	return lerpf(H_START, H_END, clampf(traveled / H_BLEND, 0.0, 1.0))


## Asa ucu damlası (staff_tip_fx.gd "poison"): ground_y = sahibin ayak hizası.
static func tip_drop(tree: SceneTree, from: Vector2, ground_y: float) -> void:
	var m := _mgr(tree)
	if m == null:
		return
	var gy: float = maxf(ground_y, from.y + 4.0)
	m.call("_add", Vector2(from.x, gy), gy - from.y, -randf_range(5.0, 20.0), randf_range(-4.0, 4.0), K_BIG)


## İsabet: taç sıçraması + büyük gölcük. origin = isabet noktası, feet_y = vurulanın ayak hizası.
static func splash(tree: SceneTree, origin: Vector2, feet_y: float) -> void:
	var m := _mgr(tree)
	if m == null:
		return
	var o: Vector2 = origin
	if o.y > feet_y - SPLASH_BODY * 0.6:
		o.y = feet_y - SPLASH_BODY
	for i in SPLASH_N:
		var ang: float = -PI * 0.5 + (float(i) - (SPLASH_N - 1) * 0.5) * 0.42 + randf_range(-0.1, 0.1)
		var sp: float = randf_range(45.0, 75.0)
		var gy: float = feet_y + randf_range(-2.0, 3.0)
		m.call("_add", Vector2(o.x, gy), gy - o.y, -sin(ang) * sp, cos(ang) * sp, K_DROP)
	m.call("_add_puddle", Vector2(o.x, feet_y + 1.0), K_PUDDLE_BIG, PUDDLE_LIFE_BIG)


static func _mgr(tree: SceneTree) -> Node2D:
	if tree == null or tree.current_scene == null:
		return null
	var root: Node = tree.current_scene
	var m: Node = root.get_node_or_null(NODE_NAME)
	if m != null:
		return m as Node2D
	var node: Node2D = (load("res://scripts/poison_drip_fx.gd") as GDScript).new()
	node.name = NODE_NAME
	root.add_child(node)
	node.call("_setup")
	return node


func _setup() -> void:
	z_index = AIR_Z
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ground = GroundLayer.new()
	_ground.name = "PoisonDripGround"
	_ground.mgr = self
	_ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_parent().add_child(_ground)
	EnemyAbilities.place_on_ground(get_tree(), _ground)
	set_process(false)


func _exit_tree() -> void:
	if is_instance_valid(_ground):
		_ground.queue_free()


func _add(g: Vector2, z: float, vz: float, vx: float, k: int) -> void:
	if _drops.size() >= MAX_DROPS:
		_drops.pop_front()
	_drops.append({"g": g, "z": maxf(0.0, z), "vz": vz, "vx": vx, "k": k})
	set_process(true)


func _add_puddle(p: Vector2, k: int, life: float) -> void:
	if _puddles.size() >= MAX_PUDDLES:
		_puddles.pop_front()
	_puddles.append({"p": (p * 2.0).round() * 0.5, "t": 0.0, "life": life, "k": k})
	set_process(true)


func _process(delta: float) -> void:
	var i: int = 0
	while i < _drops.size():
		var d: Dictionary = _drops[i]
		var vz: float = float(d["vz"]) - GRAVITY * delta
		var z: float = float(d["z"]) + vz * delta
		var g: Vector2 = d["g"]
		g.x += float(d["vx"]) * delta
		if z <= 0.0:
			_drops.remove_at(i)
			## asa ucu damlası küçük gölcük, mermi damlası da küçük gölcük (büyüğü yalnız isabette)
			_add_puddle(g, K_PUDDLE, PUDDLE_LIFE)
			continue
		d["vz"] = vz
		d["z"] = z
		d["g"] = g
		i += 1
	i = 0
	while i < _puddles.size():
		var p: Dictionary = _puddles[i]
		p["t"] = float(p["t"]) + delta
		if float(p["t"]) >= float(p["life"]):
			_puddles.remove_at(i)
			continue
		i += 1
	queue_redraw()
	if is_instance_valid(_ground):
		_ground.queue_redraw()
	if _drops.is_empty() and _puddles.is_empty():
		set_process(false)


func _draw() -> void:
	for d in _drops:
		var k: int = int(d["k"])
		if k == K_DROP and float(d["vz"]) < FAST_VZ:
			k = K_FAST
		var g: Vector2 = d["g"]
		_blit(self, Vector2(g.x, g.y - float(d["z"])), k, 1.0)


func _draw_puddles(layer: CanvasItem) -> void:
	for p in _puddles:
		var f: float = float(p["t"]) / float(p["life"])
		var a: float = 1.0
		if f > FADE_FROM:
			a = ceilf((1.0 - (f - FADE_FROM) / (1.0 - FADE_FROM)) * 4.0 - 0.0001) / 4.0
		if a > 0.0:
			_blit(layer, p["p"], int(p["k"]), a)


static func _blit(ci: CanvasItem, at: Vector2, k: int, a: float) -> void:
	var r: Rect2 = REGIONS[k]
	var sz: Vector2 = r.size * WORLD_PX
	var tl: Vector2 = ((at - sz * 0.5) * 2.0).round() * 0.5
	ci.draw_texture_rect_region(TEX, Rect2(tl, sz), r, Color(1, 1, 1, a))


## Test / ölçüm için.
func drop_count() -> int:
	return _drops.size()


func puddle_count() -> int:
	return _puddles.size()
