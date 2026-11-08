extends SceneTree
## Kullanım (başsız): $env:HARITA="kadim_derinlikler"; Godot --headless --path . -s res://tools/harita_secimi/harita_duman.gd  (HARITA boşsa ana harita)
## Harita seçimi duman testi: Main'i (buyuk_test.gd _boot gibi) açar, 8 sn oynatır, haritayı ve temel durumu yazdırır.
## Harita seçimi HARITA ortam değişkeninden (map_profiles.gd varsa).

var _gm: Node = null


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		paused = false
		await process_frame


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
	var t_load: int = Time.get_ticks_msec()
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		print("SMOKE main açılmadı")
		quit(1)
		return
	print("SMOKE main açıldı %d ms" % (Time.get_ticks_msec() - t_load))
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	await _wait(8.0)
	var h: Node = main.get_node_or_null("Harita")
	var layers: Array = []
	if h:
		for c in h.find_children("*", "TileMapLayer", true, false):
			layers.append(str(c.name))
	print("SMOKE harita=", h.scene_file_path if h else "YOK", " idx=", h.get_index() if h else -1, " katman=", layers.size(), " ", layers.slice(0, 6))
	var p: Node2D = main.get_node_or_null("Player")
	print("SMOKE oyuncu=", p.global_position if p else Vector2.ZERO, " yaratik=", get_nodes_in_group("enemies").size(),
		" rect=", _gm.call("get_map_world_rect"), " orman=", _gm.call("get_forest_layer") != null)
	var mp: Variant = load("res://scripts/map_profiles.gd") if ResourceLoader.exists("res://scripts/map_profiles.gd") else null
	if mp:
		print("SMOKE profil=", (mp as GDScript).call("current_id"), " doğuş=", (mp as GDScript).call("spawn_position"))
	var nodes: Array = []
	for n in ["HouseInterior", "TravelingMerchant", "WorldEventManager", "MineWorld", "GuardCamps", "DungeonManager", "HideBrushManager", "Atmosphere"]:
		nodes.append("%s=%s" % [n, main.get_node_or_null(n) != null])
	print("SMOKE düğümler ", " ".join(nodes))
	var forest: TileMapLayer = _gm.call("get_forest_layer")
	if forest:
		print("SMOKE orman hücre=", forest.get_used_cells().size(), " (0,0) engel=", _gm.call("is_position_blocked_by_walls", Vector2(8, 8)),
			" oyuncu engel=", _gm.call("is_position_blocked_by_walls", p.global_position) if p else "?")
	var ep: GDScript = load("res://scripts/enemy_pathing.gd")
	var path: Variant = ep.call("find_path", p.global_position, p.global_position + Vector2(600, 300)) if p else null
	print("SMOKE yol=", (path as PackedVector2Array).size() if path is PackedVector2Array else str(path), " yeraltı=", p.call("is_underground_now") if p else "?")
	var dm: Node = main.get_node_or_null("DungeonManager")
	var gc: Node = main.get_node_or_null("GuardCamps")
	if dm:
		print("SMOKE yönetici harita=", dm.get("_map_id"), " görsel=", (dm.get("_map_props") as Dictionary).size(), " kök=", (dm.get("_roots") as Dictionary).keys(),
			" ısınma=", dm.call("warm_done") if dm.has_method("warm_done") else "yok (madde 463)")
	await _wait(10.0)
	print("SMOKE 18sn yaratik=", get_nodes_in_group("enemies").size(), " bekçi=", get_nodes_in_group("guards").size(), " oyuncu=", p.global_position if p else Vector2.ZERO)
	if gc:
		var dcamps: int = 0
		for c: Dictionary in gc.get("_camps"):
			if (c["def"] as Dictionary).has("dungeon"):
				dcamps += 1
		print("SMOKE kamp=", (gc.get("_camps") as Array).size(), " zindan/harita kampı=", dcamps)
	var DW: GDScript = load("res://scripts/dungeon/dungeon_world.gd")
	var me: Dictionary = DW.call("map_entry")
	if dm and not me.is_empty():
		var gate_key: String = ""
		var chest_key: String = ""
		var node_key: String = ""
		var node_obj: Dictionary = {}
		for o: Dictionary in (me["data"] as Resource).objects:
			if gate_key == "" and str(o.get("gate_key", "")) != "":
				gate_key = str(o["gate_key"])
			if chest_key == "" and str(o.get("chest_key", "")) != "":
				chest_key = str(o["chest_key"])
			if node_key == "" and str(o.get("node_key", "")) != "":
				node_key = str(o["node_key"])
				node_obj = o
		var cells: Array = DW.call("gate_cells", gate_key)
		print("SMOKE kapı ", gate_key, " kapat=", dm.call("host_close_gate", gate_key), " kapalı=", DW.call("is_gate_closed", gate_key),
			" hücre engel=", DW.call("is_move_blocked_cell", cells[0]) if not cells.is_empty() else "?")
		print("SMOKE sandık ", chest_key, " aç=", dm.call("host_open_chest", chest_key), " ikinci=", dm.call("host_open_chest", chest_key))
		## kol (madde 449): son kolu çek, grubundaki parmaklıklar inmeli (ilk kapı yukarıda zaten indirildiyse o grup hazırlanıyor sayılır)
		var lever_key: String = ""
		for o: Dictionary in (me["data"] as Resource).objects:
			if str(o.get("lever_key", "")) != "":
				lever_key = str(o["lever_key"])
		if lever_key != "":
			var lg: Array = dm.call("_lever_gates", lever_key)
			var pulled: bool = dm.call("host_pull_lever", lever_key)
			var closed_n: int = 0
			for gk: String in lg:
				closed_n += 1 if DW.call("is_gate_closed", gk) else 0
			print("SMOKE kol ", lever_key, " grup kapısı=", lg.size(), " çek=", pulled, " inen=", closed_n)
		## gaz fıçısı (madde 449): ateşle, fitil (1,4 sn) sonra patlamış ve dolmayı bekliyor olmalı
		var barrel_key: String = ""
		for o: Dictionary in (me["data"] as Resource).objects:
			if barrel_key == "" and str(o.get("barrel_key", "")) != "":
				barrel_key = str(o["barrel_key"])
		if barrel_key != "":
			var ig: bool = dm.call("host_ignite_barrel", barrel_key)
			await _wait(2.2)
			print("SMOKE fıçı ", barrel_key, " ateş=", ig, " patladı=", (dm.get("barrel_until") as Dictionary).has(barrel_key),
				" ikinci ateş=", dm.call("host_ignite_barrel", barrel_key))
		var res: String = dm.call("_resource_of", str(me["id"]), node_obj)
		var before: int = _gm.call("get_dungeon_resource", res)
		print("SMOKE kaynak ", node_key, " tür=", res, " topla=", dm.call("host_harvest", node_key, 1), " ", before, "->", _gm.call("get_dungeon_resource", res))
	quit(0)
