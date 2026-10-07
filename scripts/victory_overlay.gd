extends CanvasLayer

## ZAFER penceresi (kullanıcı isteği 2026-10-05: Final'in 13 bossunu yenince "Hayatta Kaldın" + "Sonsuza Devam Et").
## main.gd, NetworkManager.victory_reached geldiğinde (HER peer'de) kurar. Dünya arkada görünür kalır (ölüm ekranıyla AYNI
## yarı saydam desen) ve OYUN DURMAZ - çok oyunculuda bir peer'in duraklaması herkesi durduramaz, zaten yaratıklar dağıldı ve
## doğuş durdu (bkz. enemy_spawner.gd _begin_victory), oyuncular dropları toplayabilir.
## Devam kararını SADECE host (ya da tek oyunculu) verir: "Sonsuza Devam Et" -> continue_pressed. İstemcide düğme yerine
## "host karar veriyor" yazısı çıkar; herkes "Ana Menü" ile ayrılabilir. Pencere endless_started gelince main.gd tarafından kapatılır.

signal continue_pressed
signal menu_pressed

const RunSummaryUIScript: GDScript = preload("res://scripts/run_summary_ui.gd")

var _summary: Dictionary = {}
var _is_host: bool = true
var _solo: bool = true
var _grid: GridContainer = null
var _extras_slot: VBoxContainer = null
var _continue_btn: Button = null
var _menu_btn: Button = null
var _wait_label: Label = null


## add_child'dan ÖNCE çağrılır (arayüz _ready'de bu değerlerle kurulur).
func setup(summary: Dictionary, is_host: bool, solo: bool) -> void:
	_summary = summary
	_is_host = is_host
	_solo = solo


func _ready() -> void:
	layer = 96 ## ölüm ekranının (95) üstünde: izleyici modundaki ölü oyuncu da zaferi görsün
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"gamepad_modal") ## kumandayla düğmelere basılabilsin (bkz. gamepad_ui.gd)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.07, 0.03, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var window := PanelContainer.new()
	window.name = "Window"
	window.theme = UIKit.theme()
	window.add_theme_stylebox_override("panel", UIKit.panel_style("window_tight"))
	window.set_anchors_preset(Control.PRESET_CENTER_TOP)
	window.offset_top = 56
	window.offset_left = -380
	window.offset_right = 380
	window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(window)

	var box := VBoxContainer.new()
	box.name = "VBox"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	window.add_child(box)

	var title := Label.new()
	title.name = "Title"
	title.text = "ZAFER!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(title, UIKit.FS_BIG, UIKit.C_GOLD, 0)
	box.add_child(title)

	var sub := Label.new()
	sub.name = "Subtitle"
	sub.text = "Final Kademesi'nin 13 bossunu da yendin - hayatta kaldın!" if _solo \
			else "Final Kademesi'nin 13 bossunu da yendiniz - hayatta kaldınız!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIKit.style_label(sub, 24, UIKit.C_TEXT_DIM, 0)
	box.add_child(sub)

	box.add_child(RunSummaryUIScript.summary_row(_summary))

	var stats_title := Label.new()
	stats_title.text = "İSTATİSTİKLER"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(stats_title, UIKit.FS_BODY, UIKit.C_ACCENT, 0)
	box.add_child(stats_title)
	_grid = GridContainer.new()
	_grid.name = "StatsGrid"
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(_grid)

	_extras_slot = VBoxContainer.new()
	_extras_slot.name = "ExtrasSlot"
	box.add_child(_extras_slot)

	var hint := Label.new()
	hint.name = "EndlessHint"
	hint.text = "SONSUZ MOD: yaratıklar her kat güçlenir, 3 katta bir boss dalgası gelir. Ne kadar dayanabileceksin?"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	UIKit.style_label(hint, 24, UIKit.C_TEXT, 0)
	box.add_child(hint)

	var btn_row := HBoxContainer.new()
	btn_row.name = "ButtonRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	box.add_child(btn_row)

	if _is_host:
		_continue_btn = Button.new()
		_continue_btn.name = "ContinueButton"
		_continue_btn.text = "Sonsuza Devam Et"
		_continue_btn.custom_minimum_size = Vector2(300, 52)
		_continue_btn.pressed.connect(_on_continue)
		btn_row.add_child(_continue_btn)
	else:
		_wait_label = Label.new()
		_wait_label.name = "WaitLabel"
		_wait_label.text = "Devam kararını host veriyor..."
		_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIKit.style_label(_wait_label, 24, UIKit.C_GOLD, 0)
		btn_row.add_child(_wait_label)

	_menu_btn = Button.new()
	_menu_btn.name = "BackToMenuButton"
	_menu_btn.text = "Ana Menüye Dön"
	_menu_btn.custom_minimum_size = Vector2(240, 52)
	_menu_btn.pressed.connect(func() -> void: menu_pressed.emit())
	btn_row.add_child(_menu_btn)

	UISound.connect_all_buttons(self)
	UISound.apply_wood_buttons(self)
	if _continue_btn:
		UIKit.style_button(_continue_btn, "green", false, UIKit.FS_BODY)
	UIKit.style_button(_menu_btn, "wood", false, UIKit.FS_BODY)


func _on_continue() -> void:
	lock_for_continue()
	continue_pressed.emit()


## Devam seçildi: çift basılmasın (pencere endless_started ile kapanana kadar).
func lock_for_continue() -> void:
	if _continue_btn:
		_continue_btn.disabled = true
		_continue_btn.text = "Başlıyor..."


## Sonsuz mod başlatılamadıysa (ör. spawner henüz zafer evresinde değil) düğme tekrar basılabilir olsun.
func unlock_continue() -> void:
	if _continue_btn:
		_continue_btn.disabled = false
		_continue_btn.text = "Sonsuza Devam Et"


## Takım tablosu - diğer peer'lerin istatistikleri RPC ile art arda geldikçe main.gd çağırır.
func refresh_stats(stats_by_peer: Dictionary) -> void:
	if _grid and is_instance_valid(_grid):
		RunSummaryUIScript.fill_stats_grid(_grid, stats_by_peer)


## "YENİ REKOR" / "BAŞARIM" satırları (results = {"records": [...], "achievements": [...]}).
func set_results(results: Dictionary) -> void:
	if _extras_slot == null or not is_instance_valid(_extras_slot):
		return
	for child in _extras_slot.get_children():
		child.queue_free()
	var extras: Control = RunSummaryUIScript.extras_box(results, _summary)
	if extras:
		_extras_slot.add_child(extras)
