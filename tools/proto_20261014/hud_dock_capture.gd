extends SceneTree

## Mevcut oyuncu panelini (dock) gerçek çizicide yakalar + düğüm dikdörtgenlerini yazar (prototip ölçüleri için).
## Kullanım: Godot --path . --windowed --resolution 1920x1080 -s tools/proto_20261014/hud_dock_capture.gd

const OUT := "res://tools/proto_20261014/out/"


func _initialize() -> void:
	_run.call_deferred()


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _run() -> void:
	await process_frame
	var gm: Node = root.get_node("GameManager")
	gm.set("selected_char_id", int(OS.get_environment("CAP_CHAR")) if OS.get_environment("CAP_CHAR") != "" else 0)
	gm.set("selected_spiritual", "can")
	gm.set("selected_pet", "peri")
	var n_legend: int = int(OS.get_environment("CAP_LEGEND")) if OS.get_environment("CAP_LEGEND") != "" else 2
	var keys: Array = ["anka_kusunun_kalbi", "ilidaricin_kilici", "son_felaket_pencesi", "kralin_kadehi", "zaman_kiran"]
	var owned: Array = [{"key": "ruzgar_eldiveni"}]
	for i in n_legend:
		owned.append({"key": keys[i]})
	var late: bool = OS.get_environment("CAP_LATE") == "1"
	if not late:
		gm.set("owned_items", owned)
	var shield: String = OS.get_environment("CAP_SHIELD")
	if shield == "standart":
		gm.set("shield_standart_level", 1)
	elif shield != "":
		gm.set("shield_enchant", "shield_" + shield)
		gm.set("shield_enchant_ups", [2, 1, 0])
	var bg := ColorRect.new()
	bg.color = Color("#4f7a3a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var hud: Node = (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	await _wait(0.5)
	if late:
		gm.set("owned_items", owned)
		await _wait(0.6)
	var low: bool = OS.get_environment("CAP_LOW") == "1"
	hud.call("update_health", 312.0 if low else 1284.0, 2150.0)
	hud.call("_on_item_shield_changed", 0.0 if low else 356.0, 900.0)
	hud.call("update_level", 12)
	hud.get_node("ReviveHearts").call("set_revives", 0 if low else 2)
	if low:
		gm.set("revives_remaining", 0)
		gm.get("_revive_regen_left")[0] = 187.0
		hud.get_node("SkillBar/SkillIcon").call("update_state", 0.4, false, 8.0, 0.0)
	await _wait(0.8)
	if low:
		gm.get("_revive_regen_left")[0] = 187.0
		await process_frame
		await process_frame
	for p: String in ["DockFrame", "DockLegend", "DockPet", "DockDivider", "ReviveHearts", "SkillBar", "SkillBar/PassiveIcon", "SkillBar/SkillIcon",
			"SkillBar/Skill2Icon", "SkillBar/Skill3Icon", "CharacterCluster/DockHpBar", "CharacterCluster/DockShieldBar",
			"CharacterCluster/PortraitFrame", "CharacterCluster/LevelBadge"]:
		var c: Control = hud.get_node_or_null(p) as Control
		if c:
			print("RECT ", p, " ", c.get_global_rect(), " scale ", c.get_global_transform().get_scale(), " vis ", c.is_visible_in_tree())
	for c: Node in hud.get_node("SkillBar").get_children():
		if c is Control:
			print("SB ", c.name, " ", (c as Control).get_global_rect(), " vis ", (c as Control).visible)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	print("IMG ", img.get_size())
	img.save_png(ProjectSettings.globalize_path(OUT + ("oyun_%s%s.png" % ["az" if low else "normal", ("_" + shield) if shield != "" else ""])))
	quit()
