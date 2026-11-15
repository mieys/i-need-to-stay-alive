extends Node

## 2026-11-10 oyuncu bildirimi (ekran görüntülü): tek oyunculu lobide sol sütun kutuları üst üste biniyordu -> tek VBox ("SoloStack").
## Madde 606: HARİTA kutusu kalktı (harita OYUNU BAŞLAT'tan sonra dünya haritasında seçilir): SoloStack = oyuncu kartı + kayıt kutusu,
## OYUNU BAŞLAT dünya haritasını açar, GERİ kapatır.

const LobbyDesktopScript := preload("res://scripts/lobby_select_desktop.gd")


## Ekran açılırken karakter önizleme iş parçacığı tüm karakter kareleri dosyalarını yüklüyor (`_warm_previews`); test bitmeden süreç
## kapanırsa yarım yükleme "Parse Error" gürültüsü basıp testi sahte başarısız gösteriyordu -> yükleme bitene kadar beklenir.
func _wait_previews_warm() -> void:
	for i in 900:
		var all_cached := true
		for id in Characters.DEFS.keys():
			var p: String = str(Characters.get_def(int(id)).get("frames", ""))
			if p != "" and not ResourceLoader.has_cached(p):
				all_cached = false
		if all_cached:
			break
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame


func test_solo_stack_and_world_map_on_start() -> void:
	var old_map: String = GameManager.selected_map
	GameManager.selected_map = "col"
	var scene: Control = (load("res://scenes/character_select.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	await _wait_previews_warm()
	var desk: Control = scene.get("_desk")
	var stack: Control = desk.find_child("SoloStack", true, false)
	assert(stack != null and stack.get_child_count() == 2, "sol sütun SoloStack: oyuncu kartı + kayıt kutusu (HARİTA kutusu yok)")
	var players: Control = stack.get_child(0)
	var records: Control = stack.get_child(1)
	assert(players.get_global_rect().end.y <= records.get_global_rect().position.y + 0.5, "oyuncu kartı kayıt kutusuna binmiyor")
	assert(records.get_global_rect().end.y <= LobbyDesktopScript.LEFT.end.y + 0.5, "kayıt kutusu ekranın altını geçmiyor")
	## OYUNU BAŞLAT -> dünya haritası (son seçilen haritada açılır), GERİ kapatır, harita değişmez
	scene.call("_on_start_pressed")
	await get_tree().process_frame
	var wm: Control = scene.get("_world_map")
	assert(wm != null and wm.is_inside_tree(), "OYUNU BAŞLAT dünya haritasını açar")
	assert(wm.call("get_pick") == "col")
	wm.emit_signal("cancelled")
	await get_tree().process_frame
	assert(scene.get("_world_map") == null, "GERİ dünya haritasını kapatır")
	assert(GameManager.selected_map == "col")
	GameManager.selected_map = old_map
	scene.queue_free()
	await get_tree().process_frame
