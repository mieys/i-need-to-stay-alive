extends Node

## Yaratık yeniden yazımı (docs/yaratik_yeniden_yazim/PLAN.md Aşama 5 "testleri yeni sisteme taşı"): C++ EnemyWorld
## çekirdeğinin davranış testleri (kovalama, duvar dolanma, menzilli dur/atış/görüş, korku, donma/kök, tahrik, Şovalye
## baloncuğu, müttefik önyargısı, ağaç önceliği, dolaşma, itme formülleri, satıcı bölgesi, temas aralığı, hayalet, saldırı
## kilidi, isabet sorguları, temas alanı). Gövdeler tools/enemy_rewrite/world_behavior_cases.gd'de; ayrıntılı çıktı için
## tools/enemy_rewrite/test_world_behaviors.gd. Gerçek oyun A/B testleri (harita + menü akışı) tools/enemy_rewrite/ altında.


func test_enemy_world_extension_loaded() -> void:
	assert(ClassDB.class_exists("EnemyWorld"), "EnemyWorld eklentisi yüklenmedi (gdextension/enemy_world, --import)")


func test_enemy_world_behaviors() -> void:
	if not ClassDB.class_exists("EnemyWorld"):
		return
	var cases: Object = load("res://tools/enemy_rewrite/world_behavior_cases.gd").new()
	var failed: int = int(cases.call("run_all"))
	assert(failed == 0, "EnemyWorld davranış testlerinden %d tanesi başarısız (bkz. PASS/FAIL satırları)" % failed)