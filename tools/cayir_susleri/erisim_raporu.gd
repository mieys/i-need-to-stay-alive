extends SceneTree

## BAŞLANGIÇ ÇAYIRI SÜSLERİ (madde 383) doğrulaması: pişmiş haritada oyunun KENDİ engel kümesiyle (orman duvarı + TerrainCollision: su, bina,
## ağaç gövdesi, katı nesneler...) evin kapısından 4-komşulukla ulaşılabilen hücreleri yazar. Bake öncesi ve sonrası koşup karşılaştır
## (python tools/cayir_susleri/erisim_karsilastir.py): süslerin kendi ayak izi dışında ulaşılamaz olan hücre 0 olmalı (geçit/cep kapanmadı).
## Kullanım: Godot --headless --path . -s res://tools/cayir_susleri/erisim_raporu.gd -- <çıktı.txt>

const START := Vector2i(120, 84) ## evin kapısının önü (ev kapı 119..121 x 80..82)
const PLAY := Rect2i(0, 0, 256, 256)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "user://erisim.txt"
	var tc: GDScript = load("res://scripts/terrain_collision.gd")
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var h: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	h.name = "Harita"
	h.position = Vector2(-2, 21)
	scene.add_child(h)
	await process_frame
	var forest: TileMapLayer = h.get_node("Orman parçaları/Orman parçaları")
	tc.call("reset")
	var cells: Dictionary = tc.call("ensure", forest)
	var blocked := func(c: Vector2i) -> bool: return forest.get_cell_source_id(c) != -1 or cells.has(c)
	var seen: Dictionary = {START: true}
	var queue: Array[Vector2i] = [START]
	var i: int = 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if PLAY.has_point(n) and not seen.has(n) and not blocked.call(n):
				seen[n] = true
				queue.append(n)
	var lines := PackedStringArray()
	for c: Vector2i in seen:
		lines.append("R %d,%d" % [c.x, c.y])
	for c: Vector2i in cells:
		if PLAY.has_point(c):
			lines.append("B %d,%d" % [c.x, c.y])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
	var st: Dictionary = tc.get("stats")
	print("ERISIM start_blocked=%s reachable=%d terrain_cells=%d props=%s trees=%s" % [str(blocked.call(START)), seen.size(), cells.size(),
		str(st.get("props", "?")), str(st.get("trees", "?"))])
	quit()
