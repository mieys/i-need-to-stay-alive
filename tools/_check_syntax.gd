extends SceneTree

func _init():
	var scripts := [
		"res://scripts/food_drop.gd",
		"res://scripts/enemy.gd",
		"res://scripts/network_manager.gd",
	]
	var ok := true
	for path in scripts:
		var s: GDScript = load(path)
		if s == null:
			print("FAIL to load: ", path)
			ok = false
		else:
			print("loaded OK: ", path)

	var scene: PackedScene = load("res://scenes/food_drop.tscn")
	if scene == null:
		print("FAIL to load scene: res://scenes/food_drop.tscn")
		ok = false
	else:
		var inst = scene.instantiate()
		if inst == null:
			print("FAIL to instantiate food_drop.tscn")
			ok = false
		else:
			print("instantiate OK, tier=", inst.tier)
			for t in range(1, 6):
				inst.tier = t
				inst._setup_visual()
				print("tier ", t, " heal=", inst.get_heal_amount(), " sprite_scale=", inst.sprite.scale, " tex=", inst.sprite.texture.resource_path)
			inst.free()

	print("OK" if ok else "FAILED")
	quit()
