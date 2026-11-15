extends RefCounted

## TEK SEFERLİK İLERLEME SIFIRLAMA (kullanıcı isteği 2026-11-12: "herkesin kayıtları ve ilerlemesi sıfırlansın").
## Kalıcı ilerleme her oyuncunun KENDİ makinesinde (meta.cfg = Ruh Kıymığı/kilitler/geliştirmeler/anahtarlar, records.cfg = rekorlar +
## başarımlar), bu yüzden sıfırlama kodla yapılır: yeni sürümü ilk açan her makinede dosyalar bir kez silinir.
##
## Nasıl çalışır: `user://progress_reset.cfg` her dosya için "hangi sıfırlama sürümü uygulandı" bilgisini tutar. `EPOCH` bundan büyükse
## dosya yedeğe (`<dosya>.sifirlama_oncesi`) taşınır ve işaret yazılır -> bir daha dokunulmaz. Yeni kurulumda dosya yoktur, yalnız işaret yazılır.
## TEKRAR sıfırlamak için `EPOCH`'u artır (başka bir şey gerekmez).
##
## Çağıranlar (MetaProgress.load_all/_save, RunRecords.load_all/_save) yalnız KENDİ yolları varsayılanken çağırır: testler / ortam değişkeniyle
## ayrılmış yollar (`path_override`, LILSLAYERS_*_PATH) hiç etkilenmez. İlk erişimde (menü açılışı, koşu başlamadan) çalışır.
## KAPSAM DIŞI (bilerek): ayarlar, tuş atamaları, oyuncu adı, son seçim, balans telemetrisi (user://balans).

const EPOCH := 1
const MARKER_PATH := "user://progress_reset.cfg"
const BACKUP_SUFFIX := ".sifirlama_oncesi"

static var _checked: Dictionary = {} ## anahtar -> true (bu süreçte denetlendi; diske tekrar bakılmaz)


## `key`: "meta" / "records"; `file_path`: o kaydın varsayılan yolu. Sıfırlama yapıldıysa true.
## `marker_path`: testler geçici işaret dosyası verir (gerçek işarete dokunmaz).
static func ensure(key: String, file_path: String, marker_path: String = MARKER_PATH) -> bool:
	if _checked.has(key):
		return false
	_checked[key] = true
	var marker := ConfigFile.new()
	marker.load(marker_path) ## yoksa boş kalır
	if int(marker.get_value("reset", key, 0)) >= EPOCH:
		return false
	var did: bool = false
	if FileAccess.file_exists(file_path):
		var abs_path: String = ProjectSettings.globalize_path(file_path)
		var backup: String = abs_path + BACKUP_SUFFIX
		if FileAccess.file_exists(file_path + BACKUP_SUFFIX):
			DirAccess.remove_absolute(backup) ## eski yedek (önceki bir sıfırlamadan)
		if DirAccess.rename_absolute(abs_path, backup) != OK:
			DirAccess.remove_absolute(abs_path) ## taşınamadıysa yine de sıfırla
		did = true
	marker.set_value("reset", key, EPOCH)
	marker.save(marker_path)
	return did
