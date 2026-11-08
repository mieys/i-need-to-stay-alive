extends SceneTree

## Madde 432: yeni akış (önce kart, sonra pazar) gerçek SP main.tscn'de, HUD açık. Durum level_pazar_oyun.gd ile aynı (Oakley,
## Uzunkılıç III + Ateş Asası, Kanlı Yakut + Çeviklik Yüzüğü, 1480 altın / 17 parçacık). Kuyrukta 2 seviye: 1. kart -> pazar AÇILMAZ,
## 2. kart (ikinci ekran) -> pazar açılır. Çekimler: akis_1_kart.png, akis_2_pazar.png (eşya yuvasının üstünde, araçlar görünür),
## akis_3_kayit.png (eşya + geliştirme kaydedildi, karıştırıldı, yasak kuruldu). Sonra DEVAM: pazarın kapandığı / ağacın açıldığı.
## Kullanım: tools/proto_20261027/level_pazar/level_pazar_run.ps1 -Script level_pazar_akis.gd

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
	## AKIS_FAKIR=1: erken oyun gibi 30 altın / 0 parçacık - hiçbir şey alınamazken de pazar açılmalı (kullanıcı 2026-11-06 hatası)
	var fakir: bool = OS.get_environment("AKIS_FAKIR") == "1"
	if fakir:
		GM.gold = 30
		GM.call("add_weapon_shards", -int(GM.weapon_shards))
		print("VERI fakir: altın=", GM.gold, " parçacık=", GM.weapon_shards)

	## kuyrukta 2 seviye
	main.set("_pending_level_ups", 1)
	main.call("_show_level_up_screen", LEVEL)
	await _wait(1.4)
	var screen: Node = main.get_node_or_null("LevelUpScreen")
	await _shot("akis_fakir_1_kart.png" if fakir else "akis_1_kart.png")
	(screen.get("cards")[1] as Button).pressed.emit()
	await _wait(1.8)
	print("VERI 1. kart sonrası: pazar=", main.get_node_or_null("LevelMarketScreen") != null, " kart_ekranı=", main.get_node_or_null("LevelUpScreen") != null)
	var screen2: Node = main.get_node_or_null("LevelUpScreen")
	if screen2 == null:
		print("!! ikinci kart ekranı yok")
		quit()
		return
	(screen2.get("cards")[0] as Button).pressed.emit()
	await _wait(1.8)
	var ms: Node = main.get_node_or_null("LevelMarketScreen")
	print("VERI 2. kart sonrası: pazar=", ms != null, " paused=", paused)
	if ms == null:
		quit()
		return
	var view: Control = ms.get("view")
	view.call("_set_hover", "items", 1, true)
	await _wait(0.4)
	await _shot("akis_fakir_2_pazar.png" if fakir else "akis_2_pazar.png")
	if fakir:
		(view.get("go_button") as Button).pressed.emit()
		await _wait(0.6)
		print("VERI fakir DEVAM sonrası: pazar=", main.get_node_or_null("LevelMarketScreen") != null and not main.get_node("LevelMarketScreen").is_queued_for_deletion(), " paused=", paused)
		quit()
		return
	view.call("_set_hover", "items", 1, false)
	view.call("toggle_save", "items", 1)
	view.call("toggle_save", "upgrades", 0)
	var saved_ids: Array = (GM.get("market_saved") as Array).map(func(e: Dictionary) -> String: return (load("res://scripts/level_market.gd") as GDScript).call("offer_id", e))
	view.call("reroll")
	await _wait(0.4)
	view.call("_set_hover", "items", 4, true)
	view.call("press_ban", "items", 4)
	await _wait(0.4)
	await _shot("akis_3_kayit.png")
	var o: Dictionary = view.get("offers")
	var M: GDScript = load("res://scripts/level_market.gd")
	## madde 433 ek 6/7: tarifli bir eşyayı seç -> ayrıntıda tarif ağacı (AKIS_TARIF=<anahtar> o eşyayı 6. yuvaya koyar)
	var oo: Dictionary = view.get("offers")
	var force_key: String = OS.get_environment("AKIS_TARIF")
	if force_key != "":
		(oo["items"] as Array)[5] = {"type": "item", "key": force_key}
		view.call("_rebuild_slots")
		await _wait(0.3)
	for k in (oo["items"] as Array).size():
		var ek: Dictionary = oo["items"][k]
		if str(ek.get("type", "")) == "item" and not (Items.recipe(str(ek["key"])) as Array).is_empty() and (force_key == "" or str(ek["key"]) == force_key):
			view.call("_set_hover", "items", 4, false)
			view.call("_select", "items", k)
			await _wait(0.4)
			await _shot("akis_4_tarif.png")
			print("VERI tarif: ", ek["key"])
			break
	print("VERI kayıtlı=", saved_ids, " karıştırma sonrası items[1]=", M.call("offer_id", o["items"][1]), " upgrades[0]=", M.call("offer_id", o["upgrades"][0]))
	(view.get("go_button") as Button).pressed.emit()
	await _wait(0.6)
	print("VERI DEVAM sonrası: pazar=", main.get_node_or_null("LevelMarketScreen") != null and not main.get_node("LevelMarketScreen").is_queued_for_deletion(),
		" paused=", paused)
	quit()
