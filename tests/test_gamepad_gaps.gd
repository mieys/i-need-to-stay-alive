extends Node

## KUMANDA DENETİMİ düzeltmeleri (madde 547 -> 548, 2026-11-10): tuş adı ipuçları + HUD yetenek kapakları kumandada düğme adı gösterir,
## Takım paneli kumandayla (L3 hasar sıralaması, LT altın gönder, B kapat), sandık animasyonu kumandayla atlanır, envanter ilk odağı seçili yuva,
## kumanda çıkınca duraklatma. (Teslim oyu: test_surrender_vote.gd; tuş atama iptali: test_settings_screen.gd.)

const HudScene: PackedScene = preload("res://scenes/hud.tscn")
const PartyPanelScript := preload("res://scripts/party_panel.gd")
const ChestOpenAnimScript: GDScript = preload("res://scripts/chest_open_anim.gd")

## test düğümü "Main" adını alınca GamepadUi onu oyun sahnesi sayar (kumanda çıkınca duraklatma denemesi).
var pause_menu_instance: Node = null
var _toggles: int = 0


func _toggle_pause() -> void:
	_toggles += 1


func _gp() -> Node:
	return GameManager.get_node("GamepadUi")


func _pad(on: bool) -> void:
	_gp().set("joypad_active", on)


func _button(idx: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = idx
	e.pressed = true
	return e


func test_hint_labels_follow_input_mode() -> void:
	_pad(false)
	assert(GameManager.get_action_hint_label("interact") == GameManager.get_action_key_label("interact"), "klavyede klavye adı")
	var seen: Array = []
	_gp().connect("input_mode_changed", func(j: bool) -> void: seen.append(j))
	_pad(true)
	_pad(true) ## aynı değer sinyal yaymaz
	assert(seen == [true], "girdi türü değişince bir kez sinyal: %s" % str(seen))
	## Kullanıcının kayıtlı kumanda atamaları (Tuş Atamaları) olabilir: beklenen ad GERÇEK atamadan, kısa ad eşlemesi ayrıca sabit sınanır.
	for a: String in ["interact", "skill", "skill2", "skill3", "skill4"]:
		var want: String = GameManager.joypad_short_label(GameManager.get_keybind_joypad_descriptor(a))
		assert(want != "" and GameManager.get_action_hint_label(a) == want, "%s kumandada düğme adı: %s" % [a, GameManager.get_action_hint_label(a)])
		assert(GameManager.get_action_hint_label(a) != GameManager.get_action_key_label(a), "%s: kumanda adı klavye adından farklı" % a)
	assert(GameManager.get_action_hint_label("chat") == GameManager.get_action_key_label("chat"), "kumandası olmayan eylem klavye adına düşer")
	assert(GameManager.get_action_key_label("interact") != "LB", "menü etiketi (get_action_key_label) hep klavye")
	var JK = GameManager.JoypadKind
	assert(GameManager.joypad_short_label({"kind": JK.BUTTON, "button": JOY_BUTTON_LEFT_SHOULDER}) == "LB", "LB")
	assert(GameManager.joypad_short_label({"kind": JK.BUTTON, "button": JOY_BUTTON_Y}) == "Y", "Y")
	assert(GameManager.joypad_short_label({"kind": JK.BUTTON, "button": JOY_BUTTON_RIGHT_STICK}) == "R3", "R3")
	assert(GameManager.joypad_short_label({"kind": JK.BUTTON, "button": JOY_BUTTON_START}) == "START", "START")
	assert(GameManager.joypad_short_label({"kind": JK.AXIS, "axis": JOY_AXIS_TRIGGER_LEFT, "sign": 1.0}) == "LT", "tetik adı")
	assert(GameManager.joypad_short_label({"kind": JK.AXIS, "axis": JOY_AXIS_LEFT_X, "sign": -1.0}) == "L-SOL", "çubuk adı")
	_pad(false)
	assert(seen == [true, false], "klavyeye dönünce yine sinyal")


func test_party_actions_are_bound() -> void:
	var has_l3: bool = false
	for ev in InputMap.action_get_events("party_stats"):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_STICK:
			has_l3 = true
	assert(has_l3, "party_stats = L3")
	var has_lt: bool = false
	for ev in InputMap.action_get_events("party_gift"):
		if ev is InputEventJoypadMotion and (ev as InputEventJoypadMotion).axis == JOY_AXIS_TRIGGER_LEFT:
			has_lt = true
	assert(has_lt, "party_gift = LT")
	assert(InputMap.action_get_deadzone("party_gift") >= 0.5, "tetik yalnız yarıdan fazla çekilince")


func test_hud_skill_key_caps_follow_input_mode() -> void:
	_pad(false)
	var hud: Node = HudScene.instantiate()
	add_child(hud)
	await get_tree().process_frame
	var q: Label = hud.skill_icon.get_node("KeyLabel") as Label
	var r: Label = hud.skill3_icon.get_node("KeyLabel") as Label
	assert(q.text == GameManager.get_action_key_label("skill"), "klavyede Q: %s" % q.text)
	_pad(true)
	assert(q.text == GameManager.get_action_hint_label("skill") and q.text != GameManager.get_action_key_label("skill"), "kumandada Q kapağı kumanda düğmesi: %s" % q.text)
	assert(hud.skill2_icon.get_node("KeyLabel").text == GameManager.get_action_hint_label("skill2"), "E kapağı")
	assert(r.text == GameManager.get_action_hint_label("skill3") and hud.spirit_icon.get_node("KeyLabel").text == GameManager.get_action_hint_label("skill4"), "R ve F kapakları")
	_pad(false)
	assert(q.text == GameManager.get_action_key_label("skill"), "klavyeye dönünce kapak geri döner")
	hud.queue_free()
	await get_tree().process_frame


func _fake_ally(peer: int, pname: String) -> Node2D:
	var s := GDScript.new()
	s.source_code = "extends Node2D\nvar match_damage_dealt: float = 0.0\nvar match_damage_taken: float = 0.0\nvar player_name: String = \"\"\n" \
			+ "var peer_id: int = 0\nvar char_id: int = 10\nvar health: float = 300.0\nvar max_health: float = 500.0\n" \
			+ "var item_shield_hp: float = 50.0\nvar item_shield_max: float = 100.0\nvar is_downed: bool = false\nvar is_dead: bool = false\n"
	s.reload()
	var n := Node2D.new()
	n.set_script(s)
	n.set("player_name", pname)
	n.set("peer_id", peer)
	n.add_to_group("remote_players")
	n.add_to_group("remote_allies") ## destek yetenekleri müttefik grubunu tarar (madde 617)
	return n


## Eylemi bir karede "basılı" yapar; paneller `_process`'inde Input.is_action_just_pressed okur (4.7: aynı karede bırakılsa da doğru döner,
## o yüzden elle çağırıp bırakmak panelin kendi _process'iyle ÇİFT işlerdi) - basış karesinin sonunda panel işlemiş olur.
func _press_action(action: String) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func test_party_panel_pad_stats_and_gift() -> void:
	var saved_mp: bool = NetworkManager.is_multiplayer_active
	NetworkManager.is_multiplayer_active = true
	var me := _fake_ally(1, "Ben")
	me.remove_from_group("remote_players")
	me.add_to_group("player")
	add_child(me)
	var a1 := _fake_ally(1234, "Mira")
	add_child(a1)
	var a2 := _fake_ally(4321, "Deniz")
	add_child(a2)
	var panel: Control = PartyPanelScript.new()
	add_child(panel)
	_pad(true)
	var stats: Control = panel.get("_stats_popup")
	var gift: Control = panel.get("_gift_popup")
	## L3: hasar sıralaması aç / kapa
	await _press_action("party_stats")
	assert(stats.visible, "L3 hasar sıralamasını açar")
	await _press_action("party_stats")
	assert(not stats.visible, "L3 tekrar kapatır")
	## B hasar sıralamasını kapatır
	panel.call("_on_stats_button_pressed")
	assert(stats.visible)
	panel._input(_button(JOY_BUTTON_B))
	assert(not stats.visible and GameManager.was_ui_cancel_consumed(), "B hasar sıralamasını kapatır ve duraklatmayı açtırmaz")
	## LT: ilk arkadaş, tekrar LT sıradaki, sonra başa
	await _press_action("party_gift")
	assert(gift.visible and int(panel.get("_gift_target_peer")) == 1234, "LT altın penceresini ilk arkadaşa açar: %s" % str(panel.get("_gift_target_peer")))
	var btns: Array = gift.find_children("*", "Button", true, false)
	assert(not btns.is_empty() and (btns[0] as Button).focus_mode == Control.FOCUS_ALL, "kumandayla açılınca düğmeler odaklanır")
	assert(GameManager.is_any_blocking_panel_open(), "açıkken engelleyici panel (yetenek tuşları sızmaz)")
	await _press_action("party_gift")
	assert(int(panel.get("_gift_target_peer")) == 4321, "LT tekrar sıradaki arkadaş: %s" % str(panel.get("_gift_target_peer")))
	await _press_action("party_gift")
	assert(int(panel.get("_gift_target_peer")) == 1234, "sonra başa döner")
	## B kapatır, düğmeler eski odaksız hâline döner
	panel._input(_button(JOY_BUTTON_B))
	assert(not gift.visible and (btns[0] as Button).focus_mode == Control.FOCUS_NONE, "B kapatır, klavye odağı yine çalınmaz")
	assert(not GameManager.is_any_blocking_panel_open(), "kapanınca engelleyici değil")
	## başka pencere açıkken kısayol susar
	var other := Control.new()
	other.add_to_group(&"gamepad_modal")
	add_child(other)
	await _press_action("party_gift")
	assert(not gift.visible, "envanter/kart gibi başka pencere açıkken LT altın penceresi açmaz")
	other.free()
	_pad(false)
	panel.queue_free()
	me.queue_free()
	a1.queue_free()
	a2.queue_free()
	NetworkManager.is_multiplayer_active = saved_mp
	await get_tree().process_frame


func test_chest_open_anim_skips_on_pad_button_not_stick() -> void:
	var a: Control = ChestOpenAnimScript.new()
	a.setup(false, 2)
	add_child(a)
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 1.0
	a._input(motion)
	assert(not a.skipped, "çubuk hareketi animasyonu atlatmaz")
	a._input(_button(JOY_BUTTON_A))
	assert(a.skipped, "kumanda düğmesi animasyonu atlatır")
	a.queue_free()


func test_inventory_first_focus_is_the_selected_slot_not_close() -> void:
	var saved_items: Array = GameManager.owned_items.duplicate(true)
	var saved_weapons: Array = GameManager.owned_weapons.duplicate(true)
	GameManager.owned_items = [{"key": "kanli_yakut", "spent": 0}]
	GameManager.owned_weapons = [EnchantDefs.new_weapon_entry("dagger", 1, 0)]
	var hud: Node = HudScene.instantiate()
	add_child(hud)
	await get_tree().process_frame
	var inv: Control = hud.inventory_panel_instance as Control
	hud._on_envanter_toggle()
	await get_tree().process_frame
	_pad(true)
	await get_tree().create_timer(0.6, true).timeout
	var owner: Control = get_viewport().gui_get_focus_owner()
	assert(owner != null and inv.is_ancestor_of(owner), "kumandayla açılışta odak envanterin içinde")
	assert(owner.name != "CloseX", "ilk odak KAPAT düğmesi olmamalı (ilk A kapatıyordu): %s" % owner.name)
	assert(owner.is_in_group(&"gamepad_first_focus"), "seçili yuva ilk odak adayı")
	_pad(false)
	hud._on_envanter_toggle()
	GameManager.owned_items = saved_items
	GameManager.owned_weapons = saved_weapons
	hud.queue_free()
	await get_tree().process_frame


func test_pad_disconnect_opens_pause_only_in_game_for_pad_players() -> void:
	var old_name: String = name
	name = "Main"
	_toggles = 0
	pause_menu_instance = null
	## kumandayla oynarken kumanda çıkar -> duraklatma menüsü
	_pad(true)
	_gp().call("_on_joy_connection_changed", 0, false)
	assert(_toggles == 1, "kumanda çıkınca duraklatma açılır: %d" % _toggles)
	assert(not bool(_gp().get("joypad_active")), "kumanda yok: girdi türü klavyeye döner")
	## klavye/fareyle oynayan (son girdi kumanda değil) etkilenmez
	_gp().call("_on_joy_connection_changed", 0, false)
	assert(_toggles == 1, "kumandayla oynamayana dokunmaz")
	## zaten açık menü varsa tekrar açmaz
	_pad(true)
	pause_menu_instance = Node.new()
	_gp().call("_on_joy_connection_changed", 0, false)
	assert(_toggles == 1, "menü zaten açıksa dokunmaz")
	pause_menu_instance.free()
	pause_menu_instance = null
	## takılma (bağlanma) bir şey yapmaz
	_pad(true)
	_gp().call("_on_joy_connection_changed", 0, true)
	assert(_toggles == 1, "bağlanınca bir şey olmaz")
	_pad(false)
	name = old_name
