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
	"res://scripts/oakley_tree.gd",
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


## 2026-10-14: host menüye dönerken istemci kayıtlarını toplama (network_manager.gd collect_client_balance_records) - tek süreçte sadece
## korumalar sınanabilir (gerçek peer yok): bağlantı/oyun yokken hemen döner, bekleme listesini bırakmaz, tekrar girişe izin vermez.
func test_collect_client_balance_records_returns_at_once_without_peers() -> void:
	var nm: Node = get_node("/root/NetworkManager")
	var t0: int = Time.get_ticks_msec()
	await nm.collect_client_balance_records()
	assert(Time.get_ticks_msec() - t0 < 200, "peer yokken beklememeli")
	assert((nm._balance_ack_pending as Dictionary).is_empty(), "bekleme listesi boş")
	assert(not nm._balance_collecting, "toplama bayrağı kapalı")
	assert(nm.BALANCE_COLLECT_TIMEOUT_SEC >= 1.0 and nm.BALANCE_COLLECT_TIMEOUT_SEC <= 4.0, "bekleme sınırı makul (oda kapanışını uzatmasın)")


## 2026-10-15 (madde 168): öldürme/asist altını + verilen destek sayısı kayda girer (alıcı makinede KillGold.show_at çağırır).
func test_gold_and_assist_recorded() -> void:
	_begin()
	BalanceLogScript.on_kill_gold(5, 0)
	BalanceLogScript.on_kill_gold(3, 0)
	BalanceLogScript.on_kill_gold(4, 1) ## hasar asisti
	BalanceLogScript.on_kill_gold(2, 2) ## destek asisti
	BalanceLogScript.on_kill_gold(2, 2)
	BalanceLogScript.on_kill_gold(1, 3) ## ikisi
	BalanceLogScript.on_kill_gold(3, 4) ## takım payı (madde 308)
	BalanceLogScript.on_kill_gold(2, 4)
	BalanceLogScript.on_kill_gold(0, 1) ## 0 altın sayılmaz
	BalanceLogScript.note_support_sent()
	BalanceLogScript.note_support_sent()
	var rec: Dictionary = BalanceLogScript.build_record(null, _summary(), "end")
	assert(rec["gold_kill"] == [2, 8], "öldürme altını [adet, altın]: %s" % str(rec["gold_kill"]))
	var ga: Dictionary = rec["gold_assist"]
	assert(ga["dmg"] == [1, 4] and ga["sup"] == [2, 4] and ga["both"] == [1, 1], "asist türleri: %s" % str(ga))
	assert(ga["team"] == [2, 5], "takım payı [adet, altın]: %s" % str(ga))
	assert(int(rec["sup_sent"]) == 2, "destek sayısı")
	BalanceLogScript.reset()
	var rec2: Dictionary = BalanceLogScript.build_record(null, _summary(), "end")
	assert(rec2["gold_kill"] == [0, 0] and (rec2["gold_assist"] as Dictionary).is_empty() and int(rec2["sup_sent"]) == 0, "reset sıfırlar")
	_end()


## 2026-10-17 (madde 223): kayıt kapalıyken NEDEN kapalı olduğu okunur (main.gd / network_manager.gd net_log satırları bunu yazar) ve host
## reddettiği istemci kaydının nedenini bırakır. Debug bayrağı assert'ten ÖNCE geri alınır (assert yarıda keserse sonraki testlere sızmasın).
func test_disabled_reason_and_ingest_reject_reason() -> void:
	_begin()
	var open_reason: String = BalanceLogScript.disabled_reason()
	var json: String = JSON.stringify(BalanceLogScript.build_record(null, _summary(), "end"))
	var accepted: bool = BalanceLogScript.ingest_remote(json, 7)
	var accepted_reason: String = BalanceLogScript.last_ingest_reason
	var bad_json: bool = BalanceLogScript.ingest_remote("bu json degil", 7)
	var json_reason: String = BalanceLogScript.last_ingest_reason
	var bad_schema: bool = BalanceLogScript.ingest_remote(JSON.stringify({"schema": 99, "run_id": "x"}), 7)
	var schema_reason: String = BalanceLogScript.last_ingest_reason
	var too_big: bool = BalanceLogScript.ingest_remote("x".repeat(BalanceLogScript.MAX_RECORD_CHARS + 1), 7)
	var big_reason: String = BalanceLogScript.last_ingest_reason
	GameManager.debug_mode_unlocked = true
	var debug_reason: String = BalanceLogScript.disabled_reason()
	var debug_write: Dictionary = BalanceLogScript.write_run(null, _summary(), "end")
	var debug_ingest: bool = BalanceLogScript.ingest_remote(json, 7)
	var debug_ingest_reason: String = BalanceLogScript.last_ingest_reason
	GameManager.debug_mode_unlocked = false
	OS.set_environment(BalanceLogScript.ENV_PATH, "")
	var headless_reason: String = BalanceLogScript.disabled_reason()
	var lines: int = _lines().size()
	assert(open_reason == "", "yol verilmiş + debug kapalı: kayıt açık (%s)" % open_reason)
	assert(accepted and accepted_reason == "", "geçerli kayıt kabul edilir, neden boş")
	assert(not bad_json and "JSON" in json_reason, "bozuk kayıt: %s" % json_reason)
	assert(not bad_schema and "şema" in schema_reason, "yanlış şema: %s" % schema_reason)
	assert(not too_big and "büyük" in big_reason, "aşırı büyük: %s" % big_reason)
	assert("debug" in debug_reason, "debug açıkken neden debug olmalı: %s" % debug_reason)
	assert(debug_write.is_empty() and not debug_ingest, "debug açıkken ne yerel kayıt yazılır ne istemci kaydı kabul edilir")
	assert("debug" in debug_ingest_reason, "host kaydı debug yüzünden reddetti: %s" % debug_ingest_reason)
	assert("headless" in headless_reason, "headless + yol yok: %s" % headless_reason)
	assert(lines == 1, "yalnız ilk geçerli kayıt dosyaya yazıldı (%d satır)" % lines)
	_end()


## main.gd kayıt günlüğü yardımcıları: neden metni, atlama satırının Main başına bir kez yazılması, headless'ta gerçek net_log'a YAZMAMA.
func test_main_record_log_helpers() -> void:
	var m: Node = (load("res://scripts/main.gd") as GDScript).new()
	var headless_reason: String = m._record_skip_reason()
	GameManager.debug_mode_unlocked = true
	var debug_reason: String = m._record_skip_reason()
	GameManager.debug_mode_unlocked = false
	m._record_log_once("a")
	m._record_log_once("a")
	m._record_log_once("b")
	var seen: int = (m._record_log_seen as Dictionary).size()
	var marker: String = "HEADLESS_MARKER_%d" % Time.get_ticks_usec()
	m._record_log(marker)
	var leaked: bool = false
	if FileAccess.file_exists("user://net_log.txt"):
		leaked = FileAccess.get_file_as_string("user://net_log.txt").contains(marker)
	m.free()
	assert(headless_reason == "headless", "testte neden headless: %s" % headless_reason)
	assert("debug" in debug_reason, "debug açıkken neden debug: %s" % debug_reason)
	assert(seen == 2, "aynı atlama satırı bir kez (%d farklı satır)" % seen)
	assert(not leaked, "headless koşu gerçek net_log.txt'ye yazmamalı")


## 2026-10-17 (madde 223): host menüye çıkarken KENDİ kaydı odayı kapatmadan ÖNCE yazılır (Main'in flush_run_record_before_leave'i oda hâlâ
## açıkken çağrılır) - eskiden close_room() sonrası _exit_tree'de alındığı için host'un kaydı hep solo=True, team=1 çıkıyordu. Bu test dosyası
## sahte "Main" olur (aşağıdaki flush_run_record_before_leave).
var _flush_calls: int = 0
var _flush_mp_active: bool = false


func flush_run_record_before_leave() -> bool:
	_flush_calls += 1
	_flush_mp_active = NetworkManager.is_multiplayer_active
	return false


func test_host_flushes_own_record_while_room_still_open() -> void:
	var prev_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var old_host: bool = NetworkManager.is_host
	var old_active: bool = NetworkManager.is_multiplayer_active
	_flush_calls = 0
	NetworkManager.is_host = true
	NetworkManager.is_multiplayer_active = true
	await NetworkManager.flush_balance_before_leave()
	var host_calls: int = _flush_calls
	var active_at_call: bool = _flush_mp_active
	NetworkManager.is_multiplayer_active = false ## host ama çok oyunculu değil: dokunmaz (tek oyunculuda _exit_tree zaten doğru)
	await NetworkManager.flush_balance_before_leave()
	var inactive_calls: int = _flush_calls
	NetworkManager.is_host = false ## istemci: bu yol host'un kaydını yazmaz (kendi kaydı flush_run_record_before_leave ile peer varken gider)
	NetworkManager.is_multiplayer_active = true
	await NetworkManager.flush_balance_before_leave()
	var client_calls: int = _flush_calls
	NetworkManager.is_host = old_host
	NetworkManager.is_multiplayer_active = old_active
	if prev_scene != null and is_instance_valid(prev_scene) and prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = prev_scene
	assert(host_calls == 1, "host menüye çıkarken kendi kaydını bir kez yazmalı (%d)" % host_calls)
	assert(active_at_call, "kayıt oda HÂLÂ açıkken (is_multiplayer_active true) alınmalı")
	assert(inactive_calls == 1, "çok oyunculu değilse host yolu dokunmaz (%d)" % inactive_calls)
	assert(client_calls == 1, "istemci bu yoldan host kaydı yazmaz (%d)" % client_calls)


## ---- Madde 269 (2026-10-18): sonsuz kat kırılımı, bitiş statları, kart seçimleri ----

## Kayıtta okunan alanları taşıyan sahte oyuncu (gerçek player.gd'yi yüklemeden).
class StatsPlayer extends Node:
	var match_damage_dealt: float = 1000.0
	var match_damage_taken: float = 250.0
	var damage_bonus: float = 321.0
	var max_health: float = 9280.0
	var crit_chance_bonus: float = 0.35
	var crit_damage_bonus: float = 0.6
	var exp_gain_percent: float = 2.05
	var luck: float = 41.0
	var heal_regen_card_bonus: float = 10.0
	var item_health_regen: float = 81.0
	var upgrade_log: Array = [["damage", 1], ["damage", 3], ["damage", 3], ["max_health", 2], ["luck", 9]]

	func get_attack_speed_bonus_percent() -> float:
		return 600.0

	func get_attack_speed_overflow_percent() -> float:
		return 42.0


func test_note_layer_records_once_per_layer_and_ignores_non_endless() -> void:
	_begin()
	var p := StatsPlayer.new()
	add_child(p)
	BalanceLogScript.note_layer(0, p) ## sonsuz değil: yok sayılır
	BalanceLogScript.note_layer(-3, p)
	BalanceLogScript.note_layer(2, p)
	p.damage_bonus = 999.0
	BalanceLogScript.note_layer(2, p) ## aynı kat ikinci kez: ilk anlık görüntü korunur
	var rec: Dictionary = BalanceLogScript.build_record(p, _summary(), "end")
	var layers: Dictionary = rec["layers"]
	assert(layers.keys() == ["2"], "yalnız kat 2 kaydı beklenir: %s" % str(layers.keys()))
	var row: Array = layers["2"]
	assert(row.size() == 9, "satır 9 alan: %d" % row.size())
	assert(is_equal_approx(float(row[5]), 321.0), "ilk anlık görüntüdeki saldırı gücü korunmalı: %s" % str(row[5]))
	assert(is_equal_approx(float(row[6]), 9280.0) and is_equal_approx(float(row[7]), 600.0), "can ve saldırı hızı: %s" % str(row))
	p.free()
	_end()


func test_layers_are_cleared_by_reset_and_survive_json() -> void:
	_begin()
	BalanceLogScript.note_layer(1, null)
	var rec: Dictionary = BalanceLogScript.build_record(null, _summary(), "end")
	assert((rec["layers"] as Dictionary).has("1"), "oyuncusuz da kat satırı yazılır")
	var back: Variant = JSON.parse_string(JSON.stringify(rec))
	assert(back is Dictionary and (back["layers"] as Dictionary).has("1"), "JSON gidiş-dönüşünde kat korunmalı")
	BalanceLogScript.reset()
	assert((BalanceLogScript.build_record(null, _summary(), "end")["layers"] as Dictionary).is_empty(), "reset katları temizler")
	_end()


func test_player_stats_and_cards_in_record() -> void:
	_begin()
	var p := StatsPlayer.new()
	add_child(p)
	var rec: Dictionary = BalanceLogScript.build_record(p, _summary(), "end")
	var st: Dictionary = rec["stats"]
	assert(is_equal_approx(float(st["ap"]), 321.0) and is_equal_approx(float(st["hp"]), 9280.0), "ap/hp: %s" % str(st))
	assert(is_equal_approx(float(st["atk"]), 600.0) and is_equal_approx(float(st["atk_over"]), 42.0), "saldırı hızı: %s" % str(st))
	assert(is_equal_approx(float(st["regen"]), 91.0), "yenilenme = kart + eşya: %s" % str(st["regen"]))
	assert(is_equal_approx(float(st["exp"]), 2.05) and is_equal_approx(float(st["exp_eff"]), GameManager.EXP_GAIN_CAP), "ham ve etkin XP bonusu ayrı: %s" % str(st))
	assert(is_equal_approx(float(st["dodge"]), 0.0), "oyuncuda olmayan alan 0")
	var cards: Dictionary = rec["cards"]
	assert(cards["damage"] == [1, 0, 2, 0], "damage kartları kademe sayımı: %s" % str(cards["damage"]))
	assert(cards["max_health"] == [0, 1, 0, 0] and cards["luck"] == [0, 0, 0, 1], "diğer kartlar (kademe 1-4 dışı 4'e kısılır): %s" % str(cards))
	assert((BalanceLogScript.build_record(null, _summary(), "end")["stats"] as Dictionary).is_empty(), "oyuncusuz stats boş")
	assert((BalanceLogScript.build_record(null, _summary(), "end")["cards"] as Dictionary).is_empty(), "oyuncusuz cards boş")
	p.free()
	_end()


func test_record_with_new_fields_stays_under_the_host_size_limit() -> void:
	_begin()
	var p := StatsPlayer.new()
	for i in 200:
		p.upgrade_log.append(["card_%d" % (i % 30), 1 + (i % 4)])
	add_child(p)
	for layer in range(1, 41):
		BalanceLogScript.note_layer(layer, p)
	var json: String = JSON.stringify(BalanceLogScript.build_record(p, _summary(), "end"))
	assert(json.length() < BalanceLogScript.MAX_RECORD_CHARS - 6000, "40 katlı kayıt (eşyasız) host sınırına yakın olmamalı: %d" % json.length())
	p.free()
	_end()
