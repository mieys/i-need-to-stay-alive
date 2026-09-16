extends Node2D
class_name FxArcaneSkullBounce

## Büyücü Kız'ın Arcane Lanet varyasyonu için mor piksel kafatası sekme ve iz efekti.
## Yaratıktan yaratığa doğru hızla uçar, arkasında mor kıvılcım izleri bırakır ve
## hedefe çarptığında küçük patlama efekti (FxArcaneImpact) tetikler.

var from_pos: Vector2 = Vector2.ZERO
var to_target: Node2D = null
var to_pos: Vector2 = Vector2.ZERO
var speed: float = 750.0
var elapsed: float = 0.0
var skull_tex: Texture2D = preload("res://assets/generated/fx_arcane_skull_pixel_frame_0.png")

var trail_points: Array[Dictionary] = [] ## {pos, alpha, size}

func setup(p_from: Vector2, p_target: Node2D) -> void:
	from_pos = p_from
	to_target = p_target
	global_position = from_pos
	if is_instance_valid(to_target):
		to_pos = to_target.global_position
	else:
		to_pos = from_pos


## weapon.gd/network_manager.gd'nin "chain_lightning" broadcast'iyle AYNI
## desen - uzak oyuncularda gerçek Enemy node referansı olmadığı için (host
## dışındaki istemcilerde bu yaratığın kozmetik kopyasını canlı takip etmek
## yerine) iki SABİT pozisyon arasında uçuyor. Canlı hedefi kaybetme riski
## yok (to_target hep null), ama görsel olarak setup()'tan ayırt edilemez.
func setup_positions(p_from: Vector2, p_to: Vector2) -> void:
	from_pos = p_from
	to_target = null
	to_pos = p_to
	global_position = from_pos

func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(to_target):
		to_pos = to_target.global_position

	var dir: Vector2 = to_pos - global_position
	var dist: float = dir.length()
	var step: float = speed * delta

	# Trail güncelle
	trail_points.append({
		"pos": global_position + Vector2(randf_range(-3, 3), randf_range(-3, 3)),
		"alpha": 0.9,
		"size": randf_range(3.0, 6.0)
	})

	var active_trail: Array[Dictionary] = []
	for tp in trail_points:
		tp["alpha"] -= delta * 3.5
		tp["size"] = max(1.0, tp["size"] - delta * 6.0)
		if tp["alpha"] > 0.0:
			active_trail.append(tp)
	trail_points = active_trail

	if dist <= step or dist < 12.0 or elapsed > 1.5:
		global_position = to_pos
		_spawn_impact()
		queue_free()
		return
	else:
		global_position += dir.normalized() * step

	queue_redraw()

func _spawn_impact() -> void:
	var impact := Node2D.new()
	impact.set_script(preload("res://scripts/fx_arcane_impact.gd"))
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(impact)
		impact.global_position = global_position

func _draw() -> void:
	# 1. Mor/eflatun iz parçacıkları
	for tp in trail_points:
		var rel_pos: Vector2 = tp["pos"] - global_position
		var c := Color(0.8, 0.3, 1.0, tp["alpha"])
		draw_circle(rel_pos, tp["size"] * 0.5, c)
		draw_circle(rel_pos, tp["size"] * 0.25, Color(1.0, 0.7, 1.0, tp["alpha"]))

	# 2. Mor enerji aurası
	var pulse: float = 1.0 + sin(elapsed * 18.0) * 0.15
	draw_circle(Vector2.ZERO, 10.0 * pulse, Color(0.6, 0.1, 0.9, 0.35))

	# 3. Piksel Kafatası
	if skull_tex:
		var sz: Vector2 = skull_tex.get_size()
		var rect := Rect2(-sz * 0.5, sz)
		draw_texture_rect(skull_tex, rect, false, Color(1.1, 0.9, 1.2, 1.0))
