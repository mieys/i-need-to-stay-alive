extends Node

## AYARLAR ekranı + duraklatma (ESC) menüsü "B - Ateş Işığı" (2026-10-17, madde 234): settings_screen.gd, pause_menu.gd,
## fire_menu_kit.gd. Kaydeden UISound / GameManager setter'larından sadece ses yüzdesi ve bir tuş ataması denenir; ikisi de
## assert'ten ÖNCE eski değerine geri yazılır (test yarıda kesilse de kullanıcının ayarı bozulmasın).

const SettingsScreenScript := preload("res://scripts/settings_screen.gd")
const PauseScene := preload("res://scenes/pause_menu.tscn")

var _made: Array[Node] = []


func _cleanup() -> void:
	get_tree().paused = false
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()


func _open() -> Control:
	var s: Control = SettingsScreenScript.new("Geri dön", 0.8)
	add_child(s)
	_made.append(s)
	await get_tree().process_frame
	return s


func _row_ids(s: Control) -> Array:
	var out: Array = []
	for r: Dictionary in s.get("_rows"):
		out.append(r["id"])
	return out


func _push_action(action: String) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		get_viewport().push_input(ev)


func _push_key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		get_viewport().push_input(ev)


func test_categories_build_all_current_settings() -> void:
	var s := await _open()
	assert(_row_ids(s) == ["volume", "music", "fullscreen", "resolution", "fps", "ui_opacity", "shake", "ui_anim", "auto_pick"], "GENEL: %s" % str(_row_ids(s)))
	_push_key(KEY_E)
	assert(int(s.get("_cat")) == 1, "E -> GRAFİK")
	assert(_row_ids(s) == ["preset", "sun", "ground", "render_scale", "fps_limit"], "GRAFİK: %s" % str(_row_ids(s)))
	_push_key(KEY_E)
	assert(_row_ids(s).size() == GameManager.REBINDABLE_ACTIONS.size(), "TUŞLAR: her atanabilir eylem bir satır")
	_push_key(KEY_E)
	assert(int(s.get("_cat")) == 0, "E sona gelince başa döner")
	_push_key(KEY_Q)
	assert(int(s.get("_cat")) == 2, "Q geri")
	_cleanup()


func test_rows_reflect_current_values() -> void:
	var s := await _open()
	var vol: Range = s.find_child("VolumeSlider", true, false)
	assert(vol != null and is_equal_approx(vol.value, UISound.master_volume_percent), "ses kaydırıcısı kayıtlı değeri gösterir")
	var res: Control = s.find_child("ResolutionChoice", true, false)
	assert(res != null and bool(res.get("locked")) == UISound.is_fullscreen, "çözünürlük tam ekranda kilitli")
	var shake_lbl: Label = s.find_child("ShakeValue", true, false)
	var want: String = "Kapalı" if roundi(UISound.camera_shake_percent) == 0 else "%%%d" % roundi(UISound.camera_shake_percent)
	assert(shake_lbl != null and shake_lbl.text == want, "sarsıntı değeri: %s" % (shake_lbl.text if shake_lbl else "yok"))
	_cleanup()


## Müzik Sesi kaydırıcısı (2026-10-19): kayıtlı değeri gösterir, değişince "Music" bus'ını ayarlar, Oyun Sesi'ne dokunmaz.
func test_music_slider_sets_music_bus_only() -> void:
	var original_music: float = UISound.music_volume_percent
	var original_master: float = UISound.master_volume_percent
	var s := await _open()
	var mus: Range = s.find_child("MusicSlider", true, false)
	assert(mus != null and is_equal_approx(mus.value, UISound.music_volume_percent), "müzik kaydırıcısı kayıtlı değeri gösterir")
	mus.value = 40.0
	var bus_idx: int = AudioServer.get_bus_index("Music")
	var db: float = AudioServer.get_bus_volume_db(bus_idx) if bus_idx >= 0 else 99.0
	var music_now: float = UISound.music_volume_percent
	var master_now: float = UISound.master_volume_percent
	UISound.set_music_volume_percent(original_music)
	assert(bus_idx >= 0, "Music bus'ı kurulmuş olmalı")
	assert(is_equal_approx(music_now, 40.0), "müzik yüzdesi: %s" % str(music_now))
	assert(absf(db - linear_to_db(0.4)) < 0.01, "bus dB: %s" % str(db))
	assert(is_equal_approx(master_now, original_master), "Oyun Sesi değişmemeli")
	_cleanup()


func test_keyboard_moves_focus_and_steps_slider() -> void:
	var original: float = UISound.master_volume_percent
	var s := await _open()
	assert(int(s.get("_focus")) == 0, "ilk satır seçili")
	_push_action("ui_down")
	_push_action("ui_down")
	assert(int(s.get("_focus")) == 2, "aşağı iki satır")
	_push_action("ui_up")
	_push_action("ui_up")
	_push_action("ui_up")
	assert(int(s.get("_focus")) == 0, "en üstte kalır")
	UISound.set_master_volume_percent(50.0)
	(s.call("_sync_all"))
	_push_action("ui_left")
	var after: float = UISound.master_volume_percent
	UISound.set_master_volume_percent(original)
	assert(is_equal_approx(after, 45.0), "sola = -5: %s" % str(after))
	_cleanup()


func test_escape_closes_settings_and_marks_cancel_consumed() -> void:
	var s := await _open()
	var closed := [false]
	s.connect("closed", func() -> void: closed[0] = true)
	_push_action("ui_cancel")
	assert(closed[0], "ESC ayarları kapatır")
	assert(GameManager.was_ui_cancel_consumed(), "aynı basış duraklatma menüsünü de kapatmasın")
	_cleanup()


func test_keybind_listen_and_escape_cancels() -> void:
	var action: String = "inventory"
	var original: int = GameManager.get_keybind_keycode(action)
	var s := await _open()
	s.call("_set_category", 2, false)
	var idx := -1
	var rows: Array = s.get("_rows")
	for i in rows.size():
		if rows[i]["id"] == "key_" + action:
			idx = i
	assert(idx >= 0, "envanter satırı")
	s.set("_focus", idx)
	_push_action("ui_accept")
	assert(str(s.get("_listen_action")) == action, "Enter klavye hücresini dinlemeye alır")
	_push_key(KEY_ESCAPE)
	assert(str(s.get("_listen_action")) == "" and is_instance_valid(s) and not s.is_queued_for_deletion(), "ESC sadece dinlemeyi iptal eder")
	_push_action("ui_accept")
	var new_key: Key = KEY_F7 if original != KEY_F7 else KEY_F8
	_push_key(new_key)
	var got: int = GameManager.get_keybind_keycode(action)
	GameManager.set_keybind_override(action, original)
	assert(got == new_key, "yeni tuş atandı: %s" % OS.get_keycode_string(got))
	_cleanup()


func test_pause_menu_builds_fire_items_and_settings_escape_keeps_it_open() -> void:
	var pm: Node = PauseScene.instantiate()
	add_child(pm)
	_made.append(pm)
	await get_tree().process_frame
	for n: String in ["ResumeButton", "SettingsButton", "RestartButton", "MenuButton"]:
		assert(pm.find_child(n, true, false) is Button, "öğe: %s" % n)
	var title: Label = pm.find_child("Title", true, false)
	assert(title != null and title.text == "DURAKLATILDI", "tek oyunculu başlık")
	get_tree().paused = true ## tek oyunculu ESC yolu: menünün kendi _process'i
	pm.call("_on_settings_pressed")
	await get_tree().process_frame
	assert(pm.call("get_settings_screen") != null, "ayarlar açıldı")
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var rel := InputEventAction.new()
	rel.action = "ui_cancel"
	rel.pressed = false
	Input.parse_input_event(rel)
	await get_tree().process_frame
	assert(is_instance_valid(pm) and not pm.is_queued_for_deletion(), "ayarlardaki ESC duraklatma menüsünü kapatmamalı")
	assert(pm.call("get_settings_screen") == null, "ESC ayarları kapattı")
	assert((pm.find_child("MainView", true, false) as Control).visible, "ana görünüm geri geldi")
	_cleanup()


func test_mouse_click_sets_slider_and_locked_choice_ignores() -> void:
	var original: float = UISound.master_volume_percent
	var s := await _open()
	var vol: Range = s.find_child("VolumeSlider", true, false)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(vol.size.x * 0.5, vol.size.y * 0.5)
	vol.call("_gui_input", ev)
	var after: float = UISound.master_volume_percent
	UISound.set_master_volume_percent(original)
	assert(absf(after - 50.0) <= 2.0, "kaydırıcının ortasına tıklama ~%%50: %s" % str(after))
	var res: Control = s.find_child("ResolutionChoice", true, false)
	res.call("set_state", int(res.get("index")), "", true)
	var before: int = int(res.get("index"))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(res.size.x - 4.0, res.size.y * 0.5)
	res.call("_gui_input", click)
	assert(int(res.get("index")) == before, "kilitli seçim tıklamayla değişmez")
	_cleanup()
