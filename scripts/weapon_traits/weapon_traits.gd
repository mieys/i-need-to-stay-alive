extends RefCounted

## KALICI SİLAH ÖZELLİKLERİ - silahın bir parçası (kullanıcı 2026-10-11: "silah efsunlarını silahlara kalıcı olarak eklediğimiz için
## artık bunlar silahın bir parçası, o yüzden silahın kodlarıyla aynı yerde olmalılar"). Eskiden tablo + tanımlar enchant_defs.gd'deki
## kapalı efsun kartlarının arasında, davranışlar scripts/enchants/'taydı. Artık:
##   - TRAITS: silah anahtarı -> o silahın doğuştan özelliği (tek tablo; weapon_catalog.gd trait_text + EnchantDefs.trait_of buradan okur)
##   - DEFS: 15 özelliğin tanımı (desc, base, 4 geliştirme, final) - demirci "EFSUNLAR" sekmesi + envanter ipucu bu metinleri gösterir
##   - davranışlar: scripts/weapon_traits/<id>.gd (temel sınıf enchant_behavior.gd; weapon.gd önce bu klasörden yükler)
## Tanım biçimi EnchantDefs ile AYNI (resolve/upgrade_rows aynen çalışır: EnchantDefs.get_def önce buraya bakar). Sismik Dalga ve
## Rüzgâr Kılıcı eski efsun kartlarında da var (o kopyalar kapalı kart sistemine ait, bu tanımlar özelliğe).
## HEDEFLER: özellik kodu düşmanı enchant_behavior.gd'nin yardımcılarıyla bulur/vurur (enemies_near, hit, el()) - gerçek yaratıklar,
## bosslar ve görev kopyaları (mission_player_copy.gd apply_element) aynı yoldan etkilenir.

const TRAITS := {
	"dagger": "kanayan_kesikler", "pence": "kanli_pence", "topuz": "sismik_dalga", "uzunkilic": "wind_sword",
	"fire_staff": "ates_nefesi", "lightning_staff": "zincir_yildirim", "tabanca": "seri_parmak", "tuftuf": "bulasici_salgi",
	"tufek": "delici_mermi", "arcane": "yankilanan_buyu", "yay": "uclu_ok", "crossbow": "zincir_civata",
	"boomerang": "cifte_donus", "buz_asasi": "kirik_buz", "fisek": "kivilcim_yagmuru",
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
		"desc": "Asa mermi atmaz; en yakın düşmana doğru sürekli bir alev konisi püskürtür ve konideki herkesi yakar.",
		"base": {"text": "60°'lik, 140 birim menzilli bir alev konisi püskürtürsün. Koninin içindeki herkes 0,25 saniyede bir saldırı gücünün %27'si kadar hasar alır (saniyede %108) ve 3 saniye yanar (saniyede saldırı gücünün %14'ü). Püskürtme saldırı hızınla hızlanır.",
			"set": {"spray_angle": 60.0, "spray_range": 140.0, "spray_tick": 0.25, "spray_ap": 0.27, "spray_rate": 0.0,
				"elem_ap": 0.14, "elem_dur": 3.0, "elem_dur_mult": 1.0, "spray_push": 0.0}},
		"upgrades": [
			{"name": "Genişleyen Boğaz", "text": "Püskürtme açısı 60° → 72°, menzili 140 → 161 birim.",
				"add": {"spray_angle": 12.0, "spray_range": 21.0}},
			{"name": "Yoğun Alev", "text": "Püskürtme %20 daha sık hasar verir (0,25 → 0,21 saniyede bir).", "add": {"spray_rate": 0.2}},
			{"name": "Kalıcı Yanık", "text": "Yanma süresi %30 uzar (3 → 3,9 saniye).", "add": {"elem_dur_mult": 0.3}},
			{"name": "Nefes Basıncı", "text": "Alev konisi değdiği düşmanları hafifçe geri iterek yaklaşmalarını engeller (bosslar hariç).", "set": {"spray_push": 14.0}},
		],
		"final": {"name": "Ejderha Nefesi", "text": "Koni 1,5 kat uzar (140 → 210 birim) ve 1,25 kat genişler (60° → 75°). Alevin ucuna saniyede bir lav birikintisi düşer: 3 saniye kalır, içindekiler saniyede saldırı gücünün %20'si kadar yanar.",
			"set": {"spray_size": 1.5, "dragon": true}},
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
		"desc": "Topuz yere vurduğunda şansa bağlı olarak vuruş noktasından yayılan, düşmanları sarsan bir şok dalgası çıkar.",
		"base": {"text": "Her vuruş %40 ihtimalle vuruş noktasından yayılan bir dalga çıkarır (4 vuruş üst üste çıkmazsa sonraki kesin çıkar): 110 birim içindekilere saldırı gücünün %70'i kadar hasar verir ve onları 20 birim sarsar (topuzun menzilinden atmaz).",
			"set": {"seis_chance": 0.40, "seis_pity": 4, "seis_radius": 110.0, "seis_ap": 0.7, "seis_push": 20.0, "seis_pulses": 1}},
		"upgrades": [
			{"name": "Halka Yankısı", "text": "Dalga ihtimali: %40 → %50.", "add": {"seis_chance": 0.10}},
			{"name": "Genişleyen Halka", "text": "Dalganın yarıçapı %25 büyür (110 → 137,5 birim).", "add": {"seis_radius": 27.5}},
			{"name": "Tok Darbe", "text": "Dalganın hasarı saldırı gücünün %70'i → %90'ı olur, itme 20 → 30 birim.", "add": {"seis_ap": 0.2, "seis_push": 10.0}},
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
		"weapons": ["pence"], "name": "Kanlı Pençe", "element": "kanama",
		"desc": "Pençe darbeleri kanama bırakır; her pençe darbesinde can kazanırsın.",
		## 2026-10-17 (kullanıcı: "pençe çok güçsüz ve az can basıyor" -> "kanama %20 sg olsun kanama birikmesin"): kanama %7 -> %20 (tek
		## yük, birikmez), can emme %4 -> %6 ve artık İLK vuruşta da (eskiden sadece zaten kanayan hedefte: yeni hedefe ilk vuruş 0 can).
		"base": {"text": "Her pençe 3 saniyelik kanama bırakır (saniyede saldırı gücünün %20'si; birikmez, her vuruş süreyi yeniler). Her pençe darbesinde verdiğin hasarın %6'sı kadar can kazanırsın (alandaki diğer yaratıklara verilen hasardan üçte biri).",
			"set": {"kp_ap": 0.20, "kp_dur": 3.0, "kp_leech": 0.06, "bleeding_bonus": 0.0, "kp_kill_haste": 0.0, "kp_kill_heal": 0.0}},
		"upgrades": [
			{"name": "Derin Pençe", "text": "Kanama hasarı: saniyede saldırı gücünün %20'si → %25'i.", "add": {"kp_ap": 0.05}},
			{"name": "Uzun Kanama", "text": "Kanama 1,5 saniye daha uzun sürer (3 → 4,5 sn).", "add": {"kp_dur": 1.5}},
			{"name": "Kan Emici", "text": "Can emme oranı: %6 → %8.", "add": {"kp_leech": 0.02}},
			{"name": "Yırtıcı Darbe", "text": "Kanayan düşmana verdiğin hasar %15 artar.", "set": {"bleeding_bonus": 0.15}},
		],
		"final": {"name": "Kan Susuzluğu", "text": "Kanayan bir düşmanı öldürdüğünde 3 saniye boyunca saldırı hızın %30 artar ve maksimum canının %3'ü kadar iyileşirsin.",
			"set": {"kp_kill_haste": 0.3, "kp_kill_heal": 0.03}},
	},
	"zincir_yildirim": {
		"weapons": ["lightning_staff"], "name": "Zincir Yıldırım", "element": "sok",
		"desc": "Işın hedefinden en yakın düşmanlara zincirleme atlar.",
		"base": {"text": "Işın hedefinden en yakın 2 düşmana atlar (165 birim içinde, hasarın %35'i).",
			"set": {"chain_add": 2, "chain_pct": 0.35, "chain_range": 0.75, "chain_slow": 0.0}},
		"upgrades": [
			{"name": "Güçlü Atlayış", "text": "Atlayan şimşeğin hasarı: ışının %35'i → %50'si.", "add": {"chain_pct": 0.15}},
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
	"bulasici_salgi": {
		"weapons": ["tuftuf"], "name": "Bulaşıcı Salgı", "element": "zehir",
		"desc": "Dartlar zehirler; zehirli düşman ölünce zehir çevresindeki düşmanlara bulaşır.",
		"base": {"text": "Her dart 4 saniyelik zehir yükü bırakır (yük başına saniyede saldırı gücünün %7'si), yükler 5'e kadar üst üste biner. Zehirli bir düşman ölünce zehri olduğu gibi 50 birim içindeki en çok 6 düşmana bulaşır.",
			"set": {"poison_stacks": 1, "poison_dps": 0.07, "poison_dur": 4.0, "poison_cap": 5.0, "plague_radius": 50.0, "plague_ratio": 1.0}},
		"upgrades": [
			{"name": "Yoğun Zehir", "text": "Zehir hasarı: yük başına saniyede saldırı gücünün %7'si → %9'u.", "add": {"poison_dps": 0.02}},
			{"name": "Uzun Etki", "text": "Zehir 2 saniye daha uzun sürer (4 → 6 sn).", "add": {"poison_dur": 2.0}},
			{"name": "Geniş Salgın", "text": "Bulaşma yarıçapı 50 → 70 birim.", "add": {"plague_radius": 20.0}},
			{"name": "Kalın Birikim", "text": "Zehir yığın sınırı 5 → 8.", "add": {"poison_cap": 3.0}},
		],
		"final": {"name": "Kara Veba", "text": "Bulaşan zehir yükleri %50 artar ve bulaşma yarıçapı 25 birim daha büyür.",
			"add": {"plague_ratio": 0.5, "plague_radius": 25.0}},
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
	"yankilanan_buyu": {
		"weapons": ["arcane"], "name": "Yankılanan Büyü", "element": "kaos",
		"desc": "İsabet hedefin yerinde bir yankı bırakır; kısa süre sonra aynı yerde ikinci bir küre patlar.",
		"base": {"text": "Her isabet %25 ihtimalle (4 isabette bir kesin) hedefin yerinde bir yankı bırakır. 0,8 saniye sonra aynı noktada ikinci bir küre patlar: 45 birim içindekilere silah hasarının %70'i kadar vurur.",
			"set": {"echo_chance": 0.25, "echo_pity": 4, "echo_delay": 0.8, "echo_dmg": 0.7, "echo_radius": 45.0, "echo_repeat": 0, "echo_stun": 0.0}},
		"upgrades": [
			{"name": "Sık Yankı", "text": "Yankı ihtimali: %25 → %35.", "add": {"echo_chance": 0.10}},
			{"name": "Güçlü Yankı", "text": "Yankı patlamasının hasarı: silah hasarının %70'i → %90'ı.", "add": {"echo_dmg": 0.2}},
			{"name": "Geniş Yankı", "text": "Yankı patlamasının alanı 45 → 60 birim.", "add": {"echo_radius": 15.0}},
			{"name": "Çift Yankı", "text": "Yankı 0,5 saniye sonra bir kez daha patlar (hasarın %50'si).", "add": {"echo_repeat": 1}},
		],
		"final": {"name": "Çınlayan Boşluk", "text": "Yankı ihtimali %60'a çıkar ve patlamaya yakalananlar 0,5 saniye sersemler.",
			"set": {"echo_chance": 0.6, "echo_stun": 0.5}},
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
	"zincir_civata": {
		"weapons": ["crossbow"], "name": "Zincir Cıvata", "element": "fiziksel",
		"desc": "Cıvata hedefi delip arkasındaki düşmana da çarpar ve onu sersemletir.",
		"base": {"text": "Cıvata hedefi delip arkasındaki ilk düşmana da çarpar ve onu 0,4 saniye sersemletir.",
			"set": {"pierce": 1, "pierce_pct": 1.0, "cv_stun": 0.4, "cv_slow": 0.0, "cv_splash": 0.0, "cv_all_stun": false}},
		"upgrades": [
			{"name": "Uzun Sersemlik", "text": "Sersemletme süresi 0,4 → 0,7 saniye.", "add": {"cv_stun": 0.3}},
			{"name": "Çift Delme", "text": "Cıvata 1 yerine 2 düşmanı delip geçer.", "add": {"pierce": 1}},
			{"name": "Ağır Cıvata", "text": "Sersemleyen düşman 1,5 saniye %25 yavaşlar.", "set": {"cv_slow": 0.25}},
			{"name": "Şok Dalgası", "text": "Sersemleyen düşmanın 60 birim çevresindekilere cıvata hasarının %50'si kadar vurur.", "set": {"cv_splash": 0.5}},
		],
		"final": {"name": "Zincir Kırıcı", "text": "Cıvata 2 düşman daha deler ve vurduğu HER düşmanı 1 saniye sersemletir.",
			"add": {"pierce": 2}, "set": {"cv_stun": 1.0, "cv_all_stun": true}},
	},
	"cifte_donus": {
		"weapons": ["boomerang"], "name": "Çifte Dönüş", "element": "fiziksel",
		"desc": "Belirli aralıklarla ikinci bir bumerang ters yönlü bir yay çizerek gider.",
		"base": {"text": "Her 4. atışta ikinci bir bumerang ters yönlü bir yay çizerek gider (hasarın %70'i).",
			"set": {"twin_every": 4, "twin_dmg": 0.7, "twin_angle": 40.0, "twin_third": 0.0, "range_mult": 1.0}},
		"upgrades": [
			{"name": "Sık Çift", "text": "İkinci bumerang her 4. atış yerine her 3. atışta gelir.", "add": {"twin_every": -1}},
			{"name": "Güçlü İkiz", "text": "İkinci bumerangın hasarı: %70 → %90.", "add": {"twin_dmg": 0.2}},
			{"name": "Geniş Yay", "text": "İkinci bumerang daha geniş bir yay çizer ve %15 daha uzağa gider.", "add": {"twin_angle": 15.0}, "set": {"range_mult": 1.15}},
			{"name": "Üçüncü Kol", "text": "İkiz atışa üçüncü bir bumerang eklenir (hasarın %50'si).", "set": {"twin_third": 0.5}},
		],
		"final": {"name": "Bumerang Fırtınası", "text": "İkiz atış her 2. atışta gelir ve üçüncü bumerangın hasarı %70'e çıkar.",
			"set": {"twin_every": 2, "twin_third": 0.7}},
	},
	"kirik_buz": {
		"weapons": ["buz_asasi"], "name": "Kırık Buz", "element": "donma",
		"desc": "Asa düşmanları dondurur; donmuşken ölen düşman parçalanır.",
		## 2026-10-10 (kullanıcı: "buz asası hiç dondurmuyor ve efsunu çok işlevsiz"): sayaç asaya bağlı (freeze_count_global; eskiden düşman başınaydı ve asa hedefleri
		## dağıttığı için neredeyse hiç dolmuyordu), taban her 3. -> her 2. isabet, parçalanma %100 -> %120 ve alan 90 -> 100.
		"base": {"text": "Asanın her 2. isabeti vurduğu düşmanı 1,5 saniye dondurur. Donmuşken ölen düşman parçalanır: 100 birim içindekilere saldırı gücünün %120'si kadar vurur ve onları 1 saniye %40 yavaşlatır.",
			"set": {"freeze_after": 2, "freeze_count_global": true, "freeze_dur": 1.5, "shatter_ap": 1.2, "shatter_radius": 100.0, "shatter_slow": 0.4, "shatter_slow_dur": 1.0, "shatter_freeze": false}},
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
		"desc": "Fişek patladığı yerde bir süre rastgele kıvılcım patlamaları bırakır.",
		"base": {"text": "Fişek patlayınca patlama yerinde 3 saniye boyunca rastgele kıvılcım patlamaları olur: 45 birimlik alanda 0,4 saniyede bir, her biri 22 birim içine saldırı gücünün %25'i kadar vurur.",
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
}
