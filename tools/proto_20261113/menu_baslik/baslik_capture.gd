extends SceneTree

## Ana menü başlığı (TitleSign) prototip yakalama (2026-11-13, oyuna bağlı DEĞİL). Kullanıcı: "şu bölümü ai kullanmadan daha iyi hale getirir misin".
## Gerçek main_menu.tscn açılır; her varyant TitleSign düğümünü değiştirir, tam ekran 1920x1080 + başlık kırpıntısı kaydedilir.
## MB_VARIANTS = "simdi,A,B,C" ; çıktı MB_OUT. Koşturucu baslik_run.ps1 (gizli masaüstü).

const CROP := Rect2i(0, 0, 1000, 420)

var _dir: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_dir.path_join(name + "_tam.png"))
	img.get_region(CROP).save_png(_dir.path_join(name + ".png"))
	print("MB SHOT %s %s" % [name, str(img.get_size())])


func _run() -> void:
	await process_frame
	_dir = OS.get_environment("MB_OUT")
	if _dir == "":
		_dir = ProjectSettings.globalize_path("res://tools/proto_20261113/menu_baslik/out")
	DirAccess.make_dir_recursive_absolute(_dir)
	AudioServer.set_bus_mute(0, true)
	var variants: PackedStringArray = OS.get_environment("MB_VARIANTS").split(",", false)
	if variants.is_empty():
		variants = PackedStringArray(["simdi"])
	## "yukleme": gerçek yükleme ekranı (main.tscn yüklenirken), 1 sn sonra tam ekran. Yalnız başına verilir.
	if variants[0] == "yukleme":
		change_scene_to_file("res://scenes/loading_screen.tscn")
		await _wait(1.0)
		await RenderingServer.frame_post_draw
		var li: Image = root.get_texture().get_image()
		li.convert(Image.FORMAT_RGB8)
		li.save_png(_dir.path_join("yukleme_tam.png"))
		print("MB SHOT yukleme %s" % str(li.get_size()))
		quit(0)
		return
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _wait(2.5)
	var menu: Node = current_scene
	var sign: Control = menu.find_child("TitleSign", true, false) as Control
	if sign != null:
		print("MB sign pos=%s size=%s" % [str(sign.global_position), str(sign.size)])
		for c in sign.find_children("*", "Control", true, false):
			print("MB   %s %s pos=%s size=%s" % [c.name, c.get_class(), str((c as Control).global_position), str((c as Control).size)])
	for v: String in variants:
		if v == "anim":
			## Harf dalgası: 2,6 sn'lik bir tur boyunca 26 kare (0,1 sn aralık), yalnız logo bölgesi -> anim_NN.png (GIF'e çevrilir).
			for n in 26:
				await RenderingServer.frame_post_draw
				var ai: Image = root.get_texture().get_image()
				ai.convert(Image.FORMAT_RGB8)
				ai.get_region(Rect2i(0, 60, 900, 300)).save_png(_dir.path_join("anim_%02d.png" % n))
				await _wait(0.1)
			print("MB SHOT anim 26")
			continue
		if v != "simdi":
			var builder: Script = load("res://tools/proto_20261113/menu_baslik/baslik_proto.gd")
			if sign != null:
				sign.visible = false
			for old in menu.get_children():
				if old.name.begins_with("ProtoSign"):
					old.queue_free()
			await process_frame
			var node: Control = builder.build(v, menu)
			node.name = "ProtoSign_" + v
			menu.add_child(node)
			await _wait(0.6)
		await _shot(v)
	quit(0)
