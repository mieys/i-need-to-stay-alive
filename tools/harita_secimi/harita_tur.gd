extends SceneTree
## HARİTA TURU (madde 449): seçili haritada (HARITA) verilen hücrelere ışınlanıp gerçek çizici görüntüsü alır.
## Kullanım: gizli masaüstünde (tools/fps_micro/hidden_launch.ps1 Invoke-GodotHidden), APPDATA yalıtılı;
##   HARITA=<id>  CAP_OUT=<png klasörü>  CAP_NOKTALAR="ad:x,y;ad2:x,y"  (hücre)  [CAP_TEKRAR=2: her noktada 0,45 sn arayla 2 görüntü - tuzak evresi]
## Çıktı <CAP_OUT>/<HARITA>_<ad>[_n].png (960x540) + "CAP <ad> ort kare" satırları.
## Zemin shader karşılaştırması: CAP_SHADERS="su_an=;A=C:/.../zemin_A.gdshader" -> her noktada her shader zemin katmanlarına (Zemin /
## Zemin ayrıntı / Zemin desen / Zemin süsü) takılıp <ad>_<shader>.png; boş yol = materyalsiz. zemin_maske (R duvar, G su) DungeonData'dan.
## CAP_TAM=1: görüntü küçültülmez (1920x1080, piksel ayrıntısı için).

var _gm: Node = null
var _out: String = OS.get_environment("CAP_OUT")
var _tag: String = OS.get_environment("HARITA")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if OS.get_environment("CAP_TAM") != "1":
		img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	img.save_png(_out.path_join(_tag + "_" + name + ".png"))


const FLOOR_LAYERS := ["Zemin", "Zemin ayrıntı", "Zemin desen", "Zemin süsü"]


## CAP_SHADERS listesi: [[ad, ShaderMaterial ya da null]]
func _floor_materials(main: Node) -> Array:
	var out: Array = []
	var spec: String = OS.get_environment("CAP_SHADERS")
	if spec == "":
		return out
	var mp: GDScript = load("res://scripts/map_profiles.gd")
	var d: Resource = mp.call("data")
	var sz: Vector2i = d.size
	var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RG8)
	var cells: PackedByteArray = d.cells
	for y in range(sz.y):
		for x in range(sz.x):
			var c: int = cells[y * sz.x + x]
			img.set_pixel(x, y, Color(1.0 if c == 1 else 0.0, 1.0 if c == 5 else 0.0, 0.0))
	var tex := ImageTexture.create_from_image(img)
	var mapn: Node2D = main.get_node_or_null("Harita") as Node2D
	for item: String in spec.split(";", false):
		var kv: PackedStringArray = item.split("=")
		if kv.size() < 2 or kv[1] == "":
			out.append([kv[0], null])
			continue
		var sh := Shader.new()
		sh.code = FileAccess.get_file_as_string(kv[1])
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("zemin_maske", tex)
		mat.set_shader_parameter("harita_origin", mapn.global_position if mapn != null else Vector2.ZERO)
		mat.set_shader_parameter("harita_hucre", Vector2(sz))
		out.append([kv[0], mat])
	return out


func _apply_floor(main: Node, mat: Material) -> void:
	var mapn: Node = main.get_node_or_null("Harita")
	if mapn == null:
		return
	for n: Node in mapn.find_children("*", "TileMapLayer", true, false):
		if FLOOR_LAYERS.has(str(n.name)):
			(n as CanvasItem).material = mat


func _run() -> void:
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 1)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(1).get("skill", 1))
	_gm.set("selected_start_weapon", "sword")
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await _wait(6.0)
	## CAP_ZEMIN_GECIS=0: zemin dünya pikseli geçişi (ground_texel_pass.gd) kapalı - zemin doğrudan çizilir (karşılaştırma)
	if OS.get_environment("CAP_ZEMIN_GECIS") == "0":
		for n: Node in get_nodes_in_group(&"ground_texel_pass"):
			n.set("enabled", false)
	## CAP_ZEMIN_ISIKSIZ=1: zemin geçişi sprite'ı ışıksız (light_mode unshaded) - çift ışık/renk uygulaması sınaması
	if OS.get_environment("CAP_ZEMIN_ISIKSIZ") == "1":
		for n: Node in get_nodes_in_group(&"ground_texel_pass"):
			var cm := (n as CanvasItem).material as CanvasItemMaterial
			if cm:
				cm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	## CAP_SAAT=<sn>: atmosfer saati (0..600; gece 390-540)
	if OS.get_environment("CAP_SAAT") != "":
		var atmo: Node = main.get_node_or_null("Atmosphere")
		if atmo:
			atmo.set("cycle_time", float(OS.get_environment("CAP_SAAT")))
	var p: Node2D = main.get_node("Player")
	var reps: int = maxi(1, int(OS.get_environment("CAP_TEKRAR")))
	var mats: Array = _floor_materials(main)
	for item: String in OS.get_environment("CAP_NOKTALAR").split(";", false):
		if not mats.is_empty():
			var kv0: PackedStringArray = item.split(":")
			var xy0: PackedStringArray = kv0[1].split(",")
			p.global_position = Vector2(float(xy0[0]) * 16.0 + 8.0, float(xy0[1]) * 16.0 + 8.0)
			p.reset_physics_interpolation()
			await _wait(2.0)
			for m: Array in mats:
				_apply_floor(main, m[1])
				await _wait(0.3)
				await _shot("%s_%s" % [kv0[0], m[0]])
			continue
		var kv: PackedStringArray = item.split(":")
		var xy: PackedStringArray = kv[1].split(",")
		p.global_position = Vector2(float(xy[0]) * 16.0 + 8.0, float(xy[1]) * 16.0 + 8.0)
		p.reset_physics_interpolation()
		var f0: int = Engine.get_process_frames()
		var u0: int = Time.get_ticks_usec()
		await _wait(2.5)
		print("CAP %s ort kare %.2f ms" % [kv[0], float(Time.get_ticks_usec() - u0) / 1000.0 / maxf(1.0, float(Engine.get_process_frames() - f0))])
		for i in range(reps):
			await _shot(kv[0] if reps == 1 else "%s_%d" % [kv[0], i])
			await _wait(0.45)
		## CAP_GIZLE="ad:Düğüm1,Düğüm2|ad2:Düğüm3": her varyantta adı eşleşen düğümler (CanvasItem/CanvasLayer) gizlenip ayrı görüntü
		## (<nokta>_<ad>.png), sonra geri açılır - görsel bir farkın hangi katmandan geldiğini ayırmak için (2026-11-08).
		for variant: String in OS.get_environment("CAP_GIZLE").split("|", false):
			var vv: PackedStringArray = variant.split(":")
			var hidden: Array = []
			for gizle_ad: String in vv[1].split(",", false):
				for n: Node in main.find_children(gizle_ad, "", true, false):
					if (n is CanvasItem or n is CanvasLayer) and n.get("visible") == true:
						n.set("visible", false)
						hidden.append(n)
			await _wait(0.4)
			await _shot("%s_%s" % [kv[0], vv[0]])
			for n: Node in hidden:
				if is_instance_valid(n):
					n.set("visible", true)
	quit(0)
