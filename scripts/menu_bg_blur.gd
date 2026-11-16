extends RefCounted

## MENÜ ARKA PLANI BULANIKLIĞI (2026-11-16, kullanıcı: "ana menü haricinde bir menüdeyken (ruh dükkanı, oda kurma ekranı ve diğer
## her şey) arka plan blurlansın"). Kamp sahnesinin (menu_camp_scene.gd) ÜSTÜNE, ekranın kendi katmanlarından ÖNCE eklenen tam ekran
## katman: BackBufferCopy (o ana kadar çizilen sahneyi yeniden kopyalar) + ekran dokusunu bulanık çizen ColorRect (menu_bg_blur.gdshader).
## Kullanan: menu_hearth_bg.gd add_to (oda listesi, karakter seçimi, lobi, Ruh Mağazası) + main_menu.gd (Ayarlar / Rekorlar açıkken).
## Bağımlılığı yok (main_menu.gd de preload edebilir; menu_hearth_bg.gd'yi edemez - döngü).

const SHADER: Shader = preload("res://shaders/menu_bg_blur.gdshader")


## parent'ın SON çocuğu olarak eklenir: parent'ta ondan önce çizilen her şey bulanır, sonra eklenenler (örtü, paneller) keskin kalır.
static func add_to(parent: Control) -> Control:
	var holder := Control.new()
	holder.name = "BgBlur"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	holder.add_child(copy)
	var rect := ColorRect.new()
	rect.name = "Blur"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	holder.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return holder
