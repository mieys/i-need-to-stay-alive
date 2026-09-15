@tool
extends SceneTree

func _init() -> void:
	var hud_scene = load("res://scenes/hud.tscn")
	var hud = hud_scene.instantiate()
	var cc = hud.get_node("BottomBar/CharacterCluster")
	
	var old_hb = cc.get_node("HealthBar")
	old_hb.name = "OldHealthBar"
	
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
	
	old_hb.queue_free()
	
	var old_sb = cc.get_node("ShieldBar")
	old_sb.name = "OldShieldBar"
	
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
	
	old_sb.queue_free()
	
	var err = ResourceSaver.save(hud_scene, "res://scenes/hud.tscn")
	print("Save result: ", err)
	quit()
