extends SceneTree

## Projenin tests/test_*.gd dosyaları için çalıştırıcı (repo'da başka çalıştırıcı yok; testler extends Node + test_* metotları,
## assert ile). TEST_FILE ortam değişkenindeki TEK dosyayı yükler, köke ekler, her test_* metodunu sırayla çağırır (coroutine
## ise bekler). Her testten önce stderr'e "RUN <dosya>::<test>" yazar - "Assertion failed" / "SCRIPT ERROR" satırları stderr'de
## sıralı geldiği için hangi teste ait oldukları bulunur. Sonda "TESTFILE_DONE <dosya> <n>" (n = koşan test sayısı).
## Toplu koşu: tools/enemy_rewrite/run_tests.ps1

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var path: String = OS.get_environment("TEST_FILE")
	var script: GDScript = load(path) as GDScript
	if script == null:
		printerr("TESTFILE_LOAD_FAIL ", path)
		quit(1); return
	var methods: Array[String] = []
	for m: Dictionary in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not methods.has(n):
			methods.append(n)
	var inst: Node = script.new()
	root.add_child(inst)
	## Oyunda current_scene hep var (yüzen yazılar, efektler, EnemyWorld köprüsü oraya eklenir); test düğümü sahne olur.
	current_scene = inst
	await process_frame
	var ran: int = 0
	for m in methods:
		printerr("RUN %s::%s" % [path.get_file(), m])
		if not is_instance_valid(inst):
			inst = script.new()
			root.add_child(inst)
			current_scene = inst
			await process_frame
		await inst.call(m)
		ran += 1
		paused = false
	printerr("TESTFILE_DONE %s %d" % [path.get_file(), ran])
	print("TESTFILE_DONE %s %d" % [path.get_file(), ran])
	quit()
