extends SceneTree

## terrain_collision.object_groups evre evre (madde 371): object_bases / birleştirme / hücre başına sınır taraması / renk taraması ms.
## Kullanım: Godot --headless --path . -s res://tools/fps_micro/object_groups_profil.gd


func _initialize() -> void:
	_run.call_deferred()


func _us(t0: int) -> float:
	return float(Time.get_ticks_usec() - t0) / 1000.0


func _run() -> void:
	var h: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	root.add_child(h)
	await process_frame
	var tc: GDScript = load("res://scripts/terrain_collision.gd")
	var helper: Node = (load("res://scripts/depth_occluders.gd") as GDScript).new()
	for path in ["Shader Eklenecek/Derin orman nesneleri", "Orman parçaları/Orman parçaları 3", "Shader Eklenecek/Derin orman süsleri"]:
		var layer := h.get_node(path) as TileMapLayer
		for with_colors in [false, true]:
			var t0: int = Time.get_ticks_usec()
			var bases: Dictionary = helper.call("object_bases", layer)
			var t_ob: float = _us(t0)
			t0 = Time.get_ticks_usec()
			var parent: Dictionary = {}
			for c: Vector2i in bases:
				parent[c] = c
			for c: Vector2i in bases:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					var n: Vector2i = c + d
					if bases.has(n) and is_equal_approx(float(bases[n]), float(bases[c])):
						helper.call("_union", parent, c, n)
			var by_base: Dictionary = {}
			for c: Vector2i in bases:
				var r: Vector2i = helper.call("_find", parent, c)
				if not by_base.has(r):
					by_base[r] = []
				(by_base[r] as Array).append(c)
			var t_grp: float = _us(t0)
			t0 = Time.get_ticks_usec()
			var all_ms: float = 0.0
			var groups: Array = tc.call("object_groups", helper, layer, with_colors)
			all_ms = _us(t0)
			print("OG %-40s renk=%s hücre=%d | object_bases %.1f | gruplama %.1f | object_groups TOPLAM (içinde object_bases tekrar) %.1f ms, nesne %d" % [path, str(with_colors), bases.size(), t_ob, t_grp, all_ms, groups.size()])
	helper.free()
	quit()
