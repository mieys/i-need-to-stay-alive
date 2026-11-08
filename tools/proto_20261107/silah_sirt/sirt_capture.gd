extends SceneTree

## Silahlar SIRTTA (madde 451) GERÇEK ÇİZİCİDE: üstte yerel oyuncu (weapon.gd), altta uzak kukla (remote_player.gd), 3 silah
## (Uzunkılıç, Ateş Asası, Yay). Düşman yok -> 4 yön (önden, sağ, arkadan, sol) + yürüyüş; sonra slime -> sırttan çekiş; slime silinir ->
## kına giriş. Kareler SS_CAP_DIR'e <etiket>.png / f_<ms>.png. Koşturucu: sirt_capture.ps1 (gizli masaüstü).
## Sahneler preload EDİLMEZ: -s betiği autoload'lardan önce derlenir.

var _dir: String = OS.get_environment("SS_CAP_DIR")
var _player: Node2D = null
var _puppet: Node2D = null
var _face: String = "down"
var _walk: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		_apply_face()
		await process_frame


func _apply_face() -> void:
	var clip: String = ("walk_" if _walk else "idle_") + _face
	for n in [_player, _puppet]:
		if n == null:
			continue
		var spr: AnimatedSprite2D = n.get_node_or_null("AnimatedSprite2D")
		if spr != null and spr.sprite_frames != null and spr.sprite_frames.has_animation(clip) and spr.animation != clip:
			spr.play(clip)


func _snap(name: String) -> void:
	_apply_face()
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var c := Vector2(img.get_width(), img.get_height()) * 0.5
	var rect := Rect2i(int(c.x) - 160, int(c.y) - 250, 320, 500).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	img.get_region(rect).save_png(_dir.path_join(name + ".png"))


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
	var player: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.scale = Vector2(0.5, 0.5)
	player.z_index = 1
	scene.add_child(player)
	var p0 := Vector2(2900, 3000)
	player.global_position = p0
	player.set_physics_process(false)
	for k in ["uzunkilic", "fire_staff", "yay"]:
		player.call("buy_weapon_copy", k, 1)
	var puppet: Node2D = (load("res://scenes/remote_player.tscn") as PackedScene).instantiate()
	scene.add_child(puppet)
	puppet.setup(77, 5, "Dost")
	var q0 := p0 + Vector2(0, 70)
	puppet.call("snap_to_network_position", q0)
	puppet.call("update_weapon_visuals", ["uzunkilic", "fire_staff", "yay"], {})
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	scene.add_child(cam)
	cam.global_position = p0 + Vector2(0, 30)
	cam.make_current()
	_player = player
	_puppet = puppet
	await _wait(1.0)
	for f in ["down", "right", "up", "left"]:
		_face = f
		await _wait(0.25)
		await _snap("yon_" + f)
	_face = "down"
	_walk = true
	await _wait(0.2)
	await _snap("yuru_down")
	_walk = false
	_face = "right"
	await _wait(0.3)
	var slime: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	scene.add_child(slime)
	slime.global_position = p0 + Vector2(230, 30)
	slime.set("speed", 0.0)
	slime.max_health = 600000.0
	slime.health = 600000.0
	var t0: int = Time.get_ticks_msec()
	var freed := false
	while Time.get_ticks_msec() - t0 < 2600:
		var ms: int = Time.get_ticks_msec() - t0
		if not freed and ms > 1300:
			freed = true
			slime.queue_free()
		await _snap("f_%05d" % ms)
		await process_frame
	print("BITTI")
	quit()
