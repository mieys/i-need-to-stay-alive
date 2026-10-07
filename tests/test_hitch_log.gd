extends Node

## Takılma kaydedici (scripts/hitch_log.gd, 2026-10-06): eşik/sınır kuralı, dosyaya yazma + boyut sınırı, olay işaretleri, bağlam satırı.

const HitchLogScript: GDScript = preload("res://scripts/hitch_log.gd")
const TEST_PATH := "user://hitch_log_test.txt"


func _begin() -> void:
	HitchLogScript.set_log_path(TEST_PATH)
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func _end() -> void:
	HitchLogScript.set_log_path("user://hitch_log.txt")
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_threshold_and_entry_cap() -> void:
	assert(not HitchLogScript.should_record(40.0, 0), "normal kare kaydedilmemeli")
	assert(not HitchLogScript.should_record(HitchLogScript.THRESHOLD_MS - 1.0, 0), "eşik altı kaydedilmemeli")
	assert(HitchLogScript.should_record(HitchLogScript.THRESHOLD_MS, 0), "eşikte kaydedilmeli")
	assert(HitchLogScript.should_record(2500.0, 3), "uzun kare kaydedilmeli")
	assert(not HitchLogScript.should_record(2500.0, HitchLogScript.MAX_ENTRIES), "oturum sınırı dolunca yazılmamalı")


func test_entries_are_appended_to_the_file() -> void:
	_begin()
	HitchLogScript.write_entry(1234.0, "scene=Main | enemies=5")
	HitchLogScript.write_entry(456.0, "scene=Main | enemies=9")
	var txt: String = FileAccess.get_file_as_string(TEST_PATH)
	var lines: PackedStringArray = txt.strip_edges().split("\n")
	assert(lines.size() == 2, "iki satır beklenir: %s" % txt)
	assert(lines[0].contains("HITCH 1234 ms") and lines[0].contains("enemies=5"), "ilk satır: %s" % lines[0])
	assert(lines[1].contains("HITCH 456 ms"), "ikinci satır eklenmeli: %s" % lines[1])
	_end()


func test_file_is_reset_when_it_grows_too_large() -> void:
	_begin()
	var big: String = "x".repeat(2000)
	for i in 200: ## ~400 KB > MAX_FILE_BYTES
		HitchLogScript.write_entry(500.0, big)
	var size: int = FileAccess.get_file_as_bytes(TEST_PATH).size()
	assert(size <= HitchLogScript.MAX_FILE_BYTES + 2500, "dosya sınırı aşmamalı: %d bayt" % size)
	_end()


func test_marks_show_up_with_age_and_are_limited() -> void:
	HitchLogScript.mark("shop_open")
	HitchLogScript.mark("shop_setup 94 ms")
	var m: PackedStringArray = HitchLogScript.recent_marks()
	assert(m.size() >= 2 and m[m.size() - 2].begins_with("shop_open (-") and m[m.size() - 1].begins_with("shop_setup 94 ms (-"), "işaretler sırayla ve yaşıyla gelmeli: %s" % str(m))
	for i in 40:
		HitchLogScript.mark("m%d" % i)
	assert(HitchLogScript.recent_marks().size() <= HitchLogScript.MAX_MARKS, "işaret sayısı sınırlı olmalı")


func test_context_line_has_the_fields_needed_to_find_the_cause() -> void:
	var node: Node = HitchLogScript.new()
	add_child(node)
	var line: String = node.describe()
	for key in ["scene=", "mp=", "enemies=", "proc=", "phys=", "nodes=", "draw=", "panel=", "paused=", "marks=["]:
		assert(line.contains(key), "bağlam satırında '%s' yok: %s" % [key, line])
	node.free()


func test_recorder_is_attached_but_silent_in_headless_runs() -> void:
	var rec: Node = GameManager.get_node_or_null("HitchLog")
	assert(rec != null, "GameManager altında HitchLog düğümü olmalı")
	assert(not rec.is_processing(), "başsız çalışmada (testler) kayıt kapalı olmalı - kullanıcının kayıtlarını kirletmesin")
