extends Node

## madde 206: oyun imleci (scripts/game_cursor.gd). Ölçek pencereye göre tam kat, uç pikseli dokuda koyu ve sabit,
## düğmeler el şekline geçer (devre dışı / tam ekran yakalayıcı / kendi şekli olan hariç), basılı hâl aç-kapa.

const GameCursor := preload("res://scripts/game_cursor.gd")

var _nodes: Array[Node] = []


func _add(n: Node) -> Node:
	add_child(n)
	_nodes.append(n)
	return n


func _cleanup() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()


func test_scale_follows_window() -> void:
	## imleç pikseli = arayüz pikselinin 3/4'ü, aşağı yuvarlanır ("çok büyük" geri bildirimi)
	assert(GameCursor.scale_for(Vector2i(1920, 1080)) == 1)
	assert(GameCursor.scale_for(Vector2i(2560, 1440)) == 2)
	assert(GameCursor.scale_for(Vector2i(3840, 2160)) == 3)
	assert(GameCursor.scale_for(Vector2i(5120, 2880)) == 4)
	assert(GameCursor.scale_for(Vector2i(7680, 4320)) == 4) ## donanım imleci sınırı
	assert(GameCursor.scale_for(Vector2i(1280, 720)) == 1)
	assert(GameCursor.scale_for(Vector2i(2560, 1600)) == 2) ## keep oranı: dar kenar belirler
	assert(GameCursor.scale_for(Vector2i(0, 0)) == 1)


func test_textures_share_size_and_hotspot() -> void:
	var texs: Array[Texture2D] = [GameCursor.TEX_NORMAL, GameCursor.TEX_HAND, GameCursor.TEX_PRESSED]
	for tex: Texture2D in texs:
		assert(tex.get_size() == GameCursor.TEX_NORMAL.get_size())
		var img := GameCursor.scaled_image(tex, 1)
		var tip := img.get_pixelv(GameCursor.HOTSPOT)
		assert(tip.a > 0.99 and tip.get_luminance() < 0.2) ## koyu uç pikseli = tıklama noktası
		## ucun solu ve üstü boş (çaprazına basılı hâlde tık ışınının gölgesi düşer)
		assert(img.get_pixelv(GameCursor.HOTSPOT - Vector2i(1, 0)).a == 0.0)
		assert(img.get_pixelv(GameCursor.HOTSPOT - Vector2i(0, 1)).a == 0.0)
	var big := GameCursor.scaled_image(GameCursor.TEX_NORMAL, 3)
	assert(big.get_size() == Vector2i(GameCursor.TEX_NORMAL.get_size()) * 3)
	assert(big.get_size().x <= 256 and big.get_size().y <= 256)
	assert(big.get_pixelv(GameCursor.HOTSPOT * 3).is_equal_approx(big.get_pixelv(GameCursor.HOTSPOT * 3 + Vector2i(2, 2))))


func test_buttons_get_hand_shape() -> void:
	assert(GameCursor._inst != null) ## UISound kurdu
	var b := _add(Button.new()) as Button
	assert(b.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
	var off := Button.new()
	off.disabled = true
	_add(off)
	assert(off.mouse_default_cursor_shape == Control.CURSOR_ARROW)
	off.disabled = false
	off.mouse_entered.emit()
	assert(off.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
	var own := Button.new()
	own.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_add(own)
	assert(own.mouse_default_cursor_shape == Control.CURSOR_MOVE)
	var catcher := _add(Button.new()) as Button
	catcher.size = Vector2(1920, 1080)
	catcher.mouse_entered.emit()
	assert(catcher.mouse_default_cursor_shape == Control.CURSOR_ARROW)
	_cleanup()


func test_pressed_toggles() -> void:
	var gc = GameCursor._inst
	assert(gc != null)
	gc._set_pressed(true)
	assert(gc._pressed)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	gc._input(up)
	assert(not gc._pressed)
	gc._set_pressed(true)
	gc._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not gc._pressed)
