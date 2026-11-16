extends Node

## 2026-10-12 (kullanıcı: "Tüftüf'ün efekti çok fazla"): zehir durum efekti en çok POISON_STATUS_FX_MAX görünür, dart isabet efekti en çok 8 aynı anda;
## fazlası gizli ama zehir mantığı (is_poisoned) bozulmaz.

const EnemyScene: PackedScene = preload("res://scenes/creatures/enemy_rat1.tscn")
const DartScene: PackedScene = preload("res://scenes/dart_projectile.tscn")
const PoisonDripFx := preload("res://scripts/poison_drip_fx.gd")

var _made: Array[Node] = []


func _cleanup() -> void:
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	for n in get_tree().get_nodes_in_group("impact_fx_fx_poison_hit.tscn"):
		n.free()


func test_poison_status_fx_is_capped_but_poison_logic_is_not() -> void:
	NetworkManager.is_multiplayer_active = false
	var enemies: Array[Node] = []
	for i in range(20):
		var e: Node = EnemyScene.instantiate()
		add_child(e)
		_made.append(e)
		enemies.append(e)
		e.call("apply_poison", 5.0, 5.0, 4.0)
	var visible_fx: int = get_tree().get_node_count_in_group(&"poison_status_fx_visible")
	assert(visible_fx == 12, "en çok 12 görünür zehir efekti: %d" % visible_fx)
	for e in enemies:
		assert(e.call("is_poisoned"), "efekt gizli olsa da zehirli sayılmalı")
	_cleanup()


## Madde 749: Zehir Asası isabeti "B - Kabarcık" sahnesi (fx_hit_kabarcik.tscn) - sahnedeki impact_max_alive (8) bütçesiyle sınırlı.
func test_dart_impact_fx_budget() -> void:
	if get_tree().current_scene == null:
		get_tree().current_scene = self
	var dart: Node = DartScene.instantiate()
	add_child(dart)
	_made.append(dart)
	for i in range(40):
		dart.call("_spawn_impact")
	assert(get_tree().get_node_count_in_group("impact_fx_fx_poison_hit.tscn") == 0, "eski zehir patlaması çıkmaz")
	var alive: int = get_tree().get_node_count_in_group("impact_fx_fx_hit_kabarcik.tscn")
	assert(alive == int(dart.get("impact_max_alive")) and alive == 8, "aynı anda en çok 8 kabarcık isabeti: %d" % alive)
	assert(get_tree().current_scene.get_node_or_null(PoisonDripFx.NODE_NAME) == null, "isabet damla / gölcük üretmez")
	for n in get_tree().get_nodes_in_group("impact_fx_fx_hit_kabarcik.tscn"):
		n.free()
	_cleanup()
