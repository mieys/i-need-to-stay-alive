extends Node

## Yükleme ekranı akışı. Geçmiş (bkz. loading_screen.gd başı):
## - 2026-10-05 "host olmama rağmen bazen yükleme ekranında kalıyor": WorkerThreadPool'da (load_threaded_request) derlenen player.gd
##   görevi aralıklı olarak sonsuza dek "devam ediyor" kalıyordu. Geçici çözüm betikleri ana iş parçacığında derlemekti -> donmalar.
## - 2026-10-17 "yüklenirken animasyonlar donmasın": 4.7.2'de WorkerThreadPool hâlâ kilitleniyor (12 denemenin 3'ü), KENDİ Thread'imizde
##   düz ResourceLoader.load 15/15 temiz ve yükleme boyunca uzun kare yok. Gerçek akış (loading_screen -> Main) burada değil, elle çoklu
##   süreçle ölçüldü; bu dosya kuralları korur: tek özel Thread, WorkerThreadPool yok, plan sırası, durdurma, Sade görünüş (madde 411).

const LoadingScene: PackedScene = preload("res://scenes/loading_screen.tscn")
const LoadingScript: GDScript = preload("res://scripts/loading_screen.gd")
const HudTheme := preload("res://scripts/hud_theme.gd")
const ShopsFlag := preload("res://scripts/shops_flag.gd")
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


## Görünüş "Sade" (madde 411): düz koyu zemin, resim/ışık yok; yazılar stil rehberi boylarında; ipucu havuzdan; yüzde çubuğu izler.
func test_sade_screen_is_built() -> void:
	var s: Control = _screen()
	var bg: ColorRect = s.find_child("Background", true, false) as ColorRect
	assert(bg != null and bg.color == HudTheme.DEEP, "zemin düz DEEP olmalı")
	for c: Node in s.find_children("*", "TextureRect", true, false):
		assert(false, "arka plan resmi kalmamalı: %s" % c.name)
	assert(s.status_label.get_theme_font_size("font_size") == 48, "durum yazısı m5x7 48")
	var tip: Label = s.find_child("TipLabel", true, false) as Label
	assert(tip != null and s.tip_pool().has(tip.text), "ipucu havuzdan: %s" % (tip.text if tip else "yok"))
	assert(tip.get_theme_font_size("font_size") == 32, "ipucu m5x7 32")
	s.progress_bar.value = 42.0
	assert(s._pct_label.text == "%42", "yüzde çubuğu izler: %s" % s._pct_label.text)
	assert(s._party.size() == 1 and s._party[0].animation == &"walk_right", "tek oyunculuda yerel karakter yürür")
	s.free()


## Parti sırası: yerel oyuncu önce (en önde), diğerleri peer kimliği sırasıyla; tek oyunculuda yalnız yerel.
func test_party_order_puts_local_player_first() -> void:
	var lobby := {5: {"char_id": 7}, 1: {"char_id": 3}, 3: {"char_id": 4}, 9: {"name": "kimliksiz"}}
	var got: Array[int] = LoadingScript.party_chars(2, lobby, 5, true)
	assert(got == [2, 3, 4], "yerel + lobi sırası: %s" % str(got))
	assert(LoadingScript.party_chars(2, lobby, 5, false) == [2], "tek oyunculu: yalnız yerel")


## Seyyar satıcı kapalıyken (madde 389) satıcı ipucu çıkmaz; açılınca geri gelir (demirci bayrağından bağımsız, madde 431).
func test_shop_tip_follows_shops_flag() -> void:
	var was: bool = ShopsFlag.merchant_enabled
	ShopsFlag.set_merchant_enabled(false)
	assert(not LoadingScript.tip_pool().has(LoadingScript.SHOP_TIP), "satıcı kapalıyken ipucu yok")
	ShopsFlag.set_merchant_enabled(true)
	assert(LoadingScript.tip_pool().has(LoadingScript.SHOP_TIP), "satıcı açıkken ipucu var")
	ShopsFlag.set_merchant_enabled(was)


## Varışta parti durur (idle_right) ve ayağı aynı satırda kalır (donma duran karede geçer).
func test_arrive_stops_the_party_on_its_feet() -> void:
	var s: Control = _screen()
	var sp: AnimatedSprite2D = s._party[0]
	var foot: Vector2 = sp.get_meta("foot")
	s._stop_party()
	assert(sp.animation == &"idle_right", "parti durmalı: %s" % sp.animation)
	var bottom: float = sp.position.y + LoadingScript._foot_offset(sp.sprite_frames.get_frame_texture(&"idle_right", 0)) * sp.scale.y
	assert(absf(bottom - foot.y) <= 1.0, "ayak yerinde: %f vs %f" % [bottom, foot.y])
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
