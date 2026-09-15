@tool
extends SceneTree

func _init() -> void:
	var hud_scene = load("res://scenes/hud.tscn")
	var hud = hud_scene.instantiate()
	
	var bot_bar = hud.get_node("BottomBar")
	var cc = bot_bar.get_node("CharacterCluster")
	
	# Strip scripts from the bars
	cc.get_node("HealthBar").set_script(null)
	cc.get_node("ShieldBar").set_script(null)
	
	# Add cute frames for skill icons
	var skill_bar = hud.get_node("SkillBar")
	for icon_name in ["SkillIcon", "Skill2Icon"]:
		var icon = skill_bar.get_node(icon_name)
		var bg_name = "BG"
		if not icon.has_node(bg_name):
			var bg = TextureRect.new()
			bg.name = bg_name
			bg.texture = load("res://assets/generated/cute_ui_skill_slot_frame_0.png")
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.add_child(bg)
			icon.move_child(bg, 0)
			bg.owner = hud

	var packed = PackedScene.new()
	packed.pack(hud)
	ResourceSaver.save(packed, "res://scenes/hud.tscn")
	quit()
