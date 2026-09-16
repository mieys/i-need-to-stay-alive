## Kullanıcı isteği: "gamepad desteği ekle... eksik birşeyin olmamasını
## istiyorum" - menü ekranlarının odak (focus) gezinmesi için PAYLAŞILAN,
## TEK kaynak yardımcı fonksiyonlar. weapon_orbit_math.gd/talon_formation_
## math.gd ile AYNI desen (class_name + saf static func'lar, RefCounted) -
## her ekran kendi kopyasını yazmak yerine bunu çağırır.
class_name GamepadFocusHelper
extends RefCounted

## Projede zaten kullanılan aynı vurgu tonu (bkz. keybind_menu.gd/
## party_panel.gd/merchant_shop_screen.gd PAL_ACCENT) - odak halkası da AYNI
## dili konuşsun diye.
const FOCUS_RING_COLOR := Color(0.83, 0.56, 0.30, 1.0)


## Button OLMAYAN (PanelContainer vb.) Control'ler için: Button'ın aksine
## bunlar "focus" stilini kendiliğinden ÇİZMEZ (motor sadece BaseButton için
## bunu otomatik yapar) - bu yüzden ayrı, sadece kenarlık çizen bir çocuk
## Control ekleyip focus_entered/exited ile açıp kapatıyoruz. shop_panel.gd
## _refresh_selection_highlight()'ın "panel" StyleBoxFlat swap'ından
## (seçili/seçili değil) TAMAMEN bağımsız bir katman - odaklı-ama-seçili-
## değil durumunu bozmuyor.
static func add_focus_ring(control: Control, thickness: int = 3) -> void:
	if not is_instance_valid(control):
		return
	var ring := Panel.new()
	ring.name = "GamepadFocusRing"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.visible = control.has_focus()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.draw_center = false
	sb.set_border_width_all(thickness)
	sb.border_color = FOCUS_RING_COLOR
	sb.set_corner_radius_all(6)
	ring.add_theme_stylebox_override("panel", sb)
	control.add_child(ring)
	control.focus_entered.connect(func(): if is_instance_valid(ring): ring.visible = true)
	control.focus_exited.connect(func(): if is_instance_valid(ring): ring.visible = false)


## Bir ekran açılırken "ilk odak" bu Control'e verilir - gamepad/klavye
## kullanıcısı hiçbir şeye tıklamadan direkt ui_up/down/ui_accept ile
## gezinebilsin diye. control geçersiz/görünmezse no-op (güvenli).
static func grab_initial_focus(control: Control) -> void:
	if control and is_instance_valid(control) and control.visible:
		control.grab_focus()


## Bir Control dizisini dikey (yukarı/aşağı) dairesel bir odak zincirine
## bağlar - Godot'un otomatik uzamsal odak aramasının şaşırabileceği
## (örtüşen/karmaşık) düzenlerde elle kullanılır. Basit VBoxContainer'larda
## genelde gerek yoktur (motor zaten doğru sırayı buluyor) ama garantili
## davranış için tercih edilebilir.
static func chain_vertical(controls: Array) -> void:
	var n: int = controls.size()
	if n < 2:
		return
	for i in range(n):
		var cur: Control = controls[i]
		if not is_instance_valid(cur):
			continue
		var prev: Control = controls[(i - 1 + n) % n]
		var next: Control = controls[(i + 1) % n]
		if is_instance_valid(prev):
			cur.focus_neighbor_top = cur.get_path_to(prev)
			cur.focus_previous = cur.get_path_to(prev)
		if is_instance_valid(next):
			cur.focus_neighbor_bottom = cur.get_path_to(next)
			cur.focus_next = cur.get_path_to(next)


## chain_vertical ile AYNI mantık, yatay (sol/sağ) diziler için (ör. bir
## popup'taki yan yana duran birkaç buton).
static func chain_horizontal(controls: Array) -> void:
	var n: int = controls.size()
	if n < 2:
		return
	for i in range(n):
		var cur: Control = controls[i]
		if not is_instance_valid(cur):
			continue
		var prev: Control = controls[(i - 1 + n) % n]
		var next: Control = controls[(i + 1) % n]
		if is_instance_valid(prev):
			cur.focus_neighbor_left = cur.get_path_to(prev)
			cur.focus_previous = cur.get_path_to(prev)
		if is_instance_valid(next):
			cur.focus_neighbor_right = cur.get_path_to(next)
			cur.focus_next = cur.get_path_to(next)
