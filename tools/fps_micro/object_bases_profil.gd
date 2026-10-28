extends SceneTree

## depth_occluders.object_bases evre evre (madde 371): hücre bilgisi / birleştirme / satır taraması ms - hangi katmanda neden hücre başına süre değişiyor.
## Kullanım: Godot --headless --path . -s res://tools/fps_micro/object_bases_profil.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var h: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	root.add_child(h)
	await process_frame
	var helper: Node = (load("res://scripts/depth_occluders.gd") as GDScript).new()
	for path in ["Shader Eklenecek/Ağaç 0", "Shader Eklenecek/Derin orman nesneleri", "Orman parçaları/Orman parçaları 3", "Shader Eklenecek/Derin orman süsleri", "Shader Eklenecek/Animasyonsuz çalılar"]:
		var layer := h.get_node(path) as TileMapLayer
		var t0: int = Time.get_ticks_usec()
		var cells: Array[Vector2i] = layer.get_used_cells()
		var t_cells: int = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		var info: Dictionary = {}
		for cell in cells:
			var sid: int = layer.get_cell_source_id(cell)
			var td: TileData = layer.get_cell_tile_data(cell)
			info[cell] = [sid, layer.get_cell_atlas_coords(cell), td != null and td.flip_h, td != null and td.flip_v, td != null and td.transpose]
		var t_info: int = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		var parent: Dictionary = {}
		for cell in info:
			parent[cell] = cell
		for cell: Vector2i in info:
			var a: Array = info[cell]
			var right: Vector2i = cell + Vector2i(1, 0)
			if info.has(right):
				var b: Array = info[right]
				var want: Vector2i = a[1] + (Vector2i(-1, 0) if a[2] else Vector2i(1, 0))
				if b[0] == a[0] and b[2] == a[2] and b[1] == want:
					helper.call("_union", parent, cell, right)
			var down: Vector2i = cell + Vector2i(0, 1)
			if info.has(down):
				var c: Array = info[down]
				if c[0] == a[0] and c[2] == a[2] and c[1] == a[1] + Vector2i(0, 1):
					helper.call("_union", parent, cell, down)
		var t_union: int = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		var uniq: Dictionary = {}
		for cell: Vector2i in info:
			var inf: Array = info[cell]
			helper.call("_tile_rows_of", layer, inf[0], inf[1], inf[3], inf[4])
			uniq[Vector3i(inf[0], inf[1].x, inf[1].y)] = true
		var t_rows: int = Time.get_ticks_usec() - t0
		t0 = Time.get_ticks_usec()
		helper.call("object_bases", layer)
		var t_total: int = Time.get_ticks_usec() - t0
		print("OB %-40s hücre=%d tekil karo=%d | get_used_cells %.1f | hücre bilgisi %.1f | birleştirme %.1f | satır taraması %.1f | object_bases (sıcak) %.1f ms" % [
			path, cells.size(), uniq.size(), t_cells / 1000.0, t_info / 1000.0, t_union / 1000.0, t_rows / 1000.0, t_total / 1000.0])
	helper.free()
	quit()
