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
const COLORS := [
	Color(0.98, 0.94, 0.85, 1.0), ## Tier 1 - normal, özel vurgu YOK
	Color(0.35, 0.55, 1.0, 1.0), ## Tier 2 - mavi
	Color(0.68, 0.32, 0.96, 1.0), ## Tier 3 - mor
	Color(1.0, 0.22, 0.2, 1.0), ## Tier 4 - kırmızı
]
## Üst tierlar diğerlerine göre daha nadir çıksın diye ağırlıklı dağılım -
## kümülatif DEĞİL, roll() toplamı kendisi hesaplayıp normalize eder.
## DÜZELTME (kullanıcı isteği: "yüksek tierların çıkma olasılığını büyük
## oranda azalt - tier 2'yi biraz azalt, 3'ü biraz daha fazla, 4'ü daha da
## fazla azalt") - eskiden %60/%25/%12/%3'tü; üst tierlar KADEMELİ olarak
## (tier2 en az oranda, tier4 en çok oranda) düşürüldü.
const WEIGHTS := [60.0, 16.0, 5.0, 1.0]

## Şansa (Luck) bağlı olarak üst tierların GÖRECELİ ağırlığını büyütür - luck
## 0 iken WEIGHTS aynen kullanılır (tier1 hiç etkilenmez, sadece 2/3/4
## büyür). Kullanıcı isteği: "çıkma ihtimalleri şansa bağlı olarak artacak" -
## bu istek özellikle level atlama kartlarıyla ilgiliydi, bu yüzden SADECE
## level_up_screen.gd (_populate_cards) roll()'a gerçek luck değerini
## geçiyor; sandık/seyyar satıcı çekilişleri (bkz. chest_menu.gd/
## traveling_merchant.gd) varsayılan luck=0 ile eskisi gibi ETKİLENMİYOR.
const TIER_LUCK_WEIGHT_BONUS_PER_POINT := 0.015

## Kullanıcı isteği: "Can çalma statlarını düzenliyoruz, tier 1: %1, tier 2: %1.5,
## tier 3: %2, tier 4: %2.5 can çalma" - level atlama kartındaki "Can Çalma"
## (bkz. player.gd apply_upgrade "lifesteal" dalı ve level_up_screen.gd
## _scaled_desc_value ile kartta gösterilen sayı) İÇİN TEK kaynak. Vampir Dişi
## eşyasının (bkz. items.gd) tier basamakları da ITEM_TIER_POWER (x1/1.5/2/2.5)
## ile bu AYNI %1/%1.5/%2/%2.5 merdivenini veriyor (eşya tabanı %1) - iki
## kaynak aynı sayıları üretsin diye eşya tabanı bu merdivenin ilk basamağına
## eşitlendi.
static func lifesteal_percent_for_tier(tier: int) -> float:
	return 0.01 + 0.005 * float(clampi(tier, 1, NAMES.size()) - 1)

## Kart arkaplanı: level atlama kartlarının çizilmiş 4 tier çerçevesi
## (eskiden SADECE level_up_screen.gd'nin kendi TIER_FRAME_TEXTURES'ıydı).
## Kullanıcı isteği: "seyyar satıcı eşyalarının / sandık ödülü kartının
## arkaplanı da level atlama kartları gibi olmalı, tierlarına göre renkleri
## değişmeli (aynı kartları kullan arkaplan için)" - isim/renk/nadirlikle
## AYNI gerekçeyle (bkz. dosya başı notu) buraya taşındı, üç taraf da
## (level atlama, seyyar satıcı, sandık) TEK bir kaynaktan okuyor.
const FRAME_TEXTURES := [
	preload("res://assets/sprites/level_card_tier_1.png"),
	preload("res://assets/sprites/level_card_tier_2.png"),
	preload("res://assets/sprites/level_card_tier_3.png"),
	preload("res://assets/sprites/level_card_tier_4.png"),
]

## Küçük KARE ikon-slotu çerçevesi (seyyar satıcı mini kartlarındaki ikonun
## arkası için, bkz. merchant_shop_screen.gd) - FRAME_TEXTURES'in aksine
## tüm kartı değil, sadece ikonun oturduğu kare alanı kaplar. Tier'ı olmayan
## girişler (silah/kalkan) varsayılan olarak MINI_FRAME_TEXTURES[0] (tier 1)
## kullanır.
const MINI_FRAME_TEXTURES := [
	preload("res://assets/sprites/mini_slot_tier_1.png"),
	preload("res://assets/sprites/mini_slot_tier_2.png"),
	preload("res://assets/sprites/mini_slot_tier_3.png"),
	preload("res://assets/sprites/mini_slot_tier_4.png"),
]

static func roll(luck: float = 0.0) -> int:
	var effective_weights: Array = WEIGHTS.duplicate()
	if luck > 0.0:
		var mult: float = 1.0 + luck * TIER_LUCK_WEIGHT_BONUS_PER_POINT
		for i in range(1, effective_weights.size()):
			effective_weights[i] *= mult
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
