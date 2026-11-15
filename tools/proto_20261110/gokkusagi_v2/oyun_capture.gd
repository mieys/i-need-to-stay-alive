extends SceneTree

## Madde 551 gerçek çizici yakalaması: Gökkuşağı Asası IŞIK SAÇILMASI (C + yıldız) + final "Lux Huzmesi" (görüş kenarına kadar, rengarenk
## halkalar, gönderiliş/bırakış). Gerçek oyuncu + gerçek silah + gerçek slime, kamera zoom 2 = 1080p oyun ölçeği. Komşu slime'ların aldığı
## hasar yazdırılır (saçılma = birincilin tik hasarının yarısı, en yakın 4). Kareler GK_CAP_DIR'e.
## Çalıştırma: tools/proto_20261110/gokkusagi_v2/oyun_run.ps1 (gizli masaüstü).

var _dir: String = OS.get_environment("GK_CAP_DIR")
var _cam: Camera2D = null
var _gm: Node = null ## -s betiği autoload'lardan önce derlenir: GameManager adıyla erişilemez


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String, w: int, h: int, dx: int = 0) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c: Vector2 = root.get_final_transform() * (root.get_canvas_transform() * _cam.global_position)
	var rect := Rect2i(int(c.x) - w / 2 + dx, int(c.y) - h / 2, w, h)
	rect = rect.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name))
	print("SHOT %s %s" % [name, str(rect.size)])


func _slime(scene: Node2D, pos: Vector2) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	scene.add_child(e)
	e.global_position = pos
	e.set("speed", 0.0)
	e.max_health = 600000.0
	e.health = 600000.0
	return e


func _set_ench(player: Node, ench: Dictionary) -> void:
	_gm.owned_weapons[0]["enchant"] = ench
	player.call("_apply_enchant_to_weapon", 0)


func _report(tag: String, list: Array) -> void:
	var parts: Array = []
	for e in list:
		if is_instance_valid(e):
			parts.append("%.0f" % (600000.0 - float(e.get("health"))))
	print("HASAR %s %s" % [tag, " ".join(parts)])


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
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
	root.get_node("NetworkManager").set("is_multiplayer_active", false)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	scene.add_child(player)
	player.global_position = Vector2(3000, 3030)
	player.set_physics_process(false)
	if "max_health" in player:
		player.set("max_health", 100000.0)
		player.set("health", 100000.0)
	for w in player.owned_weapon_nodes.duplicate():
		if is_instance_valid(w):
			w.queue_free()
	player.owned_weapon_nodes.clear()
	_gm.owned_weapons = [{"key": "gokkusagi", "level": 1}]
	player.call("buy_weapon_copy", "gokkusagi", 1)
	_set_ench(player, {"id": "goz_kamastiran", "ups": [1, 2]})
	_cam = Camera2D.new()
	_cam.zoom = Vector2(2, 2)
	scene.add_child(_cam)
	_cam.global_position = Vector2(3090, 3000)
	_cam.make_current()
	## 1) temel: birincil + 60 px içinde 4 komşu + 80 px'te 1 dışarıda
	var prim := _slime(scene, Vector2(3120, 3020))
	var nb: Array = []
	## komşular birincilin oyuncudan uzak yanında (silah oyuncuya en yakın yaratığı hedefler)
	for off in [Vector2(30, -26), Vector2(44, 18), Vector2(14, 42), Vector2(52, -6)]:
		nb.append(_slime(scene, prim.global_position + off))
	var outside := _slime(scene, prim.global_position + Vector2(84, 26))
	var t0: int = Time.get_ticks_msec()
	for at in [0.4, 0.9, 1.7, 2.3]:
		while Time.get_ticks_msec() - t0 < int(at * 1000.0):
			await process_frame
		await _shot("temel_%04d.png" % int(at * 1000.0), 760, 380)
	_report("birincil", [prim])
	_report("komsular", nb)
	_report("disarida", [outside])
	for e in [prim, outside] + nb:
		e.queue_free()
	await _wait(0.6)
	## 2) final: hatta 4 slime + birincilin çevresinde 2 komşu; gönderiliş, halkalar, bırakış
	_set_ench(player, {"id": "goz_kamastiran", "ups": [0, 1, 2, 3], "final": true})
	var w: Node = player.owned_weapon_nodes[0]
	var tip: Vector2 = (w.get("muzzle") as Node2D).global_position if w.get("muzzle") != null else w.global_position
	var dir := Vector2(1.0, 0.12).normalized()
	_cam.global_position = Vector2(3170, 3000)
	var line: Array = []
	for d in [70.0, 140.0, 215.0, 290.0]:
		line.append(_slime(scene, tip + dir * d + Vector2(0, 8)))
	var nb2: Array = [_slime(scene, (line[0] as Node2D).global_position + Vector2(34, 30)), _slime(scene, (line[0] as Node2D).global_position + Vector2(20, -42))]
	t0 = Time.get_ticks_msec()
	for at in [0.06, 0.55, 0.8, 1.45]:
		while Time.get_ticks_msec() - t0 < int(at * 1000.0):
			await process_frame
		await _shot("final_%04d.png" % int(at * 1000.0), 1400, 420, 120)
	var bw: Node = w.get("_beam_fx")
	if bw != null and is_instance_valid(bw):
		print("FINAL uc=%.0f px  hat=%d" % [tip.distance_to(Vector2(w.get("_beam_end"))), (w.get("_beam_extra_targets") as Array).size()])
	_report("final_hat", line)
	_report("final_komsu", nb2)
	## bırakış: hedefler kalkar, ışın incelip söner
	for e in line + nb2:
		e.queue_free()
	await process_frame
	await _shot("final_birakis_a.png", 1400, 420, 120)
	await _wait(0.1)
	await _shot("final_birakis_b.png", 1400, 420, 120)
	print("BITTI")
	quit()
