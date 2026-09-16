extends Control

## Yükleme ekranı: "BAŞLAT"tan sonra ana oyun sahnesine (main.tscn) geçişte
## gösterilir. Alttaki bar, kullanıcı isteği ("yükleme barında aşağıda
## yükleme dolma barı olucak") doğrultusunda sabit bir sürede 0'dan 100'e
## dolar.
##
## NOT (mühendislik kararı): main.tscn'i ResourceLoader.load_threaded_
## request ile arka planda yükleyip GERÇEK ilerlemeyi göstermek denendi,
## ama bu projede TUTARLI ŞEKİLDE başarısız oluyor - player.gd (main.tscn'in
## bir bağımlılığı) bir arka plan iş parçacığında derlenirken güvenilir
## şekilde "Parse Error: Failed" veriyor (bkz. test: --scene ile DOĞRUDAN
## yüklemek her seferinde temiz, load_threaded_request ile SÜREKLİ
## başarısız - Godot 4.7'nin GDScript derleyicisinde iş parçacığı
## güvenliğiyle ilgili bilinen bir sınıf soruna işaret ediyor). Bu yüzden
## asıl sahne geçişi (aşağıdaki _proceed) HER ZAMAN senkron/ana iş
## parçacığında yapılıyor - bar süresi sadece görsel/zamanlanmış bir dolum.
##
## Multiplayer'da (kullanıcı isteği: "bundan sonra multiplayerda herkesin
## yükleme barı dolmadan oyun başlamamalı") yerel bar dolunca
## NetworkManager'a bildirilir; TÜM oyuncular bitirene kadar (bkz.
## NetworkManager.all_players_loading_done) burada "Diğer oyuncular
## bekleniyor..." yazısıyla beklenir, sahneye geçiş ancak o zaman
## gerçekleşir - böylece hiçbir oyuncu diğerlerinden önce oyuna düşmez.
## Bir peer donup asla haber vermezse sonsuza dek takılı kalınmaması için
## bir güvenlik zaman aşımı var.

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const FILL_DURATION := 1.4
const WAIT_FOR_OTHERS_TIMEOUT := 30.0

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var status_label: Label = $StatusLabel

var _elapsed: float = 0.0
var _local_load_done: bool = false
var _proceeded: bool = false
var _disconnected: bool = false
var _wait_elapsed: float = 0.0

var _dots_timer: float = 0.0
var _dots_count: int = 0

func _ready() -> void:
	status_label.text = "YÜKLENİYOR"
	progress_bar.value = 0.0
	NetworkManager.host_left_game.connect(_on_disconnected)
	NetworkManager.server_disconnected.connect(_on_disconnected)


func _process(delta: float) -> void:
	if _proceeded or _disconnected:
		return

	if not _local_load_done:
		_elapsed += delta
		var ratio: float = clamp(_elapsed / FILL_DURATION, 0.0, 1.0)
		progress_bar.value = ratio * 100.0
		
		_dots_timer += delta
		if _dots_timer >= 0.3:
			_dots_timer = 0.0
			_dots_count = (_dots_count + 1) % 4
			status_label.text = "YÜKLENİYOR" + ".".repeat(_dots_count)
			
		if ratio >= 1.0:
			_local_load_done = true
			NetworkManager.mark_local_loading_done()
		return

	if NetworkManager.is_multiplayer_active and not NetworkManager.all_players_loading_done():
		_wait_elapsed += delta
		
		_dots_timer += delta
		if _dots_timer >= 0.4:
			_dots_timer = 0.0
			_dots_count = (_dots_count + 1) % 4
			status_label.text = "DİĞER OYUNCULAR BEKLENİYOR" + ".".repeat(_dots_count)
			
		if _wait_elapsed >= WAIT_FOR_OTHERS_TIMEOUT:
			push_warning("[LoadingScreen] Diğer oyuncular %.0f sn içinde hazır olmadı, yine de devam ediliyor." % WAIT_FOR_OTHERS_TIMEOUT)
			_proceed()
		return

	_proceed()


func _proceed() -> void:
	_proceeded = true
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_disconnected() -> void:
	if _proceeded or _disconnected:
		return
	_disconnected = true
	status_label.text = "BAĞLANTI KESİLDİ. ANA MENÜYE DÖNÜLÜYOR..."
	var timer: SceneTreeTimer = get_tree().create_timer(1.6)
	timer.timeout.connect(func():
		if is_inside_tree():
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
