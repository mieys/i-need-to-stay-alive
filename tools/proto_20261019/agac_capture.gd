extends SceneTree

## Ağacı Koru ağacının atışları gerçek çizicide (madde 317): ağaç + 3 sabit slime, kamera zoom 2 (1080p oyun ölçeği).
## Durum ilk görüldüğünde kare alır: kristal mermisi uçarken / sihirli atış şarjı / uçuşu / patlaması. Kareler AGAC_CAP_DIR'e.
## Çalıştırma (gizli masaüstü): powershell -ExecutionPolicy Bypass -File tools/proto_20261019/agac_run.ps1 -Label once

const TREE_POS := Vector2(3000, 3000)

var _dir: String = OS.get_environment("AGAC_CAP_DIR")
var _cam: Camera2D = null


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * _cam.global_position)
	var rect := Rect2i(int(c.x) - 500, int(c.y) - 300, 1000, 600)
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))
	print("SHOT %s %s (pencere %dx%d)" % [name, str(rect.size), img.get_width(), img.get_height()])


func _first(script_path: String, cond: Callable) -> Node:
	for n: Node in current_scene.get_children():
		var s: Script = n.get_script()
		if s != null and s.resource_path == script_path and cond.call(n):
			return n
	return null


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 152, 88)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	scene.add_child(_cam)
	_cam.global_position = TREE_POS + Vector2(100, -40)
	_cam.make_current()
	for p: Vector2 in [Vector2(230, -60), Vector2(260, 40), Vector2(170, 90)]:
		var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
		scene.add_child(e)
		e.global_position = TREE_POS + p
		e.set("speed", 0.0)
		e.set("max_health", 600000.0)
		e.set("health", 600000.0)
	await process_frame
	var tree: Node2D = (load("res://scripts/mission_tree.gd") as GDScript).new()
	scene.add_child(tree)
	tree.global_position = TREE_POS
	tree.call("setup", 1, true)
	var want := {
		"1_kristal_mermisi.png": ["res://scripts/mission_tree_bolt.gd", func(n: Node) -> bool: return float(n.get("_life")) > 0.12],
		"2_atis_sarji.png": ["res://scripts/mission_tree_blast.gd", func(n: Node) -> bool: return int(n.get("_phase")) == 0 and float(n.get("_t")) > 0.3],
		"3_atis_ucusu.png": ["res://scripts/mission_tree_blast.gd", func(n: Node) -> bool: return int(n.get("_phase")) == 1 and float(n.get("_t")) > 0.12],
		"4_atis_patlamasi.png": ["res://scripts/mission_tree_blast.gd", func(n: Node) -> bool: return int(n.get("_phase")) == 2 and float(n.get("_t")) > 0.06],
	}
	## kristal parlaması (yeni ağaçta): şarj bitip güçlü pulse anında
	if tree.get("_glow") != null:
		want["5_kristal_parlamasi.png"] = ["res://scripts/mission_tree.gd", func(n: Node) -> bool: return float(n.get("_glow").get("intensity")) > 0.9]
	var t0: int = Time.get_ticks_msec()
	while not want.is_empty() and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
		for k: String in want.keys():
			if _first(want[k][0], want[k][1]) != null:
				await _shot(k)
				want.erase(k)
				break
	print("BITTI eksik=%s" % str(want.keys()))
	quit()
