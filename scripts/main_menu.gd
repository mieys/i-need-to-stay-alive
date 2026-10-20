extends Control

## Ana menü. 2026-10-16 YENİDEN (kullanıcı: "ana menü için 4 prototip, yapay zeka kullanma, hafif koyu tonlar" -> sol panel yerleşimi;
## arka plan için "haritanın bir parçası yerine yeni sade bir arka plan, oyunun asset'leriyle" -> 4 sade sahneden "Ocak Başı" seçildi):
##   arka plan = tools/proto_20261016/gen_ana_menu_bg.py --oyun -> assets/ui/ana_menu/ocak_basi.png (480x270, Ev içi karolarından elle
##   dizilmiş oda, ışık sadece şömine + ayaklı lambada), üstünde CANLI şömine ateşi (ocak_ates.png 6 kare) + şömineye dönük oturan parti
##   (gerçek sprite'lar, sit_ klipleri) + lambanın yanında uyuyan köpek; hepsi x4 tam kat.
##   sol: "D - Panelsiz Ateş Işığı" (2026-10-16, ilk düz koyu panel "ruhsuz ve sıradan" bulundu; 4 prototipten D seçildi): kutu yok,
##   sol taraf yumuşak kararır (sol_golge.png), büyük başlık + kiriş süsü, öğeler ikon + başlık + alt yazı, seçilide yanan mum.
## AYARLAR: ortak settings_screen.gd (duraklatma menüsüyle aynı "Ateş Işığı" ekranı, madde 234) - açıkken tabela + menü gizlenir. Davranış (sahne geçişleri, ayarlar, debug modu) eskisiyle AYNI.
## Telefon: mobile_menu_fit.gd "TitleSign" + "MenuPanel" adlı düğümleri ekrana sığdırır (adlar korunur).

const UiAnim := preload("res://scripts/ui_anim.gd")
const SettingsScreenScript := preload("res://scripts/settings_screen.gd")
const RecordsScreenScript := preload("res://scripts/records_screen.gd")
const SoulShopScreenScript := preload("res://scripts/soul_shop_screen.gd")
const DK := preload("res://scripts/menu_dark_kit.gd")
const LobbyUI := preload("res://scripts/menu_lobby_ui.gd")
const WC := preload("res://scripts/weapon_catalog.gd")
const PC := preload("res://scripts/pet_catalog.gd")
const MetaProgressScript: GDScript = preload("res://scripts/meta_progress.gd")
const RunRecordsScript: GDScript = preload("res://scripts/run_records.gd")
const MobileUIScript := preload("res://scripts/mobile_ui.gd")
const PK := preload("res://scripts/phone_menu_kit.gd")
const FM := preload("res://scripts/fire_menu_kit.gd")
const LastLoadout := preload("res://scripts/last_loadout.gd")

## Oyun adı (2026-10-04): "Lil'Slayers" (birleşik). Eski ad: "I NEED TO STAY ALIVE" (72 punto).
const TITLE := "LIL'SLAYERS"
const SCREEN := Vector2(1920, 1080)
const COL_W := 560.0
## Sahne: 480x270 tuval, x4 = 1920x1080. Konumlar tuval pikselinde (gen_ana_menu_bg.py bg_c ile aynı yerler).
const ART_K := 4.0
const FIRE_POS := Vector2(300, 70) ## şömine karesinin sol üstü (FIRE_X, base_y - 56)
const FIRE_FRAME := Vector2(48, 64)
const FIRE_FRAMES := 6
const FIRE_FPS := 8.0
const SCENE_TINT := Color(0.98, 0.78, 0.62) ## ateş ışığındaki karakterler (sahnenin sıcak ortamı)
## [karakter id, klip, ayak ortası (tuval px)] - şömineye dönük halıda (sit_up = sırtı bize), Şovalye yandan.
const PARTY := [[1, "sit_up", Vector2(300, 180)], [4, "sit_up", Vector2(324, 192)], [8, "sit_up", Vector2(348, 180)], [7, "sit_left", Vector2(374, 164)]]
const DOG := ["kopek", "sleep_down", Vector2(262, 214)]

var _settings_screen: Control = null
var _records_screen: Control = null

var _start_btn: Button
var _multiplayer_btn: Button
var _records_btn: Button
var _soul_shop_btn: Button
var _settings_btn: Button
var _exit_btn: Button
var _stage: Control = null
var _shard_label: Label = null


## Bir sayfadaki kareleri (yatay şerit) sırayla oynatan piksel-tam çizim (şömine ateşi).
class SheetAnim extends Control:
	var tex: Texture2D = null
	var frame_size: Vector2 = Vector2.ZERO
	var count: int = 1
	var fps: float = 8.0
	var k: float = 4.0
	var _t: float = 0.0

	func _init(t: Texture2D, fsz: Vector2, n: int, speed: float, scale_k: float) -> void:
		tex = t
		frame_size = fsz
		count = n
		fps = speed
		k = scale_k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		custom_minimum_size = fsz * scale_k

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if tex == null:
			return
		var i: int = int(_t * fps) % count
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, frame_size * k), Rect2(Vector2(i * frame_size.x, 0), frame_size))


## Gerçek SpriteFrames klibi, ayak ortası `foot`a oturur (tam kat k), altında piksel gölge; klip kendi hızında döner.
## sit_ klipleri "oturma HAREKETİ" (kare 0 ayakta -> son kare oturmuş; ride_ klipleri de son kareyi kullanır): döngüde oynarsa karakter
## kalkıp oturur -> sit_ için SON KARE sabit tutulur (hold).
class SceneSprite extends Control:
	var frames: SpriteFrames = null
	var anim: StringName = &"idle_down"
	var k: float = 4.0
	var hold: int = -1 ## >= 0: bu kare sabit
	var _t: float = 0.0
	var _used: Rect2i = Rect2i()
	var _fsize: Vector2 = Vector2.ZERO

	func _init(sf: SpriteFrames, clip: String, scale_k: float) -> void:
		frames = sf
		anim = StringName(clip) if sf != null and sf.has_animation(clip) else &"idle_down"
		k = scale_k
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if frames != null:
			if clip.begins_with("sit_"):
				hold = frames.get_frame_count(anim) - 1
			var img: Image = frames.get_frame_texture(anim, maxi(hold, 0)).get_image()
			if img.is_compressed():
				img.decompress()
			_used = img.get_used_rect()
			_fsize = Vector2(img.get_width(), img.get_height())
		custom_minimum_size = _fsize * k

	## Kontrolün sol üstü: ayak ortası foot (tuval px) olacak şekilde.
	func place_at(foot: Vector2) -> void:
		position = (foot - Vector2(_used.position.x + _used.size.x * 0.5, _used.end.y)).floor() * k ## sanat pikseli ızgarasında (arka planla hizalı)
		size = _fsize * k

	func _ready() -> void:
		set_process(hold < 0)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if frames == null:
			return
		var n: int = frames.get_frame_count(anim)
		var spd: float = frames.get_animation_speed(anim)
		var i: int = hold if hold >= 0 else int(_t * spd) % maxi(1, n)
		var sw: float = maxf(12.0, _used.size.x * 0.7)
		var cx: float = _used.position.x + _used.size.x * 0.5
		draw_rect(Rect2((cx - sw * 0.5) * k, (_used.end.y - 1) * k, sw * k, 2 * k), Color(0, 0, 0, 0.32))
		draw_texture_rect(frames.get_frame_texture(anim, i), Rect2(Vector2.ZERO, _fsize * k), false)


func _ready() -> void:
	DisplayServer.window_set_title("Lil'Slayers")
	theme = MenuKit.theme()
	_build_scene()
	if MobileUIScript.enabled:
		_build_phone_menu()
	else:
		_build_left_panel()
	UISound.connect_all_buttons(self)
	_start_btn.grab_focus()


## ------------------------------------------------------------------ arka plan sahnesi
## Tam ekran katman (telefonda RootFitter ekranın tamamına yayar) + içinde 1920x1080 sahne; sahne katmanı ÖRTECEK kadar büyütülür
## (KEEP_ASPECT_COVERED gibi) - ateş/parti arka planla birlikte ölçeklenir, hizası bozulmaz.
func _build_scene() -> void:
	var layer := Control.new()
	layer.name = "BackgroundImage"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.clip_contents = true
	add_child(layer)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_stage)
	_stage.size = SCREEN
	_stage.add_child(scene_background())
	var shade := TextureRect.new() ## sol menünün okunurluğu: yumuşak karartma (ışık değil), sahneyle birlikte ölçeklenir
	shade.texture = load(FM.SHADE_PATH)
	shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fire := SheetAnim.new(load("res://assets/ui/ana_menu/ocak_ates.png"), FIRE_FRAME, FIRE_FRAMES, FIRE_FPS, ART_K)
	_stage.add_child(fire)
	fire.position = FIRE_POS * ART_K
	fire.size = FIRE_FRAME * ART_K
	var pet_spec: Array = PC.FRAMES.get(DOG[0], [])
	if not pet_spec.is_empty():
		_add_scene_sprite(load(str(pet_spec[0])) as SpriteFrames, str(DOG[1]), DOG[2])
	var party: Array = PARTY.duplicate()
	party.sort_custom(func(a: Array, b: Array) -> bool: return (a[2] as Vector2).y < (b[2] as Vector2).y)
	for p: Array in party:
		_add_scene_sprite(load(str(Characters.get_def(int(p[0])).get("frames", ""))) as SpriteFrames, str(p[1]), p[2])
	_stage.add_child(shade)
	shade.position = Vector2.ZERO
	shade.size = SCREEN
	layer.resized.connect(_fit_stage.bind(layer))
	_fit_stage(layer)


## Sahnenin arka plan resmi (SCREEN boyutunda, sahne katmanının ilk çocuğu). Doku IŞIKSIZ taban; şömine + lamba ışığı ve kenar karartması
## ocak_basi_isik.gdshader'da ekran pikselinde yumuşak hesaplanır (2026-10-20: pişmiş Bayer basamakları "pixel pixel" bulundu).
## menu_hearth_bg.gd de bunu kullanır.
static func scene_background() -> TextureRect:
	var bg := TextureRect.new()
	bg.name = "SceneBg"
	bg.texture = load("res://assets/ui/ana_menu/ocak_basi.png")
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ocak_basi_isik.gdshader")
	mat.set_shader_parameter("lamp_tex", load("res://assets/ui/ana_menu/ocak_lamba.png"))
	bg.material = mat
	bg.position = Vector2.ZERO
	bg.size = SCREEN
	return bg


func _add_scene_sprite(sf: SpriteFrames, clip: String, foot: Vector2) -> void:
	if sf == null:
		return
	var s := SceneSprite.new(sf, clip, ART_K)
	_stage.add_child(s)
	s.place_at(foot)
	s.modulate = SCENE_TINT


func _fit_stage(layer: Control) -> void:
	if _stage == null or layer.size.x < 1.0:
		return
	var s: float = maxf(layer.size.x / SCREEN.x, layer.size.y / SCREEN.y)
	_stage.scale = Vector2(s, s)
	_stage.position = ((layer.size - SCREEN * s) * 0.5).floor()


## ------------------------------------------------------------------ sol menü: "D - Panelsiz Ateş Işığı" (2026-10-16, kullanıcı seçti)
## Kutu yok: sahnenin sol tarafı yumuşak kararır (sol_golge.png, sahne katmanında), üstte büyük başlık + kiriş süsü ayracı, öğeler
## ikon + 48 punto başlık + alt yazı. Seçili öğe (fare üstünde = odak; kumanda/klavye de odakla gezer) altın yazı + yanında YANAN MUM.
const ITEM_ICON := 48.0
const ITEM_H := 92.0
const C_GOLD := Color("#f4c56e")
const C_GOLD_DIM := Color("#e2c08a")
const C_CREAM := Color("#efe2c6")
const C_SUB := Color("#b09878")
const C_TAG := Color("#c8b28e")
const C_RED := Color("#dc7f60")

var _items: Array = [] ## [{btn, title, sub, candle, danger}]


## İki karelik mum alevi (seçili öğenin yanında).
class Candle extends Control:
	const COL := 3 ## Candles.png sütunu (32x32); satır 0/1 = iki alev karesi
	var tex: Texture2D = null
	var _t: float = 0.0

	func _init(t: Texture2D) -> void:
		tex = t
		custom_minimum_size = Vector2(64, 64)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if tex == null:
			return
		var row: int = int(_t * 4.0) % 2
		draw_texture_rect_region(tex, Rect2(Vector2.ZERO, Vector2(64, 64)), Rect2(Vector2(COL * 32, row * 32), Vector2(32, 32)))


func _lbl(t: String, fs: int, c: Color) -> Label:
	var l := DK.lbl(t, fs, c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


## Öğe ikonu: yüz / üç yüz / kıymık / eşya ikonu; hepsi aynı genişlikte kutu (yazılar hizalı kalsın).
func _item_icon(spec: String) -> Control:
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(ITEM_ICON * 1.6, ITEM_ICON)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match spec:
		"face1":
			box.add_child(DK.icon(_face_tex(1), ITEM_ICON))
		"faces":
			var c := Control.new()
			c.custom_minimum_size = Vector2(ITEM_ICON * 1.6, ITEM_ICON)
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for i in 3:
				var f: Control = DK.icon(_face_tex([4, 8, 1][i]), ITEM_ICON * 0.75)
				f.position = Vector2(i * ITEM_ICON * 0.42, ITEM_ICON * 0.25 if i == 1 else 0.0)
				c.add_child(f)
			box.add_child(c)
		"shard":
			box.add_child(DK.ShardIcon.new(ITEM_ICON * 0.66))
		_:
			box.add_child(DK.icon(load(spec) as Texture2D, ITEM_ICON))
	return box


func _face_tex(id: int) -> Texture2D:
	return LobbyUI.face_texture(str(Characters.get_def(id).get("portrait", "")))


func _record_text() -> String:
	var data: Dictionary = RunRecordsScript.load_all()
	if int(data.get("runs", 0)) <= 0:
		return "Henüz koşu yok"
	var t: int = int(float(data.get("best_time", 0.0)))
	return "En iyi: Kademe %d · %d:%02d" % [int(data.get("best_tier", 0)), t / 60, t % 60]


## Bir menü öğesi: görünmez düğme (tıklama/odak) + içinde mum yuvası, ikon, başlık, alt yazı.
func _menu_item(title: String, sub: String, icon_spec: String, danger: bool = false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(COL_W, ITEM_H)
	b.flat = true
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var row := DK.h(14)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	var candle := Candle.new(load("res://harita/Ev içi/Candles.png") as Texture2D)
	candle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	candle.visible = false
	var slot := CenterContainer.new()
	slot.custom_minimum_size = Vector2(64, 64)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(candle)
	row.add_child(slot)
	row.add_child(_item_icon(icon_spec))
	var v := DK.v(-2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var tl := _lbl(title, DK.FS_TITLE, C_RED if danger else C_CREAM)
	v.add_child(tl)
	var sl := _lbl(sub, DK.FS_LABEL, C_SUB)
	v.add_child(sl)
	row.add_child(v)
	b.add_child(row)
	var it := {"btn": b, "title": tl, "sub": sl, "candle": candle, "danger": danger, "row": row}
	_items.append(it)
	## Fare üstüne gelmek = odak: tek bir "seçili" görünümü (kumanda/klavyeyle aynı).
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_entered.connect(_set_item_selected.bind(it, true))
	b.focus_exited.connect(_set_item_selected.bind(it, false))
	return b


func _set_item_selected(it: Dictionary, on: bool) -> void:
	var tl: Label = it["title"]
	(it["candle"] as Control).visible = on
	UiAnim.slide_x(it["row"] as Control, 12.0 if on else 0.0) ## seçili öğe hafifçe öne (sağa) çıkar, madde 200
	if on:
		tl.add_theme_color_override("font_color", C_GOLD)
		tl.add_theme_color_override("font_outline_color", Color(0.35, 0.16, 0.04, 1))
		tl.add_theme_constant_override("outline_size", 6)
		(it["sub"] as Label).add_theme_color_override("font_color", C_GOLD_DIM)
	else:
		tl.add_theme_color_override("font_color", C_RED if bool(it["danger"]) else C_CREAM)
		tl.add_theme_constant_override("outline_size", 0)
		(it["sub"] as Label).add_theme_color_override("font_color", C_SUB)


func _build_left_panel() -> void:
	var logo := DK.v(0)
	logo.name = "TitleSign"
	var lh := DK.h(14)
	var left_ic: CenterContainer = DK.icon(WC.icon("dagger"), 64)
	if left_ic.get_child_count() > 0:
		(left_ic.get_child(0) as TextureRect).flip_h = true
	lh.add_child(left_ic)
	var title := DK.lbl(TITLE, 96, C_GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.03, 1))
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 8)
	title.add_theme_constant_override("shadow_outline_size", 16)
	lh.add_child(title)
	lh.add_child(DK.icon(WC.icon("fire_staff"), 64))
	logo.add_child(lh)
	logo.add_child(_lbl("Hayatta kal. Birlikte.", DK.FS_BODY, C_TAG))
	logo.add_child(DK.sp(0, 14))
	var trim := TextureRect.new()
	trim.texture = load("res://assets/ui/ana_menu/kiris_suslu.png")
	trim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trim.stretch_mode = TextureRect.STRETCH_TILE
	trim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trim.custom_minimum_size = Vector2(480, 48)
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(trim)
	add_child(logo)
	MenuKit.place(logo, Vector2(40, 80), Vector2(0, 0))

	var v := DK.v(0)
	v.name = "MenuPanel"
	_start_btn = _menu_item("TEK OYUNCULU", "Tek başına hayatta kal", "face1")
	_multiplayer_btn = _menu_item("ÇOK OYUNCULU", "Oda kur ya da arkadaşına katıl", "faces")
	_soul_shop_btn = _menu_item("RUH MAĞAZASI", "", "shard")
	_shard_label = _items[_items.size() - 1]["sub"]
	_refresh_shards()
	_records_btn = _menu_item("REKORLAR", _record_text(), "res://assets/items/kralin_kadehi.png")
	_settings_btn = _menu_item("AYARLAR", "Ses, görüntü, tuşlar", "res://assets/items/tornavida.png")
	_exit_btn = _menu_item("ÇIKIŞ", "Masaüstüne dön", "res://assets/items/ruzgar_yuruyen_cizmeleri.png", true)
	for b: Button in [_start_btn, _multiplayer_btn, _soul_shop_btn, _records_btn, _settings_btn, _exit_btn]:
		v.add_child(b)
	add_child(v)
	MenuKit.place(v, Vector2(40, 320), Vector2(COL_W, 0))
	UiAnim.cascade(v, 0.05) ## menü öğeleri sırayla belirir (madde 200)
	_start_btn.pressed.connect(_on_start_pressed)
	_multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	_soul_shop_btn.pressed.connect(_on_soul_shop_pressed)
	_records_btn.pressed.connect(_on_records_pressed)
	_settings_btn.pressed.connect(_on_settings_pressed)
	_exit_btn.pressed.connect(_on_exit_pressed)

	## Alt: şömine başındaki parti yüzleri + en iyi koşu.
	var bot := DK.h(10)
	bot.name = "PartyLine"
	for p: Array in PARTY:
		bot.add_child(DK.icon(_face_tex(int(p[0])), 48))
	bot.add_child(DK.sp(6))
	bot.add_child(_lbl(_record_text(), DK.FS_LABEL, C_TAG))
	add_child(bot)
	MenuKit.place(bot, Vector2(104, SCREEN.y - 132.0), Vector2(0, 48))
	_create_debug_mode_button()


func _refresh_shards() -> void:
	if is_instance_valid(_shard_label):
		_shard_label.text = "Kilit aç, kalıcı geliştir" if MobileUIScript.enabled else "%d kıymık · kilit aç" % MetaProgressScript.shards()
	if is_instance_valid(_ph_shard_value):
		_ph_shard_value.text = str(MetaProgressScript.shards())


## ------------------------------------------------------------------ telefon
## TELEFON (2026-10-19; kullanıcı seçimi prototip S: ana menü = A düzeni + B "Gece Sıvası" renkleri, mobil_proto.gd A_ana_menu): sahne
## (şömine, parti, köpek) aynı; solda yumuşak lacivert gölge + başlık + 5 iri öğe (seçili = altın zemin + sol şerit + yanan mum,
## diğerleri soluk elmas), sağ üstte Ruh Kıymığı, sağ altta "Son seçim" kartı + HIZLI BAŞLA (son tek oyunculu seçimle doğrudan
## oyuna, last_loadout.gd). ÇIKIŞ telefonda yok (sistem geri / ana ekran). MenuFitter bu sahneyi artık büyütmez (PK.fit).
const PH_ITEM_W := 900.0
const PH_ITEM_H := 132.0
const PH_ITEMS_TOP := 352.0
const PH_CARD_W := 700.0
var _ph_items: Array[Button] = []
var _ph_shard_value: Label = null


func _build_phone_menu() -> void:
	var root := Control.new()
	root.name = "PhoneMenu"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	PK.fit(root)
	var shade := FM.StepShade.new()
	shade.name = "PhoneShade"
	shade.col = Color(PK.DIMBG, 0.9)
	shade.x0 = 700.0
	shade.step_w = 80.0
	shade.steps = 10
	root.add_child(shade)
	## Başlık: oyunun adı + slogan + kiriş süsü (masaüstü tabelasıyla aynı parçalar, B renkleri).
	var logo := DK.v(0)
	logo.name = "TitleSign"
	var lh := DK.h(14)
	var left_ic: CenterContainer = DK.icon(WC.icon("dagger"), 64)
	if left_ic.get_child_count() > 0:
		(left_ic.get_child(0) as TextureRect).flip_h = true
	lh.add_child(left_ic)
	var title := DK.lbl(TITLE, 96, DK.C_ACCENT)
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.08, 1))
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_y", 8)
	lh.add_child(title)
	lh.add_child(DK.icon(WC.icon("fire_staff"), 64))
	logo.add_child(lh)
	logo.add_child(PK.lbl("Hayatta kal. Birlikte.", PK.FS_SMALL, DK.C_DIM))
	logo.add_child(DK.sp(0, 14))
	var trim := TextureRect.new()
	trim.texture = load("res://assets/ui/ana_menu/kiris_suslu.png")
	trim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	trim.stretch_mode = TextureRect.STRETCH_TILE
	trim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	trim.custom_minimum_size = Vector2(480, 48)
	trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(trim)
	logo.position = Vector2(PK.SIDE + 8.0, 40.0)
	root.add_child(logo)
	## Öğeler.
	var v := DK.v(8)
	v.name = "MenuPanel"
	v.position = Vector2(PK.SIDE, PH_ITEMS_TOP)
	var shard_icon := DK.ShardIcon.new(52.0)
	_start_btn = _ph_item("TEK OYUNCU", "Tek başına hayatta kal", PK.glyph(PK.G_PLAY, DK.C_TEXT, 7))
	_multiplayer_btn = _ph_item("ÇOK OYUNCU", "İnternet ya da LAN odası", PK.glyph(PK.G_USERS, DK.C_TEXT, 7))
	_soul_shop_btn = _ph_item("RUH MAĞAZASI", "Kilit aç, kalıcı geliştir", shard_icon)
	_records_btn = _ph_item("REKORLAR", "En iyiler ve başarımlar", PK.glyph(PK.G_TROPHY, DK.C_TEXT, 7))
	_settings_btn = _ph_item("AYARLAR", "Ses, grafik, dokunmatik", PK.glyph(PK.G_GEAR, DK.C_TEXT, 7))
	for b: Button in [_start_btn, _multiplayer_btn, _soul_shop_btn, _records_btn, _settings_btn]:
		v.add_child(b)
	root.add_child(v)
	_start_btn.pressed.connect(_on_start_pressed)
	_multiplayer_btn.pressed.connect(_on_multiplayer_pressed)
	_soul_shop_btn.pressed.connect(_on_soul_shop_pressed)
	_records_btn.pressed.connect(_on_records_pressed)
	_settings_btn.pressed.connect(_on_settings_pressed)
	UiAnim.cascade(v, 0.05)
	## Sağ üst: Ruh Kıymığı.
	var chip := PK.inset(0.85, 0.0, DK.C_LINE)
	chip.name = "ShardChip"
	(chip.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 20
	(chip.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 24
	var ch := DK.h(14)
	ch.add_child(DK.ShardIcon.new(40.0))
	_ph_shard_value = PK.lbl(str(MetaProgressScript.shards()), PK.FS_BODY, PK.C_SOUL)
	ch.add_child(_ph_shard_value)
	chip.add_child(ch)
	chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chip.offset_right = -PK.SIDE
	chip.offset_left = -PK.SIDE - 10.0
	chip.offset_top = PK.TOP + 8.0
	chip.offset_bottom = PK.TOP + 8.0 + 88.0
	root.add_child(chip)
	## Sağ alt: son seçim + HIZLI BAŞLA.
	var lo: Dictionary = LastLoadout.load_valid()
	var card := PK.panel(0.85, 16.0)
	card.name = "LastPick"
	card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	card.offset_left = -(PK.SIDE + PH_CARD_W)
	card.offset_right = -PK.SIDE
	card.offset_top = -(PK.BOTTOM + PK.BTN_H + 20.0 + 136.0)
	card.offset_bottom = -(PK.BOTTOM + PK.BTN_H + 20.0)
	var crow := DK.h(20)
	crow.add_child(PK.portrait(_face_tex(int(lo["char"])), 104.0))
	var cv := DK.v(0)
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_child(PK.lbl("Son seçim", PK.FS_SMALL, DK.C_DIM))
	var sl := PK.lbl(LastLoadout.summary(lo), PK.FS_BODY, DK.C_TEXT)
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cv.add_child(sl)
	crow.add_child(cv)
	card.add_child(crow)
	root.add_child(card)
	var quick := PK.button("HIZLI BAŞLA", "primary", PK.FS_TITLE, PK.G_PLAY, PH_CARD_W, PK.BTN_H)
	quick.name = "QuickStart"
	quick.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	quick.offset_left = -(PK.SIDE + PH_CARD_W)
	quick.offset_right = -PK.SIDE
	quick.offset_top = -(PK.BOTTOM + PK.BTN_H)
	quick.offset_bottom = -PK.BOTTOM
	quick.pressed.connect(_on_quick_start_pressed)
	root.add_child(quick)
	_create_debug_mode_button()
	var dbg: Control = get_node_or_null("DebugButton") as Control
	if dbg: ## sol alt köşe, öğelerin altında kalmasın
		dbg.reparent(root, false)
		dbg.position = Vector2(PK.SIDE, 1080.0 - 64.0)


## Öğe: görünmez düğme + seçili zemini (altın %14 + 8 px sol şerit) + mum (seçili) / elmas (diğerleri) + 64 px simge + başlık / alt yazı.
func _ph_item(title: String, sub: String, icon: Control) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(PH_ITEM_W, PH_ITEM_H)
	b.flat = true
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var sel := Panel.new()
	sel.name = "Sel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(DK.C_ACCENT, 0.14)
	sb.border_width_left = 8
	sb.border_color = DK.C_ACCENT
	sel.add_theme_stylebox_override("panel", sb)
	sel.set_anchors_preset(Control.PRESET_FULL_RECT)
	sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel.visible = false
	b.add_child(sel)
	var candle := Candle.new(load("res://harita/Ev içi/Candles.png") as Texture2D)
	candle.scale = Vector2(1.5, 1.5)
	candle.position = Vector2(24, 18)
	candle.visible = false
	b.add_child(candle)
	var dia := PK.glyph(PK.G_DIAMOND, Color(DK.C_DIM, 0.6), 5)
	dia.position = (Vector2(72, PH_ITEM_H * 0.5) - dia.custom_minimum_size * 0.5).floor()
	dia.size = dia.custom_minimum_size
	b.add_child(dia)
	var ib := CenterContainer.new()
	ib.position = Vector2(192 - 40, PH_ITEM_H * 0.5 - 40)
	ib.size = Vector2(80, 80)
	ib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ib.add_child(icon)
	b.add_child(ib)
	var tl := PK.lbl(title, PK.FS_TITLE, DK.C_TEXT)
	tl.position = Vector2(264, 8)
	tl.size = Vector2(620, 72)
	b.add_child(tl)
	var sl := PK.lbl(sub, PK.FS_SMALL, DK.C_DIM)
	sl.position = Vector2(264, 76)
	sl.size = Vector2(620, 44)
	b.add_child(sl)
	if title == "RUH MAĞAZASI":
		_shard_label = sl
	b.set_meta("ph", {"sel": sel, "candle": candle, "dia": dia, "icon": icon, "title": tl})
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_entered.connect(_ph_item_selected.bind(b, true))
	b.focus_exited.connect(_ph_item_selected.bind(b, false))
	_ph_items.append(b)
	return b


func _ph_item_selected(b: Button, on: bool) -> void:
	var it: Dictionary = b.get_meta("ph")
	(it["sel"] as Control).visible = on
	(it["candle"] as Control).visible = on
	(it["dia"] as Control).visible = not on
	(it["title"] as Label).add_theme_color_override("font_color", DK.C_ACCENT if on else DK.C_TEXT)
	var ic: Control = it["icon"]
	if ic is PK.PGlyph:
		(ic as PK.PGlyph).set_color(DK.C_ACCENT if on else DK.C_TEXT)


## HIZLI BAŞLA: son tek oyunculu seçimle (kilitliler varsayılana çekilmiş) doğrudan yükleme ekranına - karakter seçimi atlanır.
func _on_quick_start_pressed() -> void:
	var lo: Dictionary = LastLoadout.load_valid()
	LastLoadout.apply(lo)
	get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")


## Kullanıcı isteği (2026-09-24): "bu modun otomatik olarak açıldığı bir debugmode haritası
## seçeneği" - ana ekrandaki büyük TEK OYUNCULU/ÇOK OYUNCULU yığınıyla YARIŞMASIN diye küçük,
## sol-alt köşede ayrı bir buton (bkz. scripts/debug_menu.gd/hud.gd/GameManager.
## debug_mode_unlocked notu). Normal "Tek Oyunculu" akışının BİREBİR aynısı, tek fark
## debug_mode_unlocked'ı sahne değişmeden ÖNCE true yapması - hud.gd _setup_debug_mode() bunu
## okuyup DEBUG butonunu baştan görünür kurar, chate "baykusseverim" yazmaya gerek kalmaz.
func _create_debug_mode_button() -> void:
	var btn := Button.new()
	btn.name = "DebugButton"
	btn.text = "Debug Modu"
	btn.add_theme_font_override("font", DK.font())
	btn.add_theme_font_size_override("font_size", DK.FS_LABEL)
	btn.custom_minimum_size = Vector2(168, 40)
	DK.style_button_colors(btn, Color(0.1, 0.07, 0.05, 0.7), Color("#45372a"), C_SUB, C_GOLD, 2, 4, 6.0)
	btn.pressed.connect(_on_debug_mode_pressed)
	add_child(btn)
	MenuKit.place(btn, Vector2(40, SCREEN.y - 64.0), btn.custom_minimum_size)


func _on_debug_mode_pressed() -> void:
	NetworkManager.disconnect_from_room()
	GameManager.reset()
	GameManager.debug_mode_unlocked = true
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


func _on_start_pressed() -> void:
	NetworkManager.disconnect_from_room()
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


func _on_multiplayer_pressed() -> void:
	## 2026-10-11 lobi sistemi: önce oda listesi (oda kur / şifreli odaya gir), sonra oda lobisi, sonra karakter seçimi.
	NetworkManager.disconnect_from_room(false)
	get_tree().change_scene_to_file("res://scenes/room_browser.tscn")


## Kullanıcı isteği: "oyunun başlangıç ekranına çıkış düğmesi ekle".
func _on_exit_pressed() -> void:
	get_tree().quit()


## Rekorlar + başarımlar (madde 250, "A - Ateş Işığı"): ayarlarla AYNI desen - menünün tabelası/öğeleri gizlenir, ekran tasarım boyutunda.
func _on_records_pressed() -> void:
	if is_instance_valid(_records_screen) or is_instance_valid(_settings_screen):
		return
	_set_menu_parts_visible(false)
	_records_screen = RecordsScreenScript.new()
	_records_screen.closed.connect(func() -> void:
		_records_screen = null
		_set_menu_parts_visible(true)
		if is_instance_valid(_records_btn):
			_records_btn.grab_focus.call_deferred()
	)
	add_child(_records_screen)
	_records_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_records_screen.position = Vector2.ZERO
	_records_screen.size = SCREEN


## Ruh Mağazası (bkz. soul_shop_screen.gd, meta_progress.gd): koşularda kazanılan Ruh Kıymığı ile karakter/silah/evcil/ruhani yetenek kilidi açılır.
func _on_soul_shop_pressed() -> void:
	var screen: CanvasLayer = SoulShopScreenScript.new()
	add_child(screen)
	if MobileUIScript.enabled: ## telefonda mağaza tam ekran - menü altında görünmesin
		_set_menu_parts_visible(false)
	screen.closed.connect(func() -> void:
		_set_menu_parts_visible(true)
		_refresh_shards() ## mağazada harcanan kıymık öğedeki bakiyeye yansısın
		if is_instance_valid(_soul_shop_btn):
			_soul_shop_btn.grab_focus()
	)


## Ayarlar (madde 234): ortak "Ateş Işığı" ayar ekranı, kendi başlığı + kategori sütunuyla; açıkken menünün tabelası/öğeleri gizlenir.
## Tasarım boyutunda (1920x1080) sola-üste yaslı - telefonda RootFitter tam ekran çocukları ekrana yayar, bu ekranın içeriği
## tasarım koordinatında kalmalı.
const SETTINGS_HIDE := ["TitleSign", "MenuPanel", "PartyLine", "DebugButton", "PhoneMenu"] ## PhoneMenu: telefon menüsü (madde 279)


func _on_settings_pressed() -> void:
	if is_instance_valid(_settings_screen) or is_instance_valid(_records_screen):
		return
	_set_menu_parts_visible(false)
	_settings_screen = SettingsScreenScript.new("Ana menüye dön", 0.74)
	_settings_screen.closed.connect(_on_settings_closed)
	add_child(_settings_screen)
	_settings_screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_settings_screen.position = Vector2.ZERO
	_settings_screen.size = SCREEN


func _on_settings_closed() -> void:
	_settings_screen = null
	_set_menu_parts_visible(true)
	_settings_btn.grab_focus.call_deferred()


## Tam ekran alt ekranlar (ayarlar, rekorlar) açıkken menünün tabelası / öğeleri / parti satırı gizlenir.
func _set_menu_parts_visible(on: bool) -> void:
	for n: String in SETTINGS_HIDE:
		var c := get_node_or_null(n) as CanvasItem
		if c:
			c.visible = on
