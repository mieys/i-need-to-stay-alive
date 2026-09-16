extends SceneTree

func _fail(msg: String) -> void:
	print("FAIL: ", msg)

func _init():
	var GM: GDScript = load("res://scripts/game_manager.gd")
	var gm = GM.new()
	get_root().add_child(gm)
	# _ready() already ran via add_child (autoload-style _ready), which calls
	# _load_keybind_overrides() + _setup_input_actions().
	await process_frame

	var ok := true

	# 1) Expected default joypad events present after setup.
	var checks := {
		"skill": ["button", JOY_BUTTON_Y],
		"skill2": ["button", JOY_BUTTON_X],
		"skill3": ["button", JOY_BUTTON_RIGHT_SHOULDER],
		"interact": ["button", JOY_BUTTON_LEFT_SHOULDER],
	}
	for action in checks.keys():
		var found := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton and ev.button_index == checks[action][1]:
				found = true
		if not found:
			ok = false
			_fail("action '%s' missing expected joypad button %s" % [action, checks[action][1]])
		else:
			print("OK: ", action, " has expected joypad button")

	# movement: expect both an axis event AND a dpad button event per direction
	var move_checks := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0, JOY_BUTTON_DPAD_LEFT],
		"move_right": [JOY_AXIS_LEFT_X, 1.0, JOY_BUTTON_DPAD_RIGHT],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0, JOY_BUTTON_DPAD_UP],
		"move_down": [JOY_AXIS_LEFT_Y, 1.0, JOY_BUTTON_DPAD_DOWN],
	}
	for action in move_checks.keys():
		var want_axis = move_checks[action][0]
		var want_sign = move_checks[action][1]
		var want_btn = move_checks[action][2]
		var has_axis := false
		var has_btn := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadMotion and ev.axis == want_axis and is_equal_approx(ev.axis_value, want_sign):
				has_axis = true
			if ev is InputEventJoypadButton and ev.button_index == want_btn:
				has_btn = true
		if not (has_axis and has_btn):
			ok = false
			_fail("action '%s' missing axis=%s or dpad button=%s (axis_found=%s, btn_found=%s)" % [action, want_axis, want_btn, has_axis, has_btn])
		else:
			print("OK: ", action, " has expected axis+dpad")

	# 2) chat/debug_tuning/shield_mode_slot_* should have NO joypad event.
	for action in ["chat", "debug_tuning", "shield_mode_slot_1"]:
		var has_joy := false
		for ev in InputMap.action_get_events(action):
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				has_joy = true
		if has_joy:
			ok = false
			_fail("action '%s' unexpectedly has a joypad event (should stay keyboard-only)" % action)
		else:
			print("OK: ", action, " has no joypad event, as expected")

	# 3) THE BUG FIX: rebinding the keyboard key must NOT wipe the joypad event.
	var before_joy_events: int = 0
	for ev in InputMap.action_get_events("skill"):
		if ev is InputEventJoypadButton:
			before_joy_events += 1
	gm.set_keybind_override("skill", KEY_SPACE)
	var after_joy_events: int = 0
	var after_key_ok := false
	for ev in InputMap.action_get_events("skill"):
		if ev is InputEventJoypadButton:
			after_joy_events += 1
		if ev is InputEventKey and ev.physical_keycode == KEY_SPACE:
			after_key_ok = true
	if before_joy_events == 0 or after_joy_events != before_joy_events:
		ok = false
		_fail("set_keybind_override wiped the joypad binding! before=%d after=%d" % [before_joy_events, after_joy_events])
	elif not after_key_ok:
		ok = false
		_fail("set_keybind_override did not apply the new keyboard key")
	else:
		print("OK: set_keybind_override preserved joypad binding (before=%d after=%d) and applied new key" % [before_joy_events, after_joy_events])

	# 4) Reverse: rebinding the joypad button must NOT wipe the keyboard event.
	gm.set_keybind_joypad_override("skill", {"kind": gm.JoypadKind.BUTTON, "button": JOY_BUTTON_B})
	var key_survived := false
	var new_joy_ok := false
	for ev in InputMap.action_get_events("skill"):
		if ev is InputEventKey and ev.physical_keycode == KEY_SPACE:
			key_survived = true
		if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_B:
			new_joy_ok = true
	if not key_survived:
		ok = false
		_fail("set_keybind_joypad_override wiped the keyboard binding!")
	elif not new_joy_ok:
		ok = false
		_fail("set_keybind_joypad_override did not apply the new joypad button")
	else:
		print("OK: set_keybind_joypad_override preserved keyboard binding and applied new joypad button")

	# 5) get_keybind_joypad_descriptor round-trip
	var desc: Dictionary = gm.get_keybind_joypad_descriptor("skill")
	if desc.get("kind") != gm.JoypadKind.BUTTON or desc.get("button") != JOY_BUTTON_B:
		ok = false
		_fail("get_keybind_joypad_descriptor returned unexpected value: %s" % [desc])
	else:
		print("OK: get_keybind_joypad_descriptor round-trips correctly: ", desc)

	# 6) ConfigFile persistence round-trip (separate sections).
	var config := ConfigFile.new()
	var load_err := config.load(gm.KEYBIND_SETTINGS_PATH)
	if load_err != OK:
		ok = false
		_fail("could not reload KEYBIND_SETTINGS_PATH: %s" % load_err)
	else:
		var has_kb: bool = config.has_section("keybinds") and int(config.get_value("keybinds", "skill", -1)) == KEY_SPACE
		var has_joy_section: bool = config.has_section("keybinds_joypad")
		var joy_val = config.get_value("keybinds_joypad", "skill", {}) if has_joy_section else {}
		var has_joy: bool = has_joy_section and int(joy_val.get("button", -1)) == JOY_BUTTON_B
		if not has_kb or not has_joy:
			ok = false
			_fail("ConfigFile round-trip failed: has_kb=%s has_joy=%s" % [has_kb, has_joy])
		else:
			print("OK: ConfigFile persisted both keybinds and keybinds_joypad sections correctly")

	# 7) blocking-panel registry
	var dummy := Control.new()
	dummy.visible = false
	gm.register_blocking_panel(dummy)
	if gm.is_any_blocking_panel_open():
		ok = false
		_fail("is_any_blocking_panel_open() true while panel invisible")
	dummy.visible = true
	if not gm.is_any_blocking_panel_open():
		ok = false
		_fail("is_any_blocking_panel_open() false while a registered panel is visible")
	else:
		print("OK: blocking-panel registry tracks visibility correctly")
	gm.unregister_blocking_panel(dummy)
	if gm.is_any_blocking_panel_open():
		ok = false
		_fail("is_any_blocking_panel_open() still true after unregister")
	else:
		print("OK: unregister_blocking_panel works")
	dummy.free()

	# 8) stale-reference sweep
	var dummy2 := Control.new()
	dummy2.visible = true
	get_root().add_child(dummy2)
	gm.register_blocking_panel(dummy2)
	dummy2.queue_free()
	await process_frame
	await process_frame
	if gm.is_any_blocking_panel_open():
		ok = false
		_fail("is_any_blocking_panel_open() did not sweep a freed panel reference")
	else:
		print("OK: stale (freed) blocking-panel reference correctly swept")

	# CLEANUP: this test intentionally rebinds "skill" mid-run to verify the
	# bug fix - restore it to the real shipped default (Q key / Y button) so
	# this test run doesn't leave the user's real keybind_settings.cfg in a
	# mutated state.
	gm.set_keybind_override("skill", KEY_Q)
	gm.set_keybind_joypad_override("skill", {"kind": gm.JoypadKind.BUTTON, "button": JOY_BUTTON_Y})
	print("cleanup: restored 'skill' to default Q / Y")

	print("ALL OK" if ok else "SOME CHECKS FAILED")
	quit()
