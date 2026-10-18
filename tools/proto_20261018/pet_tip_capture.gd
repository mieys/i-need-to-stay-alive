extends SceneTree

## Evcil yuvası ipucu yakalaması (2026-10-18): gerçek hud.tscn 1920x1080 SubViewport, sahte sayaçlarla. Çıktı out/pet_tip/<evcil>.png
## Kullanım: Godot --path . --windowed --resolution 640x360 -s tools/proto_20261018/pet_tip_capture.gd

const OUT := "res://tools/proto_20261018/out/pet_tip/"


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	var bl: Object = load("res://scripts/balance_log.gd")
	var gm: Node = root.get_node("GameManager")
	gm.set("selected_char_id", 0)
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color("#4f7a3a")
	bg.size = Vector2(1920, 1080)
	vp.add_child(bg)
	var hud: Node = (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	vp.add_child(hud)
	await _wait(0.5)
	bl.call("reset")
	bl.call("on_hit", "s:matthew_kopek", 18450.0, false)
	bl.call("on_hit", "s:evcil_kirpi", 2310.0, false)
	bl.call("on_prevented", "s:evcil_kirpi", 845.0)
	bl.call("on_gain", "s:evcil_peri", 3120.0, 0.0)
	for i in 7:
		bl.call("on_pet_drop")
	var slot: Control = hud.get_node("DockPet") as Control
	for key in ["kirpi", "kopek", "peri", "papagan"]:
		slot.call("set_pet", key)
		slot.call("_open_tooltip")
		await _wait(0.3)
		var tip: Control = slot.get("tooltip_panel") as Control
		var r: Rect2 = tip.get_global_rect().merge(slot.get_global_rect()).grow(12.0)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().get_region(Rect2i(r)).save_png(ProjectSettings.globalize_path(OUT + key + ".png"))
		slot.call("_close_tooltip")
	quit()
