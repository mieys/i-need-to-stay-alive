extends SceneTree

## PROTOTİP 2 yakalama (2026-10-14): 32x32 simgeli mini stat paneli gerçek hud.tscn üstünde (1920x1080 SubViewport).
## Yazı 9 / 18 px x kapalı / sayfa 1 / sayfa 2 / sınır (en geniş değerler) -> out/stat_panel2_<px>_<durum>.png
## Kullanım: python tools/proto_20261014/gen_stat_icons32.py; Godot --path . --windowed -s tools/proto_20261014/stat_panel_proto2.gd

const OUT := "res://tools/proto_20261014/out/"
const Draw := preload("res://tools/proto_20261014/stat_panel_proto2_draw.gd")


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(vp: SubViewport, crop: Rect2i, file: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().get_region(crop).save_png(ProjectSettings.globalize_path(OUT + file))


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

	var tag: String = OS.get_environment("CAP_TAG") if OS.get_environment("CAP_TAG") != "" else "stat_panel2"
	## Yapılandırmalar: "simge_px:yazı_px:klasör" virgülle (varsayılan: 32 px simge, 9 ve 18 px yazı).
	var cfg_env: String = OS.get_environment("CAP_CONFIGS")
	if cfg_env == "":
		cfg_env = "32:9:stat_ikon32,32:18:stat_ikon32"
	var cfgs: Array = []
	for c in cfg_env.split(","):
		var f: PackedStringArray = c.split(":")
		cfgs.append([float(f[0]), int(f[1]), f[2]])
	var btn := Control.new()
	btn.set_script(Draw)
	hud.add_child(btn)
	btn.set("mode", "button")
	btn.position = dock.position + Vector2(24, 122)
	btn.size = Vector2(64, 20)
	var bottom: float = legend.end.y ## panelin altı efsanevi panelin altıyla hizalı
	var crop := Rect2i(int(dock.position.x) - 300, int(dock.position.y) - 70, 0, 0)
	crop.size = Vector2i(int(legend.end.x) + 12 - crop.position.x, 1080 - crop.position.y)
	for cfg in cfgs:
		var panel := Control.new()
		panel.set_script(Draw)
		panel.set("icon_dir", "res://tools/proto_20261014/out/%s/" % cfg[2])
		panel.set("icon_px", cfg[0])
		panel.set("font_px", cfg[1])
		hud.add_child(panel)
		hud.move_child(panel, frame.get_index()) ## ana panelin ARKASINDA
		var ps: Vector2 = panel.call("panel_size")
		print("CFG ", cfg, " PANEL ", ps, " COL ", panel.call("col_w"), " VALW ", panel.call("value_w"))
		panel.position = Vector2(dock.position.x - ps.x + Draw.OVERLAP, bottom - ps.y - (Draw.TAB_SIZE.y - Draw.TAB_BITE))
		panel.size = ps + Vector2(0, Draw.TAB_SIZE.y)
		for st in [["sayfa1", true, 0], ["sayfa2", true, 1], ["sinir", true, 0]]:
			for n: Control in [panel, btn]:
				n.set("open", st[1])
				n.set("page", st[2])
				n.set("stress", st[0] == "sinir")
				n.queue_redraw()
			await _shot(vp, crop, "%s_%d_%d_%s.png" % [tag, int(cfg[0]), cfg[1], st[0]])
		panel.queue_free()
		await process_frame
	print("CROP ", crop)
	quit()
