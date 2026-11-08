extends RefCounted

## OYUNUN TEK ARAYÜZ PALETİ (stil rehberi, madde 403, 2026-11-06; kural metni docs/stil_rehberi.md).
## Kaynağı HUD TEMASI "Kısık Ahşap" (madde 207/202). Bütün arayüz kitleri (menu_dark_kit, shop_dark_kit, fire_menu_kit,
## phone_menu_kit, oyun bitti, ruh mağazası, rekorlar...) renklerini BURADAN okur - kitte yeni hex YAZMA, rol ekle.
## HUD dokuları tools/gen_hud_tema.py PAL ile üretilir - üstteki HUD değerleri onunla AYNI tutulmalı.
## Levhalar orta-koyu kahve -> yazılar AÇIK (UIKit.C_TEXT/C_GOLD bej zemin içindir, burada okunmaz).
## Kullanım: const HudTheme := preload("res://scripts/hud_theme.gd") ; HudTheme.TEXT
## (class_name YOK: yeni class_name -s koşularında görünmüyor, bkz. hafıza godot-cli-testing.)

const OUTLINE := Color("#20150d") ## dış hat / çubuk konturu
const RIM := Color("#6a4a30") ## ahşap kenar
const RIM_HI := Color("#86623f")
const RIM_LO := Color("#4b3320")
const PANEL := Color("#5a4734") ## panel içi
const INSET := Color("#271a11") ## kuyu: çubuk/yuva/levha içi
const STRIPE := Color("#342316") ## kuyu satır şeridi (INSET -> RIM_LO %35)
const MARK := Color("#392618") ## boş yuva işareti (INSET -> RIM_LO %50)
const PLATE_ON := Color("#3e2b1c") ## açık düğme levhası (INSET -> RIM %35)
const PLATE_HOVER := Color("#342417") ## (INSET -> RIM %20)
const DIVIDER := Color("#20150d99") ## Q-E-R / küçük yuvalar ayracı
## Can çubuğu rengi (madde 473, kullanıcı: "canın yeşili pek istediğim gibi değil"): eskisi kırmızı -> yeşil RGB karışımıydı, %70 canda
## bile çamurlu zeytin (#78a645) çıkıyor, ahşap panelde kahveye karışıyordu. Artık HP_GREEN_UNTIL'e kadar düz yeşil (LoL gibi), altında
## renk TONU üstünden (sarı-amber) kırmızıya; ara tonlar temiz kalır. Dock + grup paneli bunu kullanır.
const HP_GREEN := Color("#3f9a3c") ## D "Orman" (kullanıcı seçimi)
const HP_RED := Color("#d63838")
const HP_GREEN_UNTIL := 0.5
## Kalkan çubuğu dolgusu + değer yazısı (oyuncu paneli ve madde 479'dan beri grup paneli masaüstü çubukları ortak).
const SHIELD_BAR := Color(0.24, 0.59, 0.91)
const SHIELD_VALUE := Color("#bfe0ff")
const HP_RED_BELOW := 0.2 ## bunun altında düz kırmızı (düşük can uyarısı turuncuya kaymasın)


static func hp_color(pct: float, green: Color = HP_GREEN) -> Color:
	if pct >= HP_GREEN_UNTIL:
		return green
	var t: float = clampf((pct - HP_RED_BELOW) / (HP_GREEN_UNTIL - HP_RED_BELOW), 0.0, 1.0)
	return Color.from_hsv(lerpf(HP_RED.h, green.h, t), lerpf(HP_RED.s, green.s, t), lerpf(HP_RED.v, green.v, t))


## Oyuncu paneli (dock) "C Gömme Tepsi" (madde 454): koyu tepsinin içindeki kuyular bir ton koyu (INSET'ten koyu, RIM_LO'ya karışımlar).
const DOCK_INSET := Color("#1c120b") ## çubuk/yuva/kalp levhası/stat düğmesi altı
const DOCK_MARK := Color("#342316") ## boş efsanevi yuva işareti (DOCK_INSET -> RIM_LO %50)
const DOCK_STRIPE := Color("#2c1e12") ## stat paneli satır şeridi + stat düğmesi üstüne gelince (DOCK_INSET -> RIM_LO %35)
const DOCK_PLATE_ON := Color("#382618") ## stat düğmesi açık (DOCK_INSET -> RIM_LO %60)

const TEXT := Color("#f3e6cc") ## levhada ana yazı
const DIM := Color("#c4b090") ## ikincil yazı
const PRICE := Color("#f6d27e") ## altın/sayı
const ACCENT := Color("#f0c070") ## başlık / birinci sıra
const GOOD := Color("#b5d98a")
const BAD := Color("#f09a80") ## uyarı / yere düştü (kahve zeminde okunur kırmızı)
const SHARD := Color("#b8e0f4") ## silah parçacığı sayısı
const ACCENT_SOFT := Color("#e2c08a") ## sönük altın (seçili olmayan başlık, ikincil vurgu)
const ACCENT_DK := Color("#6a4416") ## altın düğmenin kenarı / koyu altın
const ACCENT_TEXT := Color("#24160a") ## altın zemin üstündeki yazı
const SPOT := Color("#c0803a") ## sahne ışığı / sıcak parıltı
## Yetenek evrimi kartı (madde 428): ANLAMLI renk (kullanıcı 2026-10-02: normal evrim mor, final kırmızı) - yalnız kart kenarı,
## simge yuvası kenarı ve ilerleme pipi; zemin ya da yazı rengi olarak kullanılmaz (stil rehberi bölüm 1).
const EVO_EDGE := Color("#8a5fd0")
const EVO_FINAL_EDGE := Color("#d0523e")
## Evrim kartının GÖVDESİ (madde 461, kullanıcı 2026-11-08: "eski efsun kartındaki gibi renk"): eski efsun kartı dokusunun gövde rengi
## (normal mor / final koyu kırmızı-kahve) - ANLAMLI renk, yalnız evrim kartının iç kutu dışı gövdesi.
const EVO_FILL := Color("#2c233a")
const EVO_FINAL_FILL := Color("#332123")
## Level pazarında KAYDET'lenen seçenek (madde 433, kullanıcı 2026-11-06 "B - Yosun Kuyu" + kilit simgesi): ANLAMLI renk - pazarda yeşil
## kenar yalnız "kayıtlı" demek (silah geliştirme satırının tür kenarı bu yüzden turuncu). Okuyan: level_market_view.gd.
const SAVED := GOOD ## "KAYITLI" yazısı, kilit simgesi, ayrıntıdaki kayıt satırı
const SAVED_EDGE := Color("#8fb466") ## kayıtlı yuva / satır / ayrıntı kuyusu kenarı (GOOD'un bir ton koyusu)
const SAVED_FILL := Color("#2d2b17") ## kayıtlı yuvanın içi (INSET -> yosun #3a4c22 %34)
const SAVED_FILL_HOVER := Color("#2f2f18") ## üstündeyken (%42)
const SAVED_BTN := Color("#7c9f52") ## kayıtlıyken kilit düğmesi zemini (simge ACCENT_TEXT)
const SAVED_BTN_EDGE := Color("#3d5126") ## koyu yosun: kilit düğmesi kenarı
## Level kartı satırının KADEME kenarı (madde 456): ANLAMLI renk (Sıradan gri / Nadir mavi / Epik mor / Efsanevi kırmızımsı), Yüzen Kapsül
## satırlarının kademe tonuyla aynı (level_up_screen.gd ROW_TIER_TEXT). Efsanevi ALTIN değil: altın kenar "üstünde / seçili" demek.
## Okuyan: level_market_view.gd _style_card (kart kipi).
const LEVEL_TIER_EDGE := [Color("#cdd1d6"), Color("#a6c6f4"), Color("#d8aef4"), Color("#f8a890")]

## PENCERE ZEMİNLERİ (menüler, dükkanlar, oyun bitti, telefon ekranları): HUD rampasının koyu ucu.
## Sıra koyudan açığa: DEEP < WIN_INSET < OUTLINE < WIN_PANEL < WIN_PANEL2 < WIN_PANEL3 ; çizgi WIN_LINE < WIN_LINE_HI.
const DEEP := Color("#140e09") ## en koyu: kaydırıcı yuvası, kuyu dibi, sahne karartması
const WIN_INSET := Color("#1a110a") ## pencere içindeki kuyu / gömme kutu
const WIN_PANEL := INSET ## pencere zemini
const WIN_PANEL2 := STRIPE ## iç kart / satır şeridi
const WIN_PANEL3 := PLATE_ON ## seçili / üstüne gelinen kart
const WIN_LINE := RIM_LO ## kenar çizgisi
const WIN_LINE_HI := RIM ## vurgulu kenar

## YARATIK HASAR SAYILARI (madde 429, kullanıcı 2026-11-06: "hasar sayıları çok göz yoruyor, karmaşık"): saf beyaz + saf siyah kontür yerine
## sıcak krem + OUTLINE kahvesi; kritik doygun kırmızı yerine turuncu-altın; süreli hasar kendi soluk tonunda. Okuyan: damage_numbers.gd spawn_hit (madde 429).
const DMG_HIT := Color("#f2dcb4") ## normal vuruş: sıcak krem
const DMG_CRIT := Color("#f7a04a") ## kritik: turuncu-altın (sayılar içinde en doygun renk)
const DMG_DOT_POISON := Color("#b5d98a") ## zehir / arı zehri (= GOOD)
const DMG_DOT_BURN := Color("#eba873") ## yanma
const DMG_DOT_BLEED := Color("#e5917c") ## kanama
const DMG_DOT := Color("#d9c09a") ## diğer süreli hasar

## Koyu levhada okunan "mürekkep" renkleri (BBCode hex) - UIKit.INK'in (bej zemin) koyu HUD karşılığı, anahtarlar AYNI.
## Yetenek ipucu (skill_icon.gd _format_lol_style, hud_tooltip.gd) buradan okur.
const INK := {
	"health": "#a9dc86",
	"damage": "#ff9a80",
	"crit": "#f4a86c",
	"speed": "#8ccaf0",
	"attack_speed": "#f0c070",
	"shield": "#94bef8",
	"shield_pen": "#e2b468",
	"exp": "#d0a8f6",
	"luck": "#e8d070",
	"range": "#f0a870",
	"cooldown": "#a9c6ee",
	"value": "#f6d27e",
	"passive": "#e6cf72",
	"text": "#f3e6cc",
}
