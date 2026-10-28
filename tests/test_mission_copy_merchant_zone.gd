extends Node

## 2026-10-21 (kullanıcı: "kopyanı öldür görevinde kopya seyyar satıcı kalkanına girebiliyor ve saldırabiliyor, hasar veremese de rahatsız edici"):
## kopya seyyar satıcının koruma bölgesine GİREMEZ, bölgedeki oyuncuyu hedef almaz, mermisi bölgeye girince söner (yaratıklarla aynı kural).

const CopyScript: GDScript = preload("res://scripts/mission_player_copy.gd")
const BoltScript: GDScript = preload("res://scripts/mission_copy_bolt.gd")

const ZONE_POS := Vector2(1000.0, 1000.0)

var _spawned: Array[Node] = []


func _enter_zone() -> void:
	GameManager.merchant_zone_active = true
	GameManager.merchant_zone_pos = ZONE_POS


func _cleanup() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	GameManager.merchant_zone_active = false
	GameManager.merchant_zone_pos = Vector2.ZERO


func _make_copy(at: Vector2) -> Node2D:
	var c: Node2D = CopyScript.new()
	add_child(c)
	_spawned.append(c)
	c.call("setup", 1, 0, 0, 200.0, 0.0, 150.0, 100.0, true)
	c.global_position = at
	return c


func _make_fake_player(at: Vector2) -> Node2D:
	var p := Node2D.new()
	add_child(p)
	p.add_to_group("player")
	_spawned.append(p)
	p.global_position = at
	return p


func test_copy_inside_zone_is_pushed_out() -> void:
	_enter_zone()
	var c: Node2D = _make_copy(ZONE_POS + Vector2(40.0, 0.0))
	c.call("_keep_out_of_merchant_zone")
	var d: float = c.global_position.distance_to(ZONE_POS)
	assert(d > GameManager.MERCHANT_ZONE_RADIUS, "içeri düşen kopya dışarı alınmalı: %s" % str(d))
	assert(d < GameManager.MERCHANT_ZONE_RADIUS + 3.0, "bölgenin hemen dışına alınmalı (savrulmamalı): %s" % str(d))
	assert(c.global_position.x > ZONE_POS.x, "merkezden geldiği yöne doğru itilmeli")
	assert(not GameManager.is_position_in_merchant_zone(c.global_position), "itildikten sonra bölge içinde sayılmamalı")
	_cleanup()


func test_copy_exactly_at_center_is_pushed_out() -> void:
	_enter_zone()
	var c: Node2D = _make_copy(ZONE_POS)
	c.call("_keep_out_of_merchant_zone")
	assert(c.global_position.distance_to(ZONE_POS) > GameManager.MERCHANT_ZONE_RADIUS, "tam merkezdeki kopya da dışarı alınmalı")
	_cleanup()


func test_copy_outside_zone_is_untouched() -> void:
	_enter_zone()
	var at: Vector2 = ZONE_POS + Vector2(GameManager.MERCHANT_ZONE_RADIUS + 60.0, 0.0)
	var c: Node2D = _make_copy(at)
	c.call("_keep_out_of_merchant_zone")
	assert(c.global_position.is_equal_approx(at), "bölge dışındaki kopya yerinden oynamamalı")
	_cleanup()


func test_copy_ignores_zone_when_no_merchant() -> void:
	GameManager.merchant_zone_active = false
	GameManager.merchant_zone_pos = ZONE_POS
	var at: Vector2 = ZONE_POS + Vector2(10.0, 0.0)
	var c: Node2D = _make_copy(at)
	c.call("_keep_out_of_merchant_zone")
	assert(c.global_position.is_equal_approx(at), "satıcı yokken bölge kuralı işlemez")
	_cleanup()


func test_player_in_zone_is_not_targeted() -> void:
	_enter_zone()
	var c: Node2D = _make_copy(ZONE_POS + Vector2(GameManager.MERCHANT_ZONE_RADIUS + 100.0, 0.0))
	var inside: Node2D = _make_fake_player(ZONE_POS + Vector2(20.0, 0.0)) ## kopyaya daha YAKIN ama bölgede
	var target: Variant = c.call("_find_nearest_player")
	assert(target != inside, "bölgedeki oyuncu hedef olmamalı")
	var outside: Node2D = _make_fake_player(c.global_position + Vector2(0.0, 400.0)) ## uzak ama bölge dışında
	target = c.call("_find_nearest_player")
	assert(target == outside, "bölge dışındaki oyuncu hedef olmalı")
	_cleanup()


func test_bolt_dies_inside_zone() -> void:
	_enter_zone()
	var bolt := Node2D.new()
	bolt.set_script(BoltScript)
	var from: Vector2 = ZONE_POS + Vector2(GameManager.MERCHANT_ZONE_RADIUS + 5.0, 0.0)
	bolt.call("setup", from, ZONE_POS, 10.0, null, false, {})
	add_child(bolt)
	_spawned.append(bolt)
	bolt.global_position = from
	for i in 20: ## 340 px/sn x 1/60 -> ~5,7 px/kare: bir kaç karede sınırı geçer
		if bolt.is_queued_for_deletion():
			break
		bolt.call("_physics_process", 1.0 / 60.0)
	assert(bolt.is_queued_for_deletion(), "bölgeye giren mermi sönmeli")
	_cleanup()


func test_bolt_does_not_hit_player_in_zone() -> void:
	_enter_zone()
	var inside: Node2D = _make_fake_player(ZONE_POS + Vector2(GameManager.MERCHANT_ZONE_RADIUS - 5.0, 0.0))
	var bolt := Node2D.new()
	bolt.set_script(BoltScript)
	bolt.call("setup", inside.global_position + Vector2(10.0, 0.0), inside.global_position + Vector2(200.0, 0.0), 10.0, null, true, {})
	add_child(bolt)
	_spawned.append(bolt)
	bolt.global_position = inside.global_position + Vector2(10.0, 0.0)
	assert(bolt.call("_touching_player") == null, "bölgedeki oyuncu mermiye isabet olarak sayılmamalı")
	_cleanup()
