extends SceneTree

## KARAKTER TANITIM KLİPLERİ (2026-11-14, kullanıcı isteği): her karakter temasına uygun haritada, ekrana bakan idle pozunda; sağda Q/E/R/pasif
## ikonları + İngilizce adları. GERÇEK Main (harita gölgelendiricileri, ağaç sallanması, su, hava) - HUD gizlenir, oyuncu işlemesi durdurulur.
## Koşturucu: karakter_klip_run.ps1 (gizli masaüstü, APPDATA yalıtılır, --fixed-fps 30).
##   KK_MODE=survey  KK_MAPS="ana,bataklik,..."  -> her haritanın kuşbakışı + koordinat ızgarası (survey_<harita>.png)
##   KK_MODE=clip    [KK_ONLY="1,3"] [KK_STILL=1] [KK_SPEC="id:harita:x:y;..."] -> <id>/f_0000.jpg... (KK_STILL=1: tek kare still_<id>.png)
##   KK_MODE=weapon  [KK_ONLY="dagger,kalkan"] [KK_STILL=1] [KK_SEED=n] -> SİLAH KLİPLERİ (2026-11-14 ikinci istek): her silah, temasına uyan
##                   karakter havuzundan rastgele (dengeli) bir karakterle, o karakterin harita noktasında; yakında 3 hareketsiz ölümsüz hedef, silah
##                   gerçekten saldırır. Kalkan: soldaki büyücü yaratıktan gelen mermileri siper duruşuyla bloklar (madde 685), sonra yanına gelen
##                   hedefi döver. Çıktı <NN>_<Silah>_<Karakter>/f_*.jpg.
## Ortak: KK_DIR çıktı klasörü, KK_ZOOM kamera yakınlığı (tamsayı; karakter pikseli tam ekran pikseline yuvarlanır).

const FPS := 30
const CLIP_SEC := 6.0
const WARM_FRAMES := 75
const SCREEN := Vector2(1920, 1080)

## id -> [harita, x, y, saat (cycle_time sn; 0-330 gündüz, 330-390 gün batımı), hava]   x < 0: evden çıkış noktası.
## Yer işaretleri tools/<harita>/gen_*.py REGIONS'tan (dünya = (yerel hücre + (32, 20)) x 16 + 8); karakter yer işaretinin sağ önünde
## (sağ taraf panelin altında kalır). KK_SPEC ile ezilebilir.
const SPOTS := {
	1: ["ana", -1.0, -1.0, 150.0, 0], ## Talon: ana harita, ev önü (oyunun başladığı yer)
	2: ["ana", 1850.0, 2250.0, 150.0, 0], ## Oakley: çiçekli çayır
	3: ["kis", 3940.0, 1075.0, 150.0, 0], ## Matthew: Kristal Vadisi
	4: ["col", 1225.0, 1010.0, 150.0, 0], ## Lyra: Küre Tapınağı
	5: ["bataklik", 3600.0, 1640.0, 365.0, 0], ## Kestrel: ölü orman, gün batımı
	7: ["kis", 4160.0, 4000.0, 150.0, 0], ## Aldric: Eski Harabe
	8: ["ana", 1453.0, 2090.0, 150.0, 0], ## Elara: göl köprüsü
	9: ["col", 3150.0, 3560.0, 150.0, 0], ## Flint: Büyük Vaha kıyısı
	10: ["kis", 2795.0, 2300.0, 150.0, 0], ## Seraphine: Kadim Buz Ağacı
	11: ["bataklik", 2500.0, 3280.0, 150.0, 0], ## Corvina: kemik tarlası
	12: ["kis", 1185.0, 995.0, 150.0, 0], ## Ulric: Ayı Totemi Tapınağı
	13: ["batik_nekropol", 1745.0, 1680.0, 150.0, 0], ## Nox: nekropol
	14: ["col", 2215.0, 2300.0, 150.0, 0], ## Hadime: Firavun Vadisi
	15: ["bataklik", 1090.0, 950.0, 150.0, 0], ## Hazel: cadı oyuğu
}

## Silah kliplerinde KULLANILMAYAN karakterler (kullanıcı 2026-11-15: "necromancerı kullanma bu testlerde").
const WEAPON_EXCLUDED_CHARS := [11]
## Silah -> temasına uyan karakterler (silah modunda bunlardan rastgele, kullanım sayısı en az olanlar arasından, art arda aynı karakter olmadan).
const WEAPON_POOLS := {
	"dagger": [5, 13, 1], "fire_staff": [4, 12, 15], "lightning_staff": [3, 4, 12], "tabanca": [8, 9, 1], "tuftuf": [15, 2],
	"tufek": [8, 1, 9], "arcane": [4, 10, 15], "yay": [8, 2, 5], "crossbow": [5, 1, 7], "boomerang": [5, 3, 1], "buz_asasi": [4, 10, 14],
	"fisek": [9, 1], "pence": [14, 13], "topuz": [7, 12, 1], "uzunkilic": [7, 1, 10], "gokkusagi": [2, 10, 4], "mizrak": [7, 12, 1],
	"kalkan": [7, 10], "yinyang": [14, 4, 10], "pompali": [9, 1, 8], "makineli": [1, 8, 9],
}
## Silah modunda nokta değişikliği: hedefler suya / dekorun arkasına düşmesin (Elara köprüsü -> ana harita çayırı, Flint kumsala,
## Ulric totemlerin altına).
const WEAPON_SPOT_OVERRIDE := {
	8: ["ana", 2600.0, 2560.0, 150.0, 0],
	9: ["col", 3150.0, 3604.0, 150.0, 0],
	12: ["kis", 1185.0, 1035.0, 150.0, 0],
}
## Hedefler oyuncuya göre (dünya birimi; yakın dövüş menzili ~55): sağ, sol, alt - sudan kaçınmak için yukarı yok.
const TARGET_OFFSETS := [Vector2(48, 6), Vector2(-44, 14), Vector2(4, 46)] ## (eski duran hedefler; kaçış modunda kullanılmıyor)
## KAÇIŞ (kullanıcı 2026-11-15: "karakterler sabit duruyor, yaratıklardan kaçıyormuş gibi görünmeli"): karakter koşar (gerçek hareket girdisi,
## engelden kaçan yönlendirme), arkasından ölümsüz yaratıklar kovalar, silahlar onlara ateş eder. Kovalayanlar oyuncudan biraz yavaş (CHASE_K).
## Kovalayanlar HARİTAYA göre (kullanıcı 2026-11-15: "hep aynı yaratıklar olmasın"): her klip kendi haritasının havuzundan tohumlu rastgele 3-4 tür
## seçer. Gerçek canla (ölürler -> öldürmeyle tetiklenen silah özellikleri çalışır), azaldıkça arkadan yenisi gelir (ALIVE_TARGET).
const MAP_MELEE := {
	"ana": ["slime1", "goblin1", "gnoll1", "rat1", "mantar1", "ork1", "zombie1", "agac1"],
	"bataklik": ["pelte1", "zombie1", "mantar1", "kertenkele1", "hayalet1", "slime2", "rat1"],
	"col": ["kertenkele1", "iskelet1", "golem1", "rat1", "goblin1", "zombie1"],
	"kis": ["iskelet1", "gnoll1", "ork1", "golem1", "hayalet1", "yarasa1", "goblin1"],
	"batik_nekropol": ["iskelet1", "zombie1", "hayalet1", "yarasa1", "vampire1", "rat1"],
}
## Gerçek menzilli yaratıklar (is_ranged = true; kendi mermilerini atar): Kalkan klibinde bunlar ateş eder, kalkan bloklar.
const RANGED_CREATURES := ["rontgen1", "demon1", "iblis1"]
const ALIVE_TARGET := 6
## Kovalayan canı = saldırı gücü x bu (2-3 isabette ölür): öldürmeyle tetiklenen özellikler (Seri Parmak, Sıçrayan Zehir, Kırık Buz parçalanması)
## klipte gerçekten çalışsın (kullanıcı 2026-11-15: "silahların özelliklerinin aktifleştiğinden emin ol").
const CHASER_HP_AP := 3.0
## Silaha göre can çarpanı: Gökkuşağı özelliği (Göz Kamaştırma) ışın AYNI düşmanda 3 sn tutulunca -> düşman ~4 sn dayanmalı; Buz Asası (Kırık Buz:
## her 2. isabet dondurur, donmuşken ölen parçalanır) isabeti zayıf -> 3. isabette ölsün.
const WEAPON_HP_AP := {"gokkusagi": 6.0, "buz_asasi": 1.5, "dagger": 5.0, "tabanca": 0.9} ## tabanca (Seri Parmak): her atış öldürsün -> 3 sn içinde 2+ yığın
## Bıçak (Kanayan Kesikler): 2 sn içinde art arda 3 isabet -> patlama; hedef 3. isabette hâlâ CANLI olmalı (ölüde kanama silinir) ve
## kovalayanlar yakın dövüş menzilinde kalmalı -> can 6 x SG, kovalama hızı oyuncuyla eşit.
const WEAPON_CHASE_K := {"dagger": 1.03, "buz_asasi": 1.0}
## Bıçak: kovalayanlar yakın dövüş menzilinde (~55 birim) başlasın (yelpaze mesafesi x0,45) ve hafif hızlı yetişsin.
const WEAPON_FAN_SCALE := {"dagger": 0.45}
## Yeniden doğma mesafesi (varsayılan 100-140, ekran kenarından koşarak girer): kovalayanın oyuncu hızında olduğu kliplerde yakın doğsun ki menzile girsin.
const WEAPON_RESPAWN_DIST := {"buz_asasi": [45.0, 60.0], "dagger": [40.0, 60.0]}
## Buz: donmuş yaratık durur, oyuncu koşarsa 3. mermi uzar ve 1,5 sn donmayı kaçırır -> düşman donmuşken oyuncu durup bitirir (kiting).
const PAUSE_ON_FROZEN := ["buz_asasi"] ## buz: tek kovalayan sabit mesafede -> isabet aralığı = atış aralığı 1,43 sn < donma 1,5 sn
## Buz Asası: donmuş düşmanı bilerek hedeflemez (donmamışlara dağıtır) ve öldüren isabet dondurmaz -> parçalanma için TEK kovalayan: 1. isabet
## yavaşlatır, 2. dondurur (1,5 sn), 3. (1,43 sn sonra, hâlâ donmuş) öldürür -> parçalanır. Diğer silahlarda ALIVE_TARGET.
const WEAPON_ALIVE := {"buz_asasi": 1}
const CHASE_K := 0.93 ## kovalayan hızı / oyuncu hızı (yaratık _ready'de hızı 0,528 x 0,9 x 1,05 ile çarpar - önceden bölünür)
const ENEMY_SPEED_MUL := 0.528 * 0.9 * 1.05
const RUN_LOOK := [12.0, 24.0, 36.0]
const WEAPON_ZOOM := 6.0
const WEAPON_SEC := 6.0 ## (eski sabit süre; artık kanıt + kuyruk: CLIP_MIN/CLIP_MAX/PROOF_TAIL)
## KLİP SÜRESİ ÖZELLİK KANITINA GÖRE (kullanıcı 2026-11-16: "bazı silahlar işini yapamadan klip kesilmiş"): kayıt, silahın özelliği TRAIT_PROOF
## koşullarını (kayıt başından beri) sağlayana kadar sürer, sonra PROOF_TAIL sn daha (düşen balista, kıvılcım yağmuru, cirit uçuşu, sersemleme bitsin);
## en az CLIP_MIN, en çok CLIP_MAX. Koşullar: ["add", düğüm anahtarı, adet] (_drain_added sayacı), ["var", özellik değişkeni, artış],
## ["cur", değişken, şimdiki değer], ["pierce", adet] (silah isabeti - atış).
const CLIP_MIN := 5.0
const CLIP_MAX := 12.0
const PROOF_TAIL := 2.0
## Klibin ilk 0,7 sn'sindeki tetiklenme kanıt sayılmaz (birleşik videoda 0,3 sn karartmanın altında / klibin en başında kalıyordu):
## sayaçlar bu andan itibaren yeniden başlar.
const PROOF_LEAD := 0.7
const TRAIT_PROOF := {
	"dagger": [["add", "fx_enchant_pixel:ring", 1]],
	"fire_staff": [["add", "fx_burn_status", 3]],
	"lightning_staff": [["add", "fx_lightning_chain", 6]],
	"tabanca": [["cur", "_stacks", 2]],
	"tuftuf": [["var", "leaps", 1]],
	"tufek": [["pierce", 2]],
	"arcane": [["add", "fx_enchant_pixel:ring", 1]], ## yankı işareti (halka); 0,8 sn sonra ikinci küre - kuyruk kapsar
	"yay": [["var", "attacks", 4]],
	"crossbow": [["var", "drops", 1]],
	"boomerang": [["var", "bounces", 4]],
	"buz_asasi": [["add", "fx_enchant_sprite:crystal_burst", 1]],
	"fisek": [["add", "fx_enchant_sprite:mini_pop", 8]],
	"pence": [["add", "fx_enchant_sprite:shuriken_hit", 8]],
	"topuz": [["add", "fx_enchant_sprite:seismic_ring", 1]],
	"uzunkilic": [["add", "enchant_area:blade", 1]],
	"gokkusagi": [["add", "fx_enchant_sprite:rainbow_dazzle", 1]],
	"mizrak": [["var", "throws", 1]],
	"kalkan": [["add", "fx_evo_burst", 5], ["var", "bashes", 1]],
	"yinyang": [["add", "yinyang_light", 3]],
	"pompali": [["var", "volleys", 3]],
	"makineli": [["var", "attacks", 20]],
}
const KALKAN_SEC := 7.0
const PLAYER_SCREEN := Vector2(640, 620) ## silah modunda karakterin ekran konumu
## Kalkan klibi: karakter aşağıda, atıcı sol üstte (kalkanın baş üstü yuvasına doğru gelen atış kalkanın hemen önünde söner).
const PLAYER_SCREEN_KALKAN := Vector2(700, 850)

var _out: String = OS.get_environment("KK_DIR")
var _gm: Node = null
var _main: Node = null
var _player: Node2D = null
var _zoom: float = float(OS.get_environment("KK_ZOOM")) if OS.get_environment("KK_ZOOM") != "" else 8.0
var _font: FontFile = null
var _ht: GDScript = null
var _mute: Array = []
var _keep: Array = [] ## silah modunda bizim koyduğumuz yaratıklar (diğerleri temizlenir)
var _pscreen: Vector2 = PLAYER_SCREEN
var _run_dir: Vector2 = Vector2.LEFT
var _run_t: float = 0.0
var _base_dir: Vector2 = Vector2.LEFT
var _clip_melee: Array = [] ## bu klibin kovalayan türleri
var _rng := RandomNumberGenerator.new()
var _added: Array = [] ## kayıt sırasında sahneye eklenen düğümler (özellik efekti kanıtı)
var _added_count: Dictionary = {}
var _log_on: bool = false
var _chaser_hp: float = 0.0
var _chase_k: float = CHASE_K
var _clip_key: String = ""
var _eb: Object = null ## klibin silah özellik betiği (enchant_behavior)
var _eb_base: Dictionary = {}
var _hits_base: int = 0
var _cur_f: int = -1 ## kayıttaki kare (olay günlüğü: ses eşleşmesi kontrolü)
var _events: Dictionary = {}
var _rec_t0: int = 0
## GERÇEK ZAMANLI YAKALAMA (KK_RT=1, 2026-11-16): bazı silah özellikleri pencerelerini GERÇEK saatle tutar (Time.get_ticks_msec: Bıçak kombosu
## 2 sn, Buz donma kaydı 1,5 sn, Seri Parmak yığını 3 sn, Gökkuşağı tutma, Zehir kaydı). Sabit kare hızlı yakalamada kare başına ~100 ms
## gerçek süre geçtiği için (oyun 3 kat yavaş) bu pencereler 3 kat daralıp özellik HİÇ tetiklenmiyordu. Gerçek zamanlı modda oyun normal
## hızında koşar; her 33,3 ms'de bir kare alınır (gecikirse atlanan kare aynı görüntüyle doldurulur -> ses ile eş), JPG kodlaması iş
## parçacığında; ses Master veriyolundaki AudioEffectRecord ile gerçek zamanlı kaydedilir (klasöre audio.wav).
var _rt: bool = OS.get_environment("KK_RT") == "1"
var _rec_fx: AudioEffectRecord = null
const FRAME_US := 1000000.0 / 30.0 ## pistin yönü (yönlendirme buna sadık kalır)


func _pre_draw() -> void:
	for n in _mute:
		if is_instance_valid(n):
			(n as CanvasItem).visible = false


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await process_frame
	_ht = load("res://scripts/hud_theme.gd")
	_font = load("res://assets/fonts/m5x7.ttf")
	if OS.get_environment("KK_MODE") == "survey":
		await _survey()
	elif OS.get_environment("KK_MODE") == "weapon":
		await _weapons()
	else:
		await _clips()
	print("BITTI")
	quit()


## ------------------------------------------------------------------ açılış
func _boot(char_id: int, map_id: String, time: float, weather: int, start_weapon: String = "") -> bool:
	var nm: Node = root.get_node("NetworkManager")
	_gm = root.get_node("GameManager")
	root.get_node("UISound").set("show_fps", false)
	for c in _gm.get_children():
		var sc: Variant = c.get_script()
		if sc != null and str((sc as Script).resource_path).ends_with("hitch_log.gd"):
			c.set_process(false)
	nm.call("disconnect_from_room")
	_gm.call("reset")
	_gm.set("selected_char_id", char_id)
	var chars: GDScript = load("res://scripts/characters.gd")
	_gm.set("selected_character", chars.get_def(char_id).get("skill", 1))
	_gm.set("selected_map", map_id)
	if start_weapon != "":
		_gm.set("selected_start_weapon", start_weapon)
	_gm.set("debug_immortal", true)
	_gm.set("debug_mode_unlocked", true) ## kayıt yazılmaz
	change_scene_to_file("res://scenes/main.tscn")
	var t0: int = Time.get_ticks_msec()
	while (current_scene == null or current_scene.name != "Main") and Time.get_ticks_msec() - t0 < 60000:
		await process_frame
	if current_scene == null or current_scene.name != "Main":
		return false
	_main = current_scene
	_main.set("_run_end_recorded", true)
	_gm.set("run_record_suppressed", true)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _frames(70)
	var house: Node = _main.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	## Ana harita açılışı (madde 313): deprem + kamera sarsıntısı + oyuncunun üstünde korku balonu (fear_emote.gd) çıkmasın -> evre DONE.
	var intro: Node = _main.get_node_or_null("HouseInterior/HouseIntro")
	if intro and intro.has_method("_set_phase"):
		intro.call("_set_phase", 3, 0.0)
	await _frames(60)
	_player = _main.get_node_or_null("Player") as Node2D
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)
	var atmo: Node = get_first_node_in_group("atmosphere")
	if atmo:
		atmo.call("debug_set_time", time)
		atmo.call("debug_set_weather", weather)
		atmo.call("debug_set_time_scale", 0.0)
	return _player != null


func _clear_world() -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	var spawner: Node = _main.get_node_or_null("EnemySpawner")
	if spawner:
		spawner.set("_spawn_timer", 1.0e9)


## HUD + oyun üstü katmanlar gizlenir (dünya rengi/vinyet katmanları kalır - adlar keşifte basılır).
func _hide_hud() -> void:
	var keep: PackedStringArray = PackedStringArray(["VignetteOverlay"])
	var hud: Node = _main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		(hud as CanvasLayer).visible = false
		(hud as CanvasLayer).offset = Vector2(100000, 100000)
	## Ev kapısı ipucu / "CANAVARLAR GELİYOR" sayacı her karede yeniden açılıyor: işlemeyi durdur + katmanı ekran dışına it.
	for nm in ["HouseInterior", "TravelingMerchant"]:
		var h: Node = _main.get_node_or_null(nm)
		if h:
			h.set_process(false)
	for n in _all_nodes(root):
		if n is CanvasLayer and n != hud and n.has_meta("kk_ui") == false:
			var cl := n as CanvasLayer
			if cl.layer >= 5 and not keep.has(String(cl.name)):
				cl.visible = false
				cl.offset = Vector2(100000, 100000)
		elif n is Label and not n.has_meta("kk_ui") and n.get_viewport() == root and _is_world_label(n as Label):
			(n as Label).visible = false
		elif n is CanvasItem and n.get_script() != null and str((n.get_script() as Script).resource_path).ends_with("fear_emote.gd"):
			(n as CanvasItem).visible = false ## açılış depreminin korku balonu (yedek; evre DONE'a alınınca hiç çıkmamalı)
			if not _mute.has(n):
				_mute.append(n)


## Dünyada duran oyun yazıları (kapı ipucu vb.): CanvasLayer altında olmayan Label'lar.
func _is_world_label(l: Label) -> bool:
	var p: Node = l.get_parent()
	while p != null:
		if p is CanvasLayer:
			return false
		p = p.get_parent()
	return true


func _all_nodes(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all_nodes(c))
	return out


func _dump_tree() -> void:
	for n in _all_nodes(root):
		if n is CanvasLayer:
			print("CL ", n.get_path(), " layer=", (n as CanvasLayer).layer, " vis=", (n as CanvasLayer).visible)
	for c in _player.get_children():
		print("PC ", c.name, " ", c.get_class(), " vis=", (c as CanvasItem).visible if c is CanvasItem else "-",
				" script=", str((c.get_script() as Script).resource_path) if c.get_script() else "")
	for c in _main.get_children():
		print("MC ", c.name, " ", c.get_class(), " script=", str((c.get_script() as Script).resource_path) if c.get_script() else "")


func _setup_camera(center_world: Vector2, zoom: float) -> Camera2D:
	var cam: Camera2D = _player.get_node("Camera2D")
	cam.limit_left = -10000000
	cam.limit_top = -10000000
	cam.limit_right = 10000000
	cam.limit_bottom = 10000000
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(zoom, zoom)
	cam.offset = center_world - _player.global_position
	cam.force_update_scroll()
	return cam


func _setup_cam_limits() -> void:
	var cam: Camera2D = _player.get_node_or_null("Camera2D")
	if cam:
		cam.limit_left = -10000000
		cam.limit_top = -10000000
		cam.limit_right = 10000000
		cam.limit_bottom = 10000000


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size())


## ------------------------------------------------------------------ keşif
func _survey() -> void:
	var first := true
	for m in OS.get_environment("KK_MAPS").split(","):
		if not await _boot(1, m, 150.0, 0):
			print("BOOT FAIL ", m)
			continue
		_clear_world()
		_player.set_process(false)
		_player.set_physics_process(false)
		if first:
			_dump_tree()
			first = false
		_hide_hud()
		var rect := Rect2(0, 0, 4608, 4608)
		if _gm.has_method("get_map_world_rect"):
			rect = _gm.call("get_map_world_rect")
		print("RECT ", m, " ", rect)
		var z: float = minf(SCREEN.x / rect.size.x, SCREEN.y / rect.size.y)
		_player.global_position = rect.get_center()
		_setup_camera(rect.get_center(), z)
		var grid: Node2D = Node2D.new()
		grid.set_script(load("res://tools/proto_20261114/karakter_klip/grid_overlay.gd"))
		grid.set("rect", rect)
		grid.set("zoom", z)
		grid.z_index = 4000
		grid.z_as_relative = false
		_main.add_child(grid)
		await _frames(20)
		await _shot(_out.path_join("survey_%s.png" % m))


## ------------------------------------------------------------------ klipler
func _spots() -> Dictionary:
	var d: Dictionary = SPOTS.duplicate()
	for item in OS.get_environment("KK_SPEC").split(";", false):
		var p: PackedStringArray = item.split(":")
		if p.size() >= 4:
			d[int(p[0])] = [p[1], float(p[2]), float(p[3]), float(p[4]) if p.size() > 4 else 150.0, int(p[5]) if p.size() > 5 else 0]
	return d


func _clips() -> void:
	var spots: Dictionary = _spots()
	var only: PackedStringArray = OS.get_environment("KK_ONLY").split(",", false)
	var still: bool = OS.get_environment("KK_STILL") == "1"
	TranslationServer.set_locale("en")
	var ids: Array = spots.keys()
	ids.sort()
	for id in ids:
		if not only.is_empty() and not only.has(str(id)):
			continue
		var s: Array = spots[id]
		if not await _boot(int(id), s[0], s[3], s[4]):
			print("BOOT FAIL ", id)
			continue
		TranslationServer.set_locale("en")
		_clear_world()
		_player.set_process(false)
		_player.set_physics_process(false)
		if float(s[1]) >= 0.0:
			_player.global_position = Vector2(s[1], s[2])
		print("SPOT ", id, " ", s[0], " ", _player.global_position)
		_hide_hud()
		_pose_player(int(id))
		var cam: Camera2D = _setup_camera(Vector2.ZERO, _zoom)
		## Karakter ekranın sol üçte birinde: kamera merkezi oyuncunun sağında.
		cam.offset = Vector2((SCREEN.x * 0.5 - 600.0) / _zoom, (SCREEN.y * 0.5 - 600.0) / _zoom)
		for k in WARM_FRAMES / 15:
			await _frames(15)
			_clear_world()
			_hide_hud()
		var ui: CanvasLayer = _build_ui(int(id))
		if still:
			await _frames(int(FPS * 1.6))
			_hide_hud()
			await _shot(_out.path_join("still_%d.png" % id))
		else:
			var dir: String = _out.path_join(str(id))
			DirAccess.make_dir_recursive_absolute(dir)
			var n: int = int(CLIP_SEC * FPS)
			for f in n:
				if f % 10 == 0:
					_clear_world()
					_hide_hud()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(dir.path_join("f_%04d.jpg" % f), 0.95)
				await process_frame
			print("CLIP ", id, " frames=", n)
		ui.queue_free()


func _pose_player(id: int, keep_weapons: bool = false) -> void:
	for nm in ["NameLabel", "OverheadBar", "DownedTimerLabel", "ShieldVisual"]:
		var n: Node = _player.get_node_or_null(nm)
		if n is CanvasItem:
			(n as CanvasItem).visible = false
	_mute.clear()
	for c in _player.get_children():
		var sc: Variant = c.get_script()
		var file: String = str((sc as Script).resource_path).get_file() if sc != null else ""
		if "weapon" in file and not keep_weapons:
			(c as CanvasItem).visible = false
		elif file in ["chat_bubble.gd", "overhead_bar.gd"] or String(c.name) in ["NameLabel", "OverheadBar", "DownedTimerLabel", "ShieldVisual"]:
			_mute.append(c) ## sohbet balonu (ana haritada açılışta emoji balonu çıkıyordu) her çizimden önce gizlenir
	if not RenderingServer.frame_pre_draw.is_connected(_pre_draw):
		RenderingServer.frame_pre_draw.connect(_pre_draw)
	var spr: AnimatedSprite2D = _player.get_node("AnimatedSprite2D")
	if not keep_weapons:
		spr.play("idle_down")
	## Keskin piksel: karakter pikseli tamsayı ekran pikseline yuvarlanır (oyunda ~0,9 dünya birimi).
	var root_k: float = absf(_player.global_scale.x)
	var world_px: float = absf(spr.scale.x) * root_k
	var target: float = maxf(1.0, roundf(world_px * _zoom)) / _zoom
	spr.scale = Vector2(signf(spr.scale.x), signf(spr.scale.y)) * target / root_k
	print("POSE ", id, " world_px=", world_px, " -> ", target, " screen_px=", target * _zoom)


## ------------------------------------------------------------------ arayüz
func _tr(s: String) -> String:
	return String(TranslationServer.translate(StringName(s)))


func _split_passive_name(desc: String) -> Array:
	var i: int = desc.find(": ")
	if i <= 0 or i > 28:
		return ["", desc]
	var head: String = desc.substr(0, i)
	if head == head.to_upper():
		return ["", desc]
	var re := RegEx.new()
	re.compile("[0-9(),%]")
	if re.search(head) != null:
		return ["", desc]
	return [head, desc.substr(i + 2)]


func _label(text: String, size: int, color: Color, outline: int) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font = _font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = _ht.get("OUTLINE")
	l.label_settings = ls
	l.text = text
	return l


func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBox:
	var b: StyleBox = (load("res://scripts/pixel_box.gd") as GDScript).new()
	b.set("bg_color", bg)
	b.set("border_color", border)
	b.call("set_border_width_all", bw)
	b.call("set_corner_radius_all", radius)
	return b


func _build_ui(id: int) -> CanvasLayer:
	var def: Dictionary = (load("res://scripts/characters.gd") as GDScript).get_def(id)
	var ui := CanvasLayer.new()
	ui.layer = 120
	ui.set_meta("kk_ui", true)
	root.add_child(ui)
	var rows: Array = []
	var set_re := RegEx.new()
	set_re.compile("\\s*\\((Set|Takım)[^)]*\\)\\s*$") ## Lyra: "Arcane Curse (Set 1/2)" -> taban ad
	for k in [["skill_name", "skill_icon", "Q"], ["skill2_name", "skill2_icon", "E"], ["skill3_name", "skill3_icon", "R"]]:
		rows.append([set_re.sub(_tr(str(def.get(k[0], ""))), ""), str(def.get(k[1], "")), k[2], false])
	var pdesc: String = _tr(str(def.get("passive", "")))
	var pn: Array = _split_passive_name(pdesc)
	var pname: String = str(def.get("passive_name", pn[0])) if def.has("passive_name") else str(pn[0])
	## Adlı pasif: ad + altında küçük "Passive"; adsız pasif: yalnız "Passive" (ikonda tuş etiketi yok).
	var psub: String = _tr("Pasif") if pname != "" else ""
	if pname == "":
		pname = _tr("Pasif")
	rows.append([pname, str(def.get("passive_icon", "")), psub, true])
	print("NAMES ", id, " ", _tr(str(def.get("name", ""))), " | ", rows.map(func(r: Array) -> String: return r[0]))

	## Karakter adı: başın üstünde (oyuncu ekranda x=600, y=600).
	var name_l: Label = _label(_tr(str(def.get("name", ""))), 96, _ht.get("ACCENT"), 18)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.size = Vector2(800, 110)
	name_l.position = Vector2(600 - 400, float(OS.get_environment("KK_NAME_Y")) if OS.get_environment("KK_NAME_Y") != "" else 600.0 - 24.0 * _zoom - 110.0)
	name_l.modulate.a = 0.0
	ui.add_child(name_l)
	var tw: Tween = name_l.create_tween()
	tw.tween_interval(0.15)
	tw.tween_property(name_l, "modulate:a", 1.0, 0.45)

	## Sağ sütun: ikon kuyusu + ad. Q/E/R 48 px ikon x3, pasif x2 (çizimdeki küçük kutu).
	var x0: float = 1040.0
	var y: float = 180.0
	var i: int = 0
	for r in rows:
		var passive: bool = r[3]
		var k: float = 2.0 if passive else 3.0
		var icon_px: float = 48.0 * k
		var row := Control.new()
		row.position = Vector2(x0 + (24.0 if passive else 0.0), y)
		row.modulate.a = 0.0
		ui.add_child(row)
		var well := Panel.new()
		well.add_theme_stylebox_override("panel", _box(_ht.get("INSET"), _ht.get("RIM"), 6, 6))
		well.size = Vector2(icon_px + 12, icon_px + 12)
		row.add_child(well)
		if ResourceLoader.exists(r[1]):
			var tr_ := TextureRect.new()
			tr_.texture = load(r[1])
			tr_.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr_.stretch_mode = TextureRect.STRETCH_SCALE
			tr_.size = Vector2(icon_px, icon_px)
			tr_.position = Vector2(6, 6)
			well.add_child(tr_)
		var mid: float = (icon_px + 12) * 0.5
		if not passive:
			var key: Label = _label(r[2], 48, _ht.get("TEXT"), 9)
			key.position = Vector2(icon_px - 22.0, icon_px - 30.0)
			key.size = Vector2(40, 40)
			key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			well.add_child(key)
		elif r[2] != "":
			var sub: Label = _label(r[2], 32, _ht.get("DIM"), 9)
			sub.position = Vector2(icon_px + 46, mid + 14)
			sub.size = Vector2(600, 40)
			row.add_child(sub)
			mid -= 14.0
		var nl: Label = _label(r[0], 64, _ht.get("TEXT"), 15)
		nl.position = Vector2(icon_px + 44, mid - 40)
		nl.size = Vector2(800, 80)
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(nl)
		var tw2: Tween = row.create_tween()
		## Sıralı giriş: her satır kendi gecikmesiyle (set_parallel + aralık birlikte kullanılınca aralık da paralel sayılıyordu).
		var d: float = 0.45 + 0.14 * i
		tw2.set_parallel(true)
		tw2.tween_property(row, "modulate:a", 1.0, 0.3).set_delay(d)
		tw2.tween_property(row, "position:x", row.position.x, 0.35).from(row.position.x + 60.0).set_delay(d) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		y += icon_px + 12 + 36.0
		i += 1
	return ui


## ------------------------------------------------------------------ silah klipleri (KK_MODE=weapon)
## Her silaha havuzundan karakter: en az kullanılanlar arasından rastgele, bir önceki klibin karakteri olmadan (tohumlu -> tekrarlanabilir).
func _weapon_plan() -> Array:
	## Her karakter en az bir kez görünsün: tohumu ilerleterek 14 karakterin hepsini kapsayan ilk planı al.
	var base: int = int(OS.get_environment("KK_SEED")) if OS.get_environment("KK_SEED") != "" else 20261114
	var plan: Array = []
	for t in 500:
		plan = _weapon_plan_seed(base + t)
		var seen: Dictionary = {}
		for it in plan:
			seen[it[1]] = true
		if seen.size() >= SPOTS.size() - WEAPON_EXCLUDED_CHARS.size():
			print("PLAN SEED ", base + t)
			break
	return plan


func _weapon_plan_seed(seed_value: int) -> Array:
	var keys: Array = (load("res://scripts/weapon_catalog.gd") as GDScript).get("KEYS")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var used: Dictionary = {}
	var prev: int = -1
	var plan: Array = []
	for k in keys:
		var pool: Array = (WEAPON_POOLS.get(k, [1]) as Array).duplicate()
		if pool.size() > 1:
			pool.erase(prev)
		var least: int = 1 << 30
		for c in pool:
			least = mini(least, int(used.get(c, 0)))
		var cands: Array = pool.filter(func(c: int) -> bool: return int(used.get(c, 0)) == least)
		var cid: int = cands[rng.randi_range(0, cands.size() - 1)]
		used[cid] = int(used.get(cid, 0)) + 1
		prev = cid
		plan.append([k, cid])
	return plan


func _spawn_creature(scene_path: String, pos: Vector2, world_speed: float = 0.0, immortal: bool = true) -> Node2D:
	var e: Node2D = (load(scene_path) as PackedScene).instantiate()
	e.set("speed", world_speed / ENEMY_SPEED_MUL) ## _ready çarpanı önceden bölünür -> dünya biriminde istenen hız
	if immortal:
		e.set("max_health", 1.0e9)
	elif _chaser_hp > 0.0:
		e.set("max_health", _chaser_hp)
	_main.add_child(e)
	e.global_position = pos
	if immortal:
		e.set("health", 1.0e9)
	_keep.append(e)
	return e


static func _creature_path(id: String) -> String:
	return "res://scenes/creatures/enemy_%s.tscn" % id


## Ölen / silinen (bizim koyduğumuz) yaratık sayısı.
func _dead_count() -> int:
	var c: int = 0
	for e in _keep:
		if not is_instance_valid(e) or e.get("is_dead") == true:
			c += 1
	return c


## Silahın özellik betiğindeki sayaçlar (sıfır olmayan int/float betik değişkenleri: leaps, bounces, throws, drops, attacks, _stacks...).
func _trait_counters() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for c in _player.get_children():
		var eb: Variant = c.get("enchant_behavior")
		if not (eb is Object) or not is_instance_valid(eb):
			continue
		parts.append(str((eb as Object).get_script().resource_path).get_file().get_basename())
		for pr in (eb as Object).get_property_list():
			if int(pr["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and (int(pr["type"]) == TYPE_INT or int(pr["type"]) == TYPE_FLOAT):
				var v: Variant = (eb as Object).get(pr["name"])
				if v != null and float(v) != 0.0 and not str(pr["name"]).ends_with("msec"):
					parts.append("%s=%s" % [pr["name"], str(v)])
	return " ".join(parts)


func _find_eb() -> Object:
	for c in _player.get_children():
		var eb: Variant = c.get("enchant_behavior")
		if eb is Object and is_instance_valid(eb):
			return eb
	return null


func _eb_val(name: String) -> float:
	if _eb == null or not is_instance_valid(_eb):
		return 0.0
	var v: Variant = _eb.get(name)
	return float(v) if v != null else 0.0


func _w_hits(key: String) -> int:
	var dealt: Dictionary = (load("res://scripts/balance_log.gd") as GDScript).call("dealt_snapshot")
	var row: Variant = dealt.get("w:" + key, null)
	return int((row as Array)[1]) if row is Array else 0


func _proof_ok(key: String) -> bool:
	for cond in TRAIT_PROOF.get(key, []):
		match str(cond[0]):
			"add":
				if int(_added_count.get(cond[1], 0)) < int(cond[2]):
					return false
			"var":
				if _eb_val(cond[1]) - float(_eb_base.get(cond[1], 0.0)) < float(cond[2]):
					return false
			"cur":
				if _eb_val(cond[1]) < float(cond[2]):
					return false
			"pierce":
				var shots: float = _eb_val("attacks") - float(_eb_base.get("attacks", 0.0))
				if float(_w_hits(key) - _hits_base) - shots < float(cond[1]):
					return false
	return true


## İş parçacığında: ilk yola JPG yaz, atlanan kare yuvalarına aynı dosyayı kopyala.
func _save_jpgs(img: Image, paths: PackedStringArray) -> void:
	img.save_jpg(paths[0], 0.95)
	for i in range(1, paths.size()):
		DirAccess.copy_absolute(paths[0], paths[i])


func _rec_start() -> void:
	if _rec_fx == null:
		_rec_fx = AudioEffectRecord.new()
	var bus: int = 0
	var found: bool = false
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) == _rec_fx:
			found = true
	if not found:
		AudioServer.add_bus_effect(bus, _rec_fx)
	_rec_fx.set_recording_active(true)


func _rec_stop(path: String) -> void:
	if _rec_fx == null:
		return
	_rec_fx.set_recording_active(false)
	var w: AudioStreamWAV = _rec_fx.get_recording()
	if w != null:
		w.save_to_wav(path)
		print("WAV ", path, " len=", w.get_length(), " rate=", w.mix_rate)
	else:
		print("WARN WAV YOK ", path)


func _alive_chasers() -> int:
	var c: int = 0
	for e in _keep:
		if is_instance_valid(e) and e.get("is_dead") != true and not bool(e.get("is_ranged")):
			c += 1
	return c


## Arkadan yeni kovalayan: kaçış yönünün 100-140 birim gerisi, +-55 yan (ekranın arka kenarından koşarak girer).
func _spawn_chaser_behind(psp: float) -> void:
	var perp: Vector2 = Vector2(-_run_dir.y, _run_dir.x)
	for t in 8:
		var rd: Array = WEAPON_RESPAWN_DIST.get(_clip_key, [100.0, 140.0])
		var q: Vector2 = _player.global_position - _run_dir * _rng.randf_range(float(rd[0]), float(rd[1])) + perp * _rng.randf_range(-55.0, 55.0)
		if not _blocked(q):
			_spawn_creature(_creature_path(_clip_melee[_rng.randi_range(0, _clip_melee.size() - 1)]), q, psp * _chase_k, false)
			return


## Hasar sayıları / altın "+N" yazıları gizli (kullanıcı 2026-11-15); kayıt sırasında eklenen düğümler özellik kanıtı için sayılır.
func _on_node_added(n: Node) -> void:
	var sc: Variant = n.get_script()
	if sc == null:
		return
	var file: String = str((sc as Script).resource_path).get_file()
	if file == "damage_numbers.gd" or file == "gold_gain_popup.gd" or file == "floating_text.gd": ## sayı yazıları (hasar, altın, "+N saldırı gücü")
		if n is CanvasItem:
			(n as CanvasItem).visible = false
			_mute.append(n)
		return
	if _log_on:
		_added.append(n)


## Bu karede eklenenlerin betik + tür/sayfa adını say (düğüm çoğu zaman kısa ömürlü: aynı karede okunur).
func _drain_added() -> void:
	for n in _added:
		if not is_instance_valid(n):
			continue
		var sc: Variant = n.get_script()
		var file: String = str((sc as Script).resource_path).get_file().get_basename() if sc != null else n.get_class()
		if file in ["enemy", "xp_orb", "creature_blood", "gold_coin", "ground_shadow", "shadow_blob", "night_glow"]:
			continue
		var k: String = file
		for prop in ["kind", "sheet", "_sheet", "fx_kind"]:
			var v: Variant = n.get(prop)
			if v is String and str(v) != "":
				k += ":" + str(v)
		var d: Variant = n.get("data")
		if d is Dictionary and (d as Dictionary).has("sheet"):
			k += ":" + str((d as Dictionary)["sheet"])
		_added_count[k] = int(_added_count.get(k, 0)) + 1
		if k in ["fx_evo_burst", "firework_projectile", "fx_enchant_sprite:ballista", "fx_enchant_sprite:seismic_ring"] and _cur_f >= 0:
			(_events.get_or_add(k, []) as Array).append(_cur_f)
	_added.clear()


func _added_summary() -> String:
	var keys: Array = _added_count.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(_added_count[a]) > int(_added_count[b]))
	var parts: PackedStringArray = PackedStringArray()
	for k in keys.slice(0, 18):
		parts.append("%s=%d" % [k, int(_added_count[k])])
	return ", ".join(parts)


## ------------------------------------------------------------------ kaçış (oyuncu koşar, yaratıklar kovalar)
func _blocked(p: Vector2) -> bool:
	return bool(_gm.call("is_position_blocked_by_walls", p))


func _clear_ahead(p: Vector2, d: Vector2) -> bool:
	var perp := Vector2(-d.y, d.x) * 7.0
	for k in RUN_LOOK:
		var q: Vector2 = p + d * float(k)
		if _blocked(q) or _blocked(q + perp) or _blocked(q - perp):
			return false
	return true


func _clear_len(p: Vector2, d: Vector2, max_len: float) -> float:
	var l: float = 0.0
	while l < max_len:
		if _blocked(p + d * (l + 8.0)):
			return l
		l += 8.0
	return l


## KOŞU PİSTİ: tema noktasının çevresinde (+-160, 16'lık ızgara) sola doğru açık ve 3 şerit genişliğinde en uzun yol; yoksa sağa. Dekor
## arasında çıkmaz sokağa girip kadrajdan kaybolmasın (Kalkan/Aldric harabe kayalarında, Flint kayaya giriyordu).
func _find_runway(spot: Vector2, need: float) -> Array:
	var best: Array = [spot, Vector2.LEFT]
	var best_s: float = -1.0e9
	for d in [Vector2.LEFT, Vector2.RIGHT]:
		for gy in range(-10, 11):
			for gx in range(-10, 11):
				var q: Vector2 = spot + Vector2(gx * 16, gy * 16)
				if _blocked(q):
					continue
				var l: float = need
				for side in [-14.0, 0.0, 14.0]:
					l = minf(l, _clear_len(q + Vector2(0, side), d, need))
					if l < best_s * 0.5:
						break
				var sc: float = l - 0.25 * q.distance_to(spot) - (120.0 if d == Vector2.RIGHT else 0.0)
				if sc > best_s:
					best_s = sc
					best = [q, d]
	print("RUNWAY spot=", spot, " -> ", best, " score=", best_s, " need=", need)
	return best


## Başlangıç yönü: 16 yönden en uzun açık yol (sola yakın olanlar tercih: kovalayanlar sağda, panelin önünde görünür).
func _pick_run_dir(p: Vector2, need: float) -> Vector2:
	var best: Vector2 = Vector2.LEFT
	var best_s: float = -1.0e9
	for i in 16:
		var d: Vector2 = Vector2.LEFT.rotated(TAU * float(i) / 16.0)
		var sc: float = minf(_clear_len(p, d, need), need) + 90.0 * (-d.x)
		if sc > best_s:
			best_s = sc
			best = d
	return best


## Her kare: kovalayanlardan uzağa (ağırlık 0,3) + mevcut yön; önü kapalıysa en yakın açık açıya döner; hafif zikzak. Gerçek hareket girdisi basılır
## (player.gd kendi yürüme/koşma klibini, yönünü, Matthew izi vb. oynar).
func _steer(delta: float) -> void:
	_run_t += delta
	var p: Vector2 = _player.global_position
	var away: Vector2 = Vector2.ZERO
	var cnt: int = 0
	for e in _keep:
		if is_instance_valid(e):
			away += p - (e as Node2D).global_position
			cnt += 1
	var pref: Vector2 = _run_dir
	if cnt > 0 and away.length() > 1.0:
		pref = (_run_dir * 0.75 + _base_dir * 0.15 + away.normalized() * 0.1).normalized()
	var choice: Vector2 = pref
	for a in [0, 20, -20, 40, -40, 65, -65, 90, -90, 120, -120, 160, -160]:
		var d: Vector2 = pref.rotated(deg_to_rad(float(a)))
		if _clear_ahead(p, d):
			choice = d
			break
	_run_dir = _run_dir.slerp(choice, 0.3).normalized()
	var perp: Vector2 = Vector2(-_run_dir.y, _run_dir.x)
	if _clip_key in PAUSE_ON_FROZEN:
		for e in _keep:
			if is_instance_valid(e) and e.get("is_frozen") == true and e.get("is_dead") != true:
				_set_move(Vector2.ZERO)
				return
	_set_move((_run_dir + perp * sin(_run_t * 2.3) * 0.22).normalized())


func _set_move(v: Vector2) -> void:
	for pair in [["move_left", -v.x], ["move_right", v.x], ["move_up", -v.y], ["move_down", v.y]]:
		if float(pair[1]) > 0.01:
			Input.action_press(pair[0], float(pair[1]))
		else:
			Input.action_release(pair[0])


func _player_speed() -> float:
	var sp: float = float(_player.get("speed")) if _player.get("speed") != null else 82.0
	return sp if sp > 20.0 and sp < 200.0 else 82.0


## Haritanın kendi yaratıkları (zindan odaları, kamplar...) kadraja girip oyuncuya saldırmasın: bizimkiler dışındakiler silinir.
func _clear_others() -> void:
	for e in get_nodes_in_group("enemies"):
		if not _keep.has(e):
			e.queue_free()


func _fire_at_player(from: Vector2) -> void:
	var p: Node2D = (load("res://scenes/enemy_projectile.tscn") as PackedScene).instantiate()
	var to: Vector2 = _player.global_position + Vector2(0, -8)
	p.set("direction", (to - from).normalized().rotated(randf_range(-0.06, 0.06)))
	p.set("damage", 5.0)
	_main.add_child(p)
	p.global_position = from


func _weapons() -> void:
	var cat: GDScript = load("res://scripts/weapon_catalog.gd")
	var only: PackedStringArray = OS.get_environment("KK_ONLY").split(",", false)
	var still: bool = OS.get_environment("KK_STILL") == "1"
	_zoom = WEAPON_ZOOM
	var plan: Array = _weapon_plan()
	print("PLAN ", plan)
	var idx: int = 0
	for item in plan:
		idx += 1
		var key: String = item[0]
		var cid: int = item[1]
		if not only.is_empty() and not only.has(key):
			continue
		var s: Array = WEAPON_SPOT_OVERRIDE.get(cid, SPOTS[cid])
		if not await _boot(cid, s[0], s[3], s[4], key):
			print("BOOT FAIL ", key)
			continue
		TranslationServer.set_locale("en")
		_clear_world()
		if float(s[1]) >= 0.0:
			_player.global_position = Vector2(s[1], s[2])
		_hide_hud()
		_pose_player(cid, true)
		_pscreen = PLAYER_SCREEN_KALKAN if key == "kalkan" else PLAYER_SCREEN
		_gm.set("team_xp_needed", 1.0e12) ## öldürmeler XP verir: level atlama kartı klibi bölmesin
		var ap_v: Variant = _player.get("damage_bonus")
		_chase_k = float(WEAPON_CHASE_K.get(key, CHASE_K))
		_clip_key = key
		_chaser_hp = float(WEAPON_HP_AP.get(key, CHASER_HP_AP)) * maxf(6.0, float(ap_v) if ap_v != null else 10.0)
		var dn: Variant = (load("res://scripts/damage_numbers.gd") as GDScript).call("get_instance", self)
		if dn is CanvasItem:
			(dn as CanvasItem).visible = false
			_mute.append(dn)
		if not node_added.is_connected(_on_node_added):
			node_added.connect(_on_node_added)
		_rng.seed = hash(key) ^ (20261115 + int(OS.get_environment("KK_RNG")) if OS.get_environment("KK_RNG") != "" else 20261115) ## KK_RNG: yeniden deneme
		var pool: Array = (MAP_MELEE.get(s[0], MAP_MELEE["ana"]) as Array).duplicate()
		_clip_melee.clear()
		while _clip_melee.size() < mini(4, pool.size()):
			var pick: String = pool.pop_at(_rng.randi_range(0, pool.size() - 1))
			_clip_melee.append(pick)
		## Oyuncunun KENDİ kamerası (çocuk düğüm: fizik interpolasyonuyla koşan oyuncuyu titremeden izler); ofset dünya biriminde, sınırlar her karede açılır.
		_set_move(Vector2.ZERO)
		var cam: Camera2D = _setup_camera(_player.global_position + (SCREEN * 0.5 - _pscreen) / _zoom, _zoom)
		cam.make_current()
		var kalkan: bool = key == "kalkan"
		var shooter: Node2D = null
		var shooter_rel := Vector2.ZERO
		_keep.clear()
		var psp: float = _player_speed()
		var clip_len: float = (KALKAN_SEC if kalkan else WEAPON_SEC) + 1.0
		var rw: Array = _find_runway(_player.global_position, psp * clip_len)
		_player.global_position = rw[0]
		_run_dir = rw[1]
		_base_dir = rw[1]
		_run_t = 0.0
		var perp0: Vector2 = Vector2(-_run_dir.y, _run_dir.x)
		## Kovalayanlar arkada yelpaze: 45-80 birim geride, +-40 yanda (engelli noktaya düşen atlanır).
		var spawned: int = 0
		var alive_t: int = int(WEAPON_ALIVE.get(key, 3 if kalkan else ALIVE_TARGET))
		var fan: Array = [[50.0, 0.0], [62.0, 30.0], [70.0, -32.0], [84.0, 12.0], [92.0, -12.0], [58.0, -55.0], [66.0, 52.0]]
		for f_ in fan:
			if spawned >= mini(5, alive_t):
				break
			var q: Vector2 = _player.global_position - _run_dir * float(f_[0]) * float(WEAPON_FAN_SCALE.get(key, 1.0)) + perp0 * float(f_[1]) * float(WEAPON_FAN_SCALE.get(key, 1.0))
			if _blocked(q):
				continue
			_spawn_creature(_creature_path(_clip_melee[spawned % _clip_melee.size()]), q, psp * _chase_k, false)
			spawned += 1
		var shooters: Array = []
		if kalkan:
			## GERÇEK menzilli yaratıklar (kullanıcı 2026-11-15): kendi mermilerini atarlar; oyuncu hızında kovalar (menzilde kalsınlar), ölümsüz.
			## Kalkan siper duruşunda atışlarını karşılar, menzile giren kovalayanları döver.
			var rpool: Array = RANGED_CREATURES.duplicate()
			for r_ in [[95.0, -60.0], [105.0, 55.0]]:
				var rq: Vector2 = _player.global_position - _run_dir * float(r_[0]) + perp0 * float(r_[1])
				if _blocked(rq):
					rq = _player.global_position - _run_dir * float(r_[0])
				var rid: String = rpool.pop_at(_rng.randi_range(0, rpool.size() - 1))
				shooters.append(_spawn_creature(_creature_path(rid), rq, psp * 1.05, true))
		print("RUN ", key, " dir=", _run_dir, " speed=", psp, " chasers=", spawned, " types=", _clip_melee, " ranged=", shooters.map(func(x: Node) -> String: return str(x.name)))
		if _rt:
			Engine.max_fps = 60
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var w0: int = Time.get_ticks_msec()
		var wlast: int = w0
		var wsteps: int = 0
		while (_rt and Time.get_ticks_msec() - w0 < 2000) or (not _rt and wsteps < 60):
			var wnow: int = Time.get_ticks_msec()
			var wdt: float = (wnow - wlast) / 1000.0 if _rt else 1.0 / FPS
			wlast = wnow
			if (_rt and wnow - w0 >= 1000) or (not _rt and wsteps >= 30):
				_steer(wdt)
			if wsteps % 6 == 0 and _alive_chasers() < alive_t:
				_spawn_chaser_behind(psp)
			if wsteps % 15 == 14:
				_hide_hud()
				_clear_others()
			wsteps += 1
			await process_frame
		_hide_hud()
		_clear_others()
		var wname: String = _tr(str(cat.call("display_name", key)))
		var cname: String = _tr(str((load("res://scripts/characters.gd") as GDScript).get_def(cid).get("name", "")))
		var ui: CanvasLayer = _build_weapon_ui(cid, key, wname)
		var dirname: String = "%02d_%s_%s" % [idx, wname.replace(" ", ""), cname]
		print("WEAPON ", dirname)
		var n: int = int(CLIP_MAX * FPS) ## üst sınır; gerçek bitiş kanıt + kuyruk
		var min_f: int = int((KALKAN_SEC if kalkan else CLIP_MIN) * FPS)
		var dir: String = _out.path_join(dirname)
		if not still:
			DirAccess.make_dir_recursive_absolute(dir)
		_added.clear()
		_added_count.clear()
		_log_on = true
		var dead0: int = _dead_count()
		_eb = _find_eb()
		_eb_base.clear()
		for vn in ["attacks", "leaps", "drops", "bounces", "throws", "bashes", "volleys"]:
			_eb_base[vn] = _eb_val(vn)
		_hits_base = _w_hits(key)
		var proof_f: int = -1
		var lead_done: bool = false
		_events.clear()
		_rec_t0 = Time.get_ticks_msec()
		var p0: int = -1
		var p_last: int = -1
		var saved: int = 0
		var t0_us: int = Time.get_ticks_usec()
		var last_us: int = t0_us
		var cap_idx: int = 0
		var tasks: Array = []
		var it: int = 0
		var next_hud_us: int = 0
		var next_clear_us: int = 0
		var next_spawn_us: int = 0
		if _rt and not still:
			_rec_start()
			t0_us = Time.get_ticks_usec()
			last_us = t0_us
		for f_it in 100000:
			var now_us: int = Time.get_ticks_usec()
			var f: int = int(float(now_us - t0_us) / FRAME_US) if _rt else f_it
			var step_dt: float = float(now_us - last_us) / 1000000.0 if _rt else 1.0 / FPS
			last_us = now_us
			if f >= n:
				break
			_cur_f = f
			if not lead_done and f >= int(PROOF_LEAD * FPS):
				lead_done = true
				_drain_added()
				_added_count.clear()
				for vn in ["attacks", "leaps", "drops", "bounces", "throws", "bashes", "volleys"]:
					_eb_base[vn] = _eb_val(vn)
				_hits_base = _w_hits(key)
			if lead_done and proof_f < 0 and _proof_ok(key):
				proof_f = f
				print("PROOF ", key, " f=", f)
			if proof_f >= 0 and f >= maxi(min_f, proof_f + int(PROOF_TAIL * FPS)):
				break
			if (_rt and now_us >= next_hud_us) or (not _rt and f % 10 == 0):
				_hide_hud()
				next_hud_us = now_us + 330000
			if (_rt and now_us >= next_clear_us) or (not _rt and f % 5 == 0):
				_clear_others()
				next_clear_us = now_us + 160000
			if ((_rt and now_us >= next_spawn_us) or (not _rt and f % 6 == 0)) and _alive_chasers() < alive_t:
				_spawn_chaser_behind(psp)
				next_spawn_us = now_us + 200000
			_drain_added()
			if kalkan and OS.get_environment("KK_DIAG") == "1" and f % 30 == 0:
				print("DIAG f=", f, " valid=", is_instance_valid(shooter), " ", (str(shooter.global_position) + " vis=" + str(shooter.is_visible_in_tree()) + " mod=" + str(shooter.modulate) + " hp=" + str(shooter.get("health")) + " st=" + str(shooter.get("_state")) + " kids=" + str(shooter.get_children().map(func(c: Node) -> String: return c.name + ":" + str(c.visible if c is CanvasItem else "-")))) if is_instance_valid(shooter) else "")
			_steer(step_dt)
			_setup_cam_limits()
			if OS.get_environment("KK_DIAG") == "1" and f % 30 == 0:
				var dmin: float = 1.0e9
				for e in _keep:
					if is_instance_valid(e) and e != shooter:
						dmin = minf(dmin, (e as Node2D).global_position.distance_to(_player.global_position))
				print("RUNDIAG ", key, " f=", f, " p=", _player.global_position, " dir=", _run_dir, " nearest=", dmin)
			if still and (f == 20 or f == n - 10):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(_out.path_join("wstill_%s_%s.png" % [key, "a" if f == 20 else "b"]))
				print("SHOT wstill_", key)
			if not still and _rt:
				await RenderingServer.frame_post_draw
				var idx_now: int = mini(n - 1, int(float(Time.get_ticks_usec() - t0_us) / FRAME_US))
				if idx_now >= cap_idx:
					var paths := PackedStringArray()
					for j in range(cap_idx, idx_now + 1):
						paths.append(dir.path_join("f_%04d.jpg" % j))
					tasks.append(WorkerThreadPool.add_task(_save_jpgs.bind(root.get_texture().get_image(), paths)))
					cap_idx = idx_now + 1
					saved = cap_idx
			elif not still:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_jpg(dir.path_join("f_%04d.jpg" % f), 0.95)
				## SES (kullanıcı 2026-11-16): Movie Maker AVI'sinden bu klibin sesi kesilecek - AVI karesi k = oyun karesi k + 1.
				if p0 < 0:
					p0 = Engine.get_process_frames()
				p_last = Engine.get_process_frames()
				saved = f + 1
			await process_frame
		_set_move(Vector2.ZERO)
		if _rt and not still:
			_rec_stop(dir.path_join("audio.wav"))
			for t in tasks:
				WorkerThreadPool.wait_for_task_completion(t)
		_drain_added()
		_log_on = false
		if proof_f < 0:
			print("WARN PROOF YOK ", key, " (", CLIP_MAX, " sn içinde özellik kanıtı gelmedi)")
		if not still and p0 >= 0 and not _rt:
			var af := FileAccess.open(dir.path_join("audio.json"), FileAccess.WRITE)
			af.store_string(JSON.stringify({"p0": p0, "p_last": p_last, "frames": saved, "fps": FPS, "proof_f": proof_f}))
			af.close()
		var dealt: Dictionary = (load("res://scripts/balance_log.gd") as GDScript).call("dealt_snapshot")
		var wrow: Variant = dealt.get("w:" + key, null)
		print("EVENTS ", dirname, " ", _events, " real_ms_per_frame=", (Time.get_ticks_msec() - _rec_t0) / maxf(1.0, float(saved)))
		_cur_f = -1
		print("TRAIT ", dirname, " | kills=", _dead_count() - dead0, " hp=", _chaser_hp, " w_hits=", (wrow as Array)[1] if wrow is Array else "-",
				" | ", _trait_counters(), " | ", _added_summary())
		if not still:
			print("CLIP ", dirname, " frames=", saved, " unique=", tasks.size() if _rt else saved)
		ui.queue_free()


## Sağ panel: silah ikonu (menü ikonu, x3 kuyuda) + İngilizce adı + Melee/Ranged; karakter adı başının üstünde.
func _build_weapon_ui(cid: int, key: String, wname: String) -> CanvasLayer:
	var cat: GDScript = load("res://scripts/weapon_catalog.gd")
	var def: Dictionary = (load("res://scripts/characters.gd") as GDScript).get_def(cid)
	var ui := CanvasLayer.new()
	ui.layer = 120
	ui.set_meta("kk_ui", true)
	root.add_child(ui)
	## Karakter adı YOK (kullanıcı 2026-11-16: "karakterlerin ismi yazmasın"); yalnız sağ üstte silah.

	var row := Control.new()
	row.position = Vector2(1180, 70) ## sağ üst: kovalayanlar oyuncu hizasında (y 620) arkada, panel onları örtmesin
	row.modulate.a = 0.0
	ui.add_child(row)
	var icon_px: float = 144.0
	var well := Panel.new()
	well.add_theme_stylebox_override("panel", _box(_ht.get("INSET"), _ht.get("RIM"), 6, 6))
	well.size = Vector2(icon_px + 12, icon_px + 12)
	row.add_child(well)
	var tex: Texture2D = cat.call("menu_icon", key)
	if tex != null:
		var tr_ := TextureRect.new()
		tr_.texture = tex
		tr_.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr_.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr_.size = Vector2(icon_px, icon_px)
		tr_.position = Vector2(6, 6)
		well.add_child(tr_)
	var nl: Label = _label(wname, 64, _ht.get("TEXT"), 15)
	nl.position = Vector2(icon_px + 44, (icon_px + 12) * 0.5 - 58)
	nl.size = Vector2(700, 80)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(nl)
	var sub: Label = _label(_tr(str(cat.call("category_label", key))), 32, _ht.get("DIM"), 9)
	sub.position = Vector2(icon_px + 46, (icon_px + 12) * 0.5 + 18)
	sub.size = Vector2(600, 40)
	row.add_child(sub)
	var tw: Tween = row.create_tween()
	tw.set_parallel(true)
	tw.tween_property(row, "modulate:a", 1.0, 0.3).set_delay(0.35)
	tw.tween_property(row, "position:x", row.position.x, 0.35).from(row.position.x + 60.0).set_delay(0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return ui
