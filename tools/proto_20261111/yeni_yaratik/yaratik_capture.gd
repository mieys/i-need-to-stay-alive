extends SceneTree
## Madde 575: yeni havuzun (Goblin/Gnoll/Kertenkele Adam/Pelte x 3) gerçek çizicide görünüşü + yeni yetenek efektleri. Gizli masaüstünde:
##   . tools/fps_micro/hidden_launch.ps1 ; Invoke-GodotHidden -Exe <godot> -ArgLine '--path . -s tools/proto_20261111/yeni_yaratik/yaratik_capture.gd' ...
## YY_OUT = çıktı klasörü (yaratiklar.png: 12 yaratık + ölçek için ork2/iskelet1, sağa bakan; efektler.png: 8 efekt anı).
const IDS := ["goblin1", "goblin2", "goblin3", "ork2", "gnoll1", "gnoll2", "gnoll3", "iskelet1",
	"kertenkele1", "kertenkele2", "kertenkele3", "zombie1", "pelte1", "pelte2", "pelte3", "slime2"]
var ShotScript: GDScript ## -s betiği otomatik yüklemelerden önce derlenir: efekt betikleri çalışma anında load()
var NovaScript: GDScript
var _root: Node2D
var _f := 0
var _enemies: Array = []
var _cam: Camera2D


func _initialize() -> void:
	root.size = Vector2i(1280, 640)
	current_scene = null
	_root = Node2D.new()
	root.add_child(_root)
	current_scene = _root
	var bg := ColorRect.new(); bg.color = Color(0.29, 0.40, 0.23); bg.size = Vector2(4000, 2000); bg.position = Vector2(-500, -500); bg.z_index = -100
	_root.add_child(bg)
	_cam = Camera2D.new(); _cam.zoom = Vector2(2, 2); _cam.position = Vector2(300, 150); _root.add_child(_cam); _cam.make_current()


func _out(name: String) -> String:
	var d: String = OS.get_environment("YY_OUT")
	return (d if d != "" else "user://") + "/" + name


func _process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		for i in IDS.size():
			var e: Node2D = load("res://scenes/creatures/enemy_%s.tscn" % IDS[i]).instantiate()
			e.position = Vector2(30 + (i % 8) * 76, 50 + (i / 8) * 90 + (0 if i < 8 else 0))
			if i >= 8:
				e.position.y += 0
			_root.add_child(e)
			_enemies.append(e)
	if _f == 6:
		for e in _enemies:
			e.set_physics_process(false)
			var spr: Sprite2D = e.get_node("Sprite2D")
			spr.frame = 3 * spr.hframes ## 4. satır = sağa bakan, 0. kare
	if _f == 10:
		root.get_texture().get_image().save_png(_out("yaratiklar.png"))
		for e in _enemies:
			e.queue_free()
		_cam.position = Vector2(300, 140)
	if _f == 14:
		_spawn_fx()
	if _f == 20:
		root.get_texture().get_image().save_png(_out("efektler.png"))
		quit()
	return false


func _nova(style: String, pos: Vector2, warn: float, radius: float, at: float) -> void:
	var n := Node2D.new()
	n.set_script(NovaScript)
	n.set("data", {"style": style, "warn": warn, "radius": radius})
	n.set("authoritative", false)
	n.position = pos
	_root.add_child(n)
	var t: float = 0.0
	while t < at:
		n._process(1.0 / 60.0)
		t += 1.0 / 60.0
	n.set_process(false)


func _shot(style: String, pos: Vector2, dir: Vector2) -> void:
	var s := Node2D.new()
	s.set_script(ShotScript)
	s.set("data", {"style": style, "dir": dir, "speed": 0.0})
	s.position = pos
	_root.add_child(s)
	s.set_physics_process(false)


func _spawn_fx() -> void:
	ShotScript = load("res://scripts/creature_shot.gd")
	NovaScript = load("res://scripts/creature_nova.gd")
	## üst sıra: uyarı halkaları + patlamalar; alt sıra: mermiler ve uluma
	_nova("scythe", Vector2(40, 70), 0.6, 80.0, 0.3) ## uyarı
	_nova("scythe", Vector2(200, 70), 0.0, 80.0, 0.16) ## savuruş
	_nova("fire", Vector2(360, 70), 0.0, 68.0, 0.25) ## alev halkası
	_nova("fuse", Vector2(510, 70), 0.8, 66.0, 0.5) ## fitil
	_nova("blast", Vector2(80, 220), 0.0, 66.0, 0.2) ## bomba patlaması
	_nova("howl", Vector2(230, 220), 0.0, 140.0, 0.3) ## uluma
	_shot("spear", Vector2(380, 200), Vector2.RIGHT)
	_shot("spit", Vector2(380, 225), Vector2.RIGHT)
	for i in 6:
		_shot("crystal", Vector2(520, 215) + Vector2.from_angle(i * TAU / 6.0) * 22.0, Vector2.from_angle(i * TAU / 6.0))
