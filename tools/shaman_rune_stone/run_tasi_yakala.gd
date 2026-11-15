extends SceneTree

## Rün taşları (madde 557) GERÇEK ÇİZİCİDE, oyun ölçeğinde (oyuncu kökü 0,5, oyuncu kamerası): Shaman ortada, solda iki Q taşı
## (evrimsiz / tüm evrimler), sağda iki E taşı (evrimsiz / tüm evrimler), en solda Q'nun ateş ettiği yaratık; E dalgaları Shaman'a gider.
## Taşlar ağ kopyası kipinde (mark_as_network_visual): yalnız görsel atış/dalga, hasar yok; sahibi sahte (has_evo sözlüğü).
## RT_CAP_DIR'e kare_NNN.png yazar (oyuncu çevresinden kırpılmış). Kullanım: Godot --path . -s tools/shaman_rune_stone/run_tasi_yakala.gd
## (gizli masaüstünde: tools/fps_micro/hidden_launch.ps1). GIF: tools/shaman_rune_stone/yakala_gif.py

var _dir: String = OS.get_environment("RT_CAP_DIR")
var _player: Node2D = null


class FakeCaster extends Node2D:
	var evos: Dictionary = {}

	func has_evo(evo_id: String) -> bool:
		return evos.has(evo_id)

	func is_safe_zone_frozen() -> bool:
		return false


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
	var half := Vector2i(330, 110)
	var rect := Rect2i(int(c.x) - half.x, int(c.y) - half.y - 20, half.x * 2, half.y * 2).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))


func _totem(scene: Node, path: String, offset: Vector2, evos: Array) -> Node2D:
	var fc := FakeCaster.new()
	scene.add_child(fc)
	for e in evos:
		fc.evos[e] = true
	var t: Node2D = (load(path) as PackedScene).instantiate()
	scene.add_child(t)
	t.set("caster", fc)
	t.call("mark_as_network_visual")
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
	_player.scale = Vector2(0.5, 0.5)
	scene.add_child(_player)
	_player.global_position = Vector2(3000, 3000)
	_player.set_physics_process(false)
	await _wait(0.4)
	var e: Node2D = (load("res://scenes/creatures/enemy_agac1.tscn") as PackedScene).instantiate()
	scene.add_child(e)
	e.global_position = _player.global_position + Vector2(-250, 0)
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0
	var all_q: Array = ["shaman_q1", "shaman_q2", "shaman_q3", "shaman_q4", "shaman_qf"]
	var all_e: Array = ["shaman_e1", "shaman_e2", "shaman_e3", "shaman_e4", "shaman_ef"]
	_totem(scene, "res://scenes/totem_attack.tscn", Vector2(-110, 4), [])
	_totem(scene, "res://scenes/totem_attack.tscn", Vector2(-55, 4), all_q)
	_totem(scene, "res://scenes/totem_shield.tscn", Vector2(55, 4), [])
	_totem(scene, "res://scenes/totem_shield.tscn", Vector2(110, 4), all_e)
	for i in range(90):
		await _wait(0.1)
		await _shot("kare_%03d.png" % i)
	print("BITTI")
	quit()
