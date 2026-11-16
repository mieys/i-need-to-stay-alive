extends SceneTree

## Ruhani efektlerin OYUN İÇİ doğrulaması (madde 734): gerçek main.tscn, ana harita, gerçek efekt sahneleri/betikleri oyuncuya
## takılır (yetenek mekaniği çalıştırılmaz). Kalkan Bağı için sahte partner ("remote_players" grubunda, peer_id 5).
## Kullanım: powershell -ExecutionPolicy Bypass -File tools/proto_20261116/ruhani_fx/oyun_run.ps1  (çıktı out_oyun/*.png)

var _dir: String = ""
var _main: Node = null
var _player: Node2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _shot(name: String, center: Vector2, size: Vector2 = Vector2(560, 360)) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var ratio: float = float(img.get_width()) / root.get_visible_rect().size.x
	var sp: Vector2 = (_player.get_viewport().get_canvas_transform() * center) * ratio
	var sz: Vector2 = size * ratio
	var r := Rect2i(Vector2i(sp - sz * 0.5), Vector2i(sz))
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(r).save_png(_dir.path_join(name + ".png"))
	print("SHOT ", name, " ratio=", ratio)


func _hide_hud() -> void:
	for n in _all(root):
		if n is CanvasLayer:
			var cl := n as CanvasLayer
			if cl.layer >= 5 and String(cl.name) != "VignetteOverlay" or cl.name == "HUD":
				cl.visible = false
				cl.offset = Vector2(100000, 100000)
	for nm in ["HouseInterior", "TravelingMerchant"]:
		var h: Node = _main.get_node_or_null(nm)
		if h:
			h.set_process(false)


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _run() -> void:
	await process_frame
	_dir = OS.get_environment("RF_DIR")
	AudioServer.set_bus_mute(0, true)
	root.get_node("NetworkManager").call("disconnect_from_room")
	root.get_node("UISound").set("show_fps", false)
	var gm: Node = root.get_node("GameManager")
	gm.call("reset")
	gm.set("selected_char_id", 2)
	gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).call("get_def", 2).get("skill", 1))
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	_main = current_scene
	var sp: Node = _main.get_node_or_null("EnemySpawner")
	if sp:
		sp.set("_spawn_timer", 1.0e9)
		sp.set_process(false)
		sp.set_physics_process(false)
	await _wait(2.5)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	_player = _main.get_node("Player") as Node2D
	_player.set_physics_process(false)
	_player.global_position = Vector2(1850.0, 2250.0)
	_player.set("is_indoors", false)
	_hide_hud()
	_player.set("item_shield_hp", _player.get("item_shield_max")) ## kalkan dolu: "yenileniyor" balonu efektleri örtmesin
	var sv: Variant = _player.get("shield_visual")
	if sv is CanvasItem:
		(sv as CanvasItem).visible = false
		(sv as CanvasItem).modulate.a = 0.0
	await _wait(1.5)
	var P: Vector2 = _player.global_position
	var body: Vector2 = P + Vector2(0, 0)

	## ---- Can
	var fx: Node = (load("res://scenes/fx_spirit_can.tscn") as PackedScene).instantiate()
	_player.add_child(fx)
	for s in [[0.10, "can_1"], [0.25, "can_2"], [0.35, "can_3"], [1.3, "can_4"]]:
		await _wait(float(s[0]))
		await _shot(s[1], body + Vector2(0, -25))
	await _wait(2.5)

	## ---- Adc
	fx = (load("res://scenes/fx_spirit_adc.tscn") as PackedScene).instantiate()
	_player.add_child(fx)
	for s in [[0.12, "adc_1"], [0.5, "adc_2"], [0.4, "adc_3"]]:
		await _wait(float(s[0]))
		await _shot(s[1], body)
	fx.queue_free()
	await _wait(0.3)

	## ---- Tank
	fx = (load("res://scenes/fx_spirit_tank.tscn") as PackedScene).instantiate()
	_player.add_child(fx)
	await _wait(0.15)
	await _shot("tank_1", body)
	await _wait(0.6)
	await _shot("tank_2", body)
	fx.call("zap", P + Vector2(-42, 8))
	await _wait(0.06)
	await _shot("tank_3", body)
	fx.call("zap", P + Vector2(40, -2))
	await _wait(0.14)
	await _shot("tank_4", body)
	fx.queue_free()
	await _wait(0.3)

	## ---- Taktiksel (ışınlanma: kalkıştan 230 sağa)
	var from: Vector2 = P
	var to: Vector2 = P + Vector2(230, 0)
	_player.global_position = to
	_player.call("_spirit_blink_fx", "streak", from, to)
	var mid: Vector2 = (from + to) * 0.5
	for s in [[0.03, "tak_1"], [0.1, "tak_2"], [0.12, "tak_3"]]:
		await _wait(float(s[0]))
		await _shot(s[1], mid, Vector2(760, 300))
	fx = (load("res://scenes/fx_spirit_taktik.tscn") as PackedScene).instantiate()
	_player.add_child(fx)
	var t1: int = Time.get_ticks_msec()
	var shots: Array = [[0.45, "tak_4"], [0.9, "tak_5"]]
	var last: int = t1
	while not shots.is_empty():
		await process_frame
		var now: int = Time.get_ticks_msec()
		var dt: float = float(now - last) / 1000.0
		last = now
		_player.set("velocity", Vector2(-107.0, 0.0))
		_player.global_position += Vector2(-107.0, 0.0) * dt
		if float(now - t1) / 1000.0 >= float(shots[0][0]):
			await _shot(shots[0][1], _player.global_position + Vector2(30, 0), Vector2(400, 260))
			shots.pop_front()
	_player.set("velocity", Vector2.ZERO)
	fx.queue_free()
	_player.global_position = P
	await _wait(0.5)

	## ---- Kalkan Bağı (sahte partner)
	var scr := GDScript.new()
	scr.source_code = "extends Node2D\nvar peer_id: int = 5\nvar _kalkan_bagi_partner_peer_id: int = 0\nvar anim: AnimatedSprite2D = null\n"
	scr.reload()
	var partner := Node2D.new()
	partner.set_script(scr)
	partner.scale = _player.scale
	var a2: AnimatedSprite2D = (_player.get("anim") as AnimatedSprite2D).duplicate() as AnimatedSprite2D
	partner.add_child(a2)
	partner.set("anim", a2)
	a2.flip_h = true
	_player.get_parent().add_child(partner)
	partner.add_to_group("remote_players")
	partner.global_position = P + Vector2(124, -12)
	_player.set("_kalkan_bagi_partner_peer_id", 5)
	_player.call("_ensure_kalkan_bagi_link_fx")
	var link: Node = _player.get("_kalkan_bagi_link_fx")
	var kmid: Vector2 = P + Vector2(62, -10)
	await _wait(0.1)
	await _shot("kb_1", kmid, Vector2(460, 240))
	await _wait(0.6)
	await _shot("kb_2", kmid, Vector2(460, 240))
	var owner_pid: int = int(link.call("_owner_peer_id"))
	print("KB owner_pid=", owner_pid, " partner_pos=", link.call("_partner_local_pos"))
	link.call("pulse_from", owner_pid)
	await _wait(0.2)
	await _shot("kb_3", kmid, Vector2(460, 240))
	await _wait(0.3)
	await _shot("kb_4", kmid, Vector2(460, 240))
	link.call("pulse_from", 5)
	await _wait(0.45)
	await _shot("kb_5", kmid, Vector2(460, 240))
	print("SHOT bitti")
	quit(0)
