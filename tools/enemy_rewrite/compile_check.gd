extends SceneTree

## Derleme kontrolü (yaratık yeniden yazımı, bkz. docs/yaratik_yeniden_yazim/PLAN.md §6).
## Autoload'lar hazırken scripts/ altındaki TÜM .gd dosyalarını yükler; derlenemeyenleri yazar.
##   Godot --headless --path <proje> -s res://tools/enemy_rewrite/compile_check.gd
## Çıktı sonu: "COMPILE OK (<n> dosya)" ya da "COMPILE FAIL <yol>" satırları + "COMPILE FAIL (<k>/<n>)".


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var files: Array[String] = []
	_collect("res://scripts", files)
	var bad: int = 0
	for path in files:
		var sc: GDScript = load(path) as GDScript
		if sc == null or not sc.can_instantiate():
			print("COMPILE FAIL ", path)
			bad += 1
	if bad == 0:
		print("COMPILE OK (%d dosya)" % files.size())
	else:
		print("COMPILE FAIL (%d/%d)" % [bad, files.size()])
	quit(1 if bad > 0 else 0)


func _collect(dir: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_collect(dir.path_join(sub), out)
