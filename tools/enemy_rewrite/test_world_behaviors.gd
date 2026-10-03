extends SceneTree

## Aşama 1 - EnemyWorld davranış testleri (harita YÜKLEMEDEN, yapay ızgarayla; ~1 sn). Test gövdeleri
## world_behavior_cases.gd'de (projenin test paketi de onları koşar: tests/test_enemy_world.gd).
##
##   powershell -File tools/enemy_rewrite/run_godot.ps1 -Script res://tools/enemy_rewrite/test_world_behaviors.gd
## Çıktı: her test için "PASS ad" / "FAIL ad: neden", sonda "TESTS n/m PASS" (hepsi geçmezse çıkış kodu 1).


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not ClassDB.class_exists("EnemyWorld"):
		print("TEST HATA: EnemyWorld sınıfı yok - önce --import")
		quit(1); return
	var cases: Object = load("res://tools/enemy_rewrite/world_behavior_cases.gd").new()
	var failed: int = int(cases.call("run_all"))
	var passed: int = int(cases.get("_pass"))
	print("TESTS %d/%d PASS" % [passed, passed + failed])
	quit(0 if failed == 0 else 1)