extends SceneTree

## Oakley R "Hayat Ağacı" (madde 266) GERÇEK ÇİZİCİDE: gerçek harita (harita_baked, main.tscn'deki gibi (-2, 21) ofsetle, adı "Harita"
## -> EnemyAbilities.place_on_ground çalışır), oyuncu kökü 0,5, kamera zoom 2; Oakley sağa bakıp R'yi kullanır (_skill_oakley_tree),
## yanında bir dost kuklası, çevrede gerçek slime'lar (hızı 0). Belirli anlarda ekran PNG'ye yazılır (HA_CAP_DIR).
## Kullanım (pencere açar, ~16 sn): Godot --path . --windowed --resolution 1280x720 -s tools/proto_20261018/hayat_agaci_capture.gd
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

var _dir: String = OS.get_environment("HA_CAP_DIR")
const SPOT := Vector2(3616, 2000) ## harita_renk_capture.gd "orman2": açık çayır


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join(name))
	print("SHOT ", name)


func _slime(scene: Node2D, pos: Vector2) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	scene.add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0
	return e


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 2
	gm.selected_character = 2
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var harita: Node2D = (load("res://scenes/harita_baked.tscn") as PackedScene).instantiate()
	harita.name = "Harita"
	harita.position = Vector2(-2, 21)
	scene.add_child(harita)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	scene.add_child(player)
	player.global_position = SPOT
	player.set_physics_process(false)
	player.damage_bonus = 60.0
	player.max_health = 200.0
	player.health = 90.0
	player.facing = "right"
	var ally: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(ally)
	ally.setup(77, 5, "Dost")
	ally.global_position = SPOT + Vector2(-46, 30)
	ally.set("_target_position", ally.global_position)
	for off in [Vector2(150, -20), Vector2(170, 60), Vector2(-150, -10), Vector2(-120, 90), Vector2(60, -110)]:
		_slime(scene, SPOT + off)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = SPOT + Vector2(20, -20)
	cam.make_current()
	await _wait(1.5)
	await _shot("ha_00_once.png")
	player._skill_oakley_tree()
	var tree: Node = get_first_node_in_group("oakley_trees")
	## Ağacın KENDİ saati (_t) - ilk kullanımdaki takılmalarda duvar saati kayıyordu.
	for pair in [[0.25, "ha_01_tohum.png"], [0.6, "ha_02_kucuk.png"], [1.16, "ha_03_acilis.png"], [2.3, "ha_04_kok.png"],
			[2.9, "ha_05_sarilma.png"], [6.0, "ha_06_ortasi.png"], [12.25, "ha_07_solma.png"], [12.8, "ha_08_cicek.png"]]:
		while is_instance_valid(tree) and float(tree.get("_t")) < float(pair[0]):
			await process_frame
		await _shot(str(pair[1]))
	print("BITTI")
	quit()
