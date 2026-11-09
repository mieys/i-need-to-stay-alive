extends SceneTree

## Üst üste binen parıltı önce/sonra yakalaması (2026-11-08). Çıktı: CAP_OUT/{gece_eski,gece_yeni,sprite}.png

var _f: int = 0
var _overlay: CanvasLayer = null
var _night: Node2D = null
var _sprites: Node2D = null
var _out: String = ""
const COUNTS := [1, 2, 3, 5]
const XS := [160.0, 480.0, 800.0, 1120.0]


func _initialize() -> void:
	_out = OS.get_environment("CAP_OUT")
	var world := Node2D.new()
	world.name = "World"
	root.add_child(world)
	current_scene = world
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.55, 0.27)
	bg.size = Vector2(1280, 720)
	world.add_child(bg)
	var strip := ColorRect.new()
	strip.color = Color(0.62, 0.55, 0.42)
	strip.position = Vector2(0, 300)
	strip.size = Vector2(1280, 120)
	world.add_child(strip)

	_night = Node2D.new()
	world.add_child(_night)
	var glow_script: GDScript = load("res://scripts/night_glow.gd")
	for i in range(COUNTS.size()):
		for k in range(COUNTS[i]):
			var host := Node2D.new()
			host.position = Vector2(XS[i] + (k - (COUNTS[i] - 1) * 0.5) * 14.0, 360.0 + (k % 2) * 10.0)
			_night.add_child(host)
			var g := Node2D.new()
			g.set_script(glow_script)
			g.set("color", Color(1.0, 0.55, 0.2))
			g.set("radius", 110.0)
			g.set("energy", 1.2)
			host.add_child(g)

	_sprites = Node2D.new()
	_sprites.visible = false
	world.add_child(_sprites)
	var soft: Material = load("res://scripts/soft_glow_blend.gd").material()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var lamp: Texture2D = load("res://assets/fx/gorev/fener_isik.png")
	var spark: Texture2D = load("res://assets/pickups/shield_orb/sparkle_t1.png")
	for row in range(2):
		var mat: Material = add if row == 0 else soft
		for i in range(COUNTS.size()):
			for k in range(COUNTS[i]):
				var off: float = (k - (COUNTS[i] - 1) * 0.5) * 10.0
				var a := Sprite2D.new()
				a.texture = lamp
				a.material = mat
				a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				a.scale = Vector2(3, 3)
				a.position = Vector2(XS[i] - 70.0 + off, 200.0 + row * 300.0)
				_sprites.add_child(a)
				var s := Sprite2D.new()
				s.texture = spark
				s.hframes = 48
				s.frame = 10
				s.material = mat
				s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				s.scale = Vector2(4, 4)
				s.position = Vector2(XS[i] + 60.0 + off, 200.0 + row * 300.0 + (k % 2) * 6.0)
				_sprites.add_child(s)

	var math: GDScript = load("res://scripts/atmosphere_math.gd")
	var best_t: float = 0.0
	var best_d: float = -1.0
	var t: float = 0.0
	while t < 600.0:
		var d: float = math.darkness(t)
		if d > best_d:
			best_d = d
			best_t = t
		t += 5.0
	_overlay = load("res://scripts/atmosphere_overlay.gd").new()
	root.add_child(_overlay)
	_night_t = best_t
	print("gece t=", best_t, " grade=", math.grade(best_t, 0.0, 0.0))


var _night_t: float = 0.0


func _set_old(old: bool) -> void:
	var m: ShaderMaterial = _overlay.get("_material")
	## Eski davranış ~ harita 1'de kırpılı (x light_gain 0,8 = 0,8 sert tavan), yumuşak tavan yok.
	m.set_shader_parameter("light_knee", 0.8 if old else 0.4)
	m.set_shader_parameter("light_ceiling", 0.8 if old else 0.56)


func _save(name: String) -> void:
	var img: Image = root.get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("kaydedildi ", name, " ", img.get_size())


func _process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		_overlay.call("apply", load("res://scripts/atmosphere_math.gd").grade(_night_t, 0.0, 0.0), false)
		_set_old(true)
	elif _f == 12:
		_save("gece_eski")
		_set_old(false)
	elif _f == 24:
		_save("gece_yeni")
		_night.visible = false
		_sprites.visible = true
		_overlay.call("apply", load("res://scripts/atmosphere_math.gd").grade(150.0, 0.0, 0.0), false)
	elif _f == 36:
		_save("sprite")
		quit(0)
	return false
