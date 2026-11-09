extends SceneTree

## ATEŞ ASASI alev ÖRNEKLERİ (2026-11-09, kullanıcı: "ekranı çok kaplıyor, göz yoruyor, karakterin üstünü kapatıyor" -> seçeneklerin nasıl görüneceği).
## GERÇEK Main + gerçek çizici: oyuncuya Ateş Asası verilir, menzilde hareketsiz slime'lar, alev (fx_enchant_sprite) her karede çizimden
## HEMEN ÖNCE (frame_pre_draw) değişkene göre değiştirilir - oyun koduna dokunulmaz, hasar/menzil aynı:
##   0 ŞU AN | 1 saydam + turuncu renk | 2 = 1 + çizilen boy kısa (x0,72) | 3 = 2 + yaratık/karakterin ALTINDA (z)
## Senaryolar: sağ (hedef sağda) ve yukarı (hedef karakterin üstünde). Çekimler AC_DIR'e (tam pencere 1920x1080), birleştirme ates_proto.py.
## Koşturucu: tools/proto_20261109/ates_run.ps1 (gizli masaüstü, APPDATA yalıtılır).

var _dir: String = OS.get_environment("AC_DIR")
var _gm: Node = null
var _main: Node = null
var _variant: int = 0
var _z3: int = int(OS.get_environment("AC_Z3")) if OS.get_environment("AC_Z3") != "" else 0
var _flames_seen: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_dir.path_join(name))
	print("SHOT ", name)


func _slime(pos: Vector2) -> Node2D:
	var e: Node2D = (load("res://scenes/creatures/enemy_slime1.tscn") as PackedScene).instantiate()
	e.set("speed", 0.0)
	e.set("max_health", 1.0e9)
	_main.add_child(e)
	e.global_position = pos
	e.set("health", 1.0e9)
	return e


func _set_weapons(player: Node, keys: Array) -> void:
	for n in player.get("owned_weapon_nodes"):
		if is_instance_valid(n):
			n.queue_free()
	(player.get("owned_weapon_nodes") as Array).clear()
	(_gm.get("owned_weapons") as Array).clear() ## kayıt listesi de: yoksa silah özelliği (Ateş Nefesi) anahtar uyuşmazlığıyla takılmaz
	await process_frame
	for k in keys:
		## Defter (owned_weapons) silahtan ÖNCE yazılır - buy_weapon_copy özelliği (Ateş Nefesi) defterden takar.
		(_gm.get("owned_weapons") as Array).append((load("res://scripts/enchant_defs.gd") as GDScript).new_weapon_entry(k, 1, 0))
		print("buy ", k, " ", player.call("buy_weapon_copy", k, 1))


func _collect_flames(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c.get_script() != null and str(c.get("sheet")) == "flame_fire":
			out.append(c)
		_collect_flames(c, out)


## Her karede, çizimden hemen önce: alev düğümlerine seçilen değişkeni uygula (oyunun kendi _refresh'inden SONRA çalışır).
func _apply_variant() -> void:
	var player: Node = _main.get_node_or_null("Player") if _main else null
	if player == null:
		return
	var flames: Array = []
	_collect_flames(player, flames)
	_flames_seen = maxi(_flames_seen, flames.size())
	for f in flames:
		var spr: AnimatedSprite2D = f.get("_spr") as AnimatedSprite2D
		if spr == null:
			continue
		var base_scale: Vector2 = (f.get("sprite_scale") as Vector2) * 1.212
		match _variant:
			0:
				spr.self_modulate = Color.WHITE
				spr.scale = base_scale
				f.z_index = 9
			1:
				spr.self_modulate = Color(1.0, 0.70, 0.45, 0.55)
				spr.scale = base_scale
				f.z_index = 9
			2:
				spr.self_modulate = Color(1.0, 0.70, 0.45, 0.55)
				spr.scale = base_scale * 0.72
				f.z_index = 9
			3:
				spr.self_modulate = Color(1.0, 0.70, 0.45, 0.55)
				spr.scale = base_scale * 0.72
				f.z_index = _z3


func _crop_origin(player: Node2D) -> Vector2:
	return player.get_viewport().get_canvas_transform() * player.global_position


func _run() -> void:
	await process_frame
	_gm = root.get_node("GameManager")
	root.get_node("NetworkManager").call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", 2)
	_gm.set("selected_character", (load("res://scripts/characters.gd") as GDScript).get_def(2).get("skill", 1))
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 40000:
		await process_frame
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	RenderingServer.frame_pre_draw.connect(_apply_variant)
	await _wait(2.5)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(2.0)
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", 150.0)
		atmo.call("debug_set_weather", 0)
	var player: Node2D = _main.get_node("Player")
	player.set("_oakley_flower_auto_timer", 1.0e9)
	## Açık zemin (evin çatısı alevi/yaratıkları örtmesin): avlunun sol-altındaki geniş toprak yol / çayır.
	player.global_position += Vector2(-170.0, 100.0)
	var spot: Vector2 = player.global_position
	await _wait(1.5)
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	await _wait(0.5)
	await _set_weapons(player, ["fire_staff"])
	print("ORIGIN ", _crop_origin(player))
	var scenarios: Dictionary = {
		"sag": [Vector2(105.0, -8.0), Vector2(128.0, 26.0), Vector2(118.0, -44.0), Vector2(84.0, 22.0)],
		## Hedef karakterin ALTINDA: asa karakterin ~55 birim üstünde durur, alev aşağı doğru karakterin üstünden geçer.
		"asagi": [Vector2(2.0, 46.0), Vector2(30.0, 64.0), Vector2(-26.0, 60.0), Vector2(6.0, 80.0)],
	}
	for sc in scenarios.keys():
		var sl: Array = []
		for off in scenarios[sc]:
			sl.append(_slime(spot + off))
		_variant = 0
		await _wait(2.0)
		print("DBG invasion_pending=", _gm.get("invasion_pending"), " enemies=", get_nodes_in_group("enemies").size(), " weapons=", (player.get("owned_weapon_nodes") as Array).size())
		for w in player.get("owned_weapon_nodes"):
			if is_instance_valid(w):
				var bh: Object = w.get("enchant_behavior")
				print("DBG weapon ", w.name, " vis=", w.visible, " pos=", w.global_position, " key=", w.get("weapon_key"), " parent=", w.get_parent().name, " behavior=", bh)
		var fl: Array = []
		_collect_flames(player, fl)
		print("DBG flames=", fl.size(), " player=", player.global_position)
		print("DBG z player=", player.z_index, " rel=", player.z_as_relative)
		for w in player.get("owned_weapon_nodes"):
			if is_instance_valid(w):
				print("DBG z weapon=", w.z_index, " top_level=", w.top_level, " rel=", w.z_as_relative)
		for f in fl:
			print("DBG z flame=", f.z_index, " rel=", f.z_as_relative, " parent=", f.get_parent().name)
		for c in player.get_children():
			if c is CanvasItem:
				print("DBG z child ", c.name, " ", c.get_class(), " z=", (c as CanvasItem).z_index)
		for e in get_nodes_in_group("enemies"):
			print("DBG z enemy z=", e.z_index, " y=", e.global_position.y)
			break
		var idx: int = 0
		for c in _main.get_children():
			if c is CanvasItem and (idx < 14 or c == player):
				print("DBG main ", idx, " ", c.name, " z=", (c as CanvasItem).z_index, " ysort=", (c as CanvasItem).y_sort_enabled)
			idx += 1
		var harita: Node = _main.get_node_or_null("Harita")
		print("DBG harita z=", harita.z_index if harita is CanvasItem else "-", " idx=", harita.get_index() if harita else -1, " player idx=", player.get_index())
		for v in 4:
			_variant = v
			if v == 3:
				## Seçenek 3: alev, projenin öbür efsun efektleri gibi EFEKT KATMANINA (z 0, sahne kökünün çocuğu: oyuncuların altında, zeminin ve
				## önceden doğmuş yaratıkların üstünde) alınır; asanın ucunu izlemeye devam eder (fx_enchant_sprite _follow_update ebeveynden bağımsız).
				var fl3: Array = []
				_collect_flames(player, fl3)
				for f3 in fl3:
					f3.reparent(_main, true)
			await _wait(0.5)
			await _shot("ates_%s_%d.png" % [sc, v])
		for s in sl:
			if is_instance_valid(s):
				s.queue_free()
		await _wait(0.8)
	print("flames_seen=", _flames_seen)
	print("BITTI")
	quit()
