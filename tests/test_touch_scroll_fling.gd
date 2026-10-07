extends Node

## Kullanıcı bildirimi (2026-10-05, Android): "herhangi bir arayüzde aşağı kaydırdığımda başa geri atıyor". Kök neden: touch_scroll.gd bırakma
## hızını her sürükleme olayında "olay arası duvar saati" ile hesaplayıp süzüyordu; aynı karede gelen olaylarda dt ~ 0 olunca hız onlarca kat
## şişiyor, parmak kalkarkenki küçük TERS titreme savrulmayı ters çevirip listeyi başa fırlatıyordu. Artık hız son 120 ms'nin net yer
## değiştirmesinden hesaplanır. Burada gerçek dokunma olayları (ScreenTouch/ScreenDrag) enjekte edilir.

const W := 1920
const H := 1080

var _last: Vector2 = Vector2.ZERO


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = pos
	e.relative = pos - _last
	_last = pos
	Input.parse_input_event(e)


func _make_scroll() -> ScrollContainer:
	Input.use_accumulated_input = false
	DisplayServer.window_set_size(Vector2i(W, H))
	get_tree().root.size = Vector2i(W, H)
	get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var layer := CanvasLayer.new()
	add_child(layer)
	var sc := ScrollContainer.new()
	sc.position = Vector2(100.0, 100.0)
	sc.size = Vector2(600.0, 400.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layer.add_child(sc)
	var content := Control.new()
	content.custom_minimum_size = Vector2(600.0, 3000.0)
	sc.add_child(content)
	return sc


## Parmak yukarı (içerik aşağı) sürüklenir, bırakılır; verilen süreler sonra kaydırma değerleri döner.
## jitter: kalkıştan hemen önce AYNI karede ters yönde iki küçük sürükleme. rest_ms: bırakmadan önce parmak durup bekler (olay yok).
func _flick(sc: ScrollContainer, jitter: bool, rest_ms: int = 0) -> Dictionary:
	var start := Vector2(400.0, 420.0)
	_last = start
	_touch(start, true)
	await _frames(2)
	var step: float = -12.0
	for i in 14:
		_drag(start + Vector2(0.0, step * (i + 1)))
		await _frames(1)
	var end: Vector2 = start + Vector2(0.0, step * 14.0)
	if jitter:
		_drag(end - Vector2(0.0, step * 0.25))
		_drag(end - Vector2(0.0, step * 0.5))
	if rest_ms > 0:
		var t0: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < rest_ms:
			await get_tree().process_frame
	var at_release: int = sc.scroll_vertical
	_touch(end, false)
	var t1: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 900:
		await get_tree().process_frame
	return {"release": at_release, "after": sc.scroll_vertical}


func test_flick_keeps_going_forward_and_never_snaps_back() -> void:
	var sc: ScrollContainer = _make_scroll()
	await _frames(5)
	assert(sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page > 100.0, "test önkoşulu: içerik taşmalı")
	var r: Dictionary = await _flick(sc, false)
	assert(int(r["release"]) > 100, "sürükleme listeyi kaydırmalı: %s" % str(r))
	assert(int(r["after"]) >= int(r["release"]), "temiz kaydırma sonrası savrulma ileri gitmeli: %s" % str(r))
	sc.get_parent().queue_free()


func test_lift_off_jitter_does_not_throw_the_list_back_to_the_top() -> void:
	var sc: ScrollContainer = _make_scroll()
	await _frames(5)
	var r: Dictionary = await _flick(sc, true)
	assert(int(r["release"]) > 100, "sürükleme listeyi kaydırmalı: %s" % str(r))
	assert(int(r["after"]) >= int(r["release"]) - 5, "kalkış titremesi listeyi geri/başa fırlatmamalı: %s" % str(r))
	sc.get_parent().queue_free()


func test_finger_that_rested_before_lifting_does_not_fling() -> void:
	var sc: ScrollContainer = _make_scroll()
	await _frames(5)
	var r: Dictionary = await _flick(sc, false, 250)
	assert(int(r["release"]) > 100, "sürükleme listeyi kaydırmalı: %s" % str(r))
	assert(absi(int(r["after"]) - int(r["release"])) <= 3, "durup bırakılan parmak savurmamalı: %s" % str(r))
	sc.get_parent().queue_free()
