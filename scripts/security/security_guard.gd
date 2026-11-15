extends RefCounted

## HİLE KORUMASI - ortak kapı (kullanıcı isteği 2026-11-12: "oyunumu hacklemeye karşı koruyacak bir sistem gerekiyor, insanlar kolayca
## hackleyebiliyor"). Ayrıntı: docs/notlar/madde_161-170.md (güvenlik maddesi). DÜRÜST SINIR: istemci tarafında hiçbir koruma mutlak
## değildir (exe kullanıcının makinesinde); amaç "Not Defteri / Cheat Engine / herkesin bildiği kod" seviyesini kapatıp çıtayı yükseltmek.
##
## 1) GELİŞTİRİCİ KAPISI: `dev_allowed()` yalnız Godot EDİTÖR ikilisinde (testler, tools/*, "F5") true; dışarı verilen exe'de
##    (debug şablonu dahil) false. Debug modu, ortam değişkeni kısayolları (LILSLAYERS_UNLOCK_ALL, HARITA, MOD, LILSLAYERS_UID, kayıt yolu)
##    buna bağlı: exportta ÇALIŞMAZ. Ortam değişkenini her zaman `dev_env()` ile oku (ham OS.get_environment değil).
## 2) BÜTÜNLÜK BAYRAĞI: `tampered` bu oturumda bir hile belirtisi görüldüyse true (korumalı sayı bozulmuş, ek paket/--main-pack ...).
##    true iken kalıcı kayıt (meta.cfg / records.cfg) YAZILMAZ: hileli koşu ilerleme / rekor / anahtar kazandırmaz. Sessiz (kullanıcıya yazı
##    çıkmaz), neden `user://security_log.txt`'ye yazılır.

const LOG_PATH := "user://security_log.txt"
const LOG_MAX_BYTES := 262144

static var tampered: bool = false
static var reasons: Array[String] = []


## Yalnız Godot editörü ikilisinde true (testler / araçlar / geliştirici). Exported exe'de her zaman false.
static func dev_allowed() -> bool:
	return OS.has_feature("editor")


## Geliştirici ortam değişkeni: yalnız editörde okunur, exportta hep "" döner (yani kısayol yok).
static func dev_env(env_name: String) -> String:
	if not dev_allowed():
		return ""
	return OS.get_environment(env_name)


## Hile belirtisi kaydet. `fatal`: true ise oturum "tampered" olur (kayıt yazımı kapanır); false ise yalnız günlük.
static func report(reason: String, fatal: bool = true) -> void:
	if fatal:
		tampered = true
	if reasons.has(reason):
		return
	reasons.append(reason)
	_log("%s %s" % ["!" if fatal else "-", reason])


## Test yardımcısı: bayrağı ve nedenleri sıfırlar (testler birbirini etkilemesin).
## (Adı `reset_state` OLMASIN: o adla çağrı gövdeye hiç girmiyordu, sessizce hiçbir şey yapmıyordu - 4.7.2'de ölçüldü, nedeni araştırılmadı.)
static func clear_flags() -> void:
	tampered = false
	reasons.clear()


static func _log(line: String) -> void:
	var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE
	var f := FileAccess.open(LOG_PATH, mode)
	if f == null:
		return
	if f.get_length() > LOG_MAX_BYTES:
		f.close()
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if f == null:
			return
	f.seek_end()
	f.store_line("[%s] %s" % [Time.get_datetime_string_from_system(), line])
	f.close()


## Kurulum taraması (açılışta bir kez, yalnız exportta): oyunun yanına eklenmiş ek paket (.pck) ya da `--main-pack` / `--script` gibi
## motor argümanları = betik/veri değiştirme girişimi. `override.cfg` meşru kullanıcılarda da olabilir (grafik ayarı) -> yalnız günlük.
static func scan_install() -> void:
	if dev_allowed():
		return
	for a: String in OS.get_cmdline_args():
		var low: String = a.to_lower()
		if low == "--main-pack" or low == "--script" or low == "-s" or low == "--path" or low == "--editor" or low == "--remote-debug" \
				or low == "--gdb-stub" or low == "--debug":
			report("motor argümanı: %s" % low)
	var dir_path: String = OS.get_executable_path().get_base_dir()
	if dir_path == "" or not DirAccess.dir_exists_absolute(dir_path):
		return
	var exe_base: String = OS.get_executable_path().get_file().get_basename().to_lower()
	for f: String in DirAccess.get_files_at(dir_path):
		var lf: String = f.to_lower()
		if lf == "override.cfg":
			report("override.cfg bulundu", false)
		elif lf.ends_with(".pck") and lf.get_basename() != exe_base:
			## Ek paket kendiliğinden yüklenmez (yalnız --main-pack yükler, o yukarıda ölümcül): yanlış alarm (exe yeniden adlandırma) yüzünden
			## meşru oyuncunun ilerlemesi yazılmasın diye yalnız günlük.
			report("ek paket: %s" % lf, false)
