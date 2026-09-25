extends Node2D

## Suriyeli Hadime Q (Lanet Kitabı) - TEK bir lanet: kitaptan yukarı fırlar, tepede yavaşlar, hedef yaratığa düşer.
## Görsel tamamen sprite sayfası (tools/gen_hadime_fx.py: curse_orb döngüsü + curse_mote izi + curse_launch/
## curse_impact tek seferlik) - her karede sadece DÜĞÜM KONUMU değişir (kullanıcı: "efektleri spritesheete dönüştür").
## Uçuş eğrisi HadimeMath.curse_position (yetkili kopya ve diğer oyunculardaki kozmetik kopya AYNI formül).
## Yetkili kopyada on_land (hasar) çağrılır; kozmetik kopyada on_land boş gelir (hasar host/sahibinde bir kez uygulanır).

const HadimeMath := preload("res://scripts/hadime_math.gd")
const OrbFrames: SpriteFrames = preload("res://assets/fx/hadime/curse_orb_frames.tres")
const MoteScene: PackedScene = preload("res://scenes/fx_hadime_curse_mote.tscn")
const LaunchScene: PackedScene = preload("res://scenes/fx_hadime_curse_launch.tscn")
const ImpactScene: PackedScene = preload("res://scenes/fx_hadime_curse_impact.tscn")
const MOTE_INTERVAL := 0.05
## Çarpma efektinin zemin noktası: hedefin gövde ortasından (enemy_hit_point) bu kadar aşağısı.
const IMPACT_GROUND_DROP := 8.0

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
## Tipsiz: silinmiş bir yaratık referansı tipli bir parametreye/değişkene girerse hata ayıklayıcı durur (bkz. hafıza).
var _target = null
var _on_land: Callable = Callable()
var _t: float = 0.0
var _mote_timer: float = 0.0
var _orb: AnimatedSprite2D = null


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_orb = AnimatedSprite2D.new()
	_orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_orb.sprite_frames = OrbFrames
	_orb.scale = Vector2.ONE * HadimeMath.TEXEL
	add_child(_orb)
	_orb.play(&"loop")


func setup(from: Vector2, to: Vector2, target, on_land: Callable) -> void:
	_from = from
	_to = to
	_target = target if (target is Node2D and is_instance_valid(target)) else null
	_on_land = on_land
	global_position = from
	_spawn_one_shot(LaunchScene, from)


func _process(delta: float) -> void:
	_t += delta
	## Hedef hâlâ yaşıyorsa lanet onu takip eder (yaratık uçuş sırasında yürümeye devam ediyor).
	if _target != null:
		if is_instance_valid(_target) and _target.get("is_dead") != true:
			_to = HadimeMath.enemy_hit_point(_target)
		else:
			_target = null
	global_position = HadimeMath.curse_position(_from, _to, _t)
	_mote_timer -= delta
	if _mote_timer <= 0.0:
		_mote_timer = MOTE_INTERVAL
		_spawn_one_shot(MoteScene, global_position)
	if _t >= HadimeMath.curse_total_time():
		_land()


func _land() -> void:
	_spawn_one_shot(ImpactScene, _to + Vector2(0, IMPACT_GROUND_DROP))
	if _on_land.is_valid():
		_on_land.call(_target if (_target != null and is_instance_valid(_target)) else null, _to)
	queue_free()


func _spawn_one_shot(scene: PackedScene, pos: Vector2) -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var fx: Node2D = scene.instantiate() as Node2D
	parent.add_child(fx)
	fx.global_position = pos
