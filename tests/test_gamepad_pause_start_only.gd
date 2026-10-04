extends Node

## Kullanıcı isteği (2026-10-04): "joystickteki oyun durdurma tuşunun sadece start tuşu olmasını istiyorum başka bi tuş daha oyunu
## durduruyor". Duraklatma artık "pause_game" eylemi (Esc + kumanda Start); kumanda B'si sadece menülerde "geri" (ui_cancel).


func _joy_buttons(action: String) -> Array:
	var out: Array = []
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton:
			out.append((ev as InputEventJoypadButton).button_index)
	return out


func test_pause_game_is_start_only_on_gamepad() -> void:
	assert(InputMap.has_action("pause_game"), "pause_game eylemi tanımlı")
	assert(_joy_buttons("pause_game") == [JOY_BUTTON_START], "kumandada duraklatma sadece Start: %s" % str(_joy_buttons("pause_game")))
	var has_esc: bool = false
	for ev in InputMap.action_get_events("pause_game"):
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_ESCAPE:
			has_esc = true
	assert(has_esc, "klavyede Esc duraklatmaya devam eder")


func test_b_button_is_back_only() -> void:
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	assert(InputMap.event_is_action(b, "ui_cancel"), "B menülerde geri (ui_cancel)")
	assert(not InputMap.event_is_action(b, "pause_game"), "B oyunu duraklatmaz")
	var st := InputEventJoypadButton.new()
	st.button_index = JOY_BUTTON_START
	st.pressed = true
	assert(InputMap.event_is_action(st, "pause_game"), "Start duraklatır")
	assert(InputMap.event_is_action(st, "ui_cancel"), "Start açık panelleri de kapatmaya devam eder")
