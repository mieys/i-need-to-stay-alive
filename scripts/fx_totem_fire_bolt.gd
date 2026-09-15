extends Node2D
class_name TotemFireBolt

## KOZMETİK efekt (hiçbir oyun mantığı YOK): Saldırı Totemi'nin yeteneğine
## özgü ateş mermisi. Totemin tepesinden hedef düşmana doğru süzülen bir
## alev oku - arkasında sönümlenen alev izi, varışta küçük bir ateş patlaması.
##
## Hasar hesabı buraya TAMAMEN dışarıdadır (bkz. totem_attack.gd _tick -
## enemy.take_damage). Bu node silinse bile skilin davranışı hiç değişmez.
## Kalkan Totemi'nin dalga efektiyle (totem_shield_wave.gd) AYNI "salt çizim"
## desenini kullanır: global_position tabanlı, top_level, sahne köküne eklenir.

var start_pos: Vector2 = Vector2.ZERO
## Mermi hedefi (Enemy). Takip ederken konumunu canlı okuruz; hedef sahnedan
## silinirse en son bilinen konumda patlamayla biter.
var target_ref: Node2D = null
var end_pos: Vector2 = Vector2.ZERO
var bolt_color: Color = Color(1.0, 0.55, 0.25)

var travel_time: float = 0.22
var impact_time: float = 0.28

var _elapsed: float = 0.0
## Alev izi - merminin geçmiş konumları (en yenisi başta).
var _trail: Array[Vector2] = []
## Varış kıvılcımları.
var _sparks: Array[Dictionary] = []


static func spawn(parent: Node, p_start: Vector2, p_target: Node2D, p_color: Color) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var bolt: TotemFireBolt = TotemFireBolt.new()
	bolt.start_pos = p_start
	bolt.end_pos = p_target.global_position if (p_target != null and is_instance_valid(p_target)) else p_start
	bolt.target_ref = p_target
	bolt.bolt_color = p_color
	parent.add_child(bolt)


func _ready() -> void:
	top_level = true
	position = Vector2.ZERO
	z_index = 5


func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(target_ref):
		end_pos = target_ref.global_position
	if _elapsed >= travel_time + impact_time:
		queue_free()
		return
	if _elapsed <= travel_time:
		var t: float = clampf(_elapsed / travel_time, 0.0, 1.0)
		var smooth_t: float = t * t * (3.0 - 2.0 * t)
		var head: Vector2 = start_pos.lerp(end_pos, smooth_t)
		_trail.push_front(head)
		if _trail.size() > 10:
			_trail.pop_back()
	for s in _sparks:
		s["age"] = float(s["age"]) + delta
		s["pos"] = (s["pos"] as Vector2) + (s["vel"] as Vector2) * delta
		s["vel"] = (s["vel"] as Vector2) + Vector2(0, 60.0) * delta
	queue_redraw()


func _draw() -> void:
	if _elapsed <= travel_time:
		_draw_flight()
	else:
		_draw_impact()


func _draw_flight() -> void:
	## Alev izi - geçmiş konumlarda sönümlenen turuncu daireler.
	for i in _trail.size():
		var fade: float = 1.0 - float(i) / float(_trail.size())
		var p: Vector2 = _trail[i]
		draw_circle(p, 3.0 + 2.5 * fade, Color(bolt_color.r, bolt_color.g * 0.6, bolt_color.b * 0.2, fade * 0.45))
	## Mermi çekirdeği - parlak beyaz-sarı merkez + renkli alev halesi.
	var head: Vector2 = _trail[0] if not _trail.is_empty() else start_pos
	draw_circle(head, 6.0, Color(bolt_color.r, bolt_color.g, bolt_color.b, 0.5))
	draw_circle(head, 3.2, Color(1.0, 0.95, 0.7, 0.95))
	draw_circle(head, 1.6, Color(1, 1, 1, 1))


func _draw_impact() -> void:
	var t: float = clampf((_elapsed - travel_time) / impact_time, 0.0, 1.0)
	var alpha: float = 1.0 - t
	## Varış anı ilk karede kıvılcımları bir kez üret.
	if _sparks.is_empty():
		for i in 7:
			var angle: float = randf() * TAU
			_sparks.append({
				"pos": end_pos,
				"vel": Vector2.from_angle(angle) * randf_range(60.0, 160.0),
				"age": 0.0,
				"life": randf_range(0.18, 0.3),
			})
	## Büyüyen ateş şoku halkası.
	draw_arc(end_pos, 4.0 + 22.0 * t, 0.0, TAU, 24, Color(bolt_color.r, bolt_color.g, bolt_color.b, alpha * 0.85), 2.5, true)
	draw_circle(end_pos, 6.0 * (1.0 - t) + 2.0, Color(1.0, 0.95, 0.7, alpha * 0.8))
	## Savrulan kıvılcımlar.
	for s in _sparks:
		var life: float = float(s["life"])
		var age: float = float(s["age"])
		if age >= life:
			continue
		var sa: float = (1.0 - age / life) * alpha
		draw_circle(s["pos"], 2.2, Color(bolt_color.r, bolt_color.g * 0.7, bolt_color.b * 0.3, sa))
