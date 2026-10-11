extends Node

## Engele takılınca kayma (scripts/wall_slide.gd, 2026-10-11): karşıdan köşeye yürüyen oyuncu boş yana doğru kayar; geniş duvarda durur;
## zaten yandan kayan oyuncu etkilenmez.

const WallSlide := preload("res://scripts/wall_slide.gd")


## x >= 100 ve y >= 0 engel (sağ-alt köşe değil: y < 0 tarafı açık) - "yarı düzlem" duvar, köşesi y = 0'da.
func _corner(p: Vector2) -> bool:
	return p.x >= 100.0 and p.y >= 0.0


func _wall(p: Vector2) -> bool:
	return p.x >= 100.0


func test_head_on_into_a_corner_slides_toward_the_open_side() -> void:
	## Oyuncu y = 4'te, duvarın köşesi y = 0'da: kuzeye (yukarı, -y) 4 px kayınca açılır.
	var v: Vector2 = WallSlide.resolve(Vector2(95.0, 4.0), Vector2(100.0, 0.0), _corner)
	assert(v.x == 0.0, "engelli eksen sıfırlanmalı")
	assert(v.y < 0.0, "açık yana (yukarı) kaymalı: %s" % str(v))
	assert(absf(v.y) <= 100.0, "kayma hızı asıl hızı aşmamalı")


func test_flat_wall_still_stops_the_player() -> void:
	var v: Vector2 = WallSlide.resolve(Vector2(95.0, 4.0), Vector2(100.0, 0.0), _wall)
	assert(v == Vector2.ZERO, "geniş duvarda kayma olmamalı: %s" % str(v))


func test_free_movement_is_untouched() -> void:
	var v: Vector2 = WallSlide.resolve(Vector2(10.0, 4.0), Vector2(100.0, 20.0), _wall)
	assert(v == Vector2(100.0, 20.0), "engel yokken hız değişmemeli")


func test_player_already_sliding_diagonally_keeps_own_side_speed() -> void:
	var v: Vector2 = WallSlide.resolve(Vector2(95.0, 4.0), Vector2(100.0, 90.0), _wall)
	assert(v.x == 0.0 and v.y == 90.0, "zaten yandan hareket varsa o korunur: %s" % str(v))


func test_vertical_head_on_slides_sideways() -> void:
	## Yatay şerit engel: y >= 100 ve x >= 0; oyuncu x = 3'te aşağı yürür -> sola (x < 0 açık) kayar.
	var strip := func(p: Vector2) -> bool: return p.y >= 100.0 and p.x >= 0.0
	var v: Vector2 = WallSlide.resolve(Vector2(3.0, 95.0), Vector2(0.0, 100.0), strip)
	assert(v.y == 0.0 and v.x < 0.0, "sola kaymalı: %s" % str(v))
