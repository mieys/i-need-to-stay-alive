extends CanvasLayer

## REKORLAR + BAŞARIMLAR ekranı (kullanıcı isteği 2026-10-05, öneri 3). Ana menüdeki "REKORLAR" düğmesi açar (graphics_settings_
## menu.gd ile AYNI "kendi penceresi olan, kodla kurulan popup" deseni: signal closed, ui_cancel kapatır, kumanda odağı).
## Veri tek yerde: run_records.gd (rekorlar + açılmış başarımlar), katalog achievements.gd. Ana menünün bej MenuKit diliyle.

signal closed

const RunRecordsScript: GDScript = preload("res://scripts/run_records.gd")
const AchievementsScript: GDScript = preload("res://scripts/achievements.gd")
const RunSummaryUIScript: GDScript = preload("res://scripts/run_summary_ui.gd")
const TierDisplayScript: GDScript = preload("res://scripts/tier_display.gd")

var _close_btn: Button = null


func _ready() -> void:
	add_to_group(&"gamepad_modal") ## kumandayla menü gezinmesi: açılınca ilk düğmeye odak (bkz. gamepad_ui.gd)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 95
	_build_ui()
	if _close_btn:
		_close_btn.grab_focus()


func _build_ui() -> void:
	var data: Dictionary = RunRecordsScript.load_all()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = MenuKit.theme()
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.20, 0.11, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var box := MenuKit.make_panel("panel")
	box.custom_minimum_size = Vector2(900, 0)
	center.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	box.add_child(v)

	v.add_child(MenuKit.make_section_header("Rekorlar", MenuKit.FS_TITLE))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 48)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	var rows: Array = [
		["En uzun süre", _time_or_dash(float(data["best_time"]))],
		["En yüksek kademe", TierDisplayScript.to_roman(int(data["best_tier"]))], ## Romen rakamı; 0 -> "-"
		["Tek koşuda en çok öldürme", _num_or_dash(int(data["best_kills"]))],
		["En yüksek sonsuz kat", _num_or_dash(int(data["best_layer"]))],
		["En hızlı zafer", _time_or_dash(float(data["best_victory_time"]))],
		["Zafer sayısı", str(int(data["victories"]))],
		["Toplam koşu", str(int(data["runs"]))],
		["Toplam öldürme", str(int(data["total_kills"]))],
	]
	for r: Array in rows:
		var name_lbl: Label = MenuKit.make_label(str(r[0]), MenuKit.FS_BODY, MenuKit.C_TEXT)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_lbl)
		grid.add_child(MenuKit.make_label(str(r[1]), MenuKit.FS_BODY, MenuKit.C_ACCENT, HORIZONTAL_ALIGNMENT_RIGHT))

	var unlocked: Dictionary = data["achievements"]
	v.add_child(MenuKit.make_section_header("Başarımlar  %d / %d" % [unlocked.size(), AchievementsScript.DEFS.size()], MenuKit.FS_BODY))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for d: Dictionary in AchievementsScript.DEFS:
		var done: bool = unlocked.has(str(d["id"]))
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		list.add_child(row)
		var title: Label = MenuKit.make_label(("[X] " if done else "[ ] ") + str(d["name"]), MenuKit.FS_BODY,
				MenuKit.C_GOOD if done else MenuKit.C_TEXT_DIM)
		row.add_child(title)
		var desc: Label = MenuKit.make_label("      " + str(d["desc"]), MenuKit.FS_SMALL, MenuKit.C_TEXT_DIM)
		row.add_child(desc)

	_close_btn = MenuKit.make_button("KAPAT", "sage", MenuKit.FS_BODY, 52)
	_close_btn.pressed.connect(_on_close_pressed)
	v.add_child(_close_btn)
	UISound.connect_all_buttons(self)


func _time_or_dash(seconds: float) -> String:
	return RunSummaryUIScript.format_time(seconds) if seconds > 0.0 else "-"


func _num_or_dash(n: int) -> String:
	return str(n) if n > 0 else "-"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
