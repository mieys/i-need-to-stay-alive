extends Node

## Kullanıcı bildirimi (2026-10-08): "dükkan açıkken joystick kullanan insanlar hala yetenek kullanabiliyor... bir tuş hem seçme tuşu hem
## skill tuşu olduğu için market açıkken o tuşa basmak o skili de tetikler". Dükkanlar oyunu duraklatmadığı için yetenek girişi
## (Input.is_action_just_pressed) süzülmüyordu. Artık kayıtlı engelleyici panel (GameManager.register_blocking_panel) açıkken yetenek tuşları
## oyuna gitmez (player.gd _skill_keys_blocked). GERÇEK Player + GERÇEK tuş basışı (Input.action_press) ile: Assasin Q = Şahin Hamlesi
## (yük düşer, gözlemlenmesi kolay).

const PlayerScene: PackedScene = preload("res://scenes/player.tscn")
const ASSASIN := 5
const WeaponShopScreenScript := preload("res://scripts/weapon_shop_screen.gd")

var _spawned: Array[Node] = []
var _prev_scene: Node = null
var _prev_char_id: int = 1
var _prev_character: int = 1
var _panel: Control = null


func _make_player() -> Node:
	_prev_scene = get_tree().current_scene
	get_tree().current_scene = self
	_prev_char_id = GameManager.selected_char_id
	_prev_character = GameManager.selected_character
	GameManager.selected_char_id = ASSASIN
	GameManager.selected_character = int(Characters.DEFS[ASSASIN]["skill"])
	NetworkManager.is_multiplayer_active = false
	var p: Node = PlayerScene.instantiate()
	add_child(p)
	_spawned.append(p)
	p.global_position = Vector2(1000.0, 1000.0)
	p.item_shield_max = 1000.0
	p.item_shield_hp = 1000.0
	return p


func _fake_panel() -> Control:
	_panel = Control.new()
	add_child(_panel)
	_spawned.append(_panel)
	GameManager.register_blocking_panel(_panel)
	return _panel


func _cleanup() -> void:
	Input.action_release("skill")
	Input.action_release("skill2")
	if _panel != null:
		GameManager.unregister_blocking_panel(_panel)
		_panel = null
	NetworkManager.is_multiplayer_active = false
	GameManager.selected_char_id = _prev_char_id
	GameManager.selected_character = _prev_character
	for n: Node in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()
	if _prev_scene != null and is_instance_valid(_prev_scene) and _prev_scene.get_parent() == get_tree().root:
		get_tree().current_scene = _prev_scene


## Gerçek tuş basışı: aksiyonu bas, iki fizik karesi bekle (oyuncunun _physics_process'i is_action_just_pressed görür), bırak.
func _press(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)
	await get_tree().physics_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_skill_key_works_without_any_panel() -> void:
	var p := _make_player()
	var charges_before: int = p.assasin_dash2_charges
	await _press("skill")
	assert(p.assasin_dash2_charges == charges_before - 1, "kontrol: panel yokken Q hamle atmalı (yük %d -> %d)" % [charges_before, p.assasin_dash2_charges])
	_cleanup()


func test_skill_key_is_ignored_while_a_shop_or_inventory_panel_is_open() -> void:
	var p := _make_player()
	var panel := _fake_panel()
	await _frames(3) ## panel açıkken kaç kare geçtiği önemsiz
	var charges_before: int = p.assasin_dash2_charges
	await _press("skill")
	assert(p.assasin_dash2_charges == charges_before, "dükkan/envanter açıkken Q hamle ATMAMALI (yük %d -> %d)" % [charges_before, p.assasin_dash2_charges])
	assert(p.skill_state == "ready", "yetenek durumu değişmemeli")
	## Panel kapanınca (kuyruk süresi sonra) yetenek yine çalışır.
	panel.visible = false
	await get_tree().create_timer(0.4).timeout
	await _press("skill")
	assert(p.assasin_dash2_charges == charges_before - 1, "panel kapandıktan sonra Q yine çalışmalı (yük %d -> %d)" % [charges_before, p.assasin_dash2_charges])
	_cleanup()


func test_the_press_that_closes_the_panel_does_not_fire_the_skill() -> void:
	## "Bir tuş hem seçme/kapat hem yetenek tuşu": panel o basışla kapanır, aynı karede yetenek de tetiklenmemeli.
	var p := _make_player()
	var panel := _fake_panel()
	await _frames(3)
	var charges_before: int = p.assasin_dash2_charges
	panel.visible = false ## ekran kendi _process'inde basışı işleyip kapandı
	Input.action_press("skill") ## aynı karedeki basış
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("skill")
	await get_tree().physics_frame
	assert(p.assasin_dash2_charges == charges_before, "kapatan basış yeteneği tetiklememeli (yük %d -> %d)" % [charges_before, p.assasin_dash2_charges])
	_cleanup()


func test_chat_typing_still_blocks_and_e_key_is_blocked_too() -> void:
	var p := _make_player()
	p.level = 10
	var panel := _fake_panel()
	await _frames(3)
	var before_state: String = p.skill2_state
	await _press("skill2")
	assert(p.skill2_state == before_state, "açık dükkanda E (skill2) de tetiklenmemeli: %s -> %s" % [before_state, p.skill2_state])
	panel.visible = false
	await get_tree().create_timer(0.4).timeout
	p.is_chat_typing = true
	var charges_before: int = p.assasin_dash2_charges
	await _press("skill")
	assert(p.assasin_dash2_charges == charges_before, "sohbet yazarken Q yine tetiklenmemeli")
	_cleanup()


## Asıl şikâyetin yolu: GERÇEK demirci ekranı açıkken (kayıtlı engelleyici panel) yetenek tuşu oyuna gitmemeli; ekran kapanınca gitmeli.
func test_real_smithy_screen_blocks_skill_keys_until_it_closes() -> void:
	var p := _make_player()
	var screen: CanvasLayer = WeaponShopScreenScript.new()
	add_child(screen)
	_spawned.append(screen)
	screen.setup(p)
	await _frames(3)
	var charges_before: int = p.assasin_dash2_charges
	await _press("skill")
	assert(p.assasin_dash2_charges == charges_before, "demirci ekranı açıkken Q hamle atmamalı (yük %d -> %d)" % [charges_before, p.assasin_dash2_charges])
	screen._on_close_pressed()
	await get_tree().create_timer(0.5).timeout
	await _press("skill")
	assert(p.assasin_dash2_charges == charges_before - 1, "ekran kapanınca Q çalışmalı (yük %d -> %d)" % [charges_before, p.assasin_dash2_charges])
	_cleanup()
