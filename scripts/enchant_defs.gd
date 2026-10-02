class_name EnchantDefs
extends RefCounted

## EFSUN SİSTEMİ - TEK VERİ KAYNAĞI. Kart ekranı (enchant_screen.gd), havuz (enchant_pool.gd), silah davranışları
## (scripts/enchants/<id>.gd) ve durum çözümü (resolve) hep buradan okur - bir efsunun adı/sayısı TEK yerde değişir
## (bkz. CLAUDE.md "iki ayrı yer, biri unutulmuş" hata sınıfı).
##
## 2026-09-30 YENİ SET (kullanıcının yazdığı 21 efsun; eski 75'i aynı gün silindi - git 7d22fac). Soru-cevapla netleşenler
## (hafıza: project-new-enchants-2026-09-30):
##  - Yapı: Temel kartı (mekaniği başlangıç değerleriyle açar) + 4 geliştirme + Final = 6 kart; "Seviye 1-5" biçimindeki
##    üç efsunda (Tektonik / Gölge / Astral) Seviye 1 = Temel, 2-4 = 3 geliştirme, 5 = Final (5 kart). Geliştirmeler RASTGELE
##    sırayla gelir (kullanıcı: "sıra sıra değil"); Final 4'ü de alınınca havuza girer (2026-10-02: ekstralar silinince
##    katalizör eşya şartı kaldırıldı - kullanıcı seçimi; yeni ekstralar gelince istenirse yeniden atanır).
##    Metindeki sıralı zincirler (60→45→30, 4→5→7 ...) eklemeli adımlar ("add") olarak yazıldı: hangi sırayla alınırsa
##    alınsın sonuç kullanıcının yazdığı değer.
##  - Nadirlik YOK (kartlar yazıldığı güçte; normal kart mor = Tier 3, Final kırmızı = Tier 4). Aşkın YOK: biten efsun
##    için kart gelmez. Bir silah kopyası bir efsun alınca oyun sonuna kadar başka efsun almaz.
##  - Birden çok silaha uyan efsunda kart hangi silaha gideceğini söyler (her silah kopyası için ayrı Temel kartı).
##
## Tanım: weapons (uyduğu silahlar), name, element (+ element_by_weapon), desc (tek cümle kimlik),
## base {"text", "set"}, upgrades [4 ya da 3 x {"name", "text", "set"/"add"}], final {"name", "text", "set"}.
## resolve() sırası: base.set -> alınan geliştirmeler (set yazar, add toplar) -> final.set. Anahtarları o efsunun scripti okur.
##
## KART METİNLERİ: tam cümle, kısaltma yok ("SG" değil "saldırı gücü"), değişimler "önce → sonra".
## Efsun ekranı SADECE elit sandıklardan gelir (bkz. enemy.gd _drop_chest / main.gd _show_elite_chest).

const GENERAL_REACTION_POWER := 0.03 ## genel kart: Tepkime Gücü (efsun kalmayınca doldurucu)
const GENERAL_DAMAGE_PERCENT := 0.02 ## genel kart: Keskinlik
const BANISH_PER_RUN := 3
## Kart çerçevesi rengi (TierSystem sırası): normal efsun kartları Epik (mor), Final Efsanevi (kırmızı) - kullanıcı isteği.
const CARD_TIER := 3
const FINAL_CARD_TIER := 4

const ELEMENTS := {
	"zehir": {"name": "Zehir", "color": Color("#8fd65a")},
	"yanma": {"name": "Yanma", "color": Color("#ff8a3c")},
	"donma": {"name": "Donma", "color": Color("#8fd0ff")},
	"kanama": {"name": "Kanama", "color": Color("#e0484e")},
	"sok": {"name": "Şok", "color": Color("#ffe35a")},
	"isaret": {"name": "İşaret", "color": Color("#c98cff")},
	"kaos": {"name": "Kaos", "color": Color("#e08cff")},
	"kutsal": {"name": "Kutsal", "color": Color("#fff2b0")},
	"radyasyon": {"name": "Radyasyon", "color": Color("#b6f25a")},
	"golge": {"name": "Gölge", "color": Color("#9a6ad8")},
	"fiziksel": {"name": "Fiziksel", "color": Color("#d9d2c4")},
}

const WEAPON_NAMES := {
	"dagger": "Bıçak", "fire_staff": "Ateş Asası", "lightning_staff": "Yıldırım Asası", "tabanca": "Tabanca",
	"tuftuf": "Tüftüf", "tufek": "Tüfek", "arcane": "Arcane Asası", "yay": "Yay", "crossbow": "Arbalet",
	"boomerang": "Bumerang", "buz_asasi": "Buz Asası", "fisek": "Fişek", "pence": "Pençe", "topuz": "Topuz",
	"uzunkilic": "Uzunkılıç",
}

const DEFS := {
	## ------------------------------------------------------------------ Ateş / Buz Asası
	"destiny": {
		"weapons": ["fire_staff", "buz_asasi"], "name": "Destiny of Ice and Fire", "element": "yanma",
		"element_by_weapon": {"buz_asasi": "donma"},
		"desc": "Asa mermi atmak yerine en yakın düşmana doğru sürekli ateş (Ateş Asası) ya da buz (Buz Asası) püskürtür.",
		"base": {"text": "Normal atışın yerine 60°'lik, 110 birim menzilli bir koni püskürtürsün. Koninin içindeki herkes 0,25 saniyede bir saldırı gücünün %15'i kadar hasar alır. Ateş: 3 saniye yanar (saniyede saldırı gücünün %8'i). Buz: koninin içinde 2 saniye kalan düşman 1,5 saniye donar. Püskürtme saldırı hızınla hızlanır.",
			"set": {"spray_angle": 60.0, "spray_range": 110.0, "spray_tick": 0.25, "spray_ap": 0.15, "spray_rate": 0.0,
				"elem_ap": 0.08, "elem_dur": 3.0, "freeze_build": 2.0, "freeze_time": 1.5, "elem_dur_mult": 1.0, "spray_push": 0.0}},
		"upgrades": [
			{"name": "Genişleyen Boğaz", "text": "Püskürtme açısı %20 genişler (60° → 72°) ve menzili %15 uzar (110 → 126,5 birim).",
				"add": {"spray_angle": 12.0, "spray_range": 16.5}},
			{"name": "Yoğunlaştırılmış Element", "text": "Püskürtmenin hasar verme sıklığı %20 hızlanır.", "add": {"spray_rate": 0.2}},
			{"name": "Kalıcı Yanık / Soğuk Isırığı", "text": "Püskürtmenin uyguladığı yanma ya da donmanın süresi %30 uzar (yanma 3 → 3,9 sn, donma 1,5 → 1,95 sn).",
				"add": {"elem_dur_mult": 0.3}},
			{"name": "Nefes Basıncı", "text": "Koni temas ettiği düşmanları hafifçe geriye iterek yaklaşmalarını engeller.", "set": {"spray_push": 14.0}},
		],
		"final": {"name": "Ejderha Hükmü", "text": "Püskürtmenin boyutu iki katına çıkar. Ateş nefesi yere lav birikintileri bırakır (3 saniye, içindekiler saniyede saldırı gücünün %20'si kadar yanar). Buz nefesi zemini dondurur: donmuş zemindeki düşmanlar tamamen donar ve sersemler.",
			"set": {"spray_size": 2.0, "dragon": true}},
	},
	## ------------------------------------------------------------------ Bıçak / Pençe
	"valerius": {
		"weapons": ["dagger", "pence"], "name": "Blade of Valerius", "element": "kanama",
		"desc": "Saldırılar arasında düşmanlara saplanan shurikenler fırlatırsın; geri döndüklerinde verdikleri hasarın bir kısmı can olarak döner.",
		"base": {"text": "Her 4. saldırında en yakın 2 düşmana birer shuriken fırlatırsın: çarpınca saldırı gücünün %60'ı kadar hasar verir, 5 saniye saplı kalıp saniyede %10 hasar verir, sonra sana geri döner ve verdiği hasarın %1'i kadar can getirir.",
			"set": {"shuriken_every": 4, "shuriken_count": 2, "shuriken_hit": 0.6, "shuriken_dot": 0.10, "shuriken_stick": 5.0,
				"shuriken_leech": 0.01, "shuriken_dmg_mult": 1.0}},
		"upgrades": [
			{"name": "Keskin Yıldızlar", "text": "Shurikenlerin hasarı %25 artar.", "add": {"shuriken_dmg_mult": 0.25}},
			{"name": "Hızlı Kan Bağı", "text": "Shurikenler düşmanda 5 yerine 3 saniye kalır (can daha erken döner).", "add": {"shuriken_stick": -2.0}},
			{"name": "Açgözlü Çelik", "text": "Can emme oranı: %1 → %2.", "add": {"shuriken_leech": 0.01}},
			{"name": "Üçüz Bıçak", "text": "Fırlatılan shuriken sayısı: 2 → 3.", "add": {"shuriken_count": 1}},
		],
		"final": {"name": "Valerius'un İntikamı", "text": "Geri dönen shurikenler yolundaki tüm düşmanları delip geçer (saldırı gücünün %60'ı). Dönüşte düşman öldüren shurikenin can emmesi %4'e çıkar.",
			"set": {"return_pierce": true, "return_hit": 0.6, "kill_leech": 0.04}},
	},
	## ------------------------------------------------------------------ Uzunkılıç
	"wind_sword": {
		"weapons": ["uzunkilic"], "name": "Wind Sword", "element": "fiziksel",
		"desc": "Kılıç savuruşları şansa bağlı olarak düşmanları savuran ileri doğru bir rüzgar dalgası yaratır.",
		"base": {"text": "Her savuruş %25 ihtimalle ileri doğru 180 birim giden bir rüzgar dalgası yaratır: değdiği düşmanlara saldırı gücünün %70'i kadar hasar verir ve onları 60 birim savurur.",
			"set": {"wave_chance": 0.25, "wave_ap": 0.7, "wave_range": 180.0, "wave_width": 40.0, "wave_push": 60.0, "wave_slow": 0.0}},
		"upgrades": [
			{"name": "Yükselen Akım", "text": "Rüzgar dalgası oluşturma şansı: %25 → %35.", "add": {"wave_chance": 0.10}},
			{"name": "Hırçın Rüzgar", "text": "Rüzgar dalgasının hasarı: saldırı gücünün %70'i → %90'ı.", "add": {"wave_ap": 0.2}},
			{"name": "Hava Presi", "text": "İtme mesafesi %40 artar (60 → 84 birim) ve savrulan düşmanlar 1,5 saniye %30 yavaşlar.",
				"add": {"wave_push": 24.0}, "set": {"wave_slow": 0.3}},
			{"name": "Genişleyen Tayfun", "text": "Rüzgar dalgasının genişliği ve menzili %35 büyür (menzil 180 → 243 birim).",
				"add": {"wave_range": 63.0, "wave_width": 14.0}},
		],
		"final": {"name": "Fırtına Biçici", "text": "Tetiklenme şansı %50 olur. Dalganın duvara ya da engele çarptırdığı düşmanlar %100 ek hasar alır ve 1 saniye sersemler.",
			"set": {"wave_chance_final": 0.5, "wall_slam": true}},
	},
	## ------------------------------------------------------------------ Arcane Asası
	"endless_void": {
		"weapons": ["arcane"], "name": "Endless Void", "element": "kaos",
		"desc": "İsabetler boşluk yükü biriktirir; yük dolunca hedefin yerinde düşmanları içine çeken bir karadelik açılır.",
		"base": {"text": "Her isabet 1 boşluk yükü verir. 20 yükte son vurduğun düşmanın yerinde 3 saniyelik bir karadelik açılır: 80 birim içindeki düşmanları çeker ve saniyede saldırı gücünün %15'i kadar hasar verir.",
			"set": {"void_stacks": 20, "void_radius": 80.0, "void_pull": 1.0, "void_dps": 0.15, "void_dur": 3.0}},
		"upgrades": [
			{"name": "Hafifleyen Eşik", "text": "Karadelik için gereken yük: 20 → 15.", "add": {"void_stacks": -5}},
			{"name": "Kozmik Çekim", "text": "Karadeliğin çekim yarıçapı %25 büyür (80 → 100 birim) ve daha güçlü çeker.",
				"add": {"void_radius": 20.0, "void_pull": 0.5}},
			{"name": "Boşluğun Aşınması", "text": "Karadeliğin hasarı: saniyede saldırı gücünün %15'i → %25'i.", "add": {"void_dps": 0.10}},
			{"name": "Olay Ufku", "text": "Karadelik 2 saniye daha uzun kalır (3 → 5 sn).", "add": {"void_dur": 2.0}},
		],
		"final": {"name": "Tekillik Çöküşü", "text": "Karadeliğin süresi bitince merkezinde dev bir patlama olur: içindeki tüm düşmanlara saldırı gücünün %250'si kadar hasar.",
			"set": {"void_collapse": 2.5}},
	},
	## ------------------------------------------------------------------ Arbalet / Yay
	"arrow_rain": {
		"weapons": ["crossbow", "yay"], "name": "Arrow Rain", "element": "fiziksel",
		"desc": "İsabetler şansa bağlı olarak hedefin üstüne bir süre yağan bir ok yağmuru çağırır.",
		"base": {"text": "Her isabet %15 ihtimalle hedefin üstüne 3 saniyelik bir ok yağmuru çağırır: 70 birim içindekiler 0,5 saniyede bir saldırı gücünün %20'si kadar hasar alır.",
			"set": {"rain_chance": 0.15, "rain_radius": 70.0, "rain_dur": 3.0, "rain_tick": 0.5, "rain_ap": 0.20}},
		"upgrades": [
			{"name": "Fırtına Nişanı", "text": "Ok yağmuru ihtimali: %15 → %25.", "add": {"rain_chance": 0.10}},
			{"name": "Geniş Kapsama", "text": "Ok yağmurunun alanı %25 büyür (70 → 87,5 birim).", "add": {"rain_radius": 17.5}},
			{"name": "Sık Yaylım", "text": "Oklar daha sık düşer: hasar aralığı %20 kısalır (0,5 → 0,4 sn).", "add": {"rain_tick": -0.1}},
			{"name": "Demir Sağanak", "text": "Yağmur 1,5 saniye daha uzun sürer (3 → 4,5 sn).", "add": {"rain_dur": 1.5}},
		],
		"final": {"name": "Gökyüzü Gazabı", "text": "Tetiklenme ihtimali %35 olur. Yağmurun altındaki düşmanların kalkan koruması %30 düşer ve yağmur bittiğinde merkeze dev bir balista oku düşer: 90 birim içindekilere saldırı gücünün %300'ü kadar hasar.",
			"set": {"rain_chance_final": 0.35, "rain_shield_break": 0.3, "ballista": 3.0}},
	},
	## ------------------------------------------------------------------ Yıldırım Asası
	"beam_of_zeus": {
		"weapons": ["lightning_staff"], "name": "Beam of Zeus", "element": "sok",
		"desc": "Belirli aralıklarla en kalabalık yöne kendiliğinden, düşmanları delip geçen kalın bir yıldırım ışını atarsın.",
		"base": {"text": "60 saniyede bir en kalabalık yöne 2 saniyelik, delip geçen kalın bir ışın atarsın: değdiği düşmanlar 0,25 saniyede bir saldırı gücünün %35'i kadar hasar alır. Asanın normal ışını da devam eder.",
			"set": {"zeus_cd": 60.0, "zeus_dur": 2.0, "zeus_tick": 0.25, "zeus_ap": 0.35, "zeus_width": 18.0, "zeus_len": 320.0, "zeus_push": 0.0}},
		"upgrades": [
			{"name": "Statik Depolama", "text": "Işının bekleme süresi 15 saniye kısalır (60 → 45 sn).", "add": {"zeus_cd": -15.0}},
			{"name": "Yüksek Voltaj", "text": "Işının hasarı: saldırı gücünün %35'i → %50'si.", "add": {"zeus_ap": 0.15}},
			{"name": "Geniş Frekans", "text": "Işın %30 kalınlaşır ve isabet alan düşmanları geri iter.", "add": {"zeus_width": 5.4}, "set": {"zeus_push": 24.0}},
			{"name": "Aşırı Yükleme", "text": "Işının bekleme süresi 15 saniye daha kısalır (diğer bekleme kartıyla birlikte 60 → 30 sn).", "add": {"zeus_cd": -15.0}},
		],
		"final": {"name": "Olimpos Yıldırımı", "text": "Bekleme süresi 20 saniyeye iner. Işının değdiği düşmanlar aşırı yüklenir; ışın bittiği an her biri patlar (saldırı gücünün %80'i) ve en yakın 3 düşmana zincirleme şimşek atlar (%50).",
			"set": {"zeus_cd_final": 20.0, "overcharge": true}},
	},
	## ------------------------------------------------------------------ Ateş / Yıldırım Asası
	"trail": {
		"weapons": ["fire_staff", "lightning_staff"], "name": "Magma Trail / Lightning Trail", "element": "yanma",
		"element_by_weapon": {"lightning_staff": "sok"},
		"desc": "Atışların yolu boyunca zeminde bir süre kalan, üstünden geçen düşmanları yakan (Ateş) ya da çarpan (Yıldırım) bir iz bırakır.",
		"base": {"text": "Her atışın geçtiği hat boyunca zeminde 2 saniyelik bir iz kalır (Yıldırım Asası'nda ışının hattı, saniyede bir): izin üstündeki düşmanlar saniyede saldırı gücünün %20'si kadar hasar alır.",
			"set": {"trail_dur": 2.0, "trail_width": 20.0, "trail_dps": 0.20, "trail_slow": 0.0}},
		"upgrades": [
			{"name": "Kalıcı Kalıntı", "text": "İz 1,5 saniye daha uzun kalır (2 → 3,5 sn).", "add": {"trail_dur": 1.5}},
			{"name": "Geniş Kanal", "text": "İzin genişliği %25 büyür (20 → 25 birim).", "add": {"trail_width": 5.0}},
			{"name": "Kavurucu Zemin", "text": "İzin hasarı %30 artar (saniyede saldırı gücünün %20'si → %26'sı).", "add": {"trail_dps": 0.06}},
			{"name": "Köstekleyen Hat", "text": "İzin üstündeki düşmanlar %25 yavaşlar.", "set": {"trail_slow": 0.25}},
		],
		"final": {"name": "Kıyamet Patikası", "text": "Süresi dolan iz patlar: hattın üstündekilere saldırı gücünün %60'ı kadar hasar; patlamaya yakalananlar 3 saniye boyunca yanar ya da çarpılır (saniyede %10).",
			"set": {"trail_blast": 0.6, "trail_blast_dot": 0.10}},
	},
	## ------------------------------------------------------------------ Tüfek / Arbalet
	"hunters_eye": {
		"weapons": ["tufek", "crossbow"], "name": "Hunter's Eye", "element": "isaret",
		"desc": "Canı azalmış düşmanları şansa bağlı olarak infaz edersin; her isabet kalıcı saldırı gücüne dönüşen avcı işareti biriktirir.",
		"base": {"text": "Canı %30'un altındaki normal yaratıklara her isabet %15 ihtimalle onları anında infaz eder (bosslar ve Kademe 7+ elit yaratıklar hariç). Her isabet 1 avcı işareti verir; 100 işarette kalıcı olarak +1 saldırı gücü kazanırsın.",
			"set": {"exec_chance": 0.15, "exec_hp": 0.30, "marks_per_ap": 100, "exec_orb": 0.0}},
		"upgrades": [
			{"name": "Ölümcül Hassasiyet", "text": "İnfaz ihtimali %5 artar (%15 → %20).", "add": {"exec_chance": 0.05}},
			{"name": "Seri Takip", "text": "1 saldırı gücü için gereken işaret 25 azalır (100 → 75).", "add": {"marks_per_ap": -25}},
			{"name": "Avcının Ganimeti", "text": "İnfaz edilen her düşman %25 ihtimalle sana uçan bir can küresi düşürür (maksimum canının %5'i).", "set": {"exec_orb": 0.25}},
			{"name": "Keskin Odak", "text": "İnfaz ihtimali %5 artar ve gereken işaret 25 azalır (diğer kartlarla birlikte: %25 ve 50 işaret).",
				"add": {"exec_chance": 0.05, "marks_per_ap": -25}},
		],
		"final": {"name": "Kusursuz Avcı", "text": "Elit yaratıklar (Kademe 7+) da %7 ihtimalle infaz edilebilir. Her infazdan sonraki 3 saniye boyunca bu silahın tüm atışları kritik vurur.",
			"set": {"exec_elite": 0.07, "exec_crit_time": 3.0}},
	},
	## ------------------------------------------------------------------ Arbalet / Tüfek
	"loaded_chamber": {
		"weapons": ["crossbow", "tufek"], "name": "Loaded Chamber", "element": "fiziksel",
		"desc": "Belirli sayıda atışta bir, çok daha büyük ve güçlü bir mermi atarsın.",
		"base": {"text": "Her 7. atış güçlendirilmiş bir mermidir: 2,5 kat hasar verir ve 1,5 kat büyüktür.",
			"set": {"charged_every": 7, "charged_mult": 2.5, "charged_bonus": 0.0, "charged_scale": 1.5, "charged_pierce": 0}},
		"upgrades": [
			{"name": "Dolu Kovan", "text": "Güçlü merminin hasarı %35 artar (2,5 → 3,4 kat).", "add": {"charged_bonus": 0.35}},
			{"name": "Hızlı Besleme", "text": "Güçlü mermi 1 atış daha sık gelir (her 7. → her 6. atış).", "add": {"charged_every": -1}},
			{"name": "Kinetik Boyut", "text": "Güçlü mermi %30 daha büyür ve değdiği ilk düşmanı delip geçer.", "add": {"charged_scale": 0.45, "charged_pierce": 1}},
			{"name": "Kısa Döngü", "text": "Güçlü mermi 1 atış daha sık gelir (diğer kartla birlikte her 5. atış).", "add": {"charged_every": -1}},
		],
		"final": {"name": "Ağır Kuşatma", "text": "Güçlü mermi çarptığı an şok dalgası yaratır: ilk hedefi 1 saniye sersemletir ve 100 birim içindeki tüm düşmanlara saldırı gücünün %200'ü kadar hasar verir.",
			"set": {"charged_shock": 2.0}},
	},
	## ------------------------------------------------------------------ Bumerang
	"bigerang": {
		"weapons": ["boomerang"], "name": "BIGerang", "element": "fiziksel",
		"desc": "Bumerang deldiği her düşmanla büyür; geri dönerken eski boyutuna döner, dönüşte de vurur.",
		"base": {"text": "Bumerang deldiği her düşman için %3 büyür (en fazla 2,5 kat). Uç noktadan %40 daha hızlı döner, dönüşte de vurur ve normal boyutuna iner.",
			"set": {"grow": 0.03, "grow_max": 2.5, "pierce_ramp": 0.0}},
		"upgrades": [
			{"name": "Hızlı Genleşme", "text": "Delinen düşman başına büyüme: %3 → %5.", "add": {"grow": 0.02}},
			{"name": "Kütle Kazancı", "text": "Deldiği her düşman için bumerangın hasarı da %2 artar.", "add": {"pierce_ramp": 0.02}},
			{"name": "Uzak Uçuş", "text": "Bumerangın gidiş-dönüş menzili %25 uzar.", "set": {"range_mult": 1.25}},
			{"name": "Dev Boyut", "text": "Delinen düşman başına büyüme 2 puan daha artar (diğer kartla birlikte %7).", "add": {"grow": 0.02}},
		],
		"final": {"name": "Titanyum Girdabı", "text": "En büyük boyuta ulaşan bumerang çevresindeki düşmanları (120 birim) içine çeken bir hava burgacı yaratır ve dönüşte boyutunu kaybetmez.",
			"set": {"titan": true}},
	},
	## ------------------------------------------------------------------ Fişek
	"nuukler": {
		"weapons": ["fisek"], "name": "Nuukler", "element": "radyasyon",
		"desc": "Fişek patladığı yerde bir süre kalan radyasyon alanı bırakır.",
		"base": {"text": "Fişek patladığı yere 60 birimlik bir radyasyon alanı bırakır: 3 saniye boyunca içindekiler saniyede saldırı gücünün %15'i kadar hasar alır.",
			"set": {"rad_radius": 60.0, "rad_dur": 3.0, "rad_dps": 0.15, "rad_slow": 0.0, "rad_vuln": 0.0}},
		"upgrades": [
			{"name": "Radyoaktif Yoğunluk", "text": "Radyasyonun hasarı %25 artar (saniyede %15 → %18,75).", "add": {"rad_dps": 0.0375}},
			{"name": "Kalıcı Sızıntı", "text": "Radyasyon alanı 2 saniye daha uzun kalır (3 → 5 sn).", "add": {"rad_dur": 2.0}},
			{"name": "Geniş Serpinti", "text": "Radyasyon alanı %25 büyür (60 → 75 birim).", "add": {"rad_radius": 15.0}},
			{"name": "Doku Çürümesi", "text": "Radyasyondaki düşmanlar %30 yavaşlar ve aldıkları tüm hasar %20 artar.", "set": {"rad_slow": 0.3, "rad_vuln": 0.2}},
		],
		"final": {"name": "Termonükleer Çekirdek", "text": "Fişek çarptığı an bir mantar bulutu çıkarır (100 birim içine saldırı gücünün %200'ü). Radyasyon alanı düşmanların kalkanını tamamen yok sayar.",
			"set": {"mushroom": 2.0, "rad_pen": 1.0}},
	},
	"matryoshka": {
		"weapons": ["fisek"], "name": "Matryoshka Fireworks", "element": "yanma",
		"desc": "Fişek patladığında etrafa küçük fişekler saçar; onlar da ayrıca patlar.",
		"base": {"text": "Fişek patladığında etrafa 2 küçük fişek saçılır (60 birim uzağa): her biri 35 birimde fişeğin hasarının %40'ı kadar patlar.",
			"set": {"mini_count": 2, "mini_ratio": 0.4, "mini_dmg_mult": 1.0, "mini_range": 60.0, "mini_radius": 35.0, "mini_stun": 0.0}},
		"upgrades": [
			{"name": "Ek Parça", "text": "Küçük fişek sayısı 2 artar (2 → 4).", "add": {"mini_count": 2}},
			{"name": "Yıkıcı Kapsül", "text": "Küçük fişeklerin hasarı %25 artar.", "add": {"mini_dmg_mult": 0.25}},
			{"name": "Geniş Dağılım", "text": "Küçük fişeklerin menzili ve patlama alanı %25 büyür.", "add": {"mini_range": 15.0, "mini_radius": 8.75}},
			{"name": "Kör Edici Kıvılcım", "text": "Küçük fişeklerin patlamasına yakalananlar 1 saniye sersemler.", "set": {"mini_stun": 1.0}},
		],
		"final": {"name": "Sonsuz Kaskad", "text": "Patlayan her küçük fişek bir kez daha 2 mikro fişeğe bölünür (her biri fişeğin hasarının %20'si).",
			"set": {"micro": 0.2}},
	},
	## ------------------------------------------------------------------ Pençe / Uzunkılıç
	"donen_saldiri": {
		"weapons": ["pence", "uzunkilic"], "name": "Dönen Saldırı", "element": "kanama",
		"desc": "Belirli sayıda vuruşta bir, çevrendeki herkesi biçen 360°'lik bir savurma yaparsın.",
		"base": {"text": "Her 6. vuruşta 360°'lik bir savurma yaparsın: 90 birim içindeki tüm düşmanlara saldırı gücünün %100'ü kadar hasar.",
			"set": {"spin_every": 6, "spin_ap": 1.0, "spin_radius": 90.0}},
		"upgrades": [
			{"name": "Keskin Çember", "text": "Çember savurmasının hasarı: saldırı gücünün %100'ü → %130'u.", "add": {"spin_ap": 0.3}},
			{"name": "Kısa Hazırlık", "text": "Çember savurması 1 vuruş daha sık gelir (her 6. → her 5. vuruş).", "add": {"spin_every": -1}},
			{"name": "Geniş Yarıçap", "text": "Savurmanın alanı %25 genişler (90 → 112,5 birim).", "add": {"spin_radius": 22.5}},
			{"name": "Refleks Hamlesi", "text": "Çember savurması 1 vuruş daha sık gelir (diğer kartla birlikte her 4. vuruş).", "add": {"spin_every": -1}},
		],
		"final": {"name": "Kan Kasırgası", "text": "Savurma değdiği herkese 4 saniyelik kanama uygular (saniyede saldırı gücünün %8'i) ve çevrende 120 birim içindeki düşman mermilerini yok eden bir hava dalgası çıkarır.",
			"set": {"spin_bleed": 0.08, "spin_ward": 120.0}},
	},
	## ------------------------------------------------------------------ Buz Asası / Arcane Asası
	"prizm": {
		"weapons": ["buz_asasi", "arcane"], "name": "Prizm", "element": "donma", "element_by_weapon": {"arcane": "kaos"},
		"desc": "İsabetler şansa bağlı olarak havada bir kristal bırakır; kristalin içinden geçen mermilerin bölünüp saçılmasını sağlar.",
		"base": {"text": "Her isabet %25 ihtimalle hedefin yerinde 4 saniyelik bir kristal bırakır. Bu silahın kristalden geçen mermisi 2 kopyaya bölünüp saçılır (her kopya %50 hasar).",
			"set": {"crystal_chance": 0.25, "crystal_dur": 4.0, "crystal_size": 24.0, "crystal_split": 2, "split_ratio": 0.5}},
		"upgrades": [
			{"name": "Kristal Çağrısı", "text": "Kristal çıkma ihtimali: %25 → %35.", "add": {"crystal_chance": 0.10}},
			{"name": "Dayanıklı Prizma", "text": "Kristal 3 saniye daha uzun kalır (4 → 7 sn).", "add": {"crystal_dur": 3.0}},
			{"name": "Çoğul Kırılma", "text": "Bölünen kopya sayısı 1 artar (2 → 3).", "add": {"crystal_split": 1}},
			{"name": "Geniş Odak", "text": "Kristal %30 büyür, mermileri yakalaması kolaylaşır.", "add": {"crystal_size": 7.2}},
		],
		"final": {"name": "Kırılma Matrisi", "text": "Kristalden çıkan kopyalar en yakın düşmanlara hafifçe güdümlenir. Süresi biten kristal patlayıp çevresine 6 delici şarapnel saçar (her biri saldırı gücünün %40'ı).",
			"set": {"split_homing": true, "shrapnel": 0.4}},
	},
	## ------------------------------------------------------------------ Bumerang
	"bumerang_testeresi": {
		"weapons": ["boomerang"], "name": "Bumerang Testeresi", "element": "fiziksel",
		"desc": "Bumerang uç noktada bir süre yerinde dönen bir testereye dönüşür.",
		"base": {"text": "Bumerang uç noktada 1,5 saniye yerinde döner: 40 birim içindekilere 0,3 saniyede bir saldırı gücünün %30'u kadar hasar verir, sonra geri döner.",
			"set": {"saw_dur": 1.5, "saw_tick": 0.3, "saw_ap": 0.3, "saw_radius": 40.0, "saw_pull": false}},
		"upgrades": [
			{"name": "Uzayan Dönüş", "text": "Testere 1,5 saniye daha uzun döner (1,5 → 3 sn).", "add": {"saw_dur": 1.5}},
			{"name": "Yüksek Devir", "text": "Testere %25 daha sık vurur (0,3 → 0,24 sn).", "add": {"saw_tick": -0.06}},
			{"name": "Geniş Dişler", "text": "Testerenin çapı %20 büyür (40 → 48 birim).", "add": {"saw_radius": 8.0}},
			{"name": "Girdap Tutuşu", "text": "Dönen testere yakındaki düşmanları merkezine çekip içinde tutar.", "set": {"saw_pull": true}},
		],
		"final": {"name": "Öğütücü", "text": "Testere döndüğü her saniye hasarını %15 artırır; dönüş yolunda değdiği herkese kesin kritik vurur.",
			"set": {"saw_ramp": 0.15, "return_crit": true}},
	},
	## ------------------------------------------------------------------ Tabanca / Tüftüf
	"seken_mermiler": {
		"weapons": ["tabanca", "tuftuf"], "name": "Seken Mermiler", "element": "fiziksel",
		"desc": "Mermiler vurduğu düşmandan sıradakine seker ve her sekişte güçlenir.",
		"base": {"text": "Mermin vurduktan sonra 220 birim içindeki başka düşmanlara 4 kez seker; her sekişte hasarı %5 artar.",
			"set": {"bounce": 4, "bounce_pct": 1.0, "bounce_ramp": 0.05, "bounce_range": 1.0}},
		"upgrades": [
			{"name": "Ek Sıçrama", "text": "Sekme sayısı 1 artar (4 → 5).", "add": {"bounce": 1}},
			{"name": "Kinetik Hızlanma", "text": "Sekiş başına hasar artışı: %5 → %10.", "add": {"bounce_ramp": 0.05}},
			{"name": "Genişletilmiş Açı", "text": "Sekme mesafesi %30 uzar (220 → 286 birim).", "add": {"bounce_range": 0.3}},
			{"name": "Sonsuz Sekiş", "text": "Sekme sayısı 2 artar (diğer kartla birlikte 4 → 7).", "add": {"bounce": 2}},
		],
		"final": {"name": "Kinetik Çığ", "text": "Sekiş başına hasar artışı %15 olur. Mermi son hedefine vardığında biriktirdiği tüm ek hasarı 70 birimlik bir patlamayla çevreye saçar.",
			"set": {"bounce_ramp": 0.15, "avalanche": true}},
	},
	## ------------------------------------------------------------------ Topuz
	"earthquake": {
		"weapons": ["topuz"], "name": "Earthquake", "element": "fiziksel",
		"desc": "Belirli sayıda vuruşta bir, vuruş yönünde düşmanları sersemleten bir sarsıntı hattı açarsın.",
		"base": {"text": "Her 4. vuruşta vuruş yönünde 200 birimlik bir sarsıntı hattı açılır: üstündekiler saldırı gücünün %80'i kadar hasar alır ve 0,5 saniye sersemler.",
			"set": {"quake_every": 4, "quake_len": 200.0, "quake_width": 40.0, "quake_ap": 0.8, "quake_stun": 0.5}},
		"upgrades": [
			{"name": "Derin Yarık", "text": "Sarsıntının menzili %25 uzar (200 → 250 birim).", "add": {"quake_len": 50.0}},
			{"name": "Yıkıcı Sarsıntı", "text": "Sarsıntının hasarı %25 artar (saldırı gücünün %80'i → %100'ü).", "add": {"quake_ap": 0.2}},
			{"name": "Ağır Şok", "text": "Sersemletme 0,75 saniye uzar (0,5 → 1,25 sn).", "add": {"quake_stun": 0.75}},
			{"name": "Geniş Fay", "text": "Sarsıntı hattı %30 genişler (40 → 52 birim).", "add": {"quake_width": 12.0}},
		],
		"final": {"name": "Tektonik Kırılma", "text": "Sarsıntının geçtiği hat 3 saniye yarık kalır (üstündekiler %30 yavaşlar, saniyede saldırı gücünün %15'i kadar hasar alır) ve hattın ucunda dev bir kaya sütunu fırlar: 80 birim içine saldırı gücünün %150'si.",
			"set": {"rift": true, "pillar": 1.5}},
	},
	"sismik_dalga": {
		"weapons": ["topuz"], "name": "Sismik Dalga", "element": "fiziksel",
		"desc": "Topuz yere vurduğunda şansa bağlı olarak çevrene yayılan, düşmanları iten bir şok dalgası çıkar.",
		"base": {"text": "Her vuruş %30 ihtimalle çevrene yayılan bir dalga çıkarır: 110 birim içindekilere saldırı gücünün %50'si kadar hasar verir ve onları 60 birim iter.",
			"set": {"seis_chance": 0.30, "seis_radius": 110.0, "seis_ap": 0.5, "seis_push": 60.0, "seis_pulses": 1}},
		"upgrades": [
			{"name": "Halka Yankısı", "text": "Dalga ihtimali: %30 → %40.", "add": {"seis_chance": 0.10}},
			{"name": "Genişleyen Halka", "text": "Dalganın yarıçapı %25 büyür (110 → 137,5 birim).", "add": {"seis_radius": 27.5}},
			{"name": "Tok Darbe", "text": "Dalganın hasarı ve itme gücü %30 artar.", "add": {"seis_ap": 0.15, "seis_push": 18.0}},
			{"name": "Çift Nabız", "text": "Tek dalga yerine art arda 2 dalga yayılır.", "add": {"seis_pulses": 1}},
		],
		"final": {"name": "Episantr", "text": "Dalga ihtimali %50 olur. Dalga düşmanları 1,5 saniye yere serer (sersemletir); savrulan düşmanlar birbirine çarparsa ikisi de saldırı gücünün %30'u kadar hasar alır.",
			"set": {"seis_chance_final": 0.5, "seis_knockdown": 1.5, "seis_collide": 0.3}},
	},
	## ------------------------------------------------------------------ Topuz / Uzunkılıç ("Seviye" biçimi)
	"tektonik_yarik": {
		"weapons": ["topuz", "uzunkilic"], "name": "Tektonik Yarık", "element": "fiziksel",
		"desc": "Her darbe zemini kırar; vuruş yönünde düşmanları yakan ve yavaşlatan çatlaklar bırakır.",
		"base": {"text": "Her vuruş, vuruş yönünde 120 birimlik bir zemin yarığı açar: 2 saniye açık kalır, üstündekiler saniyede silah hasarının %30'unu alır.",
			"set": {"crack_len": 120.0, "crack_width": 20.0, "crack_dur": 2.0, "crack_wdmg": 0.30, "crack_slow": 0.0, "crack_vuln": 0.0,
				"crack_x_every": 0, "crack_close": 0.0}},
		"upgrades": [
			{"name": "Seviye 2", "text": "Yarığın genişliği iki katına çıkar; üstündeki düşmanlar %40 yavaşlar ve %20 fazla hasar alır.",
				"set": {"crack_width": 40.0, "crack_slow": 0.4, "crack_vuln": 0.2}},
			{"name": "Seviye 3", "text": "Her 3. vuruş yarığı \"X\" biçiminde çapraz patlatır: değdiği düşmanlara silah hasarının %60'ı ve 0,75 saniye havaya savrulma (sersemleme).",
				"set": {"crack_x_every": 3, "crack_x_dmg": 0.6, "crack_x_stun": 0.75}},
			{"name": "Seviye 4", "text": "Yarık kapanırken içindekilere silah hasarının %40'ı kadar vurur; içerideki her düşman için bu hasar %15 artar.",
				"set": {"crack_close": 0.4}},
		],
		"final": {"name": "Fay Kırığı", "text": "Yarık kapanırken zemin lav ve sivri kayalarla fışkırır: hattaki tüm düşmanlar merkeze çekilip ezilir ve silah hasarının %400'ü kadar (içerideki her düşman için %15 fazla) tek bir sismik patlama olur.",
			"set": {"fault": 4.0}},
	},
	## ------------------------------------------------------------------ Bıçak / Pençe ("Seviye" biçimi)
	"golge_yankisi": {
		"weapons": ["dagger", "pence"], "name": "Gölge Yankısı", "element": "golge",
		"desc": "Tamamladığın vuruş serileri arkanda, komboyu gecikmeli tekrarlayan bir gölge bırakır.",
		"base": {"text": "Tamamladığın her kombo (Bıçak: 3 vuruş, Pençe: 2 vuruş) hedefin yerinde bir gölge bırakır; gölge 1,5 saniye sonra komboyu aynı yerde silah hasarının %35'iyle tekrarlar.",
			"set": {"shade_dmg": 0.35, "shade_bleed": 0.0, "shade_swap": false, "shade_max": 1, "shade_life": 4.0}},
		"upgrades": [
			{"name": "Seviye 2", "text": "Gölgenin hasarı %55'e çıkar; kestiği düşmanlara 3 saniyelik Derin Kanama bulaşır (saniyede silah hasarının %20'si).",
				"set": {"shade_dmg": 0.55, "shade_bleed": 0.2}},
			{"name": "Seviye 3", "text": "Bir hareket tuşuna çift bastığında en son gölgenle yer değiştirirsin ve 0,5 saniye hasar almazsın.",
				"set": {"shade_swap": true}},
			{"name": "Seviye 4", "text": "Aynı anda 2 gölge olabilir. İki gölgenin arasında duruyorsan %20 saldırı hızı kazanırsın.",
				"set": {"shade_max": 2}},
		],
		"final": {"name": "Bin Bıçak Dansı", "text": "Sahada 2 gölge varken kombo tamamlarsan sen ve gölgelerin 0,75 saniye hedef alınamaz olursunuz; 80 birim içindeki düşmanlar arasında ışınlanarak 8 ardışık darbe indirirsin (toplam silah hasarının %500'ü).",
			"set": {"dance": 5.0}},
	},
	## ------------------------------------------------------------------ Bumerang / Arcane Asası ("Seviye" biçimi)
	"astral_yorunge": {
		"weapons": ["boomerang", "arcane"], "name": "Astral Yörünge", "element": "kaos",
		"desc": "Vuran mermiler kaybolmak yerine etrafında yörüngeye girip koruyucu bir testere çemberi oluşturur.",
		"base": {"text": "İsabet eden mermi etrafında 3 saniye döner; değdiği düşmanlara silah hasarının %40'ı kadar vurur (en fazla 1 yörünge nesnesi).",
			"set": {"orbit_max": 1, "orbit_dur": 3.0, "orbit_dmg": 0.4, "orbit_speed": 1.0, "orbit_ward": false, "orbit_knock": 0.0}},
		"upgrades": [
			{"name": "Seviye 2", "text": "Yörüngede 2 nesne olabilir; yörünge çemberi sana gelen düşman mermilerini yok eder.",
				"add": {"orbit_max": 1}, "set": {"orbit_ward": true}},
			{"name": "Seviye 3", "text": "Yörünge %40 hızlı döner ve değdiği düşmanları geri iter.", "add": {"orbit_speed": 0.4}, "set": {"orbit_knock": 30.0}},
			{"name": "Seviye 4", "text": "Yörüngede 3 nesne olabilir. 3 nesne dönerken %15 hareket hızı ve %10 hasar azaltma kazanırsın.",
				"add": {"orbit_max": 1}, "set": {"orbit_full_buff": true}},
		],
		"final": {"name": "Olay Ufku", "text": "3 nesne birleşip 5 saniyelik dev bir kozmik diske dönüşür: bosslar dışındaki düşmanları içine çeker, 0,3 saniyede bir silah hasarının %90'ı kadar vurur ve süre bitince dışa patlayarak herkesi savurur.",
			"set": {"cosmic": 0.9}},
	},
}


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})


static func has_weapon(weapon_key: String) -> bool:
	return WEAPON_NAMES.has(weapon_key)


## Bu silaha uyan efsunlar (DEFS sırasıyla).
static func enchants_for(weapon_key: String) -> Array:
	var out: Array = []
	for id in DEFS:
		if (DEFS[id]["weapons"] as Array).has(weapon_key):
			out.append(id)
	return out


## Efsunun elementi - silaha göre değişebilir (Ateş/Buz Asası).
static func element_of(id: String, weapon_key: String) -> String:
	var def: Dictionary = get_def(id)
	return str((def.get("element_by_weapon", {}) as Dictionary).get(weapon_key, def.get("element", "fiziksel")))


static func element_color(element: String) -> Color:
	return Color(ELEMENTS.get(element, ELEMENTS["fiziksel"])["color"])


static func element_name(element: String) -> String:
	return str(ELEMENTS.get(element, ELEMENTS["fiziksel"])["name"])


## Kayıt: {"id", "ups": [alınan geliştirme indeksleri], "final": bool}. Eski biçim ({"steps"}) artık yok.
static func upgrades_taken(ench: Dictionary) -> Array:
	return ench.get("ups", [])


static func is_complete(ench: Dictionary) -> bool:
	return bool(ench.get("final", false))


## Kaydı davranış scriptinin okuyacağı düz istatistik sözlüğüne çevirir: base.set -> alınan geliştirmeler (indeks sırasıyla;
## "add" toplandığı için sıra sonucu değiştirmez) -> final.set. "weapon" = kopyanın silah anahtarı (element_by_weapon için).
static func resolve(ench: Dictionary, weapon_key: String = "") -> Dictionary:
	var id: String = str(ench.get("id", ""))
	var def: Dictionary = get_def(id)
	if def.is_empty():
		return {}
	var stats: Dictionary = {"id": id, "weapon": weapon_key, "element": element_of(id, weapon_key)}
	_apply_step(stats, def["base"])
	var ups: Array = (upgrades_taken(ench) as Array).duplicate()
	ups.sort()
	var def_ups: Array = def["upgrades"]
	for i in ups:
		if int(i) >= 0 and int(i) < def_ups.size():
			_apply_step(stats, def_ups[int(i)])
	stats["up_count"] = ups.size()
	stats["is_final"] = is_complete(ench)
	if stats["is_final"]:
		_apply_step(stats, def["final"])
	return stats


static func _apply_step(stats: Dictionary, step: Dictionary) -> void:
	for k in step.get("set", {}):
		stats[k] = step["set"][k]
	for k in step.get("add", {}):
		stats[k] = float(stats.get(k, 0.0)) + float(step["add"][k])
