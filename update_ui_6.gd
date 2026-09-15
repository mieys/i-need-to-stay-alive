@tool
extends SceneTree

func _init() -> void:
	var hud_scene = load("res://scenes/hud.tscn")
	var hud = hud_scene.instantiate()
	var bot_bar = hud.get_node("BottomBar")
	var cc = bot_bar.get_node("CharacterCluster")
	
	var old_hb = cc.get_node("HealthBar")
	cc.remove_child(old_hb)
	old_hb.free()
	
	var new_hb = TextureProgressBar.new()
	new_hb.name = "HealthBar"
	new_hb.texture_under = load("res://assets/generated/cute_ui_bar_frame_frame_0.png")
	new_hb.texture_progress = load("res://assets/generated/health_fill_cute_frame_0.png")
	new_hb.nine_patch_stretch = true
	new_hb.stretch_margin_left = 6
	new_hb.stretch_margin_right = 6
	new_hb.stretch_margin_top = 6
	new_hb.stretch_margin_bottom = 6
	new_hb.texture_progress_offset = Vector2(6, 6)
	new_hb.position = Vector2(0, 20)
	new_hb.size = Vector2(192, 64)
	new_hb.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
	
	cc.add_child(new_hb)
	new_hb.owner = hud
	
	var old_sb = cc.get_node("ShieldBar")
	cc.remove_child(old_sb)
	old_sb.free()
	
	var new_sb = TextureProgressBar.new()
	new_sb.name = "ShieldBar"
	new_sb.texture_under = load("res://assets/generated/cute_ui_bar_frame_frame_0.png")
	new_sb.texture_progress = load("res://assets/generated/shield_fill_cute_frame_0.png")
	new_sb.nine_patch_stretch = true
	new_sb.stretch_margin_left = 6
	new_sb.stretch_margin_right = 6
	new_sb.stretch_margin_top = 6
	new_sb.stretch_margin_bottom = 6
	new_sb.texture_progress_offset = Vector2(6, 6)
	new_sb.position = Vector2(308, 20)
	new_sb.size = Vector2(192, 64)
	new_sb.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	
	cc.add_child(new_sb)
	new_sb.owner = hud

	# Adjust labels
	var hl = cc.get_node("HealthValueLabel")
	hl.position = Vector2(0, 20)
	hl.size = Vector2(192, 64)
	hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hl.add_theme_font_size_override("font_size", 18)
	hl.add_theme_color_override("font_color", Color("f5f5f5"))
	
	var sl = cc.get_node("ShieldValueLabel")
	sl.position = Vector2(308, 20)
	sl.size = Vector2(192, 64)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sl.add_theme_font_size_override("font_size", 18)
	sl.add_theme_color_override("font_color", Color("f5f5f5"))
	
	var packed = PackedScene.new()
	packed.pack(hud)
	var err = ResourceSaver.save(packed, "res://scenes/hud.tscn")
	print("Save result: ", err)
	quit()
