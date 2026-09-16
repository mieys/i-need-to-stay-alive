extends Node

## REGRESYON KORUMASI - "export'ta oyun hiç başlamıyor" hatasının kök nedeni.
##
## KÖK NEDEN (özet): silinmiş bir ses dosyası (`assets/audio/yay_draw.mp3`)
## `scenes/weapon_yay.tscn` içinde `ext_resource` olarak duruyordu. Bir .tscn'de
## var olmayan bir kaynağa referans kalırsa o SAHNE yüklenemez; sahneyi
## `preload()` eden script (weapon.gd) DERLENEMEZ, ona bağlı script'ler
## (network_manager.gd) de derlenemez -> NetworkManager AUTOLOAD'u hiç
## yüklenmez. Editörde eski derlenmiş script önbelleği bunu maskelediği için
## oyun editörde çalışıyordu ama EXPORT edilmiş build'de her şey sıfırdan
## derlendiği için oyun açılıyor ve hiçbir şey çalışmıyordu.
##
## Bu test, projedeki TÜM `preload("res://...")` çağrılarının ve .tscn
## dosyalarındaki TÜM `[ext_resource ... path="res://..."]` referanslarının
## gerçekten var olduğunu doğrular. `load()` çağrıları BİLEREK taranmaz: onlar
## çalışma zamanında/koşullu olarak yapılır (ör. shop_item_icon.gd'de olmayan
## ikon dosyası) ve eksikliği derlemeyi kırmaz.

const SKIP_DIRS := [".godot", "addons", "tools"]


func _collect_files(dir_path: String, extension: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if sub in SKIP_DIRS:
			continue
		_collect_files(dir_path.path_join(sub), extension, out)
	for f in dir.get_files():
		if f.ends_with(extension):
			out.append(dir_path.path_join(f))


func _iter_matches(source: String, pattern: String) -> Array[String]:
	var out: Array[String] = []
	var re: RegEx = RegEx.create_from_string(pattern)
	var found: RegExMatch = re.search(source)
	while found != null:
		var value: String = found.get_string(1)
		## NOT: bu test dosyasının KENDİSİ de "preload(" ve "path=" ile birlikte
		## "res://..." metinleri içeriyor (yukarıdaki regex kalıpları) - bu
		## yüzden kalıbın kendisi kendini eşleştirip yanlış pozitif üretiyor.
		## Gerçek bir yol asla "..." içermez, o yüzden onlar atlanır.
		if not value.contains("..."):
			out.append(value)
		found = re.search(source, found.get_end())
	return out


func test_no_missing_preload_or_scene_dependencies() -> void:
	var missing: Array[String] = []

	## 1) .gd dosyalarındaki preload("res://...") çağrıları (bunlar DERLEME
	##    zamanında çözülür - eksik hedef script'i derlenemez hale getirir).
	var scripts: Array[String] = []
	_collect_files("res://", ".gd", scripts)
	for script_path in scripts:
		var source: String = FileAccess.get_file_as_string(script_path)
		if source.is_empty():
			continue
		for target in _iter_matches(source, "preload\\(\"(res://[^\"]+)\"\\)"):
			if not FileAccess.file_exists(target) and not ResourceLoader.exists(target):
				missing.append("%s -> preload(\"%s\")" % [script_path, target])

	## 2) .tscn dosyalarındaki ext_resource referansları (sahne yüklenemez
	##    hale gelir; onu preload eden script'i de çökertir).
	var scenes: Array[String] = []
	_collect_files("res://", ".tscn", scenes)
	for scene_path in scenes:
		var source: String = FileAccess.get_file_as_string(scene_path)
		if source.is_empty():
			continue
		for target in _iter_matches(source, "ext_resource[^\\]]*path=\"(res://[^\"]+)\""):
			if not FileAccess.file_exists(target) and not ResourceLoader.exists(target):
				missing.append("%s -> ext_resource(\"%s\")" % [scene_path, target])

	assert(missing.is_empty(),
		"Eksik kaynak referansları var (export'ta oyunu/tüm zinciri çökertir!):\n" + "\n".join(missing))


## Kök nedeni doğrudan doğrulayan test: yay silahı sahnesi artık var olan bir
## sesi kullanmalı (yoksa yukarıdaki genel test zaten patlar, bu test ise
## "hangi dosya bozuktu" bilgisini kalıcılaştırır).
func test_bow_draw_sound_exists() -> void:
	var source: String = FileAccess.get_file_as_string("res://scenes/weapon_yay.tscn")
	assert(not source.is_empty(), "weapon_yay.tscn okunamadı")
	assert(source.find("yay_draw.mp3") == -1,
		"weapon_yay.tscn hâlâ SİLİNMİŞ yay_draw.mp3 dosyasına referans veriyor - export'ta oyun açılmaz!")
	var targets: Array[String] = _iter_matches(source, "ext_resource[^\\]]*path=\"(res://[^\"]+)\"")
	assert(not targets.is_empty(), "weapon_yay.tscn'de hiç ext_resource yok - beklenmedik")
	for target in targets:
		assert(FileAccess.file_exists(target), "weapon_yay.tscn eksik dosyaya referans veriyor: %s" % target)
