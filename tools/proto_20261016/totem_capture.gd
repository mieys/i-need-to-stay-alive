extends SceneTree

## Shaman v4 totemleri (madde 176) GERÇEK ÇİZİCİDE, oyundaki gerçek ölçekle (oyuncu kökü 0,5, kamera zoom 2) görüntü doğrulaması:
## düz çimen renginde boş sahne + Shaman + solda Saldırı Totemi (Q), sağda Kalkan Totemi (E) + Q'nun ateş edeceği bir yaratık.
## TC_CAP_DIR'e PNG yazar (oyuncu çevresinden kırpılmış): dikilme.png, bosta_1..3.png (ateş oku uçuşu yakalanabilir).
## Kullanım (pencere açar, birkaç saniye): Godot --path . -s tools/proto_20261016/totem_capture.gd   (TC_CAP_DIR ortam değişkeni)
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok (bkz. matthew_capture.gd).

var _dir: String = OS.get_environment("TC_CAP_DIR")
## TC_MODE=genis: efekt incelemesi - totemler 120 birim aralikli, alanlarinda 2'ser yaratik, genis kirpma (madde 176 efekt turu)
var _wide: bool = OS.get_environment("TC_MODE") == "genis"
var _player: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * _player.global_position)
	var half := Vector2i(560, 330) if _wide else Vector2i(300, 170)
	var rect := Rect2i(int(c.x) - half.x, int(c.y) - half.y, half.x * 2, half.y + (330 if _wide else 90)).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))
	print("SHOT %s %s" % [name, str(rect.size)])


func _totem(scene: Node, path: String, offset: Vector2) -> Node2D:
	var t: Node2D = (load(path) as PackedScene).instantiate()
	scene.add_child(t)
	if t.has_method("setup_from_player"):
		t.call("setup_from_player", _player)
	t.global_position = _player.global_position + offset
	return t


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 12
	gm.selected_character = 27
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(122, 173, 85)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	_player = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	_player.scale = Vector2(0.5, 0.5) ## main.tscn'deki gerçek ölçek
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	await _wait(0.4)
	var spots: Array = [Vector2(-150, 10)]
	if _wide:
		spots = [Vector2(-250, -60), Vector2(-190, 90), Vector2(230, -70), Vector2(190, 100)]
	for sp: Vector2 in spots:
		var e: Node2D = (load("res://scenes/creatures/enemy_agac1.tscn") as PackedScene).instantiate()
		scene.add_child(e)
		e.global_position = _player.global_position + sp
		e.set("speed", 0.0)
		e.max_health = 600000.0
		e.health = 600000.0
	var gap: float = 120.0 if _wide else 48.0
	_totem(scene, "res://scenes/totem_attack.tscn", Vector2(-gap, 4))
	_totem(scene, "res://scenes/totem_shield.tscn", Vector2(gap, 4))
	await _wait(0.15)
	await _shot("dikilme.png")
	for i in range(4 if _wide else 3):
		await _wait(0.45 if not _wide else 0.3)
		await _shot("bosta_%d.png" % (i + 1))
	print("BITTI")
	quit()
