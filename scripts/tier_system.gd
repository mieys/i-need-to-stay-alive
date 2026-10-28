class_name TierSystem

## Oyun genelinde paylaşılan 4 seviyeli "tier" sistemi - önce SADECE level
## atlama kartlarında vardı (bkz. level_up_screen.gd), kullanıcı isteğiyle
## ("bundan sonra 'ekstralar' eşyalarının tierları olacak") sandık eşyalarına
## da genişletildi (bkz. chest_menu.gd). İsim/renk/nadir olma oranı TEK bir
## yerden geliyor ki level atlama kartları ile sandık eşyaları arasında
## görsel dil (Sıradan/Nadir/Epik/Efsanevi + gri/mavi/mor/kırmızı) hiç
## sapmasın - her iki taraf da bu sınıfı referans alır, KENDİ kopyasını
## tutmaz.
##
## NOT: bir tier'in GÜÇ çarpanı (statların ne kadar büyütüleceği) burada
## YOK - level atlama kartları (tier × N, bkz. player.gd apply_upgrade) ile
## sandık eşyaları (%100/%150/%200/%250, bkz. items.gd ITEM_TIER_POWER)
## birbirinden FARKLI ölçekleme kuralları kullanıyor, o yüzden her taraf
## kendi güç formülünü kendi dosyasında tutuyor - burada sadece ORTAK olan
## isim/renk/nadirlik yaşıyor.
const NAMES := ["Sıradan", "Nadir", "Epik", "Efsanevi"]
## DÜZELTME (kullanıcı isteği 2026-09-24: oyun içi arayüzler bej/ahşap kite geçti, "tier bazlı kartların renklerinin buna
## göre tasarlanması gerekiyor") - tier adları artık açık bej parşömen ÜSTÜNDE yazılıyor (level kartı, sandık, satıcı):
## eski açık krem/açık mavi tonlar okunmuyordu, aynı renk ailesinin koyu/doygun tonları kullanılıyor. Kartların kendi tier
## renkleri (emaye bant + taş) tools/gen_menu_kit.py TIER_PALS'ta - bu tonlar onların "md/dk" tonlarıyla eşleşir.
const COLORS := [
	Color("#5a3a20"), ## Tier 1 - Sıradan: koyu ahşap kahve (özel vurgu YOK)
	Color("#2c56b0"), ## Tier 2 - Nadir: mavi
	Color("#7430ac"), ## Tier 3 - Epik: mor
	Color("#b0281e"), ## Tier 4 - Efsanevi: kırmızı
]
## Üst tierlar diğerlerine göre daha nadir çıksın diye ağırlıklı dağılım -
## kümülatif DEĞİL, roll() toplamı kendisi hesaplayıp normalize eder.
## DÜZELTME (kullanıcı isteği: "yüksek tierların çıkma olasılığını büyük
## oranda azalt - tier 2'yi biraz azalt, 3'ü biraz daha fazla, 4'ü daha da
## fazla azalt") - eskiden %60/%25/%12/%3'tü; üst tierlar KADEMELİ olarak
## (tier2 en az oranda, tier4 en çok oranda) düşürüldü.
## DÜZELTME (kullanıcı bildirimi 2026-09-25: "şans kasmadığında ... hep tier 1 kartlar çıkıyor") - 60/16/5/1'de kartların
## %73'ü Sıradan'dı, level atlamaların %39'unda üç kart da Sıradan geliyordu. Orta nokta: %62/%27/%9/%2 (üçü birden Sıradan
## %24) - Efsanevi hâlâ ilk %3'ün altında (yukarıdaki "4'ü daha da fazla azalt" isteği korunuyor). Level kartları, sandık
## eşyası, efsun gücü ve seyyar satıcı aynı zarı kullanır.
## 2026-10-10 (kullanıcı: "şans almayan oyuncular neredeyse hiç güzel level atlama kartına rastlamıyor, hep kademe 1 çıkıyor"): 55/24/8/2'de
## kartların %62'si Sıradan, üç kart birden Sıradan %24'tü -> 50/32/14/4 (Sıradan %50, üçü birden %12,5; Efsanevi ~%4).
const WEIGHTS := [50.0, 32.0, 14.0, 4.0]

## Şansa (Luck) bağlı olarak üst tierların GÖRECELİ ağırlığını büyütür - luck
## 0 iken WEIGHTS aynen kullanılır (tier1 hiç etkilenmez, sadece 2/3/4
## büyür). Kullanıcı isteği: "çıkma ihtimalleri şansa bağlı olarak artacak" -
## bu istek önce SADECE level atlama kartlarıyla ilgiliydi. GÜNCELLEME
## (kullanıcı isteği 2026-09-24: "şans iyi kartlar çıkarma oranını, sandık
## düşme oranı iyi sandık çıkma oranını da arttırmalı") - artık sandık ödülü
## (chest_menu.gd, açanın şansı) ve seyyar satıcı eşya kademeleri
## (traveling_merchant.gd, yerel oyuncunun şansı) de gerçek luck geçiyor.
## 2026-10-10 (kullanıcı: "şans faktörü pek işlevsel değil"): eskiden her üst kademe x(1 + şans x 0,015) -> 10 şansta x1,15 (Sıradan oranı
## %62'den %59'a, fark edilmez). Artık çarpan 0,04/puan VE kademe numarasına göre ÜSTEL (Nadir x m, Epik x m², Efsanevi x m³): şans yüksek
## kademeleri en çok büyütür. Kart başına (Sıradan/Nadir/Epik/Efsanevi): şans 0 = %50/32/14/4, 10 = %38/34/21/8, 20 = %28/33/26/13.
const TIER_LUCK_WEIGHT_BONUS_PER_POINT := 0.04

## Kullanıcı isteği: "Can çalma statlarını düzenliyoruz, tier 1: %1, tier 2: %1.5,
## tier 3: %2, tier 4: %2.5 can çalma" - level atlama kartındaki "Can Çalma"
## (bkz. player.gd apply_upgrade "lifesteal" dalı ve level_up_screen.gd
## _scaled_desc_value ile kartta gösterilen sayı) İÇİN TEK kaynak. Vampir Dişi
## eşyasının (bkz. items.gd) tier basamakları da ITEM_TIER_POWER (x1/1.5/2/2.5)
## ile bu AYNI %1/%1.5/%2/%2.5 merdivenini veriyor (eşya tabanı %1) - iki
## kaynak aynı sayıları üretsin diye eşya tabanı bu merdivenin ilk basamağına
## eşitlendi.
## 2026-10-11 (kullanıcı: "level atlama kartlarındaki can çalma statlarını düzenliyoruz: 1. kademe %2, 2. %4, 3. %6, 4. %8"):
## SADECE kart merdiveni değişti - Vampir Dişi eşyası eski %1 tabanında kaldı (istenmedi).
const LIFESTEAL_CARD_BY_TIER := [0.02, 0.04, 0.06, 0.08]

static func lifesteal_percent_for_tier(tier: int) -> float:
	return LIFESTEAL_CARD_BY_TIER[clampi(tier, 1, LIFESTEAL_CARD_BY_TIER.size()) - 1]

## Kullanıcı isteği (2026-09-25): "tier 1: 15, tier 2: 24, tier 3: 30, tier 4: 38" - level atlama kartındaki "Can"
## (max_health) paylaşılan x1.3 tier eğrisinden çıkarıldı, elle verilen merdiven. player.gd apply_upgrade "max_health"
## dalı VE level_up_screen.gd _scaled_desc_value (kartta gösterilen sayı) İÇİN TEK kaynak - lifesteal ile aynı desen.
## 2026-10-14 (kullanıcı: "can miktarları çok düşük"): 15/24/30/38 -> 20/35/50/70.
const HEALTH_CARD_BY_TIER := [20.0, 35.0, 50.0, 70.0]

static func health_card_for_tier(tier: int) -> float:
	return HEALTH_CARD_BY_TIER[clampi(tier, 1, HEALTH_CARD_BY_TIER.size()) - 1]


## Can Yenilenmesi kartı (kullanıcı 2026-10-10): kademe 1..4 = 2 / 4 / 6 / 8 (eskiden 2 x paylaşılan x1.3 eğrisi = 2 / 2,6 / 3,2 / 3,8). player.gd ve kart yazısı buradan okur.
const REGEN_CARD_BY_TIER := [2.0, 4.0, 6.0, 8.0]


static func regen_card_for_tier(tier: int) -> float:
	return REGEN_CARD_BY_TIER[clampi(tier, 1, REGEN_CARD_BY_TIER.size()) - 1]


## Kalkan Yenilenmesi kartı (madde 380): saniyede yenilenen mana kalkanı, kademe 1..4 = 0,8 / 1,2 / 1,6 / 2,0 (Ruh Mağazası geliştirmesi seviye başına 0,4;
## eşyalar 0,5-2). Tek ondalık merdiven: kartta yazan = uygulanan. player.gd apply_upgrade "shield_regen" ve level_up_screen.gd buradan okur.
const SHIELD_REGEN_CARD_BY_TIER := [0.8, 1.2, 1.6, 2.0]


static func shield_regen_card_for_tier(tier: int) -> float:
	return SHIELD_REGEN_CARD_BY_TIER[clampi(tier, 1, SHIELD_REGEN_CARD_BY_TIER.size()) - 1]


## İyileştirme Gücü kartı (madde 380): oyuncunun sağladığı TÜM can/kalkanı büyütür (heal_shield_power), kademe 1..4 = %2 / %3 / %4 / %5
## (Ruh Mağazası seviye başına %2,5; eşyalar %5-10). Tam yüzdeler: kartta yazan = uygulanan.
const HEAL_POWER_CARD_BY_TIER := [0.02, 0.03, 0.04, 0.05]


static func heal_power_card_for_tier(tier: int) -> float:
	return HEAL_POWER_CARD_BY_TIER[clampi(tier, 1, HEAL_POWER_CARD_BY_TIER.size()) - 1]

## Kart arkaplanı: level atlama kartlarının çizilmiş 4 tier çerçevesi
## (eskiden SADECE level_up_screen.gd'nin kendi TIER_FRAME_TEXTURES'ıydı).
## Kullanıcı isteği: "seyyar satıcı eşyalarının / sandık ödülü kartının
## arkaplanı da level atlama kartları gibi olmalı, tierlarına göre renkleri
## değişmeli (aynı kartları kullan arkaplan için)" - isim/renk/nadirlikle
## AYNI gerekçeyle (bkz. dosya başı notu) buraya taşındı, üç taraf da
## (level atlama, seyyar satıcı, sandık) TEK bir kaynaktan okuyor.
## Kullanıcı isteği (2026-09-24): kartlar oyun içi bej kitle AYNI dilde yeniden çizildi (tools/gen_menu_kit.py tier_card):
## 300x480 px = 100x160 sanat px (level_up_screen.tscn Card*/Frame boyutu, 3 px texel) - ahşap dış çerçeve + tier renginde
## emaye bant + parşömen iç + tier taşı. Eski 483x643 hazır çizimler (assets/sprites/level_card_tier_*.png) kaldırıldı.
## 2026-09-25 (kullanıcı isteği: "renklerinin sadece dış çizgilerinin değil tamamen tier'a uygun hale" + "savaşla alakalı"):
## kart gövdesi tamamen tier renginde SAVAŞ kartı - tier metali çerçeve, ışık hüzmeleri, çapraz kılıçlı kalkan arması, tier
## kurdelesi, parşömen açıklama levhası. Sabit bölgeleri scripts/tier_card_fx.gd'de (level atlama + sandık aynı yerleşimi okur).
const FRAME_TEXTURES := [
	preload("res://assets/ui/game/tier_card_1.png"),
	preload("res://assets/ui/game/tier_card_2.png"),
	preload("res://assets/ui/game/tier_card_3.png"),
	preload("res://assets/ui/game/tier_card_4.png"),
]

## Küçük KARE ikon-slotu çerçevesi (seyyar satıcı mini kartlarındaki ikonun
## arkası için, bkz. merchant_shop_screen.gd) - FRAME_TEXTURES'in aksine
## tüm kartı değil, sadece ikonun oturduğu kare alanı kaplar. Tier'ı olmayan
## girişler (silah/kalkan) varsayılan olarak MINI_FRAME_TEXTURES[0] (tier 1)
## kullanır.
## 96x96 px = 32x32 sanat px (tools/gen_menu_kit.py tier_slot). 2026-09-25: TAMAMEN tier renginde (tier metali çerçeve + ortası
## aydınlık tier zemini + köşe perçinleri); kademesiz envanter yuvası eski sade hücreyi (assets/ui/game/slot_cell.png) kullanır.
const MINI_FRAME_TEXTURES := [
	preload("res://assets/ui/game/tier_slot_1.png"),
	preload("res://assets/ui/game/tier_slot_2.png"),
	preload("res://assets/ui/game/tier_slot_3.png"),
	preload("res://assets/ui/game/tier_slot_4.png"),
]

static func roll(luck: float = 0.0) -> int:
	var effective_weights: Array = WEIGHTS.duplicate()
	if luck > 0.0:
		var mult: float = 1.0 + luck * TIER_LUCK_WEIGHT_BONUS_PER_POINT
		for i in range(1, effective_weights.size()):
			effective_weights[i] *= pow(mult, float(i))
	var total: float = 0.0
	for w in effective_weights:
		total += w
	var r: float = randf() * total
	var acc: float = 0.0
	for i in range(effective_weights.size()):
		acc += effective_weights[i]
		if r <= acc:
			return i + 1
	return 1
