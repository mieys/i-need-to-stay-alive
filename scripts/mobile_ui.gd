extends RefCounted

## TELEFON UYUMU (kullanıcı isteği 2026-10-01): "mevcut arayüzü mobille uyumlu hale getir, duyarlayarak" - yeni arayüz
## tasarlanmaz; aynı ekranlar telefonda okunur/dokunulur boyuta büyür ve farklı en-boy oranlarına (20:9) oturur.
##
## Nasıl:
##  - Ekranlar: genel arayüz ölçeği DEĞİŞMEZ (1.0) - her ekran masaüstündeki 1920x1080 tasarımıyla telefona tam sığar.
##    İlk APK'da tüm arayüz 1.5x büyütülmüştü (content_scale_factor); 1080'e göre tasarlanmış ekranlar 720 satıra
##    sığmayıp kesildi (kullanıcı: "arayüz ekrana sığmıyor"). Artık:
##      * telefon HUD'u (yetenek sütunu, can/kalkan, envanter/altın, minimap, joystick, düğmeler) kendi içinde HUD_SCALE
##        kadar büyür (bkz. hud.gd _layout_mobile_hud),
##      * açılır ekranlar (FIT_LAYER_SCRIPTS) İÇERİKLERİ ekrana sığacak kadar büyütülüp ortalanır (mobile_menu_fit.gd) - kullanıcı
##        "arayüzleri büyüt ve doğru konumda olduklarından emin ol" dedi; her ekranın tasarımı aynı, sadece ölçeği.
##  - Çentik/kamera deliği: HUD kenar payları safe_margins() kadar içeri alınır.
##  - En-boy: KEEP yerine EXPAND -> telefonda siyah bant yok, geniş ekranda tuval yana uzar.
##  - Dünya: oyuncu kamerası CAMERA_CLOSER ile telefona göre yakınlaştırılır (bkz. camera_zoom).
##  - Performans: telefonda kare hızı 60'a sabitlenir (sınırsız çizim ısınıp yavaşlatıyor); uzak-yaratık LOD yarıçapı
##    telefonun dar görüş alanına göre küçülür (bkz. enemy.gd lod_near_radius_sq).
## Masaüstünde hiçbir şey değişmez. Bilgisayarda denemek için: Godot ... -- --mobile-ui

## Telefon HUD öğelerinin büyütmesi (yetenek düğmesi ~15 mm, can çubuğu okunur). 2026-10-01: 1.5 -> 1.7 ("arayüzleri büyüt").
const HUD_SCALE := 1.7
## Kullanıcı isteği (2026-10-01): "çok uzaktan görünüyor, kamera açısını yakınlaştıralım" (1.3), aynı gün "kamerayı %25
## yakınlaştır" (1.3 x 1.25). 1.0 = masaüstüyle aynı alan.
const CAMERA_CLOSER := 1.625
const FORCE_ARG := "--mobile-ui"
## Açılır ekranların büyütme sınırları ve ekran kenarı payı (tuval px).
const MENU_MAX_SCALE := 1.6
const MENU_MIN_SCALE := 0.6
const MENU_MARGIN := 20.0
## İçerikleri ekrana sığacak kadar büyütülen ekranlar (kökü CanvasLayer). Yeni bir modal ekran eklenirse buraya yaz.
## level_up_screen.gd / enchant_screen.gd / chest_menu.gd 2026-10-03'ten beri telefonda kendi yerleşimini kurar (bkz. CHOICE_*
## aşağıda) - listede YOK.
const FIT_LAYER_SCRIPTS: Array[String] = [
	"res://scripts/pause_menu.gd",
	"res://scripts/keybind_menu.gd",
	"res://scripts/graphics_settings_menu.gd",
	"res://scripts/victory_overlay.gd", ## zafer penceresi: 24 px yazı / 52 px düğme telefonda ~3 mm kalıyordu (2026-10-05)
	"res://scripts/records_screen.gd", ## ana menüdeki REKORLAR penceresi
]
## SEÇİM EKRANLARI (kullanıcı seçimi 2026-10-03, prototip "A - ekranı dolduran kartlar", tools/mobile_ui/proto_choice.gd):
## level atlama / yetenek evrimi / efsun kartları telefonda MenuFitter ile sığdırılmaz, kendi büyük yerleşimini kurar:
## aynı kart dokuları TAM sayı sanat pikseli katında (efsun kartı 3x -> 5x = 600x900; sığmazsa 4x), ekranın boyu kadar;
## karıştır / geç / geri sayım ekranın iki yanında dikey büyük düğmeler (başparmak bölgesi).
const CHOICE_SIDE_W := 220.0
const CHOICE_SIDE_PAD := 16.0
const CHOICE_TOP := 124.0 ## başlık (+ efsun özeti) altı
const CHOICE_BOTTOM := 1050.0
## Telefonda kart yazı boyları (m5x7 8'in katlarında keskin): başlık satırları ve gövde, büyükten küçüğe denenir.
const CHOICE_HEADER_FONTS := [48, 40, 32]
const CHOICE_BODY_FONTS := [48, 40, 32, 24]


## 3x kart boyutunun telefonda kaç katı çizileceği: 5/3 (5x sanat px) sığarsa o, yoksa 4/3, yoksa 1 (masaüstüyle aynı).
static func choice_card_scale(vp: Viewport, card3x: Vector2, count: int, gap: float) -> float:
	if not enabled or vp == null:
		return 1.0
	var view: Vector2 = vp.get_visible_rect().size
	var safe: Rect2 = safe_margins(vp)
	var room_w: float = view.x - safe.position.x - safe.size.x - 2.0 * (CHOICE_SIDE_W + 2.0 * CHOICE_SIDE_PAD)
	var room_h: float = view.y - CHOICE_TOP - (view.y - CHOICE_BOTTOM) - safe.position.y - safe.size.y
	for k: float in [5.0 / 3.0, 4.0 / 3.0]:
		if card3x.x * k * count + gap * (count - 1) <= room_w and card3x.y * k <= room_h:
			return k
	return 1.0


## Ekran kenarındaki dikey düğme yuvası (left: sol kenar). index/count: aynı kenarda alt alta kaçıncı / kaç tane.
static func choice_side_rect(vp: Viewport, left: bool, index: int, count: int, h: float) -> Rect2:
	var view: Vector2 = vp.get_visible_rect().size
	var safe: Rect2 = safe_margins(vp)
	var gap: float = 24.0
	var total: float = h * count + gap * (count - 1)
	var y: float = roundf((view.y - total) * 0.5) + index * (h + gap)
	var x: float = safe.position.x + CHOICE_SIDE_PAD if left else view.x - safe.size.x - CHOICE_SIDE_PAD - CHOICE_SIDE_W
	return Rect2(x, y, CHOICE_SIDE_W, h)


## Telefonda uzak-yaratık LOD yarıçapı (dünya px; masaüstü 1600). Kamera 3.25x yakın - görünen alanın yarısı ~370x170 px;
## 900, çok oyunculuda masaüstü oyuncunun görüş alanını (yarısı ~480x270) da rahat kapsar.
const MOBILE_LOD_RADIUS := 900.0

static var enabled: bool = false


static func detect() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") \
			or OS.get_cmdline_user_args().has(FORCE_ARG)


static func is_real_phone() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")


## GameManager._ready (autoload, her sahneden önce) çağırır.
static func apply(tree: SceneTree) -> void:
	enabled = detect()
	if not enabled or tree == null:
		return
	var root: Window = tree.root
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	if is_real_phone():
		## Proje vsync KAPALI (masaüstü tercihi); telefonda sınırsız kare çizmek pili ısıtıp işlemciyi yavaşlatıyor ->
		## dalgalı kasma. 60'a sabit, vsync açık.
		## project.godot display/window/frame_pacing/android/swappy_mode=0 (pipeline_forced_on) bu 60'a UYAR. Godot varsayılanı
		## 2 (auto_fps_auto_pipeline) FPS'i kendisi seçip ara sıra kaçan karelerde oyunu kalıcı 30'a indiriyordu (2026-10-03,
		## Galaxy S22: perf testinde kare ortalaması 11.8 ms = 85 FPS iken oyunda sabit 30 - bkz. perf_probe.gd).
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		## Kare sınırı (telefonda varsayılan 60) artık Grafik ayarlarında: UISound.fps_limit (bu autoload'dan SONRA yüklenir).
	## Ekran sığdırıcı ayrı dosyada (iç sınıflar bu dosyanın statik fonksiyonlarını göremiyor); load: döngüsel preload olmasın.
	var w: Node = load("res://scripts/mobile_menu_fit.gd").new()
	w.name = "MobileUIWatcher"
	root.add_child.call_deferred(w)
	tree.node_added.connect(w.on_node_added)


## Oyuncu kamerası (player.gd _ready): telefona özel yakınlaştırma.
static func camera_zoom(base: Vector2) -> Vector2:
	return base * CAMERA_CLOSER if enabled else base


## enemy.gd LOD: "yakın" sayılan yarıçapın karesi.
static func lod_near_radius_sq(desktop_sq: float) -> float:
	return MOBILE_LOD_RADIUS * MOBILE_LOD_RADIUS if enabled else desktop_sq


## Çentik/kamera deliği/yuvarlak köşe payları, tuval (mantıksal) px: Rect2(position = (sol, üst), size = (sağ, alt)).
## Sadece gerçek telefonda - masaüstünde (--mobile-ui denemesi) güvenli alan görev çubuğunu da sayar, sıfır döner.
static func safe_margins(vp: Viewport) -> Rect2:
	if not enabled or vp == null or not is_real_phone():
		return Rect2()
	var win: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Rect2()
	var k: float = vp.get_visible_rect().size.x / float(win.x)
	var l: float = clampf(float(safe.position.x), 0.0, win.x * 0.15)
	var t: float = clampf(float(safe.position.y), 0.0, win.y * 0.15)
	var r: float = clampf(float(win.x - safe.end.x), 0.0, win.x * 0.15)
	var b: float = clampf(float(win.y - safe.end.y), 0.0, win.y * 0.15)
	return Rect2(l * k, t * k, r * k, b * k)


## Bir ekranın GÖRÜNEN içeriğinin kutusu (katman-yerel px). Ekranı kaplayan karartma/kök düğümler ve sıfır boyutlu
## taşıyıcılar sayılmaz, içlerine inilir - böylece kutu sadece paneller/kartlar/düğmelerdir.
static func content_rect(root: Node, vp: Vector2) -> Rect2:
	var acc := Rect2()
	var has := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			var ctl := c as Control
			if ctl == null or not ctl.visible:
				continue
			var r: Rect2 = ctl.get_global_rect().abs()
			var big: bool = r.size.x >= vp.x * 0.85 and r.size.y >= vp.y * 0.85
			var tiny: bool = r.size.x < 4.0 or r.size.y < 4.0
			if big or tiny:
				stack.append(ctl)
			elif has:
				acc = acc.merge(r)
			else:
				acc = r
				has = true
	return acc if has else Rect2()


static func fit_scale(content: Vector2, vp: Vector2) -> float:
	if content.x < 1.0 or content.y < 1.0:
		return 1.0
	var s: float = minf((vp.x - 2.0 * MENU_MARGIN) / content.x, (vp.y - 2.0 * MENU_MARGIN) / content.y)
	return clampf(s, MENU_MIN_SCALE, MENU_MAX_SCALE)


## İçeriği kendi merkezi etrafında s kadar büyüten, sonra ekran paylarının içine iten dönüşüm.
static func fit_transform(content: Rect2, s: float, vp: Vector2) -> Transform2D:
	var size: Vector2 = content.size * s
	var pos: Vector2 = content.get_center() - size * 0.5
	pos.x = clampf(pos.x, MENU_MARGIN, maxf(MENU_MARGIN, vp.x - MENU_MARGIN - size.x))
	pos.y = clampf(pos.y, MENU_MARGIN, maxf(MENU_MARGIN, vp.y - MENU_MARGIN - size.y))
	return Transform2D(0.0, Vector2(s, s), 0.0, pos - content.position * s)
