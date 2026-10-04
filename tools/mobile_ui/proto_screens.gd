extends SceneTree

## Telefon arayüzü PROTOTİPLERİ (kullanıcı isteği 2026-10-03: "android arayüzü windows arayüzünün ufaltılmış halini
## kullanıyor, son derece konforsuz. windows arayüzündeki elementlerden fazla uzaklaşmadan 4 adet arayüz prototipi hazırla,
## mobil için daha kolay görünmesi lazım").
## Gerçek oyun açılır (mobil kip, 2400x1080 = 20:9 telefon tuvali), her prototip ekranı oyunun KENDİ kitiyle (UIKit /
## MenuKit dokuları, m5x7 yazı, gerçek ikon/portre/karakter kareleri) oyunun üstüne kurulur ve ekran görüntüsü alınır.
## Sadece görsel taslak - düğmeler bir şey yapmaz, veriler sabit örnek.
##   Godot --path <proje> --windowed --resolution 2400x1080 -s res://tools/mobile_ui/proto_screens.gd -- --mobile-ui
## Ortam: SHOT_DIR (zorunlu), PROTO_ONLY ("p1_karakter,p3_tuccar" gibi; boşsa hepsi).
##
## Telefon ölçüleri (2400 px ~ 148 mm, ~16 px/mm): gövde yazısı 40 (m5x7 5x, büyük harf ~2,2 mm; masaüstü 24-32), başlık
## 48-64, dokunma hedefi >= 112 px (~7 mm). Dokular 3x (masaüstüyle aynı kalınlık) ya da 4x (tam 4/3: her sanat pikseli
## 4 ekran pikseli, keskin). Yazı boyları 8'in katı (m5x7 keskin).
##
## Prototipler:
##   P1 Büyütülmüş Klasik   - masaüstü düzeni korunur, ekranda daha az şey, her şey büyük (en az değişiklik)
##   P2 Sekmeli Pencere     - tek büyük ahşap pencere, yan yana paneller sekmeye dönüşür, eylem alt şeritte
##   P3 Alt Çekmece         - ekranın altından çıkan parşömen çekmece, yatay kaydırmalı büyük kartlar, oyun üstte görünür
##   P4 Yan Ray + Detay     - solda büyük ikonlu dikey ray, ortada liste, sağda seçilenin detayı + tek büyük eylem düğmesi

const W := 2400.0
const H := 1080.0
const FS_S := 32
const FS_B := 40
const FS_T := 48
const FS_XL := 64
const FS_XXL := 80
const C_ROW_TEXT := Color("#fff0d6")
const C_ROW_DIM := Color("#cdb89a")
const C_VALUE := Color("#ffd75e")
const TIER_COLORS := [Color("#cdb89a"), Color("#7fb8ff"), Color("#c99bff"), Color("#ffb347")]
const TIER_NAMES := ["Sıradan", "Nadir", "Epik", "Efsanevi"]

const PreviewScript := "res://scripts/menu_character_preview.gd"

const WEAPON_ICONS := {
	"dagger": "res://assets/weapons/base_knife/icon_v2.png",
	"tufek": "res://assets/weapons/tufek/icon.png",
	"yay": "res://assets/weapons/yay/draw1.png",
	"buz_asasi": "res://assets/weapons/buz_asasi/icon_v3.png",
	"fire_staff": "res://assets/weapons/fire/firestaff_icon_v3.png",
	"boomerang": "res://assets/weapons/boomerang/icon.png",
}
const WEAPON_NAMES := {"dagger": "Bıçak", "tufek": "Tüfek", "yay": "Yay", "buz_asasi": "Buz Asası",
		"fire_staff": "Ateş Asası", "boomerang": "Bumerang"}
const SPIRITS := [
	["Para", "res://assets/skills/spirit_para_icon.png"], ["Can", "res://assets/skills/spirit_can_icon.png"],
	["Nişancı", "res://assets/skills/spirit_adc_icon.png"], ["Tank", "res://assets/skills/spirit_tank_icon.png"],
	["Taktik", "res://assets/skills/spirit_taktik_icon.png"], ["Dükkan", "res://assets/skills/spirit_dukkan_icon.png"],
	["Savaş Şevki", "res://assets/skills/spirit_savas_sevki_icon.png"], ["Kalkan Bağı", "res://assets/skills/spirit_kalkan_bagi_icon.png"],
]
## Level atlama örnek kartları: [ad, kademe(0..3), kategori, değer, stat ikonu]
const LEVEL_CARDS := [
	["Can Çalma", 0, "Saldırı", "+%1", "stat_max_health"],
	["Menzil", 0, "Saldırı", "+%12", "stat_range"],
	["Saldırı Hızı", 2, "Saldırı", "+%9.6", "stat_fire_rate"],
]
const STATS := [
	["stat_speed", "Hız", "81"], ["stat_armor_pen_percent", "Kalkan Delme", "%0"], ["stat_damage", "Saldırı Gücü", "11"],
	["stat_exp_gain", "Tecrübe Kzn.", "%0"], ["stat_fire_rate", "Saldırı Hızı", "+%0"], ["stat_luck", "Şans", "0"],
	["stat_shield", "Kalkan Soğurma", "%65"], ["stat_range", "Menzil", "+%0"], ["stat_crit_chance", "Kritik Şansı", "%5 (x1.5)"],
	["stat_dodge", "Sıvışma", "%0"], ["stat_shield", "Kalkan Miktarı", "+%0"], ["stat_max_health", "Can Yenilenmesi", "1.5/5sn"],
	["stat_max_health", "İyileştirme Gücü", "+%0"],
]
const INV_WEAPONS := ["dagger", "tufek"]
const INV_ITEMS := ["kanli_yakut", "kol_saati", "kemik_kolye", "ruzgar_eldiveni"]
## Tüccar stoku: [tür, anahtar]
const STOCK := [["weapon", "tufek"], ["weapon", "yay"], ["weapon", "buz_asasi"], ["item", "kanli_yakut"],
		["item", "ceviklik_yuzugu"], ["item", "kemik_kolye"], ["item", "ruzgar_eldiveni"], ["item", "anka_kusunun_kalbi"]]
const STOCK_PRICES := [100, 100, 95, 330, 300, 600, 650, 1850]
const SEL_CHAR := 9

var _dir: String = OS.get_environment("SHOT_DIR")
var _only: PackedStringArray = OS.get_environment("PROTO_ONLY").split(",", false)
var _gm: Node
var _layer: CanvasLayer


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_dir)
	await process_frame
	await _force_phone_window()
	_gm = root.get_node("GameManager")
	_gm.set("debug_immortal", true)
	## Oyun içi ekranların arkası gerçek oyun: menü akışıyla oyuna gir, silahı seç, evden çık, birkaç yaratık.
	change_scene_to_file("res://scenes/main_menu.tscn")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_start_pressed"), 10.0)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.has_method("_on_character_pressed"), 10.0)
	current_scene.call("_on_character_pressed", SEL_CHAR)
	current_scene.call("_on_start_pressed")
	await _until(func(): return current_scene != null and current_scene.name == "Main", 30.0)
	## Başlangıç silah (ve ardından gelebilecek) seçim ekranları: birkaç saniye boyunca açılan her seçim ekranında rastgele kart.
	for k in 10:
		await _wait(0.5)
		for n in _all_nodes(root):
			if n.has_method("_auto_pick_random_card"):
				n.call("_auto_pick_random_card")
	await _wait(1.0)
	var house: Node = current_scene.get_node_or_null("HouseInterior")
	if house and house.has_method("_do_exit_house"):
		house.call("_do_exit_house")
	await _wait(1.5)
	var player: Node2D = current_scene.get_node_or_null("Player") as Node2D
	var spawner: Node = current_scene.get_node_or_null("EnemySpawner")
	if spawner and player:
		var roster: Array = spawner.call("_spawnable_roster", 3)
		for i in 10:
			var pos: Vector2 = player.global_position + Vector2.from_angle(i * 0.63) * (330.0 + 30.0 * (i % 3))
			if _gm.call("is_position_blocked_by_forest", pos):
				continue
			var e: Node = spawner.call("_spawn_creature", roster[i % roster.size()], pos, 910000 + i)
			e.call("apply_tier_scaling", 3)
	await _wait(1.0)
	paused = true ## yaratıklar çekimler arasında oyuncuya yürümesin
	await _shots()
	quit()


## Alt sınıflar (proto_choice.gd) kendi çekim listesini verir.
func _shots() -> void:
	var shots: Array = [
		["p1_karakter", _p1_karakter], ["p1_level", _p1_level], ["p1_envanter", _p1_envanter], ["p1_tuccar", _p1_tuccar],
		["p2_karakter", _p2_karakter], ["p2_level", _p2_level], ["p2_envanter", _p2_envanter], ["p2_tuccar", _p2_tuccar],
		["p3_karakter", _p3_karakter], ["p3_level", _p3_level], ["p3_envanter", _p3_envanter], ["p3_tuccar", _p3_tuccar],
		["p4_karakter", _p4_karakter], ["p4_level", _p4_level], ["p4_envanter", _p4_envanter], ["p4_tuccar", _p4_tuccar],
	]
	for s in shots:
		if not _only.is_empty() and not _only.has(s[0]):
			continue
		var r: Control = _begin(String(s[0]).ends_with("karakter"))
		(s[1] as Callable).call(r)
		await _wait_frames(4)
		await _shot(s[0])
		_layer.queue_free()
		await _wait_frames(2)


# ---------------------------------------------------------------------------------------------------------------------
# P1 - Büyütülmüş Klasik
# ---------------------------------------------------------------------------------------------------------------------

func _p1_karakter(r: Control) -> void:
	_back_button(r, Vector2(48, 32))
	_banner(r, "Karakterini Seç", 28)
	## sol: ruhani yetenek - sadece büyük ikonlar + seçilenin adı/kısa metni
	var left := _panel(r, "menu", Vector2(48, 160), Vector2(436, 880))
	_label(r, "Ruhani Yetenek", FS_B, MenuKit.C_ACCENT, Vector2(48, 196), Vector2(436, 48), 1)
	for i in SPIRITS.size():
		var p := Vector2(84 + (i % 3) * 128, 264 + (i / 3) * 128)
		_icon_slot(r, load(SPIRITS[i][1]), p, 116, "menu", i == 0)
	_label(r, "Para (Pasif)", FS_B, MenuKit.C_TEXT, Vector2(72, 668), Vector2(388, 48), 1)
	_wrap(r, "Her 10 saniyede 5 altın kazandırır, dükkân bedelleri %10 azalır.", FS_S, MenuKit.C_TEXT_DIM,
			Vector2(84, 728), Vector2(364, 280))
	## orta: 5 sütun büyük kart (kaydırmalı), altında seçilenin yetenek ikonları
	var ids: Array = Characters.DEFS.keys()
	for i in 10:
		_char_tile(r, ids[i], Vector2(512 + (i % 5) * 256, 160 + (i / 5) * 304), ids[i] == SEL_CHAR)
	_scroll_hint(r, Vector2(1784, 160), 600, 0.4)
	var sk := _panel(r, "menu", Vector2(512, 784), Vector2(1272, 256))
	_skill_icons_row(r, SEL_CHAR, Vector2(548, 818), 128, true)
	## sağ: vitrin + BAŞLA
	_showcase(r, SEL_CHAR, Vector2(1808, 160), Vector2(544, 880), true)


func _p1_level(r: Control) -> void:
	_dim(r, 0.62)
	_title_plaque(r, "SEVİYE ATLADIN!", Vector2(W * 0.5, 96), FS_XL)
	for i in 3:
		_level_row(r, LEVEL_CARDS[i], Vector2((W - 1072) * 0.5, 184 + i * 232), Vector2(1072, 200))
	var b := _button(r, "Yeniden Karıştır (3 altın)", "wood", FS_B, Vector2((W - 720) * 0.5, 912), Vector2(720, 120))


func _p1_envanter(r: Control) -> void:
	_dim(r, 0.5)
	## sol panel: özellikler (tek sütun, büyük satırlar)
	_panel(r, "game", Vector2(96, 40), Vector2(960, 1000))
	_title_plaque(r, "ÖZELLİKLER", Vector2(576, 104), FS_T)
	for i in STATS.size():
		var y: float = 164 + i * 64
		_stat_row(r, STATS[i], Vector2(144, y), 864, 56)
	## sağ panel: envanter (büyük yuvalar)
	_panel(r, "game", Vector2(1088, 40), Vector2(1216, 1000))
	_title_plaque(r, "ENVANTER", Vector2(1640, 104), FS_T)
	_close_button(r, Vector2(2160, 48))
	var y0: float = 176
	_label(r, "Silahlar", FS_B, UIKit.C_ACCENT, Vector2(1144, y0), Vector2(600, 48))
	for i in 5:
		_inv_slot(r, Vector2(1144 + i * 152, y0 + 56), 136, "weapon", INV_WEAPONS[i] if i < INV_WEAPONS.size() else "")
	_label(r, "Ekipman", FS_B, UIKit.C_ACCENT, Vector2(1144, y0 + 216), Vector2(600, 48))
	for i in 3:
		_inv_slot(r, Vector2(1144 + i * 152, y0 + 272), 136, "shield" if i == 0 else "", "shield_standart" if i == 0 else "")
	_label(r, "Eşyalar  ·  Epik 1/10  ·  Parça 3/5", FS_B, UIKit.C_ACCENT, Vector2(1144, y0 + 432), Vector2(1100, 48))
	for i in 7:
		_inv_slot(r, Vector2(1144 + i * 152, y0 + 488), 136, "item" if i < INV_ITEMS.size() else "", INV_ITEMS[i] if i < INV_ITEMS.size() else "")
	_scroll_hint(r, Vector2(2232, 176), 640, 0.6)
	_gold_bar(r, Vector2(1144, 896), Vector2(1104, 96))


func _p1_tuccar(r: Control) -> void:
	_dim(r, 0.5)
	_panel(r, "game", Vector2(40, 32), Vector2(2320, 1016))
	_title_plaque(r, "SEYYAR SATICI", Vector2(300, 108), FS_T)
	_gold_plaque(r, Vector2(600, 56), "1250")
	_button(r, "ENVANTER", "wood", FS_B, Vector2(1000, 52), Vector2(320, 112))
	_button(r, "DURUM", "wood", FS_B, Vector2(1344, 52), Vector2(280, 112))
	_button(r, "YENİLE (3)", "wood", FS_B, Vector2(1648, 52), Vector2(360, 112))
	_close_button(r, Vector2(2208, 52))
	## sol: seçilen eşyanın detayı + SATIN AL
	_inset(r, Vector2(88, 196), Vector2(640, 812))
	_detail_block(r, STOCK[6], STOCK_PRICES[6], Vector2(88, 196), Vector2(640, 812), "SATIN AL")
	## sağ: büyük kart ızgarası (4 sütun)
	for i in 8:
		var p := Vector2(760 + (i % 4) * 384, 196 + (i / 4) * 412)
		_stock_card(r, i, p, Vector2(368, 396), i == 6)


# ---------------------------------------------------------------------------------------------------------------------
# P2 - Sekmeli Pencere
# ---------------------------------------------------------------------------------------------------------------------

func _p2_karakter(r: Control) -> void:
	_panel(r, "menu", Vector2(32, 24), Vector2(2336, 1032))
	_back_button(r, Vector2(72, 56))
	_tabs(r, ["Karakter", "Yetenekler", "Ruhani: Para"], 0, Vector2(320, 56), 112)
	var ids: Array = Characters.DEFS.keys()
	for i in 14:
		if i >= ids.size():
			break
		_char_tile(r, ids[i], Vector2(84 + (i % 7) * 256, 208 + (i / 7) * 304), ids[i] == SEL_CHAR)
	_scroll_hint(r, Vector2(1880, 208), 600, 0.6)
	## sağ: kompakt vitrin
	_showcase(r, SEL_CHAR, Vector2(1936, 208), Vector2(400, 600), false)
	## alt eylem şeridi
	_inset(r, Vector2(72, 848), Vector2(2256, 168))
	var def: Dictionary = Characters.get_def(SEL_CHAR)
	_label(r, str(def.get("name", "")), FS_XL, MenuKit.C_TEXT, Vector2(112, 872), Vector2(400, 120))
	_stat_chips(r, SEL_CHAR, Vector2(480, 888))
	_skill_icons_row(r, SEL_CHAR, Vector2(1180, 864), 104, false)
	_button(r, "BAŞLA", "green", FS_XXL, Vector2(1868, 860), Vector2(440, 144))


func _p2_level(r: Control) -> void:
	_dim(r, 0.62)
	_title_plaque(r, "SEVİYE ATLADIN!", Vector2(W * 0.5, 84), FS_XL)
	for i in 3:
		_level_card_tall(r, LEVEL_CARDS[i], Vector2(W * 0.5 - 660 + i * 460, 160), Vector2(400, 640))
	_button(r, "Yeniden Karıştır (3 altın)", "wood", FS_B, Vector2((W - 720) * 0.5, 868), Vector2(720, 120))


func _p2_envanter(r: Control) -> void:
	_dim(r, 0.5)
	_panel(r, "game", Vector2(120, 32), Vector2(2160, 1016))
	_tabs(r, ["Envanter", "Özellikler"], 0, Vector2(176, 72), 112, "game")
	_close_button(r, Vector2(2120, 64))
	var x0: float = 176
	_label(r, "Silahlar", FS_B, UIKit.C_ACCENT, Vector2(x0, 216), Vector2(600, 48))
	for i in 5:
		_inv_slot(r, Vector2(x0 + i * 176, 272), 160, "weapon", INV_WEAPONS[i] if i < INV_WEAPONS.size() else "")
	_label(r, "Ekipman", FS_B, UIKit.C_ACCENT, Vector2(x0 + 960, 216), Vector2(600, 48))
	for i in 3:
		_inv_slot(r, Vector2(x0 + 960 + i * 176, 272), 160, "shield" if i == 0 else "", "shield_standart" if i == 0 else "")
	_label(r, "Eşyalar  ·  Efsanevi 0/5  ·  Epik 1/10  ·  Parça 3/5", FS_B, UIKit.C_ACCENT, Vector2(x0, 464), Vector2(1600, 48))
	for i in 10:
		_inv_slot(r, Vector2(x0 + i * 176, 520), 160, "item" if i < INV_ITEMS.size() else "", INV_ITEMS[i] if i < INV_ITEMS.size() else "", i == 1)
	## alt eylem şeridi: seçilen eşya + SAT
	_inset(r, Vector2(168, 744), Vector2(2064, 264))
	_icon_slot_tex(r, Items.icon("kol_saati"), Vector2(200, 776), 200, Items.kademe("kol_saati"))
	_label(r, Items.item_name("kol_saati"), FS_T, UIKit.C_TEXT, Vector2(432, 780), Vector2(900, 56))
	_wrap(r, _short(Items.describe("kol_saati"), 120), FS_S, UIKit.C_TEXT_DIM, Vector2(432, 848), Vector2(1100, 140))
	_gold_plaque(r, Vector2(1760, 76), "1250")
	_button(r, "SAT  +140", "red", FS_T, Vector2(1864, 880), Vector2(336, 112))


func _p2_tuccar(r: Control) -> void:
	_dim(r, 0.5)
	_panel(r, "game", Vector2(40, 32), Vector2(2320, 1016))
	_tabs(r, ["Silahlar", "Eşyalar", "Envanter", "Durum"], 1, Vector2(88, 64), 112, "game")
	_gold_plaque(r, Vector2(1376, 68), "1250")
	_button(r, "YENİLE (3)", "wood", FS_B, Vector2(1760, 64), Vector2(320, 112))
	_close_button(r, Vector2(2200, 64))
	for i in 5:
		var idx: int = 3 + i
		_stock_card(r, idx, Vector2(88 + i * 452, 216), Vector2(432, 500), idx == 6)
	_inset(r, Vector2(88, 744), Vector2(2224, 264))
	_icon_slot_tex(r, _stock_icon(STOCK[6]), Vector2(120, 776), 200, Items.kademe(STOCK[6][1]))
	_label(r, _stock_name(STOCK[6]), FS_T, UIKit.C_TEXT, Vector2(352, 780), Vector2(1000, 56))
	_wrap(r, _short(Items.describe(STOCK[6][1]), 130), FS_S, UIKit.C_TEXT_DIM, Vector2(352, 848), Vector2(1240, 140))
	_button(r, "SATIN AL  650", "green", FS_T, Vector2(1840, 872), Vector2(440, 120))


# ---------------------------------------------------------------------------------------------------------------------
# P3 - Alt Çekmece
# ---------------------------------------------------------------------------------------------------------------------

func _p3_karakter(r: Control) -> void:
	_back_button(r, Vector2(48, 32))
	## üst: büyük vitrin (çerçevesiz sahne) + ad + statlar + yetenek ikonları
	var def: Dictionary = Characters.get_def(SEL_CHAR)
	_stage(r, SEL_CHAR, Vector2(320, 24), true)
	_label(r, str(def.get("name", "")), FS_XXL, MenuKit.C_CREAM, Vector2(720, 56), Vector2(800, 96), 0, 4)
	_stat_chips(r, SEL_CHAR, Vector2(720, 168), true)
	_skill_icons_row(r, SEL_CHAR, Vector2(720, 312), 112, false)
	## sağ üst: ruhani + BAŞLA
	_icon_slot(r, load(SPIRITS[0][1]), Vector2(1712, 72), 136, "menu", true)
	_label(r, "Ruhani:\nPara", FS_B, MenuKit.C_CREAM, Vector2(1864, 80), Vector2(400, 120), 0, 4)
	_button(r, "BAŞLA", "green", FS_XXL, Vector2(1712, 256), Vector2(640, 168), "menu")
	## alt çekmece: tek sıra yatay kaydırmalı karakter kartları
	_sheet(r, 560, "menu")
	_label(r, "Karakterini Seç", FS_T, MenuKit.C_ACCENT, Vector2(0, 592), Vector2(W, 56), 1)
	var ids: Array = Characters.DEFS.keys()
	for i in 9:
		_char_tile(r, ids[i], Vector2(80 + i * 256, 664), ids[i] == SEL_CHAR)
	_swipe_hint(r, Vector2(W * 0.5, 1004))


func _p3_level(r: Control) -> void:
	_dim(r, 0.25)
	_sheet(r, 432, "game")
	_title_plaque(r, "SEVİYE ATLADIN!", Vector2(W * 0.5, 440), FS_T)
	for i in 3:
		_level_card_wide(r, LEVEL_CARDS[i], Vector2(96 + i * 752, 560), Vector2(704, 360))
	_button(r, "Karıştır (3 altın)", "wood", FS_B, Vector2(W - 96 - 520, 952), Vector2(520, 104))
	_label(r, "Kartın tamamına dokun", FS_S, UIKit.C_TEXT_DIM, Vector2(96, 976), Vector2(800, 56))


func _p3_envanter(r: Control) -> void:
	_dim(r, 0.2)
	_sheet(r, 392, "game")
	_title_plaque(r, "ENVANTER", Vector2(300, 404), FS_T)
	_gold_plaque(r, Vector2(560, 404), "1250")
	_close_button(r, Vector2(2200, 412))
	## tek yatay şerit: silahlar | ekipman | eşyalar
	var x: float = 96
	_label(r, "Silahlar", FS_B, UIKit.C_ACCENT, Vector2(x, 532), Vector2(400, 48))
	for i in 3:
		_inv_slot(r, Vector2(x + i * 168, 588), 152, "weapon", INV_WEAPONS[i] if i < INV_WEAPONS.size() else "")
	x += 3 * 168 + 48
	_label(r, "Ekipman", FS_B, UIKit.C_ACCENT, Vector2(x, 532), Vector2(400, 48))
	_inv_slot(r, Vector2(x, 588), 152, "shield", "shield_standart")
	x += 168 + 48
	_label(r, "Eşyalar", FS_B, UIKit.C_ACCENT, Vector2(x, 532), Vector2(400, 48))
	for i in 7:
		_inv_slot(r, Vector2(x + i * 168, 588), 152, "item" if i < INV_ITEMS.size() else "", INV_ITEMS[i] if i < INV_ITEMS.size() else "")
	_swipe_hint(r, Vector2(W * 0.5, 772))
	## altta: özellik çipleri (4 sütun)
	for i in 12:
		var p := Vector2(96 + (i % 4) * 556, 812 + (i / 4) * 80)
		_stat_chip(r, STATS[i], p, Vector2(540, 72))


func _p3_tuccar(r: Control) -> void:
	_dim(r, 0.2)
	_sheet(r, 300, "game")
	_title_plaque(r, "SEYYAR SATICI", Vector2(330, 312), FS_T)
	_gold_plaque(r, Vector2(640, 312), "1250")
	_button(r, "ENVANTER", "wood", FS_B, Vector2(1420, 316), Vector2(320, 104))
	_button(r, "YENİLE (3)", "wood", FS_B, Vector2(1764, 316), Vector2(320, 104))
	_close_button(r, Vector2(2208, 316))
	for i in 6:
		var idx: int = 2 + i
		_tall_stock_card(r, idx, Vector2(72 + i * 384, 448), Vector2(360, 600))
	_swipe_hint(r, Vector2(W * 0.5, 1064))


# ---------------------------------------------------------------------------------------------------------------------
# P4 - Yan Ray + Detay
# ---------------------------------------------------------------------------------------------------------------------

func _p4_karakter(r: Control) -> void:
	_rail(r, [load(str(Characters.get_def(SEL_CHAR).get("portrait", ""))), load(str(Characters.get_def(SEL_CHAR).get("skill_icon", ""))),
			load(SPIRITS[0][1])], ["Karakter", "Yetenek", "Ruhani"], 0, "menu")
	_panel(r, "menu", Vector2(232, 24), Vector2(1104, 1032))
	_label(r, "Karakterini Seç", FS_T, MenuKit.C_ACCENT, Vector2(232, 56), Vector2(1104, 56), 1)
	var ids: Array = Characters.DEFS.keys()
	for i in 12:
		_char_tile(r, ids[i], Vector2(280 + (i % 4) * 256, 136 + (i / 4) * 304), ids[i] == SEL_CHAR)
	_scroll_hint(r, Vector2(1300, 136), 880, 0.75)
	## sağ detay
	_panel(r, "menu", Vector2(1360, 24), Vector2(1008, 1032))
	var def: Dictionary = Characters.get_def(SEL_CHAR)
	_stage(r, SEL_CHAR, Vector2(1392, 64), false)
	_label(r, str(def.get("name", "")), FS_XL, MenuKit.C_TEXT, Vector2(1800, 72), Vector2(540, 80))
	_stat_chips(r, SEL_CHAR, Vector2(1800, 176))
	_skill_list(r, SEL_CHAR, Vector2(1400, 512), Vector2(928, 336))
	_button(r, "BAŞLA", "green", FS_XXL, Vector2(1400, 872), Vector2(928, 152), "menu")


func _p4_level(r: Control) -> void:
	_dim(r, 0.62)
	_title_plaque(r, "SEVİYE ATLADIN!", Vector2(700, 84), FS_XL)
	for i in 3:
		_level_row(r, LEVEL_CARDS[i], Vector2(96, 176 + i * 232), Vector2(1072, 200), i == 2)
	_button(r, "Karıştır (3 altın)", "wood", FS_B, Vector2(96, 900), Vector2(560, 120))
	## sağ detay: iki adımlı seçim (dokun -> SEÇ), savaş ortasında yanlışlıkla kart seçilmez
	_panel(r, "game", Vector2(1232, 40), Vector2(1128, 1000))
	var c: Array = LEVEL_CARDS[2]
	_stat_icon_big(r, c[4], Vector2(1296, 112), 224, int(c[1]))
	_label(r, str(c[0]), FS_XL, UIKit.C_TEXT, Vector2(1560, 120), Vector2(760, 80))
	_label(r, "%s  ·  %s" % [TIER_NAMES[int(c[1])], c[2]], FS_B, Color("#6a3fa0"), Vector2(1560, 216), Vector2(760, 56))
	_wrap(r, "Tüm silahlarının saldırı hızı kalıcı olarak artar. Epik kart: normal kartın 2 katı etkili.", FS_B,
			UIKit.C_TEXT_DIM, Vector2(1296, 384), Vector2(1000, 240))
	_label(r, "Saldırı Hızı   +%0  →  +%9.6", FS_T, UIKit.C_GOOD, Vector2(1296, 640), Vector2(1000, 64))
	_button(r, "SEÇ", "green", FS_XXL, Vector2(1296, 872), Vector2(1000, 136))


func _p4_envanter(r: Control) -> void:
	_dim(r, 0.5)
	_rail(r, [load(WEAPON_ICONS["dagger"]), load("res://assets/ui/shields/type_standart.png"), Items.icon("kanli_yakut"),
			load("res://assets/ui/level_up_icons/stat_damage.png")], ["Silah", "Ekipman", "Eşya", "Özellik"], 2, "game")
	_panel(r, "game", Vector2(232, 24), Vector2(1104, 1032))
	_label(r, "EŞYALAR", FS_T, UIKit.C_ACCENT, Vector2(232, 64), Vector2(1104, 56), 1)
	_label(r, "Efsanevi 0/5", FS_B, TIER_COLORS[3].darkened(0.35), Vector2(296, 152), Vector2(600, 48))
	for i in 5:
		_inv_slot(r, Vector2(296 + i * 200, 208), 184, "", "")
	_label(r, "Epik 1/10", FS_B, Color("#6a3fa0"), Vector2(296, 424), Vector2(600, 48))
	for i in 5:
		_inv_slot(r, Vector2(296 + i * 200, 480), 184, "item" if i == 0 else "", "kemik_kolye" if i == 0 else "")
	_label(r, "Parça 3/5", FS_B, UIKit.C_ACCENT, Vector2(296, 696), Vector2(600, 48))
	var parts := ["kanli_yakut", "kol_saati", "ruzgar_eldiveni"]
	for i in 5:
		_inv_slot(r, Vector2(296 + i * 200, 752), 184, "item" if i < 3 else "", parts[i] if i < 3 else "", i == 1)
	## sağ detay + SAT
	_panel(r, "game", Vector2(1360, 24), Vector2(1008, 1032))
	_close_button(r, Vector2(2216, 56))
	_detail_block(r, ["item", "kol_saati"], 280, Vector2(1360, 24), Vector2(1008, 1032), "SAT  +140", "red")
	_gold_plaque(r, Vector2(1400, 720), "1250")


func _p4_tuccar(r: Control) -> void:
	_dim(r, 0.5)
	_rail(r, [load(WEAPON_ICONS["tufek"]), Items.icon("kemik_kolye"), load(WEAPON_ICONS["dagger"]),
			load("res://assets/ui/level_up_icons/stat_max_health.png")], ["Silah", "Eşya", "Envanter", "Durum"], 1, "game")
	_panel(r, "game", Vector2(232, 24), Vector2(1104, 1032))
	_title_plaque(r, "SEYYAR SATICI", Vector2(560, 92), FS_T)
	_gold_plaque(r, Vector2(880, 52), "1250")
	for i in 4:
		var idx: int = 3 + i
		_stock_row(r, idx, Vector2(272, 176 + i * 168), Vector2(1024, 152), idx == 6)
	_scroll_hint(r, Vector2(1308, 176), 656, 0.8)
	_button(r, "YENİLE (3 altın)", "wood", FS_B, Vector2(272, 880), Vector2(1024, 120))
	_panel(r, "game", Vector2(1360, 24), Vector2(1008, 1032))
	_close_button(r, Vector2(2216, 56))
	_detail_block(r, STOCK[6], STOCK_PRICES[6], Vector2(1360, 24), Vector2(1008, 1032), "SATIN AL  650")


# ---------------------------------------------------------------------------------------------------------------------
# Yapı taşları (oyunun kendi kit dokuları)
# ---------------------------------------------------------------------------------------------------------------------

func _begin(menu: bool) -> Control:
	_layer = CanvasLayer.new()
	_layer.layer = 120
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_layer)
	var r := Control.new()
	r.theme = MenuKit.theme() if menu else UIKit.theme()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(r)
	r.set_meta("menu", menu)
	if menu:
		MenuKit.add_background(r)
	return r


func _is_menu(r: Control) -> bool:
	return bool(r.get_meta("menu", false))


func _dim(r: Control, a: float) -> void:
	var c := ColorRect.new()
	c.color = Color(0.05, 0.03, 0.02, a)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.add_child(c)


func _place(c: Control, pos: Vector2, sz: Vector2) -> void:
	MenuKit.place(c, pos, sz)


func _panel(r: Control, kind: String, pos: Vector2, sz: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", MenuKit.style("panel") if kind == "menu" else UIKit.panel_style("window"))
	r.add_child(p)
	_place(p, pos, sz)
	return p


func _inset(r: Control, pos: Vector2, sz: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", MenuKit.style("inset") if _is_menu(r) else UIKit.panel_style("inset"))
	r.add_child(p)
	_place(p, pos, sz)
	return p


## Alt çekmece: ahşap pencere ekranın altından taşar (alt kenar görünmez).
func _sheet(r: Control, top: float, kind: String) -> void:
	_panel(r, kind, Vector2(24, top), Vector2(W - 48, H - top + 60))


func _label(r: Control, text: String, fs: int, col: Color, pos: Vector2, sz: Vector2, align: int = 0, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color("#2a170c"))
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(l)
	_place(l, pos, sz)
	return l


func _wrap(r: Control, text: String, fs: int, col: Color, pos: Vector2, sz: Vector2) -> Label:
	var l := _label(r, text, fs, col, pos, sz)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.clip_text = true
	return l


func _button(r: Control, text: String, variant: String, fs: int, pos: Vector2, sz: Vector2, kit: String = "") -> Button:
	var b := Button.new()
	b.text = text
	r.add_child(b)
	if kit == "menu" or (kit == "" and _is_menu(r)):
		MenuKit.style_button(b, {"wood": "tan", "green": "sage", "red": "rose", "dark": "tan"}.get(variant, "tan"), fs)
	else:
		UIKit.style_button(b, variant, false, fs)
	_place(b, pos, sz)
	return b


func _tex_rect(r: Control, tex: Texture2D, pos: Vector2, sz: Vector2, keep: bool = false) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep else TextureRect.STRETCH_SCALE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(t)
	_place(t, pos, sz)
	return t


## İkonu tam sayı katında büyüt (piksel keskin): kutuya sığan en büyük tam kat.
func _icon_int(r: Control, tex: Texture2D, center: Vector2, box: float) -> void:
	if tex == null:
		return
	var s: Vector2 = tex.get_size()
	## Büyütmede tam sayı kat (keskin); büyük üretilmiş dokular (144/250/329 px) kutuya sığacak kadar küçültülür.
	var k: float = box / maxf(s.x, s.y)
	if k >= 1.0:
		k = floorf(k)
	var sz: Vector2 = s * k
	_tex_rect(r, tex, (center - sz * 0.5).round(), sz)


func _banner(r: Control, text: String, y: float) -> void:
	var b := MenuKit.make_banner(text, FS_T)
	r.add_child(b)
	var s: Vector2 = b.get_combined_minimum_size()
	_place(b, Vector2(roundf((W - s.x) / 6.0) * 3.0, y), s)


func _title_plaque(r: Control, text: String, center: Vector2, fs: int) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.panel_style("plaque") if not _is_menu(r) else MenuKit.style("banner"))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", UIKit.C_TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	r.add_child(p)
	var s: Vector2 = p.get_combined_minimum_size() + Vector2(48, 12)
	_place(p, (center - s * 0.5).round(), s)


func _gold_plaque(r: Control, pos: Vector2, amount: String) -> void:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UIKit.panel_style("plaque"))
	r.add_child(p)
	_place(p, pos, Vector2(320, 104))
	_icon_int(r, _coin(),
			pos + Vector2(72, 52), 56)
	_label(r, amount, FS_T, UIKit.C_GOLD, pos + Vector2(112, 0), Vector2(190, 104), 1)


func _coin() -> Texture2D:
	var a := AtlasTexture.new()
	a.atlas = load("res://assets/pickups/gold/gold_coin.png")
	a.region = Rect2(0, 0, 16, 16)
	return a


func _gold_bar(r: Control, pos: Vector2, sz: Vector2) -> void:
	_inset(r, pos, sz)
	_label(r, "Altın 1250    ·    Parça 0", FS_B, UIKit.C_GOLD, pos, sz, 1)


func _close_button(r: Control, pos: Vector2) -> void:
	_button(r, "X", "red", FS_T, pos, Vector2(112, 112))


func _back_button(r: Control, pos: Vector2) -> void:
	_button(r, "< Geri", "wood", FS_B, pos, Vector2(232, 104))


func _tabs(r: Control, names: Array, active: int, pos: Vector2, h: float, kit: String = "menu") -> void:
	var x: float = pos.x
	for i in names.size():
		var w: float = maxf(300.0, 40.0 * 0.5 * String(names[i]).length() * 1.25 + 96.0)
		var b := _button(r, names[i], "green" if i == active else ("wood" if kit == "menu" else "dark"), FS_T,
				Vector2(x, pos.y), Vector2(w, h), kit)
		x += w + 16.0


func _rail(r: Control, icons: Array, names: Array, active: int, kit: String) -> void:
	_panel(r, kit, Vector2(24, 24), Vector2(192, 1032))
	for i in icons.size():
		var y: float = 64 + i * 232
		var b := _button(r, "", "green" if i == active else ("wood" if kit == "menu" else "dark"), FS_S,
				Vector2(48, y), Vector2(144, 144), kit)
		_icon_int(r, icons[i], Vector2(120, y + 68), 96)
		_label(r, names[i], FS_S, MenuKit.C_CREAM if kit == "game" else MenuKit.C_TEXT, Vector2(24, y + 152), Vector2(192, 40), 1,
				4 if kit == "game" else 0)


## Kademeli yuva (tier_slot_N dokusu) + ikon.
func _icon_slot_tex(r: Control, tex: Texture2D, pos: Vector2, size: float, tier: int = 1, selected: bool = false) -> void:
	_tex_rect(r, load("res://assets/ui/game/tier_slot_%d.png" % clampi(tier, 1, 4)), pos, Vector2(size, size))
	if selected:
		_tex_rect(r, MenuKit.tex("slot_selected.png", MenuKit.GAME_DIR), pos - Vector2(6, 6), Vector2(size + 12, size + 12))
	_icon_int(r, tex, pos + Vector2(size, size) * 0.5, size * 0.72)


func _icon_slot(r: Control, tex: Texture2D, pos: Vector2, size: float, kit: String, selected: bool) -> void:
	var dir: String = MenuKit.DIR if kit == "menu" else MenuKit.GAME_DIR
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", MenuKit.style("slot_selected" if selected else "slot_normal", dir))
	r.add_child(p)
	_place(p, pos, Vector2(size, size))
	_icon_int(r, tex, pos + Vector2(size, size) * 0.5, size - 20)


func _inv_slot(r: Control, pos: Vector2, size: float, type: String, key: String, selected: bool = false) -> void:
	if type == "" or key == "":
		_tex_rect(r, load("res://assets/ui/game/slot_cell.png"), pos, Vector2(size, size))
		return
	_icon_slot_tex(r, _type_icon(type, key), pos, size, Items.kademe(key) if type == "item" else 1, selected)


func _type_icon(type: String, key: String) -> Texture2D:
	match type:
		"item":
			return Items.icon(key)
		"weapon":
			return load(WEAPON_ICONS.get(key, WEAPON_ICONS["dagger"]))
		"shield":
			return load("res://assets/ui/shields/type_standart.png")
	return null


func _stock_icon(e: Array) -> Texture2D:
	return _type_icon(e[0], e[1])


func _stock_name(e: Array) -> String:
	return Items.item_name(e[1]) if e[0] == "item" else str(WEAPON_NAMES.get(e[1], e[1]))


func _stock_tier(e: Array) -> int:
	return Items.kademe(e[1]) if e[0] == "item" else 1


func _short(t: String, n: int) -> String:
	t = t.replace("\n", " ")
	return t if t.length() <= n else t.substr(0, n).rstrip(" ,.") + "..."


func _scroll_hint(r: Control, pos: Vector2, h: float, frac: float) -> void:
	var track := ColorRect.new()
	track.color = Color(0.2, 0.12, 0.06, 0.35)
	r.add_child(track)
	_place(track, pos, Vector2(12, h))
	var g := ColorRect.new()
	g.color = Color("#8a5a2e")
	r.add_child(g)
	_place(g, pos, Vector2(12, h * frac))


func _swipe_hint(r: Control, center: Vector2) -> void:
	_label(r, "◀   kaydır   ▶", FS_B, UIKit.C_TEXT_DIM, center - Vector2(300, 24), Vector2(600, 48), 1)


## Karakter kartı 4x (menü kart dokusu 3x -> tam 4/3: her sanat pikseli 4 ekran pikseli). 240x288.
func _char_tile(r: Control, id: int, pos: Vector2, selected: bool) -> void:
	_tex_rect(r, MenuKit.tex("card_selected.png" if selected else "card_normal.png"), pos, Vector2(240, 288))
	var def: Dictionary = Characters.get_def(id)
	var pv: Control = load(PreviewScript).new()
	r.add_child(pv)
	_place(pv, pos, Vector2(240, 288))
	pv.call("setup", def, 4, MenuKit.CARD_GROUND_Y * 4.0 / 3.0)
	var plate: Rect2 = MenuKit.CARD_PLATE_RECT
	var l := _label(r, str(def.get("name", "")), FS_B, MenuKit.C_TEXT, pos + plate.position * 4.0 / 3.0,
			plate.size * 4.0 / 3.0, 1)
	MenuKit.fit_label_font(l, l.text, FS_B, plate.size.x * 4.0 / 3.0 - 8.0)
	l.clip_text = true


func _stage(r: Control, id: int, pos: Vector2, play: bool) -> void:
	var st: Dictionary = MenuKit.STAGE_BIG
	_tex_rect(r, MenuKit.tex(st["file"]), pos, st["size"])
	var pv: Control = load(PreviewScript).new()
	r.add_child(pv)
	_place(pv, pos, st["size"])
	pv.call("setup", Characters.get_def(id), int(st["scale"]), float(st["ground_y"]))
	pv.set("playing", play)


func _showcase(r: Control, id: int, pos: Vector2, sz: Vector2, with_stats: bool) -> void:
	_panel(r, "menu", pos, sz)
	var def: Dictionary = Characters.get_def(id)
	_label(r, str(def.get("name", "")), FS_T, MenuKit.C_TEXT, pos + Vector2(0, 28), Vector2(sz.x, 56), 1)
	var st: Dictionary = MenuKit.STAGE_BIG
	var stage_size: Vector2 = st["size"]
	var sp := Vector2(pos.x + roundf((sz.x - stage_size.x) / 6.0) * 3.0, pos.y + 96)
	if not with_stats:
		stage_size = Vector2(336, 336)
		_tex_rect(r, MenuKit.tex(st["file"]), sp, stage_size)
		var pv0: Control = load(PreviewScript).new()
		r.add_child(pv0)
		_place(pv0, sp, stage_size)
		pv0.call("setup", def, 5, 300.0)
		return
	_stage(r, id, sp, true)
	_stat_chips(r, id, pos + Vector2(36, 540), false, 2)
	_button(r, "BAŞLA", "green", FS_XXL, pos + Vector2(32, sz.y - 184), Vector2(sz.x - 64, 152), "menu")


## Can/Hız/Hasar/Atış çipleri (menü stat ikonları 3x).
func _stat_chips(r: Control, id: int, pos: Vector2, light: bool = false, cols: int = 2) -> void:
	var def: Dictionary = Characters.get_def(id)
	var vals: Array = []
	for s in MenuKit.BASE_STATS:
		vals.append([s["icon"], "%s %s" % [s["label"], s["value"]]])
	for i in 4:
		var p: Vector2 = pos + Vector2((i % cols) * 236, (i / cols) * 64)
		_icon_int(r, MenuKit.tex(vals[i][0]), p + Vector2(24, 28), 48)
		_label(r, vals[i][1], FS_B, MenuKit.C_CREAM if light else MenuKit.C_TEXT, p + Vector2(56, 0), Vector2(180, 56), 0, 4 if light else 0)


func _skill_icons_row(r: Control, id: int, pos: Vector2, size: float, with_names: bool) -> void:
	var def: Dictionary = Characters.get_def(id)
	var keys := [["skill2_icon", "E", "skill2_name"], ["skill_icon", "Q", "skill_name"], ["skill3_icon", "R", "skill3_name"],
			["passive_icon", "Pasif", ""]]
	for i in keys.size():
		var x: float = pos.x + i * (size + (176 if with_names else 24))
		var path: String = str(def.get(keys[i][0], ""))
		var tex: Texture2D = load(path) if path != "" and ResourceLoader.exists(path) else null
		_icon_slot(r, tex, Vector2(x, pos.y), size, "menu", false)
		if with_names:
			_label(r, keys[i][1], FS_B, MenuKit.C_ACCENT, Vector2(x + size + 16, pos.y + 4), Vector2(150, 48))
			var nm: String = str(def.get(keys[i][2], "Papağan")) if keys[i][2] != "" else "Papağan"
			_wrap(r, nm, FS_S, MenuKit.C_TEXT, Vector2(x + size + 16, pos.y + 56), Vector2(160, 80))
		else:
			_label(r, keys[i][1], FS_S, MenuKit.C_CREAM, Vector2(x, pos.y + size + 4), Vector2(size, 40), 1, 4)


func _skill_list(r: Control, id: int, pos: Vector2, sz: Vector2) -> void:
	_inset(r, pos, sz)
	var def: Dictionary = Characters.get_def(id)
	var rows := [["skill_icon", "Q", "skill_name", "skill_desc"], ["skill2_icon", "E", "skill2_name", "skill2_desc"],
			["skill3_icon", "R", "skill3_name", "skill3_desc"]]
	for i in rows.size():
		var y: float = pos.y + 16 + i * 104
		var path: String = str(def.get(rows[i][0], ""))
		_icon_slot(r, load(path) if ResourceLoader.exists(path) else null, Vector2(pos.x + 16, y), 96, "menu", false)
		_label(r, "%s  %s" % [rows[i][1], def.get(rows[i][2], "")], FS_B, MenuKit.C_TEXT, Vector2(pos.x + 128, y), Vector2(780, 48))
		_label(r, _short(str(def.get(rows[i][3], "")).split(": ", true, 1)[-1], 52), FS_S, MenuKit.C_TEXT_DIM,
				Vector2(pos.x + 128, y + 48), Vector2(790, 44))


func _stat_row(r: Control, s: Array, pos: Vector2, w: float, h: float) -> void:
	_icon_int(r, load("res://assets/ui/level_up_icons/%s.png" % s[0]), pos + Vector2(24, h * 0.5), 48)
	_label(r, s[1], FS_B, UIKit.C_TEXT, pos + Vector2(72, 0), Vector2(w * 0.6, h))
	_label(r, s[2], FS_B, UIKit.C_TEXT_DIM, pos + Vector2(w * 0.55, 0), Vector2(w * 0.45 - 8, h), 2)


func _stat_chip(r: Control, s: Array, pos: Vector2, sz: Vector2) -> void:
	_inset(r, pos, sz)
	_stat_row(r, s, pos + Vector2(8, 4), sz.x - 24, sz.y - 8)


func _stat_icon_big(r: Control, stat: String, pos: Vector2, size: float, tier: int) -> void:
	_tex_rect(r, load("res://assets/ui/game/tier_slot_%d.png" % (tier + 1)), pos, Vector2(size, size))
	_icon_int(r, load("res://assets/ui/level_up_icons/%s.png" % stat), pos + Vector2(size, size) * 0.5, size * 0.6)


## Masaüstü level satırı (levelup_row_N 804x150) tam 4/3 -> 1072x200, yazılar 48/40/80.
func _level_row(r: Control, c: Array, pos: Vector2, sz: Vector2, selected: bool = false) -> void:
	var tier: int = int(c[1])
	if selected:
		_tex_rect(r, load("res://assets/ui/game/levelup_row_glow.png"), pos - Vector2(20, 20), sz + Vector2(40, 40))
	_tex_rect(r, load("res://assets/ui/game/levelup_row_%d.png" % (tier + 1)), pos, sz)
	_icon_int(r, load("res://assets/ui/level_up_icons/%s.png" % c[4]), pos + Vector2(112, 100), 120)
	_label(r, c[0], FS_T, C_ROW_TEXT, pos + Vector2(208, 28), Vector2(520, 64))
	_label(r, "%s  ·  %s" % [TIER_NAMES[tier], c[2]], FS_B, TIER_COLORS[tier], pos + Vector2(208, 104), Vector2(520, 56))
	_label(r, c[3], FS_XXL, C_VALUE, pos + Vector2(sz.x - 448, 20), Vector2(400, 96), 2)
	_label(r, "artar", FS_B, C_ROW_DIM, pos + Vector2(sz.x - 448, 116), Vector2(400, 56), 2)


## Dikey kart (tier_card_N 300x480 tam 4/3 -> 400x640).
func _level_card_tall(r: Control, c: Array, pos: Vector2, sz: Vector2) -> void:
	var tier: int = int(c[1])
	_tex_rect(r, load("res://assets/ui/game/tier_card_%d.png" % (tier + 1)), pos, sz)
	## Doku düzeni (4x): amblem kalkanı y ~110..330, isim kurdelesi y ~272..320, parşömen kutu y ~340..600.
	_icon_int(r, load("res://assets/ui/level_up_icons/%s.png" % c[4]), pos + Vector2(sz.x * 0.5, 190), 128)
	_label(r, c[0], FS_B, C_ROW_TEXT, pos + Vector2(40, 272), Vector2(sz.x - 80, 48), 1, 4)
	_label(r, "%s  ·  %s" % [TIER_NAMES[tier], c[2]], FS_B, [UIKit.C_TEXT_DIM, Color("#2c5c9a"), Color("#6a3fa0"), Color("#9a5a10")][tier],
			pos + Vector2(0, 360), Vector2(sz.x, 56), 1)
	_label(r, c[3], FS_XXL, UIKit.C_GOOD, pos + Vector2(0, 428), Vector2(sz.x, 96), 1)
	_label(r, "artar", FS_B, UIKit.C_TEXT_DIM, pos + Vector2(0, 520), Vector2(sz.x, 48), 1)


## Geniş kart (alt çekmece): parşömen kart çerçevesi + solda büyük ikon.
func _level_card_wide(r: Control, c: Array, pos: Vector2, sz: Vector2) -> void:
	var tier: int = int(c[1])
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UIKit.panel_style("card_selected" if tier >= 2 else "card"))
	r.add_child(p)
	_place(p, pos, sz)
	_stat_icon_big(r, c[4], pos + Vector2(32, 48), 192, tier)
	_label(r, c[0], FS_T, UIKit.C_TEXT, pos + Vector2(256, 48), Vector2(420, 64))
	_label(r, TIER_NAMES[tier], FS_B, [UIKit.C_TEXT_DIM, Color("#2c5c9a"), Color("#6a3fa0"), Color("#9a5a10")][tier],
			pos + Vector2(256, 120), Vector2(420, 56))
	_label(r, c[3], FS_XXL, UIKit.C_GOOD, pos + Vector2(256, 200), Vector2(420, 96))
	_label(r, "%s statın artar" % c[2].to_lower(), FS_S, UIKit.C_TEXT_DIM, pos + Vector2(32, 284), Vector2(sz.x - 64, 48))


func _stock_card(r: Control, idx: int, pos: Vector2, sz: Vector2, selected: bool) -> void:
	var e: Array = STOCK[idx]
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UIKit.panel_style("card_selected" if selected else "card"))
	r.add_child(p)
	_place(p, pos, sz)
	var s: float = minf(184.0, sz.y * 0.42)
	_icon_slot_tex(r, _stock_icon(e), pos + Vector2((sz.x - s) * 0.5, 32), s, _stock_tier(e))
	_label(r, _stock_name(e), FS_B, UIKit.C_TEXT, pos + Vector2(8, 48 + s), Vector2(sz.x - 16, 56), 1)
	if sz.y > 440:
		_label(r, Items.KADEME_NAMES[_stock_tier(e) - 1] if e[0] == "item" else "Silah", FS_S, UIKit.C_TEXT_DIM,
				pos + Vector2(8, 104 + s), Vector2(sz.x - 16, 48), 1)
	_label(r, "%d altın" % STOCK_PRICES[idx], FS_B, UIKit.C_GOLD, pos + Vector2(8, sz.y - 88), Vector2(sz.x - 16, 56), 1)


func _tall_stock_card(r: Control, idx: int, pos: Vector2, sz: Vector2) -> void:
	var e: Array = STOCK[idx]
	var tier: int = _stock_tier(e)
	_tex_rect(r, load("res://assets/ui/game/tier_card_%d.png" % clampi(tier, 1, 4)), pos, sz)
	_icon_slot_tex(r, _stock_icon(e), pos + Vector2((sz.x - 176) * 0.5, 72), 176, tier)
	var nm := _label(r, _stock_name(e), FS_B, C_ROW_TEXT, pos + Vector2(56, 268), Vector2(sz.x - 112, 48), 1, 4)
	MenuKit.fit_label_font(nm, nm.text, FS_B, sz.x - 120)
	_wrap(r, _short(Items.describe(e[1]), 44) if e[0] == "item" else "Silah", FS_S, UIKit.C_TEXT_DIM,
			pos + Vector2(36, 360), Vector2(sz.x - 72, 112)).horizontal_alignment = 1
	_button(r, "%d" % STOCK_PRICES[idx], "green", FS_T, pos + Vector2(36, sz.y - 136), Vector2(sz.x - 72, 104))


func _stock_row(r: Control, idx: int, pos: Vector2, sz: Vector2, selected: bool) -> void:
	var e: Array = STOCK[idx]
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UIKit.panel_style("card_selected" if selected else "card"))
	r.add_child(p)
	_place(p, pos, sz)
	_icon_slot_tex(r, _stock_icon(e), pos + Vector2(16, 12), sz.y - 24, _stock_tier(e))
	_label(r, _stock_name(e), FS_T, UIKit.C_TEXT, pos + Vector2(sz.y + 8, 16), Vector2(600, 64))
	_label(r, Items.KADEME_NAMES[_stock_tier(e) - 1] if e[0] == "item" else "Silah", FS_B, UIKit.C_TEXT_DIM,
			pos + Vector2(sz.y + 8, 76), Vector2(600, 56))
	_label(r, "%d altın" % STOCK_PRICES[idx], FS_T, UIKit.C_GOLD, pos + Vector2(sz.x - 360, 0), Vector2(320, sz.y), 2)


## Seçilen eşya/silah: büyük ikon, ad, kademe, açıklama, eylem düğmesi (alt kenarda, başparmak menzili).
func _detail_block(r: Control, e: Array, price: int, pos: Vector2, sz: Vector2, action: String, variant: String = "green") -> void:
	var s: float = 224.0
	var narrow: bool = sz.x < 800
	_icon_slot_tex(r, _stock_icon(e), pos + Vector2((sz.x - s) * 0.5 if narrow else 48.0, 48), s, _stock_tier(e))
	var tx: float = 32.0 if narrow else 304.0
	var ty: float = 48.0 + s + 24.0 if narrow else 64.0
	_label(r, _stock_name(e), FS_T, UIKit.C_TEXT, pos + Vector2(tx, ty), Vector2(sz.x - tx - 32, 64), 1 if narrow else 0)
	_label(r, (Items.KADEME_NAMES[_stock_tier(e) - 1] if e[0] == "item" else "Silah") + "  ·  %d altın" % price, FS_B,
			UIKit.C_GOLD, pos + Vector2(tx, ty + 64), Vector2(sz.x - tx - 32, 56), 1 if narrow else 0)
	var desc_y: float = ty + 136 if narrow else 320.0
	_wrap(r, _short(Items.describe(e[1]), 220 if narrow else 260) if e[0] == "item" else "Silah", FS_B if not narrow else FS_S,
			UIKit.C_TEXT_DIM, pos + Vector2(40, desc_y), Vector2(sz.x - 80, sz.y - desc_y - 200))
	_button(r, action, variant, FS_T, pos + Vector2(40, sz.y - 176), Vector2(sz.x - 80, 136))


# ---------------------------------------------------------------------------------------------------------------------

func _force_phone_window() -> void:
	var want := Vector2i(2400, 1080)
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if DisplayServer.window_get_size() != want:
		DisplayServer.window_set_size(want)
		DisplayServer.window_set_position(Vector2i(0, 0))
		for i in 6:
			await process_frame


func _shot(name: String) -> void:
	await _force_phone_window()
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(_dir.path_join(name + ".png"))
	print("SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])


func _wait(sec: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame


func _wait_frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(cond: Callable, timeout: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < int(timeout * 1000.0):
		await process_frame


func _all_nodes(n: Node) -> Array:
	var out: Array = [n]
	for c in n.get_children():
		out.append_array(_all_nodes(c))
	return out
