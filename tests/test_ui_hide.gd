extends Node

## ARAYÜZÜ GİZLE (madde 612, kullanıcı: "oyunda arayüzü komple kapatmayı sağlayan bir düğme ekle F tuşlarına").
## Modül sahne ağacında UISound'un çocuğu ("UiHide"); burada onun gerçek örneği sınanır (gizle/aç, başkasının açtığı katmanı yeniden kapatma,
## dünya içi öğeler, oyun yokken kapalı, tuş bağı) + gerçek HUD katmanlarının kaydı ve gizliyken sohbet/envanterin açılmaması.

const UiHideScript := preload("res://scripts/ui_hide.gd")
const HudScene := preload("res://scenes/hud.tscn")

var _made: Array[Node] = []


func _ui() -> Node:
	var n: Node = UISound.get_node_or_null("UiHide")
	assert(n != null, "UISound altında UiHide düğümü olmalı")
	return n


func _layer(vis: bool = true) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.visible = vis
	UiHideScript.mark_layer(l)
	add_child(l)
	_made.append(l)
	return l


func _cleanup() -> void:
	if UiHideScript.hidden:
		_ui().call("set_hidden", false)
	for n: Node in _made:
		if is_instance_valid(n):
			n.free()
	_made.clear()
	UiHideScript.hidden = false


func test_screen_layers_hide_and_restore() -> void:
	_cleanup()
	var ui: Node = _ui()
	var a: CanvasLayer = _layer(true)
	var b: CanvasLayer = _layer(false) ## zaten gizli bir katman (örn. ev ipucu duraklamada): açılışta gizli KALMALI
	assert(ui.call("toggle"), "oyunda (kayıtlı katman var) tuş çalışmalı")
	assert(UiHideScript.hidden, "gizli olmalı")
	assert(not a.visible and not b.visible, "kayıtlı katmanlar kapanmalı")
	ui.call("toggle")
	assert(not UiHideScript.hidden, "ikinci basış açmalı")
	assert(a.visible, "açık olan katman geri açılmalı")
	assert(not b.visible, "baştan gizli olan katman gizli kalmalı")
	_cleanup()


func test_layer_reshown_by_others_is_hidden_again_and_remembered() -> void:
	_cleanup()
	var ui: Node = _ui()
	var banner: CanvasLayer = _layer(true)
	ui.call("toggle")
	banner.visible = true ## level pazarı kapanınca görev satırı katmanını açar
	ui._process(0.0)
	assert(not banner.visible, "başkası açsa da gizliyken yeniden kapanmalı")
	ui.call("toggle")
	assert(banner.visible, "açınca başkasının son durumuna (görünür) dönmeli")
	## pazar açılınca katmanı gizler, biz de gizleyip açarsak pazar kapanana kadar gizli kalır
	banner.visible = false
	ui.call("toggle")
	ui.call("toggle")
	assert(not banner.visible, "gizlenmiş katman (pazar açık) açılışta açılmamalı")
	_cleanup()


func test_layer_created_while_hidden_is_hidden_next_frame() -> void:
	_cleanup()
	var ui: Node = _ui()
	_layer(true)
	ui.call("toggle")
	var notice: CanvasLayer = _layer(true) ## gizliyken doğan bildirim katmanı
	assert(notice.visible, "doğduğu anda henüz açık")
	ui._process(0.0)
	assert(not notice.visible, "bir sonraki _process'te kapanmalı")
	ui.call("toggle")
	assert(notice.visible, "açınca bildirim (hâlâ yaşıyorsa) görünmeli")
	_cleanup()


func test_freed_layers_do_not_break_restore() -> void:
	_cleanup()
	var ui: Node = _ui()
	var keep: CanvasLayer = _layer(true)
	ui.call("toggle")
	for i in 60:
		var tmp: CanvasLayer = _layer(true)
		ui._process(0.0)
		_made.erase(tmp)
		tmp.free() ## bildirim süresi doldu
	ui._process(0.0)
	ui.call("toggle")
	assert(keep.visible, "kalıcı katman geri açılmalı")
	assert(ui.get("_prior").is_empty(), "açınca kayıt temizlenmeli")
	_cleanup()


func test_world_items_use_visibility_layer_not_visible() -> void:
	_cleanup()
	var ui: Node = _ui()
	_layer(true)
	var bar := Node2D.new()
	add_child(bar)
	_made.append(bar)
	UiHideScript.mark_world(bar)
	assert(bar.visibility_layer == UiHideScript.LAYER_SHOWN, "açıkken normal katman")
	ui.call("toggle")
	assert(bar.visibility_layer == UiHideScript.LAYER_HIDDEN, "gizlenince hiçbir görünümde çizilmemeli")
	assert(bar.visible, "sahibin `visible`ına dokunulmamalı (enemy.gd çubuğu kendi açıp kapatıyor)")
	bar.visible = false
	bar.visible = true
	assert(bar.visibility_layer == UiHideScript.LAYER_HIDDEN, "sahibin visible değişikliği gizlemeyi bozmamalı")
	var late := Node2D.new() ## gizliyken doğan yaratık çubuğu
	add_child(late)
	_made.append(late)
	UiHideScript.mark_world(late)
	assert(late.visibility_layer == UiHideScript.LAYER_HIDDEN, "gizliyken doğan öğe gizli başlamalı")
	ui.call("toggle")
	assert(bar.visibility_layer == UiHideScript.LAYER_SHOWN and late.visibility_layer == UiHideScript.LAYER_SHOWN, "açınca geri gelmeli")
	_cleanup()


func test_toggle_does_nothing_outside_a_game() -> void:
	_cleanup()
	var ui: Node = _ui()
	assert(get_tree().get_nodes_in_group(UiHideScript.GROUP_SCREEN).is_empty(), "test başında kayıtlı katman olmamalı")
	assert(not ui.call("toggle"), "oyun (HUD) yokken tuş etkisiz olmalı")
	assert(not UiHideScript.hidden, "gizli duruma geçmemeli")
	_cleanup()


func test_resets_when_game_ends_while_hidden() -> void:
	_cleanup()
	var ui: Node = _ui()
	var l: CanvasLayer = _layer(true)
	var bar := Node2D.new()
	add_child(bar)
	_made.append(bar)
	UiHideScript.mark_world(bar)
	ui.call("toggle")
	_made.erase(l)
	l.free() ## ana menüye dönüş: HUD gitti
	ui._process(0.0)
	assert(not UiHideScript.hidden, "oyun bitince gizli durum sıfırlanmalı (sonraki oyun açık arayüzle başlasın)")
	assert(bar.visibility_layer == UiHideScript.LAYER_SHOWN, "dünya öğeleri de açılmalı")
	_cleanup()


func test_key_binding_f3_rebindable_and_conflict_free() -> void:
	assert(InputMap.has_action("hide_ui"), "hide_ui eylemi tanımlı olmalı")
	var f3: bool = false
	for e: InputEvent in InputMap.action_get_events("hide_ui"):
		if e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_F3:
			f3 = true
	var override_set: bool = GameManager.get_keybind_keycode("hide_ui") != KEY_F3
	assert(f3 or override_set, "varsayılan tuş F3 olmalı")
	var listed: bool = false
	for entry: Dictionary in GameManager.REBINDABLE_ACTIONS:
		if entry["action"] == "hide_ui":
			listed = true
	assert(listed, "Ayarlar > TUŞLAR'dan değiştirilebilmeli")
	## F1/F2 teslim oylaması, F9 hata ayıklama paneli: hiçbir başka eylem F3'ü kullanmamalı
	for a: StringName in InputMap.get_actions():
		if a == &"hide_ui":
			continue
		for e: InputEvent in InputMap.action_get_events(a):
			assert(not (e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_F3 and not override_set), "F3 başka eyleme bağlı: %s" % a)


func test_f3_key_event_toggles_but_not_while_typing() -> void:
	_cleanup()
	var ui: Node = _ui()
	_layer(true)
	var ev := InputEventAction.new()
	ev.action = &"hide_ui"
	ev.pressed = true
	ui.call("_input", ev)
	assert(UiHideScript.hidden, "tuş basışı arayüzü gizlemeli")
	ui.call("_input", ev)
	assert(not UiHideScript.hidden, "ikinci basış açmalı")
	var box := LineEdit.new() ## sohbet kutusu odaktayken görünmez bırakmamalı
	add_child(box)
	_made.append(box)
	box.grab_focus()
	ui.call("_input", ev)
	assert(not UiHideScript.hidden, "metin kutusuna yazarken tuş etkisiz olmalı")
	_cleanup()


func test_real_hud_registers_layers_and_blocks_invisible_chat_and_inventory() -> void:
	_cleanup()
	var ui: Node = _ui()
	var hud: CanvasLayer = HudScene.instantiate() as CanvasLayer
	add_child(hud)
	_made.append(hud)
	assert(hud.is_in_group(UiHideScript.GROUP_SCREEN), "HUD katmanı kayıtlı olmalı")
	var chat_layer: Node = hud.get("_chat_layer") as Node
	assert(chat_layer != null and chat_layer.is_in_group(UiHideScript.GROUP_SCREEN), "sohbet katmanı kayıtlı olmalı")
	var party: Node = hud.get_node_or_null("PartyPanelLayer")
	assert(party != null and party.is_in_group(UiHideScript.GROUP_SCREEN), "grup paneli katmanı kayıtlı olmalı")
	ui.call("toggle")
	assert(not hud.visible and not chat_layer.visible, "HUD + sohbet gizlenmeli")
	assert(not (party as CanvasLayer).visible, "grup paneli gizlenmeli")
	var chat_ev := InputEventAction.new()
	chat_ev.action = &"chat"
	chat_ev.pressed = true
	hud._unhandled_input(chat_ev)
	var chat_input: LineEdit = hud.get("_chat_input") as LineEdit
	assert(chat_input == null or not chat_input.visible, "gizliyken Enter görünmez sohbet kutusunu açmamalı")
	var inv_ev := InputEventAction.new()
	inv_ev.action = &"inventory"
	inv_ev.pressed = true
	hud._unhandled_input(inv_ev)
	var inv: Control = hud.get("inventory_panel_instance") as Control
	assert(inv == null or not inv.visible, "gizliyken I görünmez envanteri açmamalı")
	ui.call("toggle")
	assert(hud.visible and chat_layer.visible and (party as CanvasLayer).visible, "açınca hepsi geri gelmeli")
	_cleanup()


## Kullanıcı (2026-11-12): "kart seçme, pazar v.s. arayüzlerini hariç tut, bunlar zorunlu - yoksa oyun devam etmez".
## Etkileşimi gereken / oyunu bekleten ekranlar HİÇBİR ZAMAN gizleme grubuna girmez (açıkken F3 onlara dokunmaz).
func test_mandatory_screens_are_never_registered() -> void:
	for path: String in ["res://scripts/level_up_screen.gd", "res://scripts/level_market_screen.gd", "res://scripts/level_market_view.gd",
			"res://scripts/chest_menu.gd", "res://scripts/enchant_screen.gd", "res://scripts/merchant_shop_screen.gd",
			"res://scripts/weapon_shop_screen.gd", "res://scripts/soul_shop_screen.gd", "res://scripts/pause_menu.gd",
			"res://scripts/wait_overlay.gd", "res://scripts/victory_overlay.gd", "res://scripts/surrender_vote_panel.gd",
			"res://scripts/loading_overlay.gd", "res://scripts/loading_screen.gd", "res://scripts/gamepad_ui.gd",
			"res://scripts/game_over_board.gd", "res://scripts/menu_weapon_picker.gd"]:
		var src: String = FileAccess.get_file_as_string(path)
		assert(src != "", "%s okunamadı" % path)
		assert(not src.contains("mark_layer") and not src.contains("ui_hide.gd"), "%s zorunlu ekran: gizleme grubuna girmemeli" % path)
	## main.gd'de yalnız dört kalıcı katman + bildirim kaydı olmalı (kart/sandık/pazar/ölüm/oylama katmanları yok)
	for path: String in ["res://scripts/overhead_bar.gd", "res://scripts/damage_numbers.gd", "res://scripts/elite_bar.gd", "res://scripts/babaanne_hp_bar.gd"]:
		assert(not FileAccess.get_file_as_string(path).contains("UiHideScript.mark_world"), "%s arayüz gizliyken de görünür kalmalı" % path)
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_src.count("UiHideScript.mark_layer(") == 4, "main.gd: yalnız satıcı oku, görev satırları, boss barı ve bildirimler kayıtlı olmalı")


func test_modal_layer_stays_visible_while_hidden() -> void:
	_cleanup()
	var ui: Node = _ui()
	_layer(true) ## HUD yerine geçen kayıtlı katman (oyunda sayılmak için)
	var modal := CanvasLayer.new() ## kart seçme / pazar / sandık ekranı: kayıtsız
	add_child(modal)
	_made.append(modal)
	ui.call("toggle")
	ui._process(0.0)
	assert(modal.visible, "zorunlu ekran gizliyken de görünür kalmalı")
	ui.call("toggle")
	assert(modal.visible, "açınca da değişmemeli")
	_cleanup()


func test_world_ui_scripts_register_themselves() -> void:
	for path: String in ["res://scripts/chat_bubble.gd",
			"res://scripts/remote_player_name.gd", "res://scripts/downed_timer_label.gd"]:
		var src: String = FileAccess.get_file_as_string(path)
		assert(src.contains("UiHideScript.mark_world(self)"), "%s dünya içi arayüz olarak kayıtlı olmalı" % path)
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	for needle: String in ["UiHideScript.mark_layer(merchant_arrow_layer)", "UiHideScript.mark_layer(world_event_banner_layer)",
			"UiHideScript.mark_layer(boss_bar_layer)", "UiHideScript.mark_layer(layer) ## F3: bildirim"]:
		assert(main_src.contains(needle), "main.gd kalıcı arayüz katmanını kaydetmeli: %s" % needle)
