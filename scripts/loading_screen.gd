extends Control

## Yükleme ekranı: "BAŞLAT"tan sonra ana oyun sahnesine (main.tscn) geçişte gösterilir.
##
## YÜKLEME TEK BİR ÖZEL İŞ PARÇACIĞINDA (2026-10-17, kullanıcı: "yüklenirken animasyonlar donmasın"). Geçmiş:
## - 2026-09-27: bağımlılıklar ana iş parçacığında yüklenince büyük betiklerin derlemesi ekranı donduruyordu.
## - 2026-10-05: ResourceLoader.load_threaded_request (WorkerThreadPool) ile betik derlemesi ARALIKLI kilitleniyordu: player.gd görevi
##   sonsuza dek "devam ediyor" kalıyor, ardından gelen her istek de takılıyordu (bar %20-30'da sonsuz takılma). O gün çözüm "betikler
##   ana iş parçacığında" oldu - bedeli donmalar: 2026-10-17 başsız ölçüm, 15,5 sn'lik yüklemenin 13,6 sn'si donmuş kare (player.gd
##   3,3 sn, main.gd 3,5 sn, enemy_spawner 1,4 sn, hud 1,1 sn, sahne kurulumu 2,7 sn).
## - 2026-10-17 ölçüm: WorkerThreadPool'da betik derlemesi 4.7.2'de HÂLÂ kilitleniyor (12 denemenin 3'ü, hep player.gd). Aynı yükleme
##   KENDİ Thread'imizde düz ResourceLoader.load ile 15/15 temiz ve yükleme boyunca hiç uzun kare yok. Yani kilit WorkerThreadPool
##   görevlerinde; bu yüzden: bağımlılık ağacı taraması + her bağımlılığın sırayla yüklenmesi + main.tscn tek bir Thread'de
##   (_load_worker). Ana iş parçacığı sadece çizer ve ilerlemeyi okur (_mutex). load_threaded_request KULLANMA.
## Sahne kurulumu (Main._ready + ilk kare) zorunlu ana iş parçacığı işidir (~1-3 sn) ve donar: o ana kadar bar %97'ye akar, yürüyen
## parti durur ve yazı "OYUN BAŞLIYOR" olur (_arrive) - donma duran bir karede geçer, yürüyüşün ortasında değil. Görsel en üst katmanıyla
## (loading_overlay.gd) köke taşınır, oyunun ilk karesi hazır olunca bar %100 olur ve katman solarak kaybolur.
## Görünüş (madde 411, "Sade"): aşağıda SADE GÖRÜNÜŞ.
## İlerleme DOSYA SAYISINA göre değil yaklaşık maliyete göre (türe göre ağırlık x boyut, bkz. LOAD_WEIGHT_PER_KB); uzun bir adım
## (büyük betik) sürerken bar o adımın payına doğru süzülür.
##
## Multiplayer'da (kullanıcı isteği: "bundan sonra multiplayerda herkesin yükleme barı dolmadan oyun başlamamalı") yerel yükleme
## bitince NetworkManager'a bildirilir; TÜM oyuncular bitirene kadar (NetworkManager.all_players_loading_done) "Diğer oyuncular
## bekleniyor..." yazısıyla beklenir. Bir peer donup asla haber vermezse sonsuza dek takılı kalınmasın diye zaman aşımı var.

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const LOAD_SHARE := 95.0 ## yükleme bitince barın ulaştığı yer; kalan %5 = sahne kurulumu + ilk kare
const HANDOFF_VALUE := 97.0 ## sahne değişirken (kurulum sürerken) gösterilen değer
const FILL_SPEED := 160.0 ## gösterilen değer hedefe en fazla bu hızla (%/sn) yaklaşır - önbellekten anında yüklenince zıplamasın
const NO_DEP_SCAN_EXT: Array[String] = ["png", "jpg", "webp", "svg", "wav", "mp3", "ogg", "ttf", "otf", "gdshader"]
const OverlayScript: GDScript = preload("res://scripts/loading_overlay.gd")
## İlerleme ağırlığı: ölçümde (2026-09-27) sürenin ~%90'ı GDScript derlemesi (boyutla orantılı), ~%10'u sahneler, dokular/sesler
## ihmal edilebilir. Ağırlık = dosya boyutu x türe göre çarpan (bayt başına); boyut okunamazsa türün varsayılanı.
const LOAD_WEIGHT_PER_KB := {"gd": 1.0, "tscn": 0.25, "scn": 0.25, "tres": 0.02, "res": 0.02}
const LOAD_WEIGHT_FALLBACK := {"gd": 20.0, "tscn": 10.0, "scn": 10.0}
const LOAD_WEIGHT_DEFAULT := 0.05
const STEP_CREEP_MAX := 0.85 ## uzun bir adım sürerken bar o adımın payının en fazla bu kadarına süzülür
const STEP_CREEP_RATE := 0.5 ## /sn
const WAIT_FOR_OTHERS_TIMEOUT := 30.0
const WAIT_FOR_HOST_TIMEOUT := 120.0 ## host yüklemesini bitirmediyse istemci bu kadar bekler (bkz. NetworkManager.is_host_loading_done)

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var status_label: Label = $StatusLabel

var _elapsed: float = 0.0
var _local_load_done: bool = false
var _proceeded: bool = false
var _disconnected: bool = false
var _wait_elapsed: float = 0.0

## ---------------------------------------------------------------- YÜKLEME İŞ PARÇACIĞI
## _t_* alanlarını iş parçacığı yazar, ana iş parçacığı _mutex altında okur. _loaded_refs'e sadece iş parçacığı yazar; ana iş parçacığı
## ona wait_to_finish'ten SONRA dokunur (önbellekte kalsınlar diye referans - sahne değişince main kendi referanslarını tutar).
var _thread: Thread = null
var _mutex := Mutex.new()
var _abort: bool = false
var _t_scan_done: bool = false
var _t_scan_seen: int = 0
var _t_scan_pending: int = 0
var _t_weight_total: float = 0.0
var _t_weight_done: float = 0.0
var _t_cur_weight: float = 0.0 ## şu an yüklenen bağımlılığın ağırlığı (0 = yok)
var _t_cur_msec: int = 0
var _loaded_refs: Array = []
## Efekt ısınma listesi (fx_warmup_list.gd) de bu iş parçacığında okunur ve _proceed'de FxWarmup'a devredilir (2026-11-07: oyunun ilk
## saniyelerinde ana iş parçacığında 1,5 sn boyunca 40-60 ms'lik kareler yapıyordu).
const WARM_LIST_PATH := "res://scripts/fx_warmup_list.gd"
const FX_WARMUP_PATH := "res://scripts/fx_warmup.gd"
var _warm_paths: Dictionary = {}
var _warm_refs: Array = []
## Çalışma anında load() ile okunan ama main.tscn bağımlılık ağacında görünmeyen kaynaklar (madde 440): ortak liste (boot_preload_list.gd) +
## seçili karakterin kare sayfaları / ikonları / portresi. Ana iş parçacığında (start_loader) hesaplanır, iş parçacığı sadece okur.
const BootPreloadList := preload("res://scripts/boot_preload_list.gd")
const SpiritualSkillsScript: GDScript = preload("res://scripts/spiritual_skills.gd")
const MapProfilesScript: GDScript = preload("res://scripts/map_profiles.gd")
const BOOT_EXTENSIONS: Array[String] = ["png", "tres", "tscn", "res", "wav", "ogg", "mp3", "gdshader", "gd"]
var _boot_extra: Array[String] = []
var _boot_extra_set: Dictionary = {}
## Testler kapatır (yükleyiciyi küçük bir sahneyle elle başlatırlar); oyunda hep main.tscn.
var autostart_loader: bool = true
var main_scene_path: String = MAIN_SCENE_PATH

## ---------------------------------------------------------------- SADE GÖRÜNÜŞ (madde 411)
## Geçmiş: yapay zekâ arka planı (2026-09-17) -> "Kaçış" kovalamacası (09-27) -> "Eve Dönüş" kulübesi (madde 233) -> "Mühürlü Kapı"
## (madde 370, derin orman Kemik Mahzeni). Kullanıcı 2026-11-06: "hepsi berbat ... ama ai olmasın" -> 4 prototip (madde 408) -> "C" = SADE:
## düz koyu zemin (HudTheme.DEEP), parti tek sıra yürür (yerel oyuncu önde/sağda, diğerleri lobi sırasıyla arkasında), altında YÜKLENİYOR +
## ince çubuk + yüzde, en altta ipucu. Arka plan resmi, ışık, hale, yaratık, başlık YOK. Renkler hud_theme.gd rolleri, yazı m5x7 32/48 +
## PixeloidSans 18 (yüzde) - docs/stil_rehberi.md.
## Karakter: sanat pikseli = PARTY_PX ekran pikseli (Matthew gibi küçük karakterler characters.gd "scale" oranında, tam sayıya yuvarlı);
## ayak hizası her klibin ilk karesindeki en alt dolu satır (_foot_offset). Varışta parti durur (idle_right), yazı "OYUN BAŞLIYOR":
## ardından gelen sahne kurulumu donması duran bir karede geçer.
## Yerleşim ekran ortasına göre (1920x1080 taban), ipucu satırı alt kenara bağlı.
const HudTheme := preload("res://scripts/hud_theme.gd")
const ShopsFlag := preload("res://scripts/shops_flag.gd")
const FONT_TEXT: Font = preload("res://assets/fonts/m5x7.ttf")
const FONT_NUM: Font = preload("res://assets/fonts/PixeloidSans-Bold.ttf")
const CHAR_BASE_SCALE := 2.2368375
const PARTY_PX := 4.0
const PARTY_STEP := 129.0 ## parti üyeleri arası (ekran px)
const PARTY_FOOT_Y := -24.0
const PARTY_MAX := 8
const STATUS_RECT := Rect2(-600.0, 36.0, 1200.0, 56.0)
const BAR_RECT := Rect2(-300.0, 102.0, 600.0, 24.0)
const PCT_RECT := Rect2(-300.0, 141.0, 600.0, 30.0)
const TIP_BOTTOM := 108.0 ## ipucu satırının üstü, alt kenardan
const STATUS_FONT := 48
const TIP_FONT := 32
const PCT_FONT := 18
## Varış: bar HANDOFF_VALUE'ya bu sürede akar, sonra parti durur.
const ARRIVE_RUN_TIME := 0.35
## Seyyar satıcı kapalıyken (shops_flag.gd merchant_enabled) satıcıdan söz eden ipucu çıkmaz.
const SHOP_TIP := "Satıcının güvenli bölgesinde zaman durur - yaratıklar güçlenmez."
const TIPS: Array[String] = [
	"F tuşu ruhani yeteneğini kullanır.",
	"Bir kademenin boss'u yaşadıkça yeni kademe başlamaz.",
	"Evin içindeyken yaratıklar sana saldıramaz.",
	"Elit sandıklar herkese birer epik eşya verir.",
	"Normal sandıklar oyunculara sırayla verilir.",
	"Hiç can hakkın kalmazsa 5 dakikada bir kalp yenilenir.",
	"Space tuşu ile etkileşime girersin.",
	"Q, E ve R yeteneklerin seviye atladıkça açılır.",
]

var _overlay: CanvasLayer = null
var _stage: Control = null ## parti (ekran ortasına bağlı)
var _party: Array[AnimatedSprite2D] = [] ## meta "foot" = ayağın sahne y'si
var _pct_label: Label = null
var _tip_label: Label = null


func _ready() -> void:
	_build_scene()
	status_label.text = "YÜKLENİYOR"
	progress_bar.value = 0.0
	NetworkManager.host_left_game.connect(_on_disconnected)
	NetworkManager.server_disconnected.connect(_on_disconnected)
	## Sahne (parti kareleri) ana iş parçacığında yüklendi; bundan sonra ana iş parçacığı yüklemeye dokunmaz.
	if autostart_loader:
		start_loader()


func start_loader() -> void:
	if main_scene_path == MAIN_SCENE_PATH:
		_boot_extra = boot_extra_paths(GameManager.selected_char_id, str(GameManager.selected_spiritual))
		## Seçili harita ana harita değilse sahnesi + verisi (madde 444): Main._enter_tree onu load() eder, burada iş parçacığında önbelleğe girer.
		for mp: String in MapProfilesScript.preload_paths():
			if not _boot_extra.has(mp):
				_boot_extra.append(mp)
		for bp: String in _boot_extra:
			_boot_extra_set[bp] = true
	_thread = Thread.new()
	## Düşük öncelik (madde 440): yükleme iş parçacığı ana iş parçacığının (yürüyen parti + bar çizimi) CPU'sunu çekmesin - az çekirdekli ya da
	## meşgul makinede yürüyüşün takılmasını önler; çekirdek boşsa yükleme süresi değişmez.
	_thread.start(_load_worker, Thread.PRIORITY_LOW)


func _exit_tree() -> void:
	## Bağlantı kesilip menüye dönülürse: iş parçacığı sıradaki dosyadan önce durur; şu anki dosyanın bitmesi beklenir.
	_mutex.lock()
	_abort = true
	_mutex.unlock()
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null


func _build_scene() -> void:
	## Tüm görsel en üst CanvasLayer'da (loading_overlay.gd) - geçişte köke taşınıp yeni sahnenin katmanlarının üstünde kalır, sonra solar.
	_overlay = CanvasLayer.new()
	_overlay.name = "LoadingOverlay"
	_overlay.set_script(OverlayScript)
	add_child(_overlay)
	var holder := Control.new()
	holder.name = "Holder"
	holder.theme = theme
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(holder)
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = HudTheme.DEEP
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	for n: String in ["StatusLabel", "ProgressBar"]:
		var c: Node = get_node_or_null(n)
		if c:
			c.reparent(holder, false)

	_stage = Control.new()
	_stage.name = "PartyStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_preset(Control.PRESET_CENTER)
	holder.add_child(_stage)
	_build_party()

	## Çubuk: kuyu (WIN_INSET + 3 px WIN_LINE) + dolgu; dolgunun 6 px saydam kenarı kuyuyu gösterir (3 px boşluk).
	var trough := StyleBoxFlat.new()
	trough.bg_color = HudTheme.WIN_INSET
	trough.border_color = HudTheme.WIN_LINE
	trough.set_border_width_all(3)
	trough.anti_aliasing = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = HudTheme.ACCENT
	fill.border_color = Color(0, 0, 0, 0)
	fill.set_border_width_all(6)
	fill.anti_aliasing = false
	progress_bar.add_theme_stylebox_override("background", trough)
	progress_bar.add_theme_stylebox_override("fill", fill)
	progress_bar.show_percentage = false
	_center_anchor(progress_bar, BAR_RECT)

	_style_label(status_label, FONT_TEXT, STATUS_FONT, HudTheme.TEXT)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_anchor(status_label, STATUS_RECT)

	_pct_label = Label.new()
	_pct_label.name = "PercentLabel"
	_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_label(_pct_label, FONT_NUM, PCT_FONT, HudTheme.PRICE)
	holder.add_child(_pct_label)
	_center_anchor(_pct_label, PCT_RECT)
	## Devirde (loading_overlay.gd) çubuk %100'e çekilir; yüzde de onu izlesin (bu düğümün _process'i o sırada kapalı).
	progress_bar.value_changed.connect(_on_bar_value)
	_on_bar_value(progress_bar.value)

	var row := HBoxContainer.new()
	row.name = "TipRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -TIP_BOTTOM
	row.offset_bottom = -TIP_BOTTOM + 40.0
	holder.add_child(row)
	var head := Label.new()
	head.text = "İPUCU  "
	_style_label(head, FONT_TEXT, TIP_FONT, HudTheme.ACCENT)
	row.add_child(head)
	_tip_label = Label.new()
	_tip_label.name = "TipLabel"
	var pool: Array[String] = tip_pool()
	_tip_label.text = pool[randi() % pool.size()]
	_style_label(_tip_label, FONT_TEXT, TIP_FONT, HudTheme.DIM)
	row.add_child(_tip_label)


static func tip_pool() -> Array[String]:
	var pool: Array[String] = TIPS.duplicate()
	if ShopsFlag.merchant_enabled:
		pool.push_front(SHOP_TIP)
	return pool


## Ön yüklenecek yollar: ortak liste + seçili karakterin tanımındaki res:// kaynakları (kare sayfası, yetenek/pasif ikonları, portre) +
## seçili ruhani yeteneğin ikonu. Tekrarsız, sırayla.
static func boot_extra_paths(char_id: int, spiritual: String) -> Array[String]:
	var out: Array[String] = []
	var seen: Dictionary = {}
	var add := func(p: Variant) -> void:
		if p is String and (p as String).begins_with("res://") and BOOT_EXTENSIONS.has((p as String).get_extension().to_lower()) and not seen.has(p):
			seen[p] = true
			out.append(p)
	var def: Dictionary = Characters.get_def(char_id)
	for k: Variant in def:
		var v: Variant = def[k]
		if v is Array:
			for e: Variant in v:
				add.call(e)
		else:
			add.call(v)
	var sp: Dictionary = SpiritualSkillsScript.get_def(spiritual)
	add.call(sp.get("icon", ""))
	for bp: String in BootPreloadList.PATHS:
		add.call(bp)
	return out


## Parti sırası: yerel oyuncu önce (en önde yürür), sonra lobideki diğerleri peer kimliği sırasıyla. Tek oyunculuda yalnız yerel.
static func party_chars(local_char: int, lobby: Dictionary, me: int, mp: bool) -> Array[int]:
	var out: Array[int] = [local_char]
	if not mp:
		return out
	var ids: Array = lobby.keys()
	ids.sort()
	for id: Variant in ids:
		if int(id) == me or out.size() >= PARTY_MAX:
			continue
		var info: Variant = lobby[id]
		if info is Dictionary and (info as Dictionary).has("char_id"):
			out.append(int((info as Dictionary)["char_id"]))
	return out


func _build_party() -> void:
	var me: int = multiplayer.get_unique_id() if multiplayer and multiplayer.has_multiplayer_peer() else 1
	var chars: Array[int] = party_chars(GameManager.selected_char_id, NetworkManager.lobby_players, me, NetworkManager.is_multiplayer_active)
	var n: int = chars.size()
	for i in range(n):
		## Ekran ortasına göre: yerel oyuncu en sağda (yürüyüş yönünde önde), arkadaşları solunda.
		var x: float = roundf((float(n - 1) * 0.5 - float(i)) * PARTY_STEP / 3.0) * 3.0
		var s: AnimatedSprite2D = _party_sprite(chars[i], Vector2(x, PARTY_FOOT_Y))
		if s:
			s.frame = (i * 3) % maxi(1, s.sprite_frames.get_frame_count(s.animation)) ## adımlar aynı anda atılmasın
			_party.append(s)


func _party_sprite(char_id: int, foot: Vector2) -> AnimatedSprite2D:
	var def: Dictionary = Characters.get_def(char_id)
	var path: String = str(def.get("frames", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var frames: SpriteFrames = load(path) as SpriteFrames
	if frames == null:
		return null
	var anim: String = "walk_right" if frames.has_animation("walk_right") else ("run_right" if frames.has_animation("run_right") else "")
	if anim == "":
		return null
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ratio: float = (def.get("scale", Vector2.ONE * CHAR_BASE_SCALE) as Vector2).x / CHAR_BASE_SCALE
	s.scale = Vector2.ONE * maxf(1.0, roundf(PARTY_PX * ratio))
	s.set_meta("foot", foot)
	_stage.add_child(s)
	_play_on_foot(s, anim)
	return s


## Klibi oynatır ve sprite'ı o klibin ayağı sahnedeki ayak noktasına oturacak yere koyar (yürüme/duruş kareleri farklı yükseklikte olabilir).
func _play_on_foot(s: AnimatedSprite2D, anim: String) -> void:
	s.play(anim)
	var foot: Vector2 = s.get_meta("foot", Vector2.ZERO)
	s.position = Vector2(foot.x, foot.y - _foot_offset(s.sprite_frames.get_frame_texture(anim, 0)) * s.scale.y).round()


func _style_label(l: Label, font: Font, size: int, color: Color) -> void:
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)


func _on_bar_value(v: float) -> void:
	if is_instance_valid(_pct_label):
		_pct_label.text = "%" + str(int(round(v)))


func _center_anchor(c: Control, r: Rect2) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = r.position.x
	c.offset_right = r.end.x
	c.offset_top = r.position.y
	c.offset_bottom = r.end.y


## Sprite merkezinden en alt dolu piksel satırına uzaklık (sanat pikseli). region boşsa tüm doku.
static func _foot_offset(tex: Texture2D, region: Rect2i = Rect2i()) -> float:
	if tex == null:
		return 0.0
	var img: Image = tex.get_image()
	if img == null:
		return 0.0
	if img.is_compressed():
		img.decompress()
	if region.size != Vector2i.ZERO:
		img = img.get_region(region)
	var used: Rect2i = img.get_used_rect()
	if used.size.y <= 0:
		return img.get_height() * 0.5
	return float(used.end.y) - img.get_height() * 0.5


func _process(delta: float) -> void:
	if _proceeded or _disconnected:
		return

	## Yazının sonuna nokta eklenmez (2026-11-06): ortalı yazı her noktada kayıyordu; canlılığı yürüyen parti gösterir.
	if not _local_load_done:
		_elapsed += delta
		var target: float = _load_progress() * LOAD_SHARE
		progress_bar.value = move_toward(progress_bar.value, target, FILL_SPEED * delta)

		if _loader_finished() and progress_bar.value >= LOAD_SHARE - 0.01:
			_join_loader()
			_local_load_done = true
			NetworkManager.mark_local_loading_done()
		return

	if NetworkManager.is_multiplayer_active and not NetworkManager.all_players_loading_done():
		_wait_elapsed += delta

		## Host henüz yüklemesini bitirmediyse onsuz başlanmaz (uzun zaman aşımı): host'suz giren istemci oyunu bozuk görürdü.
		var host_ready: bool = NetworkManager.is_host_loading_done()
		var wait_limit: float = WAIT_FOR_OTHERS_TIMEOUT if host_ready else WAIT_FOR_HOST_TIMEOUT
		status_label.text = "DİĞER OYUNCULAR BEKLENİYOR" if host_ready else "HOST BEKLENİYOR"

		if _wait_elapsed >= wait_limit:
			push_warning("[LoadingScreen] Diğer oyuncular %.0f sn içinde hazır olmadı, yine de devam ediliyor." % wait_limit)
			_proceed()
		return

	_proceed()


## ---------------------------------------------------------------- yükleme iş parçacığı

## İŞ PARÇACIĞI: main.tscn'in bağımlılık ağacını tarar, yapraklardan başlayarak her birini SIRAYLA yükler, en son main.tscn'i.
## Ana iş parçacığının nesnelerine dokunmaz; paylaşılan sayılar _mutex altında.
func _load_worker() -> void:
	var root_path: String = main_scene_path
	var stack: Array = [root_path]
	var seen: Dictionary = {}
	var order: Array = []
	var roots: Array = []
	while not stack.is_empty():
		if _aborted():
			return
		var path: String = stack.pop_back()
		if seen.has(path):
			continue
		seen[path] = true
		if not NO_DEP_SCAN_EXT.has(path.get_extension().to_lower()):
			for d: String in ResourceLoader.get_dependencies(path):
				var dp: String = _dep_path(d)
				if path == root_path and dp.get_extension() == "gd":
					roots.append(dp)
				if dp != "" and not seen.has(dp):
					stack.append(dp)
		order.append(path)
		_mutex.lock()
		_t_scan_seen = seen.size()
		_t_scan_pending = stack.size()
		_mutex.unlock()
	var plan: Array = load_plan(order, roots, root_path)
	if root_path == MAIN_SCENE_PATH and ResourceLoader.exists(WARM_LIST_PATH):
		var wl: Script = ResourceLoader.load(WARM_LIST_PATH) as Script
		var paths: Variant = wl.get_script_constant_map().get("PATHS", []) if wl else []
		for wp: String in paths:
			if not seen.has(wp):
				seen[wp] = true
				_warm_paths[wp] = true
				plan.append(wp)
	for ep: String in _boot_extra:
		if not seen.has(ep):
			seen[ep] = true
			plan.append(ep)
	var weights: Array = []
	var total: float = 0.0
	for p: String in plan:
		var w: float = _estimate_weight(p)
		weights.append(w)
		total += w
	_mutex.lock()
	_t_weight_total = total
	_t_scan_done = true
	_mutex.unlock()
	for i in range(plan.size()):
		if _aborted():
			return
		var p: String = plan[i]
		if not ResourceLoader.has_cached(p) and ResourceLoader.exists(p):
			_mutex.lock()
			_t_cur_weight = float(weights[i])
			_t_cur_msec = Time.get_ticks_msec()
			_mutex.unlock()
			var r: Resource = ResourceLoader.load(p)
			if r:
				if _warm_paths.has(p):
					_warm_refs.append(r)
				else:
					_loaded_refs.append(r)
		_mutex.lock()
		_t_weight_done += float(weights[i])
		_t_cur_weight = 0.0
		_mutex.unlock()
	if _aborted():
		return
	var main_res: Resource = ResourceLoader.load(root_path)
	if main_res:
		_loaded_refs.append(main_res)


## Tarama sırası (önce-derinlik, ziyaret sırası) -> yükleme sırası: yapraklar önce, kök sahne (main.tscn) hariç. Sahnenin KÖK betikleri (main.gd)
## preload zinciriyle neredeyse tüm betikleri derler - önce gelirse ilk adım tüm sürenin yarısını alıyordu (ölçüldü). Sona alınınca
## diğer betikler tek tek derlenir, bar daha eşit akar.
static func load_plan(scan_order: Array, root_scripts: Array, root_path: String = MAIN_SCENE_PATH) -> Array:
	var plan: Array = scan_order.duplicate()
	plan.reverse()
	plan.erase(root_path)
	for rp: String in root_scripts:
		if plan.has(rp):
			plan.erase(rp)
			plan.append(rp)
	return plan


func _aborted() -> bool:
	_mutex.lock()
	var a: bool = _abort
	_mutex.unlock()
	return a


func _loader_finished() -> bool:
	return _thread == null or not _thread.is_alive()


func _join_loader() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null


## 0..1: tarama ilk %5, yükleme kalan %95.
func _load_progress() -> float:
	if _loader_finished():
		return 1.0
	_mutex.lock()
	var scan_done: bool = _t_scan_done
	var seen: int = _t_scan_seen
	var pending: int = _t_scan_pending
	var total: float = _t_weight_total
	var done: float = _t_weight_done
	var cur_w: float = _t_cur_weight
	var cur_ms: int = _t_cur_msec
	_mutex.unlock()
	if not scan_done:
		return 0.05 * float(seen) / float(seen + pending + 1)
	if total <= 0.0:
		return 1.0
	if cur_w > 0.0:
		done += cur_w * minf(STEP_CREEP_MAX, (Time.get_ticks_msec() - cur_ms) / 1000.0 * STEP_CREEP_RATE)
	return 0.05 + 0.95 * clampf(done / total, 0.0, 1.0)


## "uid://...::Tür::res://yol" ya da "res://yol::Tür" -> res:// yolu.
static func _dep_path(d: String) -> String:
	var parts: PackedStringArray = d.split("::")
	var p: String = parts[parts.size() - 1] if parts.size() >= 3 else parts[0]
	if p.begins_with("uid://"):
		var id: int = ResourceUID.text_to_id(p)
		p = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
	return p


static func _estimate_weight(path: String) -> float:
	var ext: String = path.get_extension().to_lower()
	if not LOAD_WEIGHT_PER_KB.has(ext):
		return LOAD_WEIGHT_DEFAULT
	var bytes: int = _file_size(path)
	if bytes <= 0:
		return float(LOAD_WEIGHT_FALLBACK.get(ext, LOAD_WEIGHT_DEFAULT))
	return maxf(LOAD_WEIGHT_DEFAULT, float(LOAD_WEIGHT_PER_KB[ext]) * bytes / 1024.0)


## Kaynak dosyanın boyutu; export'ta betik/sahne yeniden adlandırılmışsa (".remap") hedef dosyanınki. Bulunamazsa 0.
static func _file_size(path: String) -> int:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f:
		return f.get_length()
	var remap: FileAccess = FileAccess.open(path + ".remap", FileAccess.READ)
	if remap == null:
		return 0
	var txt: String = remap.get_as_text()
	var i: int = txt.find("path=\"")
	if i < 0:
		return 0
	var target: String = txt.substr(i + 6, txt.find("\"", i + 6) - (i + 6))
	var t: FileAccess = FileAccess.open(target, FileAccess.READ)
	return t.get_length() if t else 0


## ---------------------------------------------------------------- varış + sahne geçişi

func _proceed() -> void:
	_proceeded = true
	var packed: PackedScene = load(main_scene_path) as PackedScene ## iş parçacığı yükledi - önbellekten
	status_label.text = "OYUN BAŞLIYOR"
	await _arrive()
	if not is_inside_tree() or _disconnected:
		return
	set_process(false)
	## Bu kare (karanlık sahne, bar %97) çizilsin; sonra görsel köke taşınıp sahne değişir - kurulum + ilk kare boyunca üstte kalır,
	## ilk kare hazır olunca bar %100 olur ve katman solar (loading_overlay.gd).
	## (frame_post_draw DEĞİL: başsız/--headless çalışmada hiç yayınlanmıyor - 2 süreçli testte host burada takıldı. Bir sonraki
	## karenin başı = bu kare çizildi.)
	await get_tree().process_frame
	if not is_inside_tree() or _disconnected:
		return
	if not _warm_refs.is_empty():
		var fw: Script = load(FX_WARMUP_PATH) as Script
		if fw:
			fw.call("adopt", _warm_refs)
		_warm_refs = []
	if is_instance_valid(_overlay):
		_overlay.reparent(get_tree().root)
		_overlay.call("begin_handoff", progress_bar)
	if packed:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(main_scene_path)


## Bar HANDOFF_VALUE'ya akar, sonra parti durur (idle_right, ayak yerinde). Ana iş parçacığı bu sırada serbest - animasyon akar;
## ardından gelen sahne kurulumu donması duran partinin karesinde geçer.
func _arrive() -> void:
	var tw := create_tween()
	tw.tween_property(progress_bar, "value", HANDOFF_VALUE, ARRIVE_RUN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_inside_tree():
		return
	_stop_party()


func _stop_party() -> void:
	for s: AnimatedSprite2D in _party:
		if is_instance_valid(s) and s.sprite_frames.has_animation("idle_right"):
			_play_on_foot(s, "idle_right")


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
