extends Node

## "Read" animasyonu: dükkan / kart seçim ekranları açıkken oyuncu karakteri okuma pozunda durur ve ekran
## KAPANANA kadar oynar (kullanıcı isteği: bitiş, kartlar/dükkan kapanınca olmalı ki animasyon görülebilsin).
##
## Ekranlar (level_up_screen, chest_menu, weapon_select_screen, merchant_shop_screen, shop_panel) kendilerini
## GROUP grubuna ekler - bu düğüm her karede o grubun içinde AÇIK bir ekran var mı diye bakar ve değişince
## oyuncunun set_reading_ui_active()'ini çağırır. Neden ayrı bir düğüm: level atlama/sandık ekranları
## get_tree().paused = true yaptığı için Player'ın kendi _physics_process'i o sırada ÇALIŞMAZ; bu düğüm
## PROCESS_MODE_ALWAYS olduğu için duraklatmada da çalışıp animasyonu başlatabilir/bitirebilir. Ekranların
## kendi kapanış kodunu (her biri farklı: queue_free, closed sinyali, visible=false) tek tek kancalamak yerine
## "ekran hâlâ açık mı"yı reaktif okur - yeni bir ekran eklerken sadece gruba eklemek yeterli.
##
## Oyuncu SADECE karakterinin SpriteFrames'inde "read_<yön>" klibi varsa bu düğümü ekler (bkz. player.gd
## _ready) - başka karakterler etkilenmez.

const GROUP := "reading_ui"

var _was_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var open: bool = _any_screen_open()
	if open == _was_open:
		return
	_was_open = open
	var player: Node = get_parent()
	if is_instance_valid(player) and player.has_method("set_reading_ui_active"):
		player.set_reading_ui_active(open)


func _any_screen_open() -> bool:
	for n in get_tree().get_nodes_in_group(GROUP):
		if is_instance_valid(n) and n.is_inside_tree() and not n.is_queued_for_deletion() and _is_shown(n):
			return true
	return false


static func _is_shown(n: Node) -> bool:
	if n is CanvasLayer:
		return (n as CanvasLayer).visible
	if n is CanvasItem:
		return (n as CanvasItem).is_visible_in_tree()
	return true
