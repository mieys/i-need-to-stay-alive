extends Node2D

## Papağan'ın ULTİ'si (Tüy Fırtınası, skill 22) için oyuncunun etrafında
## dönen yeşil/kırmızı tüy fırtınası. Oyuncunun global konumunu takip eder,
## içine giren yaratıklara saniyede en fazla 1 kez hasar verir, sonra solup
## kaybolur (bkz. player.gd _skill_papagan_feather_storm).

var owner_player: Node2D = null
var radius: float = 120.0
var damage_amount: float = 0.0
var hit_interval: float = 1.0
var touch_radius: float = 55.0
var lifetime: float = 8.0

var _elapsed: float = 0.0
var _spin: float = 0.0
var _hit_timers: Dictionary = {}
var _feathers: Array[Dictionary] = []

func _ready() -> void:
	z_index = 47
	for i in range(20):
		_feathers.append({
			"angle": randf() * TAU,
			"dist": randf_range(radius * 0.3, radius),
			"speed": randf_range(4.0, 8.0),
			"size": randf_range(3.0, 6.0),
			"red": randf() < 0.4,
		})

func setup(p_owner: Node2D, p_radius: float, p_damage: float, p_lifetime: float) -> void:
	owner_player = p_owner
	radius = p_radius
	damage_amount = p_damage
	lifetime = p_lifetime
	set_process(true)

func _process(delta: float) -> void:
	_elapsed += delta
	if not is_instance_valid(owner_player):
		queue_free()
		return
	global_position = owner_player.global_position
	_spin += delta * 5.0

	if _elapsed >= lifetime:
		modulate.a = max(0.0, (lifetime + 0.4 - _elapsed) / 0.4)
		if _elapsed >= lifetime + 0.4:
			queue_free()
			return

	for key in _hit_timers.keys():
		_hit_timers[key] = max(0.0, (_hit_timers[key] as float) - delta)

	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("is_dead") == true:
			continue
		if global_position.distance_to(e.global_position) > touch_radius:
			continue
		var id: int = e.get_instance_id()
		if _hit_timers.get(id, 0.0) > 0.0:
			continue
		_hit_timers[id] = hit_interval
		if e.has_method("take_damage"):
			e.take_damage(damage_amount, false, 0.0, true)

	for ft in _feathers:
		ft["angle"] += ft["speed"] * delta
		ft["dist"] = radius * (0.3 + 0.7 * abs(sin(_elapsed * 1.5 + ft["angle"])))

	queue_redraw()

func _draw() -> void:
	for ft in _feathers:
		var pos: Vector2 = Vector2(cos(ft["angle"]), sin(ft["angle"])) * ft["dist"]
		var col: Color = Color(0.9, 0.25, 0.2, 0.9) if ft["red"] else Color(0.3, 0.85, 0.3, 0.9)
		col.a = 0.9 * modulate.a
		var sz: float = ft["size"] * 0.5
		# küçük tüy: iki yapraklı elips
		draw_line(pos - Vector2(sz, 0), pos + Vector2(sz, 0), col, 1.5)
		draw_line(pos - Vector2(0, sz * 0.6), pos + Vector2(0, sz * 0.6), col, 1.5)
