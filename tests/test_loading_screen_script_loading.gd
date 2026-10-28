extends Node

## Yükleme ekranı akışı. Geçmiş (bkz. loading_screen.gd başı):
## - 2026-10-05 "host olmama rağmen bazen yükleme ekranında kalıyor": WorkerThreadPool'da (load_threaded_request) derlenen player.gd
##   görevi aralıklı olarak sonsuza dek "devam ediyor" kalıyordu. Geçici çözüm betikleri ana iş parçacığında derlemekti -> donmalar.
## - 2026-10-17 "yüklenirken animasyonlar donmasın": 4.7.2'de WorkerThreadPool hâlâ kilitleniyor (12 denemenin 3'ü), KENDİ Thread'imizde
##   düz ResourceLoader.load 15/15 temiz ve yükleme boyunca uzun kare yok. Gerçek akış (loading_screen -> Main) burada değil, elle çoklu
##   süreçle ölçüldü; bu dosya kuralları korur: tek özel Thread, WorkerThreadPool yok, plan sırası, durdurma, sahne parçaları.

const LoadingScene: PackedScene = preload("res://scenes/loading_screen.tscn")
const LoadingScript: GDScript = preload("res://scripts/loading_screen.gd")
const SceneParts := preload("res://scripts/loading_scene_parts.gd")
## Küçük bir sahne (betik + doku bağımlılığı): yükleyiciyi main.tscn yerine bununla koşarız.
const SMALL_SCENE := "res://scenes/fx_shield_active.tscn"


func _screen() -> Control:
	var s: Control = LoadingScene.instantiate()
	s.autostart_loader = false
	add_child(s)
	s.set_process(false) ## ilerlemeyi elle okuyacağız
	return s


func _wait_loader(s: Control, limit_msec: int = 20000) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not s._loader_finished():
		if Time.get_ticks_msec() - t0 > limit_msec:
			return false
		OS.delay_msec(5)
	s._join_loader()
	return true


## WorkerThreadPool'a geri dönülmesin: 4.7.2'de betik derlemesi orada aralıklı kilitleniyor (yukarıdaki ölçüm).
func test_loader_never_uses_the_worker_thread_pool() -> void:
	var src: String = LoadingScript.source_code
	assert(src != "", "test önkoşulu: betik kaynağı okunabilmeli")
	assert(not src.contains("load_threaded_request("), "yükleme ekranı load_threaded_request KULLANMAMALI (WorkerThreadPool kilidi)")
	assert(src.contains("Thread.new()"), "yükleme kendi Thread'inde yapılmalı")


func test_worker_loads_the_scene_and_its_dependencies_in_its_own_thread() -> void:
	var s: Control = _screen()
	s.main_scene_path = SMALL_SCENE
	s.start_loader()
	assert(_wait_loader(s), "yükleyici iş parçacığı bitmeli (takılma yok)")
	var found: bool = false
	for r: Resource in s._loaded_refs:
		if r is PackedScene and r.resource_path == SMALL_SCENE:
			found = true
	assert(found, "kök sahne iş parçacığında yüklenip referansta tutulmalı")
	assert(ResourceLoader.has_cached(SMALL_SCENE), "kök sahne önbellekte olmalı (_proceed oradan alır)")
	assert(is_equal_approx(s._load_progress(), 1.0), "iş parçacığı bitince ilerleme %100")
	assert(s._t_scan_done, "tarama tamamlanmış olmalı")
	s.free()


func test_abort_stops_the_worker_before_loading() -> void:
	var s: Control = _screen()
	s.main_scene_path = SMALL_SCENE
	s._abort = true
	s.start_loader()
	assert(_wait_loader(s, 5000), "durdurulan yükleyici hemen bitmeli")
	assert(s._loaded_refs.is_empty(), "durdurulunca hiçbir şey yüklenmemeli")
	s.free()


## Sahneden çıkılırsa (bağlantı kesildi -> menü) iş parçacığı beklenir; Thread yıkılırken çalışıyor olmamalı.
func test_exit_tree_joins_the_worker() -> void:
	var s: Control = _screen()
	s.main_scene_path = SMALL_SCENE
	s.start_loader()
	remove_child(s)
	assert(s._thread == null, "_exit_tree iş parçacığını beklemeli")
	s.free()


func test_load_plan_puts_leaves_first_and_root_scripts_last() -> void:
	var order: Array = ["res://root.tscn", "res://main.gd", "res://a.tscn", "res://a.gd", "res://b.png"]
	var plan: Array = LoadingScript.load_plan(order, ["res://main.gd"], "res://root.tscn")
	assert(not plan.has("res://root.tscn"), "kök sahne planda olmamalı (en son ayrıca yüklenir)")
	assert(plan[0] == "res://b.png", "yapraklar önce: %s" % str(plan))
	assert(plan[plan.size() - 1] == "res://main.gd", "kök betik en sona: %s" % str(plan))
	assert(plan.size() == 4, "hiçbir bağımlılık düşmemeli")


## Canlı sahne parçaları (üretici tools/gen_yukleme_bg.py yazar) dokularıyla uyumlu olmalı: şerit genişliği = kare x kare sayısı.
func test_scene_parts_match_their_sheets() -> void:
	var bg: Texture2D = load("res://assets/ui/yukleme/yukleme_bg.png")
	assert(bg != null, "arka plan dokusu yok")
	assert(Vector2(bg.get_size()) == SceneParts.CANVAS, "arka plan tuvali %s olmalı" % str(SceneParts.CANVAS))
	assert(SceneParts.PARTS.size() > 0, "canlı parça yok")
	for p: Array in SceneParts.PARTS:
		var tex: Texture2D = load("res://assets/ui/yukleme/" + str(p[0]))
		assert(tex != null, "parça dokusu yok: %s" % p[0])
		var fs: Vector2 = p[2]
		assert(tex.get_width() == int(fs.x) * int(p[3]) and tex.get_height() == int(fs.y), "şerit boyutu uyuşmuyor: %s" % p[0])


## Yükleme ekranı kurulduğunda arka plan + canlı parçalar tek tuvalde, patika (çubuk) yolun üstünde.
func test_backdrop_is_built_on_the_scene_canvas() -> void:
	var s: Control = _screen()
	assert(is_instance_valid(s._scene), "sahne tuvali kurulmalı")
	assert(s._scene.size == SceneParts.CANVAS, "tuval boyutu")
	var sheets: int = 0
	for c: Node in s._scene.get_children():
		if c is TextureRect:
			var path: String = (c as TextureRect).texture.resource_path
			assert(path.ends_with("yukleme_bg.png") or path.ends_with(SceneParts.LIGHT), "arka plan / kapı ışığı olmalı: %s" % path)
		elif c.get_class() == "Control" and c.get("frame_size") != null:
			sheets += 1
	assert(sheets == SceneParts.PARTS.size(), "her canlı parça bir LiveSheet: %d" % sheets)
	s.free()


## Mühürlü Kapı (madde 370): kapının ışığı ve halesi ilerlemeyle güçlenir; ışık toplamalı; başlık oyundaki kapı sezdirmesi.
func test_gate_glow_follows_progress() -> void:
	var s: Control = _screen()
	assert(is_instance_valid(s._gate_light) and is_instance_valid(s._gate_fx), "kapı ışığı + halesi kurulmalı")
	assert((s._gate_light.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "ışık toplamalı")
	assert(s._gate_light.texture.get_size() == SceneParts.CANVAS, "ışık katmanı tuval boyunda")
	s._update_gate_glow(0.0)
	var a0: float = s._gate_light.self_modulate.a
	assert(is_equal_approx(a0, s.LIGHT_MIN) and s._gate_fx.boost == 0.0, "başta sönük: %f" % a0)
	s._update_gate_glow(1.0)
	assert(is_equal_approx(s._gate_light.self_modulate.a, 1.0) and s._gate_fx.boost == 1.0, "sonda tam")
	assert(Rect2(Vector2.ZERO, SceneParts.CANVAS).has_point(SceneParts.GATE_MOUTH), "kapı ağzı tuvalde")
	var title: Label = s.find_child("GateTitle", true, false) as Label
	assert(title != null and title.text == "KEMİK MAHZENİ", "başlık kapının adı")
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
