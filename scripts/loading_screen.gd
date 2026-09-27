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
## parçacığında yapılıyor.
## GERÇEK İLERLEME (kullanıcı bildirimi 2026-09-27: "yükleme ekranı barı gerçek dolmayı yansıtmıyor doluyor ama oyun
## başlamıyor dolduğunda, tam dolduğunda başlamasını istiyorum"): eskiden bar 1.4 sn'de sahte doluyor, SONRA main.tscn tek
## seferde yükleniyordu (ölçüldü: ~6.2 sn bağımlılık yükleme - çoğu GDScript derleme - + ~0.5 sn kurulum + ~0.5 sn ilk kare),
## yani dolu barda donup bekliyordu. İkinci tur (kullanıcı: "bu sefer de donarak doluyor"): bağımlılıklar ana iş
## parçacığında yüklenince büyük betiklerin derlemesi ekranı donduruyordu (main.gd 2.2 sn, player.gd 1.6 sn). Yukarıdaki
## "iş parçacığında Parse Error" sorunu 2026-09-27'de tekrar ölçüldü ve ARTIK OLUŞMUYOR (main.tscn iş parçacığında temiz
## yüklendi, en uzun kare 20 ms). Şimdi: main.tscn'in bağımlılık ağacı taranır, her bağımlılık SIRAYLA tek bir arka plan
## iş parçacığında (load_threaded_request) yüklenir - ekran hiç donmaz, bar gerçek (türe göre ağırlıklı) ilerlemeyi gösterir
## (%95'e kadar); iş parçacığında yüklenemeyen olursa ana iş parçacığında yeniden denenir. Sonra görsel en üst katmanıyla
## (loading_overlay.gd) köke taşınır, sahne değişir; yeni sahnenin kurulumu + ilk karesi (zorunlu ana iş parçacığı, ~1 sn)
## sırasında kahraman patikanın sonunda durur, ilk kare hazır olunca bar %100 olur ve bir kare sonra oyun görünür.
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
const LOAD_BUDGET_MS := 24 ## kare başına en fazla bu kadar yükleme (animasyon akmaya devam etsin)
const LOAD_SHARE := 95.0 ## bağımlılıklar yüklenince barın ulaştığı yer; kalan %5 = sahne kurulumu + ilk kare
const HANDOFF_VALUE := 97.0 ## sahne değişirken (kurulum sürerken) gösterilen değer
const FILL_SPEED := 160.0 ## gösterilen değer hedefe en fazla bu hızla (%/sn) yaklaşır - önbellekten anında yüklenince zıplamasın
const NO_DEP_SCAN_EXT: Array[String] = ["png", "jpg", "webp", "svg", "wav", "mp3", "ogg", "ttf", "otf", "gdshader"]
const OverlayScript: GDScript = preload("res://scripts/loading_overlay.gd")
## İlerleme DOSYA SAYISINA göre değil yaklaşık maliyete göre: ölçümde (2026-09-27) sürenin ~%90'ı GDScript derlemesi
## (boyutla orantılı - player.gd/main.gd tek başına saniyeler), ~%10'u sahneler, dokular/sesler ihmal edilebilir. Ağırlık =
## dosya boyutu x türe göre çarpan (bayt başına); boyut okunamazsa türün varsayılanı.
const LOAD_WEIGHT_PER_KB := {"gd": 1.0, "tscn": 0.25, "scn": 0.25, "tres": 0.02, "res": 0.02}
const LOAD_WEIGHT_FALLBACK := {"gd": 20.0, "tscn": 10.0, "scn": 10.0}
const LOAD_WEIGHT_DEFAULT := 0.05
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

## ---------------------------------------------------------------- KAÇIŞ SAHNESİ
## Kullanıcı isteği (2026-09-27): "oyun yükleme ekranını oyunla uygun olacak bir şekilde yapay zeka içeriği olmayan birşey
## ile değiştir" - 4 prototipten "C - Kaçış" seçildi, düzeltmelerle ("slime ve fare barın üstünde uçuyor ve oyunun isminin
## üstte görünmesine gerek yok"). Eski arka plan (assets/ui/loading_bg.png, yapay zeka görseli) artık kullanılmıyor.
## SADECE oyunun kendi içeriği: arka plan = harita karolarından kurulan menü arka planı (assets/ui/menu_bg.png) gece tonunda;
## doluluk çubuğu bir patika - seçili karakter doluluğun ucunda koşar, Kademe yaratıkları peşinden gelir.
## Ayak hizası: her sprite'ın dokusundaki en alt dolu satır (gölgesiyle birlikte) patikanın üst kenarına oturur - kare
## tuvallerinin altındaki boşluk yüzünden yaratıklar havada duruyordu (bkz. _foot_offset).
const NIGHT_TINT := Color(0.05, 0.07, 0.16, 0.72)
## Ekran ortasına göre (1920x1080 taban): patika = doluluk çubuğu.
const PATH_RECT := Rect2(-720.0, 100.0, 1440.0, 40.0)
const PATH_INSET := 6.0 ## çubuk dolgusu çukurun içinde başlar (panel_style "inset" payı)
const HERO_SCALE := 3.0 ## 2.2368 taban karakter ölçeğinde (bkz. characters.gd "scale"); diğerleri oranlanır
const CHAR_BASE_SCALE := 2.2368375
const CREATURE_SCALE := 3.6 ## yaratığın kendi Sprite2D ölçeği x bu
const CHASERS: Array[String] = ["rat1", "slime1", "iskelet1", "zombie1", "slime3"]
const CHASER_GAP := 130.0
const CHASER_START_GAP := 170.0
const FOOT_SINK := 4.0 ## gölge patikanın üst kenarına biraz binsin (üstünde duruyor gibi)
const CREATURE_ROW_RIGHT := 3 ## enemy.gd ROW_RIGHT
const TIPS: Array[String] = [
	"Satıcının güvenli bölgesinde zaman durur - yaratıklar güçlenmez.",
	"F tuşu ruhani yeteneğini kullanır.",
	"Bir kademenin boss'u yaşadıkça yeni kademe başlamaz.",
	"Evin içindeyken yaratıklar sana saldıramaz.",
	"Seçkin sandıklar silahlarına efsun kazandırır.",
	"Hiç can hakkın kalmazsa 5 dakikada bir kalp yenilenir.",
	"Space tuşu ile etkileşime girersin.",
	"Q, E ve R yeteneklerin seviye atladıkça açılır.",
]

var _stage: Control = null
var _overlay: CanvasLayer = null
## Bağımlılık ağacı taraması + yükleme durumu (bkz. _step_loading).
var _scan_stack: Array = [MAIN_SCENE_PATH]
var _scan_seen: Dictionary = {}
var _load_order: Array = []
var _scan_done: bool = false
var _load_index: int = 0
var _loaded_refs: Array = [] ## önbellekte kalsınlar diye referans (sahne değişince main kendi referanslarını tutar)
var _weight_total: float = 0.0
var _weight_done: float = 0.0
## Şu an arka planda yüklenen bağımlılık (boş = yok), ağırlığı ve o adım sürerken barın süzülme oranı (0..STEP_CREEP_MAX).
var _req_path: String = ""
var _root_scripts: Array = []
var _weights: Dictionary = {}
var _req_weight: float = 0.0
var _req_creep: float = 0.0
const STEP_CREEP_MAX := 0.85 ## uzun bir adım (büyük betik) sürerken bar o adımın payının en fazla bu kadarına süzülür
const STEP_CREEP_RATE := 0.5 ## /sn
var _hero: AnimatedSprite2D = null
var _hero_foot: float = 0.0
## [Sprite2D, hframes, fps, foot offset (px, ölçekli)]
var _chasers: Array = []
var _anim_time: float = 0.0


func _ready() -> void:
	_build_chase_scene()
	status_label.text = "YÜKLENİYOR"
	progress_bar.value = 0.0
	NetworkManager.host_left_game.connect(_on_disconnected)
	NetworkManager.server_disconnected.connect(_on_disconnected)


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
	for n: String in ["Background", "Darken", "StatusLabel", "ProgressBar"]:
		var c: Node = get_node_or_null(n)
		if c:
			c.reparent(holder, false)
	var darken: ColorRect = holder.get_node_or_null("Darken") as ColorRect
	if darken:
		darken.color = NIGHT_TINT
	var bg: TextureRect = holder.get_node_or_null("Background") as TextureRect
	if bg:
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	## Sahne (karakterler) ekranın ortasına bağlı bir Control'ün altında - patika ile aynı koordinat.
	_stage = Control.new()
	_stage.name = "ChaseStage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_preset(Control.PRESET_CENTER)
	holder.add_child(_stage)

	## Patika = doluluk çubuğu: bej çukur + adaçayı dolgu (eski yükleme çubuğunun renkleri).
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#88a24f")
	fill.border_color = Color("#4f652d")
	fill.set_border_width_all(3)
	fill.set_corner_radius_all(3)
	fill.anti_aliasing = false
	progress_bar.add_theme_stylebox_override("background", UIKit.panel_style("inset"))
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


func _arrive_pose() -> void:
	set_process(false)
	if _hero:
		var idle: String = "idle_right" if _hero.sprite_frames.has_animation("idle_right") else ""
		if idle != "":
			_hero.play(idle)
		else:
			_hero.stop()
	for c: Array in _chasers:
		(c[0] as Sprite2D).frame = CREATURE_ROW_RIGHT * int(c[1])


func _animate_chasers(delta: float) -> void:
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
		_step_loading(delta)
		var target: float = _load_progress() * LOAD_SHARE
		progress_bar.value = move_toward(progress_bar.value, target, FILL_SPEED * delta)
		
		_dots_timer += delta
		if _dots_timer >= 0.3:
			_dots_timer = 0.0
			_dots_count = (_dots_count + 1) % 4
			status_label.text = "YÜKLENİYOR" + ".".repeat(_dots_count)
			
		if _scan_done and _req_path == "" and _load_index >= _load_order.size() and progress_bar.value >= LOAD_SHARE - 0.01:
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


## Bağımlılık ağacını tarar (önce, ana iş parçacığı - ucuz), sonra yapraklardan başlayarak her birini SIRAYLA arka plan iş
## parçacığında yükletir (bkz. dosya başı notu). Kare başına LOAD_BUDGET_MS - önbellekteki/hızlı olanlar aynı karede geçer.
func _step_loading(delta: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < LOAD_BUDGET_MS:
		if not _scan_done:
			if _scan_stack.is_empty():
				_scan_done = true
				_load_order.reverse() ## yapraklar önce
				_load_order.erase(MAIN_SCENE_PATH)
				## Sahnenin KÖK betikleri (main.gd) preload zinciriyle neredeyse tüm betikleri derler - önce gelirse ilk adım
				## tüm sürenin yarısını alıyordu (ölçüldü). Sona alınınca diğer betikler tek tek derlenir, bar daha eşit akar.
				for rp: String in _root_scripts:
					if _load_order.has(rp):
						_load_order.erase(rp)
						_load_order.append(rp)
				for lp: String in _load_order:
					_weights[lp] = _estimate_weight(lp)
					_weight_total += float(_weights[lp])
				continue
			var path: String = _scan_stack.pop_back()
			if _scan_seen.has(path):
				continue
			_scan_seen[path] = true
			if not NO_DEP_SCAN_EXT.has(path.get_extension().to_lower()):
				for d: String in ResourceLoader.get_dependencies(path):
					var dp: String = _dep_path(d)
					if path == MAIN_SCENE_PATH and dp.get_extension() == "gd":
						_root_scripts.append(dp)
					if dp != "" and not _scan_seen.has(dp):
						_scan_stack.append(dp)
			_load_order.append(path)
		elif _req_path != "":
			var prog: Array = []
			var st: int = ResourceLoader.load_threaded_get_status(_req_path, prog)
			if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				_req_creep = minf(STEP_CREEP_MAX, _req_creep + STEP_CREEP_RATE * delta)
				return ## bu kare iş parçacığını bekle - ekran akmaya devam eder
			var r: Resource = null
			if st == ResourceLoader.THREAD_LOAD_LOADED:
				r = ResourceLoader.load_threaded_get(_req_path)
			if r == null and ResourceLoader.exists(_req_path):
				push_warning("[LoadingScreen] iş parçacığında yüklenemedi, ana iş parçacığında deneniyor: " + _req_path)
				r = load(_req_path)
			if r:
				_loaded_refs.append(r)
			_weight_done += _req_weight
			_req_path = ""
		elif _load_index < _load_order.size():
			var p: String = _load_order[_load_index]
			_load_index += 1
			var w: float = _load_weight(p)
			if ResourceLoader.has_cached(p) or not ResourceLoader.exists(p):
				_weight_done += w
				continue
			if ResourceLoader.load_threaded_request(p, "", false) != OK:
				var r2: Resource = load(p)
				if r2:
					_loaded_refs.append(r2)
				_weight_done += w
				continue
			_req_path = p
			_req_weight = w
			_req_creep = 0.0
		else:
			return


## "uid://...::Tür::res://yol" ya da "res://yol::Tür" -> res:// yolu.
static func _dep_path(d: String) -> String:
	var parts: PackedStringArray = d.split("::")
	var p: String = parts[parts.size() - 1] if parts.size() >= 3 else parts[0]
	if p.begins_with("uid://"):
		var id: int = ResourceUID.text_to_id(p)
		p = ResourceUID.get_id_path(id) if ResourceUID.has_id(id) else ""
	return p


## 0..1: tarama ilk %5, yükleme kalan %95.
func _load_progress() -> float:
	if not _scan_done:
		var n: int = _scan_seen.size()
		return 0.05 * float(n) / float(n + _scan_stack.size() + 1)
	if _load_order.is_empty() or _weight_total <= 0.0:
		return 1.0
	var done: float = _weight_done + (_req_weight * _req_creep if _req_path != "" else 0.0)
	return 0.05 + 0.95 * clampf(done / _weight_total, 0.0, 1.0)


func _load_weight(path: String) -> float:
	return float(_weights.get(path, LOAD_WEIGHT_DEFAULT))


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


func _proceed() -> void:
	_proceeded = true
	var packed: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	progress_bar.value = HANDOFF_VALUE
	_layout_chase(HANDOFF_VALUE / 100.0)
	## Sahne kurulumu + ilk kare ana iş parçacığında (~1 sn, önlenemez): kahraman patikanın sonuna VARIP durur, yaratıklar
	## da durur - donma gibi değil "vardı" gibi görünsün.
	_arrive_pose()
	## Bu kare (bar %97) çizilsin; sonra görsel köke taşınıp sahne değişir - kurulum + ilk kare boyunca üstte kalır,
	## ilk kare hazır olunca bar %100 olur ve bir kare sonra silinir (loading_overlay.gd).
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
