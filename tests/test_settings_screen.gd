extends Node

## AYARLAR ekranı + duraklatma (ESC) menüsü "B - Ateş Işığı" (2026-10-17, madde 234): settings_screen.gd, pause_menu.gd,
## fire_menu_kit.gd. Kaydeden UISound / GameManager setter'larından sadece ses yüzdesi ve bir tuş ataması denenir; ikisi de
## assert'ten ÖNCE eski değerine geri yazılır (test yarıda kesilse de kullanıcının ayarı bozulmasın).

const SettingsScreenScript := preload("res://scripts/settings_screen.gd")
const PauseScene := preload("res://scenes/pause_menu.tscn")
const SunCloudsScript := preload("res://scripts/sun_clouds.gd")

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
	assert(_row_ids(s) == ["language", "volume", "music", "fullscreen", "resolution", "fps", "ui_opacity", "shake", "ui_anim", "auto_pick", "player_names", "dmg_numbers", "ally_fx"], "GENEL: %s" % str(_row_ids(s)))
	_push_key(KEY_E)
	assert(int(s.get("_cat")) == 1, "E -> GRAFİK")
	## "sun" satırı yalnız güneş huzmesi ya da bulut gölgesi açıkken (madde 484: ikisi de kapalı -> satır yok).
	var gfx_rows: Array = ["preset", "sun", "ground", "wind_fx", "render_scale", "fps_limit"] if SunCloudsScript.any_enabled() \
			else ["preset", "ground", "wind_fx", "render_scale", "fps_limit"]
	assert(_row_ids(s) == gfx_rows, "GRAFİK: %s" % str(_row_ids(s)))
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


## Rüzgar Efekti (2026-10-21): kalite seviyesinden bağımsız; kapalıyken weather_wind.gd akıntı/yaprakları temizler ve gizlenir.
func test_wind_fx_toggle_clears_the_wind_visual_and_keeps_the_preset() -> void:
	var was_fx: bool = UISound.gfx_wind_fx
	var wind := Node2D.new()
	wind.set_script(preload("res://scripts/weather_wind.gd"))
	add_child(wind)
	wind.set_process(false) ## süre testte elle ilerletilir
	UISound.set_gfx_option("wind_fx", true)
	wind.call("set_wind", 1.0, 0.0, 1.0, 0.0)
	for _i in 180:
		wind.call("_process", 1.0 / 60.0)
	var gusts_on: int = (wind.get("_gusts") as Array).size()
	var leaves_on: int = (wind.get("_leaves") as Array).size()
	var preset_on: int = UISound.gfx_preset
	UISound.set_gfx_option("wind_fx", false)
	wind.call("_process", 1.0 / 60.0)
	var gusts_off: int = (wind.get("_gusts") as Array).size()
	var leaves_off: int = (wind.get("_leaves") as Array).size()
	var shown_off: bool = wind.visible
	var preset_off: int = UISound.gfx_preset
	## Tekrar açınca yeniden doğar.
	UISound.set_gfx_option("wind_fx", true)
	for _i in 180:
		wind.call("_process", 1.0 / 60.0)
	var gusts_back: int = (wind.get("_gusts") as Array).size()
	wind.free()
	UISound.set_gfx_option("wind_fx", was_fx)
	assert(gusts_on > 0 and leaves_on > 0, "açıkken akıntı ve yaprak doğmalı: %d / %d" % [gusts_on, leaves_on])
	assert(gusts_off == 0 and leaves_off == 0 and not shown_off, "kapalıyken hiçbiri kalmamalı ve gizlenmeli")
	assert(preset_off == preset_on, "rüzgar efekti kalite seviyesini değiştirmemeli: %d -> %d" % [preset_on, preset_off])
	assert(gusts_back > 0, "tekrar açılınca akıntı yeniden doğmalı")


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
	_push_action("ui_down") ## ilk satır Dil (madde 446): sesi değiştirmek için bir alta in - Dil'de sola basmak dili değiştirip ayar dosyasına yazar
	_push_action("ui_left")
	var after: float = UISound.master_volume_percent
	UISound.set_master_volume_percent(original)
	assert(is_equal_approx(after, 45.0), "sola = -5: %s" % str(after))
	_cleanup()


## 2026-11-10 oyuncu bildirimi: masaüstü GENEL sekmesi ekrana sığmıyor (~1300 px, tuval 1080) ve kaydırma yoktu, OYUN bölümü
## erişilemiyordu. Satır sütunu artık kaydırma alanında; W/S son satıra inince alan kayar, odaklı satır görünür kalır.
func test_desktop_rows_scroll_and_follow_keyboard_focus() -> void:
	var s := await _open()
	await get_tree().process_frame
	var sc: ScrollContainer = s.find_child("RowsScroll", true, false)
	assert(sc != null, "masaüstünde satırlar kaydırma alanında")
	var rows: Control = s.find_child("Rows", true, false)
	assert(rows != null and rows.get_parent() == sc, "Rows sütunu kaydırma alanının çocuğu")
	assert(sc.position.y + sc.size.y <= SettingsScreenScript.ROWS_BOTTOM + 0.5, "alan klavye ipucu satırlarının üstünde biter")
	assert(rows.size.y > sc.size.y, "GENEL ekrana sığmaz, kaydırma gerekli: %.0f > %.0f" % [rows.size.y, sc.size.y])
	for i in 30:
		_push_action("ui_down")
	await get_tree().process_frame
	await get_tree().process_frame
	var all_rows: Array = s.get("_rows")
	assert(int(s.get("_focus")) == all_rows.size() - 1, "son satıra inildi")
	assert(sc.scroll_vertical > 0, "son satır için alan kaydı")
	var panel: Control = all_rows[all_rows.size() - 1]["panel"]
	var top: float = panel.global_position.y - sc.global_position.y
	assert(top >= -1.0 and top + panel.size.y <= sc.size.y + 1.0, "odaklı son satır alanın içinde: üst %.0f alt %.0f / %.0f" % [top, top + panel.size.y, sc.size.y])
	_push_key(KEY_E)
	assert(sc.scroll_vertical == 0, "yeni sekme en üstten başlar")
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


## Kumanda sütunu dinlerken iptal tuşu yoktu (basılan HER düğme atanır; ESC yalnız klavyede) - denetim 547: 5 sn içinde basış gelmezse
## dinleme kendiliğinden biter; klavye sütunu zaman aşımına uğramaz.
func test_pad_column_listen_times_out_but_keyboard_column_does_not() -> void:
	var action: String = "inventory"
	var s := await _open()
	s.call("_set_category", 2, false)
	var row: Dictionary = {}
	for r: Dictionary in s.get("_rows"):
		if r["id"] == "key_" + action:
			row = r
	assert(not row.is_empty(), "envanter satırı")
	s.call("_start_listen", row, 1)
	assert(str(s.get("_listen_action")) == action and int(s.get("_listen_deadline_ms")) > 0, "kumanda hücresi zaman aşımlı dinler")
	s.call("_process", 0.0)
	assert(str(s.get("_listen_action")) == action, "süre dolmadan dinleme sürer")
	s.set("_listen_deadline_ms", Time.get_ticks_msec() - 1)
	s.call("_process", 0.0)
	assert(str(s.get("_listen_action")) == "", "5 sn basış yoksa dinleme biter, hiçbir düğme atanmaz")
	s.call("_start_listen", row, 0)
	assert(int(s.get("_listen_deadline_ms")) == 0, "klavye hücresinin zaman aşımı yok")
	s.call("_process", 0.0)
	assert(str(s.get("_listen_action")) == action, "klavye dinlemesi bekler")
	s.call("_cancel_listen")
	_cleanup()
