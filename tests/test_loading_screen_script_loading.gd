extends Node

## Kullanıcı bildirimi (2026-10-05): "host olmama rağmen bazen yükleme ekranında kalıyor" (bar %20-30'da sonsuza dek). Kök neden: GDScript
## (player.gd, bazen main.gd) arka plan iş parçacığında derlenirken içindeki preload("...tscn") çağrıları rastgele "Could not preload
## resource file" ile başarısız oluyor ve iş parçacığı görevi sonsuza dek "devam ediyor" kalıyordu (headless ölçüm: 10 denemenin 2-3'ü).
## Düzeltme: betikler ana iş parçacığında yüklenir; doku/ses/sahne arka planda kalır + bekçi. Gerçek akış (loading_screen -> Main) burada
## değil, elle çoklu koşuyla ölçüldü (16/16 temiz); bu dosya yönlendirme kuralını (hangi tür hangi iş parçacığında) korur.

const LoadingScene: PackedScene = preload("res://scenes/loading_screen.tscn")


func _screen() -> Control:
	var s: Control = LoadingScene.instantiate()
	add_child(s)
	s.set_process(false) ## adımı elle süreceğiz
	s._scan_done = true
	s._scan_stack.clear()
	return s


## Bu süreçte henüz önbellekte olmayan, başka betiği önyüklemeyen küçük bir betik (autoload'lar ve yükleme ekranı bazılarını zaten yükledi).
func _uncached_script() -> String:
	var d := DirAccess.open("res://scripts")
	if d == null:
		return ""
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var p: String = "res://scripts/" + f
		if ResourceLoader.has_cached(p):
			continue
		var bytes: int = FileAccess.get_file_as_bytes(p).size()
		if bytes > 0 and bytes < 4000:
			return p
	return ""


func test_gdscript_is_loaded_on_the_main_thread_not_requested_in_a_worker() -> void:
	var s: Control = _screen()
	var path: String = _uncached_script()
	assert(path != "", "test önkoşulu: henüz yüklenmemiş bir betik bulunamadı")
	s._load_order = [path]
	s._weights = {path: 1.0}
	s._weight_total = 1.0
	s._step_loading(0.016)
	assert(s._req_path == "", "GDScript için arka plan isteği açılmamalı (iş parçacığında derleme takılıyordu): %s" % s._req_path)
	assert(s._load_index == 1, "betik bu adımda işlenmiş olmalı")
	assert(ResourceLoader.has_cached(path), "betik ana iş parçacığında yüklenip önbelleğe girmeli")
	assert(is_equal_approx(s._weight_done, 1.0), "ağırlığı işlenmiş sayılmalı")
	s.free()


func test_textures_still_load_in_the_background() -> void:
	var s: Control = _screen()
	var path := "res://assets/ui/loading_bg.png"
	if not ResourceLoader.exists(path) or ResourceLoader.has_cached(path):
		s.free()
		return
	s._load_order = [path]
	s._weights = {path: 1.0}
	s._weight_total = 1.0
	s._step_loading(0.016)
	assert(s._req_path == path or ResourceLoader.has_cached(path), "doku arka plan iş parçacığında istenmeli (animasyon akmaya devam etsin)")
	## Bekçi: çok eski başlamış bir istek atlanır, yükleme ilerler.
	if s._req_path != "":
		s._req_started_msec = Time.get_ticks_msec() - s.REQ_STALL_MSEC - 1000
		var st: int = ResourceLoader.load_threaded_get_status(s._req_path)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			s._step_loading(0.016)
			assert(s._req_path == "", "bekçi uzun süren isteği atlamalı")
	s.free()


## İstemci, host'un yüklemesi sürerken zaman aşımıyla ONSUZ oyuna girmemeli (host takılınca istemciler 30 sn sonra başlıyordu).
func test_client_knows_whether_the_host_finished_loading() -> void:
	var was_active: bool = NetworkManager.is_multiplayer_active
	var was_host: bool = NetworkManager.is_host
	var was_done: Dictionary = NetworkManager._loading_done.duplicate()
	NetworkManager.is_multiplayer_active = true
	NetworkManager.is_host = false
	NetworkManager._loading_done.clear()
	assert(not NetworkManager.is_host_loading_done(), "host bitirmediyse istemci beklemeli")
	NetworkManager._loading_done[NetworkManager._host_peer_id()] = true
	assert(NetworkManager.is_host_loading_done(), "host bitirince bekleme biter")
	NetworkManager.is_host = true
	NetworkManager._loading_done.clear()
	assert(NetworkManager.is_host_loading_done(), "host'un kendisi için her zaman true")
	NetworkManager.is_multiplayer_active = false
	NetworkManager.is_host = false
	assert(NetworkManager.is_host_loading_done(), "tekli oyuncuda her zaman true")
	NetworkManager.is_multiplayer_active = was_active
	NetworkManager.is_host = was_host
	NetworkManager._loading_done = was_done
