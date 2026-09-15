extends Node

func test_uzunkilic_orbit_properties() -> void:
	var weapon_scene: PackedScene = load("res://scenes/weapon_uzunkilic.tscn")
	assert(weapon_scene != null, "Uzunkilic weapon scene should exist")
	var weapon: Node2D = weapon_scene.instantiate() as Node2D
	add_child(weapon)
	
	# Simulate ready
	weapon._ready()
	
	# 1. Verify it recognizes itself as uzunkilic
	assert(weapon.get("_is_uzunkilic") == true, "Weapon should identify itself as Uzunkilic")
	
	# 2. Verify card_damage_bonus_ratio is set to 1.8
	assert(is_equal_approx(weapon.card_damage_bonus_ratio, 1.8), "card_damage_bonus_ratio should be exactly 1.8")
	
	# 3. Verify melee is set to false to bypass standard melee configurations
	assert(weapon.melee == false, "Melee should be false for orbit behavior")
	
	weapon.queue_free()


func test_uzunkilic_orbit_movement() -> void:
	var parent: Node2D = Node2D.new()
	parent.global_position = Vector2(100.0, 200.0)
	parent.scale = Vector2(1.0, 1.0)
	add_child(parent)
	
	var weapon_scene: PackedScene = load("res://scenes/weapon_uzunkilic.tscn")
	var weapon: Node2D = weapon_scene.instantiate() as Node2D
	parent.add_child(weapon)
	
	weapon._ready()
	
	# Initial angle is 0.0, which means offset should be Vector2(1, 0) * 130.0 = Vector2(130, 0)
	weapon._physics_process(0.0)
	
	# Base attack range is 115.0. Since parent scale is 1.0 and range_mult is 1.0, orbit radius is 130px
	var expected_pos: Vector2 = parent.global_position + Vector2(130.0, 0.0)
	assert(weapon.global_position.distance_to(expected_pos) < 1.0, "Weapon position should orbit at 130px radius")
	
	# Test speed reduction: 1.0 / 0.28 = ~3.5714 seconds per full rotation when fire_rate=1.0.
	# So half rotation (PI radians, opposite side) takes exactly 1.0 / (2.0 * 0.28) = 1.785714 seconds.
	weapon.fire_rate = 1.0
	weapon._physics_process(1.785714)
	
	var expected_pos_half: Vector2 = parent.global_position + Vector2(-130.0, 0.0)
	assert(weapon.global_position.distance_to(expected_pos_half) < 1.0, "Weapon position should orbit to the other side after ~1.785s when fire_rate=1.0 (with reduced speed)")
	
	# 4. Verify range-based size/orbit scaling
	weapon.attack_range = 230.0 # Double of base range (115.0)
	weapon._orbit_angle = 0.0
	weapon._physics_process(0.0) # Updates position with new range scaling
	
	var expected_pos_double_range: Vector2 = parent.global_position + Vector2(260.0, 0.0) # 130px * 2 = 260px
	assert(weapon.global_position.distance_to(expected_pos_double_range) < 1.0, "Orbit radius should double when attack_range doubles")
	assert(is_equal_approx(weapon.scale.x, 2.0), "Weapon scale should double when attack_range doubles")
	
	parent.queue_free()
