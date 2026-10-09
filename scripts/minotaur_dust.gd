extends Node2D

## Minotaur hücum tozu: (1) boss'un çocuğu olarak hücum pozundayken (enemy.gd _pose_override == POSE_CHARGE) ayaklarının
## arkasında toz bırakan iz; (2) `burst()` - isabet / duvara çarpma anında tek seferlik toz patlaması + kamera sarsıntısı.
## Hepsi KOZMETİK ve her peer'de yerelde üretilir (host'ta minotaur_charge.gd, istemcide broadcast_enemy_vfx "minotaur_pose" /
## "minotaur_impact" -> enemy.gd on_ability_vfx aynı işlevleri çağırır): ağdan konum/parçacık gitmez.
## Parçacık = CPUParticles2D (dokusuz küçük kareler, piksel-art görünüm), iz dünya koordinatında kalır (local_coords kapalı).

const CameraShakeScript: GDScript = preload("res://scripts/camera_shake.gd")
const CHARGE_POSE := 2 ## minotaur_math.gd POSE_CHARGE (burada sayı: enemy.gd ile aynı sabit, ayrı preload döngüsü olmasın)

const DUST_LIGHT := Color(0.82, 0.72, 0.56, 0.9)
const DUST_DARK := Color(0.5, 0.42, 0.32, 0.0)

var _trail: CPUParticles2D = null
var _owner_enemy: Node = null


## Yaratığa iz düğümünü bir kez ekler (zaten varsa onu döner).
static func attach(enemy: Node2D) -> Node2D:
	var existing: Node = enemy.get_node_or_null("MinotaurDust")
	if existing != null:
		return existing as Node2D
	var node := Node2D.new()
	node.set_script(load("res://scripts/minotaur_dust.gd"))
	node.name = "MinotaurDust"
	enemy.add_child(node)
	return node


func _ready() -> void:
	_owner_enemy = get_parent()
	_trail = CPUParticles2D.new()
	_trail.position = Vector2(0.0, 3.0)
	_trail.local_coords = false
	_trail.emitting = false
	_trail.amount = 30
	_trail.lifetime = 0.5
	_trail.direction = Vector2(0.0, -1.0)
	_trail.spread = 180.0
	_trail.initial_velocity_min = 10.0
	_trail.initial_velocity_max = 34.0
	_trail.gravity = Vector2.ZERO
	_trail.scale_amount_min = 1.6
	_trail.scale_amount_max = 3.4
	_trail.color_ramp = _ramp()
	add_child(_trail)


func _process(_delta: float) -> void:
	if _trail == null or _owner_enemy == null or not is_instance_valid(_owner_enemy):
		return
	_trail.emitting = int(_owner_enemy.get("_pose_override")) == CHARGE_POSE and _owner_enemy.get("is_dead") != true


static func _ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, DUST_LIGHT)
	g.set_color(1, DUST_DARK)
	return g


## Tek seferlik toz patlaması (isabet noktası / duvar). power 0..1: parçacık sayısı ve kamera sarsıntısı. dir: patlamanın ana yönü.
static func burst(tree: SceneTree, pos: Vector2, dir: Vector2, power: float) -> void:
	CameraShakeScript.add_at(pos, clampf(power, 0.0, 1.0))
	if tree == null or tree.current_scene == null or DisplayServer.get_name() == "headless":
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = int(14.0 + power * 18.0)
	p.lifetime = 0.55
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector2.UP
	p.spread = 75.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0
	p.damping_min = 120.0
	p.damping_max = 190.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.4
	p.color_ramp = _ramp()
	p.z_index = 4
	tree.current_scene.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
