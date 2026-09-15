@tool
extends SceneTree

func _init() -> void:
	var hud_scene = load("res://scenes/hud.tscn")
	var hud = hud_scene.instantiate()
	
	var bottom_bar = hud.get_node("BottomBar")
	var char_cluster = bottom_bar.get_node("CharacterCluster")
	
	# We will restructure CharacterCluster to use standard Control nodes instead of sprite_bar
	
	# 1. Clear out old textures from HealthBar / ShieldBar so they don't draw anything
	var hb = char_cluster.get_node("HealthBar")
	hb.set_script(null) # Remove sprite_bar.gd
	hb.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hb.position = Vector2(100, 70)
	hb.size = Vector2(192, 64)
	
	var sb = char_cluster.get_node("ShieldBar")
	sb.set_script(null)
	sb.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	sb.position = Vector2(400, 70)
	sb.size = Vector2(192, 64)
	
	# Create TextureProgressBars as children of HB/SB, and a small script to forward set_value
	var shim_script = GDScript.new()
	shim_script.source_code = "extends TextureProgressBar\nfunc set_value(v: float, mv: float) -> void:\n\tmax_value = max(mv, 0.001)\n\tvalue = v"
	shim_script.reload()
	
	# Health ProgressBar
	var hb_bg = TextureRect.new()
	hb_bg.name = "BG"
	hb_bg.texture = load("res://assets/generated/cute_ui_bar_frame_frame_0.png")
	hb.add_child(hb_bg)
	hb_bg.owner = hud
	
	var hp_prog = TextureProgressBar.new()
	hp_prog.name = "Prog"
	hp_prog.texture_progress = load("res://assets/generated/health_fill_cute_frame_0.png")
	hp_prog.nine_patch_stretch = true
	hp_prog.stretch_margin_left = 4
	hp_prog.stretch_margin_right = 4
	hp_prog.stretch_margin_top = 4
	hp_prog.stretch_margin_bottom = 4
	hp_prog.position = Vector2(12, 12)
	hp_prog.size = Vector2(168, 40)
	hp_prog.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
	hp_prog.set_script(shim_script)
	hb.add_child(hp_prog)
	hp_prog.owner = hud
	
	# Update hud.gd to point to Prog? No, we can just put the shim on HealthBar directly!
	# Wait, if HealthBar is just a Control, we can't make it a TextureProgressBar easily without replacing the node.
	# Godot lets you change a node's class by replacing it or just instantiating a new one and renaming.
	
	var new_hb = TextureProgressBar.new()
	new_hb.name = "HealthBar"
	new_hb.texture_under = load("res://assets/generated/cute_ui_bar_frame_frame_0.png")
	new_hb.texture_progress = load("res://assets/generated/health_fill_cute_frame_0.png")
	new_hb.nine_patch_stretch = true
	new_hb.stretch_margin_left = 12
	new_hb.stretch_margin_right = 12
	new_hb.stretch_margin_top = 12
	new_hb.stretch_margin_bottom = 12
	new_hb.texture_progress_offset = Vector2(12, 12) # Doesn't stretch progress texture though.
	
	quit()
