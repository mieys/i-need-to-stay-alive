extends RefCounted

## MÜHÜRLÜ KAYIT DOSYASI (kullanıcı isteği 2026-11-12, hile koruması). meta.cfg (Ruh Kıymığı/kilitler/anahtarlar) ve records.cfg (rekorlar +
## başarımlar) eskiden düz ConfigFile metniydi: Not Defteri ile açıp "shards=999999" yazmak yetiyordu.
##
## BİÇİM: motorun AES şifreli dosyası (`FileAccess.open_encrypted`, anahtar koda gömülü parçalardan türetilir, dosya türü başına ayrı)
## + içinde [MAGIC, ConfigFile metni, HMAC-SHA256(metin)] üç Pascal dizgisi. Anahtarı bilmeyen içeriği okuyamaz da, değiştirip imzalayamaz da.
## DÜRÜST SINIR: anahtar exe'nin içinde -> betiği çözüp çıkaran biri sahte dosya üretebilir; bu "Not Defteri" seviyesini kapatır.
##
## ESKİ (DÜZ METİN) KAYITLAR: eski sürümden gelen oyuncuların dosyası düz metindir. `LEGACY_PLAIN_UNTIL_UNIX`e kadar (ve editörde hep)
## kabul edilir, çağıran ilk fırsatta mühürlü yazar (taşıma). Süre dolunca düz dosya = geçersiz. Daha erken kapatmak için tarihi öne çek.
##
## GEÇERSİZ DOSYA (anahtar/imza uymuyor, bozuk): `<dosya>.bak` (son iyi mühürlü kopya) varsa ona dönülür, yoksa varsayılana düşülür;
## bozuk dosya `<dosya>.bozuk`a taşınır (kullanıcı elle bakabilsin). Yazım ATOMİK: önce `.tmp`, sonra yer değiştirme (yarım yazım kaydı bozmaz).

enum Status { OK, MISSING, LEGACY, TAMPERED }

const Guard := preload("res://scripts/security/security_guard.gd")

const MAGIC := "LSv1"
const BACKUP_SUFFIX := ".bak"
const BAD_SUFFIX := ".bozuk"
const LEGACY_PLAIN_UNTIL_UNIX := 1798761600 ## 2027-01-01 00:00 UTC
const ENC_HEADER: PackedByteArray = [0x47, 0x44, 0x45, 0x43] ## motorun şifreli dosya başlığı ("GDEC")

## Anahtar malzemesi: iki bayt dizisinin XOR'u (düz metin dizgi olarak exe'de aranamasın). Türe (tag) göre ayrışır.
const _M1: Array = [70, 52, 56, 31, 222, 168, 186, 204, 29, 39, 126, 130, 212, 217, 67, 234, 217, 21, 192, 168, 60, 199, 199, 151, 190, 250, 207, 169, 95, 171, 113, 217, 172, 80, 34, 142, 243, 193, 13, 111, 6, 217, 242, 141, 87, 54, 53, 84]
const _M2: Array = [59, 19, 220, 240, 213, 233, 24, 89, 98, 96, 89]
const _S1: Array = [41, 21, 58, 31, 136, 222, 108, 174, 212, 102, 217, 31, 227, 82, 82, 221, 221, 80, 97, 122, 198, 97, 102, 107, 63, 58, 4, 133, 66, 151, 224, 148, 51, 34, 251, 29, 224, 106, 117, 119, 135, 131, 80, 32, 193, 175, 10, 96]
const _S2: Array = [98, 64, 186, 144, 36, 164, 208, 119, 213, 57, 35, 239, 171]


static func legacy_allowed() -> bool:
	return Guard.dev_allowed() or Time.get_unix_time_from_system() < LEGACY_PLAIN_UNTIL_UNIX


static func _derive(a: Array, b: Array, tag: String) -> PackedByteArray:
	var raw := PackedByteArray()
	for i in a.size():
		raw.append(int(a[i]) ^ int(b[i % b.size()]))
	raw.append_array(tag.to_utf8_buffer())
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(raw)
	return ctx.finish()


static func _enc_key(tag: String) -> PackedByteArray:
	return _derive(_M1, _M2, tag)


static func _sign(text: String, tag: String) -> String:
	var crypto := Crypto.new()
	return crypto.hmac_digest(HashingContext.HASH_SHA256, _derive(_S1, _S2, tag), text.to_utf8_buffer()).hex_encode()


## Dosya motorun şifreli biçiminde mi? (Düz metin dosyayı open_encrypted'a vermek motor ERROR satırı basar - önce başlığa bak.)
static func _is_sealed(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var head: PackedByteArray = f.get_buffer(4)
	f.close()
	return head == ENC_HEADER


static func _load_one(path: String, tag: String) -> Dictionary:
	var res: Dictionary = {"status": Status.MISSING, "cfg": ConfigFile.new()}
	if not FileAccess.file_exists(path):
		return res
	if _is_sealed(path):
		var f := FileAccess.open_encrypted(path, FileAccess.READ, _enc_key(tag))
		if f == null:
			res["status"] = Status.TAMPERED
			return res
		var magic: String = f.get_pascal_string()
		var text: String = f.get_pascal_string()
		var sig: String = f.get_pascal_string()
		f.close()
		var cfg := ConfigFile.new()
		if magic == MAGIC and sig == _sign(text, tag) and cfg.parse(text) == OK:
			res["status"] = Status.OK
			res["cfg"] = cfg
		else:
			res["status"] = Status.TAMPERED
		return res
	var plain := ConfigFile.new()
	if plain.load(path) != OK:
		res["status"] = Status.TAMPERED
	elif legacy_allowed():
		res["status"] = Status.LEGACY
		res["cfg"] = plain
	else:
		res["status"] = Status.TAMPERED
	return res


## Dosyayı oku. Dönen sözlük: {"status": Status, "cfg": ConfigFile, "restored": bool}. `real_file`: true ise (varsayılan oyuncu dosyası)
## geçersiz dosya `.bozuk`a taşınır ve `.bak`tan dönülmeye çalışılır; testler/geçici yollar için false (yan dosya bırakmaz).
static func load_cfg(path: String, tag: String, real_file: bool = false) -> Dictionary:
	var res: Dictionary = _load_one(path, tag)
	res["restored"] = false
	if int(res["status"]) != Status.TAMPERED:
		return res
	Guard.report("kayıt dosyası geçersiz: %s" % path.get_file(), false)
	if not real_file:
		return res
	var abs_path: String = ProjectSettings.globalize_path(path)
	DirAccess.remove_absolute(abs_path + BAD_SUFFIX)
	DirAccess.rename_absolute(abs_path, abs_path + BAD_SUFFIX) ## bozuk dosya kenara (bir sonraki okuma "yok" görür; kullanıcı elle bakabilir)
	var bak: Dictionary = _load_one(path + BACKUP_SUFFIX, tag)
	if int(bak["status"]) == Status.OK or int(bak["status"]) == Status.LEGACY:
		bak["restored"] = true
		return bak
	return res


## Mühürlü yaz (atomik). `real_file`: true ise önceki GEÇERLİ dosya `.bak`a kopyalanır. Hata kodu döner (OK = başarılı).
static func save_cfg(cfg: ConfigFile, path: String, tag: String, real_file: bool = false) -> Error:
	var text: String = cfg.encode_to_text()
	var tmp: String = path + ".tmp"
	var f := FileAccess.open_encrypted(tmp, FileAccess.WRITE, _enc_key(tag))
	if f == null:
		return FileAccess.get_open_error()
	f.store_pascal_string(MAGIC)
	f.store_pascal_string(text)
	f.store_pascal_string(_sign(text, tag))
	f.close()
	var abs_path: String = ProjectSettings.globalize_path(path)
	var abs_tmp: String = ProjectSettings.globalize_path(tmp)
	if FileAccess.file_exists(path):
		if real_file and int(_load_one(path, tag)["status"]) == Status.OK:
			DirAccess.copy_absolute(abs_path, abs_path + BACKUP_SUFFIX)
		DirAccess.remove_absolute(abs_path)
	var err: Error = DirAccess.rename_absolute(abs_tmp, abs_path)
	if err != OK:
		err = DirAccess.copy_absolute(abs_tmp, abs_path)
		DirAccess.remove_absolute(abs_tmp)
	return err
