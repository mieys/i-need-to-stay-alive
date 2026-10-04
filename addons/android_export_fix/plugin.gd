@tool
extends EditorPlugin

## Android export "Task :clean FAILED / Unable to delete directory android\build\build" hatası - kullanıcı bildirimi
## (2026-10-03): "her güncellemede şu hataya sebep olan şeyi çözer misin apk exportlarken".
##
## Kök neden (Gradle'ın clean'i elle çalıştırılıp yeniden üretildi): bu makinede projenin klasörlerine bilinmeyen bir dış
## etken Windows "Salt okunur" (ReadOnly) özniteliğini koyuyor (2026-10-03 itibarıyla 453 klasörün 452'si; dosyalar
## değil, sadece klasörler - normal kullanımda zararsız). Export bu klasörleri android/build/src/main/assets'e, Gradle da
## oradan build/ altına kopyalarken öznitelik taşınıyor. Bir SONRAKİ export'ta Gradle :clean, Windows'ta salt okunur
## klasörü silemiyor (java.nio.file.AccessDeniedException) -> export her seferinde düşüyordu; klasörü elle silmek
## (rm -rf özniteliği yok sayar) sadece bir export'luk çözümdü.
## Çözüm: Godot Android export'unda proje dosyalarını yazarken (_export_begin) Gradle'dan ÖNCE çalışır ve
## android/build/build altındaki tüm salt okunur öznitelikleri `attrib -R /S /D` ile kaldırır. Sadece Windows + Android.

var _export_plugin: EditorExportPlugin = null


func _enter_tree() -> void:
	_export_plugin = AndroidReadOnlyFix.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	if _export_plugin:
		remove_export_plugin(_export_plugin)
		_export_plugin = null


class AndroidReadOnlyFix extends EditorExportPlugin:
	func _get_name() -> String:
		return "AndroidReadOnlyFix"

	func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
		if OS.get_name() != "Windows" or not features.has("android"):
			return
		var build_dir: String = ProjectSettings.globalize_path("res://android/build/build").replace("/", "\\")
		if not DirAccess.dir_exists_absolute(build_dir):
			return
		var out: Array = []
		OS.execute("cmd.exe", ["/c", "attrib", "-R", build_dir], out, true) ## klasörün kendisi
		var code: int = OS.execute("cmd.exe", ["/c", "attrib", "-R", build_dir + "\\*", "/S", "/D"], out, true) ## içindekiler
		print("[Android Export Fix] salt okunur işaretleri temizlendi (attrib çıkış kodu %d): %s" % [code, build_dir])
