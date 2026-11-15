extends SceneTree
## Madde 597: İblis kademe yeteneklerinin gerçek çizicide görünüşü (gizli masaüstü):
##   . tools/fps_micro/hidden_launch.ps1 ; $env:IB_OUT = "<klasör>" ; Invoke-GodotHidden -Exe <godot> -ArgLine '--path . -s tools/proto_20261111/iblis_kademe/iblis_capture.gd' -WorkDir .
## Çıktı IB_OUT/iblis_kademe.png: üst sıra iblis1-3 (sağa bakan) + düz ateş topu; orta sıra Kor Yağmuru (uçuş başı / ortası / iniş / kavrulmuş zemin);
## alt sıra Alev Küreleri (açılış / 3 küre / 1 küre atıldı). Kamera zoom 2 (oyun yakınlığı).
var NovaScript: GDScript ## -s betiği otomatik yüklemelerden önce derlenir: efekt betikleri çalışma anında load()
var FireballScript: GDScript
var _root: Node2D
var _f := 0
var _enemies: Array = []
var _cam: Camera2D


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	current_scene = null
	_root = Node2D.new()
	root.add_child(_root)
	current_scene = _root
	var bg := ColorRect.new(); bg.color = Color(0.29, 0.40, 0.23); bg.size = Vector2(4000, 2000); bg.position = Vector2(-500, -500); bg.z_index = -100
	_root.add_child(bg)
	_cam = Camera2D.new(); _cam.zoom = Vector2(2, 2); _cam.position = Vector2(300, 170); _root.add_child(_cam); _cam.make_current()


func _out(name: String) -> String:
	var d: String = OS.get_environment("IB_OUT")
	return (d if d != "" else "user://") + "/" + name


func _process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		NovaScript = load("res://scripts/creature_nova.gd")
		FireballScript = load("res://scripts/enemy_fireball.gd")
		for i in 3:
			var e: Node2D = load("res://scenes/creatures/enemy_iblis%d.tscn" % (i + 1)).instantiate()
			e.position = Vector2(60 + i * 90, 40)
			_root.add_child(e)
			_enemies.append(e)
		_spawn_fx()
	if _f == 6:
		for e in _enemies:
			e.set_physics_process(false)
			e.set_process(false)
			var spr: Sprite2D = e.get_node("Sprite2D")
			spr.frame = 3 * spr.hframes ## 4. satır = sağa bakan
	if _f == 10:
		root.get_texture().get_image().save_png(_out("iblis_kademe.png"))
		quit()
	return false


func _nova(data: Dictionary, pos: Vector2, at: float) -> Node2D:
	var n := Node2D.new()
	n.set_script(NovaScript)
	n.set("data", data)
	n.set("authoritative", false)
	n.position = pos
	_root.add_child(n)
	var t: float = 0.0
	while t < at:
		n._process(1.0 / 60.0)
		t += 1.0 / 60.0
	n.set_process(false)
	return n


func _spawn_fx() -> void:
	## düz ateş topu (iblis1, ölçek karşılaştırması)
	var fb := Node2D.new()
	fb.set_script(FireballScript)
	fb.set("data", {"dir": Vector2.RIGHT, "speed": 0.0})
	fb.position = Vector2(330, 40)
	_root.add_child(fb)
	fb.set_physics_process(false)
	## Kor Yağmuru: iniş noktaları sıralı, top soldan (iblisten) gelir
	var ember := {"style": "ember", "warn": 0.8, "radius": 40.0, "from": Vector2(-110, -14)}
	_nova(ember, Vector2(140, 170), 0.12)
	_nova(ember, Vector2(290, 170), 0.45)
	_nova(ember, Vector2(440, 170), 0.86)
	_nova(ember, Vector2(560, 170), 1.6)
	## Alev Küreleri: açılış / 3 küre / 1'i atıldı - iblis3 gövdesiyle
	var orbs := {"style": "orbs", "warn": 1.3, "first": 0.9, "gap": 0.2, "count": 3}
	for i in 3:
		var e: Node2D = load("res://scenes/creatures/enemy_iblis3.tscn").instantiate()
		e.position = Vector2(140 + i * 150, 280)
		_root.add_child(e)
		_enemies.append(e)
		_nova(orbs, e.position, [0.15, 0.6, 0.98][i])
