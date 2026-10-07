extends Node

## Telefon HUD'unda sohbet + grup paneli dokunma davranışı (kullanıcı bildirimi 2026-10-05: "android'de chat ve grup
## penceresinin aşağı kaydırması bazen oyunu bozuyor, takılı kalıp oynamama engel oluyor, çok sağa kayık görünüyor").
## Kök nedenler (hepsi burada sınanır):
##  1) Sohbet günlüğü joystick bölgesinde duruyordu ve joystick engel listesinde DEĞİLDİ: sohbeti parmakla kaydırmak joystick'i de
##     başlatıp karakteri yürütüyordu (grup paneli listesi zaten engel listesindeydi).
##  2) Sohbet günlüğünün varsayılan kaydırma çubuğu (36 px, temasız) panelin en sağında yalnız başına duruyordu.
##  3) Sohbet yazma kutusu açıkken dışına dokunmak / sohbet düğmesine tekrar dokunmak kutuyu kapatmıyordu; ekran klavyesi geri
##     hareketiyle kapanınca `is_chat_typing` oyuncuyu (hareket + yetenek) KİLİTLİ bırakıyordu.
##  4) touch_scroll.gd, joystick/düğme tutan parmağı da liste kaydırma için sahipleniyordu.

const MobileUIPath := "res://scripts/mobile_ui.gd"
const W := 2400
const H := 1080


class FakeAlly extends Node:
	var peer_id: int = 0
	var player_name: String = ""
	var char_id: int = 2
	var health: float = 80.0
	var max_health: float = 100.0
	var item_shield_max: float = 0.0
	var item_shield_hp: float = 0.0
	var is_dead: bool = false
	var is_downed: bool = false
	var match_damage_dealt: float = 0.0


class FakePlayer extends Node2D:
	var is_chat_typing: bool = false


var _hud: Node = null
var _extra: Array[Node] = []


func _setup(allies: int, msgs: int) -> void:
	Input.use_accumulated_input = false
	(load(MobileUIPath) as GDScript).set(&"enabled", true)
	DisplayServer.window_set_size(Vector2i(W, H))
	get_tree().root.size = Vector2i(W, H)
	## Gerçek telefondaki gibi (bkz. mobile_ui.gd apply): tuval ekranı doldurur, pencere = tuval koordinatları (1:1), yoksa
	## enjekte edilen dokunuşlar HUD kutularının yanına düşer.
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	await get_tree().process_frame
	_hud = (load("res://scenes/hud.tscn") as PackedScene).instantiate()
	add_child(_hud)
	for i in allies:
		var a := FakeAlly.new()
		a.peer_id = 100 + i
		a.player_name = "Oyuncu%d" % i
		a.char_id = 2 + i
		add_child(a)
		a.add_to_group("remote_players")
		_extra.append(a)
	await _frames(70)
	_hud._layout_mobile_hud()
	await _frames(70)
	for i in msgs:
		_hud.append_chat_message("Ali", "Mesaj numara %d selam nasilsin bugun" % i)
		await _frames(2)
	await _frames(10)


func _teardown() -> void:
	for n in _extra:
		if is_instance_valid(n):
			n.queue_free()
	_extra.clear()
	if is_instance_valid(_hud):
		_hud.queue_free()
	(load(MobileUIPath) as GDScript).set(&"enabled", false)
	await _frames(2)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(idx: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)


func _tap(pos: Vector2) -> void:
	_touch(0, pos, true)
	await _frames(2)
	_touch(0, pos, false)
	await _frames(3)


func _rect(c: Control) -> Rect2:
	return c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)


## Parmağı `from` noktasından `steps` adım aşağı (dy > 0) / yukarı sürükler, bırakmadan döner (çağıran bırakır).
func _drag_down(from: Vector2, steps: int, dy: float) -> void:
	_touch(0, from, true)
	await _frames(2)
	for i in steps:
		_drag(0, from + Vector2(0, dy * (i + 1)), Vector2(0, dy))
		await _frames(1)


func test_chat_log_has_no_stray_scrollbar_and_blocks_joystick_when_scrollable() -> void:
	await _setup(3, 12)
	var cs: ScrollContainer = _hud._chat_scroll
	assert(cs.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER, "telefonda sohbetin kaydırma çubuğu görünmemeli")
	assert(not cs.get_v_scroll_bar().visible, "sohbet kaydırma çubuğu çizilmemeli")
	assert(cs.get_v_scroll_bar().max_value - cs.get_v_scroll_bar().page > 1.0, "12 mesaj sohbette taşma yapmalı")
	assert(_hud._mobile_joy_exclude().has(cs), "taşan sohbet joystick engel listesinde olmalı")
	await _teardown()


func test_short_chat_does_not_block_joystick() -> void:
	await _setup(3, 1)
	assert(not _hud._mobile_joy_exclude().has(_hud._chat_scroll), "kaydırılmayan (sığan) sohbet joystick'i engellememeli")
	await _teardown()


func test_dragging_chat_scrolls_it_without_moving_the_character() -> void:
	await _setup(3, 12)
	var cs: ScrollContainer = _hud._chat_scroll
	var tc: Control = _hud.touch_controls
	var r: Rect2 = _rect(cs)
	var start: Vector2 = r.position + r.size * Vector2(0.4, 0.5)
	var before: int = cs.scroll_vertical
	await _drag_down(start, 8, 14.0)
	assert(tc._joy_id == -1, "sohbet üstünde joystick başlamamalı")
	assert(Input.get_action_strength("move_down") == 0.0, "sohbeti kaydırırken karakter yürümemeli")
	assert(cs.scroll_vertical != before, "sohbet parmakla kaymalı (önce %d, sonra %d)" % [before, cs.scroll_vertical])
	_touch(0, start + Vector2(0, 112), false)
	await _frames(3)
	assert(tc._joy_id == -1 and Input.get_action_strength("move_down") == 0.0, "bırakınca takılı joystick kalmamalı")
	await _teardown()


func test_party_list_scrolls_without_moving_the_character() -> void:
	await _setup(8, 1)
	var party: Control = _hud.get_node("PartyPanelLayer/PartyPanel")
	var ls: ScrollContainer = party._list_scroll
	var tc: Control = _hud.touch_controls
	var r: Rect2 = _rect(ls)
	var start: Vector2 = r.position + r.size * Vector2(0.5, 0.8)
	var before: int = ls.scroll_vertical
	_touch(0, start, true)
	await _frames(2)
	for i in 8:
		_drag(0, start + Vector2(0, -14.0 * (i + 1)), Vector2(0, -14.0))
		await _frames(1)
	assert(tc._joy_id == -1, "grup listesi üstünde joystick başlamamalı")
	assert(Input.get_action_strength("move_up") == 0.0, "grup listesini kaydırırken karakter yürümemeli")
	assert(ls.scroll_vertical > before, "kalabalık grup listesi parmakla kaymalı")
	_touch(0, start + Vector2(0, -112), false)
	await _frames(3)
	await _teardown()


func test_scroll_does_not_steal_a_finger_the_joystick_owns() -> void:
	await _setup(3, 12)
	var cs: ScrollContainer = _hud._chat_scroll
	var tc: Control = _hud.touch_controls
	tc.joy_exclude = Callable() ## engeli kaldır: joystick sohbetin üstünde başlasın (touch_scroll.gd korumasını tek başına sına)
	var r: Rect2 = _rect(cs)
	var start: Vector2 = r.position + r.size * Vector2(0.4, 0.5)
	var before: int = cs.scroll_vertical
	await _drag_down(start, 8, 14.0)
	assert(tc._joy_id == 0, "bu senaryoda joystick parmağı sahiplenmeli")
	assert(cs.scroll_vertical == before, "joystick'in tuttuğu parmak sohbeti kaydırmamalı")
	_touch(0, start + Vector2(0, 112), false)
	await _frames(3)
	assert(tc._joy_id == -1, "bırakınca joystick serbest kalmalı")
	await _teardown()


func test_chat_input_cannot_lock_the_player() -> void:
	await _setup(3, 1)
	var fake_player := FakePlayer.new()
	add_child(fake_player)
	_extra.append(fake_player)
	_hud.player = fake_player
	var ci: LineEdit = _hud._chat_input
	var btn_pos: Vector2 = _rect(_hud.mobile_chat_button).get_center()

	await _tap(btn_pos)
	assert(ci.visible and fake_player.is_chat_typing, "sohbet düğmesi kutuyu açmalı")
	await _tap(btn_pos)
	assert(not ci.visible and not fake_player.is_chat_typing, "sohbet düğmesine tekrar dokunmak kutuyu kapatmalı")

	await _tap(btn_pos)
	await _tap(Vector2(1700.0, 300.0))
	assert(not ci.visible and not fake_player.is_chat_typing, "dünyaya dokunmak kutuyu kapatmalı (oyuncu kilitli kalmamalı)")

	await _tap(btn_pos)
	await _tap(_rect(ci).get_center())
	assert(ci.visible and fake_player.is_chat_typing, "kutunun kendisine dokunmak kutuyu kapatmamalı")
	await _tap(Vector2(160.0, 900.0))
	assert(not ci.visible and not fake_player.is_chat_typing, "joystick bölgesine dokunmak kutuyu kapatmalı")
	await _teardown()
