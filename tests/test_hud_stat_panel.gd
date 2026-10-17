extends Node

## Mini stat paneli (hud_stat_panel.gd + hud_stat_toggle.gd, 2026-10-14): normalde kapalı, portre altı düğmesiyle açılır, 1-2 sekmeleri
## sayfa değiştirir, 16 stat simgesi yüklenir, sayılar sütundan ASLA taşmaz, panel ana panelin soluna yapışık + altı efsanevi panelle hizalı.

const StatPanel := preload("res://scripts/hud_stat_panel.gd")
const StatToggle := preload("res://scripts/hud_stat_toggle.gd")
const Hud := preload("res://scripts/hud.gd")


func _make_hud() -> Node:
	StatToggle.remembered_open = false
	StatPanel.remembered_page = 0
	var hud: Node = (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	add_child(hud)
	return hud


func _click(c: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	if c.get_script() == StatToggle:
		c._gui_input(ev)
	else:
		c.gui_input.emit(ev)


func test_panel_closed_by_default_and_toggle_opens() -> void:
	var hud: Node = _make_hud()
	var panel: Control = hud.get_node_or_null("DockStats") as Control
	var toggle: Control = hud.get_node_or_null("DockStatsToggle") as Control
	assert(panel != null and toggle != null, "DockStats / DockStatsToggle kurulmamış")
	assert(not panel.visible, "Stat paneli başta kapalı olmalı")
	_click(toggle)
	assert(panel.visible, "Düğme paneli açmadı")
	_click(toggle)
	assert(not panel.visible, "Düğme paneli kapatmadı")
	hud.queue_free()


func test_tabs_switch_pages() -> void:
	var hud: Node = _make_hud()
	var panel: Control = hud.get_node("DockStats") as Control
	assert(int(panel.get("page")) == 0)
	_click(panel.get_node("Tab2") as Control)
	assert(int(panel.get("page")) == 1, "2 sekmesi 2. sayfaya geçmedi")
	assert((panel.get_node("Cell0") as Control).tooltip_text.begins_with("Kalkan Delme"), "2. sayfanın ilk ipucu Kalkan Delme olmalı")
	_click(panel.get_node("Tab1") as Control)
	assert(int(panel.get("page")) == 0, "1 sekmesi 1. sayfaya dönmedi")
	assert((panel.get_node("Cell0") as Control).tooltip_text.begins_with("Saldırı Gücü"))
	hud.queue_free()


func test_sixteen_stats_with_icons_and_tips() -> void:
	assert(StatPanel.STATS.size() == 16, "16 stat olmalı (2 sayfa x 8)")
	var ids: Dictionary = {}
	for s in StatPanel.STATS:
		ids[s[0]] = true
		var tex: Texture2D = load(StatPanel.ICON_DIR + str(s[0]) + ".png") as Texture2D
		assert(tex != null, "Simge yok: %s" % s[0])
		assert(tex.get_size() == Vector2(24, 24), "Simge 24x24 olmalı: %s" % s[0])
	assert(ids.size() == 16, "Aynı stat iki kez")
	## Kullanıcı: can/kalkan MİKTARI ve toplama mesafesi olmasın.
	for banned in ["max_health", "shield_max", "pickup_range"]:
		assert(not ids.has(banned), "Panelde olmaması gereken stat: %s" % banned)
	var hud: Node = _make_hud()
	var panel: Control = hud.get_node("DockStats") as Control
	for k in StatPanel.PER_PAGE:
		assert((panel.get_node("Cell%d" % k) as Control).tooltip_text != "", "Hücre %d ipucu boş" % k)
	hud.queue_free()


func test_values_never_overflow() -> void:
	var budget: float = StatPanel.value_w()
	for t in ["%600", "%250", "9999", "999.9", "x9.99", "%175", "12345", "%12345", "1234.5", "99999999", "x123.45"]:
		var f: String = StatPanel.fit(t)
		var w: float = StatPanel.FONT.get_string_size(f, HORIZONTAL_ALIGNMENT_LEFT, -1, StatPanel.FONT_PX).x
		assert(w <= budget, "'%s' -> '%s' %d px > %d px" % [t, f, int(w), int(budget)])
	assert(StatPanel.fit("12345") == "12k", "12345 kısaltması 12k olmalı, %s" % StatPanel.fit("12345"))
	assert(StatPanel.fit("%45") == "%45", "Sığan değer değişmemeli")
	## Hücre: simge + yazı payı sütun genişliğini aşmaz.
	assert(StatPanel.PAD + StatPanel.ICON + StatPanel.GAP + budget + StatPanel.PAD <= StatPanel.col_w() + 0.01)


## Dock parçaları DOCK_UI_SCALE ile küçülür; get_global_rect ölçeği yok sayar.
func _srect(c: Control) -> Rect2:
	return Rect2(c.get_global_position(), c.size * c.get_global_transform().get_scale())


func test_layout_left_of_dock_bottom_aligned_with_legend() -> void:
	var hud: Node = _make_hud()
	await get_tree().process_frame
	var frame: Rect2 = _srect(hud.get_node("DockFrame") as Control)
	var legend: Rect2 = _srect(hud.get_node("DockLegend") as Control)
	var panel: Control = hud.get_node("DockStats") as Control
	var toggle: Control = hud.get_node("DockStatsToggle") as Control
	var pr: Rect2 = _srect(panel)
	assert(is_equal_approx(pr.end.x, frame.position.x + StatPanel.OVERLAP * Hud.DOCK_UI_SCALE), "Panelin sağ kenarı ana panelin 12 px altına girmeli: %s / %s" % [pr, frame])
	assert(is_equal_approx(pr.end.y, legend.end.y), "Panelin altı efsanevi panelin altıyla hizalı olmalı: %s / %s" % [pr, legend])
	assert(panel.get_index() < hud.get_node("DockFrame").get_index(), "Panel ana panelin ARKASINDA çizilmeli")
	var tr: Rect2 = _srect(toggle)
	assert(frame.encloses(tr), "Düğme ana panelin içinde (portre altı) olmalı: %s / %s" % [tr, frame])
	var badge: Control = hud.get_node("CharacterCluster/LevelBadge") as Control
	assert(tr.position.y >= badge.get_global_rect().end.y, "Düğme seviye rozetinin ALTINDA olmalı")
	hud.queue_free()
