extends Control
const Loc := preload("res://scripts/localization.gd") ## dil desteği: Loc.t / Loc.pct (madde 446)

## KADEME GÖSTERİMİ (kullanıcı isteği 2026-10-05): kademe numaraları ROMEN RAKAMIYLA yazılır ve kademe bildirimi sadece
## "KADEME <ROMEN>" + altında zorluğu temsil eden 6 KURU KAFA satırıdır; kademe arttıkça kafalar dolar (yarım yarım da).
## Bu dosya hem SAF yardımcıları (to_roman, skull_steps, title, ordinal) hem de kafa satırını çizen Control'ü (set_tier) taşır.
## Kafa sanatı kullanıcının kafatası çizimidir (scripts/skull_icon.gd, 2026-11-11; boss işareti / boss barıyla AYNI ikon): 22x30 doku, tam katlarda.
## Kullanım: const TierDisplay := preload("res://scripts/tier_display.gd") ; TierDisplay.to_roman(7) ; row.set_tier(7)

const SkullIcon := preload("res://scripts/skull_icon.gd")

const FINAL_TIER := 10 ## son kademe = enemy_spawner.gd LAST_TIER ile aynı (madde 597: oyun 10 kademe; eskiden ayrı Final kademesi 16'ydı)
const SKULLS := 6
const HALF_STEPS := SKULLS * 2 ## 0..12: her kafa 2 adım (yarım + tam)
const SKULL_W := 22 ## 1 kat çizimde kafa genişliği (ekran px = SkullIcon.BIG_SIZE)
const SKULL_H := 30
const SKULL_GAP := 5
const ROW_W := SKULLS * SKULL_W + (SKULLS - 1) * SKULL_GAP ## 157

var _tier: int = 1
var _k: int = 1 ## doku katı (1 doku pikseli = _k ekran pikseli)


# ---------------------------------------------------------------- saf yardımcılar
## 1 -> I, 4 -> IV, 9 -> IX, 14 -> XIV, 16 -> XVI. 0 ve eksi için "-", 3999'dan büyük için düz sayı (sonsuz mod katları Romenlenmez).
static func to_roman(n: int) -> String:
	if n <= 0:
		return "-"
	if n > 3999:
		return str(n)
	var vals: Array[int] = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var syms: Array[String] = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	var out: String = ""
	var left: int = n
	for i in range(vals.size()):
		while left >= vals[i]:
			out += syms[i]
			left -= vals[i]
	return out


## Bildirim başlığı: "KADEME IV"; son kademe (X) "FİNAL KADEMESİ" (SON boss orada, ölümü zafer).
static func title(tier: int) -> String:
	if tier >= FINAL_TIER:
		return "FİNAL KADEMESİ"
	return Loc.t("KADEME %s") % to_roman(tier)


## "5'e ulaş" yerine ünlü uyumuna takılmadan okunan sıra biçimi: "V. Kademe" (Romen rakamı + nokta).
static func ordinal(tier: int) -> String:
	return Loc.t("%s. Kademe") % to_roman(tier)


## Zorluk kafa adımı (0..12 = yarım kafa adımı): kademe 1 yarım kafa, son kademe (10) altı tam kafa; arası doğrusal ve azalmayan.
## 10 kademe 12 adıma sığmadığı için bazı komşu kademeler 1 adım atlar (kullanıcı: "yarım yarım da artabilir").
static func skull_steps(tier: int) -> int:
	if tier <= 0:
		return 0
	return clampi(roundi(float(tier) * float(HALF_STEPS) / float(FINAL_TIER)), 1, HALF_STEPS)


## Tek kafanın dolulukları: 6 elemanlı dizi, her biri 0 (boş) / 1 (yarım) / 2 (tam).
static func skull_fills(tier: int) -> Array[int]:
	var steps: int = skull_steps(tier)
	var out: Array[int] = []
	for i in range(SKULLS):
		out.append(clampi(steps - 2 * i, 0, 2))
	return out


## Arayüz birimi `px` (1 sanat pikseli = px ekran pikseli, ana arayüzde 3) için kafa katı: 3 -> 1, 6 -> 2 (doku piksel ızgarası bozulmaz).
static func scale_for(px: int) -> int:
	return maxi(1, roundi(float(px) / 3.0))


## Satırın ekran px boyutu (set_tier'dan önce yerleşim hesabı için).
static func row_size(px: int) -> Vector2:
	return Vector2(ROW_W, SKULL_H) * float(scale_for(px))


# ---------------------------------------------------------------- kafa satırı (Control)
func set_tier(tier: int, px: int = 3) -> void:
	_tier = tier
	_k = scale_for(px)
	custom_minimum_size = row_size(px)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()


func get_tier() -> int:
	return _tier


func _draw() -> void:
	var fills: Array[int] = skull_fills(_tier)
	var k: float = float(_k)
	for i in range(SKULLS):
		SkullIcon.draw(self, Vector2(float(i * (SKULL_W + SKULL_GAP)) * k, 0.0), k, fills[i], _tier >= FINAL_TIER)
