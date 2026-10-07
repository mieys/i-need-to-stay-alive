extends RefCounted

## KOŞU REKORLARI + BAŞARIMLAR - kalıcı kayıt (kullanıcı isteği 2026-10-05, öneri 3). user://records.cfg (ConfigFile,
## ayar dosyalarıyla AYNI desen). Her oyuncu KENDİ makinesinde kendi kaydını tutar (çok oyunculuda host'un kaydı herkesinki
## değildir; takım istatistik tablosu ayrı, bkz. main.gd _match_stats_by_peer).
##
## Üç giriş noktası, hepsi {"records": [yeni kırılan rekor anahtarları], "achievements": [yeni açılan başarım id'leri]} döner:
##  - note_progress(özet): koşu İLERLERKEN (her kademe/kat bildiriminde) - en iyi değerleri hemen kaydeder; oyuncu menüye
##    çıksa / pencereyi kapatsa bile en yüksek kademe/kat/süre kaybolmaz.
##  - record_victory(özet): Final bosslarını yenince bir kez - zafer sayısı, zafer kazanılan karakter, en hızlı zafer.
##  - record_run_end(özet): koşu bitince bir kez (ölüm ekranı ya da menüye çıkış) - koşu sayısı, toplam öldürme/süre.
## özet = {"time" sn, "tier", "kills", "layer" (sonsuz kat, yoksa 0), "victory" bool, "solo" bool, "char_id"}.
##
## TEST/DEBUG GÜVENLİĞİ: yol `path_override` (testler) ya da LILSLAYERS_RECORDS_PATH ortam değişkeniyle (iki süreçli testler)
## değiştirilir - yoksa test koşuları kullanıcının gerçek rekorlarını kirletirdi. Debug modunda (GameManager.debug_mode_unlocked,
## istediğin yaratığı doğurma / saat hızı) main.gd HİÇ kayıt yazmaz.

const AchievementsScript: GDScript = preload("res://scripts/achievements.gd")

const DEFAULT_PATH := "user://records.cfg"
const ENV_PATH := "LILSLAYERS_RECORDS_PATH"
static var path_override: String = ""


## Testler için (GDScript: `const X := preload(...)` üzerinden statik değişkene atanamaz, bu yüzden ayarlayıcı). "" = varsayılana dön.
static func set_path_override(p: String) -> void:
	path_override = p


## Rekor anahtarı -> ekranda görünen ad (koşu sonu "YENİ REKOR" satırı + Rekorlar ekranı).
const RECORD_LABELS := {
	"time": "En uzun süre",
	"tier": "En yüksek kademe",
	"kills": "Tek koşuda en çok öldürme",
	"layer": "En yüksek sonsuz kat",
	"victory_time": "En hızlı zafer",
}


static func _path() -> String:
	if path_override != "":
		return path_override
	var env: String = OS.get_environment(ENV_PATH)
	return env if env != "" else DEFAULT_PATH


static func _defaults() -> Dictionary:
	return {
		"best_time": 0.0, "best_tier": 0, "best_kills": 0, "best_layer": 0, "best_victory_time": 0.0,
		"victories": 0, "runs": 0, "total_kills": 0, "total_time": 0.0,
		"victory_chars": [], "achievements": {},
	}


## Tüm kayıt (dosya yoksa/bozuksa sıfırlar). Rekorlar ekranı da bunu okur.
static func load_all() -> Dictionary:
	var data: Dictionary = _defaults()
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return data
	for key: String in ["best_time", "best_victory_time", "total_time"]:
		data[key] = float(cfg.get_value("records", key, 0.0))
	for key: String in ["best_tier", "best_kills", "best_layer", "victories", "runs", "total_kills"]:
		data[key] = int(cfg.get_value("records", key, 0))
	var chars: Array = []
	var raw_chars: Variant = cfg.get_value("records", "victory_chars", [])
	if raw_chars is Array: ## elle bozulmuş dosyada başka bir tip olabilir - çökmesin
		for c in raw_chars:
			chars.append(int(c))
	data["victory_chars"] = chars
	var ach: Dictionary = {}
	if cfg.has_section("achievements"):
		for id: String in cfg.get_section_keys("achievements"):
			ach[id] = int(cfg.get_value("achievements", id, 0))
	data["achievements"] = ach
	return data


static func _save(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for key: String in data.keys():
		if key == "achievements":
			continue
		cfg.set_value("records", key, data[key])
	for id: String in (data["achievements"] as Dictionary).keys():
		cfg.set_value("achievements", id, data["achievements"][id])
	cfg.save(_path())


static func _ctx(s: Dictionary, data: Dictionary) -> Dictionary:
	var victory: bool = bool(s.get("victory", false))
	var solo: bool = bool(s.get("solo", true))
	return {
		"tier": int(s.get("tier", 0)), "time": float(s.get("time", 0.0)),
		"kills": int(s.get("kills", 0)), "layer": int(s.get("layer", 0)),
		"victory": 1 if victory else 0,
		"victory_solo": 1 if (victory and solo) else 0,
		"victory_coop": 1 if (victory and not solo) else 0,
		"victory_chars": (data["victory_chars"] as Array).size(),
		"runs_total": int(data["runs"]), "total_kills": int(data["total_kills"]),
	}


## En iyi değerleri günceller, KIRILAN rekorların anahtarlarını döner (ilk koşuda hepsi "yeni" sayılır).
static func _apply_bests(data: Dictionary, s: Dictionary) -> Array:
	var fresh: Array = []
	var t: float = float(s.get("time", 0.0))
	var tier: int = int(s.get("tier", 0))
	var kills: int = int(s.get("kills", 0))
	var layer: int = int(s.get("layer", 0))
	if t > float(data["best_time"]):
		data["best_time"] = t
		fresh.append("time")
	if tier > int(data["best_tier"]):
		data["best_tier"] = tier
		fresh.append("tier")
	if kills > int(data["best_kills"]):
		data["best_kills"] = kills
		fresh.append("kills")
	if layer > int(data["best_layer"]):
		data["best_layer"] = layer
		fresh.append("layer")
	return fresh


static func _unlock(data: Dictionary, ctx: Dictionary) -> Array:
	var ids: Array = AchievementsScript.evaluate(ctx, data["achievements"])
	for id: String in ids:
		data["achievements"][id] = int(Time.get_unix_time_from_system())
	return ids


static func note_progress(s: Dictionary) -> Dictionary:
	var data: Dictionary = load_all()
	var fresh: Array = _apply_bests(data, s)
	var ach: Array = _unlock(data, _ctx(s, data))
	_save(data)
	return {"records": fresh, "achievements": ach}


static func record_victory(s: Dictionary) -> Dictionary:
	var sv: Dictionary = s.duplicate()
	sv["victory"] = true
	var data: Dictionary = load_all()
	var fresh: Array = _apply_bests(data, sv)
	data["victories"] = int(data["victories"]) + 1
	var cid: int = int(sv.get("char_id", -1))
	if cid >= 0 and not (data["victory_chars"] as Array).has(cid):
		(data["victory_chars"] as Array).append(cid)
	var t: float = float(sv.get("time", 0.0))
	if t > 0.0 and (float(data["best_victory_time"]) <= 0.0 or t < float(data["best_victory_time"])):
		data["best_victory_time"] = t
		fresh.append("victory_time")
	var ach: Array = _unlock(data, _ctx(sv, data))
	_save(data)
	return {"records": fresh, "achievements": ach}


static func record_run_end(s: Dictionary) -> Dictionary:
	var data: Dictionary = load_all()
	var fresh: Array = _apply_bests(data, s)
	data["runs"] = int(data["runs"]) + 1
	data["total_kills"] = int(data["total_kills"]) + int(s.get("kills", 0))
	data["total_time"] = float(data["total_time"]) + float(s.get("time", 0.0))
	var ach: Array = _unlock(data, _ctx(s, data))
	_save(data)
	return {"records": fresh, "achievements": ach}


## İki sonucu birleştirir (aynı koşuda birden fazla çağrının sonuçlarını ölüm ekranında tek listede göstermek için) - tekrarsız.
static func merge_results(into: Dictionary, add: Dictionary) -> void:
	for key: String in ["records", "achievements"]:
		var list: Array = into.get(key, [])
		for v in add.get(key, []):
			if not list.has(v):
				list.append(v)
		into[key] = list
