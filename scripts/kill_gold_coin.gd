extends Node2D

## Yaratık altını yerde dönen para (kullanıcı isteği 2026-10-21): "yaratıklar ölünce direk altın vermek yerine verecekleri altını yere
## düşürüp (altının dönüş animasyonlu hali) 0.5 saniye sonra otomatik olarak vermesi gereken kişiye doğru uçarak versin."
## Ölüm noktasında HOVER_TIME sn dönerek durur (küçük bir zıplamayla), sonra alıcıya (yerel oyuncu) hızlanarak uçar; VARINCA altın
## eklenir + "+N" yazısı + ses (KillGold.credit). Sadece alıcının kendi ekranında vardır (uzak alıcıya host RPC atar, bkz. KillGold.award).

const COIN_FRAMES := preload("res://assets/pickups/gold/gold_coin_frames.tres")
const EnemyAbilities := preload("res://scripts/enemy_abilities.gd")

const HOVER_TIME := 0.5
const COIN_SCALE := 0.6 ## gold_drop.tscn ile aynı boy
const HOP_HEIGHT := 9.0
const HOP_TIME := 0.28
const START_SPEED := 150.0
const ACCEL := 1900.0
const MAX_SPEED := 950.0
const ARRIVE_DIST := 9.0
const MAX_FLIGHT := 1.6 ## yetişemezse (hızlı koşan hedef) bu süre sonunda yine de verilir
const TARGET_OFFSET := Vector2(0.0, -10.0)
const FLY_Z := 3

var amount: int = 0
var assist: int = 0
var target: Node2D = null
var on_arrive: Callable ## (amount, world_pos, assist); kill_gold.gd önyüklemesi döngü olmasın diye çağıran verir

var _t: float = 0.0
var _flight_t: float = 0.0
var _speed: float = START_SPEED
var _sprite: AnimatedSprite2D
var _done: bool = false


func setup(p_amount: int, p_assist: int, p_target: Node2D, p_on_arrive: Callable) -> void:
	amount = p_amount
	assist = p_assist
	target = p_target
	on_arrive = p_on_arrive


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = COIN_FRAMES
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * COIN_SCALE
	add_child(_sprite)
	_sprite.play("spin")
	_sprite.frame = randi() % maxi(1, COIN_FRAMES.get_frame_count("spin"))
	EnemyAbilities.place_on_ground(get_tree(), self) ## beklerken zeminde, karakterlerin altında


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t < HOVER_TIME:
		var k: float = clampf(_t / HOP_TIME, 0.0, 1.0)
		_sprite.position.y = -sin(k * PI) * HOP_HEIGHT
		return
	if _flight_t == 0.0:
		_sprite.position.y = 0.0
		z_index = FLY_Z ## uçarken karakterlerin üstünde görünsün
	_flight_t += delta
	if target == null or not is_instance_valid(target):
		_arrive() ## alıcı gitti (yerel oyuncu sahneden çıktı): olduğu yerde ver
		return
	var goal: Vector2 = target.global_position + TARGET_OFFSET
	_speed = minf(_speed + ACCEL * delta, MAX_SPEED)
	var to_goal: Vector2 = goal - global_position
	if to_goal.length() <= ARRIVE_DIST + _speed * delta * 0.5 or _flight_t >= MAX_FLIGHT:
		global_position = goal
		_arrive()
		return
	global_position += to_goal.normalized() * _speed * delta


func _arrive() -> void:
	if _done:
		return
	_done = true
	on_arrive.call(amount, global_position, assist)
	queue_free()
