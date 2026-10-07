extends Node

## Kullanıcı isteği (2026-10-05, öneri 3): koşu sonu rekor + başarım kaydı (scripts/run_records.gd, achievements.gd).
## Hepsi GEÇİCİ bir dosyada (path_override) - kullanıcının gerçek user://records.cfg'sine DOKUNMAZ.

const RunRecordsScript: GDScript = preload("res://scripts/run_records.gd")
const AchievementsScript: GDScript = preload("res://scripts/achievements.gd")

var _tmp: String = ""


func _begin() -> void:
	_tmp = "user://test_records_%d.cfg" % Time.get_ticks_usec()
	RunRecordsScript.set_path_override(_tmp)


func _end() -> void:
	if _tmp != "" and FileAccess.file_exists(_tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_tmp))
	RunRecordsScript.set_path_override("")
	_tmp = ""


func _run(time: float, tier: int, kills: int, layer: int = 0, solo: bool = true, char_id: int = 1) -> Dictionary:
	return {"time": time, "tier": tier, "kills": kills, "layer": layer, "victory": false, "solo": solo, "char_id": char_id}


func test_missing_file_gives_zeroed_defaults() -> void:
	_begin()
	var d: Dictionary = RunRecordsScript.load_all()
	assert(float(d["best_time"]) == 0.0 and int(d["best_tier"]) == 0 and int(d["runs"]) == 0, "yeni oyuncu: her şey sıfır")
	assert((d["achievements"] as Dictionary).is_empty() and (d["victory_chars"] as Array).is_empty())
	_end()


func test_progress_saves_bests_and_only_reports_broken_ones() -> void:
	_begin()
	var r1: Dictionary = RunRecordsScript.note_progress(_run(600.0, 6, 120))
	for key in ["time", "tier", "kills"]:
		assert((r1["records"] as Array).has(key), "ilk kayıtta '%s' yeni rekor olmalı" % key)
	assert(not (r1["records"] as Array).has("layer"), "sonsuz kat 0: rekor sayılmaz")
	var r2: Dictionary = RunRecordsScript.note_progress(_run(300.0, 4, 50))
	assert((r2["records"] as Array).is_empty(), "daha düşük değerler rekor kırmamalı: %s" % str(r2["records"]))
	var r3: Dictionary = RunRecordsScript.note_progress(_run(700.0, 6, 100))
	assert(r3["records"] == ["time"], "sadece süre kırıldı: %s" % str(r3["records"]))
	var d: Dictionary = RunRecordsScript.load_all()
	assert(float(d["best_time"]) == 700.0 and int(d["best_tier"]) == 6 and int(d["best_kills"]) == 120, "en iyiler dosyada kalıcı")
	_end()


func test_records_survive_a_fresh_load() -> void:
	_begin()
	RunRecordsScript.note_progress(_run(900.0, 8, 400, 0))
	RunRecordsScript.record_victory({"time": 1500.0, "tier": 16, "kills": 900, "layer": 0, "solo": true, "char_id": 4})
	var d: Dictionary = RunRecordsScript.load_all() ## dosyadan sıfırdan okunur
	assert(int(d["victories"]) == 1 and (d["victory_chars"] as Array) == [4], "zafer + karakter kalıcı")
	assert(float(d["best_victory_time"]) == 1500.0)
	_end()


func test_achievement_unlocks_once_and_stacks_in_order() -> void:
	_begin()
	var r1: Dictionary = RunRecordsScript.note_progress(_run(60.0, 5, 10))
	assert(r1["achievements"] == ["tier_5"], "Kademe 5: tek başarım: %s" % str(r1["achievements"]))
	var r2: Dictionary = RunRecordsScript.note_progress(_run(120.0, 5, 20))
	assert((r2["achievements"] as Array).is_empty(), "aynı başarım ikinci kez açılmamalı")
	var r3: Dictionary = RunRecordsScript.note_progress(_run(1000.0, 10, 20))
	assert(r3["achievements"] == ["tier_10", "time_15"], "Kademe 10 + 15 dk: %s" % str(r3["achievements"]))
	assert(int((RunRecordsScript.load_all()["achievements"] as Dictionary).size()) == 3, "3 başarım kayıtlı")
	_end()


func test_victory_unlocks_victory_achievements_and_best_time() -> void:
	_begin()
	var s := {"time": 1700.0, "tier": 16, "kills": 600, "layer": 0, "solo": true, "char_id": 7}
	var r: Dictionary = RunRecordsScript.record_victory(s)
	for id in ["victory", "victory_solo", "final", "tier_15", "kills_500", "time_15"]:
		assert((r["achievements"] as Array).has(id), "zaferde '%s' açılmalı: %s" % [id, str(r["achievements"])])
	assert(not (r["achievements"] as Array).has("victory_coop"), "tek oyunculu zaferde takım başarımı açılmamalı")
	assert((r["records"] as Array).has("victory_time"), "ilk zafer = en hızlı zafer")
	var faster: Dictionary = RunRecordsScript.record_victory({"time": 1600.0, "tier": 16, "kills": 600, "solo": true, "char_id": 7})
	assert((faster["records"] as Array).has("victory_time"), "daha hızlı zafer rekor kırmalı")
	var slower: Dictionary = RunRecordsScript.record_victory({"time": 1900.0, "tier": 16, "kills": 600, "solo": true, "char_id": 7})
	assert(not (slower["records"] as Array).has("victory_time"), "daha yavaş zafer rekor kırmamalı")
	var d: Dictionary = RunRecordsScript.load_all()
	assert(int(d["victories"]) == 3 and float(d["best_victory_time"]) == 1600.0, "3 zafer, en hızlısı 1600")
	_end()


func test_coop_victory_gives_team_achievement_not_solo() -> void:
	_begin()
	var r: Dictionary = RunRecordsScript.record_victory({"time": 1700.0, "tier": 16, "kills": 100, "solo": false, "char_id": 2})
	assert((r["achievements"] as Array).has("victory_coop"), "çok oyunculu zafer: Takım Ruhu")
	assert(not (r["achievements"] as Array).has("victory_solo"))
	_end()


func test_three_different_heroes_unlock_versatile_once() -> void:
	_begin()
	var got: Array = []
	for cid in [1, 2, 2, 3]:
		var r: Dictionary = RunRecordsScript.record_victory({"time": 1500.0, "tier": 16, "kills": 10, "solo": true, "char_id": cid})
		got.append((r["achievements"] as Array).has("victory_heroes_3"))
	assert(got == [false, false, false, true], "3. FARKLI karakterde açılmalı (tekrar eden karakter saymaz): %s" % str(got))
	assert((RunRecordsScript.load_all()["victory_chars"] as Array).size() == 3)
	_end()


func test_run_end_accumulates_totals_and_cumulative_achievements() -> void:
	_begin()
	for i in range(9):
		RunRecordsScript.record_run_end(_run(100.0, 2, 1000))
	var d9: Dictionary = RunRecordsScript.load_all()
	assert(int(d9["runs"]) == 9 and int(d9["total_kills"]) == 9000, "9 koşu / 9000 öldürme")
	assert(not (d9["achievements"] as Dictionary).has("runs_10"))
	var r: Dictionary = RunRecordsScript.record_run_end(_run(100.0, 2, 1000))
	assert((r["achievements"] as Array).has("runs_10"), "10. koşuda Azimli")
	assert((r["achievements"] as Array).has("total_kills_10000"), "toplam 10.000 öldürmede Efsane Avcı")
	_end()


func test_endless_layer_record_and_achievements() -> void:
	_begin()
	var r: Dictionary = RunRecordsScript.note_progress(_run(2500.0, 16, 100, 10))
	assert((r["records"] as Array).has("layer"), "sonsuz kat rekoru")
	assert((r["achievements"] as Array).has("layer_3") and (r["achievements"] as Array).has("layer_10"), "Kat 10: Kat 3 + Kat 10 başarımları")
	assert(not (r["achievements"] as Array).has("layer_25"))
	_end()


## Sözdizimi geçerli ama değer tipleri bozuk (elle düzenlenmiş dosya) - çökmemeli, makul varsayılana düşmeli. (Sözdizimi bozuk
## dosya motor ERROR satırı basar ve test koşturucusu onu yanlışlıkla hata sayar, bu yüzden o durum burada denenmiyor:
## cfg.load() != OK dalı "dosya yok" testiyle aynı yoldan varsayılana döner.)
func test_wrong_typed_values_do_not_crash() -> void:
	_begin()
	var f := FileAccess.open(_tmp, FileAccess.WRITE)
	f.store_string("[records]\nbest_time=\"abc\"\nruns=\"x\"\nvictory_chars=\"nope\"\n\n[achievements]\ntier_5=\"oops\"\n")
	f.close()
	var d: Dictionary = RunRecordsScript.load_all()
	assert(float(d["best_time"]) == 0.0 and int(d["runs"]) == 0, "yanlış tipli sayılar 0'a düşmeli")
	assert((d["victory_chars"] as Array).is_empty(), "yanlış tipli liste boş olmalı")
	var r: Dictionary = RunRecordsScript.note_progress(_run(60.0, 6, 10))
	assert(not (r["achievements"] as Array).has("tier_5"), "dosyada anahtarı olan başarım zaten açık sayılır")
	assert((r["records"] as Array).has("tier"), "bozuk dosya sonrası kayıt çalışmalı")
	_end()


func test_merge_results_dedupes() -> void:
	var into := {"records": ["time"], "achievements": ["tier_5"]}
	RunRecordsScript.merge_results(into, {"records": ["time", "tier"], "achievements": ["tier_5", "victory"]})
	assert(into["records"] == ["time", "tier"] and into["achievements"] == ["tier_5", "victory"], "tekrarsız birleşmeli: %s" % str(into))


func test_every_achievement_has_a_reachable_key() -> void:
	var keys := ["tier", "time", "kills", "layer", "victory", "victory_solo", "victory_coop", "victory_chars", "runs_total", "total_kills"]
	var ids := {}
	for d: Dictionary in AchievementsScript.DEFS:
		assert(keys.has(str(d["key"])), "tanımsız ctx anahtarı: %s" % str(d["key"]))
		assert(not ids.has(d["id"]), "tekrarlı başarım id: %s" % str(d["id"]))
		ids[d["id"]] = true
		assert(str(d["name"]) != "" and str(d["desc"]) != "", "ad/açıklama boş: %s" % str(d["id"]))


## 2026-10-05: yeniden başlatma yolları GameManager.reset()'i sahne değişmeden ÖNCE çağırıyor; Main'in _exit_tree'si çalıştığında süre/öldürme
## sıfırdı ve o koşunun toplamları kaydedilmiyordu. Artık reset() öncesi Main toplamları yazar (headless'ta _record_run dosyaya yazmaz;
## burada işaretin kurulması sınanır).
func test_main_records_run_end_before_restart_reset() -> void:
	var main_script: GDScript = load("res://scripts/main.gd")
	var long_run: Node = main_script.new()
	GameManager.reset()
	GameManager.game_time = 600.0
	GameManager.run_clock_origin = 0.0
	GameManager.run_about_to_reset.connect(long_run._record_run_end_once)
	GameManager.reset() ## yeniden başlatma: sinyal süre sıfırlanmadan önce gelmeli
	GameManager.run_about_to_reset.disconnect(long_run._record_run_end_once)
	assert(bool(long_run.get("_run_end_recorded")), "10 dk'lık koşu reset öncesi kaydedilmeli")
	long_run.free()
	var short_run: Node = main_script.new()
	GameManager.game_time = 5.0
	short_run._record_run_end_once()
	assert(not bool(short_run.get("_run_end_recorded")), "30 sn'den kısa koşu sayılmaz")
	short_run.free()
	GameManager.reset()
