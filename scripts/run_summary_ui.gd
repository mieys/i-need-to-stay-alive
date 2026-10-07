extends RefCounted

## KOŞU ÖZETİ arayüz parçaları (kullanıcı isteği 2026-10-05: koşu sonu süre/kademe/öldürme + rekor + başarım). Ölüm ekranı
## (main.gd _show_death_overlay) ve zafer penceresi (victory_overlay.gd) AYNI parçaları kullanır - ikinci bir kopya yok.
## Oyun içi bej kit (UIKit); değerler main.gd'nin derlediği "özet" sözlüğünden gelir:
##   {"time" sn, "tier", "kills", "layer" (0 = sonsuz değil), "victory", "solo", "char_id"}

const RunRecordsScript: GDScript = preload("res://scripts/run_records.gd")
const AchievementsScript: GDScript = preload("res://scripts/achievements.gd")
const TierDisplayScript: GDScript = preload("res://scripts/tier_display.gd")

const STAT_FS := 24


@warning_ignore("integer_division")
static func format_time(seconds: float) -> String:
	var total: int = maxi(int(seconds), 0)
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]


## SÜRE | KADEME | (SONSUZ KAT) | ÖLDÜRME - büyük değer, altında küçük başlık.
static func summary_row(summary: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "SummaryRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 36)
	_add_stat(row, "SÜRE", format_time(float(summary.get("time", 0.0))))
	_add_stat(row, "KADEME", TierDisplayScript.to_roman(int(summary.get("tier", 1)))) ## Romen rakamı (2026-10-05)
	if int(summary.get("layer", 0)) > 0:
		_add_stat(row, "SONSUZ KAT", str(int(summary["layer"])))
	_add_stat(row, "ÖLDÜRME", str(int(summary.get("kills", 0))))
	return row


static func _add_stat(parent: Control, caption: String, value: String) -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var v := Label.new()
	v.text = value
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(v, UIKit.FS_TITLE, UIKit.C_ACCENT, 0)
	col.add_child(v)
	var c := Label.new()
	c.text = caption
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(c, STAT_FS, UIKit.C_TEXT_DIM, 0)
	col.add_child(c)
	parent.add_child(col)


## Takım istatistik tablosu: Oyuncu | Verdiği Hasar | Tankladığı Hasar | Öldürme, en çok hasar veren üstte.
## stats_by_peer: {peer_id: {"name", "dealt", "taken", "kills"}} (bkz. main.gd _match_stats_by_peer).
static func fill_stats_grid(grid: GridContainer, stats_by_peer: Dictionary) -> void:
	for child in grid.get_children():
		child.queue_free()
	grid.columns = 4
	for header_text in ["Oyuncu", "Verdiği Hasar", "Tankladığı Hasar", "Öldürme"]:
		var h := Label.new()
		h.text = header_text
		UIKit.style_label(h, STAT_FS, UIKit.C_TEXT_DIM, 0)
		grid.add_child(h)
	var peer_ids: Array = stats_by_peer.keys()
	peer_ids.sort_custom(func(a, b): return float(stats_by_peer[a]["dealt"]) > float(stats_by_peer[b]["dealt"]))
	for peer_id in peer_ids:
		var entry: Dictionary = stats_by_peer[peer_id]
		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("name", "?"))
		UIKit.style_label(name_lbl, STAT_FS, UIKit.C_TEXT, 0)
		grid.add_child(name_lbl)
		_add_cell(grid, "%d" % int(round(float(entry.get("dealt", 0.0)))), Color(UIKit.INK["damage"]))
		_add_cell(grid, "%d" % int(round(float(entry.get("taken", 0.0)))), Color(UIKit.INK["shield"]))
		_add_cell(grid, "%d" % int(entry.get("kills", 0)), UIKit.C_TEXT)


static func _add_cell(grid: GridContainer, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(l, STAT_FS, color, 0)
	grid.add_child(l)


## Rekor anahtarının bu koşudaki değeri (özetten) - "YENİ REKOR: En uzun süre - 24:51".
static func record_value_text(key: String, summary: Dictionary) -> String:
	match key:
		"time", "victory_time":
			return format_time(float(summary.get("time", 0.0)))
		"tier":
			return "Kademe %s" % TierDisplayScript.to_roman(int(summary.get("tier", 1)))
		"kills":
			return "%d" % int(summary.get("kills", 0))
		"layer":
			return "Kat %d" % int(summary.get("layer", 0))
	return ""


## "YENİ REKOR" + "BAŞARIM" satırları. results = {"records": [...], "achievements": [...]}; ikisi de boşsa null döner.
static func extras_box(results: Dictionary, summary: Dictionary) -> VBoxContainer:
	var records: Array = results.get("records", [])
	var achievements: Array = results.get("achievements", [])
	if records.is_empty() and achievements.is_empty():
		return null
	var box := VBoxContainer.new()
	box.name = "ExtrasBox"
	box.add_theme_constant_override("separation", 4)
	for key in records:
		var text: String = "YENİ REKOR: %s" % RunRecordsScript.RECORD_LABELS.get(key, key)
		var value: String = record_value_text(str(key), summary)
		if value != "":
			text += " - " + value
		_add_line(box, text, UIKit.C_GOLD)
	for id in achievements:
		var d: Dictionary = AchievementsScript.def_of(str(id))
		_add_line(box, "BAŞARIM: %s - %s" % [d.get("name", id), d.get("desc", "")], UIKit.C_GOOD)
	return box


static func _add_line(box: VBoxContainer, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.style_label(l, STAT_FS, color, 0)
	box.add_child(l)
