extends SceneTree

## EVCİL ARKA PLANI doğrulama yakalaması (madde 585): gerçek seçim ekranı (EVCİL sekmesi) + gerçek hud.tscn evcil yuvası, ipucu FAREYLE açılır
## (push_input; madde 585 hatası: CharacterCluster fareyi yuvadan önce yutuyordu). Çıktı out/: secim.png, yuva_<anahtar>.png, ipucu_<anahtar>.png
## Çalıştırıcı: powershell -ExecutionPolicy Bypass -File tools/proto_20261111/evcil_bg/evcil_bg_run.ps1 (gizli masaüstü, APPDATA yalıtılı)

const OUT := "res://tools/proto_20261111/evcil_bg/out/"


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _shot(name: String, r: Rect2i = Rect2i()) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	if r.size.x > 0:
		## kontrol koordinatı 1920x1080 mantıksal alanda, doku pencere boyunda (gizli masaüstü 2560x1440 olabilir)
		var k: float = float(img.get_width()) / root.get_visible_rect().size.x
		var rs := Rect2i(Vector2i((Vector2(r.position) * k).floor()), Vector2i((Vector2(r.size) * k).ceil()))
		img = img.get_region(rs.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


func _mouse(p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	root.push_input(ev, true) ## viewport koordinatı (gizli masaüstünde pencere 1920x1080 olmayabilir)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await process_frame
	var mp: GDScript = load("res://scripts/meta_progress.gd")
	mp.set("unlock_all_override", true)
	var gm: Node = root.get_node("GameManager")
	gm.set("selected_char_id", 4)
	gm.set("selected_pet", "hayalet")
	## 1) seçim ekranı, EVCİL sekmesi
	var cs: Node = (load("res://scenes/character_select.tscn") as PackedScene).instantiate()
	root.add_child(cs)
	await _wait(1.2)
	var desk: Node = cs.get("_desk")
	if desk:
		desk.call("_set_tab", "pet")
	await _wait(0.6)
	await _shot("secim")
	cs.queue_free()
	await _wait(0.3)
	## 2) HUD evcil yuvası + fareyle açılan ipucu
	var bg := ColorRect.new()
	bg.color = Color("#4f7a3a")
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var hud: Node = (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	await _wait(0.8)
	var bl: Object = load("res://scripts/balance_log.gd")
	bl.call("reset")
	bl.call("on_gain", "s:evcil_peri", 3120.0, 0.0)
	bl.call("on_prevented", "s:evcil_hayalet", 845.0)
	bl.call("on_hit", "s:matthew_kopek", 18450.0, false)
	var slot: Control = hud.get_node("DockPet") as Control
	for key: String in ["kopek", "papagan", "kelebek", "peri", "kirpi", "slime", "hayalet"]:
		_mouse(Vector2(40, 40))
		await _wait(0.15)
		slot.call("set_pet", key)
		await _wait(0.1)
		var r: Rect2 = slot.get_global_rect()
		await _shot("yuva_" + key, Rect2i(r.grow(6.0)))
		_mouse(r.get_center())
		await _wait(0.45)
		var tip: Control = slot.get("tooltip_panel") as Control
		print("CAP ", key, " tooltip ", tip != null, " hovered ", root.gui_get_hovered_control())
		if tip and key in ["kopek", "peri", "hayalet"]:
			await _shot("ipucu_" + key, Rect2i(tip.get_global_rect().merge(r).grow(12.0)))
	quit()
