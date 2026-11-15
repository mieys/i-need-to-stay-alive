extends Node

## BUZ KAYMASI (madde 680, 2026-11-14): Ayaz Dağı'nda donmuş göl buzunda oyuncu hızı girdiye anında uymaz (scripts/ice_slide_math.gd),
## GameManager.is_position_on_ice saf buz hücrelerini (kıyı kar kenarı hariç) tanır.

const IceSlide := preload("res://scripts/ice_slide_math.gd")
const SPEED := 252.0
const DT := 1.0 / 60.0


func _run(vel: Vector2, target: Vector2, seconds: float) -> Vector2:
	var v: Vector2 = vel
	for i: int in int(seconds / DT):
		v = IceSlide.step(v, target, DT, SPEED)
	return v


func test_start_is_gradual_not_instant() -> void:
	var v: Vector2 = IceSlide.step(Vector2.ZERO, Vector2(SPEED, 0.0), DT, SPEED)
	assert(v.x > 0.0 and v.x < SPEED * 0.1, "ilk karede tam hıza fırlamamalı: %s" % str(v))
	assert(is_equal_approx(_run(Vector2.ZERO, Vector2(SPEED, 0.0), IceSlide.ACCEL_TIME + 0.1).x, SPEED), "ACCEL_TIME sonunda tam hız")


func test_releasing_input_coasts_then_stops() -> void:
	var v: Vector2 = _run(Vector2(SPEED, 0.0), Vector2.ZERO, 0.3)
	assert(v.x > SPEED * 0.5, "bıraktıktan 0,3 sn sonra hâlâ kayıyor olmalı: %s" % str(v))
	assert(_run(Vector2(SPEED, 0.0), Vector2.ZERO, IceSlide.FRICTION_TIME + 0.1) == Vector2.ZERO, "sonunda durmalı")


func test_turning_keeps_old_direction_for_a_while() -> void:
	## Sağa tam hızla giderken sola basınca: 0,2 sn sonra hâlâ sağa gidiyor (kayma), sonunda sola döner.
	var v: Vector2 = _run(Vector2(SPEED, 0.0), Vector2(-SPEED, 0.0), 0.2)
	assert(v.x > 0.0, "ters yöne basınca hemen dönmemeli: %s" % str(v))
	v = _run(Vector2(SPEED, 0.0), Vector2(-SPEED, 0.0), IceSlide.ACCEL_TIME * 2.0 + 0.1)
	assert(is_equal_approx(v.x, -SPEED), "yeterince bekleyince yeni yöne oturmalı: %s" % str(v))


func test_perpendicular_turn_drifts_diagonally() -> void:
	## Sağa giderken yukarı basınca ara kare köşegen: eski hız bir süre korunur, yeni yön yavaş gelir.
	var v: Vector2 = _run(Vector2(SPEED, 0.0), Vector2(0.0, -SPEED), 0.2)
	assert(v.x > 0.0 and v.y < 0.0, "köşegene kaymalı: %s" % str(v))


func test_never_exceeds_target_speed() -> void:
	var v: Vector2 = _run(Vector2(SPEED, 0.0), Vector2(0.0, -SPEED), 0.5)
	assert(v.length() <= SPEED + 0.01, "kayarken hız hedef hızı aşmamalı: %s" % str(v.length()))


func test_ice_cell_query_ignores_shore_snow_cells() -> void:
	var scene: PackedScene = load("res://scenes/kis_baked.tscn")
	var root: Node = scene.instantiate()
	add_child(root)
	var ice := root.get_node("Yer/Buz") as TileMapLayer
	var edge := root.get_node("Yer/Zemin Çimen") as TileMapLayer
	GameManager._terrain_layers_searched = true
	GameManager._terrain_ice_layer = ice
	GameManager._terrain_ice_edge_layer = edge
	var pure := Vector2i(-1, -1)
	var shore := Vector2i(-1, -1)
	for c: Vector2i in ice.get_used_cells():
		if edge.get_cell_source_id(c) == -1:
			pure = c
		else:
			shore = c
		if pure.x >= 0 and shore.x >= 0:
			break
	assert(pure.x >= 0 and shore.x >= 0, "haritada hem saf buz hem kıyı hücresi olmalı")
	assert(GameManager.is_position_on_ice(ice.to_global(ice.map_to_local(pure))), "saf buz hücresi kaydırmalı")
	assert(not GameManager.is_position_on_ice(ice.to_global(ice.map_to_local(shore))), "kar kenarlı kıyı hücresi kaydırmamalı")
	assert(not GameManager.is_position_on_ice(Vector2(1352.0, 3784.0)), "doğuş noktası (kar) kaydırmamalı")
	root.queue_free()
	GameManager.reset() ## önbelleği temizle (sonraki testler gerçek sahneyi arasın)
