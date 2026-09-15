extends Button

var mode_name: String = ""
var texture: Texture2D = null

func setup(p_mode: String, p_tex: Texture2D) -> void:
	mode_name = p_mode
	texture = p_tex

func _get_drag_data(_at_position: Vector2) -> Variant:
	var lvl: int = int(GameManager.get("shield_mod_" + mode_name + "_level"))
	if lvl <= 0:
		return null
		
	var preview: TextureRect = TextureRect.new()
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(50, 50)
	if is_inside_tree():
		set_drag_preview(preview)
	
	return {"type": "battle_mode", "mode": mode_name}
