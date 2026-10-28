extends Node

## Mini stat paneli (hud_stat_panel.gd + hud_stat_toggle.gd, 2026-10-14): normalde kapalı, portre altı düğmesiyle açılır, 1-2 sekmeleri
## sayfa değiştirir, 16 stat simgesi yüklenir, sayılar sütundan ASLA taşmaz, panel ana panelin soluna yapışık + altı efsanevi panelle hizalı.
## 2026-10-18: LoL tarzı düz glif simgeler (assets/ui/stat_mini_lol/, 48 px -> 24 px), Nunito yazı, panel ÖLÇEKSİZ.

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
		assert(tex.get_size() == Vector2(48, 48), "Simge 48x48 olmalı (24 px çizilir): %s" % s[0])
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
		var w: float = StatPanel.font().get_string_size(f, HORIZONTAL_ALIGNMENT_LEFT, -1, StatPanel.FONT_PX).x
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
	## Panel ölçeksiz + tam piksel konum (yuvarlama: <= 1 px fark); simge/pürüzsüz yazı LINEAR çocukta.
	assert(panel.scale == Vector2.ONE, "Stat paneli ölçeksiz olmalı (0,92 yazıyı bozuyordu)")
	assert(is_equal_approx(pr.position.x, roundf(pr.position.x)) and is_equal_approx(pr.position.y, roundf(pr.position.y)), "Panel tam piksele oturmalı: %s" % pr)
	assert(absf(pr.end.x - (frame.position.x + StatPanel.OVERLAP * Hud.DOCK_UI_SCALE)) <= 1.0, "Panelin sağ kenarı ana panelin 12 px altına girmeli: %s / %s" % [pr, frame])
	assert(absf(pr.end.y - legend.end.y) <= 1.0, "Panelin altı efsanevi panelin altıyla hizalı olmalı: %s / %s" % [pr, legend])
	assert((panel.get_node("Content") as CanvasItem).texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "Simge/yazı katmanı LINEAR olmalı")
	assert(panel.get_index() < hud.get_node("DockFrame").get_index(), "Panel ana panelin ARKASINDA çizilmeli")
	var tr: Rect2 = _srect(toggle)
	assert(frame.encloses(tr), "Düğme ana panelin içinde (portre altı) olmalı: %s / %s" % [tr, frame])
	var badge: Control = hud.get_node("CharacterCluster/LevelBadge") as Control
	assert(tr.position.y >= badge.get_global_rect().end.y, "Düğme seviye rozetinin ALTINDA olmalı")
	hud.queue_free()


## Madde 369: Can Çalma ipucundaki iyileşme miktarı GameManager.LIFESTEAL_HEAL'den okunur (eskiden metin "2 can" diyordu, gerçek değer 1'di).
func test_lifesteal_tip_reads_the_real_heal_amount() -> void:
	var StatsPanel := preload("res://scripts/stats_panel.gd")
	var row: Array = []
	for r in StatsPanel.EXTRA_ROWS:
		if r[0] == "lifesteal":
			row = r
	assert(not row.is_empty(), "lifesteal satırı olmalı")
	var tip: String = StatsPanel.row_tip(row)
	assert(not tip.contains("{HEAL}"), "yer tutucu doldurulmalı: %s" % tip)
	var heal: float = GameManager.LIFESTEAL_HEAL
	var want: String = str(int(heal)) if is_equal_approx(heal, round(heal)) else ("%.1f" % heal).replace(".", ",")
	assert(tip.contains("%s can" % want), "ipucu gerçek iyileşmeyi (%s can) yazmalı: %s" % [want, tip])
