extends SceneTree

## HÜCUM takibi (madde 247) GERÇEK ÇİZİCİDE, oyundaki ölçekte (oyuncu kökü 0,5, kamera zoom 2):
##   üstte yerel oyuncu (weapon.gd), altta uzak kukla (remote_player.gd, aynı kural, ağ verisi yok); 3 silah: Uzunkılıç (kademe 5 ->
##   uç parıltısı), Ateş Asası, Tabanca. Akış: düşman yok (gizli) -> sağda slime görüşe girer (çıkış) -> sağa yürü (hücum, ardıl
##   görüntü, uç gidiş yönüne) -> dur (hazır + kademe 5 parıltısı) -> sola yürü -> slime silinir (grace sonrası içe çekilme).
## Kareler BC_CAP_DIR'e f_<ms>.png. Kullanım (pencere açar, ~7 sn): Godot --path . -s tools/proto_20261017/hucum_capture.gd
## Sahneler preload EDİLMEZ: -s betiği derlenirken autoload'lar henüz yok - _run'da load edilir.

var _dir: String = OS.get_environment("BC_CAP_DIR")
var _vx: float = 0.0 ## yürüyüş hızı: oyundaki gibi FİZİK karesinde uygulanır (çizim karesinde kaydırmak hız yayını kesik kesik besliyordu)
var _player: Node2D = null
var _puppet: Node2D = null


func _on_physics() -> void:
	if _player == null or _vx == 0.0:
		return
	var step := Vector2(_vx / float(Engine.physics_ticks_per_second), 0.0)
	_player.global_position += step
	_puppet.set("_target_position", (_puppet.get("_target_position") as Vector2) + step)


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


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
	gm.selected_char_id = 5
	gm.selected_character = 16
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var bg := ColorRect.new()
	bg.color = Color8(108, 152, 88)
	bg.size = Vector2(8000, 8000)
	bg.position = Vector2(-1000, -1000)
	bg.z_index = -10
	scene.add_child(bg)
	## zemin referansı: yürüyüş görünsün diye seyrek koyu çimen lekeleri
	for i in 140:
		var d := ColorRect.new()
		d.color = Color8(92, 136, 76)
		d.size = Vector2(6, 3)
		d.position = Vector2(2700 + (i * 37) % 700, 2850 + (i * 53) % 420)
		d.z_index = -9
		scene.add_child(d)
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	player.z_index = 1
	scene.add_child(player)
	var p0 := Vector2(2900, 3000)
	player.global_position = p0
	player.set_physics_process(false)
	for k in ["uzunkilic", "fire_staff", "tabanca"]:
		player.call("buy_weapon_copy", k, 1)
	await process_frame
	for w in player.get("owned_weapon_nodes"):
		if str(w.get_meta("shop_key", "")) == "uzunkilic" or str(w.name).containsn("uzun"):
			w.set("enchant_glow_tier", 5)
			w.call("_apply_tier_art", 5)
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(puppet)
	puppet.setup(77, 5, "Dost")
	var q0 := p0 + Vector2(0, 150)
	puppet.call("snap_to_network_position", q0)
	puppet.call("update_weapon_visuals", ["uzunkilic", "fire_staff", "tabanca"], {})
	puppet.call("_apply_enchant_glows", [5, 0, 0])
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = p0 + Vector2(90, 20)
	_player = player
	_puppet = puppet
	physics_frame.connect(_on_physics)
	cam.make_current()
	await _wait(0.6)
	var slime: Node2D = null
	var spawned := false ## (silinmiş nesne == null true döner - bayrak ayrı)
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6600:
		var now: int = Time.get_ticks_msec()
		var ms: int = now - t0
		if not spawned and ms > 700:
			spawned = true
			slime = _slime(scene, p0 + Vector2(300, 50))
		_vx = 0.0
		if ms > 1500 and ms < 2700:
			_vx = 82.0
		elif ms > 3500 and ms < 4000: ## hızlı koşu (atılma gibi): ardıl görüntü burada belirginleşir
			_vx = -220.0
		if ms > 4400 and is_instance_valid(slime):
			slime.queue_free() ## görüşte düşman kalmadı -> grace (0,6 sn) sonra içe çekilme
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var c := Vector2(img.get_width(), img.get_height()) * 0.5
		var rect := Rect2i(int(c.x) - 400, int(c.y) - 300, 800, 600).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
		img.get_region(rect).save_png(_dir.path_join("f_%05d.png" % ms))
		await process_frame
	print("BITTI")
	quit()
