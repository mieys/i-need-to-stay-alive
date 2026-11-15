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


## --- Takılınca yön arama (resolve_detour, 2026-11-13) ---

## 16x16 tek hücre engel (ağaç gövdesi gibi): x 0..16, y 0..16.
func _trunk(p: Vector2) -> bool:
	return p.x >= 0.0 and p.x < 16.0 and p.y >= 0.0 and p.y < 16.0


## Yürüt: her adımda resolve_detour; engele girilen adım sayısını ve son konumu döndürür.
func _walk(start: Vector2, dir: Vector2, blocked: Callable, steps: int, sides: Array = []) -> Dictionary:
	var state: Dictionary = {}
	var pos: Vector2 = start
	var inside: int = 0
	for i in steps:
		var v: Vector2 = WallSlide.resolve_detour(pos, dir * 120.0, blocked, state)
		if state.has("side"):
			sides.append(state["side"])
		pos += v * (1.0 / 60.0)
		if blocked.call(pos):
			inside += 1
	return {"pos": pos, "inside": inside}


func test_detour_walks_around_a_trunk_and_continues_forward() -> void:
	## Gövdenin tam ortasına karşıdan (aşağıdan yukarı) yürüyen oyuncu yana dolanıp gövdenin ötesine geçer.
	var r: Dictionary = _walk(Vector2(8.0, 40.0), Vector2.UP, _trunk, 240)
	assert(r["inside"] == 0, "engele girildi: %d adım" % r["inside"])
	assert(r["pos"].y < -10.0, "gövdenin ötesine geçmeliydi: %s" % str(r["pos"]))


func test_detour_does_not_flip_sides_every_frame() -> void:
	var sides: Array = []
	_walk(Vector2(8.0, 40.0), Vector2.UP, _trunk, 120, sides)
	assert(not sides.is_empty(), "dolanma başlamalıydı")
	for s in sides:
		assert(s == sides[0], "dolanma tarafı titredi: %s" % str(sides))


func test_detour_picks_the_side_that_is_not_a_dead_end() -> void:
	## Gövdenin solunu (x < 0) yukarıdan aşağı bir duvar kapatır: oyuncu biraz soldan gelse de SAĞA dolanmalı.
	var blocked := func(p: Vector2) -> bool: return _trunk(p) or (p.x < -6.0 and p.y > -60.0 and p.y < 60.0)
	var r: Dictionary = _walk(Vector2(4.0, 40.0), Vector2.UP, blocked, 300)
	assert(r["inside"] == 0, "engele girildi")
	assert(r["pos"].y < -10.0 and r["pos"].x >= 16.0, "sağdan dolanıp geçmeliydi: %s" % str(r["pos"]))


func test_detour_still_stops_at_a_wide_wall() -> void:
	var state: Dictionary = {}
	var v: Vector2 = WallSlide.resolve_detour(Vector2(95.0, 4.0), Vector2(100.0, 0.0), _wall, state)
	assert(v == Vector2.ZERO and state.is_empty(), "geniş duvarda dolanma olmamalı: %s" % str(v))


func test_detour_leaves_free_and_diagonal_movement_alone() -> void:
	var state: Dictionary = {}
	assert(WallSlide.resolve_detour(Vector2(10.0, 4.0), Vector2(100.0, 20.0), _wall, state) == Vector2(100.0, 20.0), "serbest hareket değişmemeli")
	var v: Vector2 = WallSlide.resolve_detour(Vector2(95.0, 4.0), Vector2(100.0, 90.0), _wall, state)
	assert(v == Vector2(0.0, 90.0) and state.is_empty(), "duvar boyunca çapraz kayma aynen kalmalı: %s" % str(v))


func test_detour_is_dropped_when_the_input_changes() -> void:
	var state: Dictionary = {}
	WallSlide.resolve_detour(Vector2(8.0, 24.0), Vector2(0.0, -120.0), _trunk, state)
	assert(state.has("side"), "dolanma başlamalıydı")
	var v: Vector2 = WallSlide.resolve_detour(Vector2(8.0, 24.0), Vector2(0.0, 120.0), _trunk, state)
	assert(state.is_empty() and v == Vector2(0.0, 120.0), "girdi tersine dönünce dolanma bırakılmalı: %s" % str(v))
