extends Node2D
class_name FxArcaneSkullBounce

## Büyücü Kız'ın Arcane Lanet varyasyonu için mor piksel kafatası sekme ve iz efekti.
## Yaratıktan yaratığa doğru hızla uçar, arkasında mor kıvılcım izleri bırakır ve
## hedefe çarptığında ARCANE PATLAMASI (FxArcaneImpact) tetikler.
##
## Kullanıcı isteği (2026-09-22): "arcane patlaması ... sıfırdan, daha iyi, pixel tarzda" - projektil de yeniden çizildi: eskiden düzgün daireler
## (draw_circle) + raster kafatası dokusu vardı, artık tamamen 1-texel pixel-art: pixel kafatası (FxArcaneImpact.SKULL ile AYNI şekil - patlamada
## çıkan hayalet kafatasıyla bağlantılı), dither mor aura, üç hayalet art-görüntü (afterimage), dönen mor kıvılcımlar ve yanan pixel izi.

const PixelDraw := preload("res://scripts/pixel_draw.gd")

var from_pos: Vector2 = Vector2.ZERO
var to_target: Node2D = null
var to_pos: Vector2 = Vector2.ZERO
var speed: float = 750.0
var elapsed: float = 0.0

var trail_points: Array[Dictionary] = [] ## {pos, alpha, size}
var _ghosts: Array[Dictionary] = [] ## {pos, alpha} - kafatasının geride bıraktığı soluk kopyalar
var _ghost_timer: float = 0.0


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


func _ready() -> void:
	z_index = 45
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(to_target):
		to_pos = to_target.global_position

	var dir: Vector2 = to_pos - global_position
	var dist: float = dir.length()
	var step: float = speed * delta

	# İz parçacıkları (pixel kıvılcımlar)
	trail_points.append({
		"pos": global_position + Vector2(randf_range(-4, 4), randf_range(-4, 4)),
		"alpha": 0.95,
		"size": randf_range(1.0, 3.0),
	})
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_ghost_timer = 0.035
		_ghosts.append({"pos": global_position, "alpha": 0.5})

	var active_trail: Array[Dictionary] = []
	for tp in trail_points:
		tp["alpha"] -= delta * 3.2
		if tp["alpha"] > 0.0:
			active_trail.append(tp)
	trail_points = active_trail
	var active_ghosts: Array[Dictionary] = []
	for g in _ghosts:
		g["alpha"] -= delta * 4.5
		if g["alpha"] > 0.0:
			active_ghosts.append(g)
	_ghosts = active_ghosts

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


func _skull_palette(a: float, glow: float) -> Dictionary:
	return {
		"W": Color(0.42, 0.14, 0.62, a),
		"L": Color(0.98, 0.9, 1.0, a),
		"D": Color(0.2, 0.04, 0.3, a),
		"E": Color(1.0, 0.45 + 0.4 * glow, 1.0, a),
	}


func _draw() -> void:
	var t: float = PixelDraw.TEXEL
	# 1. Yanan mor pixel izi
	for tp in trail_points:
		var rel_pos: Vector2 = tp["pos"] - global_position
		var a: float = tp["alpha"]
		var n: int = 2 if float(tp["size"]) > 2.2 else 1
		PixelDraw.px(self, rel_pos, n, Color(0.72, 0.32, 1.0, a))
		if a > 0.55:
			PixelDraw.px(self, rel_pos, 1, Color(1.0, 0.82, 1.0, a))
	# 2. Hayalet art-görüntüler (soluk kafatası kopyaları)
	for g in _ghosts:
		PixelDraw.art(self, g["pos"] - global_position, FxArcaneImpact.SKULL, _skull_palette(float(g["alpha"]) * 0.55, 0.0), 1.0)
	# 3. Mor dither enerji aurası (nabız atar)
	var pulse: float = 1.0 + sin(elapsed * 18.0) * 0.14
	PixelDraw.disc_dither(self, Vector2.ZERO, 13.0 * pulse, Color(0.6, 0.15, 0.95, 0.5), int(elapsed * 20.0), 1)
	# 4. Pixel kafatası (gözler parlar)
	PixelDraw.art(self, Vector2.ZERO, FxArcaneImpact.SKULL, _skull_palette(1.0, 0.5 + 0.5 * sin(elapsed * 30.0)), 1.0)
	# 5. Etrafında dönen 3 mor kıvılcım
	for i in range(3):
		var ang: float = elapsed * 16.0 + float(i) * TAU / 3.0
		PixelDraw.px(self, Vector2(cos(ang), sin(ang)) * 10.0, 1, Color(0.95, 0.75, 1.0, 0.95))
