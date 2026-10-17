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
## Sahne kurulumu (Main._ready + ilk kare) zorunlu ana iş parçacığı işidir (~1-3 sn) ve donar: o ana kadar kahraman yolun sonundaki
## kulübenin kapısına varır, içeri girer, sahne kararır (_arrive) - donma karanlık "OYUN BAŞLIYOR" karesinde geçer, canlı bir
## animasyonun ortasında değil. Görsel en üst katmanıyla (loading_overlay.gd) köke taşınır, oyunun ilk karesi hazır olunca bar %100
## olur ve katman solarak kaybolur.
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
const SceneParts := preload("res://scripts/loading_scene_parts.gd")
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

var _dots_timer: float = 0.0
var _dots_count: int = 0

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
## Testler kapatır (yükleyiciyi küçük bir sahneyle elle başlatırlar); oyunda hep main.tscn.
var autostart_loader: bool = true
var main_scene_path: String = MAIN_SCENE_PATH

## ---------------------------------------------------------------- EVE DÖNÜŞ SAHNESİ
## Kullanıcı isteği (2026-09-27): oyunun içeriğiyle, yapay zekâ görseli olmadan - "C - Kaçış" kovalamacası seçildi: doluluk çubuğu bir
## yol, seçili karakter doluluğun ucunda koşar, Kademe yaratıkları peşinden gelir. 2026-10-17 ("yükleme ekranının arkaplanı için daha iyi
## bir sahne hazırla"): arka plan artık bu kovalamacanın YERİ - karanlık ormandan çıkan toprak yol, yolun sonunda pencereleri yanan kütük
## kulübe (bar dolunca kahraman kapıya varır). Sanat SADECE harita tileset'lerinden, üretici tools/gen_yukleme_bg.py (640x360 tuval, x3;
## kahraman/yaratıklar da sanat pikseli başına 3 ekran pikseli). Canlı parçalar (rüzgârda sallanan ağaçlar + baca dumanı) kare şeritleri,
## yerleşimleri scripts/loading_scene_parts.gd'de (üretici yazar).
## Ayak hizası: her sprite'ın dokusundaki en alt dolu satır (gölgesiyle birlikte) patikanın üst kenarına oturur (bkz. _foot_offset).
const SCENE_DIR := "res://assets/ui/yukleme/"
## Ekran ortasına göre (1920x1080 taban): patika = doluluk çubuğu = sahnedeki yolun ortası (tuval y 213..227).
const PATH_RECT := Rect2(-720.0, 100.0, 1440.0, 40.0)
const PATH_INSET := 6.0 ## çubuk dolgusu çukurun içinde başlar (panel_style "inset" payı)
const HERO_SCALE := 3.0 ## 2.2368 taban karakter ölçeğinde (bkz. characters.gd "scale"); diğerleri oranlanır
const CHAR_BASE_SCALE := 2.2368375
const CREATURE_SCALE := 3.6 ## yaratığın kendi Sprite2D ölçeği x bu
const CHASERS: Array[String] = ["slime1", "slime2", "iskelet1", "zombie1", "slime3"]
const CHASER_GAP := 130.0
const CHASER_START_GAP := 170.0
const FOOT_SINK := 4.0 ## gölge patikanın üst kenarına biraz binsin (üstünde duruyor gibi)
const CREATURE_ROW_RIGHT := 3 ## enemy.gd ROW_RIGHT
## Varış: bar HANDOFF_VALUE'ya akar (kahraman kapıya koşar), sonra kahraman kapıda kaybolur ve sahne kararır.
const ARRIVE_RUN_TIME := 0.35
const ARRIVE_FADE_TIME := 0.4
const ARRIVE_DIM := Color(0.2, 0.2, 0.27)
const MOON_TINT := Color(0.9, 0.92, 1.0) ## karakterler gece sahnesine otursun (hafif ay ışığı), okunurluk kalsın
const TROUGH_COLOR := Color(0.17, 0.13, 0.1, 0.85)
const TROUGH_BORDER := Color(0.35, 0.27, 0.2)
const TIPS: Array[String] = [
	"Satıcının güvenli bölgesinde zaman durur - yaratıklar güçlenmez.",
	"F tuşu ruhani yeteneğini kullanır.",
	"Bir kademenin boss'u yaşadıkça yeni kademe başlamaz.",
	"Evin içindeyken yaratıklar sana saldıramaz.",
	"Elit sandıklar herkese birer epik eşya verir.",
	"Normal sandıklar oyunculara sırayla verilir.",
	"Hiç can hakkın kalmazsa 5 dakikada bir kalp yenilenir.",
	"Space tuşu ile etkileşime girersin.",
	"Q, E ve R yeteneklerin seviye atladıkça açılır.",
]

var _scene: Control = null ## arka plan + canlı parçalar (640x360 tuval, ekranı örtecek kadar ölçekli)
var _stage: Control = null ## kahraman + yaratıklar (ekran ortasına bağlı, patika ile aynı koordinat)
var _overlay: CanvasLayer = null
var _hero: AnimatedSprite2D = null
var _hero_foot: float = 0.0
## [Sprite2D, hframes, fps, foot offset (px, ölçekli), faz]
var _chasers: Array = []
var _anim_time: float = 0.0
var _chasers_running: bool = true


## Kare şeridinden oynayan sahne parçası (sallanan ağaç, baca dumanı); sadece kare değişince yeniden çizer.
class LiveSheet extends Control:
	var tex: Texture2D = null
	var frame_size: Vector2 = Vector2.ZERO
	var count: int = 1
	var fps: float = 10.0
	var _t: float = 0.0
	var _frame: int = -1

	func _init(t: Texture2D, fsz: Vector2, n: int, speed: float) -> void:
		tex = t
		frame_size = fsz
		count = maxi(1, n)
		fps = speed
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		size = fsz

	func _process(delta: float) -> void:
		_t += delta
		var f: int = int(_t * fps) % count
		if f != _frame:
			_frame = f
			queue_redraw()

	func _draw() -> void:
		if tex:
			draw_texture_rect_region(tex, Rect2(Vector2.ZERO, frame_size), Rect2(Vector2(maxi(_frame, 0) * frame_size.x, 0.0), frame_size))


func _ready() -> void:
	_build_chase_scene()
	status_label.text = "YÜKLENİYOR"
	progress_bar.value = 0.0
	NetworkManager.host_left_game.connect(_on_disconnected)
	NetworkManager.server_disconnected.connect(_on_disconnected)
	## Sahne (kahraman/yaratık kareleri) ana iş parçacığında yüklendi; bundan sonra ana iş parçacığı yüklemeye dokunmaz.
	if autostart_loader:
		start_loader()


func start_loader() -> void:
	_thread = Thread.new()
	_thread.start(_load_worker)


func _exit_tree() -> void:
	## Bağlantı kesilip menüye dönülürse: iş parçacığı sıradaki dosyadan önce durur; şu anki dosyanın bitmesi beklenir.
	_mutex.lock()
	_abort = true
	_mutex.unlock()
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null


func _build_chase_scene() -> void:
	## Tüm görsel en üst CanvasLayer'da (loading_overlay.gd) - geçişte köke taşınıp yeni sahnenin katmanlarının üstünde kalır.
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
	for n: String in ["Background", "StatusLabel", "ProgressBar"]:
		var c: Node = get_node_or_null(n)
		if c:
			c.reparent(holder, false)
	_build_backdrop(holder) ## sahne kendi gece ışığıyla çizildi - üstüne karartma örtüsü yok

	## Sahne (karakterler) ekranın ortasına bağlı bir Control'ün altında - patika ile aynı koordinat.
	_stage = Control.new()
	_stage.name = "ChaseStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_preset(Control.PRESET_CENTER)
	_stage.modulate = MOON_TINT
	holder.add_child(_stage)

	## Patika = doluluk çubuğu: adaçayı dolgu (eski yükleme çubuğunun rengi) + yolda kazılmış koyu çukur (2026-10-17: eski bej çukur
	## [UIKit inset] gece sahnesinde parlak bir şerit gibi duruyordu).
	var trough := StyleBoxFlat.new()
	trough.bg_color = TROUGH_COLOR
	trough.border_color = TROUGH_BORDER
	trough.set_border_width_all(3)
	trough.set_corner_radius_all(3)
	trough.anti_aliasing = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#88a24f")
	fill.border_color = Color("#4f652d")
	fill.set_border_width_all(3)
	fill.set_corner_radius_all(3)
	fill.anti_aliasing = false
	progress_bar.add_theme_stylebox_override("background", trough)
	progress_bar.add_theme_stylebox_override("fill", fill)
	_center_anchor(progress_bar, PATH_RECT)

	UIKit.style_label(status_label, 36, UIKit.C_CREAM, 8)
	_center_anchor(status_label, Rect2(PATH_RECT.position.x, PATH_RECT.end.y + 26.0, PATH_RECT.size.x, 44.0))
	var tip := Label.new()
	tip.name = "TipLabel"
	tip.text = "İpucu: " + TIPS[randi() % TIPS.size()]
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.style_label(tip, 24, Color("#e8d4b0"), 6)
	holder.add_child(tip)
	_center_anchor(tip, Rect2(PATH_RECT.position.x, PATH_RECT.end.y + 76.0, PATH_RECT.size.x, 32.0))

	## Karakterler çubuğun ÜSTÜNDE çizilsin.
	holder.move_child(_stage, holder.get_child_count() - 1)
	_build_hero()
	for i in range(CHASERS.size()):
		_build_chaser(CHASERS[i])
	_layout_chase(0.0)


## Arka plan (tscn'deki Background) + canlı parçalar tek bir tuval Control'ünde; tuval ekranı ÖRTECEK kadar ölçeklenir ve ortalanır
## (1920x1080'de tam x3 - patika yolun üstüne oturur).
func _build_backdrop(holder: Control) -> void:
	_scene = Control.new()
	_scene.name = "Scene"
	_scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_scene)
	holder.move_child(_scene, 0)
	_scene.size = SceneParts.CANVAS
	var bg: TextureRect = holder.get_node_or_null("Background") as TextureRect
	if bg:
		bg.reparent(_scene, false)
		bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.position = Vector2.ZERO
		bg.size = SceneParts.CANVAS
	for p: Array in SceneParts.PARTS:
		var tex: Texture2D = load(SCENE_DIR + str(p[0])) as Texture2D
		if tex == null:
			continue
		var s := LiveSheet.new(tex, p[2], int(p[3]), float(p[4]))
		_scene.add_child(s)
		s.position = p[1]
	holder.resized.connect(_fit_scene.bind(holder))
	_fit_scene(holder)


func _fit_scene(holder: Control) -> void:
	if not is_instance_valid(_scene) or holder.size.x < 1.0:
		return
	var s: float = maxf(holder.size.x / SceneParts.CANVAS.x, holder.size.y / SceneParts.CANVAS.y)
	_scene.scale = Vector2(s, s)
	_scene.position = ((holder.size - SceneParts.CANVAS * s) * 0.5).floor()


func _center_anchor(c: Control, r: Rect2) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.offset_left = r.position.x
	c.offset_right = r.end.x
	c.offset_top = r.position.y
	c.offset_bottom = r.end.y


func _build_hero() -> void:
	var def: Dictionary = Characters.get_def(GameManager.selected_char_id)
	var frames_path: String = str(def.get("frames", ""))
	if frames_path == "" or not ResourceLoader.exists(frames_path):
		return
	var frames: SpriteFrames = load(frames_path) as SpriteFrames
	var anim: String = "run_right" if frames.has_animation("run_right") else ("walk_right" if frames.has_animation("walk_right") else "")
	if anim == "":
		return
	_hero = AnimatedSprite2D.new()
	_hero.sprite_frames = frames
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var char_scale: float = (def.get("scale", Vector2.ONE * CHAR_BASE_SCALE) as Vector2).x
	_hero.scale = Vector2.ONE * HERO_SCALE * char_scale / CHAR_BASE_SCALE
	_stage.add_child(_hero)
	_hero.play(anim)
	_hero_foot = _foot_offset(frames.get_frame_texture(anim, 0)) * _hero.scale.y


func _build_chaser(id: String) -> void:
	var path: String = "res://scenes/creatures/enemy_%s.tscn" % id
	if not ResourceLoader.exists(path):
		return
	## Ağaca EKLENMEDEN örneklenir: _ready çalışmaz, sadece sahnedeki doku/hücre/ölçek okunur (tek kaynak = yaratık sahnesi).
	var e: Node = (load(path) as PackedScene).instantiate()
	var tex: Texture2D = e.get("walk_texture")
	var cell: int = int(e.get("cell_size"))
	var fps: float = float(e.get("sprite_fps"))
	var src: Sprite2D = e.get_node_or_null("Sprite2D") as Sprite2D
	var s: float = src.scale.x if src else 1.0
	e.free()
	if tex == null or cell <= 0:
		return
	var sp := Sprite2D.new()
	sp.texture = tex
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.hframes = maxi(1, int(tex.get_width() / cell))
	sp.vframes = 4
	sp.scale = Vector2.ONE * s * CREATURE_SCALE
	sp.frame = CREATURE_ROW_RIGHT * sp.hframes
	_stage.add_child(sp)
	var foot: float = _foot_offset(tex, Rect2i(0, CREATURE_ROW_RIGHT * cell, cell, cell)) * sp.scale.y
	_chasers.append([sp, sp.hframes, maxf(fps, 1.0), foot, randf() * 10.0])


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


## Kahraman doluluğun ucunda, yaratıklar arkasında sabit aralıkla; hepsinin ayağı patikanın üst kenarında.
func _layout_chase(ratio: float) -> void:
	var ground: float = PATH_RECT.position.y + FOOT_SINK
	var hx: float = PATH_RECT.position.x + PATH_INSET + (PATH_RECT.size.x - PATH_INSET * 2.0) * ratio
	if _hero:
		_hero.position = Vector2(hx, ground - _hero_foot).round()
	for i in range(_chasers.size()):
		var c: Array = _chasers[i]
		var sp: Sprite2D = c[0]
		sp.position = Vector2(hx - CHASER_START_GAP - i * CHASER_GAP, ground - float(c[3])).round()


func _animate_chasers(delta: float) -> void:
	if not _chasers_running:
		return
	_anim_time += delta
	for c: Array in _chasers:
		var sp: Sprite2D = c[0]
		var cols: int = c[1]
		sp.frame = CREATURE_ROW_RIGHT * cols + int((_anim_time + float(c[4])) * float(c[2])) % cols


func _process(delta: float) -> void:
	_animate_chasers(delta)
	_layout_chase(progress_bar.value / 100.0)
	if _proceeded or _disconnected:
		return

	if not _local_load_done:
		_elapsed += delta
		var target: float = _load_progress() * LOAD_SHARE
		progress_bar.value = move_toward(progress_bar.value, target, FILL_SPEED * delta)

		_dots_timer += delta
		if _dots_timer >= 0.3:
			_dots_timer = 0.0
			_dots_count = (_dots_count + 1) % 4
			status_label.text = "YÜKLENİYOR" + ".".repeat(_dots_count)

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
		_dots_timer += delta
		if _dots_timer >= 0.4:
			_dots_timer = 0.0
			_dots_count = (_dots_count + 1) % 4
			status_label.text = ("DİĞER OYUNCULAR BEKLENİYOR" if host_ready else "HOST BEKLENİYOR") + ".".repeat(_dots_count)

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
	if is_instance_valid(_overlay):
		_overlay.reparent(get_tree().root)
		_overlay.call("begin_handoff", progress_bar)
	if packed:
		get_tree().change_scene_to_packed(packed)
	else:
		get_tree().change_scene_to_file(main_scene_path)


## Kahraman yolun sonundaki kulübenin kapısına koşar (bar -> HANDOFF_VALUE), kapıda kaybolur, yaratıklar durur, sahne kararır.
## Ana iş parçacığı bu sırada serbest - animasyonlar akar; ardından gelen sahne kurulumu donması karanlık karede geçer.
func _arrive() -> void:
	var tw := create_tween()
	tw.tween_property(progress_bar, "value", HANDOFF_VALUE, ARRIVE_RUN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_inside_tree():
		return
	_chasers_running = false
	for c: Array in _chasers:
		(c[0] as Sprite2D).frame = CREATURE_ROW_RIGHT * int(c[1])
	var fade := create_tween().set_parallel(true)
	if _hero:
		fade.tween_property(_hero, "modulate:a", 0.0, ARRIVE_FADE_TIME * 0.6)
	for n: CanvasItem in [_scene, _stage]:
		if is_instance_valid(n):
			fade.tween_property(n, "modulate", ARRIVE_DIM, ARRIVE_FADE_TIME)
	await fade.finished


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
