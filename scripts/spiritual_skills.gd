extends RefCounted

## RUHANİ YETENEKLER (kullanıcı isteği, 2026-09-21): oyun başında karakter seçim ekranında (tek oyunculu: character_select.gd,
## çok oyunculu: lobby_menu.gd) HER oyuncu, hangi karakteri seçmiş olursa olsun bu 6 yetenekten BİRİNİ seçer. F tuşuyla
## kullanılır (action "skill4"); HUD'da 3. yetenek butonunun sağında, farklı çerçeve renginde ve %20 büyük bir butonda görünür.
## Bekleme süreleri "Bekleme Süresi Azaltma" statından ETKİLENMEZ (bkz. player.gd _spirit_* bloğu). Pasif olanın (Para) HUD'da
## sadece ikonu vardır.
##
## Bu dosya SADECE tanımları (ad, açıklama, sayılar, ikon/ses yolu) tutar - çalışma zamanı mantığı player.gd sonundaki
## "Ruhani Yetenekler" bloğunda. Sayılar TEK yerde (burada): player.gd, tooltip, seçim ekranı hepsi buradan okur.

const NONE := ""
const PARA := "para"
const CAN := "can"
const ADC := "adc"
const TANK := "tank"
const TAKTIK := "taktik"
const DUKKAN := "dukkan"

## Seçim ekranındaki sıra.
const ORDER := [PARA, CAN, ADC, TANK, TAKTIK, DUKKAN]
## Seçim yapılmamışsa (ör. editörden doğrudan sahne açılırsa) kullanılan varsayılan.
const DEFAULT_ID := PARA

## --- Sayılar (kullanıcı isteğindeki değerlerin birebir karşılığı) ---
const PARA_INTERVAL := 10.0 ## Para: her 10sn ...
const PARA_GOLD := 5 ## ... 5 altın
const PARA_SHOP_DISCOUNT := 0.10 ## dükkandaki altın bedelleri %10 azalır

const CAN_HEAL_PERCENT := 0.08 ## maksimum canın %8'i
const CAN_SHIELD_PERCENT := 0.15 ## maksimum kalkanın %15'i
const CAN_INVULN_TIME := 3.0
const CAN_COOLDOWN := 90.0

const ADC_DURATION := 10.0
const ADC_ATTACK_SPEED := 0.30 ## +%30 saldırı hızı
const ADC_SHIELD_PEN := 0.15 ## +%15 kalkan delme
const ADC_LIFESTEAL := 0.01 ## +%1 can emme
const ADC_COOLDOWN := 120.0

const TANK_DURATION := 10.0
const TANK_REFLECT := 0.60 ## alınan hasarın %60'ı hasarı verene yansır
const TANK_SHIELD_REGEN := 0.03 ## her hasarda eksik kalkanın %3'ü yenilenir
const TANK_COOLDOWN := 100.0

const TAKTIK_DISTANCE := 230.0 ## ileriye ışınlanma mesafesi
const TAKTIK_SPEED_BONUS := 0.30 ## +%30 hareket hızı
const TAKTIK_SPEED_TIME := 3.0
const TAKTIK_COOLDOWN := 30.0

const DUKKAN_CHANNEL := 3.0 ## odaklanma süresi
const DUKKAN_COOLDOWN := 120.0
## Odaklanma iptal edilirse (hareket/hasar) kısa bir kilit - ışınlanma tamamlanmadığı için tam bekleme süresi YOK, ama
## art arda basıp spam'lenmesin.
const DUKKAN_CANCEL_LOCKOUT := 4.0

const DEFS := {
	PARA: {
		"name": "Para",
		"active": false,
		"cooldown": 0.0,
		"icon": "res://assets/skills/spirit_para_icon.png",
		"desc": "PASİF: Her 10 saniyede 5 altın kazandırır ve dükkandaki altın bedelleri %10 azalır.",
	},
	CAN: {
		"name": "Can",
		"active": true,
		"cooldown": CAN_COOLDOWN,
		"duration": CAN_INVULN_TIME,
		"icon": "res://assets/skills/spirit_can_icon.png",
		"sound": "res://assets/audio/spiritual/spirit_can.wav",
		"desc": "Sana ve tüm takım arkadaşlarına mesafe fark etmeksizin anında %8 can ve %15 kalkan kazandırır ve 3 saniyeliğine hasar görmez hale getirir. (90sn bekleme)",
	},
	ADC: {
		"name": "Adc",
		"active": true,
		"cooldown": ADC_COOLDOWN,
		"duration": ADC_DURATION,
		"icon": "res://assets/skills/spirit_adc_icon.png",
		"sound": "res://assets/audio/spiritual/spirit_adc.wav",
		"desc": "10 saniyeliğine %30 saldırı hızı ve %15 kalkan delme kazanırsın, ayrıca %1 can emme kazanırsın. (120sn bekleme)",
	},
	TANK: {
		"name": "Tank",
		"active": true,
		"cooldown": TANK_COOLDOWN,
		"duration": TANK_DURATION,
		"icon": "res://assets/skills/spirit_tank_icon.png",
		"sound": "res://assets/audio/spiritual/spirit_tank.wav",
		"desc": "10 saniye boyunca aldığın hasarın %60'ını hasarı verene yansıtırsın ve her hasar aldığında eksik kalkanının %3'ü yenilenir. (100sn bekleme)",
	},
	TAKTIK: {
		"name": "Taktiksel",
		"active": true,
		"cooldown": TAKTIK_COOLDOWN,
		"duration": TAKTIK_SPEED_TIME,
		"icon": "res://assets/skills/spirit_taktik_icon.png",
		"sound": "res://assets/audio/spiritual/spirit_taktik.wav",
		"desc": "İleriye doğru ışınlanırsın ve hareket hızın 3 saniyeliğine %30 artar. (30sn bekleme)",
	},
	DUKKAN: {
		"name": "Dükkan",
		"active": true,
		"cooldown": DUKKAN_COOLDOWN,
		"duration": DUKKAN_CHANNEL,
		"icon": "res://assets/skills/spirit_dukkan_icon.png",
		"sound": "res://assets/audio/spiritual/spirit_dukkan.wav",
		"desc": "3 saniye odaklanıp dükkana (seyyar satıcıya) ışınlanırsın. Odaklanırken hareket eder ya da hasar alırsan iptal olur; satıcı yokken kullanılamaz. (120sn bekleme)",
	},
}


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func is_valid(id: String) -> bool:
	return DEFS.has(id)


static func is_active_skill(id: String) -> bool:
	return bool(get_def(id).get("active", false))


static func skill_name(id: String) -> String:
	return str(get_def(id).get("name", ""))


static func base_cooldown(id: String) -> float:
	return float(get_def(id).get("cooldown", 0.0))
