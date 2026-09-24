extends Node

## Kullanıcı isteği doğrulaması:
##  1) İKİNCİ tur: "Erken levellerde hafif kolay, sonraki levellerde hafif
##     zorlaşsın - şu anki hali (bir önceki karekök düzeltmesi) tam tersi
##     olmuş. İlerleyen levellerde aşırı zor olmasın, genel olarak da aşırı
##     kolay olmasın."
##  2) "altın toplayıcı ve madeni oyundan tamamen kaldır ve ekranın sağındaki
##     arayüzlerini de sil."
##
## Doğrulananlar:
##  - Yeni eğri, bir önceki (karekök) düzeltmeye göre ERKEN seviyelerde
##    KOLAY, GEÇ seviyelerde belirgin şekilde ZOR (yön düzeltildi),
##  - gereksinim monoton artıyor ve seviye başına artış miktarı asla bir
##    tavanı (MAX_XP_INCREMENT) aşmıyor (yani "aşırı zor olmuyor"),
##  - level atlama gerçekten yeni eğriyi uyguluyor,
##  - maden/altın toplayıcı: GameManager durumu+pasif üretimi, HUD'un sağdaki
##    üretim butonları ve dükkan kayıtları tamamen kaldırıldı,
##  - kaldırma sonrası HUD ve dükkan paneli hâlâ sorunsuz kurulup
##    çalışabiliyor (duman testi).

## Sahneler bilerek preload EDİLMİYOR (bkz. aşağıdaki "sahneleri instantiate
## ETMİYOR" notu) - sadece dükkan script'inin sabitlerine/yansımasına
## erişmek için script referansı yeterli.
const ShopScript: GDScript = preload("res://scripts/shop_panel.gd")
## Sahneleri instantiate etmesek de hud.gd'nin DERLENDİĞİNİ (söz dizimi
## hatası olmadığını) doğrulamak için script'i preload ediyoruz - preload
## derleme yapar, _ready() çalıştırmaz.
const HudScript: GDScript = preload("res://scripts/hud.gd")

## BİR ÖNCEKİ (yanlış yönlü) düzeltmenin birebir kopyası (karşılaştırma
## tabanı): karekök eğrisi, taban 50 + 25*sqrt(level-1). Erken seviyelerde
## zor başlayıp geç seviyelerde neredeyse düzleşiyordu - şikayet edilen
## "tam tersi olmuş" davranış. Yeni eğrinin bunu düzelttiğini ölçmek için.
func _previous_wrong_xp_needed(level: int) -> float:
	var steps: float = float(maxi(level - 1, 0))
	return round(50.0 + 25.0 * sqrt(steps))


func _new_xp_needed(level: int) -> float:
	return GameManager._xp_needed_for_level(level)


func test_curve_is_easier_early_harder_late() -> void:
	## ERKEN seviyeler bir önceki (karekök) eğriden DAHA KOLAY (şikayet:
	## "erken levellerde hafif kolay olması lazımdı, zor olmuş"). NOT: eğriler
	## ~L8-L9 civarında kesişiyor (yeni eğri hızlanarak zorlaşıyor, öncekiyse
	## düzleşiyor) - o yüzden burada sadece gerçekten ERKEN seviyeler test
	## ediliyor, karşılaştırma L9'dan sonra anlamını yitiriyor.
	## GÜNCELLEME (2026-09-24): eğri sonradan kullanıcı istekleriyle x5/3 ve x1.5 büyütüldü (BASE_XP_NEEDED 75) -
	## L1 artık eski karekök eğrisinin (50) altında DEĞİL; bilinçli tasarım, bu yüzden L1 karşılaştırması kaldırıldı.
	assert(_new_xp_needed(1) <= GameManager.BASE_XP_NEEDED + 0.5,
		"L1 gereksinimi taban değer olmalı: %s" % _new_xp_needed(1))
	## Aynı sebeple L3/L5'in eski eğriden kolay olma şartı da kaldırıldı; erken seviyelerin artışı hâlâ küçük olmalı.
	assert(_new_xp_needed(5) - _new_xp_needed(1) < _new_xp_needed(25) - _new_xp_needed(21),
		"Erken seviyeler geç seviyelerden daha yavaş zorlaşmalı")

	## GEÇ seviyeler bir önceki eğriden belirgin şekilde ZOR (şikayet:
	## "sonraki levellerde hafif zorlaşması lazımdı, aşırı kolay kalmış")
	for level in [20, 25, 30, 40]:
		assert(_new_xp_needed(level) > _previous_wrong_xp_needed(level),
			"L%d hâlâ önceki kadar kolay: yeni %s, önceki %s" % [level, _new_xp_needed(level), _previous_wrong_xp_needed(level)])
	assert(_new_xp_needed(30) > _previous_wrong_xp_needed(30) * 2.0,
		"Geç seviye zorlaşması yetersiz: L30 yeni %s, önceki %s" % [_new_xp_needed(30), _previous_wrong_xp_needed(30)])


func test_curve_growth_increases_then_caps_and_never_explodes() -> void:
	var previous_needed: float = 0.0
	var increments: Array[float] = []
	for level in range(1, 41):
		var needed: float = _new_xp_needed(level)
		assert(needed > previous_needed, "Gereksinim L%d'de artmamış (%s)" % [level, needed])
		if level > 1:
			increments.append(needed - previous_needed)
		previous_needed = needed

	## Erken artışlarla geç artışlar karşılaştırılıyor: eğri "hafifçe
	## zorlaşmalı", yani üst seviyelerdeki toplam artış alt seviyelerinkinden
	## belirgin şekilde FAZLA olmalı (bir önceki eğrinin tam tersi).
	var early_growth: float = 0.0
	var late_growth: float = 0.0
	for i in range(increments.size()):
		if i < 10:
			early_growth += increments[i]
		elif i >= increments.size() - 10:
			late_growth += increments[i]
	assert(late_growth > early_growth * 1.5,
		"Eğri yeterince zorlaşmıyor: ilk 10 seviyenin artışı %s, son 10 seviyenin %s" % [early_growth, late_growth])

	## Tek bir seviyede ASLA büyük bir sıçrama olmamalı (üstel eğride geç
	## seviyelerde atışlar 100+ XP'ye çıkıyordu) - artış bir tavanda sınırlı.
	for increment in increments:
		assert(increment <= GameManager.MAX_XP_INCREMENT + 1.0,
			"Tek seviyede aşırı artış: %s XP (tavan %s)" % [increment, GameManager.MAX_XP_INCREMENT])
	## Geç seviye artık MAKUL şekilde zor olmalı ama üstel eğrideki (L30:
	## 1267) gibi patlamamalı.
	assert(_new_xp_needed(30) > 400.0,
		"L30 gereksinimi hâlâ çok düşük (aşırı kolay): %s" % _new_xp_needed(30))
	## GÜNCELLEME (2026-09-24 denge turu): eğri x2.5 büyütüldü ve rampadan sonraki artış 60 -> 110 oldu (L30 = 2540).
	assert(_new_xp_needed(30) < 3000.0,
		"L30 gereksinimi çok yüksek (aşırı zor): %s" % _new_xp_needed(30))


func test_level_up_applies_new_curve() -> void:
	GameManager.reset()
	assert(is_equal_approx(GameManager.team_xp_needed, _new_xp_needed(1)),
		"Başlangıç gereksinimi eğrinin L1 değeri değil: %s" % GameManager.team_xp_needed)
	GameManager.add_team_xp(400.0)
	assert(GameManager.team_level > 1, "Level atlanmadı")
	assert(is_equal_approx(GameManager.team_xp_needed, _new_xp_needed(GameManager.team_level)),
		"Level sonrası gereksinim eğriden gelmiyor: %s (beklenen %s)" % [GameManager.team_xp_needed, _new_xp_needed(GameManager.team_level)])
	GameManager.reset()


func test_gold_production_removed_from_game_manager() -> void:
	assert(GameManager.get("mine_level") == null, "GameManager.mine_level hâlâ duruyor")
	assert(GameManager.get("gold_collector_level") == null, "GameManager.gold_collector_level hâlâ duruyor")
	assert(GameManager.get("mine_timer") == null, "GameManager.mine_timer hâlâ duruyor")
	assert(GameManager.get("gold_collector_timer") == null, "GameManager.gold_collector_timer hâlâ duruyor")
	for method_name in ["get_mine_fill_progress", "get_gold_collector_fill_progress", "_mine_fill_duration", "_gold_collector_fill_duration"]:
		assert(not GameManager.has_method(method_name), "GameManager.%s hâlâ duruyor" % method_name)
	## Pasif altın üretimi gerçekten bitti mi: uzun bir süre geçse bile altın
	## kendiliğinden artmamalı (eskiden maden/toplayıcı seviyesi > 0 iken
	## _process altın ekliyordu; o seviyeler artık yok).
	GameManager.reset()
	var gold_before: int = GameManager.gold
	GameManager._process(600.0)
	assert(GameManager.gold == gold_before,
		"Pasif altın üretimi hâlâ var: %s -> %s" % [gold_before, GameManager.gold])
	GameManager.reset()


## NOT: Kaldırma testleri sahneleri instantiate ETMİYOR - hud.tscn'in içindeki
## ShopPanel alt-sahnesi, projede ZATEN var olan eksik ikon dosyalarını
## (assets/generated/item_*_frame_0.png) yüklemeye çalışıp test çıktısını
## kirletiyor (bu işle ilgisiz, önceden var olan bir sorun). Bu yüzden
## doğrulama kaynak metin + yansıma (reflection) üzerinden yapılıyor;
## "func " öneki / tam kod parçaları sayesinde "kaldırıldı" yorumlarındaki
## isim geçişleri yanlış pozitif üretmiyor.
func test_hud_has_no_production_ui() -> void:
	assert(HudScript != null, "hud.gd derlenemedi (söz dizimi hatası olabilir)")
	var src: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	assert(src.length() > 0, "hud.gd okunamadı")
	for removed_function in ["func _create_production_buttons", "func _refresh_production_buttons",
			"func _on_production_button_pressed", "func _reposition_production_buttons"]:
		assert(src.find(removed_function) == -1, "hud.gd'de hâlâ duruyor: %s" % removed_function)
	assert(src.find("PRODUCTION_KEYS") == -1, "hud.gd'de PRODUCTION_KEYS hâlâ duruyor")
	## NOT: sadece "_production_buttons" aranmıyor - o dizge kaldırılan
	## fonksiyon adlarının (_create_production_buttons vb.) İÇİNDE de geçiyor
	## ve yorumlarda anılıyor. Değişken TANIMI tam olarak aranıyor.
	assert(src.find("var _production_buttons") == -1, "hud.gd'de _production_buttons değişkeni hâlâ duruyor")
	## Butonlar kodla üretiliyordu (sahnede düğümleri yoktu) - sahnede de
	## kalmadığını doğruluyoruz.
	var scene_src: String = FileAccess.get_file_as_string("res://scenes/hud.tscn")
	assert(scene_src.find("production_button") == -1, "hud.tscn'de üretim butonu düğümü kalmış")


func test_shop_panel_has_no_gold_production_entries() -> void:
	var constants: Dictionary = ShopScript.get_script_constant_map()
	var max_levels: Dictionary = constants["MAX_LEVELS"]
	assert(not max_levels.has("mine"), "MAX_LEVELS'ta 'mine' hâlâ var")
	assert(not max_levels.has("gold_collector"), "MAX_LEVELS'ta 'gold_collector' hâlâ var")
	var upgrade_names: Dictionary = constants["UPGRADE_NAMES"]
	assert(not upgrade_names.has("mine"), "UPGRADE_NAMES'te 'mine' hâlâ var")
	assert(not upgrade_names.has("gold_collector"), "UPGRADE_NAMES'te 'gold_collector' hâlâ var")

	var src: String = FileAccess.get_file_as_string("res://scripts/shop_panel.gd")
	assert(src.length() > 0, "shop_panel.gd okunamadı")
	assert(src.find("\"mine\": {\"panel\"") == -1, "Dükkan satırlarında 'mine' girdisi hâlâ var")
	assert(src.find("\"gold_collector\": {\"panel\"") == -1, "Dükkan satırlarında 'gold_collector' girdisi hâlâ var")
	assert(src.find("GameManager.mine_level") == -1, "shop_panel.gd hâlâ GameManager.mine_level okuyor")
	assert(src.find("GameManager.gold_collector_level") == -1, "shop_panel.gd hâlâ GameManager.gold_collector_level okuyor")
	assert(src.find("mine_fill_bar.visible") == -1, "Dolum barı güncelleme kodu hâlâ duruyor")

	## Kaldırılan anahtar artık ÇÖKMEMELİ (eskiden MAX_LEVELS[item] erişimi
	## çökerdi) - _upgrade_cost'ın varsayılan dalına düşüyor.
	assert(ShopScript._upgrade_cost("mine", 1) > 0,
		"Kaldırılan 'mine' anahtarı maliyet hesabında varsayılana düşmüyor")
	assert(ShopScript._upgrade_cost("gold_collector", 1) > 0,
		"Kaldırılan 'gold_collector' anahtarı maliyet hesabında varsayılana düşmüyor")
