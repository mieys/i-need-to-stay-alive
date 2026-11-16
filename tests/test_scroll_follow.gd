extends Node

## Lobi / karakter seçimi sohbeti en alta yapışır (scroll_follow.gd, 2026-11-16): autowrap RichTextLabel boyunu
## birkaç karede bulduğu için tek kare beklemesi yetmiyordu, kutu yukarıda kalıyordu.

const ScrollFollow: GDScript = preload("res://scripts/scroll_follow.gd")


func _line(t: String) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text = t
	return l


func _at_bottom(sc: ScrollContainer) -> bool:
	var vb := sc.get_v_scroll_bar()
	return sc.scroll_vertical >= int(vb.max_value - vb.page) - 1


func test_new_lines_stick_to_bottom_until_user_scrolls_up() -> void:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size = Vector2(200, 80)
	var log := VBoxContainer.new()
	log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(log)
	add_child(sc)
	ScrollFollow.attach(sc)
	for i in 12:
		log.add_child(_line("satir %d uzun bir mesaj ki sarmasi gereksin bir iki satira" % i))
		ScrollFollow.to_end(sc)
	for _f in 6:
		await get_tree().process_frame
	assert(sc.get_v_scroll_bar().max_value > 80.0, "icerik tasmali")
	assert(_at_bottom(sc), "yeni satirlarla en alta inmeli: %d / %s" % [sc.scroll_vertical, sc.get_v_scroll_bar().max_value])
	## Kullanıcı yukarı kaydırdı -> gelen satır büyüse de yerinde kalır; to_end (yeni mesaj) yine indirir.
	sc.scroll_vertical = 0
	await get_tree().process_frame
	log.add_child(_line("kaydirma bozulmamali"))
	for _f in 4:
		await get_tree().process_frame
	assert(sc.scroll_vertical == 0, "yukari kaydiran kullanici zorla indirilmemeli")
	ScrollFollow.to_end(sc)
	log.add_child(_line("yeni mesaj gelince yine en alta"))
	for _f in 4:
		await get_tree().process_frame
	assert(_at_bottom(sc))
	sc.queue_free()
