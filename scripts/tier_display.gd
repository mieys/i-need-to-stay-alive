extends Control

## KADEME GÖSTERİMİ (kullanıcı isteği 2026-10-05): kademe numaraları ROMEN RAKAMIYLA yazılır ve kademe bildirimi sadece
## "KADEME <ROMEN>" + altında zorluğu temsil eden 6 KURU KAFA satırıdır; kademe arttıkça kafalar dolar (yarım yarım da).
## Bu dosya hem SAF yardımcıları (to_roman, skull_steps, title, ordinal) hem de kafa satırını çizen Control'ü (set_tier) taşır.
## Kafa sanatı boss_bar_art.gd'deki 9x9 kuru kafadır (boss kuru kafa işaretiyle AYNI dil).
## Kullanım: const TierDisplay := preload("res://scripts/tier_display.gd") ; TierDisplay.to_roman(7) ; row.set_tier(7)

const BossBarArt := preload("res://scripts/boss_bar_art.gd")

const FINAL_TIER := 16 ## enemy_spawner.gd FINAL_TIER ile aynı
const SKULLS := 6
const HALF_STEPS := SKULLS * 2 ## 0..12: her kafa 2 adım (yarım + tam)
const SKULL_W := 9 ## sanat pikseli
const SKULL_H := 9
const SKULL_GAP := 3
const HALF_COL := 4 ## kafanın orta sütunu (0-9): yarım kafa 0..HALF_COL arası
const ROW_ART_W := SKULLS * SKULL_W + (SKULLS - 1) * SKULL_GAP ## 69

const FILL_RED := Color("#d2413a") ## Final kademede kafalar kan kırmızısı
const SHADE_RED := Color("#831824")

var _tier: int = 1
var _px: int = 3 ## 1 sanat pikseli = _px ekran pikseli


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


## Bildirim başlığı: "KADEME IV"; Final kademe kendi adıyla ("FİNAL KADEMESİ").
static func title(tier: int) -> String:
	if tier >= FINAL_TIER:
		return "FİNAL KADEMESİ"
	return "KADEME %s" % to_roman(tier)


## "5'e ulaş" yerine ünlü uyumuna takılmadan okunan sıra biçimi: "V. Kademe" (Romen rakamı + nokta).
static func ordinal(tier: int) -> String:
	return "%s. Kademe" % to_roman(tier)


## Zorluk kafa adımı (0..12 = yarım kafa adımı): kademe 1 yarım kafa, Final (16) altı tam kafa; arası doğrusal ve azalmayan.
## 16 kademe 12 adıma sığdığı için bazı komşu kademeler aynı kafa sayısında kalır (kullanıcı: "yarım yarım da artabilir").
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


# ---------------------------------------------------------------- kafa satırı (Control)
func set_tier(tier: int, px: int = 3) -> void:
	_tier = tier
	_px = maxi(1, px)
	custom_minimum_size = Vector2(ROW_ART_W, SKULL_H) * float(_px)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func get_tier() -> int:
	return _tier


func _draw() -> void:
	var fills: Array[int] = skull_fills(_tier)
	for i in range(SKULLS):
		var x: float = float(i * (SKULL_W + SKULL_GAP))
		_draw_skull(Vector2.ZERO, x, fills[i], _tier >= FINAL_TIER)


## fill: 0 boş (soluk hayalet), 1 yarım (sol yarısı dolu), 2 tam.
func _draw_skull(o: Vector2, x: float, fill: int, red: bool) -> void:
	var s: float = float(_px)
	## Boş taban: her zaman hayalet olarak çizilir (yarım kafanın sağ yarısı da böyle kalır).
	var ghost := {"X": Color(BossBarArt.OUT, 0.55), "W": Color(BossBarArt.OUT, 0.14), "K": Color(BossBarArt.OUT, 0.35)}
	BossBarArt.blit(self, o, s, BossBarArt.SKULL_ROWS, ghost, x, 0.0)
	if fill <= 0:
		return
	var rows: Array[String] = BossBarArt.SKULL_ROWS
	if fill == 1:
		rows = _left_half(BossBarArt.SKULL_ROWS)
	var body: Color = FILL_RED if red else BossBarArt.BONE
	var shade: Color = SHADE_RED if red else BossBarArt.BONE_D
	BossBarArt.blit(self, o, s, rows, {"X": BossBarArt.OUT, "W": body, "K": BossBarArt.OUT2}, x, 0.0)
	## Gölge pikselleri (boss_bar_art.gd skull ile aynı yerler), yarım kafada yalnız sol yarıdakiler.
	for p: Vector2i in [Vector2i(1, 5), Vector2i(7, 5), Vector2i(6, 6)]:
		if fill == 2 or p.x <= HALF_COL:
			BossBarArt.r(self, o, s, x + p.x, float(p.y), 1.0, 1.0, shade)


## Kafanın sol yarısı (orta sütun dahil): sağ yarıdaki piksellerin hepsi saydam yapılır.
static func _left_half(rows: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for row: String in rows:
		var cut: String = ""
		for i in range(row.length()):
			cut += row[i] if i <= HALF_COL else "."
		out.append(cut)
	return out
