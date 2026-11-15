extends Node

## Tek oyunculu "Yeniden Başla" / teslim sonrası "Yeniden Başla" (2026-11-11, kullanıcı: "karakter seçim ekranına döndürmeli").
## Eskiden main.tscn'i doğrudan yeniden yüklüyor, aynı karakterle başlıyordu. Sahneler bu testte kurulmadığı için kural kaynak
## üzerinden sınanır (test_pause_over_end_screens.gd ile aynı desen).


func _body(path: String, signature: String) -> String:
	var src: String = FileAccess.get_file_as_string(path)
	var start: int = src.find(signature)
	assert(start != -1, "bulunamadı: %s" % signature)
	var end: int = src.find("\nfunc ", start + signature.length())
	return src.substr(start, (end if end != -1 else src.length()) - start)


func test_pause_menu_solo_restart_goes_to_character_select() -> void:
	var body: String = _body("res://scripts/pause_menu.gd", "func _on_restart()")
	assert(body.find("character_select.tscn") != -1, "tek oyunculu yeniden başlatma karakter seçimine dönmeli")
	assert(body.find("scenes/main.tscn") == -1, "main.tscn'e doğrudan dönmemeli")


func test_death_overlay_solo_restart_goes_to_character_select() -> void:
	var body: String = _body("res://scripts/main.gd", "func _on_death_overlay_restart_pressed()")
	assert(body.find("character_select.tscn") != -1, "ölüm/teslim ekranından tek oyunculu yeniden başlatma karakter seçimine dönmeli")
	assert(body.find("scenes/main.tscn") == -1, "main.tscn'e doğrudan dönmemeli")
