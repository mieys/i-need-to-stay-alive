extends RefCounted

## KALICI SİLAH ÖZELLİKLERİ - silahın bir parçası (kullanıcı 2026-10-11: "silah efsunlarını silahlara kalıcı olarak eklediğimiz için
## artık bunlar silahın bir parçası, o yüzden silahın kodlarıyla aynı yerde olmalılar"). Eskiden tablo + tanımlar enchant_defs.gd'deki
## kapalı efsun kartlarının arasında, davranışlar scripts/enchants/'taydı. Artık:
##   - TRAITS: silah anahtarı -> o silahın doğuştan özelliği (tek tablo; weapon_catalog.gd trait_text + EnchantDefs.trait_of buradan okur)
##   - DEFS: 18 özelliğin tanımı (desc, base, 4 geliştirme, final) - demirci "EFSUNLAR" sekmesi + envanter ipucu bu metinleri gösterir
##   - davranışlar: scripts/weapon_traits/<id>.gd (temel sınıf enchant_behavior.gd; weapon.gd önce bu klasörden yükler)
## Tanım biçimi EnchantDefs ile AYNI (resolve/upgrade_rows aynen çalışır: EnchantDefs.get_def önce buraya bakar). Sismik Dalga ve
## Rüzgâr Kılıcı eski efsun kartlarında da var (o kopyalar kapalı kart sistemine ait, bu tanımlar özelliğe).
## HEDEFLER: özellik kodu düşmanı enchant_behavior.gd'nin yardımcılarıyla bulur/vurur (enemies_near, hit, el()) - gerçek yaratıklar,
## bosslar ve görev kopyaları (mission_player_copy.gd apply_element) aynı yoldan etkilenir.

const TRAITS := {
	"dagger": "kanayan_kesikler", "pence": "kanli_pence", "topuz": "sismik_dalga", "uzunkilic": "wind_sword",
	"fire_staff": "ates_nefesi", "lightning_staff": "zincir_yildirim", "tabanca": "seri_parmak", "tuftuf": "sicrayan_zehir",
	"tufek": "delici_mermi", "arcane": "yankilanan_buyu", "yay": "uclu_ok", "crossbow": "balista",
	"boomerang": "seken_celik", "buz_asasi": "kirik_buz", "fisek": "kivilcim_yagmuru", "gokkusagi": "goz_kamastiran",
	"mizrak": "cirit", "kalkan": "siper", "yinyang": "denge", "pompali": "dip_atis", "makineli": "kizisan_namlu",
}

## Davranış scriptlerinin klasörü (delici_mermi scriptsizdir: sadece ortak anahtarlar).
const SCRIPT_DIR := "res://scripts/weapon_traits/%s.gd"


static func trait_of(weapon_key: String) -> String:
	return str(TRAITS.get(weapon_key, ""))


static func is_trait(id: String) -> bool:
	return DEFS.has(id)


static func script_path(id: String) -> String:
	return SCRIPT_DIR % id


const DEFS := {
	## Ateş Asası (2026-10-11): eski "Destiny of Ice and Fire" efsununun yerine SADECE ateşe ait, güncel sayılarla doğru metin
	## (kullanıcı: "alev asasının yetenek açıklaması yanlış, eski efsun açıklaması görünüyor, geliştirmelerde dahil").
	"ates_nefesi": {
		"weapons": ["fire_staff"], "name": "Ateş Nefesi", "element": "yanma",
		## Madde 639 (2026-11-13): alan = kullanıcının flamethrower efektinin şekli (ates_nefesi.gd + flamethrower_shape.gd), boy sabit 160.
		## "Genişleyen Boğaz" -> "Kavurucu Uç", final'in büyüme kısmı (ayrı büyük alev sayfası) -> "Isınan Nefes" (kullanıcı isteği).
		"desc": "Asa mermi atmaz; en yakın düşmana doğru sürekli bir alev püskürtür ve alevin içindeki herkesi yakar.",
		"base": {"text": "160 birim uzunluğunda bir alev püskürtürsün: ağızda ince bir hat, ucunda kabaran bir ateş bulutu. Alevin değdiği herkes 0,36 saniyede bir saldırı gücünün %27'si kadar hasar alır (saniyede %76) ve 3 saniye yanar (saniyede saldırı gücünün %14'ü). Püskürtme saldırı hızınla hızlanır.",
			"set": {"spray_range": 160.0, "spray_tick": 0.25, "spray_ap": 0.27, "spray_rate": 0.0,
				"elem_ap": 0.14, "elem_dur": 3.0, "elem_dur_mult": 1.0, "spray_push": 0.0, "tip_bonus": 0.0}},
		"upgrades": [
			{"name": "Kavurucu Uç", "text": "Alevin ucundaki ateş bulutuna yakalanan düşmanlar %40 fazla hasar alır.",
				"set": {"tip_bonus": 0.4}},
			{"name": "Yoğun Alev", "text": "Püskürtme %20 daha sık hasar verir (0,36 → 0,30 saniyede bir).", "add": {"spray_rate": 0.2}},
			{"name": "Kalıcı Yanık", "text": "Yanma süresi %30 uzar (3 → 3,9 saniye).", "add": {"elem_dur_mult": 0.3}},
			{"name": "Nefes Basıncı", "text": "Alev değdiği düşmanları hafifçe geri iterek yaklaşmalarını engeller (bosslar hariç).", "set": {"spray_push": 14.0}},
		],
		"final": {"name": "Ejderha Nefesi", "text": "Isınan Nefes: kesintisiz püskürttükçe alev ısınır, hasarı her saniye %15 artar (en çok %45; püskürtme kesilince sıfırlanır). Alevin ucuna saniyede bir lav birikintisi düşer: 3 saniye kalır, içindekiler saniyede saldırı gücünün %20'si kadar yanar.",
			"set": {"heat": true, "heat_rate": 0.15, "heat_cap": 0.45, "dragon": true}},
	},
	"wind_sword": {
		"weapons": ["uzunkilic"], "name": "Wind Sword", "element": "fiziksel",
		"desc": "Kılıç savuruşları şansa bağlı olarak düşmanları savuran ileri doğru bir rüzgar dalgası yaratır.",
		"base": {"text": "Her savuruş %50 ihtimalle ileri doğru 180 birim giden bir rüzgar dalgası yaratır: değdiği düşmanlara saldırı gücünün %75'i kadar hasar verir ve onları 60 birim savurur.",
			"set": {"wave_chance": 0.5, "wave_ap": 0.75, "wave_range": 180.0, "wave_width": 40.0, "wave_push": 60.0, "wave_slow": 0.0}},
		"upgrades": [
			{"name": "Yükselen Akım", "text": "Rüzgar dalgası oluşturma şansı: %50 → %65.", "add": {"wave_chance": 0.15}},
			{"name": "Hırçın Rüzgar", "text": "Rüzgar dalgasının hasarı: saldırı gücünün %75'i → %95'i.", "add": {"wave_ap": 0.2}},
			{"name": "Hava Presi", "text": "İtme mesafesi %40 artar (60 → 84 birim) ve savrulan düşmanlar 1,5 saniye %30 yavaşlar.",
				"add": {"wave_push": 24.0}, "set": {"wave_slow": 0.3}},
			{"name": "Genişleyen Tayfun", "text": "Rüzgar dalgasının genişliği ve menzili %35 büyür (menzil 180 → 243 birim).",
				"add": {"wave_range": 63.0, "wave_width": 14.0}},
		],
		"final": {"name": "Fırtına Biçici", "text": "Her savuruş rüzgar dalgası yaratır. Dalganın duvara ya da engele çarptırdığı düşmanlar %100 ek hasar alır ve 1 saniye sersemler.",
			"set": {"wave_chance_final": 1.0, "wall_slam": true}},
	},
	"sismik_dalga": {
		"weapons": ["topuz"], "name": "Sismik Dalga", "element": "fiziksel",
		"desc": "Balyoz yere vurduğunda şansa bağlı olarak vuruş noktasından yayılan, düşmanları sarsan bir şok dalgası çıkar.",
		"base": {"text": "Her vuruş %40 ihtimalle vuruş noktasından yayılan bir dalga çıkarır (4 vuruş üst üste çıkmazsa sonraki kesin çıkar): 110 birim içindeki en yakın 4 düşmana saldırı gücünün %50'si kadar hasar verir (kalabalıkta fazlası %35'ini alır) ve hepsini 20 birim sarsar (balyozun menzilinden atmaz).",
			"set": {"seis_chance": 0.40, "seis_pity": 4, "seis_radius": 110.0, "seis_ap": 0.5, "seis_push": 20.0, "seis_pulses": 1}},
		"upgrades": [
			{"name": "Halka Yankısı", "text": "Dalga ihtimali: %40 → %50.", "add": {"seis_chance": 0.10}},
			{"name": "Genişleyen Halka", "text": "Dalganın yarıçapı %25 büyür (110 → 137,5 birim).", "add": {"seis_radius": 27.5}},
			{"name": "Tok Darbe", "text": "Dalganın hasarı saldırı gücünün %50'si → %70'i olur, itme 20 → 30 birim.", "add": {"seis_ap": 0.2, "seis_push": 10.0}},
			{"name": "Çift Nabız", "text": "Tek dalga yerine art arda 2 dalga yayılır.", "add": {"seis_pulses": 1}},
		],
		"final": {"name": "Episantr", "text": "Dalga ihtimali %60 olur. Dalga düşmanları 1,5 saniye yere serer (sersemletir); savrulan düşmanlar birbirine çarparsa ikisi de saldırı gücünün %30'u kadar hasar alır.",
			"set": {"seis_chance_final": 0.6, "seis_knockdown": 1.5, "seis_collide": 0.3}},
	},
	"kanayan_kesikler": {
		"weapons": ["dagger"], "name": "Kanayan Kesikler", "element": "kanama",
		"desc": "Her vuruş üst üste binen bir kanama bırakır; kombonun son vuruşu kanamaları anında patlatır.",
		"base": {"text": "Her vuruş 4 saniyelik bir kanama yığını bırakır (yığın başına saniyede saldırı gücünün %6'sı). Yığınlar 5'e kadar üst üste biner. Kombonun 3. vuruşu hedefteki kanamaları anında patlatır: kalan hasarın tamamı tek seferde verilir.",
			"set": {"kb_ap": 0.06, "kb_dur": 4.0, "kb_cap": 5, "kb_combo": 3, "kb_burst": 1.0, "kb_spread": false}},
		"upgrades": [
			{"name": "Derin Kesik", "text": "Kanama hasarı: yığın başına saniyede saldırı gücünün %6'sı → %8'i.", "add": {"kb_ap": 0.02}},
			{"name": "Uzun Kanama", "text": "Kanama 2 saniye daha uzun sürer (4 → 6 sn).", "add": {"kb_dur": 2.0}},
			{"name": "Kalın Damar", "text": "Kanama yığın sınırı 5 → 8.", "add": {"kb_cap": 3}},
			{"name": "Kan Patlaması", "text": "Kombonun 3. vuruşundaki patlama hasarı %50 artar.", "add": {"kb_burst": 0.5}},
		],
		"final": {"name": "Kızıl Hasat", "text": "Kanayan bir düşman ölünce yığınlarının tamamı 100 birim içindeki en yakın düşmana geçer. Patlatma kombosu 3 vuruştan 2 vuruşa düşer.",
			"set": {"kb_spread": true, "kb_combo": 2}},
	},
	"kanli_pence": {
		"weapons": ["pence"], "name": "Kanlı Tırpan", "element": "kanama",
		"desc": "Tırpan darbeleri kanama bırakır; her tırpan darbesinde can kazanırsın.",
		## 2026-10-17 (kullanıcı: "pençe çok güçsüz ve az can basıyor" -> "kanama %20 sg olsun kanama birikmesin"): kanama %7 -> %20 (tek
		## yük, birikmez), can emme %4 -> %6 ve artık İLK vuruşta da (eskiden sadece zaten kanayan hedefte: yeni hedefe ilk vuruş 0 can).
		## 2026-10-19 (kullanıcı: "pençe aşırı güçlü olmuş hem çok can çalıyor hem de çok vuruyor" -> "kanama her hedefe uygulansın ama can emmesi %3'e düşsün
		## diğerlerini de aynen yap"): can emme %6 -> %3 ve SADECE ana hedef (alan payı vuruşlarından can yok), final %3 -> %1 azami can (saniyede en fazla
		## bir kez) + saldırı hızı %30 -> %20. Kanama (her hedefe %20 SG/sn) ve taban hasar aynı. Kayıt rev 63: Pençe toplam hasarın %43'ü.
		## 2026-10-19 (kullanıcı: "pençe hala çok can çalıyor" -> "sınırları kaldırıp oranları düşür"): can emme %3 -> %1 (Kan Emici %5 -> %2), final %1 ->
		## %0,5 azami can; saniyelik üst sınır YOK (ara sürümdeki kp_leech_cap ve "saniyede en fazla bir kez" kalktı). Kanama tikleri genel can çalma zarı atmaz.
		## 2026-10-19 (kullanıcı: "pençe çok az vuruyor buffla"): doğrudan hasar sahne oranı 1,035 -> 1,35 (+%30, %145 -> %189) ve kanama %20 -> %30 SG/sn (can emme aynı). BALANCE_REV 80.
		## Neden düşük oran: can emme hasarın yüzdesi ve saldırı gücü can sayısından çok hızlı büyür (kayıt rev 63: saldırı gücü 416 / can 655). BALANCE_REV 72 (madde 304).
		"base": {"text": "Her tırpan darbesi 3 saniyelik kanama bırakır (ana hedefte saniyede saldırı gücünün %30'u, alandaki diğer yaratıklarda %20'si; birikmez, her vuruş süreyi yeniler). Ana hedefe her tırpan darbesinde verdiğin hasarın %1'i kadar can kazanırsın (alandaki diğer yaratıklardan ve kanama hasarından can gelmez).",
			"set": {"kp_ap": 0.30, "kp_area": 0.6667, "kp_dur": 3.0, "kp_leech": 0.01, "bleeding_bonus": 0.0, "kp_kill_haste": 0.0, "kp_kill_heal": 0.0}},
		"upgrades": [
			{"name": "Derin Biçiş", "text": "Kanama hasarı: saniyede saldırı gücünün %30'u → %35'i (alandaki diğerlerinde %20 → %23).", "add": {"kp_ap": 0.05}},
			{"name": "Uzun Kanama", "text": "Kanama 1,5 saniye daha uzun sürer (3 → 4,5 sn).", "add": {"kp_dur": 1.5}},
			{"name": "Kan Emici", "text": "Can emme oranı: %1 → %2.", "add": {"kp_leech": 0.01}},
			{"name": "Yırtıcı Darbe", "text": "Kanayan düşmana verdiğin hasar %15 artar.", "set": {"bleeding_bonus": 0.15}},
		],
		"final": {"name": "Kan Susuzluğu", "text": "Kanayan bir düşmanı öldürdüğünde 3 saniye boyunca saldırı hızın %20 artar ve maksimum canının %0,5'i kadar iyileşirsin.",
			"set": {"kp_kill_haste": 0.2, "kp_kill_heal": 0.005}},
	},
	"zincir_yildirim": {
		"weapons": ["lightning_staff"], "name": "Zincir Yıldırım", "element": "sok",
		"desc": "Işın hedefinden en yakın düşmanlara zincirleme atlar.",
		"base": {"text": "Işın hedefinden en yakın 2 düşmana atlar (165 birim içinde, hasarın %50'si).",
			"set": {"chain_add": 2, "chain_pct": 0.50, "chain_range": 0.75, "chain_slow": 0.0}},
		"upgrades": [
			{"name": "Güçlü Atlayış", "text": "Atlayan şimşeğin hasarı: ışının %50'si → %65'i.", "add": {"chain_pct": 0.15}},
			{"name": "Geniş Zincir", "text": "Atlama menzili %40 uzar (165 → 231 birim).", "add": {"chain_range": 0.3}},
			{"name": "Üçüncü Halka", "text": "Atlama sayısı 2 → 3.", "add": {"chain_add": 1}},
			{"name": "Çarpılma", "text": "Atlayan şimşeğin vurduğu düşmanlar 1 saniye %25 yavaşlar.", "set": {"chain_slow": 0.25}},
		],
		"final": {"name": "Fırtına Zinciri", "text": "Atlama sayısı 2 daha artar ve atlayan şimşeklerin hasarı ışının %100'üne çıkar.",
			"add": {"chain_add": 2}, "set": {"chain_pct": 1.0}},
	},
	"seri_parmak": {
		"weapons": ["tabanca"], "name": "Seri Parmak", "element": "fiziksel",
		"desc": "Her öldürme saldırı hızını geçici olarak artırır; atışlar sıklaşır.",
		"base": {"text": "Öldürdüğün her düşman 3 saniye boyunca saldırı hızını %12 artırır. Etki 5 kata kadar üst üste biner ve her öldürme süreyi yeniler.",
			"set": {"sp_per": 0.12, "sp_cap": 5, "sp_dur": 3.0, "sp_extra": 0.0, "sp_full_double": false}},
		"upgrades": [
			{"name": "Hızlı Parmak", "text": "Yığın başına saldırı hızı: %12 → %15.", "add": {"sp_per": 0.03}},
			{"name": "Uzun Seri", "text": "Yığınlar 1,5 saniye daha uzun sürer (3 → 4,5 sn).", "add": {"sp_dur": 1.5}},
			{"name": "Çifte Seri", "text": "Yığın sınırı 5 → 7.", "add": {"sp_cap": 2}},
			{"name": "Kurşun Yağmuru", "text": "3 ve üstü yığındayken her atış %20 ihtimalle ek bir mermi daha atar.", "set": {"sp_extra": 0.2}},
		],
		"final": {"name": "Ölüm Sağanağı", "text": "Yığın sınırı 3 artar ve sınıra ulaşınca her atış iki mermi atar.",
			"add": {"sp_cap": 3}, "set": {"sp_full_double": true}},
	},
	## Madde 592 (2026-11-11): Bulaşıcı Salgı yerine. Yaratıklar zehir işlemeden ölüyordu; değer artık ÖLÜMDE (damla sıçrar), yere bir şey kalmaz.
	## Madde 749 (2026-11-16 buff, kullanıcı "sadece sayılar"): yük başına zehir %7 -> %10, atış 1,7 -> 1,3 sn (weapon_tuftuf.tscn fire_rate).
	"sicrayan_zehir": {
		"weapons": ["tuftuf"], "name": "Sıçrayan Zehir", "element": "zehir",
		"desc": "Atışları zehirler; zehirlediğin bir düşman ölünce zehir cesedinden en yakın düşmana sıçrar.",
		"base": {"text": "Her atış 6 saniyelik zehir yükü bırakır (yük başına saniyede saldırı gücünün %10'u, 5 yüke kadar). Zehirlediğin düşman zehirliyken ölürse (kim öldürürse öldürsün) cesedinden bir damla 110 birim içindeki en yakın düşmana sıçrar: saldırı gücünün %50'si kadar hasar verir ve onu da zehirler. Bir zincir en çok 3 kez sıçrar.",
			"set": {"poison_stacks": 1, "poison_dps": 0.10, "poison_dur": 6.0, "poison_cap": 5.0, "leap_ap": 0.5, "leap_range": 110.0, "leap_hops": 3, "leap_count": 1}},
		"upgrades": [
			{"name": "Keskin Damla", "text": "Sıçrama hasarı: saldırı gücünün %50'si → %70'i.", "add": {"leap_ap": 0.2}},
			{"name": "Uzun Zincir", "text": "Bir zincir en çok 3 → 4 kez sıçrar.", "add": {"leap_hops": 1}},
			{"name": "Uzak Sıçrayış", "text": "Sıçrama menzili 110 → 150 birim.", "add": {"leap_range": 40.0}},
			{"name": "Uzun Etki", "text": "Zehir 2 saniye daha uzun sürer (6 → 8 sn); zehirli düşmanın ölüp damla sıçratabileceği süre de uzar.", "add": {"poison_dur": 2.0}},
		],
		"final": {"name": "Kara Veba", "text": "Zehirli düşman ölünce iki damla iki ayrı düşmana sıçrar.", "set": {"leap_count": 2}},
	},
	"delici_mermi": {
		"weapons": ["tufek"], "name": "Delici Mermi", "element": "fiziksel",
		"desc": "Mermi bir düşmanda durmaz, arkasındakileri de delip geçer ve her delişte güçlenir.",
		"base": {"text": "Mermi arkasındaki 2 düşmanı da deler (toplam 3 düşmana vurur); delinen düşmanlar hasarın %70'ini alır.",
			"set": {"pierce": 2, "pierce_pct": 0.7, "pierce_ramp": 0.0, "proj_speed": 1.0, "slow_pct": 0.0, "shield_pen": 0.0}},
		"upgrades": [
			{"name": "Sivri Uç", "text": "Delinen düşman sayısı 2 → 3.", "add": {"pierce": 1}},
			{"name": "Kinetik Enerji", "text": "Delinen her düşmanla mermi hasarı %10 artar.", "add": {"pierce_ramp": 0.10}},
			{"name": "Hızlı Mermi", "text": "Mermi %25 daha hızlı uçar.", "set": {"proj_speed": 1.25}},
			{"name": "Ezici Darbe", "text": "Vurulan düşmanlar 1 saniye %20 yavaşlar.", "set": {"slow_pct": 0.2, "slow_dur": 1.0}},
		],
		"final": {"name": "Zırh Delen Salvo", "text": "Mermi 3 düşman daha deler ve düşmanların kalkan korumasını %30 yok sayar.",
			"add": {"pierce": 3}, "set": {"shield_pen": 0.3}},
	},
	## Pompalı Tüfek (madde 448): saçmalar ortaya yoğun dar koni şeklinde saçılır, her biri saldırı gücünün %42'sini vurur -> hasar mesafeyle
	## kendiliğinden değişir (yakında 6 x %42 = %252, orta mesafede 4, uzakta 2 saçma). Davranış scripts/weapon_traits/dip_atis.gd, koni scripts/pompali_math.gd.
	"dip_atis": {
		"weapons": ["pompali"], "name": "Dip Atış", "element": "fiziksel",
		"desc": "Her atış koni şeklinde saçılan saçmalar atar; hedef ne kadar yakınsa o kadar çok saçma isabet eder.",
		"base": {"text": "Her atış 6 saçma atar (14°'lik, ortaya yoğun koni); her saçma saldırı gücünün %42'sini vurur. Yakındaki hedefe hepsi isabet eder (toplam %252), orta mesafede 4, uzakta 2 saçma.",
			"set": {"pellets": 6, "cone_mult": 1.0, "push": 0.0, "full_every": 0}},
		"upgrades": [
			{"name": "Çift Dolum", "text": "Saçma sayısı 2 artar (6 → 8).", "add": {"pellets": 2}},
			{"name": "Sıkı Demet", "text": "Koni %35 daralır (14° → 9,1°); orta ve uzak mesafede daha çok saçma isabet eder.", "set": {"cone_mult": 0.65}},
			{"name": "Kırıcı Darbe", "text": "100 birim içinde vurduğun sıradan yaratıklar geri itilir (bosslar ve elitler itilmez).", "set": {"push": 28.0}},
			{"name": "Tam Yük", "text": "Her 4. atış çift yüktür: saçma sayısı iki katına çıkar ve koni %30 genişler.", "set": {"full_every": 4}},
		],
		"final": {"name": "Kasırga Yükü", "text": "Saçma sayısı 4 artar ve Tam Yük her 3. atışta çıkar.",
			"add": {"pellets": 4}, "set": {"full_every": 3}},
	},
	## Makineli (madde 652, kullanıcı tasarımı: "30 şarjör, ilk sıkışlarda yavaş başlıyor, giderek hızlanıyor, şarjör bitince yenileniyor ve
	## sıfırlanıyor; geliştirmeler şarjör boyu + ekstra"). Hızlanma kuralı gun_mag_math.gd "ramp" (başlangıç x1,6 W, her aralık %8 kısalır,
	## tavan x0,27 W), weapon.gd _mag_next_gap / ramp_at_top; davranış scripts/weapon_traits/kizisan_namlu.gd. Sayılar W = 0,3 sn (sahne
	## fire_rate 0,21 / genel 0,7): ilk aralık 0,48 sn, tavan 0,081 sn (23. aralıktan sonra), 30 mermi ~5,6 sn, doldurma ~3,4 sn.
	## Geliştirmeler doldurmayı uzatmaz (reload_time temel 30'luk şarjörden) - bilinçli güç artışı.
	"kizisan_namlu": {
		"weapons": ["makineli"], "name": "Kızışan Namlu", "element": "fiziksel",
		"desc": "Şarjör yavaş başlar, her atışta biraz daha hızlanır; şarjör bitince doldurulur ve hız başa döner.",
		"base": {"text": "30 mermilik şarjör. İlk atışlar saniyede ~2 mermi; her atış bir öncekinden %8 daha çabuk çıkar ve şarjörün son mermilerinde saniyede ~12 mermiye ulaşır. Şarjör bitince doldurulur (~3,4 sn) ve hız başa döner. Saldırı hızı hepsini hızlandırır.",
			"set": {"mag_add": 0, "hot_start": 0, "hot_dmg": 0.0, "ramp_floor_mult": 1.0, "hot_pierce": false}},
		"upgrades": [
			{"name": "Uzatılmış Şarjör", "text": "Şarjör 10 mermi büyür (30 → 40); doldurma süresi değişmez. Eklenen mermiler en yüksek hızda çıkar.", "add": {"mag_add": 10}},
			{"name": "Tamburlu Şarjör", "text": "Şarjör 10 mermi daha büyür (diğer kartla birlikte 30 → 50); doldurma süresi değişmez.", "add": {"mag_add": 10}},
			{"name": "Sıcak Namlu", "text": "Doldurmadan sonra namlu soğumaz: yeni şarjör ısınmış başlar (ilk atışlar saniyede ~2 yerine ~5 mermi).", "set": {"hot_start": 10}},
			{"name": "Kızgın Mermiler", "text": "En yüksek hızdayken çıkan mermiler %25 fazla hasar verir.", "set": {"hot_dmg": 0.25}},
		],
		"final": {"name": "Kurşun Fırtınası", "text": "En yüksek hız %33 artar (saniyede ~12 → ~16 mermi). En yüksek hızdaki mermiler hedefi delip arkasındaki ilk düşmana da tam hasar verir.",
			"set": {"ramp_floor_mult": 0.75, "hot_pierce": true}},
	},
	"yankilanan_buyu": {
		"weapons": ["arcane"], "name": "Yankılanan Büyü", "element": "kaos",
		## Madde 749 (2026-11-16 buff, kullanıcı: "her 3 saldırıda herhangi bir hedefte kesin açılıyorsa"): şans kalktı, sayaç SİLAHA bağlı
		## (echo_chance 0 + echo_pity 2 = her 3. isabet; echo_pity <= 0 = her isabet, bkz. yankilanan_buyu.gd _echo_now), patlama %70 -> %100.
		"desc": "Asanın her 3. isabeti hedefin yerinde bir kaos yarığı açar; kısa süre sonra yarık patlar.",
		"base": {"text": "Asanın her 3. isabeti (hangi düşmana olursa olsun) hedefin yerinde bir kaos yarığı açar. 0,8 saniye sonra yarık patlar: 45 birim içindekilere silah hasarının %100'ü kadar vurur.",
			"set": {"echo_chance": 0.0, "echo_pity": 2, "echo_delay": 0.8, "echo_dmg": 1.0, "echo_radius": 45.0, "echo_repeat": 0, "echo_stun": 0.0}},
		"upgrades": [
			{"name": "Sık Yankı", "text": "Yarık her 3. yerine her 2. isabette açılır.", "add": {"echo_pity": -1}},
			{"name": "Güçlü Yankı", "text": "Yankı patlamasının hasarı: silah hasarının %100'ü → %120'si.", "add": {"echo_dmg": 0.2}},
			{"name": "Geniş Yankı", "text": "Yankı patlamasının alanı 45 → 60 birim.", "add": {"echo_radius": 15.0}},
			{"name": "Çift Yankı", "text": "Yankı 0,5 saniye sonra bir kez daha patlar (hasarın %50'si).", "add": {"echo_repeat": 1}},
		],
		"final": {"name": "Çınlayan Boşluk", "text": "Yarık bir isabet daha erken açılır (Sık Yankı ile birlikte her isabette) ve patlamaya yakalananlar 0,5 saniye sersemler.",
			"add": {"echo_pity": -1}, "set": {"echo_stun": 0.5}},
	},
	## Mızrak (madde 305; öneri kullanıcıya sunuldu, "güzel"): her N. saplamada fırlatılan cirit. Görünüş/zaman scripts/mizrak_thrust_math.gd,
	## hasar scripts/weapon_traits/cirit.gd (karede ilerleyen uç). cirit_every n() ile okunur (geliştirme -1 ekler).
	"cirit": {
		"weapons": ["mizrak"], "name": "Cirit", "element": "fiziksel",
		"desc": "Birkaç saplamada bir mızrağını düz bir hatta fırlatırsın; cirit yolundaki herkesi delip geçer.",
		"base": {"text": "Her 4. saplamada mızrağı hedefe doğru fırlatırsın: cirit senden 280 birim uzağa kadar düz bir hatta uçar ve yolundaki tüm düşmanlara saldırı gücünün %90'ı kadar hasar verir (saplamanın kendi hasarı da hedefe ve arkasındakilere işler). Mızrak 0,4 saniye sonra elinde yeniden belirir.",
			"set": {"cirit_every": 4, "cirit_range": 280.0, "cirit_speed": 1.0, "cirit_ap": 0.9, "cirit_vuln": 0.0, "cirit_skewer": 0}},
		"upgrades": [
			{"name": "Hafif Cirit", "text": "Cirit her 4. saplama yerine her 3. saplamada fırlatılır.", "add": {"cirit_every": -1}},
			{"name": "Uzun Atış", "text": "Ciritin menzili 280 → 360 birim, cirit %25 daha hızlı uçar.", "add": {"cirit_range": 80.0, "cirit_speed": 0.25}},
			{"name": "Ağır Uç", "text": "Ciritin hasarı: saldırı gücünün %90'ı → %120'si.", "add": {"cirit_ap": 0.3}},
			{"name": "Yarık Zırh", "text": "Ciritin vurduğu düşmanlar 3 saniye boyunca mızrağından %15 fazla hasar alır.", "set": {"cirit_vuln": 0.15}},
		],
		"final": {"name": "Şişleyen Cirit", "text": "Cirit vurduğu ilk 3 düşmanı ucuna geçirip yolun sonuna kadar sürükler ve orada yere çakılır: şişlenen düşmanlar 1 saniye sersemler ve saldırı gücünün %100'ü kadar ek hasar alır, çakıldığı yerin 70 birim çevresindekiler saldırı gücünün %50'si kadar hasar alır. Bosslar sürüklenmez, sadece hasar alır.",
			"set": {"cirit_skewer": 3}},
	},
	"uclu_ok": {
		"weapons": ["yay"], "name": "Üçlü Ok", "element": "fiziksel",
		"desc": "Belirli aralıklarla ana okun yanında yelpaze halinde ek oklar çıkar.",
		"base": {"text": "Her 3. atışta ana okun yanında 2 ok daha yelpaze halinde çıkar (yan oklar hasarın %60'ı).",
			"set": {"fan_every": 3, "fan_extra": 2, "fan_deg": 10.0, "fan_dmg": 0.6, "fan_haste": 0.0, "pierce": 0}},
		"upgrades": [
			{"name": "Seri Çekiş", "text": "Yelpaze her 3. atış yerine her 2. atışta çıkar.", "add": {"fan_every": -1}},
			{"name": "Keskin Yan Oklar", "text": "Yan okların hasarı: ana okun %60'ı → %75'i.", "add": {"fan_dmg": 0.15}},
			{"name": "Geniş Yelpaze", "text": "Yan ok sayısı 2 → 4 (toplam 5 ok).", "add": {"fan_extra": 2}},
			{"name": "Delici Uçlar", "text": "Oklar bir düşmanı delip geçer.", "set": {"pierce": 1}},
		],
		"final": {"name": "Ok Yağmuru Salvosu", "text": "Yan ok sayısı 2 daha artar ve her yelpazeden sonra 1,5 saniye boyunca saldırı hızın %30 artar.",
			"add": {"fan_extra": 2}, "set": {"fan_haste": 0.3}},
	},
	## Balista (madde 553): Zincir Cıvata'nın yerine. Sayılar benim seçimim (kullanıcı yalnız "balista" görselini seçti): temel her 4. atışta
	## %150 SG alan hasarı (Arbalet ~1,57 sn'de bir atar -> ~6 sn'de bir), tam geliştirmede her 3. atışta 2 x %200.
	"balista": {
		"weapons": ["crossbow"], "name": "Balista", "element": "fiziksel",
		"desc": "Belirli atışlarda isabet ettiğin yere gökten dev bir balista oku düşer ve çevresindekilere hasar verir.",
		"base": {"text": "Her 4. atışın isabet ettiği yere dev bir balista oku düşer: 70 birim içindekilere saldırı gücünün %150'si kadar hasar verir.",
			"set": {"bal_every": 4, "bal_ap": 1.5, "bal_radius": 70.0, "bal_stun": 0.0, "bal_second": 0.0}},
		"upgrades": [
			{"name": "Sık Kuşatma", "text": "Balista oku her 4. atış yerine her 3. atışta düşer.", "add": {"bal_every": -1}},
			{"name": "Demir Uç", "text": "Balista okunun hasarı: saldırı gücünün %150'si → %200'ü.", "add": {"bal_ap": 0.5}},
			{"name": "Geniş Krater", "text": "Okun etki alanı %30 büyür (70 → 91 birim).", "add": {"bal_radius": 21.0}},
			{"name": "Sarsıcı Düşüş", "text": "Okun düştüğü yerdeki düşmanlar 0,5 saniye sersemler.", "set": {"bal_stun": 0.5}},
		],
		"final": {"name": "Çifte Kuşatma", "text": "Balista iki ok indirir: ikinci ok 0,45 saniye sonra aynı yere düşer ve ilk ok kadar vurur.",
			"set": {"bal_second": 1.0}},
	},
	## Çakram (madde 591, 2026-11-11): eski "Çifte Dönüş" (her N. atışta ikinci çakram) yerine çakrama özgü SEKME + final Çelik Değirmen
	## (kullanıcı: "final halinde gittiği yerde testere gibi dönüp belli bir süre kaldığı ... kopyası ama kendi çalışma biçimi değişmicek").
	## Mekanik boomerang_projectile.gd (_try_bounce), davranış seken_celik.gd, kopya görseli chakram_mill_fx.gd.
	"seken_celik": {
		"weapons": ["boomerang"], "name": "Seken Çelik", "element": "fiziksel",
		"desc": "Çakram çarptığı düşmandan sana dönmek yerine yakındaki başka bir düşmana seker.",
		"base": {"text": "Çakram çarptığı düşmandan sana dönmek yerine 100 birim içindeki en yakın başka düşmana bir kez seker (sekmede hasarın %40'ı), sonra döner.",
			"set": {"rico_count": 1, "rico_dmg": 0.4, "rico_range": 100.0, "rico_slow": 0.0, "mill_dur": 0.0, "mill_tick": 0.3, "mill_ap": 0.15, "mill_radius": 32.0}},
		"upgrades": [
			{"name": "Çift Sekme", "text": "Sekme sayısı 1 → 2.", "add": {"rico_count": 1}},
			{"name": "Keskin Kenar", "text": "Sekme hasarı: %40 → %55.", "add": {"rico_dmg": 0.15}},
			{"name": "Uzun Kol", "text": "Sekme menzili %40 uzar (100 → 140 birim).", "add": {"rico_range": 40.0}},
			{"name": "Çentik", "text": "Sekerek vurulan düşmanlar 1 saniye %20 yavaşlar.", "set": {"rico_slow": 0.2}},
		],
		"final": {"name": "Çelik Değirmen", "text": "Çakram geri dönmeye başladığı yerde kendinin çelik bir kopyasını bırakır: kopya 2,5 saniye yerinde testere gibi döner ve 32 birim içindekilere 0,3 saniyede bir saldırı gücünün %15'i kadar vurur. Aynı anda en fazla 1 kopya olur.",
			"set": {"mill_dur": 2.5}},
	},
	"kirik_buz": {
		## 2026-11-14 denge turu (kullanıcı: "hasarı artırmak yerine daha hızlı ve seri dondursun, supportive olsun"): asa 1,56 -> 1,0 sn atar (sahne oranı 0,9 -> 0,6,
			## saniyelik hasar aynı), her isabet %30 yavaşlatır, dondurma 3,1 sn yerine 2,0 sn'de bir gelir.
			"weapons": ["buz_asasi"], "name": "Kırık Buz", "element": "donma",
		"desc": "Asa hızlı atar: her isabet yavaşlatır, sık sık dondurur; donmuşken ölen düşman parçalanır.",
		## 2026-10-10 (kullanıcı: "buz asası hiç dondurmuyor ve efsunu çok işlevsiz"): sayaç asaya bağlı (freeze_count_global; eskiden düşman başınaydı ve asa hedefleri
		## dağıttığı için neredeyse hiç dolmuyordu), taban her 3. -> her 2. isabet, parçalanma %100 -> %120 ve alan 90 -> 100.
		"base": {"text": "Asanın her isabeti vurduğu düşmanı 1,5 saniye %30 yavaşlatır, her 2. isabeti 1,5 saniye dondurur. Donmuşken ölen düşman parçalanır: 100 birim içindekilere saldırı gücünün %120'si kadar vurur ve onları 1 saniye %40 yavaşlatır.",
			"set": {"slow_pct": 0.3, "slow_dur": 1.5, "slow_chill": true, "freeze_after": 2, "freeze_count_global": true, "freeze_dur": 1.5, "shatter_ap": 1.2, "shatter_radius": 100.0, "shatter_slow": 0.4, "shatter_slow_dur": 1.0, "shatter_freeze": false}},
		"upgrades": [
			{"name": "Çabuk Don", "text": "Asanın HER isabeti dondurur (her 2. yerine).", "add": {"freeze_after": -1}},
			{"name": "Uzun Buz", "text": "Donma süresi 1,5 → 2 saniye.", "add": {"freeze_dur": 0.5}},
			{"name": "Keskin Kırıklar", "text": "Parçalanma hasarı: saldırı gücünün %120'si → %160'ı.", "add": {"shatter_ap": 0.4}},
			{"name": "Geniş Parçalanma", "text": "Parçalanma alanı 100 → 130 birim.", "add": {"shatter_radius": 30.0}},
		],
		"final": {"name": "Buzul Çöküşü", "text": "Parçalanma hasarı saldırı gücünün %200'üne çıkar ve parçaların vurduğu komşuları 1,5 saniye dondurur.",
			"set": {"shatter_ap": 2.0, "shatter_freeze": true}},
	},
	"kivilcim_yagmuru": {
		"weapons": ["fisek"], "name": "Kıvılcım Yağmuru", "element": "yanma",
		"desc": "Dinamit patladığı yerde bir süre rastgele kıvılcım patlamaları bırakır.",
		"base": {"text": "Dinamit patlayınca patlama yerinde 3 saniye boyunca rastgele kıvılcım patlamaları olur: 45 birimlik alanda 0,4 saniyede bir, her biri 22 birim içine saldırı gücünün %25'i kadar vurur.",
			"set": {"spark_dur": 3.0, "spark_gap": 0.4, "spark_ap": 0.25, "spark_area": 45.0, "spark_radius": 22.0, "spark_count": 1, "spark_mult": 1.0}},
		"upgrades": [
			{"name": "Sık Kıvılcım", "text": "Kıvılcımlar 0,4 yerine 0,3 saniyede bir patlar.", "add": {"spark_gap": -0.1}},
			{"name": "Uzun Yağmur", "text": "Yağmur 1,5 saniye daha uzun sürer (3 → 4,5 sn).", "add": {"spark_dur": 1.5}},
			{"name": "Güçlü Kıvılcım", "text": "Kıvılcım hasarı: saldırı gücünün %25'i → %35'i.", "add": {"spark_ap": 0.10}},
			{"name": "Geniş Alan", "text": "Kıvılcımların yağdığı alan 45 → 65 birim.", "add": {"spark_area": 20.0}},
		],
		"final": {"name": "Kıvılcım Fırtınası", "text": "Her seferinde 2 kıvılcım patlar ve kıvılcım hasarları %50 artar.",
			"set": {"spark_count": 2, "spark_mult": 1.5}},
	},
	## Gökkuşağı Asası (2026-10-19, madde 306): kullanıcı onaylı öneri - ışın aynı düşmanda kesintisiz kalınca göz kamaşır, final delen ışın.
	## Sayaç/kamaşma scripts/weapon_traits/goz_kamastiran.gd, delme weapon.gd _update_beam_reach ("beam_pierce").
	"goz_kamastiran": {
		"weapons": ["gokkusagi"], "name": "Göz Kamaştıran Işık", "element": "kutsal",
		"desc": "Işını aynı düşmanda kesintisiz tutarsan gözü kamaşır: kısa süre saldıramaz, yetenek kullanamaz ve yalpalar.",
		"base": {"text": "Işını aynı düşmanda 3 saniye kesintisiz tutunca gözü 1,5 saniye kamaşır: saldıramaz, yetenek kullanamaz, yerinde yalpalar. Bosslar ve elitler kamaşmaz; onun yerine 3 saniye boyunca %20 az hasar verir. Işın başka hedefe geçerse ya da kesilirse süre sıfırlanır; ışın tuttukça kalınlaşıp parlar.",
			"set": {"dz_need": 3.0, "dz_dur": 1.5, "dz_boss": 3.0, "dz_vuln": 0.0, "dz_burst": 0.0, "dz_burst_r": 70.0, "dz_burst_stun": 0.75}},
		"upgrades": [
			{"name": "Hızlı Kamaşma", "text": "Kamaşma için gereken süre 3 → 2 saniye.", "add": {"dz_need": -1.0}},
			{"name": "Uzun Kamaşma", "text": "Kamaşma 1,5 → 2,25 saniye sürer; bosslardaki zayıflatma 3 → 4,5 saniye.", "add": {"dz_dur": 0.75, "dz_boss": 1.5}},
			{"name": "Kör Nokta", "text": "Gözü kamaşmış düşman herkesten %20 fazla hasar alır.", "set": {"dz_vuln": 0.2}},
			{"name": "Işık Saçılması", "text": "Kamaşma anında 70 birim içindeki düşmanlar saldırı gücünün %60'ı kadar hasar alır ve 0,75 saniye kamaşır.",
				"set": {"dz_burst": 0.6}},
		],
		"final": {"name": "Gökkuşağı Mızrağı", "text": "Işın artık ilk düşmanda durmaz: görüş alanının sonuna kadar dümdüz ve kalın uzanır, yolundaki her düşmanı delip geçer ve hepsine tam hasar verir. Delinen her düşmanın kamaşma süresi aynı anda işler.",
			"set": {"beam_pierce": true}},
	},
	## Kalkan (madde 338; 2026-11-14: kalkan doldurma KALDIRILDI, kullanıcı isteği - slotlar hasar/itme güçlendirmesi oldu; 2026-11-15 madde 705:
	## Sert Darbe -> Sağlam Siper, siper duruşu tam blok yerine %30 hasar azaltma - sayı KalkanGuard.DAMAGE_REDUCTION ile aynı). Davranış scripts/weapon_traits/siper.gd, darbe scripts/kalkan_bash_math.gd.
	"siper": {
		"weapons": ["kalkan"], "name": "Siper", "element": "fiziksel",
		"desc": "Kalkanını silah gibi kullanırsın: darbe önündeki herkese vurur ve geri iter; baktığı yönden gelen menzilli atışları karşılar. Özellikler darbeyi sarsıcı, siperi sağlam yapar.",
		"base": {"text": "Kalkan darbesi önündeki herkese saldırı gücünün %150'si kadar hasar verir ve geri iter. Kalkanın baktığı yönden gelen menzilli atışların hasarı %30 azalır.",
			"set": {"siper_guard": 0.0, "siper_push": 0.0, "siper_heavy": 0.0, "siper_slow": 0.0, "siper_wall": 0}},
		"upgrades": [
			{"name": "Sağlam Siper", "text": "Kalkanın baktığı yönden gelen menzilli atışların hasarı %30 yerine %50 azalır.", "set": {"siper_guard": 0.2}},
			{"name": "Sert İtiş", "text": "Darbenin geri itmesi %50 artar (45 → 67 birim; bosslar itilmez).", "set": {"siper_push": 0.5}},
			{"name": "Ağır Kenar", "text": "Mana kalkanın %50'nin üstündeyken darbe hasarı %30 artar (saldırı gücünün %150'si → %195'i).", "set": {"siper_heavy": 0.3}},
			{"name": "Sarsıcı Darbe", "text": "Darbenin vurduğu düşmanlar 1,5 saniye %25 yavaşlar.", "set": {"siper_slow": 0.25}},
		],
		"final": {"name": "Yıkılmaz Duvar", "text": "Her 5. darbe çevrendeki 140 birim içindeki herkese vurur: saldırı gücünün %225'i kadar hasar, 1 saniye sersemletme ve iki kat itme (90 birim; bosslar itilmez).",
			"set": {"siper_wall": 5}},
	},
	## Yin Yang Kitabı (madde 334): kitabın kendi kuralı (isabet başına %15 SG kalkan, MENZİLSİZ en boş oyuncuya - kullanıcı: "kalkan menzili olmasın,
	## tek kişilikte de uyumlu olmalı") scripts/yinyang_book.gd; Denge = kalkan boşa gitmez (Yin) / zor durumdakine fazla gider (Yang).
	## Davranış scripts/weapon_traits/denge.gd (Kara Mühür, Tai Chi Mührü). Kalkan sayıları SG'ye bağlı (azami kalkan yüzdesi değil).
	"denge": {
		"weapons": ["yinyang"], "name": "Denge", "element": "kutsal",
		"desc": "Kitap her vuruşta ihtiyaca göre bir yana eğilir: korunacak kimse yoksa kalkan hasara döner, zor durumdakine daha çok kalkan gider.",
		"base": {"text": "Yin: kalkan alabilecek herkesin mana kalkanı doluysa vuruşun kalkanı boşa gitmez, hasara döner - hedef ayrıca saldırı gücünün %40'ı kadar hasar alır. Yang: mana kalkanı %30'un altındaki birine giden kalkan 1,5 katına çıkar (saldırı gücünün %22,5'i).",
			"set": {"ys_shield": 0.15, "yin_ap": 0.4, "yang_th": 0.3, "yang_mult": 1.5, "km_pct": 0.0, "km_dur": 2.0,
				"tc_every": 0, "tc_r": 90.0, "tc_dur": 3.0, "tc_ap": 0.35, "tc_shield": 0.05, "tc_yin": 0.1}},
		"upgrades": [
			{"name": "Kalın Sayfa", "text": "Vuruş başına kalkan: saldırı gücünün %15'i → %18'i.", "add": {"ys_shield": 0.03}},
			{"name": "Ağır Yin", "text": "Hasara dönen kalkan: saldırı gücünün %40'ı → %55'i.", "add": {"yin_ap": 0.15}},
			{"name": "Sıcak Yang", "text": "Yang eşiği %30 → %40, kalkan 1,5 kat → 2 kat.", "set": {"yang_th": 0.4, "yang_mult": 2.0}},
			{"name": "Kara Mühür", "text": "Kitabın vurduğu düşman 2 saniye boyunca %10 az hasar verir (bosslar dahil).", "set": {"km_pct": 0.1}},
		],
		"final": {"name": "Tai Chi Mührü", "text": "Her 6. vuruşta hedefin altında 90 birimlik dönen bir mühür açılır ve 3 saniye kalır: içindeki düşmanlar saniyede saldırı gücünün %35'i kadar hasar alır, mühür her saniye kalkanı en boş oyuncuya saldırı gücünün %5'i kadar mana kalkanı gönderir (kimse alamıyorsa mühürdeki düşmanlara saldırı gücünün %10'u kadar ek hasar olur).",
			"set": {"tc_every": 6}},
	},
}
