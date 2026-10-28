extends SceneTree

## Madde 388: OYUNDAKİ level atlama + pazar ekranının (level_up_screen.gd + level_market_view.gd) gerçek çizicide çekimi. Gerçek SP
## main.tscn, prototipteki durum (Oakley, Uzunkılıç III + Ateş Asası, Kanlı Yakut + Çeviklik Yüzüğü, 1480 altın / 17 parçacık), HUD
## AÇIK; ekran main._show_level_up_screen ile açılır. Çekimler: oyun_ilk.png (açılış, 2. yuvanın üstünde), oyun_sonra.png (pazardan
## alım + pazar karıştırma + kart seçimi). Sonra DEVAM: ekranın kapandığı ve ağacın açıldığı yazdırılır.
## Kullanım: tools/proto_20261027/level_pazar/level_pazar_run.ps1 -Script level_pazar_oyun.gd

const CHAR_ID := 2
const LEVEL := 13

var GM: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _out() -> String:
	var d: String = OS.get_environment("LEVEL_PAZAR_DIR")
	if d == "":
		d = ProjectSettings.globalize_path("res://tools/proto_20261027/level_pazar/out")
	DirAccess.make_dir_recursive_absolute(d)
	return d


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if img.get_width() != 1920:
		img.resize(1920, 1080, Image.INTERPOLATE_BILINEAR)
	img.save_png(_out().path_join(name))
	print("SHOT %s" % name)


func _run() -> void:
	await process_frame
	GM = root.get_node("GameManager")
	AudioServer.set_bus_mute(0, true)
	root.get_node("NetworkManager").call("disconnect_from_room")
	root.get_node("UISound").set("show_fps", false)
	GM.call("reset")
	GM.set("selected_char_id", CHAR_ID)
	GM.set("selected_character", (load("res://scripts/characters.gd") as GDScript).call("get_def", CHAR_ID).get("skill", 1))
	GM.set("selected_start_weapon", "uzunkilic")
	GM.set("selected_pet", "kirpi")
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	await _wait(2.5)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(1.0)
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
	p.global_position += Vector2(40, 170)
	var Logic: GDScript = load("res://scripts/weapon_shop_logic.gd")
	(load("res://scripts/meta_progress.gd") as GDScript).call("set_unlock_all", true)
	GM.gold = 99999
	GM.call("add_weapon_shards", 999 - int(GM.weapon_shards))
	Logic.call("buy_weapon", p, "fire_staff")
	for e: Dictionary in GM.owned_weapons:
		EnchantDefs.ensure_trait(e)
		if str(e.get("key", "")) == "uzunkilic":
			(e["enchant"] as Dictionary)["ups"] = [0, 1]
	p.set("max_item_slots", 9)
	for key: String in ["kanli_yakut", "ceviklik_yuzugu"]:
		p.call("buy_item", key)
	GM.set("game_time", 1350.0)
	GM.set("free_rerolls_per_card", 1)
	GM.gold = 1480
	GM.call("add_weapon_shards", 17 - int(GM.weapon_shards))
	p.set("level", LEVEL)
	await _wait(1.0)

	main.call("_show_level_up_screen", LEVEL)
	await _wait(1.4)
	var screen: Node = main.get_node_or_null("LevelUpScreen")
	var view: Control = screen.get("_market_view") if screen else null
	if view == null:
		print("!! pazar görünümü yok")
		quit()
		return
	view.set("_hover", 1)
	view.call("_refresh_detail")
	await _wait(0.3)
	await _shot("oyun_ilk.png")

	view.set("_hover", -1)
	var offers: Array = view.get("offers")
	var bought: String = ""
	for i in offers.size():
		if (load("res://scripts/level_market.gd") as GDScript).call("block_reason", p, offers[i]) == "":
			view.call("_select", i)
			if view.call("buy", i):
				bought = str(offers[i])
			break
	view.call("_on_shop_reroll")
	await _wait(0.4)
	(screen.get("cards")[2] as Button).pressed.emit()
	await _wait(1.5)
	await _shot("oyun_sonra.png")
	print("VERI alınan=", bought, " altın=", GM.gold, " pazar_karistirma=", view.get("shop_rerolls"))

	(view.get("go_button") as Button).pressed.emit()
	await _wait(0.6)
	print("VERI kapandi=", not is_instance_valid(screen) or screen.is_queued_for_deletion(), " paused=", paused,
		" ekran_var=", main.get_node_or_null("LevelUpScreen") != null)
	quit()
