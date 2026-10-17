extends SceneTree

## PROTOTİP yakalama (2026-10-14): gerçek hud.tscn'i 1920x1080 SubViewport'ta çizer, sol tarafa mini stat panelini
## (stat_panel_proto_draw.gd) + portre altına aç/kapa düğmesini koyar; A/B x kapalı/sayfa 1/sayfa 2 kırpıntıları yazar.
## Kullanım: Godot --path . --windowed -s tools/proto_20261014/stat_panel_proto.gd

const OUT := "res://tools/proto_20261014/out/"
const Draw := preload("res://tools/proto_20261014/stat_panel_proto_draw.gd")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	var gm: Node = root.get_node("GameManager")
	gm.set("selected_char_id", 0)
	gm.set("selected_spiritual", "can")
	gm.set("selected_pet", "peri")
	gm.set("owned_items", [{"key": "ruzgar_eldiveni"}, {"key": "anka_kusunun_kalbi"}, {"key": "ilidaricin_kilici"}, {"key": "son_felaket_pencesi"}])
	gm.set("shield_standart_level", 1)
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
	hud.call("update_health", 1284.0, 2150.0)
	hud.call("_on_item_shield_changed", 356.0, 900.0)
	hud.call("update_level", 12)
	hud.get_node("ReviveHearts").call("set_revives", 2)
	await _wait(0.6)
	var frame: Control = hud.get_node("DockFrame") as Control
	var dock: Rect2 = frame.get_global_rect()
	var legend: Rect2 = (hud.get_node("DockLegend") as Control).get_global_rect()
	print("DOCK ", dock, " LEGEND ", legend)

	var panel := Control.new()
	panel.set_script(Draw)
	panel.name = "StatProto"
	hud.add_child(panel)
	hud.move_child(panel, frame.get_index()) ## ana panelin ARKASINDA (sağ 12 px örtülür)
	panel.position = Vector2(dock.position.x - Draw.panel_size().x + Draw.OVERLAP, dock.position.y + 6.0 - (Draw.TAB_SIZE.y - 4.0))
	panel.size = Draw.panel_size() + Vector2(0, Draw.TAB_SIZE.y)
	var btn := Control.new()
	btn.set_script(Draw)
	btn.name = "StatProtoButton"
	hud.add_child(btn)
	btn.set("mode", "button")
	btn.position = dock.position + Vector2(24, 122)
	btn.size = Vector2(64, 20)

	var f: Font = Draw.FONT
	for s in Draw.WORST:
		print("W ", s, " ", f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, Draw.FONT_PX).x)
	print("PANEL ", Draw.panel_size(), " COL ", Draw.col_w())

	var crop := Rect2i(int(panel.position.x) - 12, int(panel.position.y) - 10, 0, 0)
	crop.size = Vector2i(int(legend.end.x) + 12 - crop.position.x, 1080 - crop.position.y)
	for v in ["A", "B"]:
		for st in [["kapali", false, 0], ["sayfa1", true, 0], ["sayfa2", true, 1], ["sinir", true, 0]]:
			for n: Control in [panel, btn]:
				n.set("variant", v)
				n.set("open", st[1])
				n.set("page", st[2])
				n.set("stress", st[0] == "sinir")
				n.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img: Image = vp.get_texture().get_image().get_region(crop)
			img.save_png(ProjectSettings.globalize_path(OUT + "stat_panel_%s_%s.png" % [v, st[0]]))
	## Bağlam: tam ekran, B sayfa 1.
	for n: Control in [panel, btn]:
		n.set("variant", "B")
		n.set("open", true)
		n.set("page", 0)
		n.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT + "stat_panel_tam_ekran.png"))
	print("CROP ", crop)
	quit()
