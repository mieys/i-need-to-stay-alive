extends Node

## Tüm scripts/**/*.gd dosyaları derlenmeli (2026-10-12: alt sınıfın ezdiği `_take_dot_damage` imzası değişince yalnız o sınıfı yükleyen
## testler kırıldı - kimse bütün betikleri birlikte yüklemiyordu). Bir dosya derlenmezse bu test hangisi olduğunu söyler.


func _collect(dir_path: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir_path):
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(d), out)


func test_every_script_compiles() -> void:
	var paths: Array = []
	_collect("res://scripts", paths)
	assert(paths.size() > 100, "betik listesi okunamadı: %d" % paths.size())
	var bad: Array = []
	for p in paths:
		var scr: Resource = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REUSE)
		if scr == null or (scr is GDScript and not (scr as GDScript).can_instantiate() and not (scr as GDScript).is_abstract()):
			bad.append(p)
	assert(bad.is_empty(), "derlenmeyen betikler: %s" % str(bad))
