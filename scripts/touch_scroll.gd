extends Node

## Dokunmatik kaydırma - kullanıcı bildirimi (2026-10-04): "kaydırma gerektiren şeyler düzgün kaydırılamıyor sadece boş
## kenarlara tıklamak gerekiyor kaydırmak için".
##
## Kök neden: Godot'un ScrollContainer'ı parmakla sürüklemeyi ancak dokunuş KENDİSİNE ulaşırsa yapar; kartlar/düğmeler
## (mouse_filter STOP, bazıları accept_event) dokunuşu yutuyordu -> liste sadece aradaki boşluklardan kayıyordu.
## Bu TEK düğüm (GameManager'ın çocuğu, duraklatmada da çalışır) dokunuşu GUI'den ÖNCE (_input) izler:
##  - Parmak inince altındaki en üstteki kaydırılabilir ScrollContainer not edilir (kartın/düğmenin üstü olsa bile).
##  - DEADZONE'dan fazla sürüklenirse liste parmakla kayar; o dokunuşun düğmeye "basma"sı iptal edilir (düğmeye çok uzak
##    bir noktada sahte "bırakma" gönderilir -> Godot bırakmayı basılan düğmeye iletir, düğme dışarıda bırakıldığı için
##    tetiklenmez) ve sürükleme olayları GUI'ye gitmez (ScrollContainer'ın kendi sürüklemesiyle çift kaymasın).
##  - Parmak kalkınca son hızla bir süre savrulmaya devam eder (FLING_DECAY).
## Sadece dokunmatik olaylarda çalışır - fare/klavye/kumanda hiç etkilenmez. Kısa dokunuş (sürüklemesiz) eskisi gibi tıklar.
## Telefon HUD'unda joystick'i ya da bir yetenek düğmesini tutan parmak liste KAYDIRMAZ (touch_controls.gd owns_touch):
## sohbet/grup listesi joystick bölgesinde durduğu için, eskiden onları kaydırırken karakter de yürüyordu (2026-10-05).

const DEADZONE := 18.0 ## px (ekran) - bundan kısa hareket dokunuş sayılır
const FLING_DECAY := 6.0 ## 1/sn - büyük = savrulma çabuk durur
const FLING_MIN := 30.0 ## px/sn - altında savrulma yok
## Bırakma hızı = SON VEL_WINDOW_USEC içindeki toplam yer değiştirme / geçen süre (2026-10-05). Eskiden her sürükleme olayında
## "olay arası duvar saati" ile anlık hız hesaplanıp 0.5 ile süzülüyordu: aynı karede gelen olaylarda (dt ~ 0) hız onlarca kat şişiyor,
## parmak kalkarkenki küçük TERS titreme savrulmayı ters çevirip listeyi BAŞA fırlatıyordu ("aşağı kaydırınca başa dönüyor").
const VEL_WINDOW_USEC := 120000 ## bırakma hızı için bakılan pencere
const VEL_MIN_SPAN_USEC := 24000 ## pencerede bundan kısa süre varsa güvenilir hız yok -> savrulma yok
const VEL_MAX := 6000.0 ## px/sn (ScrollContainer birimi) - üst sınır
const FLING_STALE_USEC := 100000 ## son sürüklemeden bu kadar sonra bırakıldıysa (parmak durdu) savrulma yok

var _sc: ScrollContainer = null
var _start_pos: Vector2 = Vector2.ZERO
var _start_scroll: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _samples: Array = [] ## [zaman (usec), ekran konumu] - son sürükleme örnekleri (bırakma hızı için)
var _vel: Vector2 = Vector2.ZERO ## px/sn, ScrollContainer yerel birimi
var _fling: ScrollContainer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.index != 0:
			return
		if t.pressed:
			_fling = null
			_sc = _scroll_at(t.position)
			_dragging = false
			if _sc and _controls_own(t.index):
				_sc = null
			if _sc:
				_start_pos = t.position
				_samples = [[Time.get_ticks_usec(), t.position]]
				_start_scroll = Vector2(_sc.scroll_horizontal, _sc.scroll_vertical)
				_vel = Vector2.ZERO
		else:
			if _dragging:
				get_viewport().set_input_as_handled()
				_vel = _release_velocity()
				if is_instance_valid(_sc) and _vel.length() > FLING_MIN:
					_fling = _sc
			_sc = null
			_dragging = false
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index != 0 or _sc == null or not is_instance_valid(_sc):
			return
		## Parmak joystick'i/yetenek düğmesini tutuyorsa (touch_controls.gd ağaçta bizden ÖNCE işler ama sıraya
		## güvenmeyelim) liste kaymaz: oyun girdisi önceliklidir.
		if not _dragging and _controls_own(d.index):
			_sc = null
			return
		_add_sample(d.position)
		if not _dragging and d.position.distance_to(_start_pos) > DEADZONE:
			_dragging = true
			_cancel_press()
		if _dragging:
			var k: float = _local_scale(_sc)
			var delta: Vector2 = (d.position - _start_pos) / k
			_apply(_sc, _start_scroll - delta)
			get_viewport().set_input_as_handled()
	elif _dragging and event is InputEventMouseMotion:
		## Dokunuştan türetilen fare hareketi - GUI'ye gitmesin (ScrollContainer'ın kendi sürüklemesiyle çift kayardı).
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _fling == null:
		return
	if not is_instance_valid(_fling) or not _fling.is_visible_in_tree():
		_fling = null
		return
	_vel *= exp(-FLING_DECAY * delta)
	if _vel.length() < FLING_MIN:
		_fling = null
		return
	_apply(_fling, Vector2(_fling.scroll_horizontal, _fling.scroll_vertical) + _vel * delta)


func _add_sample(pos: Vector2) -> void:
	var now: int = Time.get_ticks_usec()
	_samples.append([now, pos])
	while _samples.size() > 2 and now - int(_samples[0][0]) > VEL_WINDOW_USEC * 2:
		_samples.pop_front()


## Parmak kalkarken savrulma hızı (ScrollContainer yerel birimi, px/sn): son VEL_WINDOW_USEC'teki net yer değiştirme / süre.
## Küçük bir kalkış titremesi pencerenin toplamında kaybolur; parmak durup bırakıldıysa ya da pencere çok kısaysa savrulma yok.
func _release_velocity() -> Vector2:
	if _samples.size() < 2 or not is_instance_valid(_sc):
		return Vector2.ZERO
	var last: Array = _samples.back()
	if Time.get_ticks_usec() - int(last[0]) > FLING_STALE_USEC:
		return Vector2.ZERO
	var first: Array = last
	for i in range(_samples.size() - 1, -1, -1):
		if int(last[0]) - int(_samples[i][0]) > VEL_WINDOW_USEC:
			break
		first = _samples[i]
	var span: int = int(last[0]) - int(first[0])
	if span < VEL_MIN_SPAN_USEC:
		return Vector2.ZERO
	var v: Vector2 = -((last[1] as Vector2) - (first[1] as Vector2)) / _local_scale(_sc) / (float(span) / 1e6)
	return v.limit_length(VEL_MAX)


## Bu parmağı telefon HUD'unun joystick'i / düğmesi tutuyor mu (bkz. touch_controls.gd owns_touch)?
func _controls_own(index: int) -> bool:
	var tc: Node = get_tree().get_first_node_in_group(&"touch_controls")
	return tc != null and tc.has_method(&"owns_touch") and bool(tc.call(&"owns_touch", index))


func _apply(sc: ScrollContainer, target: Vector2) -> void:
	if sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		sc.scroll_vertical = int(roundf(target.y))
	if sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		sc.scroll_horizontal = int(roundf(target.x))


## Basılmış düğmenin basmasını iptal et: Godot fare bırakmasını basılan kontrole iletir; çok uzakta bırakıldığı için tetiklenmez.
func _cancel_press() -> void:
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = Vector2(-100000.0, -100000.0)
	up.global_position = up.position
	get_viewport().push_input(up)


## Ekran noktasının altındaki, içeriği taşan (kaydırılabilir) en üstteki ScrollContainer.
func _scroll_at(pos: Vector2) -> ScrollContainer:
	var best: ScrollContainer = null
	var best_layer: int = -1000000
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var sc := n as ScrollContainer
		if sc == null or not sc.is_visible_in_tree() or not _scrollable(sc):
			continue
		var local: Vector2 = sc.get_global_transform_with_canvas().affine_inverse() * pos
		if not Rect2(Vector2.ZERO, sc.size).has_point(local):
			continue
		var layer: int = _layer_of(sc)
		## Aynı katmanda iç içe kaydırma kutularında içteki (ağaçta sonra gelen) kazanır.
		if layer >= best_layer:
			best_layer = layer
			best = sc
	return best


static func _scrollable(sc: ScrollContainer) -> bool:
	var v: ScrollBar = sc.get_v_scroll_bar()
	var h: ScrollBar = sc.get_h_scroll_bar()
	var can_v: bool = sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and v != null \
			and v.max_value - v.page > 1.0
	var can_h: bool = sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and h != null \
			and h.max_value - h.page > 1.0
	return can_v or can_h


static func _local_scale(c: Control) -> float:
	var s: Vector2 = c.get_global_transform_with_canvas().get_scale()
	return maxf(0.001, absf(s.y))


static func _layer_of(n: Node) -> int:
	var p: Node = n
	while p:
		if p is CanvasLayer:
			return (p as CanvasLayer).layer
		p = p.get_parent()
	return 0
