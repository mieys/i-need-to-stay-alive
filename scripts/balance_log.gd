extends RefCounted

## BALANS TELEMETRİSİ (kullanıcı isteği 2026-10-11: "neyin dengesiz olduğunu anlayabileceğimiz bir sistem"). Her koşu bitince
## user://balans/kosular.jsonl dosyasına TEK SATIR JSON eklenir (Windows: %APPDATA%\Godot\app_userdata\Temiz Sürüm\balans\).
## Çok oyunculuda istemciler kendi kaydını host'a da yollar (NetworkManager.submit_balance_record) - host kendi dosyasına
## "via":"host" ile ekler. Aynı koşu iki dosyada olabilir: raporda run_id ile tekilleştirilir (tools/balans_rapor.ps1).
## Rapor: tools/balans_rapor.ps1 -> docs/balans/rapor.md. Format ayrıntısı: docs/notlar/madde_71-80.md (madde 75).
##
## BALANCE_REV: denge sabitlerini (hasar, can, bekleme, yaratık gücü...) değiştirdiğinde BİR ARTIR - rapor yalnız en son
## revizyonu baz alır (eski denge verisi yeni dengeyi yanıltmasın). Artırmayı unutursan eski+yeni veri karışır.
##
## HASAR KAYNAĞI: enemy.take_damage() hasarın kaynağını bilmez. Çağıran taraf hemen önce tag()/tag_weapon() ile etiketler, take_damage
## etiketi okuyup SİLER (take_src). Etiketsiz hasar "diger" (yetenekler, evrimler, efsunlar...) olur - rapor bu payı gösterir.
## Etiketlenen yerler: weapon.gd, projectile.gd, boomerang_projectile.gd, firework_projectile.gd (silahlar -> "w:<shop_key>"),
## enemy.gd DOT tiki ("dot"). Yetenek (Q/E/R) kırılımı için player.gd'deki take_damage çağrılarına tag(&"s:q") eklenebilir.

const CharactersScript: GDScript = preload("res://scripts/characters.gd")
const BALANCE_REV := 21 ## 21: eşya kaynaklı bekleme azaltma da %60 üst sınırında (eskiden sadece kartlar) (2026-10-13); 20: yaratık kalkan soğurması normal %30 -> %60 (Kademe 7'de tam), elit %80 (2026-10-13); 19: eşya/ruhani/evcil saldırı hızı havuzu hıza EKLENİR (aralık = 1/(1+toplam)); eskiden 1'den çıkarılıp yüzük yığınında katlanıyordu (2026-10-13); 18: evcil hayvan Kirpi (sana saldıran yaratık azami kalkanının %5'i kadar hasar alır; kalkan varken alınan hasar %5 az) (2026-10-13); 17: evcil hayvan Peri (can eksikken 6 sn'de bir saldırı gücünün %10'u kadar can) (2026-10-12); 16: evcil hayvan Kelebek Ruhu (+%10 saldırı hızı, ilk silah isabetine saldırı gücünün %20'si lazer) (2026-10-12); 15: Savaş Kalkanı savaşta (son 3 sn hasar) yenilenme x0,5 + geliştirme başına yenilenme +2 -> +1,5 (2026-10-12); 14: evcil hayvanlar (köpek: sahibin statlarıyla saldırır; papağan: altın toplar + 10 şans) (2026-10-12); 13: Korsan pasifi Altın Avcısı (öldürme başına 1 altın, 30 altın = +1 saldırı gücü; Papağan kalktı) (2026-10-12); 12: silah parçacığı düşme şansı %1 -> %0,5, eşya satış iadesi %70 -> %50 (2026-10-12); 11: Matthew rework - köpek yok, şimşek kiti (pasif Yıldırım Hızı, E Elektrik Topu, R köpeksiz) (2026-10-12); 10: Ejderha Nefesi menzil x1,5 / açı x1,25 (eskiden x2 / x1,5) (2026-10-12); 9: silah sınırı 3 + silah hasarı x1,5 (yakın dövüş x2,1) deneme (2026-10-12); 8: Şovalye pasifi Dirençli Duruş (%40 altı %20 az hasar; Dikenli Zırh kalktı) (2026-10-12); 7: Elara pasifi gerçek +%50 hız + taşma dışı, Tüfek delme hasarı %70 (2026-10-12); 6: yaratık hasarı x0,8 iptal + Balkabağı güçlendirme (2026-10-11)
const SCHEMA := 1
const DIR_PATH := "user://balans"
const FILE_NAME := "kosular.jsonl"
const ENV_PATH := "LILSLAYERS_BALANCE_PATH" ## testler/bot koşuları için dosya yolu (tam yol) - yoksa varsayılan
const MAX_FILE_BYTES := 4 * 1024 * 1024 ## aşılırsa eski dosya kosular_eski.jsonl'e taşınır (4 MB ~ binlerce koşu)
const MAX_RECORD_CHARS := 20000 ## host'a gelen kayıt sınırı (RPC güvenliği)
const MAX_KEYS := 80

static var _src: String = ""
static var _dealt: Dictionary = {} ## kaynak -> [hasar, isabet, kritik]
static var _taken: Dictionary = {} ## yaratık ailesi -> alınan hasar
static var _dealt_tier: Dictionary = {} ## kademe(int) -> verilen hasar
static var _taken_tier: Dictionary = {} ## kademe(int) -> alınan hasar
static var _tier_time: Dictionary = {} ## kademe(int) -> o kademeye ilk girilen koşu saniyesi
static var _killer: String = "" ## bize en son vuran kaynak ailesi (ölüm sebebi tahmini)
## 2026-10-12 (madde 105): ölüm zamanı, silah/eşya edinme zamanı. Edinme, her ~5 sn'de bir sahip olunanları bir önceki örnekle karşılaştırarak
## bulunur (silah/eşya ekleyen 6 yere kanca koymamak için); çözünürlük SAMPLE_INTERVAL.
const SAMPLE_INTERVAL := 5.0
const MAX_DOWNS := 12
static var _downs: Array = [] ## [[koşu sn, kademe], ...] yere düşüş + kalıcı ölüm sırasıyla
static var _death_t: float = -1.0 ## kalıcı ölümün koşu saniyesi (-1 = ölmedi)
static var _death_tier: int = 0
static var _got_weapons: Array = [] ## [[anahtar, koşu sn], ...] edinme sırasıyla
static var _got_items: Array = []
static var _seen_weapons: Dictionary = {} ## anahtar -> görülen adet
static var _seen_items: Dictionary = {}
static var _next_sample: float = 0.0


static func reset() -> void:
	_src = ""
	_dealt.clear()
	_taken.clear()
	_dealt_tier.clear()
	_taken_tier.clear()
	_tier_time.clear()
	_killer = ""
	_downs.clear()
	_death_t = -1.0
	_death_tier = 0
	_got_weapons.clear()
	_got_items.clear()
	_seen_weapons.clear()
	_seen_items.clear()
	_next_sample = 0.0


## ---- Etiketleme ----

static func tag(source: StringName) -> void:
	_src = String(source)


## Silahın shop_key'i (weapon.gd set_meta) -> "w:<key>". Geçersiz/anahtarsız silah etiketlemez ("diger" kalır).
static func tag_weapon(weapon: Variant) -> void: ## Variant: silahı satılmış/silinmiş merminin çağrısı tipli parametrede hata verirdi
	if weapon == null or (weapon is Object and not is_instance_valid(weapon)):
		_src = ""
		return
	if weapon != null and is_instance_valid(weapon) and weapon is Node and (weapon as Node).has_meta("shop_key"):
		_src = "w:" + str((weapon as Node).get_meta("shop_key"))
	else:
		_src = ""


## enemy.take_damage'ın EN BAŞINDA: etiketi okur ve siler (erken dönüşlerde sonraki isabete sızmasın).
static func take_src() -> String:
	var s: String = _src
	_src = ""
	return s


## ---- Toplama (dealer-side: enemy.take_damage / _take_dot_damage; player.take_damage) ----

static func on_hit(source: String, amount: float, is_crit: bool) -> void:
	if amount <= 0.0:
		return
	var key: String = source if source != "" else "diger"
	var row: Array = _dealt.get(key, [0.0, 0, 0])
	row[0] += amount
	row[1] += 1
	if is_crit:
		row[2] += 1
	_dealt[key] = row
	var t: int = GameManager.run_max_tier
	_dealt_tier[t] = float(_dealt_tier.get(t, 0.0)) + amount
	_maybe_sample()


static func on_taken(amount: float, source: Node) -> void:
	if amount <= 0.0:
		return
	var fam: String = _family_of(source)
	_taken[fam] = float(_taken.get(fam, 0.0)) + amount
	_killer = fam
	var t: int = GameManager.run_max_tier
	_taken_tier[t] = float(_taken_tier.get(t, 0.0)) + amount
	_maybe_sample()


## player.gd _go_down (permanent=false) / _finalize_death (permanent=true) çağırır.
static func note_down(permanent: bool) -> void:
	var now: float = GameManager.run_elapsed()
	if _downs.size() < MAX_DOWNS:
		_downs.append([_r1(now), GameManager.run_max_tier])
	if permanent and _death_t < 0.0:
		_death_t = now
		_death_tier = GameManager.run_max_tier


static func _maybe_sample() -> void:
	var now: float = GameManager.run_elapsed()
	if now < _next_sample:
		return
	_next_sample = now + SAMPLE_INTERVAL
	sample_loadout()


## Sahip olunan silah/eşya adetlerini bir önceki örnekle karşılaştırır; artanlar şimdiki koşu saniyesiyle "edinildi" listesine eklenir.
static func sample_loadout() -> void:
	var now: float = _r1(GameManager.run_elapsed())
	_diff_owned(GameManager.owned_weapons, _seen_weapons, _got_weapons, now)
	_diff_owned(GameManager.owned_items, _seen_items, _got_items, now)


static func _diff_owned(owned: Array, seen: Dictionary, got: Array, now: float) -> void:
	var counts: Dictionary = {}
	for e in owned:
		if e is Dictionary:
			var k: String = str((e as Dictionary).get("key", ""))
			counts[k] = int(counts.get(k, 0)) + 1
	for k in counts:
		for _i in range(int(counts[k]) - int(seen.get(k, 0))):
			if got.size() < MAX_KEYS * 2:
				got.append([k, now])
	seen.clear()
	seen.merge(counts)


static func note_tier(tier: int) -> void:
	if not _tier_time.has(tier):
		_tier_time[tier] = GameManager.run_elapsed()


static func _family_of(source: Node) -> String:
	if source == null or not is_instance_valid(source):
		return "?"
	if source.has_method("creature_family"):
		var f: String = str(source.call("creature_family"))
		if f != "":
			return ("elit_" if source.get("is_elite") == true else "") + f
	var scr: Script = source.get_script()
	if scr != null:
		return str(scr.resource_path.get_file().get_basename())
	return source.name


## ---- Kayıt ----

static func _enabled() -> bool:
	if GameManager.debug_mode_unlocked:
		return false
	## Headless koşular (testler) gerçek dosyayı kirletmesin; yalnız yol AÇIKÇA verildiyse (bot/analiz koşusu) yazılır.
	if DisplayServer.get_name() == "headless" and OS.get_environment(ENV_PATH) == "":
		return false
	return true


static func _file_path() -> String:
	var env: String = OS.get_environment(ENV_PATH)
	return env if env != "" else DIR_PATH.path_join(FILE_NAME)


static func _top(d: Dictionary, n: int) -> Dictionary:
	if d.size() <= n:
		return d
	var keys: Array = d.keys()
	keys.sort_custom(func(a, b): return _scalar(d[a]) > _scalar(d[b]))
	var out: Dictionary = {}
	for i in n:
		out[keys[i]] = d[keys[i]]
	return out


static func _scalar(v: Variant) -> float:
	return float((v as Array)[0]) if v is Array else float(v)


static func _r1(x: float) -> float:
	return snappedf(x, 0.1)


## Koşunun tam kaydı. summary = main.gd _run_summary(); kind = "end" | "victory".
static func build_record(player: Node, summary: Dictionary, kind: String) -> Dictionary:
	var by_src: Dictionary = {}
	for k in _top(_dealt, MAX_KEYS):
		var row: Array = _dealt[k]
		by_src[k] = [_r1(row[0]), row[1], row[2]]
	var taken: Dictionary = {}
	for k in _top(_taken, MAX_KEYS):
		taken[k] = _r1(_taken[k])
	var dealt_tier: Dictionary = {}
	for t in _dealt_tier:
		dealt_tier[str(t)] = _r1(_dealt_tier[t])
	var taken_tier: Dictionary = {}
	for t in _taken_tier:
		taken_tier[str(t)] = _r1(_taken_tier[t])
	var tier_time: Dictionary = {}
	for t in _tier_time:
		tier_time[str(t)] = _r1(_tier_time[t])
	var weapons: Array = []
	for e in GameManager.owned_weapons:
		if not (e is Dictionary):
			continue
		var w: Dictionary = {"k": str(e.get("key", "")), "l": int(e.get("level", 1))}
		var ench: Variant = e.get("enchant", {})
		if ench is Dictionary and not (ench as Dictionary).is_empty():
			w["tr"] = str((ench as Dictionary).get("id", ""))
			w["up"] = ((ench as Dictionary).get("ups", []) as Array).size()
		weapons.append(w)
	var items: Array = []
	for e in GameManager.owned_items:
		if e is Dictionary:
			items.append(str((e as Dictionary).get("key", "")))
	sample_loadout() ## son örnek: koşu bitmeden alınanlar da kayda girsin
	var shield_key: String = ShieldEnchantDefs.owned_type()
	var shield_ups: Array = []
	for u in GameManager.shield_enchant_ups:
		shield_ups.append(int(u))
	var evo: Array = []
	var dealt_total: float = 0.0
	var taken_total: float = 0.0
	var max_hp: float = 0.0
	if player != null and is_instance_valid(player):
		if player.has_method("get_skill_evolution_ids"):
			for id in player.get_skill_evolution_ids():
				evo.append(str(id))
		dealt_total = float(player.get("match_damage_dealt"))
		taken_total = float(player.get("match_damage_taken"))
		max_hp = float(player.get("max_health"))
	var peers: int = 1
	if NetworkManager.is_multiplayer_active and multiplayer_peer_count() > 0:
		peers = multiplayer_peer_count()
	return {
		"schema": SCHEMA,
		"rev": BALANCE_REV,
		"run_id": "%d-%d" % [Time.get_unix_time_from_system(), randi() % 1000000],
		"when": Time.get_datetime_string_from_system(true),
		"player": NetworkManager.local_player_name if NetworkManager.local_player_name != "" else "solo",
		"kind": kind,
		"char": int(summary.get("char_id", 0)),
		"char_name": str(CharactersScript.get_def(int(summary.get("char_id", 0))).get("name", "?")),
		"solo": bool(summary.get("solo", true)),
		"team": peers,
		"time": _r1(float(summary.get("time", 0.0))),
		"tier": int(summary.get("tier", 1)),
		"layer": int(summary.get("layer", 0)),
		"kills": int(summary.get("kills", 0)),
		"level": int(summary.get("level", 1)),
		"victory": bool(summary.get("victory", false)),
		"dead": GameManager.is_game_over,
		"killer": _killer,
		"max_hp": _r1(max_hp),
		"dealt": _r1(dealt_total),
		"taken": _r1(taken_total),
		"weapons": weapons,
		"items": items,
		"evo": evo,
		"by_src": by_src,
		"taken_by": taken,
		"dealt_tier": dealt_tier,
		"taken_tier": taken_tier,
		"tier_time": tier_time,
		"shield": shield_key,
		"shield_ups": shield_ups,
		"pet": str(GameManager.selected_pet),
		"downs": _downs.duplicate(),
		"death_t": _r1(_death_t) if _death_t >= 0.0 else -1.0,
		"death_tier": _death_tier,
		"got_weapons": _got_weapons.duplicate(),
		"got_items": _got_items.duplicate(),
	}


static func multiplayer_peer_count() -> int:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.get_multiplayer() == null or not tree.get_multiplayer().has_multiplayer_peer():
		return 1
	return tree.get_multiplayer().get_peers().size() + 1


## Koşuyu yerel dosyaya yazar ve kaydı döndürür (boş = yazılmadı). Çağıran istemciyse kaydı host'a da yollar (main.gd).
static func write_run(player: Node, summary: Dictionary, kind: String) -> Dictionary:
	if not _enabled():
		return {}
	var rec: Dictionary = build_record(player, summary, kind)
	append_line(JSON.stringify(rec))
	return rec


## Tek satırı dosyaya ekler (yerel kayıt ve host'un aldığı kayıtlar). Boyut aşılırsa eskisi taşınır.
static func append_line(line: String) -> void:
	var path: String = _file_path()
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	if FileAccess.file_exists(path):
		var f0 := FileAccess.open(path, FileAccess.READ)
		var size: int = f0.get_length() if f0 else 0
		if f0:
			f0.close()
		if size > MAX_FILE_BYTES:
			DirAccess.rename_absolute(path, path.get_basename() + "_eski.jsonl")
	var f: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(line)
	f.close()


## Host'un aldığı istemci kaydı: doğrula, "via":"host" ekle, ekle. Geçersiz/aşırı büyük kayıt sessizce atılır.
static func ingest_remote(json_text: String, sender_peer: int) -> bool:
	if not _enabled() or json_text.length() > MAX_RECORD_CHARS:
		return false
	var parsed: Variant = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return false
	var rec: Dictionary = parsed
	if int(rec.get("schema", 0)) != SCHEMA or str(rec.get("run_id", "")) == "":
		return false
	rec["via"] = "host"
	rec["peer"] = sender_peer
	append_line(JSON.stringify(rec))
	return true
