extends RefCounted

## ==============================================================================
## CORVINA (Necromancer, id 11) BİRLİKLERİ - TEK DENGE TABLOSU (kullanıcı onayı 2026-11-16)
## ==============================================================================
## Q = Kemik Savaşçısı (yakın dövüş), E = Kemik Okçusu (menzilli), R = Ölüler Ordusu (hayalet askerler + final komutan).
## TÜM statlar Corvina'nın SALDIRI GÜCÜNDEN (player.damage_bonus) hesaplanır: can = taban + AP x katsayı, kalkan = AP x katsayı,
## vuruş = AP x oran. Saldırı hızı Corvina'nın saldırı hızı bonusunun AS_SHARE'i kadar artar (üst sınır AS_CAP_PERCENT). Statlar
## ÇAĞIRMA ANINDA hesaplanır (ömür kısa; sonradan AP artarsa yeni çağrılanlar güncel değerle gelir).
## Sayılar ilk tahmin - oyuncuya görünen metinler (characters.gd DEFS[11], skill_evolutions.gd DEFS[11]) bunlarla AYNI kalmalı;
## birini değiştirince metni ve scripts/balance_log.gd BALANCE_REV'i de güncelle.

## kind -> statlar. hp_base/hp_ap: can = hp_base + AP x hp_ap. shield_ap: kalkan = AP x shield_ap (0 = kalkansız).
## dmg_ap: vuruş/ok başına AP oranı. interval: taban saldırı aralığı (sn). speed: Corvina'nın hareket hızının oranı.
## hit_cap: tek bir vuruşun en çok alabileceği can oranı (boss bir vuruşta silemesin; savaşçı en az ~7 vuruşta ölür).
const STATS := {
	"warrior": {"hp_base": 60.0, "hp_ap": 6.0, "shield_ap": 2.0, "dmg_ap": 0.40, "interval": 0.75, "speed": 0.90, "hit_cap": 0.15},
	"archer": {"hp_base": 30.0, "hp_ap": 3.0, "shield_ap": 1.0, "dmg_ap": 0.30, "interval": 1.2, "speed": 0.95, "hit_cap": 0.25},
	## soldier 2026-11-16: can 20 + AP x 2,5 -> 40 + AP x 4, hit_cap 0,34 -> 0,20 (3 yerine en az 5 vuruşta ölür; "hemen ölüyorlar").
	"soldier": {"hp_base": 40.0, "hp_ap": 4.0, "shield_ap": 0.0, "dmg_ap": 0.25, "interval": 0.9, "speed": 1.0, "hit_cap": 0.20},
	"commander": {"hp_base": 80.0, "hp_ap": 10.0, "shield_ap": 4.0, "dmg_ap": 0.60, "interval": 0.9, "speed": 1.0, "hit_cap": 0.15},
}

## Corvina'nın saldırı hızı bonusunun (%) birliklere geçen payı ve birliklerin ulaşabileceği en yüksek bonus (%).
const AS_SHARE := 0.5
const AS_CAP_PERCENT := 200.0

## Kalkan (golemdeki mana kalkanı deseni): bu kadar sn hasar almazsa saniyede maks. kalkanın RATE'i kadar dolar.
const SHIELD_REGEN_DELAY := 5.0
const SHIELD_REGEN_RATE := 0.10

## ---------------------------------------------------------------- Q: Kemik Savaşçısı
const WARRIOR_SOUL_COST := 10
const WARRIOR_COOLDOWN := 3.0
const WARRIOR_LIFESPAN := 30.0
const WARRIOR_MAX := 5
## Görünüm/rütbe: alınan Q evrimi sayısına göre (evrim sırası rastgele). Zırhlı: engelleme; Yüzbaşı: yay savurma + daha çok engelleme.
const WARRIOR_BLOCK_CHANCE_ARMORED := 0.20
const WARRIOR_BLOCK_CHANCE_CAPTAIN := 0.30
const WARRIOR_CLEAVE_ARC_DEG := 100.0
const WARRIOR_CLEAVE_RANGE := 58.0
## Evrimler (necro_q1..q4 + necro_qf)
const EVO_WARRIOR_MAX := 8 ## Q1 Kemik Ordusu
const EVO_WARRIOR_COST := 7 ## Q2 Ucuz Ruhlar
const EVO_WARRIOR_HP_MULT := 1.30 ## Q3 Sert Kemikler
const EVO_WARRIOR_LIFE_ADD := 10.0 ## Q4 Dayanıklı Ruhlar
const EVO_KNIGHT_HP_MULT := 1.50 ## QF Kemik Şövalyesi: can
const EVO_KNIGHT_COMBO := 3 ## her 3. vuruş Super
const EVO_KNIGHT_SUPER_RADIUS := 60.0
const EVO_KNIGHT_SUPER_AP := 0.80
const EVO_KNIGHT_SUPER_STUN := 1.0

## ---------------------------------------------------------------- E: Kemik Okçusu
const ARCHER_SOUL_COST := 6
const ARCHER_COOLDOWN := 0.2
const ARCHER_LIFESPAN := 30.0
const ARCHER_MAX := 5
const ARCHER_RANGE := 280.0
## Okçu hedefe bu mesafeden yakınsa geri çekilmez ama yaklaşmaz da; menzil dışındaysa menzilin bu oranına kadar yaklaşır.
const ARCHER_APPROACH_RATIO := 0.85
const ARROW_SPEED := 520.0
## Hayalet Okçu (2+ E evrimi): ok ilk düşmanı delip arkasındakine de vurur.
const GHOST_ARCHER_MIN_EVOS := 2
const GHOST_ARCHER_PIERCE := 1
## Evrimler (necro_e1..e4 + necro_ef)
const EVO_ARCHER_MAX := 8 ## E1 Dolu Sadak
const EVO_ARCHER_COST := 4 ## E2 Ucuz Kemik
const EVO_ARCHER_AS_PERCENT := 30.0 ## E3 Gergin Kiriş (birliğin saldırı hızı bonusuna eklenir)
const EVO_ARCHER_RANGE_MULT := 1.25 ## E4 Kartal Gözü: menzil
const EVO_ARCHER_DMG_MULT := 1.15 ## E4 Kartal Gözü: ok hasarı
const EVO_MAGE_FIRE_AP := 0.45 ## EF Kemik Büyücüsü: ateş sütunu (hedef + çevresi)
const EVO_MAGE_FIRE_RADIUS := 40.0
const EVO_MAGE_REBORN_COOLDOWN := 15.0 ## her büyücü bu kadar sn'de bir yakında ölen bir iskeleti aynı rütbede diriltir
const EVO_MAGE_REBORN_RADIUS := 320.0

## ---------------------------------------------------------------- R: Ölüler Ordusu
const ARMY_COOLDOWN := 60.0
const ARMY_DURATION := 20.0 ## 2026-11-16: 10 -> 20 (kullanıcı: "çok kısa süre yaşayıp hemen ölüyorlar")
const ARMY_SIZE := 12
## Ordunun bileşimi (toplam ARMY_SIZE): 1 Yüzbaşı, ~%25 Zırhlı, kalanı Er.
const ARMY_ARMORED_RATIO := 0.25
const ARMY_RING_RADIUS := 70.0
const EVO_ARMY_SIZE := 18 ## R1 Kalabalık Saflar
const EVO_ARMY_DURATION := 30.0 ## R2 Uzun Sefer (2026-11-16: 15 -> 30)
const EVO_COMMANDER_DMG_MULT := 1.25 ## RF Hayalet Komutan: yaşadıkça askerlerin hasarı
const EVO_COMMANDER_SOUL_PER_SURVIVOR := 1


static func max_hp(kind: String, ap: float) -> float:
	var s: Dictionary = STATS[kind]
	return maxf(1.0, float(s["hp_base"]) + maxf(ap, 0.0) * float(s["hp_ap"]))


static func max_shield(kind: String, ap: float) -> float:
	return maxf(0.0, maxf(ap, 0.0) * float(STATS[kind]["shield_ap"]))


static func hit_damage(kind: String, ap: float) -> float:
	return maxf(1.0, maxf(ap, 0.0) * float(STATS[kind]["dmg_ap"]))


## Corvina'nın saldırı hızı bonusu (%, player.get_attack_speed_bonus_percent) + birliğe özel ek bonus (%) -> birliğin bonusu (%).
static func attack_speed_bonus(owner_as_percent: float, extra_percent: float = 0.0) -> float:
	return clampf(maxf(owner_as_percent, 0.0) * AS_SHARE + extra_percent, 0.0, AS_CAP_PERCENT)


static func attack_interval(kind: String, owner_as_percent: float, extra_percent: float = 0.0) -> float:
	return float(STATS[kind]["interval"]) / (1.0 + attack_speed_bonus(owner_as_percent, extra_percent) / 100.0)


## Tek vuruş tavanı: bir yaratığın tek vuruşu en çok maks. canın hit_cap'i kadar.
static func capped_hit(kind: String, hp_max: float, amount: float) -> float:
	return minf(amount, hp_max * float(STATS[kind]["hit_cap"]))


## Q savaşçısının görünümü (necro_units.gd anahtarı): alınan Q evrimi sayısı (final hariç) + final.
static func warrior_unit(evo_count: int, has_final: bool) -> String:
	if has_final:
		return "knight"
	if evo_count >= 3:
		return "captain"
	if evo_count >= 1:
		return "armored"
	return "common"


static func archer_unit(evo_count: int, has_final: bool) -> String:
	if has_final:
		return "mage"
	if evo_count >= GHOST_ARCHER_MIN_EVOS:
		return "ghost_archer"
	return "archer"


static func warrior_block_chance(unit: String) -> float:
	match unit:
		"armored", "ghost_armored":
			return WARRIOR_BLOCK_CHANCE_ARMORED
		"captain", "ghost_captain", "knight", "ghost_knight":
			return WARRIOR_BLOCK_CHANCE_CAPTAIN
	return 0.0


## Yay savurma (Yüzbaşı ve üstü): saldırı tek hedefe değil önündeki yaydaki herkese.
static func warrior_cleaves(unit: String) -> bool:
	return unit in ["captain", "ghost_captain", "knight", "ghost_knight"]


## Ordunun birim anahtarları: 1 Yüzbaşı, ARMY_ARMORED_RATIO Zırhlı, kalanı Er.
static func army_units(count: int) -> Array[String]:
	var out: Array[String] = []
	if count <= 0:
		return out
	## 2026-11-16 (kullanıcı: "mavi tonlarında çıkıyorlar bunu istemiyorum, diğerleri gibi normal görünümde doğsunlar"): hayalet kostüm
	## (ghost_*, mavi) yerine Q savaşçısıyla aynı normal iskelet kareleri. ghost_* sayfaları yalnız E Hayalet Okçu için.
	out.append("captain")
	var armored: int = int(round(float(count) * ARMY_ARMORED_RATIO))
	for i in range(1, count):
		out.append("armored" if i <= armored else "common")
	return out


## Halka dizilimi: i. askerin sahibine göre ofseti (eşit açılı, iki sıra: ilk 8 iç halka, kalanı dış halka).
static func army_slot(i: int, count: int) -> Vector2:
	var inner: int = mini(count, 8)
	if i < inner:
		return Vector2.from_angle(TAU * float(i) / float(inner)) * ARMY_RING_RADIUS
	var outer: int = maxi(count - inner, 1)
	return Vector2.from_angle(TAU * (float(i - inner) + 0.5) / float(outer)) * ARMY_RING_RADIUS * 1.7
