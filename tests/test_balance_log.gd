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


## Yetenek etiketleri (2026-10-12: "diğer olarak gözükmesin, pasifler dahil"): etiket eklenen her betik derlenebilmeli ve
## her yetenek çağrısı "s:" öneklisi olmalı (yeni bir take_damage çağrısı eklenirse bu liste/etiket unutulmasın).
const TAGGED_SCRIPTS: Array = [
	"res://scripts/player.gd", "res://scripts/evo_area.gd", "res://scripts/golem_pet.gd", "res://scripts/player_pet.gd",
	"res://scripts/skeleton_pet.gd", "res://scripts/necro_skull.gd", "res://scripts/korsan_bomb.gd", "res://scripts/fx_buyucu_tornado.gd",
	"res://scripts/fx_papagan_feather_storm.gd", "res://scripts/totem_attack.gd", "res://scripts/totem_base.gd", "res://scripts/oakley_vine.gd",
	"res://scripts/enchant_area.gd", "res://scripts/enchant_behavior.gd", "res://scripts/enchants/hunters_eye.gd",
]


func test_tagged_scripts_compile_and_tag_every_enemy_hit() -> void:
	for path in TAGGED_SCRIPTS:
		var scr: Script = load(path)
		assert(scr != null and scr.can_instantiate(), "%s derlenmeli" % path)
		var src: String = (scr as GDScript).source_code
		var lines: PackedStringArray = src.split("\n")
		for i in lines.size():
			var l: String = lines[i].strip_edges()
			if l.begins_with("#") or not (l.contains(".take_damage(") or l.contains("call(\"take_damage\"")):
				continue
			if l.contains("take_damage(amount, source)") or l.contains("take_damage(dmg, self)"):
				continue
			var prev: String = lines[i - 1] if i > 0 else ""
			assert(prev.contains("BalanceLogScript.tag") or prev.contains("tag_weapon"), "%s:%d etiketsiz take_damage çağrısı" % [path, i + 1])


func test_dot_kinds_are_labelled() -> void:
	_begin()
	BalanceLogScript.on_hit("dot:yanma", 12.0, false)
	var rec: Dictionary = BalanceLogScript.build_record(null, _summary(), "end")
	assert((rec["by_src"] as Dictionary).has("dot:yanma"))
	_end()


func test_death_downs_and_acquisition_recorded() -> void:
	_begin()
	BalanceLogScript.note_down(false)
	BalanceLogScript.note_down(true)
	BalanceLogScript.note_down(true)
	var rec: Dictionary = BalanceLogScript.build_record(null, _summary(), "end")
	assert((rec["downs"] as Array).size() == 3, "her düşüş kayda girmeli")
	assert(float(rec["death_t"]) >= 0.0, "kalıcı ölüm zamanı yazılmalı")
	assert(rec.has("shield") and rec.has("pet") and rec.has("shield_ups"), "kalkan/evcil alanları olmalı")
	## edinme: örnekleme sahip olunan silah adedinin artışını yakalar
	var old_w: Array = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_weapons = [{"key": "yay"}, {"key": "yay"}]
	BalanceLogScript.sample_loadout()
	GameManager.owned_weapons.append({"key": "dagger"})
	BalanceLogScript.sample_loadout()
	var got: Array = BalanceLogScript.build_record(null, _summary(), "end")["got_weapons"]
	GameManager.owned_weapons = old_w
	assert(got.size() == 3 and str(got[2][0]) == "dagger", "iki yay + bir hançer edinilmiş görünmeli: %s" % str(got))
	_end()
