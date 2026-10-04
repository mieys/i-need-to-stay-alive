extends "res://tools/mobile_ui/proto_screens.gd"

## Telefon arayüzü - SEÇİM EKRANLARI prototipleri (kullanıcı 2026-10-03, P1 "Büyütülmüş Klasik"i beğendi: "level atlama
## ekranları falan hala çok pcdeki gibi. efsun kartlarını da göremedim").
## Level atlama / yetenek evrimi / efsun / silah seçimi, iki varyant:
##   A "Ekranı dolduran kartlar" - aynı kart dokuları TAM 5x (efsun kartı 120x180 sanat -> 600x900, kademe kartı 500x800,
##     level satırı 6x 1608x300), ekranın boyu kadar; karta dokunmak seçer. Karıştır/Geç ekranın iki yanında (başparmak).
##   B "Liste + büyük kart" - solda üç kompakt satır, ortada seçilenin büyük kartı, sağda SEÇ (iki adımlı seçim).
##   Godot --path <proje> --windowed --resolution 2400x1080 -s res://tools/mobile_ui/proto_choice.gd -- --mobile-ui
## Ortam: SHOT_DIR, PROTO_ONLY (ör. "c_efsun_a").

## preload ETME: -s betiği autoload'lardan önce derlenir, enchant_screen.gd UISound'u bulamaz (ILERLEME tuzak notu).
var EnchantScreenScript: GDScript
const ENCH_ART := Vector2(120, 180)
const C_HEAD := Color("#ffd66e")

## Yetenek evrimi örnekleri (Korsan - skill_evolutions.gd metinleri).
const EVOS := [
	{"icon": "res://assets/skills/korsan_patlat_icon.png", "tier": "EVRİM 1/5", "cat": "Q · Patlat", "name": "Ganimet",
		"text": "Bombalarınla öldürdüğün her yaratık için 1 altın kazanırsın."},
	{"icon": "res://assets/skills/korsan_patlat_icon.png", "tier": "EVRİM 1/5", "cat": "Q · Patlat", "name": "Büyük Barut",
		"text": "Bombaların patlama alanı %30 artar."},
	{"icon": "res://assets/skills/korsan_saatli_bomba_icon.png", "tier": "EVRİM 1/5", "cat": "E · Saatli Bomba", "name": "Barut Deposu",
		"text": "Yerde aynı anda en fazla 6 bomba olabilir sınırı kalkar."},
]
## Efsun örnekleri (enchant_defs.gd + kalkan efsunları - ekrandaki metinler).
const ENCHANTS := [
	{"icon": "res://assets/ui/shields/type_enerji.png", "tier": "Epik · Kalkan", "tier_i": 2, "cat": "Kalkan efsunu",
		"name": "Enerji Kalkanı",
		"text": "Hasar alınca kısa bir süre bekler, sonra çok hızlı dolar. Şu anki kalkanının yerine geçer.",
		"head": "BU KART (kalkanını değiştirir)",
		"lines": "Kalkan: 150 → 110\nHasar soğurma: %65 → %55\nYenilenme: 10/sn → 9/sn\nBekleme: 8 sn → 6 sn"},
	{"icon": "res://assets/weapons/uzunkilic/icon.png", "tier": "Temel", "tier_i": 0, "cat": "Uzunkılıç",
		"name": "Wind Sword",
		"text": "Fiziksel efsun. Kılıç savuruşları şansa bağlı olarak düşmanları savuran ileri doğru bir rüzgar dalgası yaratır.",
		"head": "BU KART (efsunu başlatır)",
		"lines": "Her savuruş %25 ihtimalle 180 birim giden bir rüzgar dalgası yaratır: saldırı gücünün %70'i kadar hasar, 60 birim savurma."},
	{"icon": "res://assets/ui/shields/type_kale.png", "tier": "Epik · Kalkan", "tier_i": 2, "cat": "Kalkan efsunu",
		"name": "Kale Kalkanı",
		"text": "En çok kalkan ve en yüksek soğurma, ama yavaş dolar. Şu anki kalkanının yerine geçer.",
		"head": "BU KART (kalkanını değiştirir)",
		"lines": "Kalkan: 150 → 200\nHasar soğurma: %65 → %75\nYenilenme: 10/sn → 7/sn\nBekleme: 8 sn → 8 sn"},
]
const WEAPON_CHOICES := [
	{"key": "fire_staff", "icon": "res://assets/weapons/fire/firestaff_icon_v3.png", "cat": "Menzilli", "cat_col": Color("#2c5c9a"),
		"name": "Ateş Asası", "text": "Hasar: 13 + %100 saldırı gücü\nAteş hızı: 1,4 sn\nMenzil: 168\nPatlayıcı mermi"},
	{"key": "arcane", "icon": "res://assets/weapons/arcane/icon_v3.png", "cat": "Menzilli", "cat_col": Color("#2c5c9a"),
		"name": "Arcane Asası", "text": "Hasar: 16 + %110 saldırı gücü\nAteş hızı: 1,4 sn\nMenzil: 168"},
	{"key": "dagger", "icon": "res://assets/weapons/base_knife/icon_v2.png", "cat": "Yakın Dövüş", "cat_col": Color("#9a2e22"),
		"name": "Bıçak", "text": "Hasar: 10 + %85 saldırı gücü\nYakın dövüş, hedefin çevresine hafif alan hasarı"},
]


func _shots() -> void:
	EnchantScreenScript = load("res://scripts/enchant_screen.gd")
	var shots: Array = [
		["c_level_a", _level_a], ["c_level_b", _level_b],
		["c_evrim_a", _evrim_a], ["c_evrim_b", _evrim_b],
		["c_efsun_a", _efsun_a], ["c_efsun_b", _efsun_b],
		["c_silah_a", _silah_a], ["c_silah_b", _silah_b],
	]
	for s in shots:
		if not _only.is_empty() and not _only.has(s[0]):
			continue
		var r: Control = _begin(false)
		(s[1] as Callable).call(r)
		await _wait_frames(4)
		await _shot(s[0])
		_layer.queue_free()
		await _wait_frames(2)


# ---------------------------------------------------------------------------------------------------------------------
# Level atlama
# ---------------------------------------------------------------------------------------------------------------------

## A: masaüstündeki satır dokusu TAM 6x (268x50 sanat -> 1608x300), üç satır ekranın boyunu doldurur.
func _level_a(r: Control) -> void:
	_dim(r, 0.86)
	_title_plaque(r, "SEVİYE ATLADIN!", Vector2(W * 0.5, 60), FS_T)
	for i in 3:
		_level_row_k(r, LEVEL_CARDS[i], Vector2((W - 1608) * 0.5, 124 + i * 316), 6.0)
	_side_left(r, ["Karıştır\n3 altın"])
	_side_right_info(r, "Kalan\n14 sn")


## B: kademe kartları 5x (500x800) yan yana.
func _level_b(r: Control) -> void:
	_dim(r, 0.86)
	_title_plaque(r, "SEVİYE ATLADIN!", Vector2(W * 0.5, 60), FS_T)
	for i in 3:
		_tier_card_k(r, LEVEL_CARDS[i], Vector2((W - 1628) * 0.5 + i * 564, 136), 5.0)
	_side_left(r, ["Karıştır\n3 altın"])
	_side_right_info(r, "Kalan\n14 sn")


# ---------------------------------------------------------------------------------------------------------------------
# Yetenek evrimi
# ---------------------------------------------------------------------------------------------------------------------

func _evrim_a(r: Control) -> void:
	_dim(r, 0.86)
	_title_plaque(r, "YETENEK EVRİMİ!", Vector2(W * 0.5, 60), FS_T)
	for i in 3:
		var d: Dictionary = EVOS[i]
		_ench_card(r, 3, d["icon"], d["tier"], EnchantScreenScript.TIER_TEXT[2], d["cat"],
				"[color=#fff0d6]%s[/color]\n\n%s" % [d["name"], d["text"]], Vector2(252 + i * 648, 128), 5.0, false, [48, 40])
	_side_right_info(r, "Kalan\n14 sn")


func _evrim_b(r: Control) -> void:
	_dim(r, 0.86)
	for i in 3:
		var d: Dictionary = EVOS[i]
		_list_row_dark(r, d["icon"], d["name"], d["cat"], Vector2(40, 136 + i * 240), i == 1, 3)
	var d1: Dictionary = EVOS[1]
	_ench_card(r, 3, d1["icon"], d1["tier"], EnchantScreenScript.TIER_TEXT[2], d1["cat"],
			"[color=#fff0d6]%s[/color]\n\n%s" % [d1["name"], d1["text"]], Vector2(880, 96), 5.0, true, [48, 40])
	_right_column(r, "YETENEK EVRİMİ!", "Q yeteneğin 1. evrimi.\nSeçtiğin evrim kalıcıdır.", "Kalan 14 sn", [], "SEÇ")


# ---------------------------------------------------------------------------------------------------------------------
# Efsun
# ---------------------------------------------------------------------------------------------------------------------

func _efsun_a(r: Control) -> void:
	_dim(r, 0.86)
	_title_plaque(r, "EFSUN", Vector2(W * 0.5, 60), FS_T)
	for i in 3:
		var d: Dictionary = ENCHANTS[i]
		_ench_card(r, 3, d["icon"], d["tier"], EnchantScreenScript.TIER_TEXT[int(d["tier_i"])], d["cat"], _ench_text(d),
				Vector2(252 + i * 648, 128), 5.0, false)
	_side_left(r, ["Karıştır\n3 altın", "Yasakla\n3 hak"])
	_side_right(r, ["Geç\n+1 altın"])


func _efsun_b(r: Control) -> void:
	_dim(r, 0.86)
	for i in 3:
		var d: Dictionary = ENCHANTS[i]
		_list_row_dark(r, d["icon"], d["name"], d["tier"], Vector2(40, 136 + i * 240), i == 0, 3)
	var d0: Dictionary = ENCHANTS[0]
	_ench_card(r, 3, d0["icon"], d0["tier"], EnchantScreenScript.TIER_TEXT[2], d0["cat"], _ench_text(d0), Vector2(880, 96), 5.0, true)
	_right_column(r, "EFSUN", "Efsunların:\nUzunkılıç: efsunsuz", "", ["Geç (+1 altın)", "Karıştır (3 altın)", "Yasakla (3 hak)"], "SEÇ")


func _ench_text(d: Dictionary) -> String:
	return "[color=#fff0d6]%s[/color]\n\n%s\n\n[color=#ffd66e]%s[/color]\n%s" % [d["name"], d["text"], d["head"], d["lines"]]


# ---------------------------------------------------------------------------------------------------------------------
# Silah seçimi
# ---------------------------------------------------------------------------------------------------------------------

func _silah_a(r: Control) -> void:
	_dim(r, 0.86)
	_title_plaque(r, "SİLAHINI SEÇ", Vector2(W * 0.5, 60), FS_T)
	for i in 3:
		_weapon_card_k(r, WEAPON_CHOICES[i], Vector2((W - 1628) * 0.5 + i * 564, 136), 5.0)
	_side_left(r, ["Karıştır\n2 hak"])
	_side_right_info(r, "Kalan\n14 sn")


func _silah_b(r: Control) -> void:
	_dim(r, 0.86)
	for i in 3:
		var d: Dictionary = WEAPON_CHOICES[i]
		_list_row_light(r, load(d["icon"]), d["name"], d["cat"], d["cat_col"], Vector2(40, 136 + i * 240), i == 0)
	_weapon_card_k(r, WEAPON_CHOICES[0], Vector2(960, 136), 5.0)
	_right_column(r, "SİLAHINI SEÇ", "Başlangıç silahın.\nSonra dükkândan yenisini alabilirsin.", "Kalan 14 sn",
			["Karıştır (2 hak)"], "SEÇ")


# ---------------------------------------------------------------------------------------------------------------------
# Yapı taşları
# ---------------------------------------------------------------------------------------------------------------------

## Efsun / evrim kartı: levelup_enchant_card_N (120x180 sanat) TAM k kat. İç yerleşim enchant_screen.gd'nin 3x
## dikdörtgenlerinden (ICON_RECT, TIER_RECT, CATEGORY_RECT, TEXT_RECT) k/3 ile ölçeklenir. Gövde yazısı sığan en büyük boy.
func _ench_card(r: Control, card_i: int, icon_path: String, tier: String, tier_col: Color, cat: String, bb: String,
		pos: Vector2, k: float, selected: bool, sizes: Array = [40, 32, 24]) -> void:
	var s: float = k / 3.0
	var sz: Vector2 = ENCH_ART * k
	if selected:
		_tex_rect(r, EnchantScreenScript.GLOW_TEXTURE, pos - Vector2(15, 15) * s, sz + Vector2(30, 30) * s)
	_tex_rect(r, EnchantScreenScript.CARD_TEXTURES[card_i - 1], pos, sz)
	var ir: Rect2 = EnchantScreenScript.ICON_RECT
	_icon_int(r, load(icon_path), pos + (ir.position + ir.size * 0.5) * s, ir.size.x * s)
	var tr: Rect2 = EnchantScreenScript.TIER_RECT
	var cr: Rect2 = EnchantScreenScript.CATEGORY_RECT
	_label(r, tier, FS_T, tier_col, pos + tr.position * s, tr.size * s)
	_label(r, cat, FS_B, EnchantScreenScript.DIM_COLOR, pos + cr.position * s, cr.size * s)
	var xr: Rect2 = EnchantScreenScript.TEXT_RECT
	_rich(r, bb, EnchantScreenScript.DIM_COLOR, pos + xr.position * s, xr.size * s, sizes)


## Kademe kartı (tier_card_N 100x160 sanat) k kat.
func _tier_card_k(r: Control, c: Array, pos: Vector2, k: float) -> void:
	var tier: int = int(c[1])
	var u: float = k ## sanat pikseli -> ekran
	var sz := Vector2(100, 160) * u
	_tex_rect(r, load("res://assets/ui/game/tier_card_%d.png" % (tier + 1)), pos, sz)
	## Doku düzeni (sanat px): amblem kalkanı ~27..83, isim kurdelesi ~68..80, parşömen kutu ~85..150.
	_icon_int(r, load("res://assets/ui/level_up_icons/%s.png" % c[4]), pos + Vector2(50, 47.5) * u, 32 * u)
	_label(r, c[0], FS_T, C_ROW_TEXT, pos + Vector2(12, 67) * u, Vector2(76, 14) * u, 1, 4)
	_label(r, "%s  ·  %s" % [TIER_NAMES[tier], c[2]], FS_B, [UIKit.C_TEXT_DIM, Color("#2c5c9a"), Color("#6a3fa0"), Color("#9a5a10")][tier],
			pos + Vector2(0, 88) * u, Vector2(100, 14) * u, 1)
	_label(r, c[3], 96, UIKit.C_GOOD, pos + Vector2(0, 104) * u, Vector2(100, 24) * u, 1)
	_label(r, "artar", FS_B, UIKit.C_TEXT_DIM, pos + Vector2(0, 130) * u, Vector2(100, 12) * u, 1)


## Level satırı (levelup_row_N 268x50 sanat) k kat.
func _level_row_k(r: Control, c: Array, pos: Vector2, k: float) -> void:
	var tier: int = int(c[1])
	var sz := Vector2(268, 50) * k
	_tex_rect(r, load("res://assets/ui/game/levelup_row_%d.png" % (tier + 1)), pos, sz)
	_icon_int(r, load("res://assets/ui/level_up_icons/%s.png" % c[4]), pos + Vector2(28, 25) * k, 30 * k)
	_label(r, c[0], FS_XL, C_ROW_TEXT, pos + Vector2(52, 6) * k, Vector2(140, 18) * k)
	_label(r, "%s  ·  %s" % [TIER_NAMES[tier], c[2]], FS_T, TIER_COLORS[tier], pos + Vector2(52, 27) * k, Vector2(140, 16) * k)
	_label(r, c[3], 112, C_VALUE, pos + Vector2(150, 2) * k, Vector2(108, 30) * k, 2)
	_label(r, "artar", FS_T, C_ROW_DIM, pos + Vector2(150, 31) * k, Vector2(108, 14) * k, 2)


## Silah kartı: card_tall (100x160 sanat) k kat + kategori, büyük ikon, ad, özellik kutusu.
func _weapon_card_k(r: Control, d: Dictionary, pos: Vector2, k: float) -> void:
	var sz := Vector2(100, 160) * k
	_tex_rect(r, load("res://assets/ui/game/card_tall.png"), pos, sz)
	_label(r, d["cat"], FS_B, d["cat_col"], pos + Vector2(0, 9) * k, Vector2(100, 12) * k, 1)
	_icon_int(r, load(d["icon"]), pos + Vector2(50, 46) * k, 40 * k)
	_label(r, d["name"], FS_XL, UIKit.C_TEXT, pos + Vector2(0, 70) * k, Vector2(100, 16) * k, 1)
	_inset(r, pos + Vector2(10, 90) * k, Vector2(80, 60) * k)
	_rich(r, d["text"], UIKit.C_TEXT, pos + Vector2(14, 93) * k, Vector2(72, 54) * k, [40, 32])


## Başparmak bölgesi: ekranın sol/sağ kenarında dikey büyük düğmeler.
func _side_left(r: Control, texts: Array) -> void:
	for i in texts.size():
		var h: float = 300.0 if texts.size() == 1 else 240.0
		var y: float = (H - (h * texts.size() + 24 * (texts.size() - 1))) * 0.5 + i * (h + 24)
		_button(r, texts[i], "wood", FS_B, Vector2(16, y), Vector2(220, h))


func _side_right(r: Control, texts: Array) -> void:
	for i in texts.size():
		var h: float = 300.0
		_button(r, texts[i], "wood", FS_B, Vector2(W - 236, (H - h) * 0.5 + i * (h + 24)), Vector2(220, h))


func _side_right_info(r: Control, text: String) -> void:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UIKit.panel_style("plaque"))
	r.add_child(p)
	_place(p, Vector2(W - 236, (H - 200) * 0.5), Vector2(220, 200))
	_label(r, text, FS_B, UIKit.C_TEXT, Vector2(W - 236, (H - 200) * 0.5), Vector2(220, 200), 1)


## B varyantı: koyu liste satırı (evrim/efsun satır dokusu levelup_evo_row_3, 268x66 sanat 3x = 804x198).
func _list_row_dark(r: Control, icon_path: String, title: String, sub: String, pos: Vector2, selected: bool, tier: int) -> void:
	var sz := Vector2(804, 198)
	if selected:
		_tex_rect(r, load("res://assets/ui/game/levelup_evo_row_glow.png"), pos - Vector2(15, 15), sz + Vector2(30, 30))
	_tex_rect(r, load("res://assets/ui/game/levelup_evo_row_%d.png" % clampi(tier, 3, 4)), pos, sz)
	_icon_int(r, load(icon_path), pos + Vector2(99, 99), 120)
	_label(r, title, FS_T, C_ROW_TEXT, pos + Vector2(200, 36), Vector2(580, 64))
	_label(r, sub, FS_B, EnchantScreenScript.DIM_COLOR, pos + Vector2(200, 104), Vector2(580, 56))


func _list_row_light(r: Control, tex: Texture2D, title: String, sub: String, sub_col: Color, pos: Vector2, selected: bool) -> void:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UIKit.panel_style("card_selected" if selected else "card"))
	r.add_child(p)
	_place(p, pos, Vector2(804, 198))
	_icon_slot_tex(r, tex, pos + Vector2(24, 24), 150, 1)
	_label(r, title, FS_T, UIKit.C_TEXT, pos + Vector2(200, 36), Vector2(580, 64))
	_label(r, sub, FS_B, sub_col, pos + Vector2(200, 104), Vector2(580, 56))


## B varyantı sağ sütun: başlık, açıklama, ikincil düğmeler, en altta büyük SEÇ (sağ başparmak).
func _right_column(r: Control, title: String, info: String, timer: String, extra: Array, action: String) -> void:
	var x: float = 1540.0
	var w: float = W - x - 40.0
	_title_plaque(r, title, Vector2(x + w * 0.5, 84), FS_T)
	_wrap(r, info, FS_B, C_ROW_TEXT, Vector2(x, 176), Vector2(w, 200)).horizontal_alignment = 1
	if timer != "":
		_label(r, timer, FS_B, C_HEAD, Vector2(x, 380), Vector2(w, 56), 1)
	var y: float = 760.0 - extra.size() * 132.0
	for t in extra:
		_button(r, t, "wood", FS_B, Vector2(x, y), Vector2(w, 112))
		y += 132.0
	_button(r, action, "green", FS_XXL, Vector2(x, 784), Vector2(w, 256))


## Zengin metin, kutuya sığan en büyük boyla (m5x7 keskin boylar).
func _rich(r: Control, bb: String, col: Color, pos: Vector2, sz: Vector2, sizes: Array) -> void:
	var font: Font = MenuKit.font()
	var plain: String = RegEx.create_from_string("\\[/?[a-z]+(=[^\\]]*)?\\]").sub(bb, "", true)
	var fs: int = int(sizes[-1])
	for s in sizes:
		var h: float = font.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, sz.x, int(s)).y
		if h <= sz.y:
			fs = int(s)
			break
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.scroll_active = false
	t.text = bb
	t.add_theme_font_override("normal_font", font)
	t.add_theme_font_size_override("normal_font_size", fs)
	t.add_theme_color_override("default_color", col)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(t)
	_place(t, pos, sz)
