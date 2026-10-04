extends Node

## Kumandayla MENÜ/KART gezinmesi - kullanıcı bildirimi (2026-10-03): "yön tuşlarıyla kart seçemiyorum butonları
## onaylayamıyorum ayarları açamıyorum bazı eksiklikler var kontrol eder misin".
##
## Kök nedenler:
##  1) Godot 4.7'nin varsayılan ui_accept / ui_cancel eylemlerinde HİÇ kumanda düğmesi yok (sadece Enter/Space/Escape) -
##     game_manager.gd'deki eski "A/B zaten motorun varsayılanı" notu yanlıştı. -> A/B/Start artık orada bağlanıyor.
##  2) Arayüzler yeniden tasarlanınca ekranların neredeyse hiçbiri açılışta bir düğmeye ODAK vermiyordu
##     (GamepadFocusHelper sadece satıcı ekranında kalmıştı): odak yoksa D-pad'in gezinecek yeri yok.
##  3) Kartların "seçili" görünümü sadece fare üstüne gelince çalışıyordu; efsun kartlarının odağı kapalıydı.
## Ekran ekran yamamak yerine (yeni ekran eklenince yine unutulur) bu TEK düğüm (GameManager'ın çocuğu, duraklatmada da
## çalışır) şunu yapar - SADECE son girdi kumandadan geldiyse (fare/klavye/dokunma kullananı hiç etkilemez):
##  - Açık bir PENCERE varsa ve odak o pencerede değilse, penceredeki ilk seçilebilir öğeye odak verir (önce
##    FIRST_FOCUS_GROUP'taki öğeler - ör. kartlar, karıştır düğmesinden önce - sonra ilk düğme).
##  - Odaktaki öğenin çevresine her zaman görünen bir çerçeve çizer (kartlar dahil, kendi odak stili olmasa bile).
##  - Pencere yokken (oyun oynanırken) HUD'daki bir düğme odakta kalırsa odağı bırakır: yoksa D-pad yürürken odağı
##    gezdirir, A ona tıklardı.
## PENCERE sayılanlar: GROUP üyeleri + ReadingUiWatcher.GROUP üyeleri (kart/dükkan ekranları zaten oradalar) + Main
## olmayan sahneler (ana menü, karakter seçimi, lobi). Birden fazlası açıksa en üst CanvasLayer'dakini seçer.
## YENİ BİR PENCERE EKLERSEN: _ready()'de add_to_group(GamepadUi.GROUP) (kart/dükkan ekranıysa ReadingUiWatcher.GROUP
## zaten yeter). Açılışta ilk seçilmesi gereken öğe ilk düğme değilse onu FIRST_FOCUS_GROUP'a ekle.

const GROUP := &"gamepad_modal"
const FIRST_FOCUS_GROUP := &"gamepad_first_focus"
const ReadingUiWatcherScript := preload("res://scripts/reading_ui_watcher.gd")
const RING_COLOR := Color(1.0, 0.86, 0.35, 1.0)
const RING_PAD := 4.0
const SEARCH_INTERVAL := 0.1

## Son girdi kumandadan mı geldi (fare/klavye/dokunma gelince kapanır).
var joypad_active: bool = false
var _ring_layer: CanvasLayer = null
var _ring: Panel = null
var _search_cd: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ring_layer = CanvasLayer.new()
	_ring_layer.name = "GamepadFocusRing"
	_ring_layer.layer = 126
	add_child(_ring_layer)
	_ring = Panel.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.visible = false
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(4)
	sb.border_color = RING_COLOR
	sb.set_corner_radius_all(6)
	_ring.add_theme_stylebox_override("panel", sb)
	_ring_layer.add_child(_ring)


func _input(event: InputEvent) -> void:
	if (event is InputEventJoypadButton and event.pressed) \
			or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		joypad_active = true
	elif event is InputEventMouseButton or event is InputEventScreenTouch \
			or (event is InputEventKey and event.pressed) \
			or (event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0):
		joypad_active = false


func _process(delta: float) -> void:
	if not joypad_active:
		_ring.visible = false
		return
	var vp: Viewport = get_viewport()
	var owner: Control = vp.gui_get_focus_owner()
	var modal: Node = _top_modal()
	if modal == null:
		if owner and not (owner is LineEdit or owner is TextEdit):
			owner.release_focus()
		_ring.visible = false
		return
	if owner == null or not owner.is_visible_in_tree() or not (modal == owner or modal.is_ancestor_of(owner)):
		_search_cd -= delta
		if _search_cd <= 0.0:
			_search_cd = SEARCH_INTERVAL
			var target: Control = _first_focusable(modal)
			if target:
				target.grab_focus()
				owner = target
	_update_ring(owner if owner and owner.is_visible_in_tree() else null)


func _top_modal() -> Node:
	var tree: SceneTree = get_tree()
	var best: Node = null
	var best_layer: int = -1000000
	var candidates: Array = tree.get_nodes_in_group(GROUP) + tree.get_nodes_in_group(ReadingUiWatcherScript.GROUP)
	var scene: Node = tree.current_scene
	if scene and scene.name != "Main":
		candidates.push_front(scene)
	for n: Node in candidates:
		if not is_instance_valid(n) or not n.is_inside_tree() or n.is_queued_for_deletion():
			continue
		if not ReadingUiWatcherScript._is_shown(n):
			continue
		var l: int = _layer_of(n)
		if l >= best_layer:
			best_layer = l
			best = n
	return best


static func _layer_of(n: Node) -> int:
	var p: Node = n
	while p:
		if p is CanvasLayer:
			return (p as CanvasLayer).layer
		p = p.get_parent()
	return 0


static func _focusable(c: Control) -> bool:
	if c.focus_mode == Control.FOCUS_NONE or not c.is_visible_in_tree():
		return false
	if c is LineEdit or c is TextEdit:
		return false ## kumandada yazı yazılmaz (sanal klavye yok)
	if c is BaseButton and (c as BaseButton).disabled:
		return false
	return c.size.x > 0.0 and c.size.y > 0.0


func _first_focusable(root: Node) -> Control:
	for n: Node in get_tree().get_nodes_in_group(FIRST_FOCUS_GROUP):
		var c := n as Control
		if c and (root == c or root.is_ancestor_of(c)) and _focusable(c):
			return c
	var fallback: Control = null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_front()
		var c := n as Control
		if c and _focusable(c):
			if c is BaseButton:
				return c
			if fallback == null:
				fallback = c
		## Aynı sırayla (ağaç sırası) gez: çocukları öne ekle.
		var kids: Array[Node] = n.get_children()
		for i in range(kids.size() - 1, -1, -1):
			stack.push_front(kids[i])
	return fallback


func _update_ring(owner: Control) -> void:
	if owner == null:
		_ring.visible = false
		return
	var xf: Transform2D = owner.get_global_transform_with_canvas()
	var sz: Vector2 = owner.size * xf.get_scale()
	_ring.position = xf.origin - Vector2(RING_PAD, RING_PAD)
	_ring.size = sz + Vector2(RING_PAD, RING_PAD) * 2.0
	_ring.visible = true
