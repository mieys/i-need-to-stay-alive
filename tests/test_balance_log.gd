extends Node

## Balans telemetrisi (scripts/balance_log.gd): etiket -> toplama -> kayıt -> host'un aldığı kayıt. Hepsi GEÇİCİ dosyada
## (LILSLAYERS_BALANCE_PATH) - kullanıcının gerçek user://balans/kosular.jsonl'una DOKUNMAZ.

const BalanceLogScript: GDScript = preload("res://scripts/balance_log.gd")

var _tmp: String = ""


func _begin() -> void:
	_tmp = "user://test_balans_%d.jsonl" % Time.get_ticks_usec()
	OS.set_environment(BalanceLogScript.ENV_PATH, _tmp)
	BalanceLogScript.reset()


func _end() -> void:
	if _tmp != "" and FileAccess.file_exists(_tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp))
	OS.set_environment(BalanceLogScript.ENV_PATH, "")
	BalanceLogScript.reset()
	_tmp = ""


func _lines() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(_tmp):
		return out
	var f := FileAccess.open(_tmp, FileAccess.READ)
	while not f.eof_reached():
		var l: String = f.get_line()
		if l != "":
			out.append(l)
	return out


func _summary() -> Dictionary:
	return {"time": 123.4, "tier": 3, "kills": 50, "layer": 0, "victory": false, "solo": true, "char_id": 1, "level": 7}


func test_tag_is_consumed_once() -> void:
	BalanceLogScript.tag(&"w:tabanca")
	assert(BalanceLogScript.take_src() == "w:tabanca")
	assert(BalanceLogScript.take_src() == "", "etiket ikinci okumada boş olmalı (sonraki isabete sızmasın)")


func test_untagged_goes_to_diger_and_crits_counted() -> void:
	_begin()
	BalanceLogScript.on_hit("w:yay", 10.0, false)
	BalanceLogScript.on_hit("w:yay", 30.0, true)
	BalanceLogScript.on_hit("", 5.0, false)
	var rec: Dictionary = BalanceLogScript.build_record(null, _summary(), "end")
	var by: Dictionary = rec["by_src"]
	assert(is_equal_approx(float(by["w:yay"][0]), 40.0))
	assert(int(by["w:yay"][1]) == 2 and int(by["w:yay"][2]) == 1)
	assert(by.has("diger") and is_equal_approx(float(by["diger"][0]), 5.0))
	_end()


func test_write_run_appends_one_json_line_per_run() -> void:
	_begin()
	BalanceLogScript.on_hit("w:dagger", 12.0, false)
	var r1: Dictionary = BalanceLogScript.write_run(null, _summary(), "end")
	var r2: Dictionary = BalanceLogScript.write_run(null, _summary(), "end")
	assert(not r1.is_empty() and r1["run_id"] != r2["run_id"], "her kaydın run_id'si farklı olmalı")
	var lines: Array = _lines()
	assert(lines.size() == 2, "iki koşu = iki satır")
	var parsed: Variant = JSON.parse_string(lines[0])
	assert(parsed is Dictionary and int(parsed["rev"]) == BalanceLogScript.BALANCE_REV and int(parsed["tier"]) == 3)
	assert(str(parsed["char_name"]) != "", "karakter adı kayda yazılmalı")
	_end()


func test_ingest_remote_validates_and_marks_host() -> void:
	_begin()
	var rec: Dictionary = BalanceLogScript.build_record(null, _summary(), "end")
	assert(BalanceLogScript.ingest_remote(JSON.stringify(rec), 7))
	assert(not BalanceLogScript.ingest_remote("bu json degil", 7), "bozuk kayıt reddedilmeli")
	assert(not BalanceLogScript.ingest_remote(JSON.stringify({"schema": 99, "run_id": "x"}), 7), "yanlış şema reddedilmeli")
	assert(not BalanceLogScript.ingest_remote("x".repeat(BalanceLogScript.MAX_RECORD_CHARS + 1), 7), "aşırı büyük kayıt reddedilmeli")
	var lines: Array = _lines()
	assert(lines.size() == 1)
	var parsed: Dictionary = JSON.parse_string(lines[0])
	assert(parsed["via"] == "host" and int(parsed["peer"]) == 7)
	_end()


func test_taken_tracks_family_and_killer() -> void:
	_begin()
	var e := Node2D.new()
	e.name = "Zombi"
	add_child(e)
	BalanceLogScript.on_taken(20.0, e)
	BalanceLogScript.on_taken(5.0, null)
	var rec: Dictionary = BalanceLogScript.build_record(null, _summary(), "end")
	assert(is_equal_approx(float(rec["taken_by"]["Zombi"]), 20.0))
	assert(rec["killer"] == "?", "son vuran kaynağı bilinmiyorsa '?'")
	e.queue_free()
	_end()
