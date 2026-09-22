extends Node2D

## Boss altını paylaşıldığında toplanma noktasından HER oyuncuya doğru uçan pixel-art altın (kullanıcı isteği,
## 2026-09-21: "herkesin payı kendisine doğru uçar"). Tamamen kozmetik: altın host'ta zaten verildi
## (bkz. network_manager.gd host_share_boss_gold), bu efekt _rpc_gold_share_fx ile HER istemcide kendi kopyasını doğurur.
## Hedef hareketli bir düğüm (yerel oyuncu ya da uzak kukla) - her karede güncel konumuna doğru uçar.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

const FLIGHT_TIME := 0.62
const ARC_HEIGHT := 46.0
const STAGGER := 0.07 ## her ek oyuncu için başlangıç gecikmesi (paylar art arda saçılsın)
const TRAIL_LEN := 6

const COIN := [
	".yy.",
	"yGGy",
	"yGWy",
	".yy.",
]
const COIN_PALETTE := {
	"y": Color(0.78, 0.5, 0.08),
	"G": Color(1.0, 0.82, 0.22),
	"W": Color(1.0, 0.97, 0.7),
}

var _from: Vector2 = Vector2.ZERO
var _target: Node2D = null
var _delay: float = 0.0
var _is_local: bool = false
var _t: float = 0.0
var _pos: Vector2 = Vector2.ZERO
var _last_target_pos: Vector2 = Vector2.ZERO
var _trail: Array = []
var _lateral: float = 1.0 ## yayın hangi yana bombeli olacağı (her payda farklı)


func setup(from_pos: Vector2, target: Node2D, index: int, is_local: bool) -> void:
	_from = from_pos
	_target = target
	_delay = STAGGER * float(index)
	_is_local = is_local
	_lateral = 1.0 if index % 2 == 0 else -1.0
	_pos = from_pos
	_last_target_pos = target.global_position


func _ready() -> void:
	top_level = true
	z_index = 30
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _target == null or not is_instance_valid(_target):
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	if _t < _delay:
		return
	if _target != null and is_instance_valid(_target):
		_last_target_pos = _target.global_position + Vector2(0.0, -14.0) ## gövdenin ortası
	var k: float = clampf((_t - _delay) / FLIGHT_TIME, 0.0, 1.0)
	var eased: float = k * k * (3.0 - 2.0 * k)
	var dir: Vector2 = (_last_target_pos - _from)
	var normal: Vector2 = Vector2(-dir.y, dir.x).normalized() * _lateral if dir.length() > 1.0 else Vector2.ZERO
	var arc: float = sin(k * PI) * ARC_HEIGHT
	_pos = _from.lerp(_last_target_pos, eased) + normal * arc
	_trail.push_front(_pos)
	if _trail.size() > TRAIL_LEN:
		_trail.resize(TRAIL_LEN)
	global_position = Vector2.ZERO
	if k >= 1.0:
		_arrive()
		return
	queue_redraw()


func _arrive() -> void:
	PixelDraw.spawn_burst(get_tree().current_scene, _last_target_pos, "spark", 8, 90.0, 0.32)
	if _is_local:
		_play_pickup_sound()
	queue_free()


## Yalnızca payı alan oyuncunun kendi ekranında (herkes herkesinkini duymasın) altın toplama sesi.
func _play_pickup_sound() -> void:
	var stream: AudioStream = load("res://assets/audio/gold_pickup.mp3") as AudioStream
	if stream == null or get_tree().current_scene == null:
		return
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = stream
	sfx.volume_db = -8.0
	sfx.max_distance = 1500.0
	get_tree().current_scene.add_child(sfx)
	sfx.global_position = _last_target_pos
	sfx.finished.connect(sfx.queue_free)
	sfx.play()


func _draw() -> void:
	if _t < _delay:
		return
	## Kuyruk: eski konumlar küçülerek solar.
	for i in range(_trail.size()):
		var f: float = 1.0 - float(i) / float(TRAIL_LEN)
		var col := Color(1.0, 0.85, 0.3, 0.55 * f)
		PixelDraw.px(self, _trail[i], 1 if i > 1 else 2, col)
	PixelDraw.art(self, _pos, COIN, COIN_PALETTE)
