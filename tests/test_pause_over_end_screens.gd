extends Node

## ESC duraklatma menüsü ölüm / oyun bitti ekranında (2026-11-09, kullanıcı: "karakter ölünce escye basılmıyor").
## Kök nedenler: (1) `is_game_over` iken main.gd ESC'yi hiç işlemiyordu; (2) ölü izleyicide menü açılıyordu ama katman 91 < ölüm ekranı 95
## olduğu için ekranın altında soluk/örtülü kalıyordu. Main sahnesi bu testte kurulmadığı için kural kaynak üzerinden sınanır
## (test_game_over_screen_order.gd ile aynı desen); gerçek tuş + görüntü denetimi: tools/buyuk_test/run.ps1 -Mode esc.


func _main_src() -> String:
	return FileAccess.get_file_as_string("res://scripts/main.gd")


func _func_body(src: String, signature: String) -> String:
	var start: int = src.find(signature)
	assert(start != -1, "main.gd'de bulunamadı: %s" % signature)
	var end: int = src.find("\nfunc ", start + signature.length())
	return src.substr(start, (end if end != -1 else src.length()) - start)


func _const_int(src: String, name: String) -> int:
	var at: int = src.find("const %s" % name)
	assert(at != -1, "main.gd'de sabit yok: %s" % name)
	var eq: int = src.find(":=", at)
	return int(src.substr(eq + 2, src.find("\n", eq) - eq - 2).strip_edges().split(" ")[0])


func test_pause_toggle_is_not_blocked_by_game_over() -> void:
	var body: String = _func_body(_main_src(), "func _process(delta: float)")
	var at: int = body.find("Input.is_action_just_pressed(\"pause_game\")")
	assert(at != -1, "_process pause_game'i işlemeli")
	var cond: String = body.substr(at, body.find("_toggle_pause()", at) - at)
	assert(cond.find("is_game_over") == -1, "oyun bitince ESC kapalı olmamalı (duraklatma menüsü ölüm ekranının üstünde açılır)")


func test_pause_menu_is_raised_over_death_and_victory_screens() -> void:
	var src: String = _main_src()
	var pause_layer: int = _const_int(src, "PAUSE_LAYER_OVER_END_SCREENS")
	assert(pause_layer > 96, "menü ölüm ekranı (95) ve zafer ekranı (96) üstünde olmalı: %d" % pause_layer)
	var toggle: String = _func_body(src, "func _toggle_pause()")
	assert(toggle.find("_raise_pause_menu_over_end_screens()") != -1, "_toggle_pause menüyü açınca katmanı yükseltmeli")
	var raise_body: String = _func_body(src, "func _raise_pause_menu_over_end_screens()")
	assert(raise_body.find("_death_overlay_layer") != -1 and raise_body.find("_victory_overlay") != -1, "ölüm VE zafer ekranına bakmalı")


func test_restart_confirm_dialog_stays_above_pause_menu() -> void:
	var src: String = _main_src()
	var pause_layer: int = _const_int(src, "PAUSE_LAYER_OVER_END_SCREENS")
	var body: String = _func_body(src, "func _on_restart_request_received()")
	var at: int = body.find("_restart_confirm_dialog.layer = ")
	assert(at != -1, "onay diyaloğunun katmanı bulunamadı")
	var layer: int = int(body.substr(at + "_restart_confirm_dialog.layer = ".length(), 4).strip_edges().split(" ")[0])
	assert(layer > pause_layer, "yeniden başlatma onayı duraklatma menüsünün üstünde kalmalı: %d <= %d" % [layer, pause_layer])
