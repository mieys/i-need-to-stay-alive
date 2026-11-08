extends CanvasLayer

## Yükleme ekranının görseli bu en üst katmanda çizilir (bkz. loading_screen.gd). Oyun sahnesine geçerken bu katman
## ağacın köküne taşınır ve yeni sahnenin kurulumu (_ready) + ilk karesi (gölgelendirici derleme) boyunca ÜSTTE kalır:
## kullanıcı bildirimi (2026-09-27): "yükleme ekranı barı gerçek dolmayı yansıtmıyor doluyor ama oyun başlamıyor dolduğunda,
## tam dolduğunda başlamasını istiyorum" - çubuk %100'e, oyunun ilk karesi HAZIR olduğunda gelir; sonra katman FADE_TIME'da
## solar (2026-10-17: eskiden bir karede siliniyordu - kararmış sahneden oyuna sert kesme) ve silinir.

const FADE_TIME := 0.3
## AÇILIŞ ISINMASI (2026-11-07, kullanıcı: "oyun başladığında evde doğunca anlık drop, ilk saniyelerde FPS düşük"): katman, oyun sahnesinin
## arka plan ısınması (fx_warmup.gd shader'ları + kaynaklar, dungeon_manager.gd gizli zindan kurulumu) bitene kadar üstte kalır; o sırada
## grup "loading_overlay"dadır -> ısınma hızlı kipte çalışır, açılış saati (house_intro.gd) işlemez. Bitince SETTLE_FRAMES kare daha bekler.
## Bir şey takılırsa en çok WARM_TIMEOUT sn.
const WARM_TIMEOUT := 6.0
const SETTLE_FRAMES := 3
const FX_WARMUP_PATH := "res://scripts/fx_warmup.gd"

var _warm_t: float = 0.0
var _settle: int = -1

var progress_bar: ProgressBar = null
var _frames: int = -1


func _ready() -> void:
	layer = 128
	add_to_group(&"loading_overlay")
	process_mode = Node.PROCESS_MODE_ALWAYS ## oyun başlarken ağaç duraklatılsa da (silah seçimi) devir tamamlansın
	set_process(false)


## loading_screen.gd, sahne değişimini çağırmadan hemen önce çağırır.
func begin_handoff(bar: ProgressBar) -> void:
	progress_bar = bar
	_frames = 0
	set_process(true)


func _process(delta: float) -> void:
	if _frames < 0:
		return
	_frames += 1
	## Isınma sürerken sayaç 2. karede bekler (çubuk %97-99 arası); bitince + SETTLE_FRAMES kare sonra çubuk dolar ve katman solar.
	if _frames == 2:
		_warm_t += delta
		if is_instance_valid(progress_bar):
			progress_bar.value = minf(progress_bar.max_value - 1.0, progress_bar.value + delta * 2.0)
		if _settle < 0:
			if not _warm_finished() and _warm_t < WARM_TIMEOUT:
				_frames = 1
				return
			_settle = SETTLE_FRAMES
		if _settle > 0:
			_settle -= 1
			_frames = 1
			return
	## 1. kare: yeni sahne kuruldu ve ilk kez çiziliyor (yavaş kare). 2. kare: çubuk dolu. 3. kare: katman solmaya başlar.
	if _frames == 2 and is_instance_valid(progress_bar):
		progress_bar.value = progress_bar.max_value
		## Yüzde yazısı (madde 411) çubuğun value_changed'ini yükleme ekranı düğümünde dinliyordu - o düğüm artık silindi.
		var pct: Label = find_child("PercentLabel", true, false) as Label
		if pct:
			pct.text = "%100"
	elif _frames == 3:
		set_process(false)
		remove_from_group(&"loading_overlay")
		var tw := create_tween().set_parallel(true)
		for c: Node in get_children():
			if c is CanvasItem:
				tw.tween_property(c, "modulate:a", 0.0, FADE_TIME)
		tw.chain().tween_callback(queue_free)


func _warm_finished() -> bool:
	var fw: Script = load(FX_WARMUP_PATH) as Script
	if fw and not bool(fw.call("is_finished")):
		return false
	var tree: SceneTree = get_tree()
	var scene: Node = tree.current_scene
	if scene == null or scene.name != "Main":
		return false ## sahne henüz değişmedi
	var dm: Node = tree.get_first_node_in_group(&"dungeon_manager")
	if dm and dm.has_method("warm_done") and not bool(dm.call("warm_done")):
		return false
	return true
