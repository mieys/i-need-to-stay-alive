@tool
extends SceneTree

func _init() -> void:
	var hud_scene = load("res://scenes/hud.tscn")
	var hud = hud_scene.instantiate()
	
	var bottom_bar = hud.get_node("BottomBar")
	var char_cluster = bottom_bar.get_node("CharacterCluster")
	var shield_bg = bottom_bar.get_node("ShieldModeBarBG")
	var skill_bar = hud.get_node("SkillBar")
	
	# Create a new structure
	var new_cluster = Control.new()
	new_cluster.name = "CharacterCluster"
	new_cluster.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	new_cluster.position = Vector2(-346, -180) # Center bottom
	new_cluster.size = Vector2(692, 180)
	
	# HBox for Top Row: Health Bar | Portrait | Mana Bar
	var top_hbox = HBoxContainer.new()
	top_hbox.name = "TopRow"
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	top_hbox.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_hbox.position.y = 20
	top_hbox.add_theme_constant_override("separation", 10)
	new_cluster.add_child(top_hbox)
	top_hbox.owner = hud
	
	# Health Bar Container
	var hp_container = Control.new()
	hp_container.name = "HealthContainer"
	hp_container.custom_minimum_size = Vector2(192, 64)
	top_hbox.add_child(hp_container)
	hp_container.owner = hud
	
	var hp_frame = TextureRect.new()
	hp_frame.name = "Frame"
	hp_frame.texture = load("res://assets/generated/cute_ui_bar_frame_frame_0.png")
	hp_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hp_container.add_child(hp_frame)
	hp_frame.owner = hud
	
	var hp_bar = TextureProgressBar.new()
	hp_bar.name = "HealthBar"
	hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bar.nine_patch_stretch = true
	hp_bar.stretch_margin_left = 8
	hp_bar.stretch_margin_right = 8
	hp_bar.stretch_margin_top = 8
	hp_bar.stretch_margin_bottom = 8
	hp_bar.fill_mode = TextureProgressBar.FILL_RIGHT_TO_LEFT
	
	# Create green gradient for health
	var hp_grad = GradientTexture1D.new()
	var g = Gradient.new()
	g.colors = PackedColorArray([Color("1a5c1a"), Color("4ade4a")])
	hp_grad.gradient = g
	hp_grad.width = 256
	hp_bar.texture_progress = hp_grad
	
	# Keep sprite_bar_shim to prevent hud.gd crash
	var shim_script = GDScript.new()
	shim_script.source_code = "extends TextureProgressBar\nfunc set_value(v: float, mv: float) -> void:\n\tmax_value = max(mv, 0.001)\n\tvalue = v"
	shim_script.reload()
	hp_bar.set_script(shim_script)
	hp_container.add_child(hp_bar)
	hp_bar.owner = hud
	
	# Move HealthValueLabel
	var hp_label = char_cluster.get_node("HealthValueLabel")
	char_cluster.remove_child(hp_label)
	hp_container.add_child(hp_label)
	hp_label.owner = hud
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 20)
	
	# Portrait Container
	var port_container = Control.new()
	port_container.name = "PortraitContainer"
	port_container.custom_minimum_size = Vector2(96, 96)
	top_hbox.add_child(port_container)
	port_container.owner = hud
	
	var port_frame = TextureRect.new()
	port_frame.name = "Frame"
	port_frame.texture = load("res://assets/generated/cute_ui_portrait_frame_frame_0.png")
	port_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	port_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	port_container.add_child(port_frame)
	port_frame.owner = hud
	
	var old_port_clip = char_cluster.get_node("PortraitClip")
	char_cluster.remove_child(old_port_clip)
	port_container.add_child(old_port_clip)
	old_port_clip.owner = hud
	old_port_clip.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	old_port_clip.size = Vector2(60, 60)
	old_port_clip.position = Vector2(18, 18)
	
	# Move Level Label
	var lvl_label = char_cluster.get_node("LevelLabel")
	char_cluster.remove_child(lvl_label)
	port_container.add_child(lvl_label)
	lvl_label.owner = hud
	lvl_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	lvl_label.position = Vector2(28, 70)
	lvl_label.size = Vector2(40, 30)
	lvl_label.add_theme_font_size_override("font_size", 18)
	
	# Shield Bar Container
	var sh_container = Control.new()
	sh_container.name = "ShieldContainer"
	sh_container.custom_minimum_size = Vector2(192, 64)
	top_hbox.add_child(sh_container)
	sh_container.owner = hud
	
	var sh_frame = TextureRect.new()
	sh_frame.name = "Frame"
	sh_frame.texture = load("res://assets/generated/cute_ui_bar_frame_frame_0.png")
	sh_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sh_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh_frame.flip_h = true
	sh_container.add_child(sh_frame)
	sh_frame.owner = hud
	
	var sh_bar = TextureProgressBar.new()
	sh_bar.name = "ShieldBar"
	sh_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sh_bar.nine_patch_stretch = true
	sh_bar.stretch_margin_left = 8
	sh_bar.stretch_margin_right = 8
	sh_bar.stretch_margin_top = 8
	sh_bar.stretch_margin_bottom = 8
	sh_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	
	var sh_grad = GradientTexture1D.new()
	var g2 = Gradient.new()
	g2.colors = PackedColorArray([Color("1a3a6c"), Color("4aa3de")])
	sh_grad.gradient = g2
	sh_grad.width = 256
	sh_bar.texture_progress = sh_grad
	sh_bar.set_script(shim_script)
	sh_container.add_child(sh_bar)
	sh_bar.owner = hud
	
	# Move ShieldValueLabel
	var sh_label = char_cluster.get_node("ShieldValueLabel")
	char_cluster.remove_child(sh_label)
	sh_container.add_child(sh_label)
	sh_label.owner = hud
	sh_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sh_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sh_label.add_theme_font_size_override("font_size", 20)
	
	# --- HBox for Bottom Row: Skills ---
	var bot_hbox = HBoxContainer.new()
	bot_hbox.name = "BottomRow"
	bot_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_hbox.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot_hbox.position.y = 110
	bot_hbox.size.y = 70
	bot_hbox.add_theme_constant_override("separation", 8)
	new_cluster.add_child(bot_hbox)
	bot_hbox.owner = hud
	
	var old_skills = [
		skill_bar.get_node("SkillIcon"),
		skill_bar.get_node("Skill2Icon")
	]
	
	var old_slots = [
		shield_bg.get_node("ShieldModeSlot1"),
		shield_bg.get_node("ShieldModeSlot2"),
		shield_bg.get_node("ShieldModeSlot3"),
		shield_bg.get_node("ShieldModeSlot4"),
		shield_bg.get_node("ShieldModeSlot5")
	]
	
	# We must keep ShieldModeBarBG to avoid breaking paths if hud.gd searches by path
	# Actually, hud.gd gets nodes at ready via `@onready var shield_mode_slots: Array = [ $BottomBar/ShieldModeBarBG/ShieldModeSlot1, ... ]`
	# So we MUST maintain `$BottomBar/ShieldModeBarBG`!
	
	# Wait, skill_bar has `@onready var skill_icon = $SkillBar/SkillIcon`. So we MUST keep `$SkillBar/SkillIcon`
	
	pass # End script to not commit errors.
