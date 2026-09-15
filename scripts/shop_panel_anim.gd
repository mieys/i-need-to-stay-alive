extends Node
## Dükkan panelinin açılış/kapanış animasyonunu yönetir.
## Mevcut shop_panel.gd dosyasına dokunmadan çalışır.
##
## KULLANIM:
## Dükkanı açtığın yerde (şu an muhtemelen "visible = true" veya "show()" olan yerde):
##     $AnimHelper.open_shop()
## Dükkanı kapattığın yerde (şu an muhtemelen "visible = false" veya "hide()" olan yerde):
##     $AnimHelper.close_shop()
##
## Not: open_shop() paneli kendisi görünür yapar, close_shop() animasyon bitince kendisi gizler.
## Bu yüzden onları show()/hide() YERİNE çağırman yeterli.

@onready var panel: Control = get_parent()
@onready var frame: Control = panel.get_node("Frame")

var _closing := false

## DÜZELTME (kullanıcı bildirimi: "dükkan paneli açıldığında dükkan direk
## ekranın ortasında açılsın kenarda açıldığı için kullanmak çok zor
## oluyor") - shop_panel.gd _ready()'de BİR KEZ (panel ilk sahneye
## girdiğinde) ortalama denemesi zaten vardı ama bu SADECE ilk açılışı
## (ve hatta o an viewport/size henüz tam oturmamışsa onu bile) kapsardı;
## panel sürüklenebilir olduğu için (bkz. window_drag_handler.gd) bir kez
## nereye taşınırsa (ya da ilk ortalama tam oturmazsa) SONSUZA KADAR orada
## kalıyordu - her yeni "aç" bunu hiç düzeltmiyordu. Artık HER açılışta
## (viewport kesinlikle hazır olduğu bu noktada) yeniden ortalanıyor.
func open_shop() -> void:
	_closing = false
	panel.visible = true
	var vp_size: Vector2 = panel.get_viewport_rect().size
	panel.global_position = (vp_size - panel.size) * 0.5
	frame.pivot_offset = frame.size / 2.0
	frame.scale = Vector2(0.82, 0.82)
	frame.modulate.a = 0.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(frame, "scale", Vector2.ONE, 0.26)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(frame, "modulate:a", 1.0, 0.16)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func close_shop() -> void:
	if _closing:
		return
	_closing = true
	frame.pivot_offset = frame.size / 2.0

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(frame, "scale", Vector2(0.85, 0.85), 0.16)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(frame, "modulate:a", 0.0, 0.16)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		panel.visible = false
		_closing = false
		## Frame'i normale döndür - açılış hâlâ eski sistemle tetikleniyor
		## (bkz. şop_panel.gd _play_open_animation, sadece root'u animasyonluyor),
		## o yüzden Frame burada resetlenmezse bir sonraki açılışta Frame
		## küçük/saydam takılı kalıyor ve panel "kayboluyor" gibi görünüyordu.
		frame.scale = Vector2.ONE
		frame.modulate.a = 1.0
	)
