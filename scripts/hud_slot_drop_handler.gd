extends Button

var slot_index: int = 0
var hud: Node = null

func setup(idx: int, p_hud: Node) -> void:
	slot_index = idx
	hud = p_hud

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Dictionary and data.get("type") == "battle_mode":
		var mode_name: String = data.get("mode", "") as String
		return int(GameManager.get("shield_mod_" + mode_name + "_level")) > 0
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var mode_name: String = data.get("mode", "") as String
	
	if not GameManager.has_meta("hud_shield_slots") or GameManager.get_meta("hud_shield_slots") == null:
		GameManager.set_meta("hud_shield_slots", ["", "", "", ""])
		
	var hud_slots: Array = GameManager.get_meta("hud_shield_slots")
	
	# Clear duplicates
	for j in range(hud_slots.size()):
		if hud_slots[j] == mode_name:
			hud_slots[j] = ""
			
	hud_slots[slot_index] = mode_name
	GameManager.set_meta("hud_shield_slots", hud_slots)
	
	if hud and hud.has_method("_refresh_shield_mode_slots"):
		hud._refresh_shield_mode_slots()
