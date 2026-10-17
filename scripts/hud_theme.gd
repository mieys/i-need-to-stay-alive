extends RefCounted

## HUD TEMASI "Kısık Ahşap" (madde 207, 2026-10-17; kullanıcı 4 prototipten önce C'yi, aynı gün D'yi seçti, madde 202).
## Mevcut ahşap kitin kısık hâli (daha koyu, daha az doygun): oyun içi göstergeler (yetenek paneli, minimap, altın/kıymık
## levhaları, grup ve görev satırları, mini stat paneli, XP çubuğu) için TEK renk kaynağı. Dokular tools/gen_hud_tema.py
## PAL ile üretilir - bu değerler onunla AYNI tutulmalı. Oyun içi PENCERELER (envanter, stat, dükkan, sandık...) bej kitte
## kalır (UIKit). Levhalar orta-koyu kahve -> yazılar AÇIK (UIKit.C_TEXT/C_GOLD bej zemin içindir, burada okunmaz).
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

const TEXT := Color("#f3e6cc") ## levhada ana yazı
const DIM := Color("#c4b090") ## ikincil yazı
const PRICE := Color("#f6d27e") ## altın/sayı
const ACCENT := Color("#f0c070") ## başlık / birinci sıra
const GOOD := Color("#b5d98a")
const BAD := Color("#f09a80") ## uyarı / yere düştü (kahve zeminde okunur kırmızı)
const SHARD := Color("#b8e0f4") ## silah parçacığı sayısı
