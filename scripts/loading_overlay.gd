extends CanvasLayer

## Yükleme ekranının görseli bu en üst katmanda çizilir (bkz. loading_screen.gd). Oyun sahnesine geçerken bu katman
## ağacın köküne taşınır ve yeni sahnenin kurulumu (_ready) + ilk karesi (gölgelendirici derleme) boyunca ÜSTTE kalır:
## kullanıcı bildirimi (2026-09-27): "yükleme ekranı barı gerçek dolmayı yansıtmıyor doluyor ama oyun başlamıyor dolduğunda,
## tam dolduğunda başlamasını istiyorum" - çubuk %100'e, oyunun ilk karesi HAZIR olduğunda gelir; bir kare sonra bu katman
## silinir ve oyun görünür.

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
	## 1. kare: yeni sahne kuruldu ve ilk kez çiziliyor (yavaş kare). 2. kare: çubuk dolu. 3. kare: oyun görünür.
	if _frames == 2 and is_instance_valid(progress_bar):
		progress_bar.value = progress_bar.max_value
	elif _frames >= 3:
		queue_free()
