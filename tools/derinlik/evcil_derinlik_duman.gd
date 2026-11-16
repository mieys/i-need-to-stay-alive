extends SceneTree
## Kullanım (başsız): Godot --headless --path . -s res://tools/derinlik/evcil_derinlik_duman.gd
## Evcil derinlik duman testi (2026-11-16, pet_depth_proxy.gd): gerçek Main'i Minik Cadı ile açar; vekilin Main altında kurulduğunu, hayvanı izlediğini,
## yaratık ayak sırasına (C++ draw_order) girdiğini ve oyuncunun önünde z 2'ye çıkan sıçanın önündeki evcilin de yükseldiğini (creature_depth) yoklar.

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
	_gm.set("selected_pet", "slime")
	_gm.set("debug_immortal", true)
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		print("DUMAN main açılmadı")
		quit(1)
		return
	var main: Node = current_scene
	main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	await _wait(3.0)
	var ok: bool = true
	var player: Node2D = main.get_node_or_null("Player")
	var pet: Node2D = player.get_node_or_null("Slime") if player else null
	var holders: Array = get_nodes_in_group("ysort_pets")
	print("DUMAN evcil=", pet != null, " vekil=", holders.size())
	if pet == null or holders.size() != 1:
		quit(1)
		return
	var h: Node2D = holders[0]
	var spr: Node = h.get_node_or_null("AnimatedSprite2D")
	ok = ok and h.get_parent() == main and spr != null and pet.get_child_count() == 0
	print("DUMAN vekil Main çocuğu=", h.get_parent() == main, " görsel vekilde=", spr != null, " hayvanda çocuk=", pet.get_child_count(),
		" konum farkı=", h.global_position.distance_to(pet.global_position), " görünür=", h.visible, " z=", h.z_index)
	ok = ok and h.global_position.distance_to(pet.global_position) < 0.01 and h.visible
	## Sahne: oyuncunun hemen önünde sıçan, sıçanın önünde evcil (ekran görüntüsündeki durum).
	var spawner: Node = main.get_node_or_null("EnemySpawner")
	var rat: Node2D = spawner.call("_spawn_creature", "rat1", player.global_position + Vector2(4, 22)) if spawner else null
	if rat == null:
		print("DUMAN sıçan doğmadı")
		quit(1)
		return
	rat.set("speed", 0.0)
	await _wait(0.3)
	rat.global_position = player.global_position + Vector2(4, 22)
	pet.set_process(false) ## hayvan yerinde dursun
	pet.global_position = player.global_position + Vector2(18, 40)
	(h as Object).call("sync")
	var cd: Node = main.get_node("CreatureDepth")
	cd.call("update_now")
	print("DUMAN sıçan z=", rat.z_index, " evcil z=", h.z_index)
	ok = ok and rat.z_index == 2 and h.z_index == 2
	var ew: Object = (load("res://scripts/enemy_world/enemy_world_bridge.gd") as GDScript).call("fog_world", self)
	if ew != null:
		main.call("_update_creature_draw_order_ew", ew)
		var order: Array = ew.call("get_last_draw_order")
		var ri: int = -1
		var pi: int = -1
		for k in range(order.size()):
			if order[k][0] == rat:
				ri = k
			elif order[k][0] == h:
				pi = k
		print("DUMAN çizim sırası sıçan=", ri, " evcil=", pi)
		ok = ok and ri >= 0 and pi > ri
	## evcil oyuncunun arkasına geçince iner
	pet.global_position = player.global_position + Vector2(0, -30)
	(h as Object).call("sync")
	cd.call("update_now")
	print("DUMAN arkadaki evcil z=", h.z_index)
	ok = ok and h.z_index == 0
	print("DUMAN SONUÇ ", "TAMAM" if ok else "HATA")
	quit(0 if ok else 1)
