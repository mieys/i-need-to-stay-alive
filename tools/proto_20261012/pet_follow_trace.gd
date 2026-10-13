extends SceneTree

## Evcil hayvan takibinin sayısal izi (madde 109 devamı): sahip 3 sn 200 px/sn sağa yürür, 3 sn durur; her 0,5 sn'de hayvan-sahip uzaklığı + hayvan hızı.
## Kullanım: Godot --path . -s tools/proto_20261012/pet_follow_trace.gd   (PET_TRACE_PET = kirpi | kopek | kelebek | peri)

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	AudioServer.set_bus_mute(0, true)
	var gm: Node = root.get_node("GameManager")
	gm.selected_char_id = 3
	gm.selected_character = 43
	gm.selected_pet = OS.get_environment("PET_TRACE_PET") if OS.get_environment("PET_TRACE_PET") != "" else "kirpi"
	var scene := Node2D.new()
	root.add_child(scene)
	current_scene = scene
	var p: Node2D = (load("res://scenes/player.tscn") as PackedScene).instantiate()
	scene.add_child(p)
	p.global_position = Vector2(3000, 3000)
	p.set_physics_process(false)
	await create_timer(1.5).timeout
	var pet: Node2D = p.get_node_or_null("Kirpi")
	if pet == null: pet = p.get_node_or_null("KelebekRuhu")
	if pet == null: pet = p.get_node_or_null("Peri")
	if pet == null: pet = p.get("_matthew_pet")
	var prev: Vector2 = pet.global_position
	var t0: int = Time.get_ticks_msec()
	var last_print: float = 0.0
	var line: String = ""
	while true:
		await process_frame
		var el: float = float(Time.get_ticks_msec() - t0) / 1000.0
		if el > 7.0:
			break
		var dt: float = get_root().get_process_delta_time()
		if el < 3.0:
			p.global_position.x += 200.0 * dt
		if el - last_print >= 0.5:
			var spd: float = pet.global_position.distance_to(prev) / (el - last_print)
			line += "t=%.1f gap=%.0f pet_hiz=%.0f | " % [el, p.global_position.x - pet.global_position.x, spd]
			prev = pet.global_position
			last_print = el
	print(line)
	quit()
