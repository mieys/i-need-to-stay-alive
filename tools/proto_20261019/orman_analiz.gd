extends SceneTree

## "Orman parçaları" katmanları derinliğe (depth_occluders OBJECT_LAYERS) katılabilir mi? Atlas komşuluğu nesneleri ağaç boyunda mı yoksa dev blok mu:
## hücre başına (kök - hücre üstü) yüksekliği ve nesne başına hücre sayısı dağılımı. headless: Godot --headless --path . -s tools/proto_20261019/orman_analiz.gd

func _initialize() -> void:
	var harita: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	root.add_child(harita)
	var dep: Node = (load("res://scripts/depth_occluders.gd") as GDScript).new()
	for path in ["Orman parçaları/Orman parçaları", "Orman parçaları/Orman parçaları 2"]:
		var layer := harita.get_node_or_null(path) as TileMapLayer
		if layer == null:
			print("YOK ", path)
			continue
		var bases: Dictionary = dep.call("object_bases", layer)
		var groups: Dictionary = {} ## kök y -> [hücre sayısı, en üst hücre y, min x, max x]
		var spans: Array[int] = [0, 0, 0, 0, 0] ## <=48, <=96, <=160, <=320, >320
		for cell: Vector2i in bases:
			var top: float = float(cell.y) * 16.0
			var span: float = float(bases[cell]) - top
			var k: int = 0 if span <= 48 else (1 if span <= 96 else (2 if span <= 160 else (3 if span <= 320 else 4)))
			spans[k] += 1
		print(path, " hucre=", layer.get_used_cells().size(), " kokleri olan=", bases.size(), " kok-hucre ustu dagilimi <=48/96/160/320/>320: ", spans)
	quit()
