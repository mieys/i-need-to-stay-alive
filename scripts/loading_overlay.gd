extends CanvasLayer

## Yükleme ekranının görseli bu en üst katmanda çizilir (bkz. loading_screen.gd). Oyun sahnesine geçerken bu katman
## ağacın köküne taşınır ve yeni sahnenin kurulumu (_ready) + ilk karesi (gölgelendirici derleme) boyunca ÜSTTE kalır:
## kullanıcı bildirimi (2026-09-27): "yükleme ekranı barı gerçek dolmayı yansıtmıyor doluyor ama oyun başlamıyor dolduğunda,
## tam dolduğunda başlamasını istiyorum" - çubuk %100'e, oyunun ilk karesi HAZIR olduğunda gelir; sonra katman FADE_TIME'da
## solar (2026-10-17: eskiden bir karede siliniyordu - kararmış sahneden oyuna sert kesme) ve silinir.

const FADE_TIME := 0.3

var progress_bar: ProgressBar = null
var _frames: int = -1


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS ## oyun başlarken ağaç duraklatılsa da (silah seçimi) devir tamamlansın
	set_process(false)


## loading_screen.gd, sahne değişimini çağırmadan hemen önce çağırır.
func begin_handoff(bar: ProgressBar) -> void:
	progress_bar = bar
	_frames = 0
	set_process(true)


func _process(_delta: float) -> void:
	if _frames < 0:
		return
	_frames += 1
	## 1. kare: yeni sahne kuruldu ve ilk kez çiziliyor (yavaş kare). 2. kare: çubuk dolu. 3. kare: katman solmaya başlar.
	if _frames == 2 and is_instance_valid(progress_bar):
		progress_bar.value = progress_bar.max_value
	elif _frames == 3:
		set_process(false)
		var tw := create_tween().set_parallel(true)
		for c: Node in get_children():
			if c is CanvasItem:
				tw.tween_property(c, "modulate:a", 0.0, FADE_TIME)
		tw.chain().tween_callback(queue_free)
