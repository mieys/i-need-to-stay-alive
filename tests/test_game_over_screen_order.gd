extends Node

## Oyun sonu ekranı sırası (2026-10-19, kullanıcı: "bazen bir oyuncu ölünce onda oyun sonucu ekranı açılmıyor").
## Kök neden: SON ölen HOST ise main.gd _on_player_died önce NetworkManager.report_self_permanently_dead() çağırıyordu; o oyunu SENKRON
## bitirir (game_over_synced -> _show_death_overlay(true) = "OYUN BİTTİ"), hemen ardından _show_death_overlay(false) çizilip ekranı
## "SEN ÖLDÜN / izleyicisin"e çeviriyor ve istatistik kutusunu gizliyordu. Main sahnesi bu testte kurulmadığı için kural kaynak
## üzerinden sınanır (test_party_stats_taken.gd ile aynı desen).


func _main_src() -> String:
	return FileAccess.get_file_as_string("res://scripts/main.gd")


func _func_body(src: String, signature: String) -> String:
	var start: int = src.find(signature)
	assert(start != -1, "main.gd'de bulunamadı: %s" % signature)
	var end: int = src.find("\nfunc ", start + signature.length())
	return src.substr(start, (end if end != -1 else src.length()) - start)


func test_spectator_overlay_is_drawn_before_reporting_death_to_host() -> void:
	var body: String = _func_body(_main_src(), "func _on_player_died()")
	var overlay_at: int = body.find("_show_death_overlay(false)")
	var report_at: int = body.find("NetworkManager.report_self_permanently_dead()")
	assert(overlay_at != -1 and report_at != -1, "çok oyunculu ölüm dalı iki çağrıyı da içermeli")
	assert(overlay_at < report_at, "izleyici ekranı host bildiriminden ÖNCE çizilmeli (host son ölürse OYUN BİTTİ ezilmesin)")


func test_spectator_call_after_game_over_is_promoted_to_final() -> void:
	var body: String = _func_body(_main_src(), "func _show_death_overlay(")
	var guard_at: int = body.find("if GameManager.is_game_over:")
	var promote_at: int = body.find("is_final = true", guard_at)
	var first_use_at: int = body.find("if is_final and not _game_over_sfx_played")
	assert(guard_at != -1 and promote_at != -1, "oyun bittiyse is_final true'ya çevrilmeli")
	assert(promote_at < first_use_at, "dönüşüm is_final'ın ilk kullanımından önce olmalı")


## Hata defteri önerisi (2026-11-12): izleyici "Pencereyi Gizle" ile pencere + karartmayı kaldırır, alttaki küçük şeritte ad + oklar kalır,
## "Pencereyi Aç" geri getirir; oyun bitince pencere zorla geri gelir. Main ağaca eklenmez (yalnız kaplama düğümleri kurulur).
func test_spectator_can_hide_and_restore_death_window() -> void:
	var main: Node = load("res://scripts/main.gd").new()
	var layer := CanvasLayer.new()
	add_child(layer)
	main.set("_death_overlay_layer", layer)
	var dim := ColorRect.new()
	dim.name = "Dim"
	layer.add_child(dim)
	var win := PanelContainer.new()
	win.name = "Window"
	layer.add_child(win)
	var vb := VBoxContainer.new()
	vb.name = "VBox"
	win.add_child(vb)
	var row := HBoxContainer.new()
	row.name = "SpectateRow"
	vb.add_child(row)
	var lbl := Label.new()
	lbl.name = "SpectateLabel"
	lbl.text = "İzleniyor: Ayşe"
	row.add_child(lbl)
	main.call("_build_death_compact_bar")
	var bar: Control = layer.get_node("CompactBar")
	assert(not bar.visible and not bool(main.call("is_death_window_compact")))
	var was_over: bool = GameManager.is_game_over
	GameManager.is_game_over = false
	main.call("_set_death_window_compact", true)
	assert(bar.visible and not win.visible and not dim.visible, "gizle: şerit görünür, pencere + karartma gizli")
	assert((layer.get_node("CompactBar/Row/Mid/NameLabel") as Label).text.ends_with("Ayşe"), "şeritte izlenen ad")
	assert(layer.get_node_or_null("CompactBar/Row/PrevButton") != null and layer.get_node_or_null("CompactBar/Row/NextButton") != null)
	(layer.get_node("CompactBar/Row/ShowWindowButton") as Button).pressed.emit()
	assert(not bar.visible and win.visible and dim.visible, "Pencereyi Aç geri getirir")
	GameManager.is_game_over = true
	main.call("_set_death_window_compact", true)
	assert(not bar.visible and win.visible, "oyun bittiyse pencere gizlenemez")
	GameManager.is_game_over = was_over
	layer.queue_free()
	main.free()
	await get_tree().process_frame
