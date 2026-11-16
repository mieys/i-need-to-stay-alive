extends Control

## Ana menü. 2026-10-16 YENİDEN (kullanıcı: "ana menü için 4 prototip, yapay zeka kullanma, hafif koyu tonlar" -> sol panel yerleşimi;
## arka plan için "haritanın bir parçası yerine yeni sade bir arka plan, oyunun asset'leriyle" -> 4 sade sahneden "Ocak Başı" seçildi):
##   arka plan 2026-11-15'ten beri "Nehir Kenarı Kampı" (menu_camp_scene.gd): ana haritanın nehir kıyısında günbatımında kamp yapan
##   parti (Şovalye, Matthew, Talon, Elara, Hadime, Oakley + köpek), kazanlı kamp ateşi + yiyecekler. Eski "Ocak Başı" (şömine) kodu kalktı.
##   sol: "D - Panelsiz Ateş Işığı" (2026-10-16, ilk düz koyu panel "ruhsuz ve sıradan" bulundu; 4 prototipten D seçildi): kutu yok,
##   sol taraf yumuşak kararır (sol_golge.png), büyük başlık + kiriş süsü, öğeler ikon + başlık + alt yazı, seçilide altın yazı (mum 2026-11-06 kalktı).
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

## Oyun adı (2026-11-07): "Potpourri". Eski adlar: "Lil'Slayers", "I NEED TO STAY ALIVE".
const TITLE := "POTPOURRI"
const SCREEN := Vector2(1920, 1080)
const COL_W := 560.0
## Arka plan sahnesi "Nehir Kenarı Kampı" (2026-11-15): menu_camp_scene.gd (menu_hearth_bg.gd de aynısını kurar).
const CampScene := preload("res://scripts/menu_camp_scene.gd")
const BgBlur := preload("res://scripts/menu_bg_blur.gd") ## alt ekranlarda (ayarlar/rekorlar) sahne bulanık, 2026-11-16

var _settings_screen: Control = null
var _bg_blur: Control = null
var _records_screen: Control = null

var _start_btn: Button
var _multiplayer_btn: Button
var _records_btn: Button
var _soul_shop_btn: Button
var _settings_btn: Button
var _exit_btn: Button
var _stage: Control = null
var _shard_label: Label = null


func _ready() -> void:
	DisplayServer.window_set_title("Potpourri")
	GameManager.content_unlock_mode = false ## "Debug Modu" düğmesiyle açılan kilit açık modu menüye dönünce biter (madde 614)
	## TEST HARİTASI (madde 731): menüye dönünce haritanın açtığı debug kapanır, seçim ana haritaya döner (HIZLI BAŞLA test haritasını açmasın).
	GameManager.leave_test_map()
	if preload("res://scripts/map_profiles.gd").is_test_map_id(str(GameManager.selected_map)):
		GameManager.selected_map = preload("res://scripts/map_profiles.gd").DEFAULT_ID
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
	CampScene.build(_stage)
	var shade := TextureRect.new() ## sol menünün okunurluğu: yumuşak karartma (ışık değil), sahneyle birlikte ölçeklenir
	shade.texture = load(FM.SHADE_PATH)
	shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(shade)
	shade.position = Vector2.ZERO
	shade.size = SCREEN
	_bg_blur = BgBlur.add_to(layer)
	_bg_blur.visible = false ## yalnız ayarlar / rekorlar / (telefonda) Ruh Mağazası açıkken: _set_menu_parts_visible
	layer.resized.connect(_fit_stage.bind(layer))
	_fit_stage(layer)


func _fit_stage(layer: Control) -> void:
	if _stage == null or layer.size.x < 1.0:
		return
	var s: float = maxf(layer.size.x / SCREEN.x, layer.size.y / SCREEN.y)
	_stage.scale = Vector2(s, s)
	_stage.position = ((layer.size - SCREEN * s) * 0.5).floor()


## ------------------------------------------------------------------ sol menü: "D - Panelsiz Ateş Işığı" (2026-10-16, kullanıcı seçti)
## Kutu yok: sahnenin sol tarafı yumuşak kararır (sol_golge.png, sahne katmanında), üstte büyük başlık + kiriş süsü ayracı, öğeler
## ikon + 48 punto başlık + alt yazı. Seçili öğe (fare üstünde = odak; kumanda/klavye de odakla gezer) altın yazı (yanındaki mum 2026-11-06 kalktı).
const ITEM_ICON := 48.0
const ITEM_H := 92.0
const HT := preload("res://scripts/hud_theme.gd") ## tek arayüz paleti (stil rehberi, madde 403)
const C_GOLD := HT.ACCENT
const C_GOLD_DIM := HT.ACCENT_SOFT
const C_CREAM := HT.TEXT
const C_SUB := HT.DIM
const C_TAG := HT.DIM
const C_RED := HT.BAD

var _items: Array = [] ## [{btn, title, sub, danger, row}]


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
	return tr("En iyi: Kademe %d · %d:%02d") % [int(data.get("best_tier", 0)), t / 60, t % 60]


## Bir menü öğesi: görünmez düğme (tıklama/odak) + içinde boş yuva, ikon, başlık, alt yazı. Yuvadaki seçili öğe mumu
## 2026-11-06'da kullanıcı isteğiyle kalktı; yuva boş 64 px olarak duruyor (yerleşim değişmesin).
func _menu_item(title: String, sub: String, icon_spec: String, danger: bool = false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(COL_W, ITEM_H)
	b.flat = true
	for st: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var row := DK.h(14)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(64, 64)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	var it := {"btn": b, "title": tl, "sub": sl, "danger": danger, "row": row}
	_items.append(it)
	## Fare üstüne gelmek = odak: tek bir "seçili" görünümü (kumanda/klavyeyle aynı).
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_entered.connect(_set_item_selected.bind(it, true))
	b.focus_exited.connect(_set_item_selected.bind(it, false))
	return b


func _set_item_selected(it: Dictionary, on: bool) -> void:
	var tl: Label = it["title"]
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


## Başlık tabelası (2026-11-13, madde 660; kullanıcı: "şu bölümü ai kullanmadan daha iyi hale getirir misin" -> 3 prototip, seçim
## "alternatif B kuru çiçek renkleri", tools/proto_20261113/menu_baslik/): m5x7 96 yazının yerine elle çizilmiş piksel logo (harf ızgaraları,
## harf başına sönük taç yaprağı tonu - gül / altın / adaçayı / lavanta, potpourri = kuru çiçek karışımı - + hafif zıplama, üst kenar parlaması,
## 2 px kahve derinlik, 1 px dış hat; gen_logo.py --oyun), aynı piksel yoğunluğu (1 sanat px = 6 ekran px). Altında logoya ortalı, harf aralığı
## açık slogan. B'de yan silahlar yok (SIGN_WEAPONS; true = C: iki yanda aynı boy Bıçak / Ateş Asası). Eski kiriş süsü çubuğu kalktı.
## Ad "TitleSign" korunur (ayarlar/rekorlar gizler, telefon sığdırır). Masaüstü + telefon aynı tabela.
## Aynı gün: harfler hafifçe aşağı yukarı dalgalanır (potpourri_logo.gd; prototipteki sabit zıplamanın yerine), logo yükleme ekranında da var.
const PotpourriLogo := preload("res://scripts/potpourri_logo.gd")
const LOGO_K := PotpourriLogo.K
const LOGO_FACE := Vector2(1.0, 11.0) ## logo dokusunda harf yüzünün ilk satırı + yüksekliği (dış hat 1, harf 11 satır)
const SIGN_WEAPONS := false
const SIGN_WEAPON_K := 3.0
const SIGN_GAP := 6.0


func _title_sign(tag_col: Color) -> Control:
	var root := Control.new()
	root.name = "TitleSign"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lsz: Vector2 = PotpourriLogo.TEX.get_size() * LOGO_K ## dalgasız logo (harfler bunun ± PotpourriLogo.art_top() kadar oynar)
	var face_mid: float = (LOGO_FACE.x + LOGO_FACE.y * 0.5) * LOGO_K
	var wpn: Array[TextureRect] = []
	for key: String in (["dagger", "fire_staff"] if SIGN_WEAPONS else []):
		var t: Texture2D = WC.icon(key)
		var tr := TextureRect.new()
		tr.texture = t
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size = t.get_size() * SIGN_WEAPON_K
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tr)
		wpn.append(tr)
	var top: float = 0.0
	var lx: float = 0.0
	if not wpn.is_empty():
		wpn[0].flip_h = true ## bıçağın ucu sola-yukarı, asanın taşı sağa-yukarı: ayna duruş
		top = maxf(0.0, wpn[0].size.y * 0.5 - face_mid) ## silahlar logodan uzunsa logo aşağı kayar (hiçbir parça tabelanın üstüne taşmaz)
		lx = wpn[0].size.x + SIGN_GAP
	var logo: Control = PotpourriLogo.new()
	logo.name = "Logo"
	logo.position = Vector2(lx, top - PotpourriLogo.art_top()) ## dalgasız harflerin üstü = top
	root.add_child(logo)
	var right: float = lsz.x
	if not wpn.is_empty():
		wpn[0].position = Vector2(0.0, top + face_mid - wpn[0].size.y * 0.5).round()
		wpn[1].position = Vector2(lx + lsz.x + SIGN_GAP, top + face_mid - wpn[1].size.y * 0.5).round()
		right = wpn[1].position.x + wpn[1].size.x
	var tag := _lbl("Eğlenceli olan her şey", DK.FS_BODY, tag_col) ## slogan 2026-11-13 (kullanıcı: "Everything that is fun"; eski "Hayatta kal. Birlikte.")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.vertical_alignment = VERTICAL_ALIGNMENT_TOP ## etiketin en küçük boyu yedek fontlarla 32'den uzun ölçülüyor: ortalanırsa slogan logodan kopar
	var fv := FontVariation.new()
	fv.base_font = tag.get_theme_font("font")
	fv.spacing_glyph = 2 ## m5x7 32'de 1 yazı pikseli: slogan logonun altında seyrek, tabela gibi okunur
	tag.add_theme_font_override("font", fv)
	var tag_y: float = top + lsz.y + PotpourriLogo.art_top() - 2.0 ## en aşağı inen harfin altı
	tag.position = Vector2(lx, tag_y)
	tag.custom_minimum_size = Vector2(lsz.x, 0.0)
	## Etiket logodan genişse (uzun çeviri) logonun ortasına göre ortalanır.
	tag.resized.connect(func() -> void: tag.position = Vector2(roundf(lx + (lsz.x - tag.size.x) * 0.5), tag_y))
	root.add_child(tag)
	root.custom_minimum_size = Vector2(right, tag_y + DK.FS_BODY)
	return root


func _build_left_panel() -> void:
	var logo := _title_sign(C_TAG)
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

	## Masaüstünde sol alttaki parti yüzleri + "En iyi" satırı kullanıcı isteğiyle kaldırıldı (2026-11-15); rekor REKORLAR öğesinin alt yazısında.
	## Debug Modu düğmesi (sol alt) kullanıcı isteğiyle GERİ (2026-11-16: karakter/silah seçimi için lazım, madde 614).
	_create_debug_mode_button()


func _refresh_shards() -> void:
	if is_instance_valid(_shard_label):
		_shard_label.text = "Kilit aç, kalıcı geliştir" if MobileUIScript.enabled else tr("%d kıymık · kilit aç") % MetaProgressScript.shards()
	if is_instance_valid(_ph_shard_value):
		_ph_shard_value.text = str(MetaProgressScript.shards())


## ------------------------------------------------------------------ telefon
## TELEFON (2026-10-19; kullanıcı seçimi prototip S: ana menü = A düzeni + B "Gece Sıvası" renkleri, mobil_proto.gd A_ana_menu): sahne
## (şömine, parti, köpek) aynı; solda yumuşak lacivert gölge + başlık + 5 iri öğe (seçili = altın zemin + sol şerit,
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
	## Başlık: masaüstüyle aynı tabela (piksel logo + yanlarda silahlar + slogan, _title_sign).
	var logo := _title_sign(DK.C_DIM)
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
	chip.get_theme_stylebox("panel").content_margin_left = 20 ## PixelBox (madde 417)
	chip.get_theme_stylebox("panel").content_margin_right = 24
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


## Öğe: görünmez düğme + seçili zemini (altın %14 + 8 px sol şerit) + elmas (hep; seçili mumu 2026-11-06'da kalktı) + 64 px simge + başlık / alt yazı.
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
	b.set_meta("ph", {"sel": sel, "dia": dia, "icon": icon, "title": tl})
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	b.focus_entered.connect(_ph_item_selected.bind(b, true))
	b.focus_exited.connect(_ph_item_selected.bind(b, false))
	_ph_items.append(b)
	return b


func _ph_item_selected(b: Button, on: bool) -> void:
	var it: Dictionary = b.get_meta("ph")
	(it["sel"] as Control).visible = on
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
## MADDE 614: düğme exportta da var ama artık TAM debug değil - tüm karakter/silah/evcil/ruhani kilitleri açık olarak ÇOK OYUNCULU oda listesini
## açar (`GameManager.content_unlock_mode`); Q/E/R baştan açılmaz, debug menüsü yok.
func _create_debug_mode_button() -> void:
	var btn := Button.new()
	btn.name = "DebugButton"
	btn.text = "Debug Modu"
	btn.add_theme_font_override("font", DK.font())
	btn.add_theme_font_size_override("font_size", DK.FS_LABEL)
	btn.custom_minimum_size = Vector2(168, 40)
	DK.style_button_colors(btn, Color(HT.WIN_INSET, 0.7), HT.WIN_LINE, C_SUB, C_GOLD, 2, 4, 6.0)
	btn.pressed.connect(_on_debug_mode_pressed)
	add_child(btn)
	MenuKit.place(btn, Vector2(40, SCREEN.y - 64.0), btn.custom_minimum_size)


func _on_debug_mode_pressed() -> void:
	GameManager.content_unlock_mode = true ## ana menü her açılışta kapatır (_ready); oda listesinden geri dönmek de kapatır
	_on_multiplayer_pressed() ## "Çok Oyunculu" ile aynı akış: oda listesi -> oda kur / odaya gir -> karakter seçimi


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
	if is_instance_valid(_bg_blur): ## alt ekran açıkken sahne bulanık (menu_bg_blur.gd), ana menünün kendisinde keskin
		_bg_blur.visible = not on
	for n: String in SETTINGS_HIDE:
		var c := get_node_or_null(n) as CanvasItem
		if c:
			c.visible = on
