extends RefCounted

## Sohbet kutuları için "en alta yapış" (2026-11-16). Yeni satır (fit_content + autowrap RichTextLabel) boyunu
## birkaç karede bulur; tek `process_frame` beklemesinden sonra max_value henüz büyümemiş olur ve kutu
## yukarıda kalırdı. Kaydırma çubuğunun `changed` sinyali her büyümede yeniden en alta iner; kullanıcı
## yukarı kaydırınca yapışma bırakılır, `to_end()` (yeni mesaj) onu geri açar.

const META := &"_scroll_follow_stick"


static func attach(sc: ScrollContainer) -> void:
	sc.set_meta(META, true)
	var vb: VScrollBar = sc.get_v_scroll_bar()
	vb.changed.connect(func() -> void:
		if is_instance_valid(sc) and bool(sc.get_meta(META, true)):
			sc.scroll_vertical = int(vb.max_value))
	vb.value_changed.connect(func(v: float) -> void:
		if is_instance_valid(sc):
			sc.set_meta(META, v >= vb.max_value - vb.page - 4.0))


static func to_end(sc: ScrollContainer) -> void:
	if not is_instance_valid(sc):
		return
	sc.set_meta(META, true)
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)
