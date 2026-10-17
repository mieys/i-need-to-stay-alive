extends Node

## madde 200: arayüz animasyonları (scripts/ui_anim.gd). Her animasyon bitince düğüm TAM eski hâlinde olmalı (ölçek 1,
## pivot eski, alfa eski, katman ölçeği/ofseti eski) - kalıcı ölçek piksel yazıyı bulanıklaştırır (madde 144). İşaretli
## (skip), başkasının ölçeklediği ve ayar kapalıyken düğmelere dokunulmaz.

const UiAnim := preload("res://scripts/ui_anim.gd")

var _prev_enabled: bool = true
var _nodes: Array[Node] = []


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _add(n: Node) -> Node:
	add_child(n)
	_nodes.append(n)
	return n


func _button() -> Button:
	var b := Button.new()
	b.text = "DENEME"
	_add(b)
	b.size = Vector2(200, 56)
	return b


func _cleanup() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	UISound.ui_anim_enabled = _prev_enabled


func test_button_hover_and_press_restore() -> void:
	_prev_enabled = UISound.ui_anim_enabled
	UISound.ui_anim_enabled = true
	var b := _button()
	b.pivot_offset = Vector2(3, 4)
	assert(b.has_meta(UiAnim.META_HOOKED), "düğme ağaca girince otomatik bağlanmalı")
	b.mouse_entered.emit()
	await _wait(0.05)
	assert(b.scale.x > 1.0, "fare üstüne gelince düğme hafifçe büyümeli: %s" % b.scale)
	assert(b.pivot_offset.is_equal_approx(b.size * 0.5), "nefes düğmenin ortasından olmalı")
	await _wait(0.5)
	assert(b.scale.is_equal_approx(Vector2.ONE), "nefes bitince ölçek tam 1 olmalı: %s" % b.scale)
	assert(b.pivot_offset.is_equal_approx(Vector2(3, 4)), "eski pivot geri konmalı: %s" % b.pivot_offset)
	assert(not b.has_meta(UiAnim.META_TW) and not b.has_meta(UiAnim.META_SHINE), "iz bırakmamalı")
	b.button_down.emit()
	await _wait(0.03)
	assert(b.scale.x < 1.0, "basınca düğme çökmeli: %s" % b.scale)
	await _wait(0.4)
	assert(b.scale.is_equal_approx(Vector2.ONE), "basma bitince ölçek tam 1 olmalı: %s" % b.scale)
	_cleanup()


func test_skip_foreign_scale_and_disabled_setting() -> void:
	_prev_enabled = UISound.ui_anim_enabled
	UISound.ui_anim_enabled = true
	var box := _add(Control.new()) as Control
	UiAnim.skip(box)
	var inner := Button.new()
	box.add_child(inner)
	inner.size = Vector2(200, 56)
	inner.mouse_entered.emit()
	var scaled := _button()
	scaled.scale = Vector2(0.8, 0.8) ## başka bir animasyonun (kart girişi, mobil ölçek) elinde
	scaled.mouse_entered.emit()
	scaled.button_down.emit()
	UISound.ui_anim_enabled = false
	var off := _button()
	off.mouse_entered.emit()
	off.button_down.emit()
	await _wait(0.05)
	assert(inner.scale.is_equal_approx(Vector2.ONE), "atası işaretli düğme oynamamalı")
	assert(scaled.scale.is_equal_approx(Vector2(0.8, 0.8)), "başkasının ölçeğine dokunulmamalı: %s" % scaled.scale)
	assert(off.scale.is_equal_approx(Vector2.ONE), "ayar kapalıyken oynamamalı")
	_cleanup()


func test_cascade_window_and_slide_restore() -> void:
	_prev_enabled = UISound.ui_anim_enabled
	UISound.ui_anim_enabled = true
	var v := _add(VBoxContainer.new()) as VBoxContainer
	var alphas: Array[float] = [1.0, 0.5, 0.8]
	for a: float in alphas:
		var l := Label.new()
		l.text = "satır"
		l.modulate.a = a
		v.add_child(l)
	UiAnim.cascade(v)
	assert(is_zero_approx(v.get_child(0).modulate.a), "satır saydamdan başlamalı")
	UiAnim.cascade(v) ## animasyon sürerken ikinci çağrı 0'ı asıl alfa sanmamalı
	var layer := _add(CanvasLayer.new()) as CanvasLayer
	layer.scale = Vector2(0.9, 0.9)
	layer.offset = Vector2(10, 20)
	var dim := ColorRect.new()
	dim.modulate.a = 0.62
	layer.add_child(dim)
	UiAnim.window_in(layer)
	var panel := _add(Control.new()) as Control
	panel.size = Vector2(400, 300)
	UiAnim.window_in(panel)
	var row := Control.new()
	panel.add_child(row)
	UiAnim.slide_x(row, 12.0)
	await _wait(0.06)
	assert(not layer.scale.is_equal_approx(Vector2(0.9, 0.9)), "pencere katmanı yerine oturuyor olmalı")
	await _wait(0.7)
	for i: int in alphas.size():
		assert(is_equal_approx(v.get_child(i).modulate.a, alphas[i]), "satır %d asıl alfasına dönmeli: %s" % [i, v.get_child(i).modulate.a])
	assert(layer.scale.is_equal_approx(Vector2(0.9, 0.9)) and layer.offset.is_equal_approx(Vector2(10, 20)), \
			"katmanın ölçeği/ofseti eski hâline dönmeli: %s %s" % [layer.scale, layer.offset])
	assert(is_equal_approx(dim.modulate.a, 0.62), "pencere çocuğu asıl alfasına dönmeli")
	assert(panel.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(panel.modulate.a, 1.0), "Control pencere tam yerinde")
	assert(is_equal_approx(row.position.x, 12.0), "kaydırma hedefe varmalı: %s" % row.position.x)
	_cleanup()


## Seçim değişince ayrıntı paneli (reveal) ve geciktirilmiş liste girişi (cascade delay): hepsi asıl alfasına dönmeli, art arda reveal yarışmamalı.
func test_reveal_and_cascade_delay_restore() -> void:
	_prev_enabled = UISound.ui_anim_enabled
	UISound.ui_anim_enabled = true
	var p := _add(Control.new()) as Control
	p.modulate.a = 0.8
	UiAnim.reveal(p, 0.25, 0.1)
	assert(p.modulate.a < 0.8, "reveal düşük alfadan başlamalı: %s" % p.modulate.a)
	UiAnim.reveal(p, 0.25, 0.1) ## animasyon sürerken ikinci çağrı yarım alfayı asıl sanmamalı
	var row := _add(HBoxContainer.new()) as HBoxContainer
	for i in 3:
		row.add_child(Label.new())
	UiAnim.cascade(row, 0.03, 8, 0.2)
	assert(is_zero_approx(row.get_child(2).modulate.a), "geciktirilen satır da saydamdan başlamalı")
	await _wait(0.8)
	assert(is_equal_approx(p.modulate.a, 0.8), "reveal asıl alfaya dönmeli: %s" % p.modulate.a)
	for c: Node in row.get_children():
		assert(is_equal_approx((c as CanvasItem).modulate.a, 1.0), "gecikmeli giriş sonunda tam görünür olmalı")
	_cleanup()
