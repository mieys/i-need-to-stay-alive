extends Node2D
class_name FxMeteorStrike

## Büyücü Kız'ın Meteor Patlaması varyasyonu için gökten düşen piksel meteor ve yer patlaması efekti.

var target_pos: Vector2 = Vector2.ZERO
var start_pos: Vector2 = Vector2.ZERO
var duration: float = 0.45
var elapsed: float = 0.0
var has_exploded: bool = false

var rock_tex: Texture2D = preload("res://assets/generated/fx_meteor_rock_pixel_frame_0.png")
var trail_particles: Array[Dictionary] = []

func setup(p_target: Vector2) -> void:
	target_pos = p_target
	# Gökten çapraz aşağı doğru düşüş (ör. 400px yukarıdan ve 150px soldan)
	start_pos = target_pos + Vector2(-120.0, -420.0)
	global_position = start_pos
	z_index = 52

func _process(delta: float) -> void:
	elapsed += delta
	if not has_exploded:
		var p: float = clamp(elapsed / duration, 0.0, 1.0)
		# Hızlanarak düşüş (ease-in)
		var t_eased: float = p * p
		global_position = start_pos.lerp(target_pos, t_eased)

		# Alev izi parçacıkları
		trail_particles.append({
			"pos": global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
			"alpha": 0.9,
			"size": randf_range(4.0, 8.0)
		})

		if p >= 1.0:
			has_exploded = true
			_explode()

	var active_tp: Array[Dictionary] = []
	for tp in trail_particles:
		tp["alpha"] -= delta * 4.0
		tp["size"] = max(1.0, tp["size"] - delta * 10.0)
		if tp["alpha"] > 0.0:
			active_tp.append(tp)
	trail_particles = active_tp

	if has_exploded and trail_particles.is_empty():
		queue_free()
		return

	queue_redraw()

func _explode() -> void:
	global_position = target_pos
	var exp_node := Node2D.new()
	exp_node.z_index = 53
	var anim_sprite := AnimatedSprite2D.new()
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new()
	frames.add_animation("explode")
	frames.set_animation_loop("explode", false)
	frames.set_animation_speed("explode", 16.0)
	var sheet: Texture2D = preload("res://assets/generated/fx_meteor_explosion_anim.png")
	if sheet:
		for i in range(6):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * 64, 0, 64, 64)
			frames.add_frame("explode", at)
	anim_sprite.sprite_frames = frames
	anim_sprite.scale = Vector2(2.2, 2.2)
	exp_node.add_child(anim_sprite)
	if get_tree() and get_tree().current_scene:
		get_tree().current_scene.add_child(exp_node)
		exp_node.global_position = target_pos
		anim_sprite.play("explode")
		anim_sprite.animation_finished.connect(func(): exp_node.queue_free())

func _draw() -> void:
	# 1. Alev ve duman izleri
	for tp in trail_particles:
		var rel_p: Vector2 = tp["pos"] - global_position
		var c := Color(1.0, randf_range(0.3, 0.7), 0.1, tp["alpha"])
		draw_circle(rel_p, tp["size"] * 0.5, c)
		draw_circle(rel_p, tp["size"] * 0.25, Color(1.0, 0.9, 0.4, tp["alpha"]))

	# 2. Meteor Kayası
	if not has_exploded and rock_tex:
		var sz: Vector2 = rock_tex.get_size()
		var rect := Rect2(-sz * 0.5, sz)
		draw_texture_rect(rock_tex, rect, false, Color(1.1, 1.0, 0.9, 1.0))
