extends SceneTree

## Telefon arayüzü - mevcut ekranların GERÇEK oyun görüntüsü (mobil kip, PENCERELİ; headless'ta çizim yok).
##   Godot --path <proje> --windowed --resolution 2400x1080 -s res://tools/mobile_ui/capture_screens.gd -- --mobile-ui
## Ortam: SHOT_DIR (zorunlu, PNG'lerin yazılacağı klasör), SHOT_CHAR (karakter no, varsayılan 9).
## Sırayla: ana menü, karakter seçimi, silah seçimi, oyun içi HUD (yaratıklı), level atlama, sandık, envanter, tüccar,
## duraklatma. Her ekran ayrı PNG; ekran kapatılıp bir sonrakine geçilir.

var _dir: String = OS.get_environment("SHOT_DIR")
var _gm: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if _dir == "":
		push_error("SHOT_DIR yok")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_dir)
	await process_frame
	await _force_phone_window()
	_gm = root.get_node("GameManager")
	_gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_start_pressed"), 10.0)
	await _wait(1.5)
	await _shot("01_ana_menu")
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_character_pressed"), 10.0)
	await _wait(1.0)
	var ch: int = int(OS.get_environment("SHOT_CHAR")) if OS.get_environment("SHOT_CHAR") != "" else 9
	current_scene.call("_on_character_pressed", ch)
	await _wait(0.6)
	await _shot("02_karakter_secimi")
	## Başlangıç silahı ızgarası (menu_weapon_picker.gd). SHOT_WEAPON verilirse o silah seçilir (oyunda envanterde görünmeli).
	var wp: Node = current_scene.get("weapon_picker")
	if wp and OS.get_environment("SHOT_WEAPON") != "":
		wp.call("select", OS.get_environment("SHOT_WEAPON"))
	if wp and wp.has_method("_open_grid"):
		wp.call("_open_grid")
		await _wait(0.6)
		await _shot("02b_silah_listesi")
		wp.call("_close_grid")
		await _wait(0.3)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.name == "Main", 30.0)
	await _wait(1.5)
	await _shot("03_silah_secimi")
	for k in 8:
		for n in _all(root):
			if n.has_method("_auto_pick_random_card"):
				n.call("_auto_pick_random_card")
		await _wait(0.5)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.5)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner and player:
		var roster: Array = spawner.call("_spawnable_roster", 3)
		for i in 14:
			var pos: Vector2 = player.global_position + Vector2.from_angle(i * 0.45) * (260.0 + 25.0 * (i % 4))
			if _gm.call("is_position_blocked_by_forest", pos):
				continue
			var e: Node = spawner.call("_spawn_creature", roster[i % roster.size()], pos, 900000 + i)
			e.call("apply_tier_scaling", 3)
	await _wait(1.2)
	await _shot("04_oyun_ici_hud")

	## level atlama
	current_scene.call("_show_level_up_screen", 2)
	await _wait(2.0)
	await _shot("05_level_atlama")
	var lu: Node = current_scene.get("_active_level_up_screen")
	if is_instance_valid(lu):
		lu.queue_free()
	paused = false
	await _wait(0.5)

	## yetenek evrimi kartları (level atlama ekranının evrim kipi)
	if current_scene.call("debug_open_evolution_screen"):
		await _wait(2.0)
		await _shot("05b_evrim")
		_free_by_script("level_up_screen.gd")
		paused = false
		await _wait(0.5)

	## efsun kartları
	current_scene.call("debug_open_enchant_screen")
	await _wait(5.0)
	await _shot("05c_efsun")
	_free_by_script("enchant_screen.gd")
	paused = false
	await _wait(0.5)

	## sandık
	current_scene.call("debug_open_chest", false)
	await _wait(4.5)
	await _shot("06_sandik")
	for n in current_scene.get_children():
		if n.get_script() != null and String(n.get_script().resource_path).ends_with("chest_menu.gd"):
			n.queue_free()
	paused = false
	await _wait(0.5)

	## envanter (HUD)
	var hud: Node = current_scene.get("hud")
	if hud and hud.has_method("_on_envanter_toggle"):
		hud.call("_on_envanter_toggle")
		await _wait(1.0)
		## Telefonda bilgi şeridi: ilk silah yuvasına dokunulmuş gibi.
		var inv: Node = hud.get("inventory_panel_instance")
		if inv and bool(inv.get("_mobile")):
			inv.call("_on_sell_weapon_equip", 0)
		await _wait(0.3)
		await _shot("07_envanter")
		hud.call("_on_envanter_toggle")
		await _wait(0.5)

	## tüccar
	var merchant: Node = _find_by_method(current_scene, "_open_shop_screen")
	if merchant and player:
		if (merchant.get("_current_stock") as Array).is_empty() and merchant.has_method("_generate_stock"):
			merchant.set("_current_stock", merchant.call("_generate_stock"))
		_gm.set("gold", maxi(int(_gm.get("gold")), 1500)) ## -s betiği autoload adlarını derlemede göremez
		merchant.call("_open_shop_screen", player)
		await _wait(1.2)
		await _shot("08_tuccar")
		var scr: Node = merchant.get("_shop_screen")
		if is_instance_valid(scr):
			scr.queue_free()
		paused = false
		await _wait(0.5)

	## duraklatma
	current_scene.call("_toggle_pause")
	await _wait(1.0)
	await _shot("09_duraklatma")
	quit()


## Oyunun kayıtlı ayarı tam ekran açar - telefon oranı (20:9) için pencereyi her çekimden önce zorla.
func _force_phone_window() -> void:
	## SHOT_SIZE="1920x1080" ile masaüstü kontrolü (varsayılan telefon 2400x1080).
	var want := Vector2i(2400, 1080)
	var env_size: PackedStringArray = OS.get_environment("SHOT_SIZE").split("x")
	if env_size.size() == 2:
		want = Vector2i(int(env_size[0]), int(env_size[1]))
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if DisplayServer.window_get_size() != want:
		DisplayServer.window_set_size(want)
		DisplayServer.window_set_position(Vector2i(0, 0))
		for i in 6:
			await process_frame


func _shot(name: String) -> void:
	await _force_phone_window()
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_dir.path_join(name + ".png"))
	print("SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _until(cond: Callable, timeout: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		await process_frame


func _free_by_script(file: String) -> void:
	for n in _all(root):
		if n.get_script() != null and String(n.get_script().resource_path).ends_with(file):
			n.queue_free()


func _all(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all(c))
	return out


func _find_by_method(n: Node, method: String) -> Node:
	if n.has_method(method):
		return n
	for c in n.get_children():
		var r: Node = _find_by_method(c, method)
		if r:
			return r
	return null
