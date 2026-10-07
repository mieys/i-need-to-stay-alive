extends Node

## Kullanıcı isteği (2026-10-05): zafer penceresi + koşu özeti + rekor/başarım ekranı arayüzü (başsız: düğüm ağacı, metinler, düğmeler).
## Görsel yerleşim ayrıca pencereli bir çalıştırmayla bakılır; burada yapı ve davranış doğrulanır.

const VictoryOverlayScript: GDScript = preload("res://scripts/victory_overlay.gd")
const RecordsScreenScript: GDScript = preload("res://scripts/records_screen.gd")
const RunSummaryUIScript: GDScript = preload("res://scripts/run_summary_ui.gd")
const RunRecordsScript: GDScript = preload("res://scripts/run_records.gd")
const AchievementsScript: GDScript = preload("res://scripts/achievements.gd")

const SUMMARY := {"time": 1520.0, "tier": 16, "kills": 842, "layer": 0, "victory": true, "solo": true, "char_id": 3}

var _continue_count: int = 0
var _menu_count: int = 0
var _tmp: String = ""


func _on_continue() -> void:
	_continue_count += 1


func _on_menu() -> void:
	_menu_count += 1


func _overlay(is_host: bool, solo: bool) -> CanvasLayer:
	var ov := CanvasLayer.new()
	ov.set_script(VictoryOverlayScript)
	ov.call("setup", SUMMARY, is_host, solo)
	ov.connect("continue_pressed", _on_continue)
	ov.connect("menu_pressed", _on_menu)
	add_child(ov)
	return ov


func _labels(root: Node) -> Array[String]:
	var out: Array[String] = []
	for n in root.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out


func _has_text(root: Node, needle: String) -> bool:
	for t in _labels(root):
		if t.contains(needle):
			return true
	return false


func test_format_time() -> void:
	assert(RunSummaryUIScript.format_time(0.0) == "00:00")
	assert(RunSummaryUIScript.format_time(65.0) == "01:05")
	assert(RunSummaryUIScript.format_time(1520.0) == "25:20")
	assert(RunSummaryUIScript.format_time(3725.0) == "1:02:05", "saat dilimi: %s" % RunSummaryUIScript.format_time(3725.0))
	assert(RunSummaryUIScript.format_time(-4.0) == "00:00", "negatif süre sıfıra kısılmalı")


func test_host_sees_continue_and_menu_buttons_and_they_emit() -> void:
	_continue_count = 0
	_menu_count = 0
	var ov: CanvasLayer = _overlay(true, true)
	var cont: Button = ov.get_node_or_null("Window/VBox/ButtonRow/ContinueButton")
	var menu: Button = ov.get_node_or_null("Window/VBox/ButtonRow/BackToMenuButton")
	assert(cont != null and menu != null, "host: Sonsuza Devam Et + Ana Menü düğmeleri")
	assert(ov.get_node_or_null("Window/VBox/ButtonRow/WaitLabel") == null, "host'ta 'bekleniyor' yazısı olmamalı")
	assert(cont.text == "Sonsuza Devam Et")
	cont.pressed.emit()
	assert(_continue_count == 1, "devam sinyali")
	assert(cont.disabled, "çift basılmasın: düğme kilitlenmeli")
	ov.call("unlock_continue")
	assert(not cont.disabled, "sonsuz mod başlayamadıysa düğme tekrar açılmalı")
	menu.pressed.emit()
	assert(_menu_count == 1, "menü sinyali")
	ov.free()


func test_client_has_no_continue_button_only_waiting_text_and_menu() -> void:
	var ov: CanvasLayer = _overlay(false, false)
	assert(ov.get_node_or_null("Window/VBox/ButtonRow/ContinueButton") == null, "istemcide devam düğmesi olmamalı (karar host'ta)")
	assert(ov.get_node_or_null("Window/VBox/ButtonRow/WaitLabel") != null, "'host karar veriyor' yazısı")
	assert(ov.get_node_or_null("Window/VBox/ButtonRow/BackToMenuButton") != null, "istemci de menüye dönebilmeli")
	assert(_has_text(ov, "yendiniz"), "çok oyunculu metin çoğul")
	ov.free()


func test_solo_text_and_summary_row() -> void:
	var ov: CanvasLayer = _overlay(true, true)
	assert(_has_text(ov, "ZAFER!") and _has_text(ov, "yendin "), "tek oyunculu metin tekil")
	assert(_has_text(ov, "25:20"), "süre satırı")
	assert(_has_text(ov, "842"), "öldürme sayısı")
	assert(_has_text(ov, "SONSUZ MOD"), "sonsuz modun ne olduğu anlatılmalı")
	assert(ov.get_node_or_null("Window/VBox/SummaryRow") != null)
	assert(not _has_text(ov, "SONSUZ KAT"), "sonsuzda değilken kat sütunu olmamalı")
	ov.free()


func test_summary_row_shows_endless_layer_only_when_in_endless() -> void:
	var row: Control = RunSummaryUIScript.summary_row({"time": 60.0, "tier": 16, "kills": 5, "layer": 7})
	add_child(row)
	assert(_has_text(row, "SONSUZ KAT") and _has_text(row, "7"), "sonsuz kat sütunu")
	row.free()


func test_stats_grid_has_four_columns_sorted_by_damage() -> void:
	var ov: CanvasLayer = _overlay(true, false)
	ov.call("refresh_stats", {
		1: {"name": "Ayşe", "dealt": 500.0, "taken": 10.0, "kills": 20},
		2: {"name": "Bora", "dealt": 9000.0, "taken": 70.0, "kills": 333},
	})
	var grid: GridContainer = ov.get_node("Window/VBox/StatsGrid")
	assert(grid.columns == 4, "4 sütun: Oyuncu/Verdiği/Tankladığı/Öldürme")
	await get_tree().process_frame ## eski çocuklar queue_free
	var texts: Array[String] = []
	for c in grid.get_children():
		texts.append((c as Label).text)
	assert(texts.slice(0, 4) == ["Oyuncu", "Verdiği Hasar", "Tankladığı Hasar", "Öldürme"], "başlıklar: %s" % str(texts))
	assert(texts.slice(4, 8) == ["Bora", "9000", "70", "333"], "en çok hasar veren üstte: %s" % str(texts))
	assert(texts.slice(8, 12) == ["Ayşe", "500", "10", "20"], "ikinci satır: %s" % str(texts))
	ov.free()


func test_results_list_new_records_and_achievements_and_clear_on_refresh() -> void:
	var ov: CanvasLayer = _overlay(true, true)
	ov.call("set_results", {"records": ["victory_time", "tier"], "achievements": ["victory"]})
	assert(_has_text(ov, "YENİ REKOR: En hızlı zafer - 25:20"), "rekor satırı değerle: %s" % str(_labels(ov)))
	assert(_has_text(ov, "YENİ REKOR: En yüksek kademe - Kademe XVI"))
	assert(_has_text(ov, "BAŞARIM: Hayatta Kaldım!"), "başarım satırı")
	ov.call("set_results", {"records": [], "achievements": []})
	await get_tree().process_frame
	assert(not _has_text(ov, "YENİ REKOR") and not _has_text(ov, "BAŞARIM"), "boş sonuç satırları temizlemeli")
	ov.free()


## Pencere tasarım çözünürlüğüne (1920x1080) sığmalı - EN KÖTÜ durum: 5 oyuncu, 5 rekor satırı, 4 başarım satırı.
func test_victory_window_fits_the_screen_in_the_worst_case() -> void:
	var ov: CanvasLayer = _overlay(true, false)
	var stats := {}
	for i in range(5):
		stats[i + 1] = {"name": "Oyuncu %d" % (i + 1), "dealt": 1000.0 * (i + 1), "taken": 10.0, "kills": 100}
	ov.call("refresh_stats", stats)
	ov.call("set_results", {"records": ["time", "tier", "kills", "layer", "victory_time"],
			"achievements": ["victory", "victory_coop", "final", "tier_15"]})
	await get_tree().process_frame
	await get_tree().process_frame
	var win: PanelContainer = ov.get_node("Window")
	assert(win.offset_top + win.size.y <= 1080.0, "zafer penceresi ekrandan taşıyor: üst=%.0f yükseklik=%.0f" % [win.offset_top, win.size.y])
	assert(win.size.x <= 761.0, "zafer penceresi genişliği: %.0f" % win.size.x)
	var grid: GridContainer = ov.get_node("Window/VBox/StatsGrid")
	assert(grid.get_combined_minimum_size().x <= win.size.x, "istatistik tablosu pencereden geniş: %.0f > %.0f" % [grid.get_combined_minimum_size().x, win.size.x])
	ov.free()


func test_records_screen_fits_the_screen() -> void:
	_tmp = "user://test_records_ui_%d.cfg" % Time.get_ticks_usec()
	RunRecordsScript.set_path_override(_tmp)
	var screen: CanvasLayer = RecordsScreenScript.new()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Control = screen.find_children("*", "PanelContainer", true, false)[0]
	assert(panel.size.y <= 1080.0, "rekor ekranı ekrandan taşıyor: %.0f" % panel.size.y)
	assert(panel.size.x <= 1920.0)
	screen.free()
	RunRecordsScript.set_path_override("")


func test_extras_box_is_null_when_nothing_new() -> void:
	assert(RunSummaryUIScript.extras_box({"records": [], "achievements": []}, SUMMARY) == null)


func test_records_screen_lists_every_achievement_with_state() -> void:
	_tmp = "user://test_records_ui_%d.cfg" % Time.get_ticks_usec()
	RunRecordsScript.set_path_override(_tmp)
	RunRecordsScript.record_victory({"time": 1520.0, "tier": 16, "kills": 842, "solo": true, "char_id": 3})
	var screen: CanvasLayer = RecordsScreenScript.new()
	add_child(screen)
	var unlocked: int = (RunRecordsScript.load_all()["achievements"] as Dictionary).size()
	assert(_has_text(screen, "Başarımlar  %d / %d" % [unlocked, AchievementsScript.DEFS.size()]), "sayaç: %s" % str(_labels(screen)))
	for d: Dictionary in AchievementsScript.DEFS:
		assert(_has_text(screen, str(d["name"])), "başarım listede olmalı: %s" % str(d["name"]))
	assert(_has_text(screen, "[X] Hayatta Kaldım!"), "açılan başarım işaretli")
	assert(_has_text(screen, "[ ] Kıyamet Sonrası"), "açılmayan başarım boş kutu")
	assert(_has_text(screen, "25:20"), "en hızlı zafer / en uzun süre değeri")
	assert(_has_text(screen, "842"), "en çok öldürme")
	screen.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp))
	RunRecordsScript.set_path_override("")


func test_records_screen_closes_and_signals() -> void:
	_tmp = "user://test_records_ui_%d.cfg" % Time.get_ticks_usec()
	RunRecordsScript.set_path_override(_tmp)
	var screen: CanvasLayer = RecordsScreenScript.new()
	var closed_box := [0]
	screen.connect("closed", func() -> void: closed_box[0] += 1)
	add_child(screen)
	var btn: Button = screen.find_children("*", "Button", true, false)[0]
	assert(btn.text == "KAPAT")
	btn.pressed.emit()
	assert(closed_box[0] == 1, "KAPAT 'closed' yaymalı")
	await get_tree().process_frame
	assert(not is_instance_valid(screen), "ekran kendini silmeli")
	RunRecordsScript.set_path_override("")


## 2026-10-05: zafer + rekor pencereleri telefon ölçeklemesine (mobile_ui.gd FIT_LAYER_SCRIPTS) eklendi.
func test_victory_and_records_screens_are_in_the_phone_fit_list() -> void:
	var list: Array = (load("res://scripts/mobile_ui.gd") as GDScript).get_script_constant_map()["FIT_LAYER_SCRIPTS"]
	assert(list.has(VictoryOverlayScript.resource_path), "zafer penceresi telefon ölçeklemesinde olmalı")
	assert(list.has(RecordsScreenScript.resource_path), "rekorlar penceresi telefon ölçeklemesinde olmalı")


## Zafer penceresinde diğer oyuncuların takım tablosu satırları ağdan geç gelir (pencere büyür): MenuFitter ilk 0.6 sn'den sonra da
## içerik boyu değişince baştan ölçüp ölçeği küçültmeli - yoksa büyüyen pencere ekran dışına taşardı.
func test_menu_fitter_refits_when_content_grows_after_the_fit_window() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	get_tree().root.size = Vector2i(1920, 1080)
	await get_tree().process_frame
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := Panel.new()
	panel.position = Vector2(580.0, 56.0)
	panel.size = Vector2(760.0, 300.0)
	layer.add_child(panel)
	var fitter_script: GDScript = (load("res://scripts/mobile_menu_fit.gd") as GDScript).get("MenuFitter")
	assert(fitter_script != null, "MenuFitter iç sınıfı bulunamadı")
	var fitter: Node = fitter_script.new()
	layer.add_child(fitter)
	await get_tree().create_timer(1.0).timeout
	var s_small: float = layer.transform.get_scale().x
	assert(s_small > 1.4, "kısa pencere büyütülmeli: %.2f" % s_small)
	panel.size = Vector2(760.0, 960.0) ## geç gelen satırlar
	await get_tree().create_timer(1.2).timeout
	var s_big: float = layer.transform.get_scale().x
	var bottom: float = (layer.transform * Rect2(panel.position, panel.size)).end.y
	assert(s_big < s_small, "büyüyen içerik için ölçek küçülmeli: %.2f -> %.2f" % [s_small, s_big])
	assert(bottom <= 1080.0 - 18.0, "pencere ekranın altından taşmamalı: alt=%.0f" % bottom)
	layer.queue_free()
