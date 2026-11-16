extends SceneTree
## PANEL DOKUSU 3. set - DİĞER MENÜLER (2026-11-16, kullanıcı: "diğer menülerde de göster örnekleri"). Oyunun kendi ekranları; yalnız
## pixel_box.gd `grain_tex` karo geçici değişir, her varyantta ekran yeniden açılır (kutular yeni karoyla çizilsin).
## Dokulu pencere zemini olan ekranlar: oyun dışı dünya haritası; oyun içi (gerçek SP main.tscn) level pazarı + oyun sonu tablosu.
## (Ruh Mağazası / Rekorlar / Ayarlar / duraklatma panelsiz "Ateş Işığı" tasarımı: dokulu kutu YOK, n=0 ölçüldü.) Her çekimde dokulu kutuları sayar: "GRAIN <çekim> n=<adet> big=<x,y,w,h>" (en büyük kutu -> ozet_diger.py kırpar).
## CAP_SET varyantlar, CAP_PART "dis" / "ic" / "dis,ic". Çıktı CAP_OUT/diger/<varyant>_<ekran>.png. Çalıştır: run.ps1 -Script doku3_diger_capture.gd

const PB_PATH := "res://scripts/pixel_box.gd"
var _out: String = OS.get_environment("CAP_OUT").path_join("diger")
var _tiles: String = OS.get_environment("CAP_TILES")
var _pb: GDScript = null
var _orig: Texture2D = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _set_variant(v: String) -> void:
	if v == "simdi":
		_pb.set("grain_tex", _orig)
	else:
		_pb.set("grain_tex", ImageTexture.create_from_image(Image.load_from_file(_tiles.path_join(v + "_x3.png"))))


## Görünür dokulu kutular (PixelBox stil kutusu, grain_applies) - en büyüğü kırpıntı için.
func _grain_report(shot: String) -> void:
	var n := 0
	var best := Rect2()
	for node: Node in root.find_children("*", "Control", true, false):
		var c := node as Control
		if not c.is_visible_in_tree():
			continue
		for key: String in ["panel", "normal"]:
			if not c.has_theme_stylebox(key):
				continue
			var sb: StyleBox = c.get_theme_stylebox(key)
			if sb == null or sb.get_script() != _pb or not bool(sb.get("grain")):
				continue
			var r: Rect2 = c.get_global_rect()
			if not bool(_pb.call("grain_applies", sb.get("bg_color"), r.size)):
				continue
			n += 1
			if r.get_area() > best.get_area():
				best = r
			break
	print("GRAIN %s n=%d big=%d,%d,%d,%d" % [shot, n, best.position.x, best.position.y, best.size.x, best.size.y])


func _shot(v: String, screen: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	var name := "%s_%s" % [v, screen]
	img.save_png(_out.path_join(name + ".png"))
	_grain_report(name)
	print("SHOT ", name)


func _child_with_script(parent: Node, suffix: String) -> Node:
	for c: Node in parent.get_children():
		var s: Script = c.get_script()
		if s and s.resource_path.ends_with(suffix):
			return c
	return null


func _run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(_out)
	AudioServer.set_bus_mute(0, true)
	_pb = load(PB_PATH)
	_orig = _pb.get("grain_tex")
	var variants: PackedStringArray = OS.get_environment("CAP_SET").split(",", false)
	var parts: String = OS.get_environment("CAP_PART")
	(load("res://scripts/meta_progress.gd") as GDScript).call("set_unlock_all", true)
	if parts.contains("dis"):
		for v: String in variants:
			_set_variant(v)
			change_scene_to_file("res://scenes/character_select.tscn")
			await _wait(2.5)
			if int(current_scene.get("selected_char")) < 0:
				current_scene.set("selected_char", 1)
			current_scene.call("_on_start_pressed")
			await _wait(1.5)
			await _shot(v, "dunya_haritasi")
	if parts.contains("ic"):
		await _ingame(variants)
	quit(0)


func _ingame(variants: PackedStringArray) -> void:
	var GM: Node = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	root.get_node("UISound").set("show_fps", false)
	GM.call("reset")
	GM.set("selected_char_id", 2)
	GM.set("selected_character", (load("res://scripts/characters.gd") as GDScript).call("get_def", 2).get("skill", 1))
	GM.set("selected_start_weapon", "uzunkilic")
	GM.set("selected_pet", "kirpi")
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var main: Node = current_scene
	var house: Node = main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	for n in main.find_children("*", "", true, false):
		var s: Script = n.get_script()
		if s and s.resource_path.ends_with("house_intro.gd"):
			n.set_process(false)
	await _wait(2.0)
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var p: Node2D = main.get_node_or_null("Player") as Node2D
	GM.gold = 1480
	for key: String in ["kanli_yakut", "ceviklik_yuzugu"]:
		p.call("buy_item", key)
	p.set("level", 13)
	var MarketScreenScript: GDScript = load("res://scripts/level_market_screen.gd")
	for v: String in variants:
		_set_variant(v)
		paused = true
		var screen: CanvasLayer = MarketScreenScript.new()
		screen.set("player_ref", p)
		screen.set("level", 13)
		screen.set("offers", {"items": [{"type": "shield", "key": "shield_savas"}, {"type": "item", "key": "kan_kapani"}], "upgrades": []})
		main.add_child(screen)
		await _wait(1.0)
		var view: Control = screen.get("view")
		if view:
			view.call("_select", "items", 1)
			await _wait(0.5)
		await _shot(v, "level_pazari")
		screen.queue_free()
		paused = false
		await _wait(0.4)
		main.call("_show_death_overlay", true)
		await _wait(1.5)
		await _shot(v, "oyun_sonu")
		var lay: Node = main.get("_death_overlay_layer")
		if lay:
			lay.queue_free()
			main.set("_death_overlay_layer", null)
		paused = false
		await _wait(0.4)
