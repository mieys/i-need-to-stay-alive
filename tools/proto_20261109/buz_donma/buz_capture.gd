extends SceneTree
## Buz donma efektinin yaratık bedenine oturuşu (madde 544). Gerçek çizici, gizli masaüstü.
const IDS := ["slime1", "rat2", "zombie1", "iskelet2", "ork2", "lich2", "agac1", "golem2", "demon3", "ucansetan1", "sandworm1", "yarasa1"]
var _root: Node2D
var _f := 0
var _enemies: Array = []
var _t_freeze := -1.0

func _initialize() -> void:
	root.size = Vector2i(1440, 520)
	current_scene = null
	_root = Node2D.new()
	root.add_child(_root)
	current_scene = _root
	var bg := ColorRect.new(); bg.color = Color(0.25, 0.36, 0.2); bg.size = Vector2(3000, 1200); bg.position = Vector2(-50, -50); bg.z_index = -100
	_root.add_child(bg)
	var cam := Camera2D.new(); cam.zoom = Vector2(2, 2); cam.position = Vector2(360, 130); _root.add_child(cam); cam.make_current()

func _process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		for i in IDS.size():
			var e: Node2D = load("res://scenes/creatures/enemy_%s.tscn" % IDS[i]).instantiate()
			e.position = Vector2(40 + (i % 6) * 120, 60 + (i / 6) * 150)
			_root.add_child(e)
			_enemies.append(e)
	if _f == 8:
		_t_freeze = Time.get_ticks_msec() / 1000.0
		for e in _enemies:
			e.set_physics_process(false)
			var t0 := Time.get_ticks_usec()
			e._spawn_freeze_status_fx(30.0)
			var st: String = OS.get_environment("BUZ_STYLE") ## 0 = düz dip (eski), boş = solan dip
			if st == "0":
				e._freeze_status_fx.material = null
			print("buz ", e.name, " us=", Time.get_ticks_usec() - t0, " sc=", e._freeze_status_fx.scale, " pos=", e._freeze_status_fx.position)
	if _t_freeze > 0.0 and Time.get_ticks_msec() / 1000.0 - _t_freeze > float(OS.get_environment("BUZ_T") if OS.get_environment("BUZ_T") != "" else "2.0"):
		root.get_texture().get_image().save_png(OS.get_environment("BUZ_OUT"))
		quit()
	return false
