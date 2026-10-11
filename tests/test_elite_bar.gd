extends Node

## Elit can/kalkan barı (scripts/elite_bar.gd, 2026-10-11): değerleri yaratıktan okur, kalkansız yaratıkta kalkan şeridi yok, ölünce kendini siler.
## make_elite()'in barı eklediği test_elite_pool_and_bosses_off.gd'de (EliteBar) sınanır.

const BarScript: GDScript = preload("res://scripts/elite_bar.gd")


class MockEnemy extends Node2D:
	var max_health: float = 1000.0
	var health: float = 1000.0
	var item_shield_hp: float = 0.0
	var item_shield_max: float = 0.0
	var is_dead: bool = false
	var is_ability_invisible: bool = false


func test_bar_follows_health_and_shield_and_frees_on_death() -> void:
	var e := MockEnemy.new()
	add_child(e)
	var bar: Node2D = BarScript.new()
	e.add_child(bar)
	bar.setup(e, -40.0)
	assert(bar.get("_has_shield") == false, "kalkansız yaratıkta kalkan şeridi olmamalı")
	e.health = 500.0
	e.item_shield_max = 200.0
	e.item_shield_hp = 50.0
	bar._process(0.016)
	assert(absf(float(bar.get("_hp")) - 0.5) < 0.001, "can oranı: %s" % str(bar.get("_hp")))
	assert(bar.get("_has_shield") == true and absf(float(bar.get("_sh")) - 0.25) < 0.001, "kalkan oranı")
	e.is_ability_invisible = true
	bar._process(0.016)
	assert(not bar.visible, "görünmez yaratıkta çubuk gizlenmeli")
	e.is_dead = true
	bar._process(0.016)
	assert(bar.is_queued_for_deletion(), "yaratık ölünce çubuk silinmeli")
	e.free()
