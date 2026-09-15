extends Node2D
class_name FxFrostNovaBurst

## Büyücü Kız'ın Don Nova yeteneği için radial buz patlaması ve donuk piksel rüzgar efekti.

var elapsed: float = 0.0
var max_radius: float = 320.0
var duration: float = 0.75
var anim_sprite: AnimatedSprite2D = null

var wind_particles: Array[Dictionary] = []

func _ready() -> void:
	# Karakterin ve yaratıkların altında/arkasında kalarak görüşü kapatmaması için z_index düşük
	z_index = 0
	# Merkez buz patlaması animasyonu
	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim_sprite.sprite_frames = load("res://assets/skills/mage_vfx/frost_nova_frames.tres")
	anim_sprite.scale = Vector2(2.5, 2.5) # Dengeli boyut
	# Saydamlık: karakteri gizlemeyecek tatlı yarı saydam bir buz patlaması
	anim_sprite.modulate = Color(1.0, 1.0, 1.0, 0.75)
	add_child(anim_sprite)
	anim_sprite.play("default")
	
	# Donuk rüzgar parçacıkları oluştur
	for i in range(45):
		var angle: float = randf() * TAU
		var spd: float = randf_range(300.0, 500.0)
		wind_particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(cos(angle), sin(angle)) * spd,
			"size": randf_range(4.0, 8.0),
			"life": randf_range(0.4, 0.8),
			"age": 0.0,
			"angle": angle
		})

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration:
		queue_free()
		return

	if anim_sprite:
		var burst_fade: float = clamp(1.0 - (elapsed / duration), 0.0, 1.0)
		anim_sprite.modulate.a = 0.55 * burst_fade

	for wp in wind_particles:
		wp["age"] += delta
		wp["pos"] += wp["vel"] * delta
		wp["vel"] = wp["vel"].rotated(delta * 1.5)

	queue_redraw()

func _draw() -> void:
	var progress: float = elapsed / duration
	var current_r: float = max_radius * (1.0 - pow(1.0 - progress, 2.0))
	var alpha: float = clamp(1.0 - progress, 0.0, 1.0)

	# 1. Genişleyen yarı saydam buz şoku halkası
	var ring_col := Color(0.6, 0.9, 1.0, 0.65 * alpha)
	draw_arc(Vector2.ZERO, current_r, 0.0, TAU, 48, ring_col, 5.0, true)
	var inner_ring := Color(0.85, 0.95, 1.0, 0.45 * alpha)
	draw_arc(Vector2.ZERO, max(0.0, current_r - 16.0), 0.0, TAU, 48, inner_ring, 3.0, true)

	# 2. Donuk rüzgar ve kar kristalleri
	for wp in wind_particles:
		var p_alpha: float = clamp(1.0 - (float(wp["age"]) / float(wp["life"])), 0.0, 1.0) * alpha
		if p_alpha <= 0.0:
			continue
		var col := Color(0.85, 0.95, 1.0, p_alpha * 0.9)
		var sz: float = float(wp["size"]) * 1.5
		var p: Vector2 = wp["pos"]
		
		# Rüzgar çizgisi (hareket yönüne doğru uzanan)
		var tail = wp["vel"].normalized() * (sz * 3.0)
		draw_line(p, p - tail, col, 2.5)
		draw_circle(p, sz * 0.6, Color(1.0, 1.0, 1.0, p_alpha))
