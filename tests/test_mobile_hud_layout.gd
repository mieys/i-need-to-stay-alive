extends Node

## Telefon HUD'u v2 (madde 273; kullanıcı onayı 2026-10-18, prototip tools/proto_20261018/mobil_proto.gd _ml_hud): yerleşim
## ölçüleri, kare minimap, yetenek yuvaları, grup paneli katlama, okunmamış sohbet rozeti, hızlı sohbet penceresi.

const MobileUIPath := "res://scripts/mobile_ui.gd"
const W := 2400
const H := 1080


class FakeAlly extends Node:
	var peer_id: int = 0
	var player_name: String = ""
	var char_id: int = 2
	var health: float = 80.0
	var max_health: float = 100.0
	var item_shield_max: float = 50.0
	var item_shield_hp: float = 25.0
	var is_dead: bool = false
	var is_downed: bool = false
	var match_damage_dealt: float = 0.0


var _hud: Node = null
var _extra: Array[Node] = []


func _setup(allies: int) -> void:
	Input.use_accumulated_input = false
	(load(MobileUIPath) as GDScript).set(&"enabled", true)
	DisplayServer.window_set_size(Vector2i(W, H))
	get_tree().root.size = Vector2i(W, H)
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
	await _frames(20)


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


func _rect(c: Control) -> Rect2:
	return c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)


func _near(a: float, b: float, tol: float = 2.0) -> bool:
	return absf(a - b) <= tol


func test_layout_matches_prototype() -> void:
	await _setup(3)
	var frame: Rect2 = _rect(_hud._ph_map_frame)
	assert(_near(frame.position.x, 18.0) and _near(frame.position.y, 18.0) and _near(frame.size.x, 300.0) and _near(frame.size.y, 300.0),
			"minimap çerçevesi sol üstte 300 px kare olmalı: %s" % frame)
	var mm: Control = _hud.get_node("MinimapControl")
	assert(bool(mm.get("square")), "telefonda minimap kare çizilmeli")
	var map_r: Rect2 = _rect(mm)
	assert(frame.encloses(map_r), "minimap çerçevenin içinde olmalı: %s / %s" % [map_r, frame])
	var chat: Rect2 = _rect(_hud.mobile_chat_button)
	assert(_near(chat.position.x, 334.0) and _near(chat.position.y, 18.0), "sohbet düğmesi minimapin sağında, üst hizada: %s" % chat)
	var q: Rect2 = _rect(_hud.skill_icon)
	var e: Rect2 = _rect(_hud.skill2_icon)
	var r: Rect2 = _rect(_hud.skill3_icon)
	var f: Rect2 = _rect(_hud.spirit_icon)
	assert(_near(q.size.x, 162.0, 3.0), "yetenek halkası 162 px olmalı: %s" % q)
	assert(_near(q.get_center().x, e.get_center().x) and _near(e.get_center().x, r.get_center().x), "R / E / Q aynı sütunda olmalı")
	assert(r.get_center().y < e.get_center().y and e.get_center().y < q.get_center().y, "ulti (R) en üstte, Q en altta olmalı")
	assert(_near(f.get_center().y, q.get_center().y) and f.get_center().x < q.get_center().x, "ruhani F, Q'nun solunda olmalı")
	assert(_near(q.get_center().x, W - 194.0, 3.0) and _near(q.get_center().y, H - 117.0, 3.0), "Q yuvası: %s" % q)
	var strip: Rect2 = _rect(_hud._ph_strip)
	assert(_near(strip.end.x, W - 186.0) and _near(strip.position.y, 26.0), "sağ üst şerit: %s" % strip)
	var gear: Rect2 = _rect(_hud.mobile_pause_button)
	assert(_near(gear.end.x, W - 100.0) and _near(gear.position.y, 20.0), "ayar düğmesi sağ üstte: %s" % gear)
	var gold: Rect2 = _rect(_hud.gold_indicator)
	assert(strip.encloses(gold), "altın göstergesi şeridin içinde olmalı: %s / %s" % [gold, strip])
	var bg: Rect2 = _rect(_hud.get_node("PartyPanelLayer/PartyPanel/Background"))
	assert(_near(bg.position.x, 18.0, 3.0) and _near(bg.size.x, 300.0, 3.0) and _near(bg.position.y, 334.0, 3.0),
			"grup paneli minimapin altında, minimap genişliğinde: %s" % bg)
	var party_btn: Button = _hud.get_node("PartyPanelLayer/PartyPanel")._stats_button
	assert(party_btn.is_visible_in_tree() and party_btn.text == "İstatistik", "grup panelinin altında İstatistik düğmesi olmalı")
	assert(not _hud.mobile_interact_button.visible, "etkileşim düğmesi sadece yakındayken görünmeli")
	await _teardown()


func test_party_collapse_shows_portrait_column() -> void:
	await _setup(2)
	var party: Control = _hud.get_node("PartyPanelLayer/PartyPanel")
	_hud._toggle_mobile_party()
	await _frames(20)
	assert(not party.visible, "katlayınca grup paneli gizlenmeli")
	assert(_hud._ph_party_column.visible, "katlıyken portre sütunu görünmeli")
	var tab: Rect2 = _rect(_hud.mobile_party_toggle)
	assert(tab.position.x < 18.0 + 300.0, "katlıyken sekme sütunun yanına gelmeli: %s" % tab)
	_hud._toggle_mobile_party()
	await _frames(20)
	assert(party.visible and not _hud._ph_party_column.visible, "açınca panel geri gelmeli, sütun gizlenmeli")
	await _teardown()


func test_unread_badge_and_quick_chat_window() -> void:
	await _setup(1)
	_hud.append_chat_message("Ali", "selam")
	await _frames(3)
	assert(_hud._ph_chat_badge.visible and _hud._ph_badge_label.text == "1", "okunmamış mesaj rozeti 1 göstermeli")
	_hud._ph_toggle_quick_chat()
	await _frames(3)
	var qc: Control = _hud._ph_quick_chat
	assert(qc.visible, "hızlı sohbet penceresi açılmalı")
	assert(not _hud._ph_chat_badge.visible, "pencere açılınca rozet sıfırlanmalı")
	var texts: Array = []
	for row: Array in qc._recent_rows:
		texts.append((row[1] as Label).text)
	assert(texts.has("selam"), "pencerenin kuyusunda son mesaj görünmeli: %s" % str(texts))
	assert(_hud._mobile_joy_exclude().has(qc), "açık pencere joystick'i engellemeli")
	_hud._ph_toggle_quick_chat()
	await _frames(2)
	assert(not qc.visible, "ikinci basış pencereyi kapatmalı")
	await _teardown()
