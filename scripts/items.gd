class_name Items

## Eşyalar: silah DEĞİLLER - sadece pasif stat/özellik sağlarlar. Karakterler
## seviye başına 1 eşya slotu kazanır (bkz. player.gd max_item_slots,
## level_up()). Dükkandan satın alınırlar (geliştirilemezler, ama aynı eşyadan
## fazladan kopya alınabilir - bkz. kullanıcı isteği "aynı eşya fazladan
## alınabilir... additive eklenir"), satın alınınca envanterde görünüp oradan
## satılabilirler (bkz. inventory_panel.gd).
##
## "stats" içindeki her anahtar player.gd'de BİREBİR aynı isimde bir "var"a
## karşılık gelmeli - player.gd _apply_item_stats() bunu genel (dynamic
## set/get) bir döngüyle uyguluyor, birkaç özel durum (dodge_chance/
## knockback_stat/max_health) hariç. Bir eşyadan N kopya alınırsa buradaki
## her değer N ile çarpılıp uygulanır (additive stacking - kullanıcı isteği).
const DEFS := {
	"vitamin": {
		"name": "Vitamin",
		"desc": "+20 can, +1 can yenilenmesi.\nPasif: Hasar almak 5 saniye boyunca 1 can yenilenmesi kazandırır.",
		"cost_base": 50,
		"stats": {
			"max_health": 20.0,
			"heal_regen_bonus": 1.0,
			## Pasifin (hasar sonrası 5sn +1/sn regen) potansiyel gücü - bkz.
			## player.gd take_damage()/_process_item_passives.
			"item_vitamin_regen_bonus": 1.0,
		},
	},
	"eldiven": {
		"name": "Eldiven",
		"desc": "%5 saldırı hızı.\nPasif: Saldırılar isabet halinde fazladan 5 hasar verir.",
		"cost_base": 55,
		"stats": {
			"item_fire_rate_percent": 0.05,
			"item_flat_hit_damage": 5.0,
		},
	},
	"deri_cizme": {
		"name": "Deri Çizme",
		"desc": "%1 sıvışma, %3 hareket hızı.\nPasif: Hareket halindeyken %1 sıvışma kazanırsın.",
		"cost_base": 45,
		"stats": {
			"dodge_chance": 0.01,
			"item_speed_percent": 0.03,
			## Pasifin (sadece hareket halindeyken) potansiyel gücü - bkz.
			## player.gd _process_item_passives.
			"item_move_dodge_base": 0.01,
		},
	},
	"sigara": {
		"name": "Sigara",
		"desc": "+4 saldırı gücü.\nPasif: Verdiğin hasar %2 artar.",
		"cost_base": 55,
		"stats": {
			"damage_bonus": 4.0,
			"item_damage_mult_bonus": 0.02,
		},
	},
	## DÜZELTME (kullanıcı isteği: "zırh statını ve zırhla ilgili herşeyi
	## oyundan kaldır") - eskiden +2 zırh VE %30 can altında +2 ek zırh pasifi
	## vardı, ikisi de zırhla birlikte kaldırıldı - artık sadece +can veriyor.
	"steroid": {
		"name": "Steroid",
		"desc": "+10 can.",
		"cost_base": 60,
		"stats": {
			"max_health": 10.0,
		},
	},
	"sansli_zar": {
		"name": "Şanslı Zar",
		"desc": "+2 şans.\nPasif: Düşmanlar %4 ihtimalle fazladan 1 altın düşürür.",
		"cost_base": 50,
		"stats": {
			"luck": 2.0,
			"item_extra_gold_chance": 0.04,
		},
	},
	"hasat_cantasi": {
		"name": "Hasat Çantası",
		"desc": "+%10 toplama menzili, +%5 tecrübe kazanımı.\nPasif: Her tecrübe toplarken %2 ihtimalle 1 can yenilersin.",
		"cost_base": 50,
		"stats": {
			"item_pickup_range_percent": 0.10,
			"exp_gain_percent": 0.05,
			"item_xp_heal_chance": 0.02,
		},
	},
	"kalkan_yuzugu": {
		"name": "Kalkan Yüzüğü",
		"desc": "+2 kalkan gücü, +%10 maksimum kalkan.\nPasif: Kalkanının yenilenme bekleme süresi 0.1sn azalır, kalkanın %4 daha hızlı yenilenir.",
		"cost_base": 55,
		"stats": {
			"item_shield_power_flat": 2.0,
			"shield_max_percent": 0.10,
			"item_shield_delay_reduction": 0.1,
			"item_shield_regen_percent": 0.04,
		},
	},
	## DÜZELTME (kullanıcı isteği: "zırh delme olmadığından yerini kalkan
	## delme alacak") - eskiden +%2 zırh delme AYRICA veriyordu, o miktar
	## şimdi kalkan delmeye katlandı (0.03 -> 0.05).
	"keskin_uclar": {
		"name": "Keskin Uçlar",
		"desc": "+2 saldırı gücü.\nPasif: %5 kalkan delme kazanırsın.",
		"cost_base": 55,
		"stats": {
			"damage_bonus": 2.0,
			"shield_pen_percent": 0.05,
		},
	},
	"kitelama_seti": {
		"name": "Kitelama Seti",
		"desc": "%1 hareket hızı, +40 itme gücü.\nPasif: Bir rakibe hasar vermek onun hareket hızını 5 saniyeliğine %10 azaltır (hasar vermek bu etkiyi baştan başlatır). Her ek Kitelama Seti kopyası hem itme gücünü hem de yavaşlatma oranını artırır.",
		"cost_base": 55,
		"stats": {
			"item_speed_percent": 0.01,
			"knockback_stat": 40.0,
			"item_enemy_slow_percent": 0.10,
		},
	},
	"kaos_kitabi": {
		"name": "Kaos Kitabı",
		"desc": "%5 saldırı hızı.\nPasif: Silahların %1 ihtimalle 2 defa ateşlenir (her silahın olasılığı birbirinden bağımsız hesaplanır).",
		"cost_base": 55,
		"stats": {
			"item_fire_rate_percent": 0.05,
			"item_double_fire_chance": 0.01,
		},
	},
	"vampir_disi": {
		"name": "Vampir Dişi",
		## Kullanıcı isteği: "Can çalma veren tüm statları %70 azalt (Kurt Adam
		## ve Pençe hariç)" - 0.01 -> 0.003.
		"desc": "%0.3 can çalma.\nPasif: Bir hedefi katletmek 1 can yeniler.",
		"cost_base": 55,
		"stats": {
			"lifesteal_percent": 0.003,
			"item_kill_heal_amount": 1.0,
		},
	},
	"yetenek_kitabi": {
		"name": "Yetenek Kitabı",
		"desc": "%3 bekleme süresinde azalma.\nPasif: Yeteneklerin kalkan bedeli %3 azalır.",
		"cost_base": 55,
		"stats": {
			"cooldown_reduction_percent": 0.03,
			"item_skill_shield_cost_reduction": 0.03,
		},
	},
}

## Dükkanda/envanterde sabit bir sırayla göstermek için.
const KEYS := [
	"vitamin", "eldiven", "deri_cizme", "sigara", "steroid", "sansli_zar",
	"hasat_cantasi", "kalkan_yuzugu", "keskin_uclar", "kitelama_seti", "kaos_kitabi",
	"vampir_disi", "yetenek_kitabi",
]

## Kullanıcı isteği: "bundan sonra 'ekstralar' eşyalarının tierları olacak.
## Tier başına ekstraların gücü ilk tier'ın gücünün %50 fazlasına sahip
## olacak: 1. tier %100, 2. tier %150, 3. tier %200, 4. tier %250 güçte." -
## SADECE sandıklardan çıkan eşyalar bir tier taşır (bkz. chest_menu.gd
## TierSystem.roll()); dükkandan düz satın alınan eşyalar her zaman Tier
## 1/%100 güçtedir (bkz. player.gd buy_item varsayılan power_mult=1.0).
## İndeks tier-1: [0]=Tier1(%100), [1]=Tier2(%150), [2]=Tier3(%200),
## [3]=Tier4(%250). player.gd _apply_item_stats() her stat değerini bu
## çarpanla büyütür (sign ile birlikte, satarken de AYNI çarpan geri
## uygulanır ki fazla/az iade olmasın - bkz. o fonksiyondaki not).
const ITEM_TIER_POWER := [1.0, 1.5, 2.0, 2.5]


static func get_def(key: String) -> Dictionary:
	return DEFS.get(key, {})
