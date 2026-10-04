extends Control

## TELEFON DOKUNMATİK KONTROLLERİ (kullanıcı isteği 2026-10-01, bkz. mobile_ui.gd) - yalnız MobileUI.enabled iken
## hud.gd kurar. Yeni oyun mantığı YOK: dokunuşlar mevcut eylemlere basar -
##   joystick -> move_left/right/up/down (analog güç; player.gd Input.get_vector okur),
##   yetenek düğmeleri (hud.gd'nin kendi yetenek ikonları) -> skill / skill2 / skill3 / skill4,
##   etkileşim düğmesi (sadece "interact_prompt" grubundaki bir uyarı görünürken) -> interact,
##   duraklat düğmesi -> ui_cancel.
## Bu yüzden oyuncu, yetenek ve ağ kodu değişmez; multiplayer aynen çalışır.
##
## ÇOKLU DOKUNUŞ: Godot'nun "dokunuştan fare" öykünmesi yalnız İLK parmak için çalışır - joystick tutulurken ikinci
## parmakla yetenek basılabilsin diye düğmeler fareyle değil InputEventScreenTouch ile (parmak kimliği başına) izlenir.
## Görseller fare olaylarını yutmaz (mouse_filter IGNORE).

const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const JOY_ZONE_W := 0.45 ## ekranın sol bu kadarı joystick bölgesi
const JOY_ZONE_TOP := 0.30 ## üstteki can/envanter düğmeleri joystick başlatmasın
const JOY_RADIUS := 62.0 ## HUD birimi (x MobileUI.HUD_SCALE)
const KNOB_RADIUS := 25.0
const DEAD_ZONE := 0.12
const HIT_PAD := 1.2 ## düğme isabet yarıçapı görsel yarıçapın bu katı (parmak toleransı)
const REST_POS := Vector2(0.17, 0.74) ## joystick'in boştaki hayalet konumu (ekran oranı) - rest_center yoksa

const C_FILL := Color(1.0, 0.96, 0.86, 0.12)
const C_RING := Color(1.0, 0.94, 0.82, 0.6)
const C_OUTLINE := Color(0.24, 0.15, 0.08, 0.55)
const C_KNOB := Color(0.95, 0.86, 0.7, 0.95)
const C_KNOB_LO := Color(0.78, 0.6, 0.4, 0.95)

## {"node": Control, "action": StringName, "round": bool}
var _buttons: Array = []
var interact_button: Control = null
var pause_button: Control = null
## HUD'un duraklatmayan panelleri (envanter/özellikler) açıkken true döner - joystick başlamaz/çizilmez.
var extra_block: Callable = Callable()
## -> Array[Control]: üstüne dokunulunca joystick BAŞLAMAYAN alanlar (bkz. hud.gd _mobile_joy_exclude).
var joy_exclude: Callable = Callable()
var _u: float = MobileUIScript.HUD_SCALE
## Boştaki hayalet joystick merkezi (tuval px) - hud.gd Q düğmesine simetrik verir; sıfırsa REST_POS.
var rest_center: Vector2 = Vector2.ZERO

var _joy_id: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _joy_knob: Vector2 = Vector2.ZERO
var _held: Dictionary = {} ## parmak -> eylem
var _axes: Dictionary = {&"move_left": 0.0, &"move_right": 0.0, &"move_up": 0.0, &"move_down": 0.0}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Duraklayınca basılı eylemleri bırakabilmek için.
	process_mode = Node.PROCESS_MODE_ALWAYS


func register_button(node: Control, action: StringName, round_shape: bool = true) -> void:
	for b in _buttons:
		if b["node"] == node:
			b["action"] = action
			return
	_buttons.append({"node": node, "action": action, "round": round_shape})


func _blocked() -> bool:
	return get_tree().paused or GameManager.is_any_blocking_panel_open()


func _joy_blocked() -> bool:
	return _blocked() or (extra_block.is_valid() and bool(extra_block.call()))


func _process(_delta: float) -> void:
	if _blocked() and (_joy_id != -1 or not _held.is_empty()):
		_release_all()
	elif _joy_id != -1 and _joy_blocked():
		_joy_id = -1
		_set_vector(Vector2.ZERO)
	if interact_button:
		var show: bool = not _blocked() and _interact_prompt_visible()
		if interact_button.visible != show:
			interact_button.visible = show
	queue_redraw()


func _interact_prompt_visible() -> bool:
	for n in get_tree().get_nodes_in_group(&"interact_prompt"):
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			return true
	return false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_down(t.index, t.position)
		else:
			_on_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_id:
			_joy_move(d.position)


func _on_down(index: int, pos: Vector2) -> void:
	## Envanter/özellikler gibi HUD paneli açıkken (extra_block) yetenek düğmeleri de basılmaz - panel ekranı kaplıyor,
	## altında kalan bir yetenek düğmesinin yerine dokunmak yanlışlıkla yetenek kullandırmasın.
	if _blocked() or (extra_block.is_valid() and bool(extra_block.call())):
		return
	for b in _buttons:
		var node: Control = b["node"]
		if not is_instance_valid(node) or not node.is_visible_in_tree():
			continue
		if _hit(node, pos, b["round"]):
			var action: StringName = b["action"]
			Input.action_press(action)
			_held[index] = action
			return
	## Joystick bölgesindeki dokunulabilir HUD parçaları (grup paneli satırları/pencereleri, sohbet kutusu) joystick başlatmaz.
	if joy_exclude.is_valid():
		for c in joy_exclude.call():
			if c is Control and is_instance_valid(c) and (c as Control).is_visible_in_tree() 					and (c as Control).get_global_rect().has_point(pos):
				return
	if _joy_id == -1 and not _joy_blocked() and pos.x < size.x * JOY_ZONE_W and pos.y > size.y * JOY_ZONE_TOP:
		_joy_id = index
		_joy_center = pos
		_joy_move(pos)


func _on_up(index: int) -> void:
	if _held.has(index):
		Input.action_release(_held[index])
		_held.erase(index)
	if index == _joy_id:
		_joy_id = -1
		_set_vector(Vector2.ZERO)


func _hit(node: Control, pos: Vector2, round_shape: bool) -> bool:
	var xf: Transform2D = node.get_global_transform()
	var center: Vector2 = xf * (node.size * 0.5)
	var half: Vector2 = node.size * 0.5 * xf.get_scale()
	if round_shape:
		return pos.distance_to(center) <= maxf(half.x, half.y) * HIT_PAD
	return Rect2(center - half * HIT_PAD, half * 2.0 * HIT_PAD).has_point(pos)


func _joy_move(pos: Vector2) -> void:
	var v: Vector2 = (pos - _joy_center) / (JOY_RADIUS * _u)
	if v.length() > 1.0:
		v = v.normalized()
	_joy_knob = v
	_set_vector(v if v.length() > DEAD_ZONE else Vector2.ZERO)


func _set_vector(v: Vector2) -> void:
	_set_axis(&"move_right", maxf(v.x, 0.0))
	_set_axis(&"move_left", maxf(-v.x, 0.0))
	_set_axis(&"move_down", maxf(v.y, 0.0))
	_set_axis(&"move_up", maxf(-v.y, 0.0))
	if v == Vector2.ZERO:
		_joy_knob = Vector2.ZERO


func _set_axis(action: StringName, strength: float) -> void:
	if is_equal_approx(float(_axes[action]), strength):
		return
	_axes[action] = strength
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _release_all() -> void:
	for idx in _held:
		Input.action_release(_held[idx])
	_held.clear()
	_joy_id = -1
	_set_vector(Vector2.ZERO)


func _exit_tree() -> void:
	_release_all()


## Joystick: dokunulan yerde belirir (yüzen); boştayken sol altta soluk hayaleti. Piksel kenar (kenar yumuşatma yok).
func _draw() -> void:
	if _joy_blocked():
		return
	var active: bool = _joy_id != -1
	var jr: float = JOY_RADIUS * _u
	var kr: float = KNOB_RADIUS * _u
	var rest: Vector2 = rest_center if rest_center != Vector2.ZERO else Vector2(size.x * REST_POS.x, size.y * REST_POS.y)
	var c: Vector2 = _joy_center if active else rest
	var a: float = 1.0 if active else 0.4
	draw_circle(c, jr, Color(C_FILL, C_FILL.a * a), true, -1.0, false)
	draw_arc(c, jr + 2.0, 0.0, TAU, 64, Color(C_OUTLINE, C_OUTLINE.a * a), 3.0, false)
	draw_arc(c, jr - 1.5, 0.0, TAU, 64, Color(C_RING, C_RING.a * a), 4.0, false)
	var k: Vector2 = c + _joy_knob * jr
	draw_circle(k, kr + 3.0, Color(C_OUTLINE, C_OUTLINE.a * a * 1.4), true, -1.0, false)
	draw_circle(k, kr, Color(C_KNOB_LO, C_KNOB_LO.a * a), true, -1.0, false)
	draw_circle(k + Vector2(-4.0, -4.0), kr - 7.0, Color(C_KNOB, C_KNOB.a * a), true, -1.0, false)
