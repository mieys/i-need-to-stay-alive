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
